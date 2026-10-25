extends Node
# Swipe = dirección | doble toque = bomba | toque con dos dedos = disparo

var starts := {}
var multi := false
var suppress := false
var last_tap := -10.0

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			starts[e.index] = e.position
			if starts.size() >= 2: multi = true
		else:
			var s: Vector2 = starts.get(e.index, e.position)
			starts.erase(e.index)
			var tap := e.position.distance_to(s) < 12.0
			if tap and not suppress:
				if multi:
					_fire("shoot")
					suppress = true
				else:
					var now := Time.get_ticks_msec() / 1000.0
					if now - last_tap < 0.3:
						_fire("bomb")
						last_tap = -10.0
					else:
						last_tap = now
			if starts.is_empty():
				multi = false
				suppress = false
	elif e is InputEventScreenDrag:
		if not starts.has(e.index): return
		var d: Vector2 = e.position - starts[e.index]
		if d.length() > 24.0:
			var a := ""
			if absf(d.x) > absf(d.y): a = "move_right" if d.x > 0 else "move_left"
			else: a = "move_down" if d.y > 0 else "move_up"
			_fire(a)
			starts[e.index] = e.position

func _fire(a: String) -> void:
	Input.action_press(a)
	get_tree().create_timer(0.1).timeout.connect(func(): Input.action_release(a))
