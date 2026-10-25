extends Node2D
# Escena raíz: crea laberinto, spawner multijugador, UI y controles táctiles.
# Todo se instancia por código; las entidades se replican con MultiplayerSpawner.

const PlayerS := preload("res://scripts/player.gd")
const GhostS := preload("res://scripts/ghost.gd")
const BombS := preload("res://scripts/bomb.gd")
const BulletS := preload("res://scripts/bullet.gd")
const OrbS := preload("res://scripts/soul_orb.gd")
const PickupS := preload("res://scripts/pickup.gd")
const DirectorS := preload("res://scripts/ghost_director.gd")
const UIS := preload("res://scripts/ui.gd")
const TouchS := preload("res://scripts/touch_controls.gd")

const PICKUP_RESPAWN := 20.0

var maze: Maze
var spawner: MultiplayerSpawner
var director: Node
var started := false
var match_ids: Array = []

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.02, 0.02, 0.06))
	maze = Maze.new()
	maze.name = "Maze"
	add_child(maze)
	spawner = MultiplayerSpawner.new()
	spawner.name = "Spawner"
	add_child(spawner)
	spawner.spawn_path = NodePath("..")
	spawner.spawn_function = _make
	add_child(UIS.new())
	add_child(TouchS.new())
	Network.connected.connect(_on_connected)
	multiplayer.peer_disconnected.connect(func(_id): GameState.over = true; GameState.game_over.emit())

func spawn_entity(d: Dictionary) -> Node:
	return spawner.spawn(d)

func _make(d: Dictionary) -> Node:
	var n: Node
	match d["kind"]:
		"player": n = PlayerS.new()
		"ghost": n = GhostS.new()
		"bomb": n = BombS.new()
		"bullet": n = BulletS.new()
		"orb": n = OrbS.new()
		"pickup": n = PickupS.new()
	n.init(d)
	return n

func _on_connected() -> void:
	if multiplayer.is_server():
		start_match([1] + Array(multiplayer.get_peers()))

func start_match(ids: Array) -> void:
	match_ids = ids
	GameState.reset()
	maze.reset_rpc.rpc()
	for i in ids.size():
		spawn_entity({"kind": "player", "peer": ids[i], "cell": maze.player_spawns[i % maze.player_spawns.size()]})
	for i in 4:
		spawn_entity({"kind": "ghost", "role": i, "cell": maze.ghost_spawns[i % maze.ghost_spawns.size()]})
	for c in maze.pickup_cells:
		spawn_entity({"kind": "pickup", "type": maze.pickup_cells[c], "cell": c})
	director = DirectorS.new()
	add_child(director)
	started = true

func restart() -> void:
	if not multiplayer.is_server(): return
	for g in ["players", "ghosts", "bombs", "bullets", "orbs", "pickups"]:
		for n in get_tree().get_nodes_in_group(g): n.queue_free()
	if director: director.queue_free()
	started = false
	await get_tree().process_frame
	start_match(match_ids)

func pickup_taken(cell: Vector2i, type: String) -> void:
	await get_tree().create_timer(PICKUP_RESPAWN).timeout
	if started and not GameState.over and multiplayer.is_server():
		spawn_entity({"kind": "pickup", "type": type, "cell": cell})

func _process(_d: float) -> void:
	if started and multiplayer.is_server() and not GameState.over and maze.dots.is_empty():
		_next_level()

func _next_level() -> void:
	GameState.new_level()
	maze.reset_rpc.rpc()
	for p in get_tree().get_nodes_in_group("players"): p.reset_to_spawn()
	for g in get_tree().get_nodes_in_group("ghosts"): g.reset()
	for g in ["bombs", "bullets"]:
		for n in get_tree().get_nodes_in_group(g): n.queue_free()
