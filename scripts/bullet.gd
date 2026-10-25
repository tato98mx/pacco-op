class_name Bullet
extends Node2D
# Disparo en línea recta: golpea al primer fantasma o muere contra una pared.

const SPEED := 150.0
var dir := Vector2i.RIGHT

func init(d: Dictionary) -> void:
	position = d["pos"]
	dir = d["dir"]

func _ready() -> void:
	add_to_group("bullets")

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server(): return
	position += Vector2(dir) * SPEED * delta
	var m: Maze = get_tree().current_scene.maze
	if m.is_wall(m.world_to_cell(position)):
		queue_free()
		return
	for g in get_tree().get_nodes_in_group("ghosts"):
		if not g.dead and g.position.distance_to(position) < 8.0:
			g.take_hit("bullet")
			queue_free()
			return

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 2.5, Color(1, 1, 0.6))
