extends Node

## Central place for user settings: movement keybinds and mouse sensitivity.
## Applies defaults on startup, then overrides them with the saved file.

const SAVE_PATH := "user://settings.cfg"

## Movement actions shown in the menu, in display order.
const MOVEMENT_ACTIONS := {
	"move_forward": "Move Forward",
	"move_back": "Move Back",
	"move_left": "Move Left",
	"move_right": "Move Right",
	"jump": "Jump",
}

## Default bindings: WASD for movement, Space to jump.
const DEFAULT_KEYS := {
	"move_forward": KEY_W,
	"move_back": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"jump": KEY_SPACE,
}

const DEFAULT_SENSITIVITY := 1.0

## Radians of rotation per pixel of mouse movement at 1.0x sensitivity.
const LOOK_SCALE := 0.002

var mouse_sensitivity: float = DEFAULT_SENSITIVITY


func _ready() -> void:
	_apply_defaults()
	load_settings()


func look_scale() -> float:
	return LOOK_SCALE * mouse_sensitivity


# region Keybinds
func get_keybind(action: String) -> InputEventKey:
	if not InputMap.has_action(action):
		return null
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event as InputEventKey
	return null


func get_keybind_text(action: String) -> String:
	var event := get_keybind(action)
	if event == null:
		return "Unbound"
	return event.as_text_physical_keycode()


func set_keybind(action: String, keycode: Key) -> void:
	# Keep bindings unique: swap with any action already using this key.
	for other in DEFAULT_KEYS:
		if other == action:
			continue
		var other_key := get_keybind(other)
		if other_key == null or other_key.physical_keycode != keycode:
			continue
		var previous := get_keybind(action)
		if previous != null:
			_set_key(other, previous.physical_keycode)
		else:
			InputMap.action_erase_events(other)

	_set_key(action, keycode)
	save_settings()


func reset_defaults() -> void:
	_apply_defaults()
	save_settings()


func _apply_defaults() -> void:
	for action in DEFAULT_KEYS:
		_set_key(action, DEFAULT_KEYS[action])
	mouse_sensitivity = DEFAULT_SENSITIVITY


func _set_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
# endregion


# region Persistence
func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	for action in DEFAULT_KEYS:
		var event := get_keybind(action)
		if event != null:
			config.set_value("controls", action, event.physical_keycode)
	if config.save(SAVE_PATH) != OK:
		printerr("Failed to save settings to %s" % SAVE_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return

	mouse_sensitivity = float(config.get_value(
		"controls", "mouse_sensitivity", DEFAULT_SENSITIVITY))
	for action in DEFAULT_KEYS:
		if config.has_section_key("controls", action):
			_set_key(action, config.get_value("controls", action))
# endregion
