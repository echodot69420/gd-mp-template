extends Control

signal closed

@onready var create: Button = %Create
@onready var close: Button = %Close
@onready var lobby_data: LineEdit = %LobbyData
@onready var max_players: SpinBox = %MaxPlayers
@onready var visibility: OptionButton = %Visibility


func _ready() -> void:
	create.pressed.connect(_on_create_pressed)
	close.pressed.connect(func() -> void: closed.emit())
	Steam.lobby_created.connect(_on_lobby_created)


func _on_create_pressed() -> void:
	create.disabled = true
	var lobby_type: Steam.LobbyType = visibility.selected as Steam.LobbyType
	Steam.createLobby(lobby_type, int(max_players.value))


func _on_lobby_created(connect_status: Steam.Result, this_lobby_id: int) -> void:
	if connect_status == Steam.Result.RESULT_OK:
		print("Successfully created lobby %s" % this_lobby_id)
		SteamManager.lobby_id = this_lobby_id

		# The lobby name shows up in the lobby list.
		var lobby_name: String = "%s's Lobby" % SteamManager.username
		if not Steam.setLobbyData(this_lobby_id, "lobby_name", lobby_name):
			printerr("Failed to set the lobby name")

		# Any extra tags the host typed in, e.g. "Game:MyGame, Mode:Test".
		for this_data in lobby_data.text.split(",", false):
			var key_value: PackedStringArray = this_data.split(":", false, 1)
			if key_value.size() == 2:
				var key: String = key_value[0].strip_edges()
				var value: String = key_value[1].strip_edges()
				if key.length() > Steam.MAX_LOBBY_KEY_LENGTH:
					printerr("Lobby data key too long: %s" % key)
					continue
				if not Steam.setLobbyData(this_lobby_id, key, value):
					printerr("Failed to set lobby data [%s : %s]" % [key, value])
			else:
				printerr("Invalid lobby data, expected key:value - %s" % this_data)
	else:
		printerr("Failed to create a lobby: %s" % connect_status)
		create.disabled = false
