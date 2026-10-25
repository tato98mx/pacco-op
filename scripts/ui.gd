extends CanvasLayer
# Lobby (crear/unirse/solo) + HUD + pantalla de Game Over. Todo por código.

var lobby: VBoxContainer
var info: Label
var code_edit: LineEdit
var hud: Label
var over_box: VBoxContainer

func _ready() -> void:
	lobby = VBoxContainer.new()
	lobby.position = Vector2(30, 330)
	lobby.custom_minimum_size = Vector2(300, 0)
	lobby.add_theme_constant_override("separation", 10)
	add_child(lobby)
	_label(lobby, "PAC·CO-OP", 28)
	_button(lobby, "Crear sala (online)", _on_host)
	code_edit = LineEdit.new()
	code_edit.placeholder_text = "Código de 4 letras"
	code_edit.max_length = 4
	code_edit.add_theme_font_size_override("font_size", 18)
	lobby.add_child(code_edit)
	_button(lobby, "Unirse", _on_join)
	_button(lobby, "Jugar solo (pruebas)", _on_solo)
	info = _label(lobby, "", 14)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	hud = Label.new()
	hud.position = Vector2(12, 8)
	hud.add_theme_font_size_override("font_size", 14)
	add_child(hud)

	over_box = VBoxContainer.new()
	over_box.position = Vector2(60, 300)
	over_box.custom_minimum_size = Vector2(240, 0)
	over_box.visible = false
	add_child(over_box)
	_label(over_box, "GAME OVER", 32)
	_button(over_box, "Reintentar (host)", func(): get_tree().current_scene.restart(); over_box.visible = false)

	Network.room_ready.connect(func(c): info.text = "Sala: %s\nComparte el código y espera a tu compañero…" % c)
	Network.failed.connect(func(r): info.text = r)
	Network.connected.connect(func(): lobby.visible = false)
	GameState.game_over.connect(func(): over_box.visible = true)
	GameState.changed.connect(func(): if not GameState.over: over_box.visible = false)

func _label(parent: Node, t: String, size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l

func _button(parent: Node, t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _on_host() -> void:
	info.text = "Creando sala…"
	Network.host_room()

func _on_join() -> void:
	if code_edit.text.length() != 4:
		info.text = "Escribe el código de 4 letras"
		return
	info.text = "Conectando…"
	Network.join_room(code_edit.text)

func _on_solo() -> void:
	lobby.visible = false
	get_tree().current_scene.start_match([1])

func _process(_d: float) -> void:
	var me = null
	for p in GameState.players():
		if p.peer_id == multiplayer.get_unique_id(): me = p
	var t := "Vidas: %d    Puntos: %d" % [GameState.shared_lives, GameState.score]
	if me:
		t += "\nBomba: %s   Disparos: %d" % ["sí" if me.has_bomb else "no", me.ammo]
	for id in GameState.downed:
		t += "\nRESCATA A J%d: %.1f s" % [id, GameState.downed[id]]
	hud.text = t
	over_box.get_child(1).visible = multiplayer.is_server()
