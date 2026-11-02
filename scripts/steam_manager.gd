extends Node

## Global Steam state and networking helpers shared by every scene.

const MANAGER_SCENE := "res://scenes/SteamLobbyManager/SteamLobbyManager.tscn"

## 480 is Spacewar, Valve's free testing app; use your own app ID for release.
## Override with the STEAM_APP_ID environment variable without editing this file.
var STEAM_APP_ID: int = 480

var steam_id: int = 0
var username: String = ""

var lobby_id: int = 0
var is_lobby_host: bool = false

## Set when Steam launches the game with "+connect_lobby <id>" or an invite lands
## while another scene is loaded.  The lobby manager consumes it on _ready.
var invite_lobby_id: int = 0

## The one peer used for the whole session; recreated every time we reset.
var peer: SteamMultiplayerPeer = SteamMultiplayerPeer.new()

## Emitted on the server once every lobby member has reported that the game
## scene finished loading, so players can be spawned safely on all peers.
signal level_sync_complete

var _level_finished: bool = false

## Temporary two-instance test harness: --lobbytest2 (host) or
## --lobbytestjoin <lobby_id> (client).  Empty _test_role = normal gameplay.
var _test_role: String = ""
## Set when a second instance on the same Steam account must join as client.
var force_client: bool = false
var _test_phase: int = 0
var _test_local_start_x: float = -999999.0
var _test_remote_start_x: float = -999999.0
var _test_grace_ok: bool = false

const _TEST_ENET_PORT: int = 4678


func _init() -> void:
	if OS.has_environment("STEAM_APP_ID"):
		STEAM_APP_ID = int(OS.get_environment("STEAM_APP_ID"))
	OS.set_environment("SteamAppID", str(STEAM_APP_ID))
	OS.set_environment("SteamGameID", str(STEAM_APP_ID))

	var args := OS.get_cmdline_args()
	var join_index := args.find("--lobbytestjoin")
	if join_index >= 0 and join_index + 1 < args.size():
		_test_role = "client"
		force_client = true
		invite_lobby_id = int(args[join_index + 1])
	elif args.has("--lobbytest2"):
		_test_role = "host"


func _ready() -> void:
	Steam.steamInit()

	steam_id = Steam.getSteamID()
	username = Steam.getPersonaName()
	print("Logged into Steam as %s (%s)" % [username, steam_id])

	Steam.join_requested.connect(_on_join_requested)
	Steam.lobby_data_update.connect(_on_lobby_data_update)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)

	_check_command_line()

	if not _test_role.is_empty():
		get_tree().create_timer(60.0).timeout.connect(_test_timeout)


func _process(_delta: float) -> void:
	Steam.run_callbacks()
	_test_process()


#region Networking
## Creates the host side of the connection once the lobby exists.
## Note: multiplayer_peer defaults to an OfflineMultiplayerPeer since Godot 4.3,
## so check against our own peer instead of just null.
func setup_host() -> void:
	if not _test_role.is_empty():
		_setup_test_transport(true)
		return
	if multiplayer.multiplayer_peer == peer:
		return
	peer.server_relay = true
	var err: Error = peer.host_with_lobby(lobby_id)
	if err != OK:
		printerr("Failed to host lobby networking: %s" % err)
		return
	multiplayer.multiplayer_peer = peer
	print("Hosting networking for lobby %s" % lobby_id)


## Connects this player to the lobby owner through Steam.
func setup_client() -> void:
	if not _test_role.is_empty():
		_setup_test_transport(false)
		return
	if multiplayer.multiplayer_peer == peer:
		return
	peer.server_relay = true
	var err: Error = peer.connect_to_lobby(lobby_id)
	if err != OK:
		printerr("Failed to connect to lobby networking: %s" % err)
		return
	multiplayer.multiplayer_peer = peer
	print("Connected to the networking of lobby %s" % lobby_id)


## Leaves the Steam lobby and tears down the network connection.
func leave_lobby() -> void:
	if lobby_id > 0:
		Steam.leaveLobby(lobby_id)
	lobby_id = 0
	is_lobby_host = false
	reset_networking()


func reset_networking() -> void:
	multiplayer.multiplayer_peer = null
	peer.close()
	peer = SteamMultiplayerPeer.new()
	_level_finished = false
#endregion


#region Level sync
## Called by every peer, host included, once its game scene is ready.
func mark_level_loaded() -> void:
	if lobby_id <= 0:
		return
	Steam.setLobbyMemberData(lobby_id, "level_ready", "1")
	_check_level_sync()


func is_level_sync_finished() -> bool:
	return _level_finished


func _check_level_sync() -> void:
	if _level_finished or lobby_id <= 0:
		return
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	# Everyone currently in the lobby has to be ready.  The lobby is closed to
	# new members when the match starts, so this set only ever shrinks.
	for i in Steam.getNumLobbyMembers(lobby_id):
		var member_id: int = Steam.getLobbyMemberByIndex(lobby_id, i)
		if Steam.getLobbyMemberData(lobby_id, member_id, "level_ready") != "1":
			return
	_level_finished = true
	level_sync_complete.emit()


# success is an int before GodotSteam 4.20 and a bool after, so keep it untyped.
func _on_lobby_data_update(success, this_lobby_id: int, _member_id: int) -> void:
	if bool(success) and this_lobby_id == lobby_id:
		_check_level_sync()


# A member leaving (or being kicked) before the sync finishes has to re-trigger
# the readiness check; that fires lobby_chat_update, not lobby_data_update.
func _on_lobby_chat_update(this_lobby_id: int, _changed_id: int, _making_change_id, _chat_state) -> void:
	if this_lobby_id == lobby_id:
		_check_level_sync()
#endregion


#region Joining without the lobby list
func _on_join_requested(invited_lobby_id: int, friend_id: int) -> void:
	print("Joining lobby %s invited by %s" % [invited_lobby_id, Steam.getFriendPersonaName(friend_id)])
	_join_lobby_or_change_scene(invited_lobby_id)


## Steam launches the game with "+connect_lobby <lobby id>" when a player
## accepts an invite without the game already running.
func _check_command_line() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	for i in args.size():
		if args[i] == "+connect_lobby" and i + 1 < args.size():
			var id: int = int(args[i + 1])
			if id > 0:
				print("Found a lobby invite on the command line: %s" % id)
				invite_lobby_id = id


func _join_lobby_or_change_scene(new_lobby_id: int) -> void:
	if new_lobby_id == lobby_id and lobby_id > 0:
		return
	if lobby_id > 0:
		leave_lobby()

	var current := get_tree().current_scene
	if current != null and current.scene_file_path == MANAGER_SCENE:
		Steam.joinLobby(new_lobby_id)
	else:
		# The lobby manager is not loaded yet; it joins once it is ready.
		invite_lobby_id = new_lobby_id
		get_tree().change_scene_to_file(MANAGER_SCENE)
#endregion


#region Disconnections
func _on_server_disconnected() -> void:
	printerr("Lost the connection to the lobby host")
	_return_to_menu()


func _on_connection_failed() -> void:
	printerr("Failed to connect to the lobby host")
	_return_to_menu()


func _return_to_menu() -> void:
	leave_lobby()
	var current := get_tree().current_scene
	if current != null and current.scene_file_path != MANAGER_SCENE:
		get_tree().change_scene_to_file(MANAGER_SCENE)
#endregion


#region Two-instance test harness
## Two instances on one Steam account share a single lobby-member entry, so the
## Steam transport cannot connect them; ENet on loopback exercises the exact
## same Godot multiplayer code paths (spawner, authority, synchronizer).
func _setup_test_transport(as_server: bool) -> void:
	var enet := ENetMultiplayerPeer.new()
	var err: Error
	if as_server:
		err = enet.create_server(_TEST_ENET_PORT)
	else:
		err = enet.create_client("127.0.0.1", _TEST_ENET_PORT)
	if err != OK:
		printerr("LOBBYTEST2: failed to create the ENet peer: %s" % err)
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = enet
	print("LOBBYTEST2: ENet %s ready" % ("server" if as_server else "client"))


func _test_process() -> void:
	if _test_role.is_empty():
		return
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != "res://main/main.tscn":
		return
	var spawn_root := scene.get_node_or_null("Players/SpawnPosition")
	if spawn_root == null:
		return

	if _test_phase == 0:
		if spawn_root.get_child_count() < 2:
			return
		print("LOBBYTEST2: %s players spawned" % spawn_root.get_child_count())
		_test_phase = 1
		for player in spawn_root.get_children():
			if player.name == str(multiplayer.get_unique_id()):
				_test_local_start_x = player.position.x
			else:
				_test_remote_start_x = player.position.x
		if _test_role == "host":
			_hold_right_key()
			# Stay alive after moving so the client has time to receive the
			# replicated position updates before this instance exits.
			get_tree().create_timer(3.5).timeout.connect(func() -> void: _test_grace_ok = true)
		return

	var local_node := spawn_root.get_node_or_null(str(multiplayer.get_unique_id()))
	var local_moved := local_node != null \
		and absf(local_node.position.x - _test_local_start_x) > 0.4
	if _test_role == "host":
		if _test_grace_ok and local_moved:
			_test_pass("local movement works")
		return

	for player in spawn_root.get_children():
		if player.name != str(multiplayer.get_unique_id()) \
				and absf(player.position.x - _test_remote_start_x) > 0.4:
			_test_pass("position sync works (remote x %.2f -> %.2f)" % [
				_test_remote_start_x, player.position.x])
			return


## The host presses "right" so the client can observe the replicated movement.
func _hold_right_key() -> void:
	var down := InputEventKey.new()
	down.keycode = KEY_RIGHT
	down.physical_keycode = KEY_RIGHT
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().create_timer(3.0).timeout
	var up := InputEventKey.new()
	up.keycode = KEY_RIGHT
	up.physical_keycode = KEY_RIGHT
	up.pressed = false
	Input.parse_input_event(up)


func _test_pass(message: String) -> void:
	print("LOBBYTEST2: %s" % message)
	print("LOBBYTEST2: PASS")
	get_tree().quit(0)


func _test_timeout() -> void:
	var scene := get_tree().current_scene
	var where := "<none>"
	var players := 0
	if scene != null:
		where = scene.scene_file_path
		var spawn_root := scene.get_node_or_null("Players/SpawnPosition")
		if spawn_root != null:
			players = spawn_root.get_child_count()
	print("LOBBYTEST2: TIMEOUT role=%s phase=%s scene=%s players=%s" % [
		_test_role, _test_phase, where, players])
	get_tree().quit(1)
#endregion
