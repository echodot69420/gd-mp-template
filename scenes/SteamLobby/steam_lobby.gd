extends Control

signal closed

const LOBBY_PLAYER := preload("res://scenes/SteamLobby/lobby_player.tscn")
const GAME_SCENE: PackedScene = preload("res://main/main.tscn")

@onready var _title: Label = %Title
@onready var _hint: Label = %Hint
@onready var _invite: Button = %Invite
@onready var _start: Button = %Start
@onready var _leave: Button = %Leave
@onready var _player_list: VBoxContainer = %PlayerList
@onready var _log: RichTextLabel = %Log
@onready var _message: LineEdit = %Message
@onready var _send: Button = %Send

var _starting: bool = false


func _emit_closed() -> void:
	closed.emit()


func _ready() -> void:
	if SteamManager.lobby_id == 0:
		printerr("You are not in a lobby currently")
		# Defer: emitting here would make the manager free us mid-_ready().
		call_deferred("_emit_closed")
		return

	_title.text = Steam.getLobbyData(SteamManager.lobby_id, "lobby_name")
	_start.visible = SteamManager.is_lobby_host
	_hint.visible = not SteamManager.is_lobby_host

	_invite.pressed.connect(_on_invite_pressed)
	_leave.pressed.connect(_on_leave_pressed)
	_start.pressed.connect(_on_start_pressed)

	_send.disabled = true
	_send.pressed.connect(_on_send_pressed)
	_message.text_changed.connect(_on_message_text_changed)
	_message.text_submitted.connect(_on_message_text_submitted)

	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	Steam.lobby_data_update.connect(_on_lobby_data_update)
	Steam.lobby_message.connect(_on_lobby_message)

	_log.add_text("Welcome to the lobby, %s\n" % SteamManager.username)
	_get_lobby_members()


#region Members
func _get_lobby_members() -> void:
	for child in _player_list.get_children():
		_player_list.remove_child(child)
		child.free()

	for i in Steam.getNumLobbyMembers(SteamManager.lobby_id):
		var player = LOBBY_PLAYER.instantiate()
		player.steam_id = Steam.getLobbyMemberByIndex(SteamManager.lobby_id, i)
		_player_list.call_deferred("add_child", player)


func _on_lobby_chat_update(this_lobby_id: int, user_changed_id: int, _making_change_id, chat_state) -> void:
	if this_lobby_id != SteamManager.lobby_id:
		return

	var changed_user: String = Steam.getFriendPersonaName(user_changed_id)
	if chat_state == Steam.ChatMemberStateChange.CHAT_MEMBER_STATE_CHANGE_ENTERED:
		_log.add_text("%s joined the lobby\n" % changed_user)
	else:
		_log.add_text("%s left the lobby\n" % changed_user)
	_get_lobby_members()


# success is an int before GodotSteam 4.20 and a bool after, so keep it untyped.
func _on_lobby_data_update(success, this_lobby_id: int, _member_id: int) -> void:
	if not bool(success) or this_lobby_id != SteamManager.lobby_id:
		return

	_title.text = Steam.getLobbyData(this_lobby_id, "lobby_name")
	_get_lobby_members()

	# The host flags the lobby when the match starts.
	if Steam.getLobbyData(this_lobby_id, "state") == "game":
		_start_level()
#endregion


#region Chat
func _on_message_text_changed(new_text: String) -> void:
	_send.disabled = new_text.strip_edges().is_empty()


func _on_message_text_submitted(_new_text: String) -> void:
	_on_send_pressed()


func _on_send_pressed() -> void:
	var text: String = _message.text.strip_edges()
	if text.is_empty():
		return
	if not Steam.sendLobbyChatMsg(SteamManager.lobby_id, text):
		printerr("Failed to send the chat message")
	_message.clear()
	_send.disabled = true


func _on_lobby_message(this_lobby_id: int, sender: int, message: String, chat_type) -> void:
	if this_lobby_id != SteamManager.lobby_id:
		return
	if chat_type != Steam.ChatEntryType.CHAT_ENTRY_TYPE_CHAT_MSG:
		return

	var sender_name: String = Steam.getFriendPersonaName(sender)
	# Only the lobby owner may run commands.
	if message.begins_with("/") and sender == Steam.getLobbyOwner(SteamManager.lobby_id):
		_process_chat_commands(message, sender_name)
	else:
		_log.add_text("%s: %s\n" % [sender_name, message])


func _process_chat_commands(message: String, sender_name: String) -> void:
	var command: PackedStringArray = message.split(" ", false)
	match command[0]:
		"/kick":
			if command.size() < 2:
				printerr("Missing a value for the /kick command")
				return
			var target_id: int = int(command[1])
			if target_id == SteamManager.steam_id:
				_log.add_text("You were kicked from the lobby by %s\n" % sender_name)
				print("Kicked from the lobby by %s" % sender_name)
				SteamManager.leave_lobby()
				closed.emit()
			else:
				_log.add_text("%s kicked %s\n" % [sender_name, Steam.getFriendPersonaName(target_id)])
		_:
			printerr("Unknown lobby command: %s" % command[0])
#endregion


#region Controls
func _on_invite_pressed() -> void:
	Steam.activateGameOverlayInviteDialog(SteamManager.lobby_id)


func _on_leave_pressed() -> void:
	SteamManager.leave_lobby()
	closed.emit()


func _on_start_pressed() -> void:
	if not SteamManager.is_lobby_host or _starting:
		return

	# Close the lobby to new players and tell everyone to load the game scene.
	if not Steam.setLobbyJoinable(SteamManager.lobby_id, false):
		printerr("Failed to close the lobby to new players")
	if not Steam.setLobbyData(SteamManager.lobby_id, "state", "game"):
		printerr("Failed to set the lobby state")
	_start_level()


func _start_level() -> void:
	if _starting:
		return
	_starting = true
	get_tree().change_scene_to_packed(GAME_SCENE)
#endregion
