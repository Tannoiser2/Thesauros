extends SceneTree
## Fotografie dell'interfaccia (serve un display, anche virtuale: xvfb-run).
## Uso: xvfb-run -s "-screen 0 1920x1080x24" godot --path . -s tests/shot.gd -- <cartella> [giocatori] [larghezza] [altezza] [3d]
## La persona (Verde) lascia decidere all'IA; si fotografano le varie decisioni la prima volta che compaiono.

var out := "/tmp/shots"
var taken := {}
var variant := false

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var np := int(args[1]) if args.size() > 1 else 4
	var w := int(args[2]) if args.size() > 2 else 1920
	var h := int(args[3]) if args.size() > 3 else 1080
	var v3 := args.size() > 4 and args[4] == "3d"
	variant = args.size() > 5 and args[5] == "var"
	DirAccess.make_dir_recursive_absolute(out)
	_run(np, w, h, v3)


func _snap(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	print("foto ", name)


func _run(np: int, w: int, h: int, v3: bool) -> void:
	root.size = Vector2i(w, h)
	DisplayServer.window_set_size(Vector2i(w, h))
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	await _snap("menu")
	var seats := []
	for i in np:
		seats.append({"name": "Stefano" if i == 0 else "", "ai": i != 0, "level": 1, "color": i})
	main.start_game({"seats": seats, "ai_delay": 0.0, "anim": 4.0, "view3d": v3, "seed": 11, "variant": variant})
	var g = main.current
	await create_timer(1.0).timeout
	var guard := 0
	while guard < 900:
		guard += 1
		if g.engine.phase == "over":
			break
		var req: Dictionary = g.pending
		if req.is_empty():
			await create_timer(0.1).timeout
			continue
		var t: String = req["type"]
		if not taken.has(t):
			taken[t] = true
			await create_timer(0.35).timeout
			await _snap("%02d_%s" % [taken.size(), t])
		var r = g.engine.ais[0].decide(g.engine, 0, req)
		g._submit(r)
		await create_timer(0.05).timeout
	await create_timer(1.0).timeout
	await _snap("fine")
	g._clear_prompt()
	g._company_popup(0)
	await create_timer(0.4).timeout
	await _snap("compagnia")
	g._clear_prompt()
	g.board.focus(Vector2(2200, 4100), 0.55)
	await create_timer(0.3).timeout
	await _snap("mare")
	quit()
