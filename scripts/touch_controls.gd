extends Node
# Controles táctiles visibles para iPhone: cruceta y botones de acción.

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

	_add_bottom_button("↑", 20, -158, 68, -110, "move_up")
	_add_bottom_button("←", 0, -110, 48, -62, "move_left")
	_add_bottom_button("↓", 52, -110, 100, -62, "move_down")
	_add_bottom_button("→", 104, -110, 152, -62, "move_right")
	_add_bottom_button("DISPARO", -112, -158, -12, -110, "shoot", true)
	_add_bottom_button("BOMBA", -112, -106, -12, -58, "bomb", true)

func _add_bottom_button(label: String, left: float, top: float, right: float, bottom: float, action: String, from_right: bool = false) -> void:
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
	# Keep the controls visible; the previous scene-property check hid them in Safari.
	panel.visible = true

func _release_all() -> void:
	for action in active_actions:
		Input.action_release(action)
	active_actions.clear()

func _exit_tree() -> void:
	_release_all()
