class_name Pickup
extends Node2D
# Esfera de power-up ("bomb" o "gun"). Reaparece 20 s después de recogerla.

var type := "bomb"
var cell := Vector2i.ONE

func init(d: Dictionary) -> void:
	type = d["type"]
	cell = d["cell"]

func _ready() -> void:
	add_to_group("pickups")
	position = get_tree().current_scene.maze.cell_to_world(cell)

func _physics_process(_d: float) -> void:
	if not multiplayer.is_server(): return
	for p in get_tree().get_nodes_in_group("players"):
		if p.is_downed: continue
		if p.position.distance_to(position) < 9.0:
			p.collect(type)
			get_tree().current_scene.pickup_taken(cell, type)
			queue_free()
			return

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	var col := Color(1, 0.35, 0.25) if type == "bomb" else Color(0.5, 1, 0.4)
	var pulse := 1.0 + 0.15 * sin(Time.get_ticks_msec() / 200.0)
	draw_circle(Vector2.ZERO, 5.5 * pulse, col)
	draw_arc(Vector2.ZERO, 7.5, 0, TAU, 16, col, 1.0)
