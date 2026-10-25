class_name Maze
extends Node2D

const TILE := 16
const ORIGIN := Vector2(12, 60)
# # pared, . punto, P spawn jugador, G spawn fantasma, b esfera bomba, g esfera disparo
const LAYOUT := [
	"#####################",
	"#.........#.........#",
	"#.###.###.#.###.###.#",
	"#.......#...#.......#",
	"#.###.#.#####.#.###.#",
	"#.....#...#...#.....#",
	"#####.###.#.###.#####",
	"#.....#..GGGG.#.....#",
	"#####.###.#.###.#####",
	"#.....#...#...#.....#",
	"#.###.#.#####.#.###.#",
	"#b...#.........#...g#",
	"#.##.#####.#####.##.#",
	"#P.................P#",
	"#####################",
]

var dims := Vector2i.ZERO
var walls := {}
var dots := {}
var player_spawns: Array[Vector2i] = []
var ghost_spawns: Array[Vector2i] = []
var pickup_cells := {}
var astar := AStarGrid2D.new()

func _ready() -> void:
	dims = Vector2i(LAYOUT[0].length(), LAYOUT.size())
	for y in dims.y:
		for x in dims.x:
			var c := Vector2i(x, y)
			match LAYOUT[y][x]:
				"#": walls[c] = true
				"P": player_spawns.append(c)
				"G": ghost_spawns.append(c)
				"b": pickup_cells[c] = "bomb"
				"g": pickup_cells[c] = "gun"
	astar.region = Rect2i(Vector2i.ZERO, dims)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for c in walls:
		astar.set_point_solid(c, true)
	reset()

func reset() -> void:
	dots.clear()
	for y in dims.y:
		for x in dims.x:
			if LAYOUT[y][x] == ".":
				dots[Vector2i(x, y)] = true
	queue_redraw()

@rpc("authority", "call_local", "reliable")
func reset_rpc() -> void:
	reset()

@rpc("authority", "call_local", "reliable")
func eat(c: Vector2i) -> void:
	dots.erase(c)
	queue_redraw()

func is_wall(c: Vector2i) -> bool:
	return walls.has(c) or c.x < 0 or c.y < 0 or c.x >= dims.x or c.y >= dims.y

func cell_to_world(c: Vector2i) -> Vector2:
	return ORIGIN + Vector2(c) * TILE + Vector2(TILE, TILE) * 0.5

func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(((p - ORIGIN) / TILE).floor())

func path(a: Vector2i, b: Vector2i) -> Array:
	if is_wall(a) or is_wall(b): return []
	return astar.get_id_path(a, b)

func nearest_open(c: Vector2i) -> Vector2i:
	c = c.clamp(Vector2i.ZERO, dims - Vector2i.ONE)
	for r in range(0, 8):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r: continue
				var n := c + Vector2i(dx, dy)
				if not is_wall(n): return n
	return c

func open_neighbors(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if not is_wall(c + d): out.append(c + d)
	return out

func _draw() -> void:
	draw_rect(Rect2(ORIGIN, Vector2(dims) * TILE), Color(0.03, 0.03, 0.1))
	for c in walls:
		draw_rect(Rect2(ORIGIN + Vector2(c) * TILE + Vector2.ONE, Vector2(TILE - 2, TILE - 2)), Color(0.15, 0.25, 0.85))
	for c in dots:
		draw_circle(cell_to_world(c), 1.8, Color(1, 0.9, 0.7))
