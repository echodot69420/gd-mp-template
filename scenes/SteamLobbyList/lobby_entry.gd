extends HBoxContainer

signal joining_lobby(lobby_id: int)

## Set by the lobby list before the entry is added to the scene.
var lobby_id: int = 0

@onready var name_label: Label = %Name
@onready var join: Button = %Join


func _ready() -> void:
	var lobby_name: String = Steam.getLobbyData(lobby_id, "lobby_name")
	if lobby_name.is_empty():
		name_label.text = "Lobby %s" % lobby_id
	else:
		name_label.text = "%s  -  %s" % [lobby_name, lobby_id]

	join.pressed.connect(func() -> void: joining_lobby.emit(lobby_id))
