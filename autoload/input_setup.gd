extends Node
# Registra las acciones de entrada por código (teclado, mando y táctil).

func _ready() -> void:
	_act("move_left",  [_key(KEY_LEFT), _key(KEY_A), _jbtn(JOY_BUTTON_DPAD_LEFT), _jaxis(JOY_AXIS_LEFT_X, -1.0)])
	_act("move_right", [_key(KEY_RIGHT), _key(KEY_D), _jbtn(JOY_BUTTON_DPAD_RIGHT), _jaxis(JOY_AXIS_LEFT_X, 1.0)])
	_act("move_up",    [_key(KEY_UP), _key(KEY_W), _jbtn(JOY_BUTTON_DPAD_UP), _jaxis(JOY_AXIS_LEFT_Y, -1.0)])
	_act("move_down",  [_key(KEY_DOWN), _key(KEY_S), _jbtn(JOY_BUTTON_DPAD_DOWN), _jaxis(JOY_AXIS_LEFT_Y, 1.0)])
	# Xbox: X / PlayStation: Cuadrado = bomba ; Xbox: A / PlayStation: X = disparo
	_act("bomb",  [_key(KEY_SPACE), _jbtn(JOY_BUTTON_X)])
	_act("shoot", [_key(KEY_Z), _jbtn(JOY_BUTTON_A)])

func _act(a: String, evs: Array) -> void:
	if not InputMap.has_action(a):
		InputMap.add_action(a, 0.5)
	for e in evs:
		InputMap.action_add_event(a, e)

func _key(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	return e

func _jbtn(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	return e

func _jaxis(ax: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = ax
	e.axis_value = v
	return e
