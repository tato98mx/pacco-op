extends Node
# Controles por gestos para pantallas táctiles:
# deslizar = movimiento; doble toque = bomba; toque con dos dedos = disparo.

var layer: CanvasLayer
var hint: Label
var touch_start: Dictionary = {}
var touch_moved: Dictionary = {}
var two_finger_gesture := false
var swipe_action := ""
var last_tap_ms := -1000
var last_tap_pos := Vector2.ZERO
var in_game := false

const SWIPE_THRESHOLD := 26.0
const DOUBLE_TAP_MS := 330
const DOUBLE_TAP_DISTANCE := 70.0

func _ready() -> void:
	layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	hint = Label.new()
	hint.text = "Desliza para moverte · Doble toque: bomba · Dos dedos: disparo"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.anchor_left = 0.05
	hint.anchor_right = 0.95
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -46
	hint.offset_bottom = -8
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.85, 0.88, 1.0, 0.9))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hint)

func _input(event: InputEvent) -> void:
	if not in_game:
		return

	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			touch_start[e.index] = e.position
			touch_moved[e.index] = false
			if touch_start.size() >= 2:
				two_finger_gesture = true
		else:
			if not touch_start.has(e.index):
				return
			var start: Vector2 = touch_start[e.index]
			var delta := e.position - start
			if delta.length() >= SWIPE_THRESHOLD:
				_apply_swipe(delta)
				touch_moved[e.index] = true
			elif two_finger_gesture and touch_start.size() >= 2:
				_pulse_action("shoot")
			elif not touch_moved.get(e.index, false):
				_handle_tap(e.position)
			touch_start.erase(e.index)
			touch_moved.erase(e.index)
			if touch_start.is_empty():
				two_finger_gesture = false

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if touch_start.has(drag.index):
			var delta := drag.position - touch_start[drag.index]
			if delta.length() >= SWIPE_THRESHOLD:
				_apply_swipe(delta)
				touch_moved[drag.index] = true

	# En algunas versiones de Safari/Godot Web, el toque se entrega como ratón.
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			touch_start[-1] = event.position
			touch_moved[-1] = false
		elif touch_start.has(-1):
			var start: Vector2 = touch_start[-1]
			var delta := event.position - start
			if delta.length() >= SWIPE_THRESHOLD:
				_apply_swipe(delta)
			elif not touch_moved.get(-1, false):
				_handle_tap(event.position)
			touch_start.erase(-1)
			touch_moved.erase(-1)

	elif event is InputEventMouseMotion and touch_start.has(-1) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var delta := event.position - touch_start[-1]
		if delta.length() >= SWIPE_THRESHOLD:
			_apply_swipe(delta)
			touch_moved[-1] = true

func _apply_swipe(delta: Vector2) -> void:
	var action: String
	if absf(delta.x) > absf(delta.y):
		action = "move_right" if delta.x > 0 else "move_left"
	else:
		action = "move_down" if delta.y > 0 else "move_up"
	if swipe_action != action:
		if swipe_action != "":
			Input.action_release(swipe_action)
		Input.action_press(action)
		swipe_action = action

func _handle_tap(pos: Vector2) -> void:
	var now := Time.get_ticks_msec()
	if now - last_tap_ms <= DOUBLE_TAP_MS and pos.distance_to(last_tap_pos) <= DOUBLE_TAP_DISTANCE:
		_pulse_action("bomb")
		last_tap_ms = -1000
	else:
		last_tap_ms = now
		last_tap_pos = pos

func _pulse_action(action: String) -> void:
	Input.action_press(action)
	await get_tree().process_frame
	Input.action_release(action)

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	in_game = scene != null and bool(scene.get("started"))
	hint.visible = in_game
	if not in_game:
		_release_movement()

func _release_movement() -> void:
	if swipe_action != "":
		Input.action_release(swipe_action)
		swipe_action = ""

func _exit_tree() -> void:
	_release_movement()
