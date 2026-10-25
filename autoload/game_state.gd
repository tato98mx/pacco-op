extends Node
# Vidas compartidas, rescate, game over. El host decide; los clientes reciben copia.
#
# Reglas:
#  - Cada captura cuesta 1 vida compartida (el rescate es gratis).
#  - Si quedan vidas y el compañero sigue en pie: el caído deja un orbe 10 s.
#  - Sin vidas o sin compañero en pie: queda eliminado hasta el siguiente nivel.
#  - Game Over cuando NADIE queda en pie (todos caídos/eliminados).

signal game_over
signal changed

const START_LIVES := 3
const MAX_LIVES := 5
const RESCUE_TIME := 10.0
const INVULN := 2.0

var shared_lives := START_LIVES
var score := 0
var over := false
var downed := {}      # peer_id -> segundos restantes
var eliminated := {}  # peer_id -> true
var orbs := {}        # peer_id -> nodo (solo host)
var _sync_t := 0.0

func reset() -> void:
	if not multiplayer.is_server(): return
	shared_lives = START_LIVES
	score = 0
	over = false
	downed.clear()
	eliminated.clear()
	orbs.clear()
	_push()

func new_level() -> void:
	shared_lives = mini(shared_lives + 1, MAX_LIVES)
	for id in orbs:
		if is_instance_valid(orbs[id]): orbs[id].queue_free()
	downed.clear(); eliminated.clear(); orbs.clear()
	_push()

func add_score(n: int) -> void:
	if multiplayer.is_server(): score += n

func players() -> Array:
	return get_tree().get_nodes_in_group("players")

func _player(id: int):
	for p in players():
		if p.peer_id == id: return p
	return null

func _is_alive(p) -> bool:
	return not downed.has(p.peer_id) and not eliminated.has(p.peer_id)

func _partner_alive(excluded: int) -> bool:
	for p in players():
		if p.peer_id != excluded and _is_alive(p): return true
	return false

# --- Llamado por el director de fantasmas (host) ---
func on_player_caught(id: int) -> void:
	if not multiplayer.is_server() or over: return
	if downed.has(id) or eliminated.has(id): return
	var p = _player(id)
	if p == null: return
	shared_lives -= 1
	p.set_downed(true)
	if shared_lives > 0 and _partner_alive(id):
		downed[id] = RESCUE_TIME
		orbs[id] = get_tree().current_scene.spawn_entity({"kind": "orb", "owner_peer": id, "pos": p.position})
	else:
		eliminated[id] = true
	_check_game_over()
	_push()

# --- Llamado por el orbe (host) ---
func on_orb_touched(owner_id: int, rescuer_id: int) -> void:
	if not multiplayer.is_server() or over: return
	if not downed.has(owner_id) or rescuer_id == owner_id: return
	var r = _player(rescuer_id)
	if r == null or not _is_alive(r): return
	downed.erase(owner_id)
	if is_instance_valid(orbs.get(owner_id)): orbs[owner_id].queue_free()
	orbs.erase(owner_id)
	var p = _player(owner_id)
	if p: p.revive(INVULN)
	_push()

func _process(delta: float) -> void:
	if not multiplayer.is_server() or over: return
	var changed_set := false
	for id in downed.keys():
		downed[id] -= delta
		if downed[id] <= 0.0:
			downed.erase(id)
			eliminated[id] = true
			if is_instance_valid(orbs.get(id)): orbs[id].queue_free()
			orbs.erase(id)
			changed_set = true
	if changed_set:
		_check_game_over()
		_push()
	_sync_t += delta
	if _sync_t >= 0.2:
		_sync_t = 0.0
		_push()

func _check_game_over() -> void:
	var ps := players()
	if ps.is_empty(): return
	for p in ps:
		if _is_alive(p): return
	over = true
	_push()

func _push() -> void:
	_sync.rpc(shared_lives, downed, eliminated.keys(), score, over)

@rpc("authority", "call_local", "unreliable")
func _sync(lives: int, d: Dictionary, e: Array, sc: int, ov: bool) -> void:
	shared_lives = lives
	downed = d
	eliminated.clear()
	for id in e: eliminated[id] = true
	score = sc
	var was := over
	over = ov
	changed.emit()
	if over and not was: game_over.emit()
