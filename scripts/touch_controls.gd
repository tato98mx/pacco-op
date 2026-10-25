extends Node
# Controles por gestos para pantallas táctiles:
# deslizar = movimiento; doble toque = bomba; toque con dos dedos = disparo.

var layer: CanvasLayer
var hint: Label
var touch_start: Dictionary = {}
var touch_moved: Dictionary = {}
var multitouch_indices: Dictionary = {}
var two_finger_gesture := false
var two_finger_shot_queued := false
var pending_actions: Dictionary = {"bomb": 0, "shoot": 0}
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
		if e.canceled:
			_clear_touch_state()
			return
		if e.pressed:
			touch_start[e.index] = e.position
			touch_moved[e.index] = false
			if touch_start.size() >= 2:
				two_finger_gesture = true
				for index in touch_start:
					multitouch_indices[index] = true
		else:
			if not touch_start.has(e.index):
				return
			var start: Vector2 = touch_start[e.index]
			var delta := e.position - start
			if multitouch_indices.has(e.index):
				if not two_finger_shot_queued:
					_queue_action("shoot")
					two_finger_shot_queued = true
			elif delta.length() >= SWIPE_THRESHOLD:
				_apply_swipe(delta)
				touch_moved[e.index] = true
			elif not touch_moved.get(e.index, false):
				_handle_tap(e.position)
			touch_start.erase(e.index)
			touch_moved.erase(e.index)
			multitouch_indices.erase(e.index)
			if touch_start.is_empty():
				two_finger_gesture = false
				two_finger_shot_queued = false
				multitouch_indices.clear()

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if touch_start.has(drag.index) and not multitouch_indices.has(drag.index):
			var delta := drag.position - touch_start[drag.index]
			if delta.length() >= SWIPE_THRESHOLD:
				_apply_swipe(delta)
				touch_moved[drag.index] = true

	# En algunas versiones de Safari/Godot Web, el toque se entrega como ratón.
	# Si acaba de llegar un evento táctil, ignora el ratón emulado para no duplicar gestos.
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Godot marca con DEVICE_ID_EMULATION el ratón generado desde el tacto.
		# El gesto táctil ya se procesa arriba; ignora solo su duplicado emulado.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
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
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
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
		_queue_action("bomb")
		last_tap_ms = -1000
	else:
		last_tap_ms = now
		last_tap_pos = pos

func _queue_action(action: String) -> void:
	pending_actions[action] = int(pending_actions.get(action, 0)) + 1

func consume_action(action: String) -> bool:
	var count := int(pending_actions.get(action, 0))
	if count <= 0:
		return false
	pending_actions[action] = count - 1
	return true

func _clear_pending_actions() -> void:
	for action in pending_actions:
		pending_actions[action] = 0

func _clear_touch_state() -> void:
	_release_movement()
	touch_start.clear()
	touch_moved.clear()
	multitouch_indices.clear()
	two_finger_gesture = false
	two_finger_shot_queued = false
	last_tap_ms = -1000
	_clear_pending_actions()

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	in_game = scene != null and bool(scene.get("started")) and not GameState.over
	hint.visible = in_game
	if not in_game:
		_clear_touch_state()

func _release_movement() -> void:
	if swipe_action != "":
		Input.action_release(swipe_action)
		swipe_action = ""

func _exit_tree() -> void:
	_release_movement()
	_clear_pending_actions()
