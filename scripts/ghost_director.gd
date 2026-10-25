class_name GhostDirector
extends Node
# Coordina a los fantasmas (solo host): cada rol persigue algo distinto
# para acorralar, y detecta capturas.
#  CHASER   -> el jugador más cercano
#  AMBUSHER -> 4 casillas por delante de ese jugador (pinza con el chaser)
#  FLANKER  -> el OTRO jugador (separa al dúo); en solitario, por detrás
#  BLOCKER  -> acampa sobre el orbe de rescate; si no hay, corta el paso entre jugadores

const CATCH_DIST := 9.0
var _t := 0.0

func _physics_process(delta: float) -> void:
	if GameState.over: return
	_t -= delta
	if _t <= 0.0:
		_t = 0.2
		_retarget()
	_check_catches()

func _alive_players() -> Array:
	var out := []
	for p in get_tree().get_nodes_in_group("players"):
		if not p.is_downed and not GameState.eliminated.has(p.peer_id): out.append(p)
	return out

func _nearest(ps: Array, pos: Vector2):
	var best = null
	var bd := INF
	for p in ps:
		var d: float = p.position.distance_to(pos)
		if d < bd:
			bd = d
			best = p
	return best

func _retarget() -> void:
	var m: Maze = get_tree().current_scene.maze
	var ps := _alive_players()
	var orbs := get_tree().get_nodes_in_group("orbs")
	var ghosts := get_tree().get_nodes_in_group("ghosts")
	var chaser = null
	for g in ghosts:
		if g.role == Ghost.Role.CHASER: chaser = g
	for g in ghosts:
		if g.dead: continue
		if ps.is_empty():
			g.target_cell = g.spawn_cell
			continue
		var near = _nearest(ps, g.position)
		var t: Vector2i = near.cell
		match g.role:
			Ghost.Role.AMBUSHER:
				t = near.cell + near.facing * 4
			Ghost.Role.FLANKER:
				if ps.size() > 1 and chaser != null:
					var main_target = _nearest(ps, chaser.position)
					for p in ps:
						if p != main_target: t = p.cell
				else:
					t = near.cell - near.facing * 4
			Ghost.Role.BLOCKER:
				if not orbs.is_empty():
					t = m.world_to_cell(orbs[0].position)
				elif ps.size() > 1:
					t = m.world_to_cell((ps[0].position + ps[1].position) * 0.5)
				else:
					t = near.cell + near.facing * 6
		g.target_cell = m.nearest_open(t)

func _check_catches() -> void:
	for g in get_tree().get_nodes_in_group("ghosts"):
		if g.dead or g.release_t > 0.0: continue
		for p in get_tree().get_nodes_in_group("players"):
			if p.is_downed or p.invuln or GameState.eliminated.has(p.peer_id): continue
			if g.position.distance_to(p.position) < CATCH_DIST:
				GameState.on_player_caught(p.peer_id)
