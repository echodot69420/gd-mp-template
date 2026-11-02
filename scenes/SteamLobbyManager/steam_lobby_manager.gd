extends Control

## Switches between the host form, the lobby list and the lobby itself, and
## moves the player into the lobby whenever Steam reports a successful join.

const HOST_SCENE: PackedScene = preload("res://scenes/player/SteamLobbyHost/SteamLobbyHost.tscn")
const LIST_SCENE: PackedScene = preload("res://scenes/SteamLobbyList/steam_lobby_list.tscn")
const LOBBY_SCENE: PackedScene = preload("res://scenes/SteamLobby/steam_lobby.tscn")

@onready var scene_slot: Control = %Scene
@onready var menu: HBoxContainer = %Menu
@onready var host_button: Button = %Host
@onready var join_button: Button = %Join
@onready var exit_button: Button = %Exit

var _test_mode: bool = false
var _test2_mode: bool = false


func _ready() -> void:
	host_button.pressed.connect(_show_host_scene)
	join_button.pressed.connect(_show_list_scene)
	exit_button.pressed.connect(func() -> void: get_tree().quit())
	Steam.lobby_joined.connect(_on_lobby_joined)

	# Join a lobby handed to us by a Steam invite or the +connect_lobby argument.
	if SteamManager.invite_lobby_id > 0:
		var id: int = SteamManager.invite_lobby_id
		SteamManager.invite_lobby_id = 0
		Steam.joinLobby(id)

	# Temporary automated tests (see SteamManager test harness).
	_test_mode = OS.get_cmdline_args().has("--lobbytest")
	_test2_mode = OS.get_cmdline_args().has("--lobbytest2")
	if _test_mode:
		get_tree().create_timer(15.0).timeout.connect(_test_timeout)
		_show_host_scene()
		print("LOBBYTEST: pressing Create on the host form...")
		var host: Variant = scene_slot.get_child(0)
		host.create.pressed.emit()
	elif _test2_mode:
		_show_host_scene()
		print("LOBBYTEST2: creating the host lobby...")
		var host2: Variant = scene_slot.get_child(0)
		host2.create.pressed.emit()


func _on_test_match_list(lobbies: Array) -> void:
	print("LOBBYTEST: lobby list returned %s lobbies" % lobbies.size())
	SteamManager.leave_lobby()
	print("LOBBYTEST: PASS")
	get_tree().quit(0)


## The client instance connected over the test transport: start the match.
func _on_test2_peer_connected(_id: int) -> void:
	print("LOBBYTEST2: client peer connected, starting the match...")
	var lobby_scene: Variant = scene_slot.get_child(0)
	lobby_scene._on_start_pressed()


func _test_timeout() -> void:
	print("LOBBYTEST: TIMEOUT - expected callbacks never arrived")
	get_tree().quit(1)


func _show_host_scene() -> void:
	_show_scene(HOST_SCENE)


func _show_list_scene() -> void:
	_show_scene(LIST_SCENE)


func _show_scene(scene: PackedScene) -> void:
	_clear_scene()
	var instance: Node = scene.instantiate()
	# Connect before adding so a signal emitted from _ready() is not missed.
	if instance.has_signal("closed"):
		instance.connect("closed", _on_scene_closed)
	scene_slot.add_child(instance)
	menu.visible = false


func _clear_scene() -> void:
	for child in scene_slot.get_children():
		scene_slot.remove_child(child)
		child.queue_free()


func _on_scene_closed() -> void:
	_clear_scene()
	menu.visible = true


func _on_lobby_joined(this_lobby_id: int, _permissions, _locked, response) -> void:
	if response == Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		print("Lobby %s joined successfully" % this_lobby_id)
		SteamManager.lobby_id = this_lobby_id
		SteamManager.is_lobby_host = Steam.getLobbyOwner(this_lobby_id) == SteamManager.steam_id

		if SteamManager.is_lobby_host and not SteamManager.force_client:
			SteamManager.setup_host()
		else:
			SteamManager.setup_client()

		_show_scene(LOBBY_SCENE)

		if _test_mode:
			print("LOBBYTEST: peer assigned: %s, is_server: %s" % [
				multiplayer.multiplayer_peer == SteamManager.peer, multiplayer.is_server()])
			print("LOBBYTEST: joined lobby %s, requesting the lobby list..." % this_lobby_id)
			Steam.lobby_match_list.connect(_on_test_match_list, CONNECT_ONE_SHOT)
			Steam.requestLobbyList()
		elif _test2_mode:
			multiplayer.peer_connected.connect(_on_test2_peer_connected, CONNECT_ONE_SHOT)
			print("LOBBYTEST2: host lobby %s ready" % this_lobby_id)
	else:
		# Leave the player on whatever screen they were on.
		printerr(_join_error(response))


func _join_error(response) -> String:
	match response:
		Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST:
			return "Failed to join the lobby: it no longer exists."
		Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_NOT_ALLOWED:
			return "Failed to join the lobby: you don't have permission to join."
		Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_FULL:
			return "Failed to join the lobby: it is now full."
		Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_BANNED:
			return "Failed to join the lobby: you are banned."
		Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_LIMITED:
			return "Failed to join the lobby: you cannot join with a limited account."
		Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_RATE_LIMIT_EXCEEDED:
			return "Failed to join the lobby: rate limit exceeded."
	return "Failed to join the lobby: %s" % response
