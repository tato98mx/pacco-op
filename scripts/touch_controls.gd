extends Node
# Controles táctiles responsivos: visibles únicamente durante una partida.

var layer: CanvasLayer
var panel: Control
var active_actions: Array[String] = []

func _ready() -> void:
	layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(panel)

	# Cruceta en la esquina inferior izquierda, relativa al tamaño real de la pantalla.
	_add_button("↑", 18, -150, 66, -102, "move_up", false)
	_add_button("←", 0, -100, 48, -52, "move_left", false)
	_add_button("↓", 52, -100, 100, -52, "move_down", false)
	_add_button("→", 104, -100, 152, -52, "move_right", false)

	# Acciones en la esquina inferior derecha.
	_add_button("DISPARO", -118, -150, -8, -102, "shoot", true)
	_add_button("BOMBA", -118, -98, -8, -50, "bomb", true)

func _add_button(label: String, left: float, top: float, right: float, bottom: float, action: String, from_right: bool) -> void:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 14 if label.length() > 1 else 24)
	button.anchor_left = 1.0 if from_right else 0.0
	button.anchor_right = 1.0 if from_right else 0.0
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = left
	button.offset_top = top
	button.offset_right = right
	button.offset_bottom = bottom
	panel.add_child(button)

	button.button_down.connect(func():
		if not active_actions.has(action):
			active_actions.append(action)
		Input.action_press(action)
	)
	button.button_up.connect(func():
		Input.action_release(action)
		active_actions.erase(action)
	)

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	var in_game := scene != null and bool(scene.get("started"))
	panel.visible = in_game
	if not in_game:
		_release_all()

func _release_all() -> void:
	for action in active_actions:
		Input.action_release(action)
	active_actions.clear()

func _exit_tree() -> void:
	_release_all()
