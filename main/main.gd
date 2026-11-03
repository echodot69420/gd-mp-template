extends Node3D

const MANAGER_SCENE := "res://scenes/SteamLobbyManager/SteamLobbyManager.tscn"

@onready var _pause_menu = $UI/PauseMenu


func _ready() -> void:
	# The mouse is captured as soon as we spawn in so the camera can look around.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_pause_menu.leave_requested.connect(_leave_match)


func _exit_tree() -> void:
	# Never leave the mouse captured after leaving the match.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	# The menu consumes Esc while it is open (closing itself), so reaching this
	# point means the menu is closed and should be opened instead.
	if event.is_action_pressed("ui_cancel"):
		_pause_menu.open()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		# Clicking the world grabs the mouse again if it was ever released.
		if not _pause_menu.visible and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _leave_match() -> void:
	# Leaving the match also closes it down for the lobby host.
	SteamManager.leave_lobby()
	get_tree().change_scene_to_file(MANAGER_SCENE)
