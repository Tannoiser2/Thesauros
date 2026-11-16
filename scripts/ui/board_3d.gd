extends Control
## Vista 3D: il tabellone (con carte, tessere, cubetti e tesori, disegnati come nella vista 2D) su
## un tavolo, con i modelli 3D del modulo per gommoni, idrovolanti, capi e lavoratori.
## Comandi: un dito o il tasto sinistro trascinano; due dita pizzicano per lo zoom e ruotano;
## il tasto destro (o due dita in verticale) inclina la vista; rotella per lo zoom.

const D = preload("res://scripts/data/th_data.gd")
const PX := 1000.0               # pixel del tabellone per unità 3D

signal spot_pressed(id: String)

var e
var hot := {}
var svc: SubViewportContainer
var vp: SubViewport
var cam: Camera3D
var flat_vp: SubViewport
var flat
var pieces: Node3D
var yaw := 0.0
var pitch := 1.05
var dist := 7.0
var target := Vector3.ZERO
var meshes := {}
var _touches := {}
var _pinch := {}
var _press := Vector2.ZERO
var _moved := false


func setup(eng) -> void:
	e = eng
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	svc = SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	vp = SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_2X
	vp.own_world_3d = true
	svc.add_child(vp)
	var env := WorldEnvironment.new()
	var en := Environment.new()
	en.background_mode = Environment.BG_COLOR
	en.background_color = Color("#04161d")
	en.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	en.ambient_light_color = Color("#b8d8dc")
	en.ambient_light_energy = 0.45
	en.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = en
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -35, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	vp.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 40
	vp.add_child(cam)
	# tavolo
	var table := MeshInstance3D.new()
	var tm := PlaneMesh.new()
	tm.size = Vector2(9, 9)
	table.mesh = tm
	var tmat := StandardMaterial3D.new()
	tmat.albedo_texture = UI.tex("res://assets/misc/tavolo.jpg")
	tmat.albedo_color = Color(0.55, 0.62, 0.62)
	tmat.uv1_scale = Vector3(1.5, 1.5, 1)
	table.material_override = tmat
	table.position.y = -0.02
	vp.add_child(table)
	# tabellone: trama disegnata dalla vista 2D in un viewport fuori schermo
	flat_vp = SubViewport.new()
	flat_vp.size = Vector2i(2717, 4006)
	flat_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	flat_vp.transparent_bg = false
	add_child(flat_vp)
	flat = preload("res://scripts/ui/board_2d.gd").new()
	flat.flat_only = true
	flat.size = Vector2(2717, 4006)
	flat_vp.add_child(flat)
	flat.setup(e)
	var board := MeshInstance3D.new()
	var bm := PlaneMesh.new()
	bm.size = Vector2(D.BOARD_W / PX, D.BOARD_H / PX)
	board.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_texture = flat_vp.get_texture()
	bmat.albedo_texture_force_srgb = true
	bmat.roughness = 0.9
	board.material_override = bmat
	board.position.y = 0.016
	vp.add_child(board)
	# spessore del tabellone
	var edge := MeshInstance3D.new()
	var em := BoxMesh.new()
	em.size = Vector3(D.BOARD_W / PX + 0.02, 0.03, D.BOARD_H / PX + 0.02)
	edge.mesh = em
	var emat := StandardMaterial3D.new()
	emat.albedo_color = Color("#0d2a33")
	edge.material_override = emat
	vp.add_child(edge)
	pieces = Node3D.new()
	vp.add_child(pieces)
	for k in ["gommone", "idrovolante", "lavoratore", "capo", "cappello"]:
		meshes[k] = load("res://assets/modelli/%s.obj" % k)
	_cam()
	refresh()


func to3(p: Vector2, y := 0.016) -> Vector3:
	return Vector3((p.x - D.BOARD_W * 0.5) / PX, y, (p.y - D.BOARD_H * 0.5) / PX)


func _cam() -> void:
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.position = target + off
	cam.look_at(target, Vector3.UP)


func rotate_by(a: float) -> void:
	yaw += a
	_cam()


## Mette una mesh a misura (lato più lungo = lunghezza in unità) appoggiata sul piano.
func _place(mesh: Mesh, at: Vector3, length: float, col: Color, yrot := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var ab := mesh.get_aabb()
	var longest := maxf(ab.size.x, maxf(ab.size.y, ab.size.z))
	var k := length / maxf(0.0001, longest)
	var center := ab.position + ab.size * 0.5
	mi.scale = Vector3(k, k, k)
	mi.rotation.y = yrot
	var off := Vector3(-center.x, -ab.position.y, -center.z) * k
	mi.position = at + off.rotated(Vector3.UP, yrot)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.55
	mi.material_override = mat
	pieces.add_child(mi)
	return mi


func _meeple(at: Vector3, col: Color, boss: bool, hat: int) -> void:
	if boss:
		_place(meshes["capo"], at, 0.1, col)
	else:
		_place(meshes["lavoratore"], at, 0.085, col)
	if hat != 0:
		var hc: Color = preload("res://scripts/ui/board_2d.gd").HAT_COL.get(hat, Color.BLACK)
		_place(meshes["cappello"], at + Vector3(0, 0.07, 0), 0.05, hc)


func refresh() -> void:
	if e == null:
		return
	flat.hot = hot
	flat.viewer = get_parent().board.viewer if get_parent() != null and "board" in get_parent() else -1
	flat.queue_redraw()
	flat_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	for c in pieces.get_children():
		c.queue_free()
	# gommoni con l'equipaggio
	for z in e.zods:
		var pos: Vector2 = flat.zod_pos(z)
		var col := _zcol(z["color"])
		if z["loc"] == "shop":
			col = col.lerp(Color(0.5, 0.55, 0.55), 0.5)
		var boat := _place(meshes["gommone"], to3(pos), 0.17, col, PI * 0.5)
		boat.rotation.y = PI * 0.5
		if z["crew"] != -1 and z["owner"] >= 0:
			var m: Dictionary = e.meeple(z["owner"], z["crew"])
			_meeple(to3(pos, 0.03), UI.pcolor(e, z["owner"]), m.get("boss", false), m.get("hat", 0))
	# meeple nelle code
	for zq in e.queues:
		var qpos: Array = e.L["queues"][zq]["pos"]
		for i in e.queues[zq].size():
			var x = e.queues[zq][i]
			if x == null:
				continue
			var m: Dictionary = e.meeple(x["p"], x["m"])
			_meeple(to3(qpos[i] + Vector2(-60, 0)), UI.pcolor(e, x["p"]), m.get("boss", false), m.get("hat", 0))
	for i in e.z6.size():
		var x: Dictionary = e.z6[i]
		var m: Dictionary = e.meeple(x["p"], x["m"])
		_meeple(to3(D.Z6_AREA + Vector2(-90 + (i % 4) * 60, -10 + int(i / 4) * 64)), UI.pcolor(e, x["p"]), m.get("boss", false), m.get("hat", 0))
	for i in 2:
		if e.shop_used[i] >= 0:
			var p: int = e.shop_used[i]
			var ms: Array = e.meeples_at(p, "shop")
			if not ms.is_empty():
				_meeple(to3(D.SHOP[i]), UI.pcolor(e, p), ms[0]["boss"], ms[0]["hat"])
	# idrovolanti
	for i in e.planes.size():
		var at: Vector2 = D.PLANES[i]
		if str(e.planes[i]) != "home":
			at = flat.zod_pos(e.zod(int(e.planes[i]))) + Vector2(90, -50)
		_place(meshes["idrovolante"], to3(at), 0.16, Color("#c9d6d8"), PI * 0.25)


func _zcol(name: String) -> Color:
	match name:
		"verde": return Color("#3fa84a")
		"bianco": return Color("#ecebe4")
		"rosso": return Color("#e0573f")
		"blu": return Color("#5ea6e6")
		"marrone": return Color("#c08a5a")
		"rosa": return Color("#d9a3e0")
		"lime": return Color("#9ed65a")
		"giallo": return Color("#f0cf3c")
	return Color.WHITE


# ================================================================ input

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_touches[ev.index] = ev.position
			_press = ev.position
			_moved = false
		else:
			var tap: bool = _touches.size() == 1 and not _moved
			_touches.erase(ev.index)
			_pinch = {}
			if tap:
				_click(ev.position)
		accept_event()
		return
	if ev is InputEventScreenDrag:
		_touches[ev.index] = ev.position
		if ev.position.distance_to(_press) > 10:
			_moved = true
		if _touches.size() == 1:
			_pan(ev.relative)
		elif _touches.size() >= 2:
			var ks := _touches.keys()
			var a: Vector2 = _touches[ks[0]]
			var b: Vector2 = _touches[ks[1]]
			var d := a.distance_to(b)
			var ang := (b - a).angle()
			var mid := (a + b) * 0.5
			if not _pinch.is_empty():
				dist = clampf(dist * _pinch["d"] / maxf(1.0, d), 0.6, 9.0)
				yaw -= ang - _pinch["ang"]
				pitch = clampf(pitch + (mid.y - _pinch["mid"].y) * 0.004, 0.25, 1.5)
				_cam()
			_pinch = {"d": d, "ang": ang, "mid": mid}
		accept_event()
		return
	if ev is InputEventMagnifyGesture:
		dist = clampf(dist / ev.factor, 0.6, 9.0)
		_cam()
		accept_event()
		return
	if ev is InputEventPanGesture:
		_pan(-ev.delta * 10.0)
		accept_event()
		return
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			dist = clampf(dist * 0.9, 0.6, 9.0)
			_cam()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			dist = clampf(dist / 0.9, 0.6, 9.0)
			_cam()
		elif ev.pressed:
			_press = ev.position
			_moved = false
		elif ev.button_index == MOUSE_BUTTON_LEFT and not _moved and _touches.is_empty():
			_click(ev.position)
		accept_event()
	elif ev is InputEventMouseMotion and ev.button_mask != 0 and _touches.is_empty():
		if ev.position.distance_to(_press) > 6:
			_moved = true
		if ev.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			yaw -= ev.relative.x * 0.006
			pitch = clampf(pitch + ev.relative.y * 0.004, 0.25, 1.5)
			_cam()
		else:
			_pan(ev.relative)
		accept_event()


func _pan(rel: Vector2) -> void:
	var k := dist * 0.0011
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	target += (-right * rel.x + fwd * rel.y) * k
	target.x = clampf(target.x, -2.2, 2.2)
	target.z = clampf(target.z, -3.0, 3.0)
	_cam()


func _click(s: Vector2) -> void:
	if hot.is_empty():
		return
	var sc := s * Vector2(vp.size) / size
	var o := cam.project_ray_origin(sc)
	var dir := cam.project_ray_normal(sc)
	if absf(dir.y) < 0.0001:
		return
	var t := (0.016 - o.y) / dir.y
	var hit := o + dir * t
	var b := Vector2(hit.x * PX + D.BOARD_W * 0.5, hit.z * PX + D.BOARD_H * 0.5)
	var best := ""
	var bd := 1e9
	for id in hot:
		var h: Dictionary = hot[id]
		var r: float = maxf(h.get("r", 60.0), 70.0)
		var dd: float = b.distance_to(h["pos"])
		if dd < r and dd < bd:
			bd = dd
			best = id
	if best != "":
		spot_pressed.emit(best)
