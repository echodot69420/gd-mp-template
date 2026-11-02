extends Control

signal closed

const LOBBY_ENTRY := preload("res://scenes/SteamLobbyList/lobby_entry.tscn")

@onready var _distance: OptionButton = %Distance
@onready var _lobby_filters: Control = %LobbyFilters
@onready var _max_lobbies: SpinBox = %MaxLobbies
@onready var _open_slots: SpinBox = %OpenSlots
@onready var _search_terms: LineEdit = %SearchTerms
@onready var _lobby_list: VBoxContainer = %LobbyList


func _ready() -> void:
	%Filters.toggled.connect(_on_filters_toggled)
	%Refresh.pressed.connect(_on_refresh_pressed)
	%Close.pressed.connect(func() -> void: closed.emit())
	Steam.lobby_match_list.connect(_on_lobby_match_list)


func _on_filters_toggled(show_filters: bool) -> void:
	_lobby_filters.visible = show_filters


func _on_refresh_pressed() -> void:
	for entry in _lobby_list.get_children():
		_lobby_list.remove_child(entry)
		entry.free()

	_add_request_lobby_filters()
	Steam.requestLobbyList()


func _add_request_lobby_filters() -> void:
	Steam.addRequestLobbyListDistanceFilter(_distance.selected as Steam.LobbyDistanceFilter)
	if _open_slots.value > 0:
		Steam.addRequestLobbyListFilterSlotsAvailable(int(_open_slots.value))
	Steam.addRequestLobbyListResultCountFilter(int(_max_lobbies.value))

	for term in _search_terms.text.split(",", false):
		var key_value: PackedStringArray = term.split(":", false, 1)
		if key_value.size() != 2:
			printerr("Invalid search term, expected key:value - %s" % term)
			continue
		var key: String = key_value[0].strip_edges()
		if key.length() > Steam.MAX_LOBBY_KEY_LENGTH:
			printerr("Search term key too long: %s" % key)
			continue
		Steam.addRequestLobbyListStringFilter(key, key_value[1].strip_edges(), Steam.LOBBY_COMPARISON_EQUAL)


func _on_lobby_match_list(lobbies: Array) -> void:
	if lobbies.size() == 0:
		print("No lobbies were found")
		return

	for this_lobby in lobbies:
		var entry = LOBBY_ENTRY.instantiate()
		entry.lobby_id = this_lobby
		entry.joining_lobby.connect(_on_joining_lobby)
		_lobby_list.call_deferred("add_child", entry)


func _on_joining_lobby(this_lobby_id: int) -> void:
	print("Attempting to join lobby %s from the lobby list" % this_lobby_id)
	Steam.joinLobby(this_lobby_id)
