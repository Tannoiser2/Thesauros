extends SceneTree
## Partite simulate fra IA, senza grafica: controlla che le regole reggano e misura punteggi e durata.
## Uso: godot --headless --path . -s tests/sim.gd -- [giocatori 1-4] [partite] [livello] [iniziazione 0/1]
## TH_LOG=1 stampa il diario della prima partita.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var np := int(args[0]) if args.size() > 0 else 4
	var games := int(args[1]) if args.size() > 1 else 4
	var lv := int(args[2]) if args.size() > 2 else 1
	var ini := args.size() > 3 and args[3] == "1"
	_run(np, games, lv, ini)


func _run(np: int, games: int, lv: int, ini: bool) -> void:
	await process_frame
	var t0 := Time.get_ticks_msec()
	var wins := {}
	var tot := 0.0
	for g in games:
		var eng := THEngine.new()
		eng.headless = true
		root.add_child(eng)
		var seats := []
		for i in np:
			var l := lv if lv >= 0 else i % 3
			seats.append({"name": "IA%d-L%d" % [i, l], "ai": true, "level": l, "color": i})
		eng.setup({"seats": seats, "seed": 1000 + g, "initiation": ini})
		for i in np:
			eng.ais[i] = THAI.new(int(seats[i]["level"]), 50 + g * 7 + i)
		if OS.get_environment("TH_LOG") == "1" and g == 0:
			eng.log_added.connect(func(t): print(t))
		await eng.run()
		var w: int = eng.result.get("winner", -9)
		wins[seats[w]["name"]] = wins.get(seats[w]["name"], 0) + 1
		var line := []
		for p in np:
			var s: Dictionary = eng.result["scores"][p]
			line.append("%d(rep%d t%d b%d s%d c%d $%d i%d | tes%d car%d sq%d zod%d)" % [s["totale"], s["rep"], s["tesori"], s["brevetti"], s["squali"], s["carte"], s["denaro"], s["influenza"],
				eng.ps[p]["treasures"].size(), eng.ps[p]["cards"].size(), eng.ps[p]["sharks"], eng.zods_of(p).size()])
			tot += s["totale"]
		var opened := 0
		for r in eng.rooms:
			if r["open"]:
				opened += 1
		print("  partita %d (fine al quadrimestre %d, sale aperte %d): vince %s — %s" % [g, eng.period, opened, seats[w]["name"], "  ".join(line)])
		if np == 1:
			print("    solitario: obiettivo %s, totale %d" % [eng.result.get("solo_win"), eng.result.get("solo_total")])
		eng.queue_free()
	print("Vittorie %s, reputazione media %.1f, %d ms" % [wins, tot / (games * np), Time.get_ticks_msec() - t0])
	quit()
