class_name Bomb
extends Node2D
# Bomba de tóner: explota tras `fuse` segundos. El radio sigue los pasillos (no cruza paredes).

const RADIUS_TILES := 2

var fuse := 2.5
var time_left := 2.5
var exploded := false

func init(d: Dictionary) -> void:
	position = d["pos"]
	fuse = d["fuse"]
	time_left = fuse

func _ready() -> void:
	add_to_group("bombs")

func _physics_process(delta: float) -> void:
	if exploded:
		if multiplayer.is_server():
			time_left -= delta
			if time_left < -0.35: queue_free()
		return
	time_left -= delta
	if multiplayer.is_server() and time_left <= 0.0:
		_explode()

func _explode() -> void:
	var m: Maze = get_tree().current_scene.maze
	var bc := m.world_to_cell(position)
	for g in get_tree().get_nodes_in_group("ghosts"):
		if g.dead: continue
		if m.path(g.cell, bc).size() <= RADIUS_TILES + 1:
			g.take_hit("bomb")
	flash.rpc()

@rpc("authority", "call_local", "reliable")
func flash() -> void:
	exploded = true
	remove_from_group("bombs")

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	if exploded:
		draw_circle(Vector2.ZERO, RADIUS_TILES * Maze.TILE + 6, Color(1, 0.5, 0.1, 0.45))
		return
	var blink := time_left < 1.0 and int(time_left * 8) % 2 == 0
	draw_circle(Vector2.ZERO, 5.0, Color(1, 1, 1) if blink else Color(0.15, 0.15, 0.15))
	draw_circle(Vector2(0, -6), 1.5, Color(1, 0.4, 0.1))
