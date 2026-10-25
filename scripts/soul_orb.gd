class_name SoulOrb
extends Node2D
# Orbe de alma: el compañero lo toca para revivir al caído (ventana de 10 s en GameState).

var owner_peer := 0

func init(d: Dictionary) -> void:
	owner_peer = d["owner_peer"]
	position = d["pos"]

func _ready() -> void:
	add_to_group("orbs")

func _physics_process(_d: float) -> void:
	if not multiplayer.is_server(): return
	for p in get_tree().get_nodes_in_group("players"):
		if p.peer_id != owner_peer and not p.is_downed and p.position.distance_to(position) < 10.0:
			GameState.on_orb_touched(owner_peer, p.peer_id)
			return

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	var pulse := 1.0 + 0.2 * sin(Time.get_ticks_msec() / 150.0)
	draw_circle(Vector2.ZERO, 7.0 * pulse, Color(0.5, 0.95, 1, 0.45))
	draw_circle(Vector2.ZERO, 3.5, Color(0.8, 1, 1))
	var left: float = GameState.downed.get(owner_peer, 0.0)
	draw_arc(Vector2.ZERO, 10.0, -PI / 2, -PI / 2 + TAU * clampf(left / GameState.RESCUE_TIME, 0, 1), 24, Color(1, 0.4, 0.4), 2.0)
