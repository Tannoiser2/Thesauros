extends Control
## Tabellone 2D: l'immagine originale del lato in uso con sopra tutti i pezzi, disegnati dal codice.
## Si sposta trascinando (mouse o un dito), si ingrandisce con la rotella o pizzicando con due dita,
## si ruota con due dita (o con i pulsanti). Le zone selezionabili della decisione in corso sono
## evidenziate e si scelgono toccandole.

const D = preload("res://scripts/data/th_data.gd")

signal spot_pressed(id: String)

var e                            # THEngine
var tex_board: Texture2D
var zoom := 0.2
var rot := 0.0
var pan := Vector2.ZERO          # posizione sullo schermo del centro del tabellone
var hot := {}                    # id -> {pos: Vector2 (tabellone), r: raggio, label: String}
var hot_sel := ""
var viewer := -1                 # chi guarda (per le tessere coperte che conosce)
var flash := {}                  # evidenziazioni temporanee: id -> tempo
var _touches := {}
var _drag_from := Vector2.ZERO
var _dragging := false
var _press_pos := Vector2.ZERO
var _pinch := {}
var _fitted := false
var flat_only := false           # disegno piatto per la trama della vista 3D: niente gommoni né meeple

const MEEPLE := [Vector2(0, -0.5), Vector2(0.13, -0.46), Vector2(0.18, -0.34), Vector2(0.14, -0.22), Vector2(0.45, -0.12),
	Vector2(0.48, 0.0), Vector2(0.24, 0.07), Vector2(0.4, 0.5), Vector2(0.1, 0.5), Vector2(0, 0.28), Vector2(-0.1, 0.5),
	Vector2(-0.4, 0.5), Vector2(-0.24, 0.07), Vector2(-0.48, 0.0), Vector2(-0.45, -0.12), Vector2(-0.14, -0.22),
	Vector2(-0.18, -0.34), Vector2(-0.13, -0.46)]
const HAT_COL := {2: Color("#5b86d6"), 3: Color("#e23c2c"), 57: Color("#6f8a2a"), 8: Color("#6e1a1a")}


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_on_resized)


func setup(eng) -> void:
	e = eng
	tex_board = UI.tex("res://assets/tabellone/tabellone_%s.jpg" % e.side)
	queue_redraw()


func _on_resized() -> void:
	if not _fitted and size.x > 10:
		fit()
	queue_redraw()


## Mostra tutto il tabellone.
func fit() -> void:
	rot = 0.0
	zoom = minf(size.x / D.BOARD_W, size.y / D.BOARD_H) * 0.98
	pan = size * 0.5
	queue_redraw()


## Inquadra un punto del tabellone con l'ingrandimento dato.
func focus(p: Vector2, z := -1.0) -> void:
	_fitted = true
	if z > 0:
		zoom = z
	pan = size * 0.5 - _xf_basis(p - Vector2(D.BOARD_W, D.BOARD_H) * 0.5)
	queue_redraw()


func _xf_basis(v: Vector2) -> Vector2:
	return v.rotated(rot) * zoom


func board_to_screen(p: Vector2) -> Vector2:
	return pan + _xf_basis(p - Vector2(D.BOARD_W, D.BOARD_H) * 0.5)


func screen_to_board(s: Vector2) -> Vector2:
	return (s - pan).rotated(-rot) / zoom + Vector2(D.BOARD_W, D.BOARD_H) * 0.5


func _zoom_at(s: Vector2, factor: float) -> void:
	_fitted = true
	var b := screen_to_board(s)
	zoom = clampf(zoom * factor, 0.08, 2.5)
	pan += s - board_to_screen(b)
	queue_redraw()


func rotate_by(a: float) -> void:
	_fitted = true
	var c := size * 0.5
	var b := screen_to_board(c)
	rot = wrapf(rot + a, -PI, PI)
	pan += c - board_to_screen(b)
	queue_redraw()


# ================================================================ input (mouse, trackpad, tocco)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenDrag or ev is InputEventMagnifyGesture or ev is InputEventPanGesture or (ev is InputEventMouseButton and ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]) or (ev is InputEventMouseMotion and ev.button_mask != 0):
		_fitted = true
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_touches[ev.index] = ev.position
			if _touches.size() == 1:
				_press_pos = ev.position
				_dragging = false
			_pinch = {}
		else:
			var was_tap: bool = _touches.size() == 1 and not _dragging and ev.position.distance_to(_press_pos) < 14.0
			_touches.erase(ev.index)
			_pinch = {}
			if was_tap:
				_click(ev.position)
		accept_event()
		return
	if ev is InputEventScreenDrag:
		_touches[ev.index] = ev.position
		if _touches.size() == 1:
			if ev.position.distance_to(_press_pos) > 10.0:
				_dragging = true
			if _dragging:
				pan += ev.relative
				queue_redraw()
		elif _touches.size() >= 2:
			_dragging = true
			var keys := _touches.keys()
			var a: Vector2 = _touches[keys[0]]
			var b: Vector2 = _touches[keys[1]]
			var mid := (a + b) * 0.5
			var d := a.distance_to(b)
			var ang := (b - a).angle()
			if not _pinch.is_empty():
				var f: float = d / maxf(1.0, _pinch["d"])
				var bp := screen_to_board(_pinch["mid"])
				zoom = clampf(zoom * f, 0.08, 2.5)
				rot = wrapf(rot + (ang - _pinch["ang"]), -PI, PI)
				pan += mid - board_to_screen(bp)
				queue_redraw()
			_pinch = {"d": d, "ang": ang, "mid": mid}
		accept_event()
		return
	if ev is InputEventMagnifyGesture:
		_zoom_at(ev.position, ev.factor)
		accept_event()
		return
	if ev is InputEventPanGesture:
		pan -= ev.delta * 12.0
		queue_redraw()
		accept_event()
		return
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			_zoom_at(ev.position, 1.12)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			_zoom_at(ev.position, 1.0 / 1.12)
		elif ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			if ev.pressed:
				_drag_from = ev.position
				_press_pos = ev.position
				_dragging = false
			else:
				if not _dragging and ev.button_index == MOUSE_BUTTON_LEFT and ev.position.distance_to(_press_pos) < 8.0 and _touches.is_empty():
					_click(ev.position)
				_dragging = false
		accept_event()
	elif ev is InputEventMouseMotion and ev.button_mask != 0 and _touches.is_empty():
		if ev.position.distance_to(_press_pos) > 8.0:
			_dragging = true
		if _dragging:
			if ev.button_mask & MOUSE_BUTTON_MASK_RIGHT:
				rot = wrapf(rot + ev.relative.x * 0.005, -PI, PI)
			else:
				pan += ev.relative
			queue_redraw()
		accept_event()


func _click(s: Vector2) -> void:
	if hot.is_empty():
		return
	var b := screen_to_board(s)
	var best := ""
	var bd := 1e9
	for id in hot:
		var h: Dictionary = hot[id]
		var r: float = maxf(h.get("r", 60.0), 28.0 / zoom)
		var dd: float = b.distance_to(h["pos"])
		if dd < r and dd < bd:
			bd = dd
			best = id
	if best != "":
		spot_pressed.emit(best)


# ================================================================ disegno

var _last_size := Vector2.ZERO


func _draw() -> void:
	if flat_only:
		zoom = size.x / D.BOARD_W
		rot = 0.0
		pan = size * 0.5
	elif not _fitted and size != _last_size and size.x > 10:
		_last_size = size
		zoom = minf(size.x / D.BOARD_W, size.y / D.BOARD_H) * 0.98
		pan = size * 0.5
		rot = 0.0
	draw_rect(Rect2(Vector2.ZERO, size), Color("#031218"))
	if e == null or tex_board == null:
		return
	var xf := Transform2D(rot, Vector2(zoom, zoom), 0.0, pan) * Transform2D(0.0, -Vector2(D.BOARD_W, D.BOARD_H) * 0.5)
	draw_set_transform_matrix(xf)
	draw_rect(Rect2(-12, -12, D.BOARD_W + 24, D.BOARD_H + 24), Color(0, 0, 0, 0.5))
	draw_texture_rect(tex_board, Rect2(0, 0, D.BOARD_W, D.BOARD_H), false)
	_draw_tech()
	_draw_market()
	_draw_museum()
	_draw_tracks()
	_draw_sites()
	_draw_island()
	_draw_mercs()
	if not flat_only:
		_draw_zodiacs()
		_draw_queues()
	_draw_hot()
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _font() -> Font:
	return UI.font_bold


func _text_c(p: Vector2, t: String, sz: int, col: Color, outline := Color(0, 0, 0, 0.85)) -> void:
	var f := _font()
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	draw_string_outline(f, p + Vector2(-w * 0.5, sz * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, maxi(4, sz / 6), outline)
	draw_string(f, p + Vector2(-w * 0.5, sz * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


func _badge(p: Vector2, t: String, col := UI.GOLD, sz := 34) -> void:
	var r := sz * 0.75
	draw_circle(p, r, Color(0, 0, 0, 0.75))
	draw_circle(p, r - 3, col)
	_text_c(p, t, sz, UI.INK, Color(1, 1, 1, 0.0))


func _cube(p: Vector2, col: Color, s := 40.0) -> void:
	var r := Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s))
	draw_rect(r.grow(3), Color(0, 0, 0, 0.6))
	draw_rect(r, col)
	draw_rect(r, col.darkened(0.45), false, 3.0)


func meeple_poly(center: Vector2, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for v in MEEPLE:
		pts.append(center + v * h)
	return pts


func draw_meeple(center: Vector2, col: Color, h: float, boss := false, hat := 0, dbl := false) -> void:
	if dbl:
		var t := UI.tex("res://assets/segnalini/doppia.png")
		if t:
			draw_texture_rect(t, Rect2(center + Vector2(-h * 0.55, -h * 0.1), Vector2(h * 0.6, h * 0.6)), false)
	var pts := meeple_poly(center + Vector2(4, 5), h)
	draw_colored_polygon(pts, Color(0, 0, 0, 0.45))
	pts = meeple_poly(center, h)
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, col.darkened(0.55), maxf(2.0, h * 0.04))
	if boss:
		# il capo: cappello da capitano
		var top := center + Vector2(0, -h * 0.5)
		draw_rect(Rect2(top + Vector2(-h * 0.2, -h * 0.13), Vector2(h * 0.4, h * 0.14)), Color("#1b2328"))
		draw_rect(Rect2(top + Vector2(-h * 0.27, 0), Vector2(h * 0.54, h * 0.05)), Color("#1b2328"))
		draw_rect(Rect2(top + Vector2(-h * 0.2, -h * 0.03), Vector2(h * 0.4, h * 0.03)), UI.GOLD)
	if hat != 0:
		var top := center + Vector2(0, -h * 0.52)
		var hc: Color = HAT_COL.get(hat, Color.BLACK)
		draw_colored_polygon(PackedVector2Array([top + Vector2(-h * 0.3, 0), top + Vector2(0, -h * 0.12), top + Vector2(h * 0.3, 0), top + Vector2(0, h * 0.1)]), hc)
		draw_line(top + Vector2(h * 0.18, 0), top + Vector2(h * 0.22, h * 0.2), UI.GOLD_L, 3.0)
		_text_c(center + Vector2(0, h * 0.1), "5/7" if hat == 57 else str(hat), int(h * 0.28), Color.WHITE)


func _pc(p: int) -> Color:
	return UI.pcolor(e, p)


# ---------------------------------------------------------------- zona 2

func _draw_tech() -> void:
	var sz := D.TECH_SIZE
	for i in e.tech_slots.size():
		var t: String = e.tech_slots[i]
		if t == "":
			continue
		var c: Vector2 = D.TECH_SLOTS[i]
		var tx := UI.tech_tex(t)
		draw_rect(Rect2(c - sz * 0.5, sz).grow(4), Color(0, 0, 0, 0.6))
		if tx:
			draw_texture_rect(tx, Rect2(c - sz * 0.5, sz), false)
		var own: int = e.tech_owner[t]
		if own >= 0:
			var col: Color = Color("#8a8a8a") if own == 9 else _pc(own)
			# cubo del brevetto sulla colonna delle copie: scende a ogni vendita
			var col_top := c + Vector2(-sz.x * 0.36, -sz.y * 0.05)
			var step := sz.y * 0.075
			var k: int = e.copies(t) - e.tech_left(t)
			_cube(col_top + Vector2(0, step * k), col, 30)
		_badge(c + Vector2(sz.x * 0.38, sz.y * 0.42), str(e.tech_left(t)), UI.SAND, 30)
	# mazzo
	var dc := D.TECH_DECK
	if not e.deck.is_empty():
		var back := UI.tex("res://assets/tecnologie/retro.jpg")
		for k in mini(3, e.deck.size()):
			var off := Vector2(-k * 4, -k * 4)
			if back:
				draw_texture_rect(back, Rect2(dc - sz * 0.5 + off, sz), false)
		_badge(dc + Vector2(sz.x * 0.38, sz.y * 0.42), str(e.deck.size()), UI.SAND, 30)
	if not e.reserve.is_empty():
		draw_meeple(dc, _pc(e.reserve["p"]), 90, e.meeple(e.reserve["p"], e.reserve["m"]).get("boss", false))


# ---------------------------------------------------------------- zona 3

func _draw_market() -> void:
	var x: float = e.L["market_x"]
	for i in e.market.size():
		var stack: Array = e.market[i]
		if stack.is_empty():
			continue
		var y: float = e.L["market_y"][i]
		for k in stack.size():
			var t := UI.card_tex(stack[k])
			var r := Rect2(Vector2(x - 50 + k * 7, y - 50 - k * 7), Vector2(100, 100))
			draw_rect(r.grow(3), Color(0, 0, 0, 0.5))
			if t:
				draw_texture_rect(t, r, false)
		if stack.size() > 1:
			_badge(Vector2(x + 52, y + 40), "x%d" % stack.size(), UI.GOLD_L, 26)


# ---------------------------------------------------------------- zona 8

func _draw_museum() -> void:
	for i in e.rooms.size():
		var room: Dictionary = e.rooms[i]
		var cfg: Dictionary = room["cfg"]
		if not e.room_active(i):
			# sala non usata con questo numero di giocatori: velata
			var a: Vector2 = cfg["door"]
			var b: Vector2 = cfg["open"]
			draw_rect(Rect2(a.x - 75, a.y - 60, 150, b.y - a.y + 120), Color(0, 0, 0, 0.45))
			continue
		if room["sponsor"] >= 0:
			_cube(cfg["open"] if room["open"] else cfg["door"], _pc(room["sponsor"]), 46)
		for k in room["slots"].size():
			var s = room["slots"][k]
			if s == null:
				continue
			_chest(cfg["spots"][k], s["v"], s["p"], 92)
	var st: Vector2 = e.L["storage"]
	for k in e.storage.size():
		var s: Dictionary = e.storage[k]
		_chest(st + Vector2((k % 3) * 46 - 46, -60 + int(k / 3) * 40), s["v"], s["p"], 64)


func _chest(c: Vector2, v: int, p: int, s: float) -> void:
	var t := UI.chest_tex(v)
	draw_circle(c, s * 0.58, Color(0, 0, 0, 0.5))
	if p >= 0:
		draw_circle(c, s * 0.56, _pc(p))
	if t:
		draw_texture_rect(t, Rect2(c - Vector2(s, s) * 0.45, Vector2(s, s) * 0.9), false)


# ---------------------------------------------------------------- tracciati, buste, ordine

func _draw_tracks() -> void:
	# reputazione
	var at := {}
	for p in e.n:
		var v: int = e.ps[p]["rep"]
		var k: int = at.get(posmod(v, 100), 0)
		at[posmod(v, 100)] = k + 1
		var pos := D.rep_pos(v) + Vector2(-14 + k * 10, -14 + k * 10)
		var r := Rect2(pos - Vector2(26, 34), Vector2(52, 68))
		draw_rect(r.grow(3), Color(0, 0, 0, 0.6))
		draw_rect(r, _pc(p))
		if v >= 100:
			_text_c(pos, "+%d" % (int(v / 100) * 100), 22, Color.WHITE)
	# cozze e pubblicità
	_cube(D.Z6_TRACK[e.z6_idx], UI.GOLD, 34)
	_cube(D.Z9_TRACK[e.z9_idx], UI.GOLD, 34)
	# buste
	for i in e.envelopes.size():
		if i < e.L["env"].size():
			var t := UI.tex("res://assets/segnalini/busta_%s.png" % D.COLORS[e.pcol(e.envelopes[i])]["key"])
			var c: Vector2 = e.L["env"][i]
			if t:
				draw_texture_rect(t, Rect2(c - Vector2(38, 38), Vector2(76, 76)), false)
	# ordine di turno
	if not e.solo:
		for i in e.order.size():
			if i < e.L["order"].size():
				_cube(e.L["order"][i], _pc(e.order[i]), 52)
	# lavoratori ancora da assumere
	for p in e.n:
		var row: int = e.pcol(p)
		var left: int = e.reserve_left(p)
		for k in left:
			var x: float = D.WORKER_ROW_X[3 - left + k]
			draw_meeple(Vector2(x, D.WORKER_ROW_Y[row]), _pc(p), 56)
	# cappelli disponibili
	for z in e.hats:
		var pos: Array = e.L["hats"][z]
		for k in e.hats[z]:
			var c: Vector2 = pos[mini(k, pos.size() - 1)] + Vector2(0, -24 + k * 10)
			var hc: Color = HAT_COL[z]
			draw_colored_polygon(PackedVector2Array([c + Vector2(-34, 0), c + Vector2(0, -14), c + Vector2(34, 0), c + Vector2(0, 12)]), hc)
			draw_line(c + Vector2(20, 0), c + Vector2(26, 22), UI.GOLD_L, 3.0)
	# idrovolanti a casa
	for i in e.planes.size():
		if str(e.planes[i]) == "home":
			_plane(D.PLANES[i], Color("#c9d6d8"))


# ---------------------------------------------------------------- siti di scavo

func _draw_sites() -> void:
	for k in e.sites:
		var s: Dictionary = e.sites[k]
		var cfg: Dictionary = e.L["sites"][k]
		var rows := 4 if s["large"] else 3
		var cols := 5 if s["large"] else 4
		var w: float = cols * D.CELL.x
		var h: float = rows * D.CELL.y
		var ang := deg_to_rad(cfg["rot"])
		draw_set_transform_matrix(_cur_xf() * Transform2D(ang, cfg["c"]))
		var rect := Rect2(-w * 0.5, -h * 0.5, w, h)
		if s["tile"] < 0:
			pass
		elif s["up"] or (viewer >= 0 and viewer in s["access"]):
			var t := UI.site_tex(s["large"], s["tile"])
			if t:
				draw_texture_rect(t, rect, false, Color(1, 1, 1, 1.0 if s["up"] else 0.55))
			# coperture su tesori presi e squali uccisi
			var cov := UI.tex("res://assets/tesori/copertura.png")
			for r in rows:
				for c in cols:
					var v: String = s["grid"][r][c]
					if v == "X" or v == "K":
						var cr := Rect2(-w * 0.5 + c * D.CELL.x + 6, -h * 0.5 + r * D.CELL.y + 6, D.CELL.x - 12, D.CELL.y - 12)
						if cov:
							draw_texture_rect(cov, cr, false)
		else:
			var back := UI.tex("res://assets/siti/retro.png")
			if back:
				draw_texture_rect(back, rect, false)
		draw_rect(rect, Color(0, 0, 0, 0.6), false, 4.0)
		draw_set_transform_matrix(_cur_xf())
		if s["tile"] >= 0 and not s["up"]:
			_text_c(cfg["c"], "Sito %d%s" % [k, " (la vedi solo tu)" if (viewer >= 0 and viewer in s["access"]) else ""], 40, UI.SAND)
		# chi ha la carta del sito
		var ax := D.site_axes(cfg["rot"])
		var base: Vector2 = cfg["c"] - ax[1] * (h * 0.5 + 40)
		for i in s["access"].size():
			_cube(base + ax[0] * (i - (s["access"].size() - 1) * 0.5) * 44, _pc(s["access"][i]), 34)


## Idrovolante stilizzato (fusoliera, ali, coda e galleggianti).
func _plane(c: Vector2, col: Color) -> void:
	var d := col.darkened(0.5)
	draw_line(c + Vector2(0, -46), c + Vector2(0, 40), d, 22.0)
	draw_line(c + Vector2(0, -46), c + Vector2(0, 40), col, 14.0)
	draw_line(c + Vector2(-56, -12), c + Vector2(56, -12), d, 20.0)
	draw_line(c + Vector2(-54, -12), c + Vector2(54, -12), col, 13.0)
	draw_line(c + Vector2(-22, 34), c + Vector2(22, 34), col, 10.0)
	for sx in [-24.0, 24.0]:
		draw_line(c + Vector2(sx, -24), c + Vector2(sx, 8), d, 8.0)


func _cur_xf() -> Transform2D:
	return Transform2D(rot, Vector2(zoom, zoom), 0.0, pan) * Transform2D(0.0, -Vector2(D.BOARD_W, D.BOARD_H) * 0.5)


func _draw_island() -> void:
	var back := UI.tex("res://assets/isola/isola_retro.png")
	if e.island.size() < 9:
		return
	for i in 9:
		if e.island[i] < 0:
			continue
		var c := Vector2(D.ISLAND_X[i % 3], D.ISLAND_Y[int(i / 3)])
		if back:
			draw_texture_rect(back, Rect2(c - Vector2(52, 52), Vector2(104, 104)), false)


# ---------------------------------------------------------------- gommoni

func zod_pos(z: Dictionary) -> Vector2:
	var loc: String = z["loc"]
	if loc == "port":
		if z["id"] < 4:
			return Vector2(D.DOCK_X, D.DOCK_Y[e.pcol(z["owner"])])
		return Vector2(D.SPARE_X, D.DOCK_Y[z["id"] - 4])
	if loc == "shop":
		return Vector2(D.SPARE_X, D.DOCK_Y[z["id"] - 4])
	if loc.begins_with("lag:"):
		return D.LAGOON_POS[loc.substr(4)]
	if loc.begins_with("D"):
		var k: int = e.node_site(loc)
		var col := int(loc.substr(loc.find("_") + 1))
		return D.dive_pos(e.L["sites"][k], col)
	if e.L["nodes"].has(loc):
		var base: Vector2 = e.L["nodes"][loc]
		if loc.begins_with("F"):
			# più gommoni nella stessa area di pesca
			var k := 0
			for o in e.zods:
				if o["loc"] == loc and o["id"] < z["id"]:
					k += 1
			return base + Vector2(-70 + (k % 3) * 70, -30 + int(k / 3) * 60)
		return base
	return Vector2(D.DOCK_X, 3800)


func _draw_zodiacs() -> void:
	for z in e.zods:
		var pos := zod_pos(z)
		var t := UI.zod_tex(z["color"])
		var sz := Vector2(78, 108) if z["loc"] == "shop" else Vector2(92, 128)
		var tint := Color(1, 1, 1, 0.45) if z["loc"] == "shop" else Color.WHITE
		if t:
			draw_texture_rect(t, Rect2(pos - sz * 0.5, sz), false, tint)
		if z["owner"] >= 0:
			draw_circle(pos + Vector2(sz.x * 0.42, -sz.y * 0.42), 14, _pc(z["owner"]))
			draw_arc(pos + Vector2(sz.x * 0.42, -sz.y * 0.42), 14, 0, TAU, 20, Color.BLACK, 3.0)
		if z["crew"] != -1 and z["owner"] >= 0:
			var m: Dictionary = e.meeple(z["owner"], z["crew"])
			draw_meeple(pos + Vector2(0, 6), _pc(z["owner"]), 62, m.get("boss", false), m.get("hat", 0))
	# idrovolanti presso i gommoni
	for i in e.planes.size():
		if str(e.planes[i]) != "home":
			var z: Dictionary = e.zod(int(e.planes[i]))
			_plane(zod_pos(z) + Vector2(86, -46), Color("#c9d6d8"))


# ---------------------------------------------------------------- code e meeple

func _draw_queues() -> void:
	for z in e.queues:
		var pos: Array = e.L["queues"][z]["pos"]
		for i in e.queues[z].size():
			var x = e.queues[z][i]
			if x == null:
				continue
			var m: Dictionary = e.meeple(x["p"], x["m"])
			draw_meeple(pos[i] + Vector2(-60, 0), _pc(x["p"]), 64, m.get("boss", false), m.get("hat", 0), x["dbl"])
	for i in e.z6.size():
		var x: Dictionary = e.z6[i]
		var m: Dictionary = e.meeple(x["p"], x["m"])
		var c := D.Z6_AREA + Vector2(-90 + (i % 4) * 60, -10 + int(i / 4) * 64)
		draw_meeple(c, _pc(x["p"]), 58, m.get("boss", false), m.get("hat", 0), x["dbl"])
	for i in 2:
		if e.shop_used[i] >= 0:
			var p: int = e.shop_used[i]
			var ms: Array = e.meeples_at(p, "shop")
			if not ms.is_empty():
				draw_meeple(D.SHOP[i] + Vector2(0, -20), _pc(p), 60, ms[0]["boss"], ms[0]["hat"])


# ---------------------------------------------------------------- mercenari

## Casella del mercenario: in testa alla coda (zone 1 e 4) o in fondo (le altre).
func merc_pos(z: int) -> Vector2:
	var pos: Array = e.L["queues"][z]["pos"]
	if z in e.MERC_HEAD:
		return pos[0] + Vector2(-60, -74)
	var last := 0
	for i in pos.size():
		var mp: int = e.L["queues"][z]["minp"][i]
		if mp == 0 or e.n >= mp:
			last = i
	return pos[last] + Vector2(-60, 74)


func _draw_mercs() -> void:
	if not e.variant:
		return
	for z in e.merc_q:
		var x: Dictionary = e.merc_q[z]
		var c := merc_pos(z)
		draw_meeple(c, Color("#1d1f22"), 64)
		draw_circle(c + Vector2(30, 24), 13, _pc(x["p"]))
	for z in e.merc_used:
		_cube(merc_pos(z), _pc(e.merc_used[z]), 30)
	# idrovolante nero e mina
	if e.black_plane >= 0:
		var zs: Array = e.zods_of(e.black_plane, "sea")
		var at: Vector2 = zod_pos(zs[0]) + Vector2(-86, -46) if not zs.is_empty() else D.PLANES[1] + Vector2(140, 0)
		_plane(at, Color("#26292d"))
		draw_circle(at + Vector2(0, 40), 12, _pc(e.black_plane))
	if e.mercs_left > 0:
		for i in e.mercs_left:
			draw_meeple(Vector2(3330 - i * 70, 1560), Color("#1d1f22"), 56)


# ---------------------------------------------------------------- zone selezionabili

func _draw_hot() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.5 + 0.5 * sin(t * 4.0)
	for id in hot:
		var h: Dictionary = hot[id]
		var r: float = h.get("r", 60.0)
		var col: Color = h.get("col", UI.GOLD_L)
		var sel: bool = id == hot_sel
		draw_circle(h["pos"], r, Color(col, 0.16 + 0.12 * pulse))
		draw_arc(h["pos"], r, 0, TAU, 48, Color(col if not sel else Color.WHITE, 0.95), 7.0 if sel else 5.0)
		if h.get("label", "") != "":
			_text_c(h["pos"] + Vector2(0, -r - 24), h["label"], 34, col)


func _process(_dt: float) -> void:
	if not hot.is_empty() and not flat_only:
		queue_redraw()
