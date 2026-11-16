extends Control
## Schermata di gioco: tabellone (2D o 3D) a sinistra, compagnie e diario a destra, barra delle
## decisioni in basso. Le scelte si fanno con i pulsanti della barra o toccando il tabellone.

const D = preload("res://scripts/data/th_data.gd")
const SIDE_W := 560.0

var main
var config := {}
var engine: THEngine
var board
var board3d
var view3d := false
var side: PanelContainer
var side_box: VBoxContainer
var cal_lbl: Label
var phase_lbl: Label
var players_box: VBoxContainer
var company_box: VBoxContainer
var log_box: RichTextLabel
var prompt: PanelContainer
var prompt_title: Label
var prompt_box: HFlowContainer
var popup_layer: Control
var toast_box: VBoxContainer
var wait_lbl: Label
var pending := {}
var aux := {}
var focus_p := 0
var _dirty := true
var save_code := ""
var humans: Array = []
# tutorial e consiglio del tutor
var tut := false
var tut_seen := {}
var tutor_on := false
var tutor_ai: THAI
var tutor_panel: PanelContainer
var tutor_box: VBoxContainer
var tutor_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	engine = THEngine.new()
	add_child(engine)
	if not config.has("seed"):
		config["seed"] = 1 + randi() % 2000000000
	engine.setup(config)
	for i in engine.n:
		var st: Dictionary = config["seats"][i]
		engine.ais[i] = THAI.new(int(st.get("level", 1)), int(config["seed"]) + i * 31)
		if not st.get("ai", false):
			humans.append(i)
	focus_p = humans[0] if not humans.is_empty() else 0
	if config.has("online"):
		engine.online = config["online"]
		add_child(engine.online)
		engine.online.view = self
		focus_p = engine.online.seat
		humans = [engine.online.seat]
		engine.online.heartbeat_loop()
	tut = bool(config.get("tutorial", false))
	tutor_on = tut
	tutor_ai = THAI.new(2, int(config["seed"]) + 977)
	_build()
	engine.changed.connect(func(): _dirty = true)
	engine.log_added.connect(_on_log)
	engine.decision_requested.connect(_on_decision)
	engine.fx.connect(_on_fx)
	engine.game_ended.connect(_on_end)
	view3d = bool(config.get("view3d", false))
	_apply_view()
	engine.run.call_deferred()


func _exit_tree() -> void:
	if engine != null:
		engine.abort = true
		engine.provide_decision(null)


# ================================================================ struttura

func _build() -> void:
	board = preload("res://scripts/ui/board_2d.gd").new()
	board.anchor_right = 1.0
	board.anchor_bottom = 1.0
	board.offset_right = -SIDE_W
	add_child(board)
	board.setup(engine)
	board.viewer = focus_p
	board.spot_pressed.connect(_on_spot)

	# comandi della vista
	var vb := HBoxContainer.new()
	vb.position = Vector2(14, 12)
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)
	for it in [["Menu", _ask_menu], ["Regole", _show_rules], ["Salva", _save_game], ["Tutto", _view_all],
			["+", func(): _zoom(1.25)], ["-", func(): _zoom(0.8)],
			["Ruota", func(): _rotate(PI / 2)], ["2D / 3D", _toggle_view], ["Tutor", _toggle_tutor]]:
		var b := UI.button(it[0], 0, 50, 20)
		b.custom_minimum_size.x = 62 if it[0].length() <= 1 else 0
		b.pressed.connect(it[1])
		vb.add_child(b)
		if it[0] == "Tutor":
			tutor_btn = b
			b.toggle_mode = true
			b.button_pressed = tutor_on
			b.tooltip_text = "Mostra o nasconde il consiglio del tutor"
			b.visible = not config.has("online")

	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(20, 80)
	toast_box.add_theme_constant_override("separation", 6)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_box)

	wait_lbl = UI.label("", 22, UI.GOLD_L, UI.font_semi)
	wait_lbl.position = Vector2(20, 76)
	wait_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	wait_lbl.add_theme_constant_override("outline_size", 6)
	add_child(wait_lbl)

	# barra delle decisioni
	prompt = PanelContainer.new()
	prompt.add_theme_stylebox_override("panel", UI.dark_style(10, 0.94))
	prompt.anchor_top = 1.0
	prompt.anchor_bottom = 1.0
	prompt.anchor_right = 1.0
	prompt.offset_left = 12
	prompt.offset_right = -SIDE_W - 12
	prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt.offset_bottom = -12
	add_child(prompt)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	prompt.add_child(pv)
	prompt_title = UI.wrap(UI.label("", 23, UI.SAND, UI.font_semi), 600)
	prompt_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv.add_child(prompt_title)
	prompt_box = HFlowContainer.new()
	prompt_box.add_theme_constant_override("h_separation", 8)
	prompt_box.add_theme_constant_override("v_separation", 8)
	pv.add_child(prompt_box)
	prompt.visible = false

	# pannello laterale
	side = PanelContainer.new()
	var ss := UI.panel_style(Color(UI.PANEL, 0.97), Color(UI.GOLD, 0.5), 0, 0)
	ss.border_width_left = 3
	side.add_theme_stylebox_override("panel", ss)
	side.anchor_left = 1.0
	side.anchor_right = 1.0
	side.anchor_bottom = 1.0
	side.offset_left = -SIDE_W
	add_child(side)
	side_box = VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 10)
	side.add_child(side_box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	side_box.add_child(head)
	head.add_child(UI.title("Thesauros", 34))
	cal_lbl = UI.label("", 22, UI.GOLD_L, UI.font_head)
	cal_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(cal_lbl)
	phase_lbl = UI.wrap(UI.label("", 19, UI.MUTED, UI.font_semi), SIDE_W - 40)
	side_box.add_child(phase_lbl)
	players_box = VBoxContainer.new()
	players_box.add_theme_constant_override("separation", 6)
	side_box.add_child(players_box)
	var sep := HSeparator.new()
	side_box.add_child(sep)
	company_box = VBoxContainer.new()
	company_box.add_theme_constant_override("separation", 6)
	side_box.add_child(company_box)
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.custom_minimum_size = Vector2(SIDE_W - 30, 120)
	log_box.add_theme_font_size_override("normal_font_size", 17)
	log_box.add_theme_font_size_override("bold_font_size", 17)
	var lb := UI.panel_style(Color(0, 0, 0, 0.25), Color(UI.GOLD, 0.25), 1, 6)
	lb.set_content_margin_all(8)
	log_box.add_theme_stylebox_override("normal", lb)
	side_box.add_child(log_box)

	popup_layer = Control.new()
	popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup_layer)

	# consiglio del tutor: sopra le finestre, nella colonna di destra
	tutor_panel = PanelContainer.new()
	var ts := UI.panel_style(Color("#2a1d0d", 0.97), UI.GOLD, 2, 8)
	ts.shadow_color = Color(0, 0, 0, 0.6)
	ts.shadow_size = 12
	tutor_panel.add_theme_stylebox_override("panel", ts)
	tutor_panel.anchor_left = 1.0
	tutor_panel.anchor_right = 1.0
	tutor_panel.offset_left = -SIDE_W + 8
	tutor_panel.offset_right = -8
	tutor_panel.offset_top = 372
	tutor_panel.visible = false
	add_child(tutor_panel)
	tutor_box = VBoxContainer.new()
	tutor_box.add_theme_constant_override("separation", 8)
	tutor_panel.add_child(tutor_box)


func _process(_dt: float) -> void:
	if _dirty:
		_dirty = false
		_refresh()


func _view_all() -> void:
	if view3d and board3d != null:
		board3d.yaw = 0.0
		board3d.pitch = 1.05
		board3d.dist = 7.0
		board3d.target = Vector3.ZERO
		board3d._cam()
	else:
		board.fit()


func _zoom(f: float) -> void:
	if view3d and board3d != null:
		board3d.dist = clampf(board3d.dist / f, 0.6, 9.0)
		board3d._cam()
	else:
		board._zoom_at(board.size * 0.5, f)


func _rotate(a: float) -> void:
	if view3d and board3d != null:
		board3d.rotate_by(a)
	else:
		board.rotate_by(a)


func _toggle_view() -> void:
	view3d = not view3d
	_apply_view()


func _apply_view() -> void:
	if view3d and board3d == null:
		board3d = preload("res://scripts/ui/board_3d.gd").new()
		board3d.anchor_right = 1.0
		board3d.anchor_bottom = 1.0
		board3d.offset_right = -SIDE_W
		add_child(board3d)
		move_child(board3d, board.get_index() + 1)
		board3d.setup(engine)
		board3d.spot_pressed.connect(_on_spot)
	if board3d != null:
		board3d.visible = view3d
		board3d.hot = board.hot
	board.visible = not view3d
	_dirty = true


# ================================================================ aggiornamento dei pannelli

func _phase_text() -> String:
	var e := engine
	match e.phase:
		"setup": return "Preparazione"
		"budget": return "Gestione del budget dell'anno %d" % e.year
		"place": return "Piazzamento: tocca a %s" % e.pname(e.current)
		"resolve":
			if e.zone_now > 0:
				return "Risoluzione · zona %d: %s" % [e.zone_now, D.ZONE_NAMES[e.zone_now]]
			return "Risoluzione delle azioni"
		"salary": return "Pagamento degli stipendi"
		"maint": return "Manutenzione"
		"merc": return "Asta per un mercenario (cassa nera)"
		"over": return "Partita finita"
	return ""


func _refresh() -> void:
	var e := engine
	cal_lbl.text = "Anno %d · %d/9" % [e.year, e.period]
	phase_lbl.text = _phase_text()
	for c in players_box.get_children():
		c.queue_free()
	var ord: Array = e.order if not e.order.is_empty() else range(e.n)
	for p in ord:
		players_box.add_child(_player_row(p))
	_company(focus_p)
	board.queue_redraw()
	if board3d != null and board3d.visible:
		board3d.refresh()


func _player_row(p: int) -> Control:
	var e := engine
	var b := Button.new()
	b.custom_minimum_size = Vector2(SIDE_W - 30, 58)
	var on := p == e.current and e.phase != "over"
	b.add_theme_stylebox_override("normal", UI._btn(Color(UI.PANEL_L, 0.9) if not on else Color("#1d5a66"), UI.pcolor(e, p) if on else Color(UI.pcolor(e, p), 0.5)))
	b.add_theme_stylebox_override("hover", UI._btn(Color("#1d5a66"), UI.GOLD_L))
	b.pressed.connect(func():
		focus_p = p
		board.viewer = p if (p in humans or e.phase == "over") else focus_p
		_dirty = true
		_company_popup(p))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.offset_right = -10
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var chip := ColorRect.new()
	chip.color = UI.pcolor(e, p)
	chip.custom_minimum_size = Vector2(16, 40)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(chip)
	var nm := UI.label(e.pname(p), 21, UI.TEXT, UI.font_semi)
	nm.custom_minimum_size.x = 170
	nm.clip_text = true
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(nm)
	var shown: int = e.money(p) - (0 if (p in humans and humans.size() == 1) or e.phase == "over" else e.ps[p]["acc"]["bc"])
	for it in [["%d" % e.ps[p]["rep"], "rep."], ["%d$" % shown, ""], ["%d" % e.ps[p]["treasures"].size(), "tes."], ["%d" % e.ps[p]["cards"].size(), "carte"]]:
		var l := UI.label(it[0] + (" " + it[1] if it[1] != "" else ""), 19, UI.SAND if it[1] != "rep." else UI.GOLD_L, UI.font_cond)
		l.custom_minimum_size.x = 64
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(l)
	return b


func _icon_count(t: Texture2D, n: int, sz := 40.0, tip := "") -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(sz + (18 if n > 1 else 0), sz)
	var r := UI.icon_rect(t, Vector2(sz, sz))
	c.add_child(r)
	if n > 1:
		var l := UI.label("x%d" % n, 16, UI.GOLD_L, UI.font_bold)
		l.position = Vector2(sz - 6, sz - 20)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 5)
		c.add_child(l)
	c.tooltip_text = tip
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	return c


func _company(p: int) -> void:
	for c in company_box.get_children():
		c.queue_free()
	var e := engine
	var t := HBoxContainer.new()
	t.add_theme_constant_override("separation", 8)
	company_box.add_child(t)
	t.add_child(UI.heading(D.COLORS[e.pcol(p)]["company"], 22, UI.pcolor(e, p).lightened(0.2)))
	var who := UI.label("(%s)" % e.pname(p), 18, UI.MUTED)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.clip_text = true
	t.add_child(who)
	# conti
	var acc := HBoxContainer.new()
	acc.add_theme_constant_override("separation", 5)
	company_box.add_child(acc)
	var secret: bool = not (p in humans) and e.phase != "over"
	for a in D.ACCOUNTS:
		var pc := PanelContainer.new()
		var st := UI.panel_style(D.ACC_COLORS[a], Color(1, 1, 1, 0.25) if a != e.ps[p]["inc"] else UI.GOLD_L, 2, 6)
		st.set_content_margin_all(4)
		pc.add_theme_stylebox_override("panel", st)
		pc.custom_minimum_size = Vector2(98, 56)
		pc.tooltip_text = D.ACC_NAMES[a] + (" (qui vanno gli incassi)" if a == e.ps[p]["inc"] else "")
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -4)
		pc.add_child(v)
		var l1 := UI.label(D.ACC_SHORT[a], 15, Color(1, 1, 1, 0.8), UI.font_cond)
		l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l1)
		var val: String = "?" if (a == "bc" and secret) else "%d$" % e.ps[p]["acc"][a]
		var l2 := UI.label(val, 24, Color.WHITE, UI.font_bold)
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l2)
		acc.add_child(pc)
	# personale
	var mrow := HFlowContainer.new()
	mrow.add_theme_constant_override("h_separation", 6)
	company_box.add_child(mrow)
	var lm := UI.label("In sede:", 18, UI.MUTED)
	mrow.add_child(lm)
	for m in e.ps[p]["meeples"]:
		if m["loc"] == "reserve":
			continue
		var mm := _meeple_icon(p, m, 40)
		mm.modulate = Color(1, 1, 1, 1.0 if m["loc"] == "room" else 0.35)
		mm.tooltip_text = _meeple_desc(m)
		mrow.add_child(mm)
	if e.ps[p]["dbl"] > 0:
		mrow.add_child(_icon_count(UI.tex("res://assets/segnalini/doppia.png"), e.ps[p]["dbl"], 36, "Segnalino doppia azione"))
	if e.variant:
		var extra := []
		if e.black_plane == p:
			extra.append("idrovolante nero")
		if e.mine_owner == p:
			extra.append("mina subacquea")
		if not e.ps[p]["merc_cards"].is_empty():
			extra.append("carte del mercenario %s" % ", ".join(e.ps[p]["merc_cards"].map(func(x): return str(x))))
		if not extra.is_empty():
			company_box.add_child(UI.wrap(UI.label("Bottino dei mercenari: " + ", ".join(extra), 17, UI.CORAL), SIDE_W - 40))
	# oggetti, tesori, carte, squali
	var irow := HFlowContainer.new()
	irow.add_theme_constant_override("h_separation", 4)
	irow.add_theme_constant_override("v_separation", 4)
	company_box.add_child(irow)
	irow.add_child(UI.label("Magazzino:", 18, UI.MUTED))
	for k in D.ITEM_ORDER:
		var c: int = e.ps[p]["stock"].get(k, 0)
		if c > 0:
			irow.add_child(_icon_count(UI.item_tex(k), c, 40, D.ITEMS[k]["name"]))
	var trow := HFlowContainer.new()
	trow.add_theme_constant_override("h_separation", 4)
	company_box.add_child(trow)
	trow.add_child(UI.label("Tesori e carte:", 18, UI.MUTED))
	var tv := {}
	for v in e.ps[p]["treasures"]:
		tv[v] = tv.get(v, 0) + 1
	for v in [3, 5, 7, 9]:
		if tv.has(v):
			trow.add_child(_icon_count(UI.chest_tex(v), tv[v], 40, "Tesoro di %s (%d$)" % [D.TREASURE_NAMES[v], v]))
	var cv := {}
	for k in e.ps[p]["cards"]:
		cv[k] = cv.get(k, 0) + 1
	for k in range(1, 8):
		if cv.has(k):
			trow.add_child(_icon_count(UI.card_tex(k), cv[k], 40, "Carta tesoro %d" % k))
	if e.ps[p]["sharks"] > 0:
		trow.add_child(_icon_count(UI.tex("res://assets/tesori/squalo.png"), e.ps[p]["sharks"], 40, "Squali uccisi"))
	# gommoni
	for z in e.zods_of(p):
		var zr := HBoxContainer.new()
		zr.add_theme_constant_override("separation", 4)
		company_box.add_child(zr)
		zr.add_child(UI.icon_rect(UI.zod_tex(z["color"]), Vector2(30, 40)))
		var where := UI.label(_zod_where(z), 17, UI.SAND, UI.font_cond)
		where.custom_minimum_size.x = 120
		zr.add_child(where)
		for k in D.ITEM_ORDER:
			var c: int = z["items"].get(k, 0)
			if c > 0:
				zr.add_child(_icon_count(UI.item_tex(k), c, 34, D.ITEMS[k]["name"]))


func _zod_where(z: Dictionary) -> String:
	var loc: String = z["loc"]
	if loc == "port":
		return "in porto"
	if loc == "PORT":
		return "in partenza"
	if loc.begins_with("lag:"):
		return "in laguna"
	return engine.node_name(loc)


func _meeple_icon(p: int, m: Dictionary, sz: float) -> Control:
	var c := MeepleIcon.new()
	c.col = Color("#1d1f22") if m.get("merc", false) else UI.pcolor(engine, p)
	c.boss = m["boss"]
	c.hat = m["hat"]
	c.custom_minimum_size = Vector2(sz, sz)
	return c


func _meeple_desc(m: Dictionary) -> String:
	if m.get("merc", false):
		return "Mercenario" + (", in sede" if m["loc"] in ["room", "idle"] else "")
	var s := "Capo" if m["boss"] else ("Specialista n.%s" % ("5/7" if m["hat"] == 57 else str(m["hat"])) if m["hat"] != 0 else "Lavoratore")
	var where := {"room": "in sede", "sea": "in mare", "lagoon": "in laguna", "shop": "al negozio di gommoni", "deck": "sul mazzo delle tecnologie"}
	var loc: String = m["loc"]
	if loc.begins_with("q"):
		return s + ", in zona " + loc.substr(1)
	return s + ", " + where.get(loc, loc)


class MeepleIcon extends Control:
	var col := Color.WHITE
	var boss := false
	var hat := 0

	func _draw() -> void:
		var h := size.y * 0.9
		var c := size * 0.5 + Vector2(0, size.y * 0.04)
		var pts := PackedVector2Array()
		for v in preload("res://scripts/ui/board_2d.gd").MEEPLE:
			pts.append(c + v * h)
		draw_colored_polygon(pts, col)
		pts.append(pts[0])
		draw_polyline(pts, col.darkened(0.55), 2.0)
		if boss:
			draw_rect(Rect2(c + Vector2(-h * 0.22, -h * 0.62), Vector2(h * 0.44, h * 0.13)), Color("#1b2328"))
			draw_rect(Rect2(c + Vector2(-h * 0.28, -h * 0.5), Vector2(h * 0.56, h * 0.05)), Color("#1b2328"))
		if hat != 0:
			var hc: Color = preload("res://scripts/ui/board_2d.gd").HAT_COL.get(hat, Color.BLACK)
			var top := c + Vector2(0, -h * 0.52)
			draw_colored_polygon(PackedVector2Array([top + Vector2(-h * 0.3, 0), top + Vector2(0, -h * 0.13), top + Vector2(h * 0.3, 0), top + Vector2(0, h * 0.1)]), hc)


# ================================================================ diario e messaggi

func _on_log(t: String) -> void:
	var col := "#eef6f4"
	if t.begins_with("==="):
		col = "#f5d27c"
	elif t.begins_with("---"):
		col = "#7fd6cc"
	elif t.begins_with("   "):
		col = "#b9cfcf"
	log_box.append_text("[color=%s]%s[/color]\n" % [col, t])
	if log_box.get_paragraph_count() > 400:
		log_box.remove_paragraph(0)
	_dirty = true


func toast(t: String, col := UI.SAND) -> void:
	var l := UI.label(t, 22, col, UI.font_semi)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 7)
	toast_box.add_child(l)
	while toast_box.get_child_count() > 4:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _on_fx(kind: String, d: Dictionary) -> void:
	var e := engine
	match kind:
		"shark":
			toast("%s: %s (dado %d)" % [e.pname(d["p"]), "squalo ucciso!" if d["kill"] else "lo squalo fugge", d["die"]], UI.GOLD_L if d["kill"] else UI.SAND)
		"treasure":
			toast("%s recupera un tesoro di %s!" % [e.pname(d["p"]), D.TREASURE_NAMES[d["v"]]], UI.GOLD_L)
		"reveal":
			toast("Il sito %d viene scoperto." % d["site"], UI.TEAL_L)
		"open":
			toast("Una sala del museo apre al pubblico!", UI.GOLD_L)
		"hat":
			toast("%s forma uno specialista." % e.pname(d["p"]), UI.TEAL_L)
		"island":
			toast("%s trova qualcosa sull'isola." % e.pname(d["p"]), UI.SAND)
		"merc":
			toast("%s ingaggia un mercenario." % e.pname(d["p"]), UI.CORAL)
		"mercact":
			toast("Colpo del mercenario di %s in zona %d!" % [e.pname(d["p"]), d["z"]], UI.CORAL)
		"mine":
			toast("%s fa esplodere una mina nel sito %d!" % [e.pname(d["p"]), d["site"]], UI.CORAL)
	_dirty = true


# ================================================================ online

func online_waiting(s: int, slow: bool) -> void:
	if s < 0:
		wait_lbl.text = ""
	else:
		wait_lbl.text = "Aspetto %s…%s" % [engine.pname(s), " (ci mette un po')" if slow else ""]


func online_mine() -> bool:
	return engine.online != null and engine.online._mine_pending


func online_status(t: String) -> void:
	toast(t, UI.CORAL)


func online_caught_up() -> void:
	toast("Partita ripresa: sei di nuovo al tavolo.", UI.TEAL_L)


func online_cancel_decision(t: String) -> void:
	_clear_prompt()
	toast(t, UI.CORAL)


# ================================================================ decisioni: base

func _clear_prompt() -> void:
	if tutor_panel != null:
		tutor_panel.visible = false
	pending = {}
	aux = {}
	prompt.visible = false
	for c in prompt_box.get_children():
		c.queue_free()
	board.hot = {}
	board.hot_sel = ""
	board.queue_redraw()
	if board3d != null:
		board3d.hot = board.hot
	_dirty = true
	for c in popup_layer.get_children():
		c.queue_free()


func _submit(r) -> void:
	var req := pending
	_clear_prompt()
	if req.is_empty():
		return
	engine.provide_decision(r)


func _ptitle(t: String) -> void:
	prompt.visible = true
	prompt_title.text = t


func _pbtn(t: String, cb: Callable, prim := false, enabled := true) -> Button:
	var b := UI.button(t, 0, 50, 20)
	if prim:
		UI.primary(b)
	b.disabled = not enabled
	b.pressed.connect(cb)
	prompt_box.add_child(b)
	return b


func _ptoggle(t: String, on: bool, cb: Callable) -> Button:
	var b := UI.button(t, 0, 50, 20)
	b.toggle_mode = true
	b.button_pressed = on
	b.toggled.connect(cb)
	prompt_box.add_child(b)
	return b


func _hot(id: String, pos: Vector2, label := "", r := 70.0, col := UI.GOLD_L) -> void:
	board.hot[id] = {"pos": pos, "label": label, "r": r, "col": col}
	if board3d != null:
		board3d.hot = board.hot
	_dirty = true


func _on_spot(id: String) -> void:
	if aux.has("spot_cb"):
		aux["spot_cb"].call(id)


func _on_decision(req: Dictionary) -> void:
	pending = req
	aux = {}
	var p: int = req["seat"]
	focus_p = p
	board.viewer = p
	_dirty = true
	var secret_types := ["budget", "bid", "dig", "sat", "reserve", "merc_bid", "merc3"]
	var go := func():
		_show_decision(req)
		_tutor_show(req)
	if tut:
		var ks: Array = Tutorial.keys_for(engine, req, tut_seen)
		if not ks.is_empty():
			var pages := []
			for k in ks:
				tut_seen[k] = true
				pages.append_array(Tutorial.LESSONS[k])
			show_lesson(pages, 0, go)
			return
	if humans.size() > 1 and req["type"] in secret_types:
		_curtain(p, go)
	else:
		go.call()


func _curtain(p: int, then: Callable) -> void:
	var dlg := _dialog("Tocca a %s" % engine.pname(p), 640)
	dlg["box"].add_child(UI.wrap(UI.label("La prossima scelta è segreta: passate il dispositivo a %s." % engine.pname(p), 21, UI.SAND), 580))
	var b := UI.primary(UI.button("Sono %s" % engine.pname(p), 0, 60, 22))
	b.pressed.connect(func():
		dlg["root"].queue_free()
		then.call())
	dlg["box"].add_child(b)


func _show_decision(req: Dictionary) -> void:
	match req["type"]:
		"budget": _ui_budget(req)
		"place": _ui_place(req, false)
		"recruit": _ui_place(req, true)
		"z2": _ui_z2(req)
		"sat": _ui_sat(req)
		"dig": _ui_dig(req)
		"z3": _ui_z3(req)
		"plane": _ui_plane(req)
		"sea": _ui_sea(req)
		"dive": _ui_dive(req)
		"z7": _ui_z7(req)
		"island": _ui_island(req)
		"z8": _ui_z8(req)
		"bid": _ui_bid(req)
		"merc_bid": _ui_merc_bid(req)
		"merc2": _ui_merc2(req)
		"merc3": _ui_merc3(req)
		"merc8": _ui_merc8(req)
		"mine": _ui_mine(req)
		"reserve": _ui_reserve(req)
		_:
			_submit(engine.ais[req["seat"]].decide(engine, req["seat"], req))


## Finestra al centro: {root, box}.
func _dialog(title: String, w := 760.0) -> Dictionary:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	popup_layer.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.dark_style(12, 0.98))
	pc.custom_minimum_size = Vector2(w, 0)
	root.add_child(pc)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pc.add_child(sc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.custom_minimum_size.x = w - 40
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)
	vb.add_child(UI.heading(title, 30))
	var place := func():
		if not is_instance_valid(vb) or not is_instance_valid(pc) or not is_instance_valid(sc):
			return
		var avail := get_viewport_rect().size
		var maxh := avail.y - 60
		var want := vb.get_combined_minimum_size().y + 30
		sc.custom_minimum_size = Vector2(w - 24, minf(want, maxh - 30))
		pc.size = Vector2(w, 0)
		pc.reset_size()
		pc.position = ((Vector2(avail.x - SIDE_W, avail.y) - pc.size) * 0.5).max(Vector2(10, 10))
	vb.resized.connect(place)
	place.call_deferred()
	return {"root": root, "box": vb, "panel": pc}


func _row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	return h


func _flow() -> HFlowContainer:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 8)
	h.add_theme_constant_override("v_separation", 8)
	return h


# ================================================================ budget

func _ui_budget(req: Dictionary) -> void:
	var e := engine
	var p: int = req["seat"]
	var tot: int = req["money"]
	var sug: Dictionary = e.ais[p].default_budget(e, p, tot)
	aux["b"] = sug.duplicate()
	var dlg := _dialog("Budget dell'anno %d: %d$ da ripartire" % [req["year"], tot], 860)
	var box: VBoxContainer = dlg["box"]
	box.add_child(UI.wrap(UI.label("La ripartizione vale per i tre quadrimestri dell'anno. Pagare da un conto sbagliato costa %d$ di tassa per ogni trasferimento; la cassa nera si riempie solo adesso e serve per le buste alle autorità (zona 10)." % e.year
		+ (" Iniziazione: i valori suggeriti sono il minimo consigliato." if e.initiation else ""), 19, UI.MUTED), 800))
	var left := UI.label("", 24, UI.GOLD_L, UI.font_bold)
	var rows := {}
	var refresh := func():
		var s := 0
		for a in D.ACCOUNTS:
			s += aux["b"][a]
			rows[a].text = "%d$" % aux["b"][a]
		left.text = "Da assegnare: %d$" % (tot - s) if tot != s else "Tutto assegnato"
		left.add_theme_color_override("font_color", UI.GOLD_L if tot == s else UI.CORAL)
		aux["ok"].disabled = tot != s
	for a in D.ACCOUNTS:
		var r := _row()
		var chip := PanelContainer.new()
		var st := UI.panel_style(D.ACC_COLORS[a], Color(1, 1, 1, 0.3), 2, 6)
		st.set_content_margin_all(6)
		chip.add_theme_stylebox_override("panel", st)
		chip.custom_minimum_size = Vector2(300, 52)
		var nl := UI.label(D.ACC_NAMES[a] + (("  (consigliati %d$)" % D.INIT_HINT[a]) if e.initiation and e.year == 1 else ""), 19, Color.WHITE, UI.font_semi)
		chip.add_child(nl)
		r.add_child(chip)
		for d in [-5, -1]:
			var b := UI.button(str(d), 64, 52, 20)
			b.pressed.connect(func():
				aux["b"][a] = maxi(0, aux["b"][a] + d)
				refresh.call())
			r.add_child(b)
		var v := UI.label("", 26, UI.TEXT, UI.font_bold)
		v.custom_minimum_size.x = 90
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rows[a] = v
		r.add_child(v)
		for d in [1, 5]:
			var b := UI.button("+%d" % d, 64, 52, 20)
			b.pressed.connect(func():
				aux["b"][a] += d
				refresh.call())
			r.add_child(b)
		var rest := UI.button("Il resto", 110, 52, 18)
		rest.pressed.connect(func():
			var s := 0
			for x in D.ACCOUNTS:
				if x != a:
					s += aux["b"][x]
			aux["b"][a] = maxi(0, tot - s)
			refresh.call())
		r.add_child(rest)
		box.add_child(r)
	var ir := _row()
	ir.add_child(UI.label("Gli incassi dell'anno vanno nel conto:", 19, UI.SAND))
	var ibtn := []
	for a in ["hr", "rd", "gp", "me"]:
		var b := UI.button(D.ACC_SHORT[a], 70, 48, 19)
		b.toggle_mode = true
		b.button_pressed = aux["b"]["inc"] == a
		ibtn.append(b)
		b.pressed.connect(func():
			aux["b"]["inc"] = a
			for x in ibtn:
				x.button_pressed = x == b)
		ir.add_child(b)
	box.add_child(ir)
	var br := _row()
	br.add_child(left)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sugb := UI.button("Ripartizione consigliata", 0, 56, 19)
	sugb.pressed.connect(func():
		aux["b"] = sug.duplicate()
		refresh.call())
	br.add_child(sugb)
	var ok := UI.primary(UI.button("Conferma", 200, 56, 22))
	ok.pressed.connect(func(): _submit(aux["b"].duplicate()))
	aux["ok"] = ok
	br.add_child(ok)
	box.add_child(br)
	refresh.call()


# ================================================================ piazzamento

func _zone_spot(z: int) -> Vector2:
	if z == 6:
		return D.Z6_AREA
	var s := engine.queue_free_slot(z)
	return engine.L["queues"][z]["pos"][maxi(0, s)] + Vector2(-60, 0)


func _zone_hint(p: int, z: int) -> String:
	var e := engine
	if z in [1, 4, 9]:
		var s := e.queue_free_slot(z)
		if s >= 0:
			return " %d$" % e.queue_cost(z, s)
	return ""


func _ui_place(req: Dictionary, recruit: bool) -> void:
	var e := engine
	var p: int = req["seat"]
	if recruit:
		aux["m"] = req["m"]
	else:
		var room: Array = req["meeples"]
		aux["m"] = room[0]
		# di solito si sceglie prima un lavoratore semplice, il capo va scelto apposta
		for mid in room:
			if not e.meeple(p, mid)["boss"] and e.meeple(p, mid)["hat"] == 0:
				aux["m"] = mid
				break
	aux["env"] = false
	aux["dbl"] = false
	var build := func(): pass
	build = func():
		for c in prompt_box.get_children():
			c.queue_free()
		board.hot = {}
		var m: Dictionary = e.meeple(p, aux["m"])
		_ptitle(("Il nuovo lavoratore entra subito in una coda: scegli la zona." if recruit else
			"%s, piazza %s: tocca una zona sul tabellone o scegli qui sotto." % [e.pname(p), _meeple_desc(m).split(",")[0].to_lower()]))
		if not recruit:
			var seen := {}
			for mid in req["meeples"]:
				var mm: Dictionary = e.meeple(p, mid)
				var key := "%s_%d_%s" % [mm["boss"], mm["hat"], mm.get("merc", false)]
				if seen.has(key):
					continue
				seen[key] = true
				var b := _ptoggle(_meeple_desc(mm).split(",")[0], mid == aux["m"] or (key == "%s_%d_%s" % [m["boss"], m["hat"], m.get("merc", false)]), func(_on):
					aux["m"] = mid
					build.call())
				b.add_theme_color_override("font_pressed_color", UI.INK)
		if req["can_env"]:
			_ptoggle("Con la busta (zona 10)", aux["env"], func(on): aux["env"] = on)
		var is_merc: bool = m.get("merc", false)
		if req["can_dbl"] and not is_merc:
			_ptoggle("Doppia azione", aux["dbl"], func(on): aux["dbl"] = on)
		if is_merc:
			_ptitle("%s, manda il mercenario in una zona: agisce una volta sola, %s" % [e.pname(p), "e quella zona non potrà più averne altri."])
			for z in req.get("merc_zones", []):
				var zm: int = z
				var bm := _pbtn("%d %s: %s" % [z, D.ZONE_NAMES[z], D.MERC_SHORT[z]], func(): _submit({"m": aux["m"], "z": zm, "env": aux["env"], "dbl": false}))
				bm.tooltip_text = D.MERC_TEXT[z]
				_hot("z%d" % z, board.merc_pos(z), str(z), 60.0, UI.CORAL)
			aux["spot_cb"] = func(id: String):
				if id.begins_with("z"):
					_submit({"m": aux["m"], "z": int(id.substr(1)), "env": aux["env"], "dbl": false})
			return
		var zones: Array = req["zones"]
		for z in zones:
			var lbl := "%d %s%s" % [z, D.ZONE_NAMES[z], _zone_hint(p, z)]
			var zz: int = z
			var b := _pbtn(lbl, func(): _submit({"m": aux["m"], "z": zz, "env": aux["env"], "dbl": aux["dbl"]}))
			b.tooltip_text = D.ZONE_HINT.get(z, "")
			_hot("z%d" % z, _zone_spot(z), str(z), 70.0)
		aux["spot_cb"] = func(id: String):
			if id.begins_with("z"):
				_submit({"m": aux["m"], "z": int(id.substr(1)), "env": aux["env"], "dbl": aux["dbl"]})
	build.call()


# ================================================================ zona 2

func _ui_z2(req: Dictionary) -> void:
	var e := engine
	var p: int = req["seat"]
	var opts: Dictionary = req["options"]
	aux["sel"] = ""
	var names := {"dev": "sviluppa il brevetto", "buy": "compra l'oggetto", "combo": "sviluppa e compra"}
	var build := func(): pass
	build = func():
		for c in prompt_box.get_children():
			c.queue_free()
		_ptitle("Ricerca e sviluppo: tocca una carta tecnologia o scegli l'azione. Il capo e gli specialisti n.2 pagano 2$ in meno.")
		for t in opts:
			if aux["sel"] != "" and aux["sel"] != t:
				continue
			for a in opts[t]:
				var tt: String = t
				var aa: String = a
				_pbtn("%s: %s (%d$)" % [D.ITEMS[t]["name"], names[a], opts[t][a]], func(): _submit({"a": aa, "t": tt}))
		if aux["sel"] != "":
			_pbtn("Tutte le carte", func():
				aux["sel"] = ""
				build.call())
		if req["can_res"]:
			_pbtn("Prenota la prossima carta", func(): _submit({"a": "res"}))
		_pbtn("Nessuna azione (-1 reputazione)", func(): _submit({"a": "none"}))
	for i in e.tech_slots.size():
		var t: String = e.tech_slots[i]
		if opts.has(t):
			_hot("t" + t, D.TECH_SLOTS[i], "", 150.0)
	aux["spot_cb"] = func(id: String):
		aux["sel"] = id.substr(1)
		board.hot_sel = id
		build.call()
	build.call()


func _ui_sat(req: Dictionary) -> void:
	aux["nums"] = []
	var dlg := _dialog("Rilevamento satellitare: scegli 2 carte tesoro", 760)
	var box: VBoxContainer = dlg["box"]
	box.add_child(UI.wrap(UI.label("Le carte satellite valgono come carte tesoro normali: danno accesso al sito, reddito e punti.", 19, UI.MUTED), 700))
	var fl := _flow()
	box.add_child(fl)
	var ok := UI.primary(UI.button("Conferma", 220, 56, 22))
	ok.disabled = true
	for k in req["pool"]:
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(110, 120)
		b.icon = UI.tex("res://assets/carte/satellite_%d.png" % k)
		b.expand_icon = true
		var kk: int = k
		b.toggled.connect(func(on):
			if on:
				aux["nums"].append(kk)
			else:
				aux["nums"].erase(kk)
			ok.disabled = aux["nums"].size() != 2)
		fl.add_child(b)
	ok.pressed.connect(func(): _submit({"nums": aux["nums"].duplicate()}))
	box.add_child(ok)


func _ui_dig(req: Dictionary) -> void:
	var dlg := _dialog("Sito %d: scegli in segreto la tessera" % req["site"], 1100)
	var box: VBoxContainer = dlg["box"]
	box.add_child(UI.wrap(UI.label("Sei il primo ad avere la carta di questo sito: delle tre tessere pescate ne tieni una (coperta, la vedono solo i possessori della carta); le altre tornano sotto la pila. La riga in alto è la superficie.", 19, UI.MUTED), 1040))
	var r := _row()
	box.add_child(r)
	for i in req["tiles"].size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(330, 280 if req["large"] else 270)
		b.icon = UI.site_tex(req["large"], req["tiles"][i])
		b.expand_icon = true
		var ii: int = i
		b.pressed.connect(func(): _submit({"i": ii}))
		r.add_child(b)


func _ui_reserve(req: Dictionary) -> void:
	var dlg := _dialog("Scegli la prossima tecnologia dal mazzo", 1200)
	var fl := _flow()
	dlg["box"].add_child(fl)
	for t in req["cards"]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 216)
		b.icon = UI.tech_tex(t)
		b.expand_icon = true
		b.tooltip_text = D.ITEMS[t]["name"]
		var tt: String = t
		b.pressed.connect(func(): _submit({"t": tt}))
		fl.add_child(b)


# ================================================================ zona 3

func _ui_z3(req: Dictionary) -> void:
	var e := engine
	_ptitle("Mercatino: compra una carta tesoro (tocca la carta sul tabellone). Il capo e gli specialisti n.3 pagano 2$ in meno.")
	var slots: Dictionary = req["slots"]
	for i in slots:
		var k: int = e.market[i][e.market[i].size() - 1]
		var ii: int = i
		_pbtn("Carta %d: %d$" % [k, slots[i]], func(): _submit({"slot": ii}))
		_hot("m%d" % i, Vector2(e.L["market_x"], e.L["market_y"][i]), "%d$" % slots[i], 62.0)
	_pbtn("Nessuna azione (-1 reputazione)", func(): _submit({"none": true}))
	aux["spot_cb"] = func(id: String): _submit({"slot": int(id.substr(1))})


# ================================================================ dotazione dei gommoni

## Editor della dotazione: righe per ogni oggetto, fra magazzino e gommone.
func _loadout_editor(box: VBoxContainer, p: int, z: Dictionary, items: Dictionary) -> void:
	var e := engine
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 6)
	box.add_child(holder)
	var redraw := func(): pass
	redraw = func():
		for c in holder.get_children():
			c.queue_free()
		var engines := 0
		for k in items:
			if D.ITEMS[k].get("engine", false):
				engines += items[k]
		holder.add_child(UI.wrap(UI.label("A bordo del gommone %s (al massimo 2 motori aggiuntivi: %d/2)" % [z["color"], engines], 19, UI.SAND), 700))
		var any := false
		for k in D.ITEM_ORDER:
			var tot: int = int(z["items"].get(k, 0)) + int(e.ps[p]["stock"].get(k, 0))
			if tot <= 0:
				continue
			any = true
			var r := _row()
			r.add_child(UI.icon_rect(UI.item_tex(k), Vector2(46, 46)))
			var nl := UI.label(D.ITEMS[k]["name"], 19, UI.TEXT)
			nl.custom_minimum_size.x = 250
			r.add_child(nl)
			var on: int = items.get(k, 0)
			var lb := UI.label("a bordo %d / magazzino %d" % [on, tot - on], 18, UI.MUTED)
			lb.custom_minimum_size.x = 220
			r.add_child(lb)
			var kk: String = k
			var bm := UI.button("Scarica", 0, 46, 18)
			bm.disabled = on <= 0
			bm.pressed.connect(func():
				items[kk] = on - 1
				if items[kk] <= 0:
					items.erase(kk)
				redraw.call())
			r.add_child(bm)
			var bp := UI.button("Carica", 0, 46, 18)
			bp.disabled = on >= tot or (D.ITEMS[k].get("engine", false) and engines >= 2)
			bp.pressed.connect(func():
				items[kk] = on + 1
				redraw.call())
			r.add_child(bp)
			holder.add_child(r)
		if not any:
			holder.add_child(UI.label("Nessun oggetto da caricare.", 19, UI.MUTED))
	redraw.call()


func _ui_plane(req: Dictionary) -> void:
	var e := engine
	var p: int = req["seat"]
	var ids: Array = req["zods"]
	aux["zod"] = ids[0]
	aux["swap"] = false
	var dlg := _dialog("Idrovolante nero (gratis)" if req.get("black", false) else "Idrovolante (%d$)" % req["cost"], 900)
	var box: VBoxContainer = dlg["box"]
	box.add_child(UI.wrap(UI.label("L'idrovolante raggiunge un tuo gommone in mare: puoi scambiare gli oggetti fra il magazzino e il gommone%s." % (" e scambiare il pilota con l'equipaggio" if req["swap"] else ""), 19, UI.MUTED), 840))
	var inner := VBoxContainer.new()
	box.add_child(inner)
	var build := func(): pass
	build = func():
		for c in inner.get_children():
			c.queue_free()
		if ids.size() > 1:
			var r := _row()
			r.add_child(UI.label("Gommone:", 19, UI.SAND))
			for id in ids:
				var z0: Dictionary = e.zod(id)
				var b := UI.button("%s (%s)" % [z0["color"], e.node_name(z0["loc"])], 0, 46, 18)
				b.toggle_mode = true
				b.button_pressed = id == aux["zod"]
				var iid: int = id
				b.pressed.connect(func():
					aux["zod"] = iid
					build.call())
				r.add_child(b)
			inner.add_child(r)
		var z: Dictionary = e.zod(aux["zod"])
		aux["items"] = z["items"].duplicate()
		_loadout_editor(inner, p, z, aux["items"])
		if req["swap"] and z["crew"] != -1:
			var sw := UI.button("Scambia il pilota con l'equipaggio (%s)" % _meeple_desc(e.meeple(p, z["crew"])).split(",")[0].to_lower(), 0, 50, 19)
			sw.toggle_mode = true
			sw.button_pressed = aux["swap"]
			sw.toggled.connect(func(on): aux["swap"] = on)
			inner.add_child(sw)
	build.call()
	var br := _row()
	var ok := UI.primary(UI.button("Vola", 200, 56, 22))
	ok.pressed.connect(func(): _submit({"zod": aux["zod"], "items": aux["items"].duplicate(), "swap": aux["swap"]}))
	br.add_child(ok)
	var no := UI.button("Rinuncia" + (" (-1 reputazione)" if req["swap"] else ""), 0, 56, 20)
	no.pressed.connect(func(): _submit({"none": true}))
	br.add_child(no)
	box.add_child(br)


# ================================================================ mare

func _node_pos(node: String) -> Vector2:
	if node.begins_with("D"):
		var k := engine.node_site(node)
		return D.dive_pos(engine.L["sites"][k], int(node.substr(node.find("_") + 1)))
	if node == "PORT":
		return Vector2(1060, 3750)
	return engine.L["nodes"].get(node, Vector2.ZERO)


func _ui_sea(req: Dictionary) -> void:
	var e := engine
	var z: Dictionary = e.zod(req["zod"])
	aux["first"] = false
	var dests: Dictionary = req["dests"]
	_ptitle("Gommone %s (%s): tocca la destinazione. Gratis le prime %d caselle, poi 1$ per ogni motore usato." % [z["color"], e.node_name(z["loc"]), e.move_profile(z)["free"]])
	for d in dests:
		if d == z["loc"]:
			continue
		var lbl := "%d$" % dests[d] if dests[d] > 0 else ""
		_hot("n" + d, _node_pos(d), lbl, 55.0 if d.begins_with("D") else 70.0, UI.TEAL_L if d.begins_with("D") else UI.GOLD_L)
	_hot("n" + z["loc"], _node_pos(z["loc"]), "qui", 60.0, UI.SAND)
	if req["can_dive_here"]:
		_ptoggle("Immergiti prima di muovere", false, func(on): aux["first"] = on)
	_pbtn("Resta qui", func(): _submit({"dest": z["loc"], "dive_first": aux["first"]}), true)
	if dests.has("PORT") and z["loc"] != "PORT":
		_pbtn("Torna in porto (%d$)" % dests["PORT"], func(): _submit({"dest": "PORT", "dive_first": aux["first"]}))
	aux["spot_cb"] = func(id: String): _submit({"dest": id.substr(1), "dive_first": aux["first"]})
	board.focus(_node_pos(z["loc"]), maxf(board.zoom, 0.32))


func _ui_dive(req: Dictionary) -> void:
	var e := engine
	var p: int = req["seat"]
	aux["take"] = []
	var take: int = req["take"]
	var dlg := _dialog("Immersione: scegli %s" % ("un tesoro" if take == 1 else "fino a due tesori (capo o specialista 5/7)"), 820)
	var box: VBoxContainer = dlg["box"]
	box.add_child(UI.wrap(UI.label("Scendendo affronti gli squali della colonna con l'attrezzatura a bordo. Gli oggetti con un costo d'uso si pagano dal conto Spese di missione.", 19, UI.MUTED), 760))
	var ok := UI.primary(UI.button("Immergiti", 220, 56, 22))
	ok.disabled = true
	for t in req["targets"]:
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(740, 64)
		b.icon = UI.chest_tex(t["v"])
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 52)
		var how := {"T": "", "N": " (serve il sonar: %d$)", "I": " (incastrato nella roccia: %d$)"}
		var extra: String = how[t["kind"]] % t["cost"] if t["kind"] != "T" else ""
		b.text = "Livello %d: tesoro di %s, %d$%s" % [t["r"] + 1, D.TREASURE_NAMES[t["v"]], t["v"], extra]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var rr: int = t["r"]
		b.toggled.connect(func(on):
			if on:
				aux["take"].append(rr)
				if aux["take"].size() > take:
					aux["take"].pop_front()
			else:
				aux["take"].erase(rr)
			for c in box.get_children():
				if c is Button and c.toggle_mode and c != b and c.has_meta("r"):
					c.set_pressed_no_signal(int(c.get_meta("r")) in aux["take"])
			ok.disabled = aux["take"].is_empty())
		b.set_meta("r", rr)
		box.add_child(b)
	var br := _row()
	ok.pressed.connect(func(): _submit({"take": aux["take"].duplicate()}))
	br.add_child(ok)
	var no := UI.button("Non recuperare nulla", 0, 56, 20)
	no.pressed.connect(func(): _submit({"take": []}))
	br.add_child(no)
	box.add_child(br)


# ================================================================ zona 7

func _ui_z7(req: Dictionary) -> void:
	var e := engine
	var p: int = req["seat"]
	var o: Dictionary = req["options"]
	var m: Dictionary = e.meeple(p, req["m"])
	_ptitle("Porto e laguna: compra un gommone, esci in laguna (un posto per gommone, solo per questo quadrimestre) oppure prendi il largo.")
	if o.has("shop"):
		for s in o["shop"]:
			var ii: int = s["i"]
			_pbtn("Compra un gommone (%d$, +1 reputazione)" % s["cost"], func(): _submit({"a": "shop", "i": ii}))
			_hot("s%d" % ii, D.SHOP[ii], "%d$" % s["cost"], 60.0)
	if o.has("zods"):
		var zid: int = o["zods"][0]
		var full := {}
		var z0: Dictionary = e.zod(zid)
		for k in z0["items"]:
			full[k] = z0["items"][k]
		for k in e.ps[p]["stock"]:
			full[k] = full.get(k, 0) + e.ps[p]["stock"][k]
		if o.has("lagoon"):
			var island_done := false
			for spot in o["lagoon"]:
				if spot.begins_with("isola"):
					if island_done:
						continue
					island_done = true
				var g: int = e.lagoon_gain(spot, full, e.expert(m, 7))
				if g < 0:
					continue
				var txt: String = D.LAGOON[spot]["name"] + (" (+%d$)" % g if g > 0 else " (oggetto a caso)")
				var ss: String = spot
				_pbtn("Laguna: " + txt, func(): _z7_launch(req, "lagoon", ss))
				_hot("l" + spot, D.LAGOON_POS[spot], "+%d$" % g if g > 0 else "", 60.0, UI.TEAL_L)
		_pbtn("Prendi il largo", func(): _z7_launch(req, "sea", ""), true)
		_hot("port", Vector2(1060, 3750), "al largo", 70.0)
	_pbtn("Nessuna azione (-1 reputazione)", func(): _submit({"a": "none"}))
	aux["spot_cb"] = func(id: String):
		if id.begins_with("s"):
			_submit({"a": "shop", "i": int(id.substr(1))})
		elif id.begins_with("l"):
			_z7_launch(req, "lagoon", id.substr(1))
		elif id == "port":
			_z7_launch(req, "sea", "")


func _z7_launch(req: Dictionary, a: String, spot: String) -> void:
	var e := engine
	var p: int = req["seat"]
	var ids: Array = req["options"]["zods"]
	aux["zod"] = ids[0]
	var dlg := _dialog("Dotazione del gommone" if a == "sea" else "Laguna: %s" % D.LAGOON[spot]["name"], 900)
	var box: VBoxContainer = dlg["box"]
	box.add_child(UI.wrap(UI.label("In porto puoi caricare e scaricare liberamente gli oggetti. In mare servono: maschera, bombola o scafandro per scendere, arpione, fucile o gabbia contro gli squali, sonar per i tesori nascosti, trapano o martello per quelli incastrati, motori per andare lontano.", 19, UI.MUTED), 840))
	var inner := VBoxContainer.new()
	box.add_child(inner)
	var build := func(): pass
	build = func():
		for c in inner.get_children():
			c.queue_free()
		if ids.size() > 1:
			var r := _row()
			r.add_child(UI.label("Gommone:", 19, UI.SAND))
			for id in ids:
				var b := UI.button(e.zod(id)["color"], 0, 46, 18)
				b.toggle_mode = true
				b.button_pressed = id == aux["zod"]
				var iid: int = id
				b.pressed.connect(func():
					aux["zod"] = iid
					build.call())
				r.add_child(b)
			inner.add_child(r)
		var z: Dictionary = e.zod(aux["zod"])
		var items: Dictionary = z["items"].duplicate()
		# proposta: tutto il necessario a bordo
		if a == "sea" or spot != "":
			for k in e.ps[p]["stock"]:
				var cap: int = e.ps[p]["stock"][k]
				if D.ITEMS[k].get("engine", false):
					var eng := 0
					for x in items:
						if D.ITEMS[x].get("engine", false):
							eng += items[x]
					cap = mini(cap, 2 - eng)
				if cap > 0:
					items[k] = items.get(k, 0) + cap
		aux["items"] = items
		_loadout_editor(inner, p, z, items)
	build.call()
	var br := _row()
	var ok := UI.primary(UI.button("Parti" if a == "sea" else "Vai", 200, 56, 22))
	ok.pressed.connect(func():
		var r := {"a": a, "zod": aux["zod"], "items": aux["items"].duplicate()}
		if a == "lagoon":
			r["spot"] = spot
			var m: Dictionary = e.meeple(p, req["m"])
			if e.lagoon_gain(spot, aux["items"], e.expert(m, 7)) < 0:
				toast("Manca l'attrezzatura per questo posto della laguna.", UI.CORAL)
				return
		_submit(r))
	br.add_child(ok)
	var back := UI.button("Indietro", 0, 56, 20)
	back.pressed.connect(func(): dlg["root"].queue_free())
	br.add_child(back)
	box.add_child(br)


func _ui_island(req: Dictionary) -> void:
	var dlg := _dialog("Isola: il capo (o lo specialista 5/7) ne guarda due e ne tiene uno", 760)
	var r := _row()
	dlg["box"].add_child(r)
	for i in req["tiles"].size():
		var o: Dictionary = D.ISLAND[req["objs"][i]]
		var b := Button.new()
		b.custom_minimum_size = Vector2(340, 300)
		var ikey: String = o["k"] if not o.has("item") else o["item"]
		b.icon = UI.tex("res://assets/isola/%s.png" % ikey) if not o.has("item") else UI.item_tex(o["item"])
		b.expand_icon = true
		b.text = o["name"]
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		var t: int = req["tiles"][i]
		b.pressed.connect(func(): _submit({"i": t}))
		r.add_child(b)


# ================================================================ zona 8

func _ui_z8(req: Dictionary) -> void:
	var e := engine
	var p: int = req["seat"]
	var o: Dictionary = req["options"]
	aux["v"] = 0
	var build := func(): pass
	build = func():
		for c in prompt_box.get_children():
			c.queue_free()
		board.hot = {}
		_ptitle("Museo: finanzia una sala oppure vendi un tesoro (lo esponi in una sala finanziata o lo metti in deposito). Le sale piene si aprono al pubblico.")
		if aux["v"] == 0:
			for i in o["sponsor"]:
				var cfg: Dictionary = e.rooms[i]["cfg"]
				var ii: int = i
				_pbtn("Finanzia la sala %d (%d$, %d posti, apertura +%d)" % [i + 1, o["sponsor"][i], cfg["vp"].size(), cfg["rp"]], func(): _submit({"a": "sponsor", "room": ii}))
				_hot("r%d" % i, cfg["door"], "%d$" % o["sponsor"][i], 70.0)
			if not o["sell"].is_empty():
				var seen := {}
				for v in e.ps[p]["treasures"]:
					if seen.has(v):
						continue
					seen[v] = true
					var vv: int = v
					_pbtn("Vendi un tesoro di %s (%d$)" % [D.TREASURE_NAMES[v], v + o["bonus"]], func():
						aux["v"] = vv
						build.call(), true)
		else:
			for i in o["sell"]:
				var ii: int = i
				if i == -1:
					_pbtn("In deposito (1 punto)", func(): _submit({"a": "sell", "v": aux["v"], "room": -1}))
					_hot("r-1", e.L["storage"], "deposito", 70.0, UI.SAND)
				else:
					var k := e.room_free_slot(i)
					var cfg: Dictionary = e.rooms[i]["cfg"]
					_pbtn("Sala %d: posto da %d punti" % [i + 1, cfg["vp"][k]], func(): _submit({"a": "sell", "v": aux["v"], "room": ii}))
					_hot("r%d" % i, cfg["spots"][k], "%d punti" % cfg["vp"][k], 60.0, UI.TEAL_L)
			_pbtn("Indietro", func():
				aux["v"] = 0
				build.call())
		_pbtn("Nessuna azione (-1 reputazione)", func(): _submit({"a": "none"}))
	aux["spot_cb"] = func(id: String):
		var i := int(id.substr(1))
		if aux["v"] == 0:
			if o["sponsor"].has(i):
				_submit({"a": "sponsor", "room": i})
		else:
			_submit({"a": "sell", "v": aux["v"], "room": i})
	build.call()


# ================================================================ zona 10

func _ui_bid(req: Dictionary) -> void:
	var mx: int = req["max"]
	aux["bid"] = mini(mx, 2)
	var dlg := _dialog("Busta sotto il tavolo", 700)
	var box: VBoxContainer = dlg["box"]
	box.add_child(UI.wrap(UI.label("Offerta segreta dalla cassa nera (minimo 2$, hai %d$). Le offerte si pagano tutte; il nuovo ordine di turno va dall'offerta più alta, a parità vince chi ha depositato prima la busta. A fine anno l'ordine di turno dà reputazione." % mx, 19, UI.MUTED), 640))
	var r := _row()
	var v := UI.label("", 40, UI.GOLD_L, UI.font_bold)
	v.custom_minimum_size.x = 120
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var upd := func(): v.text = "%d$" % aux["bid"]
	for d in [-5, -1]:
		var b := UI.button(str(d), 70, 56, 22)
		b.pressed.connect(func():
			aux["bid"] = clampi(aux["bid"] + d, 2, mx)
			upd.call())
		r.add_child(b)
	r.add_child(v)
	for d in [1, 5]:
		var b := UI.button("+%d" % d, 70, 56, 22)
		b.pressed.connect(func():
			aux["bid"] = clampi(aux["bid"] + d, 2, mx)
			upd.call())
		r.add_child(b)
	var all := UI.button("Tutto", 100, 56, 20)
	all.pressed.connect(func():
		aux["bid"] = mx
		upd.call())
	r.add_child(all)
	box.add_child(r)
	upd.call()
	var br := _row()
	var ok := UI.primary(UI.button("Offri", 200, 56, 22))
	ok.pressed.connect(func(): _submit({"bid": aux["bid"]}))
	br.add_child(ok)
	var no := UI.button("Ritira la busta (-1 reputazione)", 0, 56, 20)
	no.pressed.connect(func(): _submit({"bid": 0}))
	br.add_child(no)
	box.add_child(br)


# ================================================================ variante: mercenari

func _ui_merc_bid(req: Dictionary) -> void:
	var e := engine
	var mx: int = req["max"]
	var high: int = req["high"]
	aux["bid"] = high + 1
	var dlg := _dialog("Asta per un mercenario", 760)
	var box: VBoxContainer = dlg["box"]
	var who: String = ("Offerta più alta: %d$ di %s." % [high, e.pname(req["by"])]) if req["by"] >= 0 else "Ancora nessuna offerta."
	box.add_child(UI.wrap(UI.label("%s Rilanci dalla cassa nera (hai %d$) oppure passi: chi passa esce dall'asta. Paga solo chi vince." % [who, mx], 20, UI.SAND), 700))
	var zl := []
	for z in req["zones"]:
		zl.append("%d %s (%s)" % [z, D.ZONE_NAMES[z], D.MERC_SHORT[z]])
	box.add_child(UI.wrap(UI.label("Dove può ancora colpire un mercenario: " + "; ".join(zl) + ".", 18, UI.MUTED), 700))
	var r := _row()
	var v := UI.label("", 40, UI.GOLD_L, UI.font_bold)
	v.custom_minimum_size.x = 120
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var upd := func(): v.text = "%d$" % aux["bid"]
	for d in [-5, -1]:
		var b := UI.button(str(d), 70, 56, 22)
		b.pressed.connect(func():
			aux["bid"] = clampi(aux["bid"] + d, high + 1, mx)
			upd.call())
		r.add_child(b)
	r.add_child(v)
	for d in [1, 5]:
		var b := UI.button("+%d" % d, 70, 56, 22)
		b.pressed.connect(func():
			aux["bid"] = clampi(aux["bid"] + d, high + 1, mx)
			upd.call())
		r.add_child(b)
	box.add_child(r)
	upd.call()
	var br := _row()
	var ok := UI.primary(UI.button("Rilancia", 200, 56, 22))
	ok.disabled = high + 1 > mx
	ok.pressed.connect(func(): _submit({"bid": aux["bid"]}))
	br.add_child(ok)
	var no := UI.button("Passa", 160, 56, 20)
	no.pressed.connect(func(): _submit({"bid": 0}))
	br.add_child(no)
	box.add_child(br)


func _ui_merc2(req: Dictionary) -> void:
	var e := engine
	var dlg := _dialog("Il mercenario ruba un brevetto", 1200)
	dlg["box"].add_child(UI.wrap(UI.label("Scegli una carta tecnologia scoperta: il brevetto diventa tuo (royalty e punti di fine partita) e, se ne resta una copia, prendi anche l'oggetto.", 19, UI.MUTED), 1140))
	var fl := _flow()
	dlg["box"].add_child(fl)
	for t in req["techs"]:
		var v := VBoxContainer.new()
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 216)
		b.icon = UI.tech_tex(t)
		b.expand_icon = true
		var tt: String = t
		b.pressed.connect(func(): _submit({"t": tt}))
		v.add_child(b)
		var own: int = e.tech_owner[t]
		v.add_child(UI.wrap(UI.label("%s\n%s" % [D.ITEMS[t]["name"], ("di " + e.pname(own)) if own >= 0 and own < e.n else "libero"], 16, UI.SAND), 150))
		fl.add_child(v)


func _ui_merc3(req: Dictionary) -> void:
	aux["nums"] = []
	var dlg := _dialog("Il mercenario ruba 2 carte tesoro", 760)
	var box: VBoxContainer = dlg["box"]
	box.add_child(UI.wrap(UI.label("Le carte del mercenario aprono i loro siti di scavo come le altre e in più, lì, i tesori nascosti si prendono senza sonar.", 19, UI.MUTED), 700))
	var fl := _flow()
	box.add_child(fl)
	var ok := UI.primary(UI.button("Conferma", 220, 56, 22))
	ok.disabled = true
	for k in req["pool"]:
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(110, 120)
		b.icon = UI.card_tex(k)
		b.expand_icon = true
		var kk: int = k
		b.toggled.connect(func(on):
			if on:
				aux["nums"].append(kk)
			else:
				aux["nums"].erase(kk)
			ok.disabled = aux["nums"].size() != mini(2, req["pool"].size()))
		fl.add_child(b)
	ok.pressed.connect(func(): _submit({"nums": aux["nums"].duplicate()}))
	box.add_child(ok)


func _museum_spot_pos(id: String) -> Vector2:
	var e := engine
	if id.begins_with("s"):
		var k := int(id.substr(1))
		return e.L["storage"] + Vector2((k % 3) * 46 - 46, -60 + int(k / 3) * 40)
	var a := id.substr(1).split("_")
	return e.rooms[int(a[0])]["cfg"]["spots"][int(a[1])]


func _ui_merc8(req: Dictionary) -> void:
	var e := engine
	aux["x"] = ""
	var build := func(): pass
	build = func():
		for c in prompt_box.get_children():
			c.queue_free()
		board.hot = {}
		if aux["x"] == "":
			_ptitle("Il mercenario nel museo: tocca un tesoro da spostare in un posto libero o da scambiare con un altro. Una sala che resta con un buco si richiude e chi l'ha aperta perde i punti dell'apertura.")
			for id in req["spots"]:
				_hot(id, _museum_spot_pos(id), "", 44.0, UI.CORAL)
		else:
			_ptitle("Ora tocca il posto libero dove spostarlo, oppure un altro tesoro con cui scambiarlo.")
			for id in req["free"]:
				_hot("to:" + id, _museum_spot_pos(id), "", 44.0, UI.TEAL_L)
			for id in req["spots"]:
				if id != aux["x"]:
					_hot("sw:" + id, _museum_spot_pos(id), "", 44.0, UI.GOLD_L)
			_pbtn("Scegli un altro tesoro", func():
				aux["x"] = ""
				build.call())
		_pbtn("Il mercenario non fa nulla", func(): _submit({"a": "none"}))
		_dirty = true
	aux["spot_cb"] = func(id: String):
		if aux["x"] == "":
			aux["x"] = id
			build.call()
		elif id.begins_with("to:"):
			_submit({"a": "move", "x": aux["x"], "to": id.substr(3)})
		elif id.begins_with("sw:"):
			_submit({"a": "swap", "x": aux["x"], "y": id.substr(3)})
	build.call()
	board.focus(Vector2(450, 1500), maxf(board.zoom, 0.4))


func _ui_mine(req: Dictionary) -> void:
	var e := engine
	var opts: Dictionary = req["options"]
	aux["site"] = -1
	var build := func(): pass
	build = func():
		for c in prompt_box.get_children():
			c.queue_free()
		board.hot = {}
		if aux["site"] < 0:
			_ptitle("Hai la mina subacquea: tocca un sito per farla esplodere (copre 3x3 caselle sotto la superficie: uccide gli squali, che diventano tuoi, e distrugge i tesori). Puoi anche tenerla per dopo.")
			for k in opts:
				_hot("k%d" % k, e.L["sites"][k]["c"], "Sito %d" % k, 140.0, UI.CORAL)
		else:
			_ptitle("Sito %d: quali colonne copre la mina?" % aux["site"])
			for c0 in opts[aux["site"]]:
				var cc: int = c0
				_pbtn("Colonne %d-%d" % [c0 + 1, c0 + 3], func(): _submit({"site": aux["site"], "col": cc}), true)
			_pbtn("Un altro sito", func():
				aux["site"] = -1
				build.call())
		_pbtn("Tienila per dopo", func(): _submit({"none": true}))
		_dirty = true
	aux["spot_cb"] = func(id: String):
		if id.begins_with("k"):
			aux["site"] = int(id.substr(1))
			build.call()
	build.call()


# ================================================================ finestre varie

func _company_popup(p: int) -> void:
	var e := engine
	if not pending.is_empty() and pending["type"] in ["budget", "dive", "bid"]:
		return
	var dlg := _dialog("%s · %s" % [D.COLORS[e.pcol(p)]["company"], e.pname(p)], 900)
	var box: VBoxContainer = dlg["box"]
	var pl := UI.icon_rect(UI.tex("res://assets/plancia/plancia.jpg"), Vector2(840, 300))
	box.add_child(pl)
	var lines := []
	lines.append("Reputazione: %d" % e.ps[p]["rep"])
	var secret: bool = not (p in humans) and e.phase != "over"
	var accs := []
	for a in D.ACCOUNTS:
		accs.append("%s %s" % [D.ACC_SHORT[a], "?" if (a == "bc" and secret) else str(e.ps[p]["acc"][a]) + "$"])
	lines.append("Conti: " + ", ".join(accs))
	lines.append("Lavoratori assunti: %d (ancora da assumere %d)" % [e.workers(p), e.reserve_left(p)])
	var pats := []
	for t in e.tech_owner:
		if e.tech_owner[t] == p:
			pats.append(D.ITEMS[t]["name"])
	lines.append("Brevetti: " + (", ".join(pats) if not pats.is_empty() else "nessuno"))
	var tv := []
	for v in e.ps[p]["treasures"]:
		tv.append("%s (%d$)" % [D.TREASURE_NAMES[v], v])
	lines.append("Tesori in sede: " + (", ".join(tv) if not tv.is_empty() else "nessuno"))
	lines.append("Carte tesoro: " + (", ".join(e.ps[p]["cards"].map(func(x): return str(x))) if not e.ps[p]["cards"].is_empty() else "nessuna"))
	lines.append("Squali uccisi: %d" % e.ps[p]["sharks"])
	for z in e.zods_of(p):
		var its := []
		for k in z["items"]:
			its.append(D.ITEMS[k]["name"] + ("" if z["items"][k] == 1 else " x%d" % z["items"][k]))
		lines.append("Gommone %s, %s: %s" % [z["color"], _zod_where(z), ", ".join(its) if not its.is_empty() else "solo costume e lenza"])
	for l in lines:
		box.add_child(UI.wrap(UI.label(l, 20, UI.TEXT), 840))
	var cl := UI.button("Chiudi", 200, 54, 20)
	cl.pressed.connect(func(): dlg["root"].queue_free())
	box.add_child(cl)


func _show_rules() -> void:
	var t := preload("res://scripts/ui/rules_view.gd").new()
	t.main = main
	t.popup = true
	popup_layer.add_child(t)


func _ask_menu() -> void:
	var dlg := _dialog("Tornare al menu?", 640)
	var box: VBoxContainer = dlg["box"]
	box.add_child(UI.wrap(UI.label("La partita in corso si chiude." + (" Online puoi rientrare con lo stesso codice." if engine.online != null else " Se vuoi riprenderla più tardi, salvala prima con «Salva»."), 20, UI.SAND), 580))
	var r := _row()
	var y := UI.primary(UI.button("Torna al menu", 0, 56, 20))
	y.pressed.connect(func(): main.show_menu())
	r.add_child(y)
	var n := UI.button("Continua a giocare", 0, 56, 20)
	n.pressed.connect(func(): dlg["root"].queue_free())
	r.add_child(n)
	box.add_child(r)


func _save_game() -> void:
	if engine.online != null:
		toast("La partita online è già salvata nella stanza: per rientrare usa il codice della stanza.", UI.TEAL_L)
		return
	var cfg := config.duplicate(true)
	cfg.erase("online")
	cfg.erase("replay")
	var data := {"cfg": var_to_str(cfg), "moves": var_to_str(engine.record), "label": "Anno %d, quadrimestre %d" % [engine.year, engine.period],
		"names": ", ".join(range(engine.n).map(func(x): return engine.pname(x)))}
	toast("Salvataggio in corso…", UI.SAND)
	var net: Net = main.get_net()
	var code := await net.save_game(data, save_code)
	if code == "":
		toast("Salvataggio non riuscito: %s" % net.last_error, UI.CORAL)
		return
	save_code = code
	var dlg := _dialog("Partita salvata", 640)
	dlg["box"].add_child(UI.wrap(UI.label("Per riprenderla scegli «Carica partita» nel menu e scrivi questo codice (vale da qualsiasi dispositivo):", 20, UI.SAND), 580))
	dlg["box"].add_child(UI.title(code, 64))
	var cl := UI.button("Chiudi", 200, 54, 20)
	cl.pressed.connect(func(): dlg["root"].queue_free())
	dlg["box"].add_child(cl)


func _on_end(res: Dictionary) -> void:
	_clear_prompt()
	if engine.online != null:
		engine.online.finish()
	board.viewer = -1
	_dirty = true
	var e := engine
	var dlg := _dialog("Fine della partita", 1100)
	var box: VBoxContainer = dlg["box"]
	if e.solo:
		var ok: bool = res.get("solo_win", false)
		box.add_child(UI.title("Obiettivo raggiunto!" if ok else "Obiettivo mancato", 44, UI.GOLD_L if ok else UI.CORAL))
		box.add_child(UI.wrap(UI.label("Reputazione finale %d%s. Per vincere servono tutte le sale del museo aperte e più di 80 punti; il bonus va da +30 (entro il 6º quadrimestre) a +0." % [res["scores"][0]["totale"],
			(", bonus %d: totale %d" % [res["solo_bonus"], res["solo_total"]]) if ok else ""], 21, UI.SAND), 1040))
	else:
		box.add_child(UI.title("Vince %s!" % e.pname(res["winner"]), 44))
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	var heads := ["", "Reputazione", "Tesori", "Brevetti", "Squali", "Carte", "Denaro", "Influenza", "Totale"]
	for h in heads:
		grid.add_child(UI.label(h, 18, UI.MUTED, UI.font_semi))
	for p in res["ranking"]:
		var s: Dictionary = res["scores"][p]
		var nm := UI.label(e.pname(p), 20, UI.pcolor(e, p).lightened(0.25), UI.font_bold)
		nm.custom_minimum_size.x = 180
		grid.add_child(nm)
		for k in ["rep", "tesori", "brevetti", "squali", "carte", "denaro", "influenza", "totale"]:
			var l := UI.label(str(s[k]), 21 if k != "totale" else 24, UI.TEXT if k != "totale" else UI.GOLD_L, UI.font_bold if k == "totale" else UI.font_semi)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			grid.add_child(l)
	var r := _row()
	var again := UI.primary(UI.button("Nuova partita", 0, 56, 22))
	again.pressed.connect(func(): main.show_menu())
	r.add_child(again)
	var look := UI.button("Guarda il tabellone", 0, 56, 20)
	look.pressed.connect(func(): dlg["root"].queue_free())
	r.add_child(look)
	box.add_child(r)
	if tut and not tut_seen.has("fine"):
		tut_seen["fine"] = true
		show_lesson(Tutorial.LESSONS["fine"], 0, func(): pass)


# ================================================================ tutorial e consiglio del tutor

func _toggle_tutor() -> void:
	tutor_on = not tutor_on
	if tutor_btn != null:
		tutor_btn.button_pressed = tutor_on
	if tutor_on and not pending.is_empty():
		_tutor_show(pending)
	elif tutor_panel != null:
		tutor_panel.visible = false


## Lezione a pagine; alla chiusura chiama then.
func show_lesson(pages: Array, i: int, then: Callable) -> void:
	var dlg := _dialog(pages[i][0], 1000)
	var box: VBoxContainer = dlg["box"]
	dlg["root"].z_index = 40
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(940, 0)
	rt.add_theme_font_size_override("normal_font_size", 23)
	rt.add_theme_font_size_override("bold_font_size", 23)
	rt.text = pages[i][1]
	box.add_child(rt)
	var h := _row()
	if i > 0:
		var b0 := UI.button("Indietro", 180, 56, 21)
		b0.pressed.connect(func():
			dlg["root"].queue_free()
			show_lesson(pages, i - 1, then))
		h.add_child(b0)
	var cnt := UI.label("Pagina %d di %d" % [i + 1, pages.size()] if pages.size() > 1 else "", 19, UI.MUTED)
	cnt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cnt.custom_minimum_size.x = 200
	h.add_child(cnt)
	var nx := UI.primary(UI.button("Avanti" if i < pages.size() - 1 else "Ho capito", 220, 56, 22))
	nx.pressed.connect(func():
		dlg["root"].queue_free()
		if i < pages.size() - 1:
			show_lesson(pages, i + 1, then)
		else:
			then.call())
	h.add_child(nx)
	box.add_child(h)


func _tutor_show(req: Dictionary) -> void:
	if not tutor_on or engine.online != null or tutor_panel == null:
		return
	for c in tutor_box.get_children():
		c.queue_free()
	var p: int = req["seat"]
	var r = tutor_ai.decide(engine, p, req)
	var adv: Array = Tutorial.advice(engine, p, req, r)
	if str(adv[0]) == "":
		tutor_panel.visible = false
		return
	var hd := _row()
	var tl := UI.heading("Consiglio del tutor", 22, UI.GOLD_L)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hd.add_child(tl)
	var hide := UI.button("Nascondi", 0, 40, 17)
	hide.pressed.connect(func(): tutor_panel.visible = false)
	hd.add_child(hide)
	tutor_box.add_child(hd)
	tutor_box.add_child(UI.wrap(UI.label(str(adv[0]), 20, UI.TEXT, UI.font_bold), SIDE_W - 50))
	if str(adv[1]) != "":
		tutor_box.add_child(UI.wrap(UI.label(str(adv[1]), 19, UI.SAND, UI.font_body), SIDE_W - 50))
	var h := _row()
	var fol := UI.primary(UI.button("Segui il consiglio", 0, 50, 19))
	fol.pressed.connect(func():
		if pending == req:
			_submit(r))
	h.add_child(fol)
	if Tutorial.LESSONS.has(req["type"]):
		var lb := UI.button("Rivedi la lezione", 0, 50, 18)
		lb.pressed.connect(func(): show_lesson(Tutorial.LESSONS[req["type"]], 0, func(): pass))
		h.add_child(lb)
	tutor_box.add_child(h)
	tutor_panel.visible = true
	tutor_panel.offset_bottom = tutor_panel.offset_top
	_shrink_tutor()


## Il riquadro si adatta al testo: due cicli dopo, quando le etichette conoscono la loro altezza.
func _shrink_tutor() -> void:
	for k in 2:
		await get_tree().process_frame
		if is_instance_valid(tutor_panel):
			tutor_panel.offset_bottom = tutor_panel.offset_top
			tutor_panel.size = Vector2(tutor_panel.size.x, 0)
