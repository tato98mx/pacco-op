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

	_add_action_button("↑", Vector2(70, 476), Vector2(48, 48), "move_up")
	_add_action_button("←", Vector2(18, 524), Vector2(48, 48), "move_left")
	_add_action_button("↓", Vector2(70, 524), Vector2(48, 48), "move_down")
	_add_action_button("→", Vector2(122, 524), Vector2(48, 48), "move_right")
	_add_action_button("DISPARO", Vector2(254, 472), Vector2(92, 46), "shoot")
	_add_action_button("BOMBA", Vector2(254, 524), Vector2(92, 46), "bomb")

func _add_action_button(label: String, pos: Vector2, button_size: Vector2, action: String) -> void:
	var button := Button.new()
	button.text = label
	button.position = pos
	button.size = button_size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 16 if label.length() > 1 else 24)
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
	var scene = get_tree().current_scene
	var should_show := scene != null and scene.get("started") == true
	panel.visible = should_show
	if not should_show:
		_release_all()

func _release_all() -> void:
	for action in active_actions:
		Input.action_release(action)
	active_actions.clear()

func _exit_tree() -> void:
	_release_all()
