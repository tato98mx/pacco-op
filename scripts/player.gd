class_name Player
extends Node2D
# Movimiento por casillas. El host simula; los clientes mandan su dirección.

const SPEED := 70.0
const MAX_AMMO := 2
const BOMB_DELAY := 2.5

var peer_id := 1
var spawn_cell := Vector2i.ONE
var cell := Vector2i.ONE
var next_cell := Vector2i.ONE
var moving := false
var move_dir := Vector2i.ZERO
var want_dir := Vector2i.ZERO
var facing := Vector2i.RIGHT
var is_downed := false
var invuln := false
var invuln_t := 0.0
var ammo := 0
var has_bomb := false
var _last_sent := Vector2i.ZERO

func init(d: Dictionary) -> void:
	peer_id = d["peer"]
	spawn_cell = d["cell"]

func _ready() -> void:
	add_to_group("players")
	cell = spawn_cell
	position = _maze().cell_to_world(cell)
	SyncUtil.attach(self, ["position", "is_downed", "ammo", "has_bomb", "invuln", "facing"])

func _maze() -> Maze:
	return get_tree().current_scene.maze

func _read_dir() -> Vector2i:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v.length() < 0.5: return Vector2i.ZERO
	if absf(v.x) > absf(v.y): return Vector2i(int(signf(v.x)), 0)
	return Vector2i(0, int(signf(v.y)))

func _physics_process(delta: float) -> void:
	if peer_id == multiplayer.get_unique_id() and not is_downed and not GameState.over:
		var d := _read_dir()
		if multiplayer.is_server():
			if d != Vector2i.ZERO: want_dir = d
		elif d != Vector2i.ZERO and d != _last_sent:
			_last_sent = d
			submit_dir.rpc_id(1, d)

		# Consume las solicitudes táctiles aunque también haya una entrada física.
		var scene := get_tree().current_scene
		var controls: Node = scene.get_node_or_null("TouchControls") if scene != null else null
		var touch_bomb := controls != null and controls.consume_action("bomb")
		var touch_shoot := controls != null and controls.consume_action("shoot")
		if Input.is_action_just_pressed("bomb") or touch_bomb:
			if multiplayer.is_server():
				request_bomb()
			else:
				request_bomb.rpc_id(1)
		if Input.is_action_just_pressed("shoot") or touch_shoot:
			if multiplayer.is_server():
				request_shoot()
			else:
				request_shoot.rpc_id(1)
	if multiplayer.is_server(): _simulate(delta)

@rpc("any_peer", "call_remote", "reliable")
func submit_dir(d: Vector2i) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == peer_id:
		want_dir = d

func _simulate(delta: float) -> void:
	if invuln_t > 0.0:
		invuln_t -= delta
		invuln = invuln_t > 0.0
	if is_downed or GameState.over: return
	var m := _maze()
	if moving and want_dir != Vector2i.ZERO and want_dir == -move_dir:
		var t := cell
		cell = next_cell
		next_cell = t
		move_dir = want_dir
		facing = move_dir
	var budget := SPEED * delta
	while budget > 0.0:
		if not moving:
			_choose(m)
			if not moving: break
		var tgt := m.cell_to_world(next_cell)
		var dist := position.distance_to(tgt)
		if dist <= budget:
			position = tgt
			budget -= dist
			cell = next_cell
			moving = false
			_arrive(m)
		else:
			position += (tgt - position).normalized() * budget
			budget = 0.0

func _choose(m: Maze) -> void:
	if want_dir != Vector2i.ZERO and not m.is_wall(cell + want_dir):
		move_dir = want_dir
	elif move_dir == Vector2i.ZERO or m.is_wall(cell + move_dir):
		move_dir = Vector2i.ZERO
		return
	facing = move_dir
	next_cell = cell + move_dir
	moving = true

func _arrive(m: Maze) -> void:
	if m.dots.has(cell):
		m.eat.rpc(cell)
		GameState.add_score(10)

# ---- Power-ups (solo host) ----
func collect(type: String) -> void:
	match type:
		"bomb": has_bomb = true
		"gun": ammo = MAX_AMMO

func _sender_ok() -> bool:
	var s := multiplayer.get_remote_sender_id()
	return multiplayer.is_server() and (s == 0 or s == peer_id)

@rpc("any_peer", "call_local", "reliable")
func request_bomb() -> void:
	if not _sender_ok() or not has_bomb or is_downed or GameState.over: return
	has_bomb = false
	get_tree().current_scene.spawn_entity({"kind": "bomb", "pos": position, "fuse": BOMB_DELAY})

@rpc("any_peer", "call_local", "reliable")
func request_shoot() -> void:
	if not _sender_ok() or ammo <= 0 or is_downed or GameState.over: return
	ammo -= 1
	get_tree().current_scene.spawn_entity({"kind": "bullet", "pos": position, "dir": facing, "owner_peer": peer_id})

# ---- Estados (solo host) ----
func set_downed(b: bool) -> void:
	is_downed = b
	moving = false
	want_dir = Vector2i.ZERO
	move_dir = Vector2i.ZERO

func revive(inv_time: float) -> void:
	is_downed = false
	invuln_t = inv_time
	invuln = true

func reset_to_spawn() -> void:
	set_downed(false)
	cell = spawn_cell
	position = _maze().cell_to_world(cell)
	invuln_t = GameState.INVULN
	invuln = true

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	if is_downed: return
	var col := Color(1, 0.85, 0) if peer_id == 1 else Color(0.4, 0.9, 1)
	if invuln and int(Time.get_ticks_msec() / 120) % 2 == 0: col.a = 0.35
	draw_circle(Vector2.ZERO, 6.5, col)
	var f := Vector2(facing)
	draw_circle(f * 3.0 + Vector2(-f.y, f.x) * 2.5, 1.2, Color.BLACK)
	if has_bomb: draw_circle(Vector2(5, -6), 2.5, Color(1, 0.3, 0.2))
	for i in ammo: draw_rect(Rect2(-6 + i * 4, 7, 3, 3), Color(0.9, 0.9, 0.9))
