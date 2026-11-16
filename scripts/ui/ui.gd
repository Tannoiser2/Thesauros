class_name UI
extends RefCounted
## Helper grafici condivisi. Tema «agenzia di recupero»: il verde acqua profondo del mare del tabellone,
## la sabbia della spiaggia e l'ottone degli strumenti nautici, con il corallo per gli avvisi.
## Caratteri liberi (OFL): Cinzel per titoli e intestazioni (le capitali spaziate del logo THESAUROS),
## Barlow per i testi e i numeri, Barlow Condensed per le etichette strette.

const D = preload("res://scripts/data/th_data.gd")

const BG := Color("#04161d")
const BG_L := Color("#0b2c37")
const PANEL := Color("#0a2a35")
const PANEL_L := Color("#123f4d")
const SAND := Color("#ead9b2")
const SAND_D := Color("#c9b386")
const GOLD := Color("#d9a646")
const GOLD_L := Color("#f5d27c")
const CORAL := Color("#e2674a")
const CORAL_D := Color("#9c3a25")
const TEAL := Color("#2aa198")
const TEAL_L := Color("#7fd6cc")
const INK := Color("#0b1f26")
const TEXT := Color("#eef6f4")
const MUTED := Color("#93b4b8")
const GREEN := Color("#8fd16a")
const RED := Color("#ff7a5c")

static var _tex := {}
static var font_title: Font
static var font_head: Font
static var font_head_r: Font
static var font_body: Font
static var font_semi: Font
static var font_bold: Font
static var font_italic: Font
static var font_cond: Font


static func _var(path: String, w: int) -> Font:
	var base: FontFile = load(path)
	var fv := FontVariation.new()
	fv.base_font = base
	var tag := TextServerManager.get_primary_interface().name_to_tag("wght")
	fv.variation_opentype = {tag: w}
	return fv


static func init_fonts() -> void:
	if font_title != null:
		return
	font_title = _var("res://assets/fonts/Cinzel.ttf", 900)
	font_head = _var("res://assets/fonts/Cinzel.ttf", 700)
	font_head_r = _var("res://assets/fonts/Cinzel.ttf", 500)
	font_body = load("res://assets/fonts/Barlow-Regular.ttf")
	font_semi = load("res://assets/fonts/Barlow-SemiBold.ttf")
	font_bold = load("res://assets/fonts/Barlow-Bold.ttf")
	font_italic = load("res://assets/fonts/Barlow-Italic.ttf")
	font_cond = load("res://assets/fonts/BarlowCondensed-SemiBold.ttf")


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


static func item_tex(k: String) -> Texture2D:
	return tex("res://assets/oggetti/%s.png" % k)


static func chest_tex(v: int) -> Texture2D:
	return tex("res://assets/tesori/tesoro_%d.png" % v)


static func card_tex(k: int) -> Texture2D:
	return tex("res://assets/carte/carta_%d.png" % k)


static func tech_tex(t: String) -> Texture2D:
	return tex("res://assets/tecnologie/%s.jpg" % t)


static func zod_tex(color: String) -> Texture2D:
	return tex("res://assets/gommoni/%s.png" % color)


static func site_tex(large: bool, i: int) -> Texture2D:
	return tex("res://assets/siti/%s_%d.png" % ["grandi" if large else "piccole", i])


static func pcolor(e, p: int) -> Color:
	return D.COLORS[e.pcol(p)]["col"]


static func pdark(e, p: int) -> Color:
	return D.COLORS[e.pcol(p)]["dark"]


static func panel_style(bg: Color, border: Color = GOLD, bw := 2, radius := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(12)
	return sb


static func dark_style(radius := 8, alpha := 0.95) -> StyleBoxFlat:
	var sb := panel_style(Color(PANEL, alpha), Color(GOLD, 0.7), 2, radius)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 10
	return sb


static func sand_style(radius := 6) -> StyleBoxFlat:
	var sb := panel_style(SAND, Color(GOLD, 0.9), 2, radius)
	sb.set_content_margin_all(10)
	return sb


static func label(text: String, size := 20, col := TEXT, font: Font = null) -> Label:
	init_fonts()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


static func title(text: String, size := 48, col := GOLD_L) -> Label:
	init_fonts()
	var l := label(text, size, col, font_title)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", maxi(2, size / 20))
	l.add_theme_constant_override("shadow_offset_y", maxi(2, size / 16))
	return l


static func heading(text: String, size := 22, col := GOLD_L) -> Label:
	init_fonts()
	return label(text, size, col, font_head)


## Etichetta che va a capo: larghezza minima fissata, così non si schiaccia mai in colonna.
static func wrap(l: Label, w: float) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = w
	return l


static func icon_rect(t: Texture2D, sz: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = sz
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func button(text: String, w := 200.0, h := 46.0, size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", size)
	b.clip_text = false
	return b


static func primary(b: Button) -> Button:
	init_fonts()
	b.add_theme_stylebox_override("normal", _btn(CORAL_D, GOLD))
	b.add_theme_stylebox_override("hover", _btn(CORAL, GOLD_L))
	b.add_theme_stylebox_override("pressed", _btn(GOLD, INK))
	b.add_theme_stylebox_override("disabled", _btn(Color("#3a2a26"), Color("#2a1e1a")))
	b.add_theme_color_override("font_color", SAND)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_font_override("font", font_head)
	return b


static func _btn(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 3
	sb.content_margin_bottom = 5
	return sb


static func make_theme() -> Theme:
	init_fonts()
	var th := Theme.new()
	th.default_font = font_semi
	th.default_font_size = 21
	th.set_stylebox("normal", "Button", _btn(Color("#0f3b47"), Color("#3d7f86")))
	th.set_stylebox("hover", "Button", _btn(Color("#16505e"), GOLD))
	th.set_stylebox("pressed", "Button", _btn(GOLD, GOLD_L))
	th.set_stylebox("hover_pressed", "Button", _btn(GOLD_L, GOLD_L))
	th.set_stylebox("disabled", "Button", _btn(Color("#0a2028"), Color("#173640")))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", GOLD_L)
	th.set_color("font_pressed_color", "Button", INK)
	th.set_color("font_hover_pressed_color", "Button", INK)
	th.set_color("font_disabled_color", "Button", Color("#4d6a70"))
	th.set_font("font", "Button", font_semi)
	th.set_font_size("font_size", "Button", 21)
	th.set_color("font_color", "Label", TEXT)
	var pn := StyleBoxFlat.new()
	pn.bg_color = PANEL
	th.set_stylebox("panel", "Panel", pn)
	th.set_stylebox("panel", "PanelContainer", pn)
	th.set_font("normal_font", "RichTextLabel", font_body)
	th.set_font("bold_font", "RichTextLabel", font_bold)
	th.set_font("italics_font", "RichTextLabel", font_italic)
	th.set_font("mono_font", "RichTextLabel", font_head_r)
	for k in ["normal_font_size", "bold_font_size", "italics_font_size", "mono_font_size"]:
		th.set_font_size(k, "RichTextLabel", 21)
	th.set_color("default_color", "RichTextLabel", TEXT)
	th.set_font("font", "LineEdit", font_semi)
	th.set_font_size("font_size", "LineEdit", 24)
	th.set_color("font_color", "LineEdit", INK)
	th.set_color("font_placeholder_color", "LineEdit", Color("#7b8d8a"))
	th.set_color("caret_color", "LineEdit", INK)
	th.set_stylebox("normal", "LineEdit", panel_style(SAND, GOLD, 2, 4))
	th.set_stylebox("focus", "LineEdit", panel_style(Color("#fff7e3"), GOLD_L, 2, 4))
	th.set_font("font", "TooltipLabel", font_body)
	th.set_font_size("font_size", "TooltipLabel", 19)
	th.set_color("font_color", "TooltipLabel", INK)
	var tp := panel_style(SAND, GOLD, 2, 4)
	tp.set_content_margin_all(8)
	th.set_stylebox("panel", "TooltipPanel", tp)
	var sc := StyleBoxFlat.new()
	sc.bg_color = Color(GOLD, 0.85)
	sc.set_corner_radius_all(3)
	for k in ["grabber", "grabber_highlight", "grabber_pressed"]:
		th.set_stylebox(k, "VScrollBar", sc)
		th.set_stylebox(k, "HSlider", sc)
	var sct := StyleBoxFlat.new()
	sct.bg_color = Color(1, 1, 1, 0.06)
	th.set_stylebox("scroll", "VScrollBar", sct)
	return th


## Sfondo: mare profondo sfumato con le linee di profondità di una carta nautica (disegnato).
class Backdrop extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var n := 28
		for i in n:
			var c := UI.BG_L.lerp(UI.BG, float(i) / n)
			draw_rect(Rect2(0, size.y * i / n, size.x, size.y / n + 1), c)
		var col := Color(UI.TEAL_L, 0.05)
		for k in 9:
			var pts := PackedVector2Array()
			var y0 := size.y * (0.1 + k * 0.1)
			for i in 41:
				var x := size.x * i / 40.0
				pts.append(Vector2(x, y0 + sin(i * 0.35 + k) * 18.0 + cos(i * 0.13 + k * 2.0) * 26.0))
			draw_polyline(pts, col, 2.0)
