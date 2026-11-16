extends SceneTree
## Fotografie ravvicinate del tabellone per controllare che i pezzi stiano nelle caselle giuste.
## Uso: xvfb-run godot --path . -s tests/shot_zoom.gd -- <cartella> <giocatori> <quadrimestri da giocare>

var out := "/tmp/zoom"

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else out
	var np := int(args[1]) if args.size() > 1 else 4
	var upto := int(args[2]) if args.size() > 2 else 4
	DirAccess.make_dir_recursive_absolute(out)
	_run(np, upto)


func _snap(name: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("foto ", name)


func _run(np: int, upto: int) -> void:
	root.size = Vector2i(1920, 1080)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	var seats := []
	for i in np:
		seats.append({"name": "", "ai": i != 0, "level": 1, "color": i})
	main.start_game({"seats": seats, "ai_delay": 0.0, "anim": 0.0, "seed": 5})
	var g = main.current
	await create_timer(0.5).timeout
	var shot_place := false
	while true:
		var req: Dictionary = g.pending
		if Engine.get_process_frames() % 200 == 0:
			print("periodo ", g.engine.period, " fase ", g.engine.phase, " req ", req.get("type", ""))
		if req.is_empty():
			if g.engine.phase == "over":
				break
			await create_timer(0.05).timeout
			continue
		if req["type"] == "place" and g.engine.period >= upto and not shot_place:
			shot_place = true
			g.board.focus(Vector2(1750, 1100), 0.42)
			await _snap("citta")
			g.board.focus(Vector2(500, 1600), 0.5)
			await _snap("museo_e_1")
			g.board.focus(Vector2(2300, 3900), 0.38)
			await _snap("mare")
			g.board.focus(Vector2(800, 3400), 0.45)
			await _snap("porto")
			g.board.focus(Vector2(1800, 4600), 0.38)
			await _snap("binario_rep")
			break
		g._submit(g.engine.ais[0].decide(g.engine, 0, req))
		await process_frame
	quit()
