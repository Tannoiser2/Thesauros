extends SceneTree
## Taratura dell'IA: misura quanto rende un insieme di pesi contro i pesi attuali (TUNED).
## Uso: godot --headless --path . -s tests/tara_ia.gd -- '<pesi JSON>' <partite> <seme iniziale> [giocatori] [variante 0/1]
## Ogni partita mette i pesi in prova in un posto (a rotazione) contro IA normali; stampa la media di
## (punti del candidato - media dei punti degli altri) e la percentuale di vittorie.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var w: Dictionary = JSON.parse_string(args[0]) if args.size() > 0 and args[0] != "" else {}
	var games := int(args[1]) if args.size() > 1 else 20
	var s0 := int(args[2]) if args.size() > 2 else 1
	var np := int(args[3]) if args.size() > 3 else 4
	var var_on := args.size() > 4 and args[4] == "1"
	_run(w, games, s0, np, var_on)


func _run(w: Dictionary, games: int, s0: int, np: int, var_on: bool) -> void:
	await process_frame
	var diff := 0.0
	var wins := 0
	for g in games:
		var eng := THEngine.new()
		eng.headless = true
		root.add_child(eng)
		var seats := []
		for i in np:
			seats.append({"name": "", "ai": true, "level": 1, "color": i})
		eng.setup({"seats": seats, "seed": s0 + g, "variant": var_on})
		var cand := g % np
		for i in np:
			eng.ais[i] = THAI.new(1, s0 * 13 + g * 7 + i, w if i == cand else {})
		await eng.run()
		var sc: Array = eng.result["scores"]
		var others := 0.0
		for i in np:
			if i != cand:
				others += sc[i]["totale"]
		diff += sc[cand]["totale"] - others / (np - 1)
		if eng.result["winner"] == cand:
			wins += 1
		eng.queue_free()
	print("RISULTATO %.3f %.3f" % [diff / games, float(wins) / games])
	quit()
