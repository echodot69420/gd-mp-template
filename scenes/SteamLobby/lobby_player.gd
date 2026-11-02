extends HBoxContainer

## Set by the lobby scene before the player row is added to the scene.
var steam_id: int = 0

@onready var host_badge: Label = %Host
@onready var name_label: Label = %Name
@onready var kick: Button = %Kick


func _ready() -> void:
	name_label.text = Steam.getFriendPersonaName(steam_id)
	kick.pressed.connect(_on_kick_pressed)
	_set_defaults()


func _set_defaults() -> void:
	# The host gets a little badge; only the host sees kick buttons.
	host_badge.visible = Steam.getLobbyOwner(SteamManager.lobby_id) == steam_id
	kick.visible = SteamManager.is_lobby_host and steam_id != SteamManager.steam_id


func _on_kick_pressed() -> void:
	if not SteamManager.is_lobby_host or steam_id == SteamManager.steam_id:
		return
	print("Sending kick command for %s" % steam_id)
	if not Steam.sendLobbyChatMsg(SteamManager.lobby_id, "/kick %s" % steam_id):
		printerr("Failed to send the kick command for %s" % steam_id)
