extends CanvasLayer

## In-game menu opened with Esc: releases the mouse, lets the player rebind
## movement keys and adjust mouse sensitivity, and leave the match.

signal leave_requested

@onready var _keybinds: VBoxContainer = %Keybinds
@onready var _rebind_hint: Label = %RebindHint
@onready var _sensitivity: HSlider = %Sensitivity
@onready var _sensitivity_value: Label = %SensitivityValue
@onready var _reset: Button = %Reset
@onready var _resume: Button = %Resume
@onready var _leave: Button = %Leave

var _rebinding_action: String = ""
var _bind_buttons: Dictionary = {}


func _ready() -> void:
	add_to_group("game_menu")
	visible = false

	_sensitivity.value = Settings.mouse_sensitivity
	_update_sensitivity_label(Settings.mouse_sensitivity)
	_sensitivity.value_changed.connect(_on_sensitivity_changed)

	_reset.pressed.connect(_on_reset_pressed)
	_resume.pressed.connect(close)
	_leave.pressed.connect(func() -> void: leave_requested.emit())

	_rebuild_keybind_rows()


func open() -> void:
	_cancel_rebind()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_resume.grab_focus()


func close() -> void:
	_cancel_rebind()
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	# While open, Esc closes the menu instead of leaving the match.
	if event.is_action_pressed("ui_cancel") and visible:
		close()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if _rebinding_action.is_empty():
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	# Swallow the key so it does not also trigger menu or game actions.
	get_viewport().set_input_as_handled()

	if key_event.physical_keycode == KEY_ESCAPE or key_event.keycode == KEY_ESCAPE:
		_cancel_rebind()
		return

	var keycode: Key = key_event.physical_keycode
	if keycode == KEY_NONE:
		keycode = key_event.keycode

	Settings.set_keybind(_rebinding_action, keycode)
	_rebinding_action = ""
	_rebind_hint.visible = false
	_refresh_keybind_rows()


# region Keybind rows
func _rebuild_keybind_rows() -> void:
	for child in _keybinds.get_children():
		_keybinds.remove_child(child)
		child.queue_free()
	_bind_buttons.clear()

	for action in Settings.MOVEMENT_ACTIONS:
		var row := HBoxContainer.new()

		var name_label := Label.new()
		name_label.text = Settings.MOVEMENT_ACTIONS[action]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var bind_button := Button.new()
		bind_button.custom_minimum_size = Vector2(150, 0)
		bind_button.text = Settings.get_keybind_text(action)
		bind_button.pressed.connect(_on_bind_button_pressed.bind(action))
		row.add_child(bind_button)

		_keybinds.add_child(row)
		_bind_buttons[action] = bind_button


func _refresh_keybind_rows() -> void:
	for action in _bind_buttons:
		_bind_buttons[action].text = Settings.get_keybind_text(action)


func _on_bind_button_pressed(action: String) -> void:
	_refresh_keybind_rows()
	_rebinding_action = action
	_rebind_hint.text = "Press a key to bind \"%s\" (Esc cancels)" % Settings.MOVEMENT_ACTIONS[action]
	_rebind_hint.visible = true
	_bind_buttons[action].text = "..."


func _cancel_rebind() -> void:
	if _rebinding_action.is_empty():
		return
	_rebinding_action = ""
	_rebind_hint.visible = false
	_refresh_keybind_rows()
# endregion


# region Controls
func _on_reset_pressed() -> void:
	Settings.reset_defaults()
	_sensitivity.value = Settings.mouse_sensitivity
	_update_sensitivity_label(Settings.mouse_sensitivity)
	_cancel_rebind()
	_refresh_keybind_rows()


func _on_sensitivity_changed(value: float) -> void:
	Settings.mouse_sensitivity = value
	Settings.save_settings()
	_update_sensitivity_label(value)


func _update_sensitivity_label(value: float) -> void:
	_sensitivity_value.text = "%.1fx" % value
# endregion
