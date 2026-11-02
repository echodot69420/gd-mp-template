extends Node3D

const MANAGER_SCENE := "res://scenes/SteamLobbyManager/SteamLobbyManager.tscn"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Leaving the match also closes it down for the lobby host.
		SteamManager.leave_lobby()
		get_tree().change_scene_to_file(MANAGER_SCENE)
