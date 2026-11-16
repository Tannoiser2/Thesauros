extends SceneTree
## Tutorial: gioca tutta la partita guidata seguendo sempre il consiglio del tutor, fotografa le prime
## lezioni e il riquadro del consiglio per ogni tipo di decisione, e controlla che si arrivi alla fine.
## Uso: xvfb-run godot --path . -s tests/shot_tut.gd -- <cartella> [larghezza] [altezza]

var out := "/tmp/tut"
var shots := {}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else out
	var w := int(args[1]) if args.size() > 1 else 1920
	var h := int(args[2]) if args.size() > 2 else 1080
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(w, h)
	DisplayServer.window_set_size(Vector2i(w, h))
	_run()


func _snap(name: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("foto ", name)


func _find_button(n: Node, texts: Array) -> Button:
	for c in n.get_children():
		if c is Button and c.visible and c.text in texts and not c.disabled:
			return c
		var r := _find_button(c, texts)
		if r != null:
			return r
	return null


func _run() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.6).timeout
	await _snap("00_menu")
	var cfg: Dictionary = Tutorial.config()
	cfg["ai_delay"] = 0.0
	cfg["anim"] = 0.0
	main.start_game(cfg)
	var g = main.current
	await create_timer(0.5).timeout
	var lessons := 0
	var guard := 0
	while guard < 20000:
		guard += 1
		await process_frame
		if g.engine.phase == "over":
			break
		# lezione aperta?
		var nx := _find_button(g.popup_layer, ["Avanti", "Ho capito"])
		if nx != null:
			lessons += 1
			if lessons <= 6 or lessons % 5 == 0:
				await create_timer(0.2).timeout
				await _snap("lezione_%02d" % lessons)
			nx.pressed.emit()
			await process_frame
			continue
		if g.pending.is_empty():
			continue
		var t: String = g.pending["type"]
		if g.tutor_panel.visible:
			if not shots.has(t):
				shots[t] = true
				await create_timer(0.25).timeout
				await _snap("tutor_%s" % t)
			var fol := _find_button(g.tutor_box, ["Segui il consiglio"])
			if fol != null:
				fol.pressed.emit()
				continue
		# nessun consiglio: decide l'IA
		g._submit(g.tutor_ai.decide(g.engine, g.pending["seat"], g.pending))
	await create_timer(1.0).timeout
	await _snap("zz_fine")
	var nx2 := _find_button(g.popup_layer, ["Avanti", "Ho capito"])
	if nx2 != null:
		nx2.pressed.emit()
	await create_timer(0.3).timeout
	await _snap("zz_punteggio")
	print("TUTORIAL fine: lezioni ", lessons, ", periodo ", g.engine.period, ", vince ", g.engine.pname(g.engine.result.get("winner", -1)), " ", g.engine.result["scores"].map(func(x): return x["totale"]))
	main.show_rules()
	await create_timer(0.4).timeout
	await _snap("zz_manuale")
	quit()
