extends Control

@onready var create: Button = %Create
@onready var lobby_data: LineEdit = %LobbyData
@onready var max_players : SpinBox = %MaxPlayers
@onready var visibility : OptionButton = %Visibility
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	create.pressed.connect(_on_create_pressed)
	Steam.lobby_created.connect(_on_lobby_created)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_create_pressed() -> void:
	var lobby_type: Steam.LobbyType = visibility.selected as Steam.LobbyType
	Steam.createLobby(lobby_type, int(max_players.value))

func _on_lobby_created(connect_status: Steam.Result, lobby_id: int) -> void:
	if connect_status == Steam.Result.RESULT_OK:
		print("Created lobby %s" % lobby_id)
		SteamManager.lobby_id = lobby_id
		if not Steam.setLobbyData(SteamManager.lobby_id, "lobby_name", "My Examle Lobby"):
			printerr("Failed to se lobby name")
	
		var data_sets: PackedStringArray = lobby_data.text.split(",", false)
		for this_data in data_sets:
			var data_key_value:PackedStringArray = this_data.split(":", false, 1)
			if not Steam.setLobbyData(SteamManager.lobby_id, data_key_value[0], data_key_value[1]):
				printerr("Failed to set lobby data")
	else:
		printerr("Failed to create lobby: %s" % connect_status)
		
