extends Node
## Registra las acciones de input por defecto al arrancar.
## Cuando exista un sistema de Settings/rebinding, esto será el fallback.

func _ready() -> void:
	_add_key(&"move_forward", KEY_W)
	_add_key(&"move_back", KEY_S)
	_add_key(&"move_left", KEY_A)
	_add_key(&"move_right", KEY_D)
	_add_key(&"jump", KEY_SPACE)
	_add_key(&"sprint", KEY_SHIFT)
	_add_key(&"crouch", KEY_CTRL)
	_add_key(&"reload", KEY_R)
	_add_key(&"zoom_reset", KEY_X)
	_add_key(&"throw_grenade", KEY_G)
	_add_key(&"throw_smoke", KEY_T)
	_add_key(&"throw_flash", KEY_F)
	_add_key(&"quick_melee", KEY_V)
	_add_mouse(&"fire", MOUSE_BUTTON_LEFT)
	_add_mouse(&"aim", MOUSE_BUTTON_RIGHT)


func _add_key(action: StringName, physical_keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = physical_keycode
	InputMap.action_add_event(action, ev)


func _add_mouse(action: StringName, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
