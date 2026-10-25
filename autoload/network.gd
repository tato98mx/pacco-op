extends Node
# WebRTC P2P (host = jugador 1) con señalización por WebSocket (Cloudflare Worker).
# Flujo: host_room() -> código de 4 letras -> el otro jugador usa join_room(código).

signal room_ready(code: String)
signal connected
signal failed(reason: String)

# >>> CAMBIA ESTO por la URL que te da `wrangler deploy` (usa wss://) <<<
const SIGNALING_URL := "wss://pacco-signal.ydfz296yrr.workers.dev"
const ICE := {"iceServers": [{"urls": ["stun:stun.l.google.com:19302"]}]}

var ws := WebSocketPeer.new()
var rtc := WebRTCMultiplayerPeer.new()
var conns := {}
var remote_ready := {}
var pending_candidates := {}
var my_id := 0
var room := ""
var _done := false

func _ready() -> void:
	set_process(false)
	multiplayer.peer_connected.connect(_on_peer_connected)

func host_room() -> void:
	var letters := "ABCDEFGHJKLMNPQRSTUVWXYZ"
	room = ""
	for i in 4:
		room += letters[randi() % letters.length()]
	_connect_ws("host")

func join_room(code: String) -> void:
	room = code.strip_edges().to_upper()
	_connect_ws("join")

func _connect_ws(role: String) -> void:
	ws = WebSocketPeer.new()
	rtc = WebRTCMultiplayerPeer.new()
	conns.clear()
	remote_ready.clear()
	pending_candidates.clear()
	_done = false
	var err := ws.connect_to_url("%s/ws/%s?role=%s" % [SIGNALING_URL, room, role])
	if err != OK:
		failed.emit("No se pudo contactar al servidor de señalización")
		return
	set_process(true)

func _process(_d: float) -> void:
	ws.poll()
	match ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0:
				var m = JSON.parse_string(ws.get_packet().get_string_from_utf8())
				if m is Dictionary: _on_msg(m)
		WebSocketPeer.STATE_CLOSED:
			if not _done: failed.emit("Se cerró la conexión con el servidor")
			set_process(false)

func _send(d: Dictionary) -> void:
	ws.send_text(JSON.stringify(d))

func _new_conn(id: int) -> WebRTCPeerConnection:
	var c := WebRTCPeerConnection.new()
	c.initialize(ICE)
	c.session_description_created.connect(func(type: String, sdp: String):
		c.set_local_description(type, sdp)
		_send({"type": type, "to": id, "sdp": sdp}))
	c.ice_candidate_created.connect(func(media: String, index: int, cname: String):
		_send({"type": "candidate", "to": id, "media": media, "index": index, "name": cname}))
	conns[id] = c
	remote_ready[id] = false
	pending_candidates[id] = []
	rtc.add_peer(c, id)
	return c

func _on_msg(m: Dictionary) -> void:
	match m.get("type", ""):
		"welcome":
			my_id = int(m["id"])
			if my_id == 1:
				rtc.create_server()
				room_ready.emit(room)
			else:
				rtc.create_client(my_id)
			multiplayer.multiplayer_peer = rtc
		"error":
			_done = true
			failed.emit(_reason(str(m.get("reason", ""))))
			ws.close()
		"peer_joined":
			_new_conn(int(m["id"])).create_offer()
		"offer":
			var oid := int(m["from"])
			_new_conn(oid)
			_set_remote(oid, "offer", str(m["sdp"]))
		"answer":
			var aid := int(m["from"])
			if conns.has(aid):
				_set_remote(aid, "answer", str(m["sdp"]))
		"candidate":
			var cid := int(m["from"])
			if not conns.has(cid): return
			var candidate := {"media": str(m["media"]), "index": int(m["index"]), "name": str(m["name"])}
			if remote_ready.get(cid, false):
				conns[cid].add_ice_candidate(candidate.media, candidate.index, candidate.name)
			else:
				pending_candidates[cid].append(candidate)

func _set_remote(id: int, type: String, sdp: String) -> void:
	conns[id].set_remote_description(type, sdp)
	remote_ready[id] = true
	for candidate in pending_candidates.get(id, []):
		conns[id].add_ice_candidate(candidate.media, candidate.index, candidate.name)
	pending_candidates[id].clear()

func _reason(r: String) -> String:
	match r:
		"no_room": return "Esa sala no existe"
		"room_full": return "La sala ya está llena"
		"room_taken": return "Código en uso, intenta de nuevo"
	return "Error de conexión"

func _on_peer_connected(_id: int) -> void:
	_done = true
	ws.close()
	connected.emit()

func leave() -> void:
	multiplayer.multiplayer_peer = null
	conns.clear()
