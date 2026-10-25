class_name Ghost
extends Node2D
# Fantasma con movimiento por casillas. Sólo el host simula.
# Habilidades: esquiva balas (con cooldown), huye de bombas a punto de explotar,
# y el BLOQUEADOR tiene un escudo que absorbe 1 disparo y se recarga.

enum Role { CHASER, AMBUSHER, FLANKER, BLOCKER }
const COLORS := [Color(1, 0.2, 0.2), Color(1, 0.55, 0.85), Color(0.2, 0.9, 0.95), Color(1, 0.65, 0.2)]
const SPEED := 52.0
const DODGE_CD := 4.0
const SHIELD_CD := 12.0
const RESPAWN := 8.0
const BOMB_FEAR := 1.6

var role := 0
var spawn_cell := Vector2i.ONE
var cell := Vector2i.ONE
var next_cell := Vector2i.ONE
var moving := false
var target_cell := Vector2i.ONE
var dead := false
var shielded := false
var release_t := 0.0
var respawn_t := 0.0
var dodge_t := 0.0
var shield_t := 0.0

func init(d: Dictionary) -> void:
	role = d["role"]
	spawn_cell = d["cell"]

func _ready() -> void:
	add_to_group("ghosts")
	reset()
	SyncUtil.attach(self, ["position", "dead", "shielded"])

func _maze() -> Maze:
	return get_tree().current_scene.maze

func reset() -> void:
	cell = spawn_cell
	next_cell = cell
	target_cell = cell
	moving = false
	dead = false
	shielded = (role == Role.BLOCKER)
	release_t = 1.5 + role * 2.0
	position = _maze().cell_to_world(cell)

# Devuelve true si el golpe mató al fantasma.
func take_hit(source: String = "bullet") -> bool:
	if dead: return false
	if shielded and source == "bullet":
		shielded = false
		shield_t = SHIELD_CD
		return false
	dead = true
	respawn_t = RESPAWN
	GameState.add_score(200)
	return true

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server(): return
	if dead:
		respawn_t -= delta
		if respawn_t <= 0.0: reset()
		return
	if GameState.over: return
	dodge_t = maxf(0.0, dodge_t - delta)
	if role == Role.BLOCKER and not shielded:
		shield_t -= delta
		if shield_t <= 0.0: shielded = true
	if release_t > 0.0:
		release_t -= delta
		return
	var m := _maze()
	var budget := SPEED * delta
	while budget > 0.0:
		if not moving:
			_decide(m)
			if not moving: break
		var tgt := m.cell_to_world(next_cell)
		var dist := position.distance_to(tgt)
		if dist <= budget:
			position = tgt
			budget -= dist
			cell = next_cell
			moving = false
		else:
			position += (tgt - position).normalized() * budget
			budget = 0.0

func _decide(m: Maze) -> void:
	var nxt := cell
	var threat = _bomb_threat(m)
	if threat != null:
		nxt = _flee(m, threat)
	else:
		var dodge := _dodge(m)
		if dodge != cell:
			nxt = dodge
		else:
			var p := m.path(cell, target_cell)
			if p.size() > 1: nxt = p[1]
	if nxt != cell:
		next_cell = nxt
		moving = true

func _bomb_threat(m: Maze):
	for b in get_tree().get_nodes_in_group("bombs"):
		if b.time_left < BOMB_FEAR:
			var bc := m.world_to_cell(b.position)
			if m.path(cell, bc).size() <= Bomb.RADIUS_TILES + 2:
				return bc
	return null

func _flee(m: Maze, from: Vector2i) -> Vector2i:
	var best := cell
	var best_d := m.path(cell, from).size()
	for n in m.open_neighbors(cell):
		var d := m.path(n, from).size()
		if d > best_d:
			best_d = d
			best = n
	return best

func _dodge(m: Maze) -> Vector2i:
	if dodge_t > 0.0: return cell
	for b in get_tree().get_nodes_in_group("bullets"):
		var bc := m.world_to_cell(b.position)
		var d: Vector2i = b.dir
		var rel := cell - bc
		var incoming := false
		if d.x != 0 and bc.y == cell.y and rel.x * d.x > 0 and absi(rel.x) <= 5: incoming = true
		if d.y != 0 and bc.x == cell.x and rel.y * d.y > 0 and absi(rel.y) <= 5: incoming = true
		if not incoming: continue
		var perp := Vector2i(absi(d.y), absi(d.x))
		for side in [perp, -perp]:
			if not m.is_wall(cell + side):
				dodge_t = DODGE_CD
				return cell + side
	return cell

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	if dead: return
	var col: Color = COLORS[role % 4]
	draw_circle(Vector2(0, -1), 6.5, col)
	draw_rect(Rect2(-6.5, -1, 13, 7), col)
	draw_circle(Vector2(-2.5, -2), 1.8, Color.WHITE)
	draw_circle(Vector2(2.5, -2), 1.8, Color.WHITE)
	if shielded:
		draw_arc(Vector2.ZERO, 9.0, 0, TAU, 20, Color(0.7, 0.9, 1), 1.5)
