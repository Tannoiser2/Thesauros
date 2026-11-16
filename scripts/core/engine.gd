class_name THEngine
extends Node
## Motore delle regole di Thesauros (senza grafica).
## Ogni scelta passa da `decide()`: l'IA risponde subito; per le persone viene emesso `decision_requested`
## e si attende `provide_decision()`. Online le scelte viaggiano nel registro di mosse (OnlineSession):
## con lo stesso seme ogni dispositivo gioca la stessa partita. Anche i salvataggi sono registri di mosse.
##
## Richieste (req["type"]) e risposte principali:
##  - "budget":      {money, year}                         → {"hr","rd","gp","me","bc": importi, "inc": conto degli incassi}
##  - "place":       {zones, meeples, can_env, can_dbl}    → {"m": meeple, "z": zona, "env": bool, "dbl": bool}
##  - "recruit":     nuovo lavoratore da mettere in coda     → {"z": zona, "env": bool, "dbl": bool}
##  - "z2":          {options}                             → {"a": "dev"|"buy"|"combo"|"res"|"none", "t": tecnologia}
##  - "sat":         due carte satellite                    → {"nums": [a, b]}
##  - "dig":         {tiles: [indici], site}               → {"i": scelta}
##  - "z3":          {slots: {casella: prezzo}}            → {"slot": casella} | {"none": true}
##  - "plane":       {zods, swap}                          → {"zod": id, "items": {…}, "swap": bool} | {"none": true}
##  - "sea":         {zod, dests: {nodo: costo}}           → {"dest": nodo, "dive_first": bool}
##  - "dive":        {zod, targets: [...], take}           → {"take": [righe]}
##  - "z7":          {options}                             → {"a": "shop"|"lagoon"|"sea"|"none", "spot", "zod", "items"}
##  - "island":      {tiles: [caselle]}                     → {"i": casella}
##  - "z8":          {sponsor, sell}                       → {"a": "sponsor", "room": i} | {"a": "sell", "v": valore, "room": i (-1 deposito)} | {"a": "none"}
##  - "bid":         {max}                                 → {"bid": n} (0 = rinuncia)
##  - "reserve":     {cards}                               → {"t": tecnologia}

const D = preload("res://scripts/data/th_data.gd")

signal changed
signal log_added(text: String)
signal decision_requested(req: Dictionary)
signal decision_provided(result)
signal game_ended(result: Dictionary)
signal fx(kind: String, data: Dictionary)

var players: Array = []          # [{name, ai, level, color}]
var ais: Array = []
var online = null
var ai_delay := 0.6
var anim := 1.0
var headless := false
var abort := false
var rng := RandomNumberGenerator.new()
var n := 0
var side := "34"
var L: Dictionary = {}           # disposizione del lato in uso
var solo := false
var initiation := false
var variant := false             # «Senza fede né legge»: aste per i mercenari
var replay: Array = []           # decisioni già prese (partita caricata da un salvataggio)
var replay_i := 0
var record: Array = []           # tutte le decisioni della partita (per salvarla)

var ps: Array = []
var order: Array = []            # ordine di turno attuale
var year := 1
var period := 1
var phase := "setup"             # "budget", "place", "resolve", "salary", "maint", "over"
var zone_now := 0
var current := -1
var queues := {}                 # zona -> Array di {p, m, dbl} o null
var z6: Array = []               # meeple in pesca delle cozze [{p, m, dbl}]
var envelopes: Array = []        # giocatori, nell'ordine di deposito
var tech_slots: Array = []       # 10 caselle: id tecnologia o ""
var deck: Array = []
var tech_owner := {}             # tecnologia -> giocatore (-1 nessuno, 9 giocatore virtuale)
var tech_sold := {}              # tecnologia -> copie vendute
var reserve := {}                # meeple sul mazzo: {p, m}
var reserved_next := {}          # meeple che riparte dalla prima casella della zona 2
var market: Array = []           # caselle: Array di numeri (pila)
var card_pool: Array = []
var sat_pool: Array = []
var piles := {"small": [], "large": []}
var sites := {}                  # numero -> {tile, large, up, grid, access: []}
var rooms: Array = []            # {sponsor, open, slots: [{p, v} o null], cfg}
var storage: Array = []          # [{p, v}]
var z6_idx := 0
var z9_idx := 0
var planes: Array = ["home", "home"]
var shop_used: Array = [-1, -1]
var lagoon_used := {}            # posto -> gommone
var island: Array = []           # 9 caselle: indice in D.ISLAND o -1
var hats := {2: 0, 3: 0, 57: 0, 8: 0}
var zods: Array = []             # gommoni
var over := false
var result := {}
var log_lines: Array = []
var last_dice := []
var history: Array = []          # reputazione a fine quadrimestre, per il riepilogo
# variante dei mercenari
var mercs_left := 0              # mercenari ancora da mettere all'asta
var merc_q := {}                 # zona -> {p, m} (casella del mercenario in questo quadrimestre)
var merc_used := {}              # zona -> giocatore che vi ha già usato un mercenario (il cubetto resta)
var merc_pool: Array = []        # carte tesoro del mercenario ancora disponibili
var black_plane := -1            # proprietario dell'idrovolante nero
var mine_owner := -1             # chi ha la mina subacquea (non ancora usata)
var planes_off := false          # idrovolanti grigi sabotati fino alla manutenzione
const MERC_ZONES := [1, 2, 3, 4, 7, 8, 9]
const MERC_HEAD := [1, 4]        # zone in cui il mercenario agisce prima della coda


# ================================================================ preparazione

func setup(cfg: Dictionary) -> void:
	players = cfg.get("seats", [])
	n = players.size()
	solo = n == 1
	initiation = bool(cfg.get("initiation", false))
	variant = bool(cfg.get("variant", false)) and players.size() >= 2 and not initiation
	side = "34" if n >= 3 else "12"
	L = D.SIDES[side]
	if cfg.has("seed"):
		rng.seed = int(cfg["seed"])
	else:
		rng.randomize()
	ai_delay = float(cfg.get("ai_delay", 0.6))
	anim = float(cfg.get("anim", 1.0))
	replay = cfg.get("replay", [])
	ais.resize(n)
	ps.clear()
	for i in n:
		var ms := []
		ms.append({"id": i * 10, "boss": true, "hat": 0, "loc": "room"})
		for k in 5:
			ms.append({"id": i * 10 + k + 1, "boss": false, "hat": 0, "loc": "room" if k < 2 else "reserve"})
		ps.append({"acc": {"hr": 0, "rd": 0, "gp": 0, "me": 0, "bc": 0}, "inc": "gp", "rep": 10, "meeples": ms,
			"hired": 0, "dbl": 0, "stock": {"metal": 1}, "treasures": [], "cards": [], "sat": [], "sharks": 0,
			"cash": 0, "fish": 0, "zods": [i], "merc_cards": [], "merc_n": 0})
	zods.clear()
	for z in 8:
		zods.append({"id": z, "color": D.ZODIAC_COLORS[z], "owner": z if z < n else -1, "loc": "port" if z < n else "shop",
			"crew": -1, "items": {}})


func pname(p: int) -> String:
	if p < 0 or p >= n:
		return "il banco"
	var nm: String = str(players[p].get("name", ""))
	return nm if nm != "" else D.COLORS[pcol(p)]["name"]


func pcol(p: int) -> int:
	return int(players[p].get("color", p))


func log_msg(t: String) -> void:
	log_lines.append(t)
	log_added.emit(t)


func _pace(sec: float) -> void:
	if headless or anim <= 0.0 or abort or not is_inside_tree():
		return
	if online != null and online.catchup:
		return
	if replay_i < replay.size():
		return
	await get_tree().create_timer(sec / anim).timeout


# ================================================================ decisioni

func decide(seat: int, req: Dictionary):
	req["seat"] = seat
	current = seat
	changed.emit()
	var r
	if replay_i < replay.size():
		r = replay[replay_i]
		replay_i += 1
	elif abort:
		r = ais[seat].decide(self, seat, req)
	elif online != null:
		r = await online.decide(self, seat, req)
	elif players[seat]["ai"]:
		if ai_delay > 0.0 and not headless and is_inside_tree():
			await get_tree().create_timer(ai_delay).timeout
		r = ais[seat].decide(self, seat, req)
	else:
		decision_requested.emit(req)
		r = await decision_provided
		if r == null:
			r = ais[seat].decide(self, seat, req)
	record.append(r)
	return r


func provide_decision(r) -> void:
	decision_provided.emit(r)


# ================================================================ denaro

func money(p: int) -> int:
	var t := 0
	for a in D.ACCOUNTS:
		t += ps[p]["acc"][a]
	return t


func fee() -> int:
	return year


## Quanto si può pagare da un conto, contando i trasferimenti dagli altri conti (ciascuno costa la tassa annuale).
func available(p: int, acct: String) -> int:
	var acc: Dictionary = ps[p]["acc"]
	var t: int = acc[acct]
	for a in D.ACCOUNTS:
		if a == acct or (a == "bc" and not initiation) or (acct == "bc"):
			continue
		if acc[a] > fee():
			t += acc[a] - fee()
	return t


func can_pay(p: int, acct: String, amount: int) -> bool:
	return amount <= 0 or available(p, acct) >= amount


## Paga dal conto indicato; se non basta trasferisce dagli altri conti (i più ricchi per primi) pagando la tassa.
func pay(p: int, acct: String, amount: int) -> bool:
	if amount <= 0:
		return true
	if not can_pay(p, acct, amount):
		return false
	var acc: Dictionary = ps[p]["acc"]
	if acc[acct] < amount and acct != "bc":
		var need: int = amount - acc[acct]
		var src := []
		for a in D.ACCOUNTS:
			if a != acct and (a != "bc" or initiation) and acc[a] > fee():
				src.append(a)
		src.sort_custom(func(x, y): return acc[x] > acc[y])
		for a in src:
			if need <= 0:
				break
			var take: int = mini(acc[a] - fee(), need)
			acc[a] -= take + fee()
			acc[acct] += take
			need -= take
			log_msg("   %s trasferisce %d$ da %s a %s (tassa %d$)" % [pname(p), take, D.ACC_SHORT[a], D.ACC_SHORT[acct], fee()])
	acc[acct] -= amount
	return true


func earn(p: int, amount: int, why := "") -> void:
	if amount <= 0:
		return
	ps[p]["acc"][ps[p]["inc"]] += amount
	if why != "":
		log_msg("   %s incassa %d$ (%s)" % [pname(p), amount, why])


func add_rep(p: int, v: int, why := "") -> void:
	var old: int = ps[p]["rep"]
	ps[p]["rep"] = maxi(0, old + v)
	if why != "" and ps[p]["rep"] != old:
		log_msg("   %s %s %d reputazione (%s)" % [pname(p), "guadagna" if v > 0 else "perde", absi(ps[p]["rep"] - old), why])
	if v != 0:
		fx.emit("rep", {"p": p, "v": v})


# ================================================================ meeple

func meeple(p: int, mid: int) -> Dictionary:
	for m in ps[p]["meeples"]:
		if m["id"] == mid:
			return m
	return {}


func meeples_at(p: int, loc: String) -> Array:
	var out := []
	for m in ps[p]["meeples"]:
		if m["loc"] == loc:
			out.append(m)
	return out


func workers(p: int) -> int:
	var c := 0
	for m in ps[p]["meeples"]:
		if m.get("merc", false):
			if m["loc"] == "room":
				c += 1
		elif not m["boss"] and m["loc"] != "reserve" and m["loc"] != "gone":
			c += 1
	return c


func reserve_left(p: int) -> int:
	return meeples_at(p, "reserve").size()


func meeple_name(m: Dictionary) -> String:
	if m.is_empty():
		return "?"
	if m.get("merc", false):
		return "un mercenario"
	if m["boss"]:
		return "il capo"
	if m["hat"] != 0:
		return "uno specialista n.%s" % ("5/7" if m["hat"] == 57 else str(m["hat"]))
	return "un lavoratore"


func expert(m: Dictionary, zone: int) -> bool:
	if m.is_empty() or m.get("merc", false):
		return false
	if m["boss"]:
		return true
	if zone in [5, 7]:
		return m["hat"] == 57
	return m["hat"] == zone


# ================================================================ code

func queue_len(z: int) -> int:
	var q: Dictionary = L["queues"][z]
	var c := 0
	for mp in q["minp"]:
		if mp == 0 or n >= mp:
			c += 1
	if solo and z in [2, 3, 7, 8]:
		c = mini(c, 2)
	return c


func queue_free_slot(z: int) -> int:
	if z == 6:
		return 0
	var arr: Array = queues[z]
	for i in queue_len(z):
		if arr[i] == null:
			return i
	return -1


func queue_cost(z: int, slot: int) -> int:
	var q: Dictionary = L["queues"][z]
	if q.has("cost"):
		return q["cost"][slot]
	return 0


func put_in_queue(p: int, mid: int, z: int, dbl: bool) -> void:
	var m := meeple(p, mid)
	m["loc"] = "q%d" % z
	if dbl:
		ps[p]["dbl"] -= 1
	if z == 6:
		z6.append({"p": p, "m": mid, "dbl": dbl})
		return
	var s := queue_free_slot(z)
	queues[z][s] = {"p": p, "m": mid, "dbl": dbl}


func _clear_queues() -> void:
	queues.clear()
	for z in L["queues"]:
		var arr := []
		arr.resize(L["queues"][z]["pos"].size())
		queues[z] = arr
	z6.clear()


# ================================================================ partita

func run() -> void:
	_setup_game()
	changed.emit()
	await _pace(0.5)
	for y in range(1, 4):
		year = y
		if y > 1:
			_income()
		await _phase_budget()
		if abort:
			return
		for k in 3:
			period = (y - 1) * 3 + k + 1
			await _phase_place()
			if abort:
				return
			await _phase_resolve()
			if abort:
				return
			_phase_salary()
			_snap()
			if _museum_full():
				log_msg("Tutte le sale del museo sono aperte al pubblico: la partita finisce.")
				_end_game()
				return
			if period < 9:
				await _phase_maint()
				if variant and period in [3, 5, 7, 8]:
					await _merc_auction()
		if y < 3 and not solo:
			_year_end()
	_end_game()


func _snap() -> void:
	var row := []
	for p in n:
		row.append(ps[p]["rep"])
	history.append(row)


func _setup_game() -> void:
	_clear_queues()
	# ordine di turno a caso e compensi
	order = range(n)
	_shuffle(order)
	var start := 55 if (initiation or solo or variant) else 50
	for i in n:
		var p: int = order[i]
		ps[p]["cash"] = start + (L["comp"][i] if i < L["comp"].size() else 0)
	# tecnologie
	tech_slots.resize(10)
	for i in 10:
		tech_slots[i] = ""
	for t in D.TECHS:
		tech_owner[t] = -1
		tech_sold[t] = 0
	tech_slots[0] = "maschera"
	if variant:
		# variante: tre carte di livello 0 a caso (non per forza la maschera)
		var v0 := ["maschera", "arpione", "sonar", "mot_piccolo"]
		_shuffle(v0)
		for i in 3:
			tech_slots[i] = v0[i]
		var vmix := [v0[3], "bombola", "mot_medio", "trapano", "sonar_av", "fucile", "nassa"]
		_shuffle(vmix)
		var vtop: Array = vmix.slice(0, 3)
		var vrest: Array = vmix.slice(3) + ["gabbia", "scafandro", "mot_super", "martello", "satellite"]
		_shuffle(vrest)
		deck = vtop + vrest
	elif initiation:
		tech_slots[1] = "arpione"
		tech_slots[2] = "mot_piccolo"
		var a := ["bombola", "sonar", "fucile", "nassa"]
		_shuffle(a)
		var b := ["mot_medio", "trapano", "sonar_av", "gabbia", "scafandro", "mot_super", "martello", "satellite"]
		_shuffle(b)
		deck = a + b
	else:
		var l0 := ["arpione", "sonar", "mot_piccolo"]
		_shuffle(l0)
		tech_slots[1] = l0[0]
		tech_slots[2] = l0[1]
		var mix := [l0[2], "bombola", "mot_medio", "trapano", "sonar_av", "fucile", "nassa"]
		_shuffle(mix)
		var top: Array = mix.slice(0, 3)
		var rest: Array = mix.slice(3) + ["gabbia", "scafandro", "mot_super", "martello", "satellite"]
		_shuffle(rest)
		deck = top + rest
	if solo:
		for i in 3:
			_solo_claim(i)
	# carte tesoro
	var maxc: int = L["cards_max"]
	card_pool.clear()
	for k in range(1, maxc + 1):
		for c in 3:
			card_pool.append(k)
	_shuffle(card_pool)
	sat_pool = range(1, maxc + 1)
	market.clear()
	for i in L["market_price"].size():
		market.append([])
	var to_place: int = L["market_start"]
	if initiation:
		var a0: int = L["market_arrow"]
		for k in range(1, 5):
			card_pool.erase(k)
			market[a0 + k - 1] = [k]
			to_place -= 1
	for i in to_place:
		_market_add(card_pool.pop_back())
	# siti di scavo
	piles["small"] = range(9)
	piles["large"] = range(12)
	_shuffle(piles["small"])
	_shuffle(piles["large"])
	sites.clear()
	for k in L["sites"]:
		sites[k] = {"tile": -1, "large": L["sites"][k]["large"], "up": false, "grid": [], "access": []}
	# museo
	rooms.clear()
	for cfg in L["rooms"]:
		var sl := []
		sl.resize(cfg["vp"].size())
		rooms.append({"sponsor": -1, "open": false, "slots": sl, "cfg": cfg})
	storage.clear()
	# isola: 9 oggetti su 12
	var bag := range(D.ISLAND.size())
	_shuffle(bag)
	island = bag.slice(0, 9)
	# cappelli
	if solo:
		var types := [2, 3, 57, 8]
		_shuffle(types)
		for t in hats:
			hats[t] = 1 if t in types.slice(0, 2) else 0
	else:
		var per := 1 if n <= 2 else (2 if n == 3 else 3)
		for t in hats:
			hats[t] = per
	z6_idx = 0
	z9_idx = 0
	planes = ["home", "home"]
	if variant:
		mercs_left = 4
		merc_pool = range(1, L["cards_max"] + 1)
		merc_used.clear()
	log_msg("Inizia la partita: %d %s, tabellone per %s giocatori%s." % [n, "compagnia" if n == 1 else "compagnie", "1-2" if side == "12" else "3-4",
		" (Iniziazione)" if initiation else (" (variante «Senza fede né legge»)" if variant else "")])
	var names := []
	for p in order:
		names.append(pname(p))
	if not solo:
		log_msg("Ordine di turno: %s." % ", ".join(names))


func _solo_claim(slot: int) -> void:
	if not solo or not (slot in D.SOLO_SLOTS):
		return
	var t: String = tech_slots[slot]
	if t == "" or tech_owner[t] != -1:
		return
	tech_owner[t] = 9
	tech_sold[t] = 1


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


# ================================================================ reddito e budget

func _income() -> void:
	var base := 30 if year == 2 else 10
	for p in n:
		var g: int = base + 5 * ps[p]["cards"].size()
		ps[p]["cash"] = g
		log_msg("%s riceve %d$ dagli investitori (%d carte tesoro)." % [pname(p), g, ps[p]["cards"].size()])


func _phase_budget() -> void:
	phase = "budget"
	zone_now = 0
	log_msg("=== Anno %d: gestione del budget ===" % year)
	for p in order:
		# il denaro rimasto torna tutto disponibile (senza tasse) e si aggiunge al reddito
		var tot: int = money(p) + ps[p]["cash"]
		var r = await decide(p, {"type": "budget", "money": tot, "year": year})
		_apply_budget(p, r, tot)
		changed.emit()


func _apply_budget(p: int, r, tot: int) -> void:
	var acc := {}
	var s := 0
	var ok := r is Dictionary
	if ok:
		for a in D.ACCOUNTS:
			var v := int(r.get(a, 0))
			if v < 0:
				ok = false
			acc[a] = v
			s += v
	if not ok or s != tot:
		acc = ais[p].default_budget(self, p, tot) if ais[p] != null else {"hr": tot, "rd": 0, "gp": 0, "me": 0, "bc": 0}
	ps[p]["acc"] = acc
	ps[p]["cash"] = 0
	var inc := str(r.get("inc", "gp")) if r is Dictionary else "gp"
	ps[p]["inc"] = inc if inc in ["hr", "rd", "gp", "me"] else "gp"
	log_msg("%s ripartisce %d$: RU %d, R&S %d, AG %d, SM %d, cassa nera ?." % [pname(p), tot, acc["hr"], acc["rd"], acc["gp"], acc["me"]])


# ================================================================ piazzamento

func zone_options(p: int) -> Array:
	var out := []
	for z in [1, 2, 3, 4, 6, 7, 8, 9]:
		if z != 6 and queue_free_slot(z) < 0:
			continue
		if z == 1 and reserve_left(p) == 0:
			continue
		if z == 4 and zods_of(p, "sea").is_empty():
			continue
		out.append(z)
	return out


func _phase_place() -> void:
	phase = "place"
	zone_now = 0
	_clear_queues()
	merc_q.clear()
	envelopes.clear()
	for p in n:
		ps[p]["env_used"] = false
		for m in ps[p]["meeples"]:
			if m["loc"] == "idle":
				m["loc"] = "room"
	if not reserved_next.is_empty():
		var rp: int = reserved_next["p"]
		queues[2][0] = {"p": rp, "m": reserved_next["m"], "dbl": false}
		meeple(rp, reserved_next["m"])["loc"] = "q2"
		reserved_next = {}
	log_msg("--- Quadrimestre %d: piazzamento ---" % period)
	var guard := 0
	while guard < 60:
		guard += 1
		var any := false
		for p in order:
			var room := meeples_at(p, "room")
			if room.is_empty():
				continue
			any = true
			var ids := []
			for m in room:
				ids.append(m["id"])
			var zones := zone_options(p)
			var req := {"type": "place", "zones": zones, "meeples": ids, "can_env": not solo and not ps[p]["env_used"],
				"can_dbl": ps[p]["dbl"] > 0, "merc_zones": merc_zones()}
			var r = await decide(p, req)
			if abort:
				return
			var mid: int = int(r.get("m", ids[0])) if r is Dictionary else int(ids[0])
			if not (mid in ids):
				mid = ids[0]
			var z := int(r.get("z", 6)) if r is Dictionary else 6
			var is_merc: bool = meeple(p, mid).get("merc", false)
			if is_merc and not (z in req["merc_zones"]):
				# un mercenario va solo nelle caselle libere dei mercenari: se non ce ne sono, si usa un altro meeple
				var other := -1
				for x in ids:
					if not meeple(p, x).get("merc", false):
						other = x
						break
				if other >= 0 or req["merc_zones"].is_empty():
					mid = other if other >= 0 else mid
					is_merc = other < 0
				if is_merc:
					z = req["merc_zones"][0] if not req["merc_zones"].is_empty() else -1
			if not is_merc and not (z in zones):
				z = 6
			var env: bool = r is Dictionary and bool(r.get("env", false)) and req["can_env"]
			var dbl: bool = r is Dictionary and bool(r.get("dbl", false)) and req["can_dbl"] and z in [1, 2, 3, 6, 8, 9] and not is_merc
			if env:
				envelopes.append(p)
				ps[p]["env_used"] = true
			if is_merc:
				if z < 0:
					# nessuna casella libera: il mercenario resta in sede
					meeple(p, mid)["loc"] = "idle"
					log_msg("%s non trova un posto per il mercenario." % pname(p))
					continue
				merc_q[z] = {"p": p, "m": mid}
				meeple(p, mid)["loc"] = "mq%d" % z
				log_msg("%s manda un mercenario in zona %d (%s)%s." % [pname(p), z, D.ZONE_NAMES[z], " con la busta per le autorità" if env else ""])
				changed.emit()
				await _pace(0.25)
				continue
			put_in_queue(p, mid, z, dbl)
			log_msg("%s manda %s in zona %d (%s)%s%s." % [pname(p), meeple_name(meeple(p, mid)), z, D.ZONE_NAMES[z],
				" con la busta per le autorità" if env else "", ", con la doppia azione" if dbl else ""])
			changed.emit()
			await _pace(0.25)
		if not any:
			break


# ================================================================ risoluzione

func _phase_resolve() -> void:
	phase = "resolve"
	for z in range(1, 11):
		zone_now = z
		changed.emit()
		if variant and merc_q.has(z) and z in MERC_HEAD:
			await _merc_act(z)
		match z:
			1: await _zone1()
			2: await _zone_generic(2)
			3: await _zone_generic(3)
			4: await _zone_generic(4)
			5: await _zone5()
			6: _zone6()
			7: await _zone_generic(7)
			8: await _zone_generic(8)
			9: _zone9()
			10: await _zone10()
		if variant and merc_q.has(z) and not (z in MERC_HEAD):
			await _merc_act(z)
		if abort:
			return
		await _pace(0.3)
	zone_now = 0


func _return_meeple(p: int, mid: int) -> void:
	var m := meeple(p, mid)
	if not m.is_empty():
		m["loc"] = "room"


func _fail(p: int, z: int) -> void:
	add_rep(p, -1, "azione non svolta in zona %d" % z)


## Formazione degli specialisti: il primo lavoratore senza cappello che sta in coda con il capo.
func _train(z: int) -> void:
	var hz := 57 if z == 7 else z
	if not hats.has(hz):
		return
	var seen := {}
	for e in queues[z]:
		if e == null or seen.has(e["p"]) or hats[hz] <= 0:
			continue
		var p: int = e["p"]
		var has_boss := false
		var cand := {}
		for f in queues[z]:
			if f == null or f["p"] != p:
				continue
			var m := meeple(p, f["m"])
			if m["boss"]:
				has_boss = true
			elif m["hat"] == 0 and cand.is_empty():
				cand = m
		if has_boss and not cand.is_empty():
			seen[p] = true
			cand["hat"] = hz
			hats[hz] -= 1
			log_msg("%s: un lavoratore impara dal capo e diventa specialista n.%s." % [pname(p), "5/7" if hz == 57 else str(hz)])
			fx.emit("hat", {"p": p, "m": cand["id"], "z": z})


func _zone1() -> void:
	for i in queues[1].size():
		var e = queues[1][i]
		if e == null:
			continue
		var p: int = e["p"]
		var m := meeple(p, e["m"])
		var times := 2 if e["dbl"] else 1
		for t in times:
			if reserve_left(p) == 0:
				if t == 0:
					_fail(p, 1)
				break
			var cost: int = queue_cost(1, i) - (2 if m["boss"] else 0)
			if not pay(p, "hr", cost):
				if t == 0:
					_fail(p, 1)
				break
			await _recruit(p, cost)
		_return_meeple(p, e["m"])
		changed.emit()


func _recruit(p: int, cost: int) -> void:
	var nw: Dictionary = meeples_at(p, "reserve")[0]
	nw["loc"] = "room"
	ps[p]["hired"] += 1
	var h: int = ps[p]["hired"]
	log_msg("%s assume un lavoratore (%d$)." % [pname(p), cost])
	if h == 2 and not ps[p].get("dbl_stolen", false):
		ps[p]["dbl"] += 1
		log_msg("   prende il segnalino doppia azione.")
	elif h == 3:
		add_rep(p, 1, "terzo lavoratore assunto")
	# il nuovo lavoratore entra subito in una coda
	var zones := []
	for z in [2, 3, 4, 6, 7, 8, 9]:
		if z == 6 or queue_free_slot(z) >= 0:
			zones.append(z)
	var r = await decide(p, {"type": "recruit", "zones": zones, "m": nw["id"], "can_env": not solo and not ps[p]["env_used"],
		"can_dbl": ps[p]["dbl"] > 0})
	var z := int(r.get("z", 6)) if r is Dictionary else 6
	if not (z in zones):
		z = 6
	if r is Dictionary and bool(r.get("env", false)) and not solo and not ps[p]["env_used"]:
		envelopes.append(p)
		ps[p]["env_used"] = true
	var dbl: bool = r is Dictionary and bool(r.get("dbl", false)) and ps[p]["dbl"] > 0 and z in [2, 3, 6, 8, 9]
	put_in_queue(p, nw["id"], z, dbl)
	log_msg("   il nuovo lavoratore va in zona %d (%s)." % [z, D.ZONE_NAMES[z]])


func _zone_generic(z: int) -> void:
	if z in [2, 3, 7, 8]:
		_train(z)
	for i in queues[z].size():
		var e = queues[z][i]
		if e == null:
			continue
		var p: int = e["p"]
		var m := meeple(p, e["m"])
		var times := 2 if e["dbl"] else 1
		var stays := false
		for t in times:
			var done := false
			match z:
				2:
					var res = await _act2(p, m)
					done = res != ""
					if res == "res":
						stays = true
						break
				3: done = await _act3(p, m)
				4:
					var r4 = await _act4(p, m, i)
					done = r4 != ""
					stays = r4 == "swap"
				7:
					var r7 = await _act7(p, m)
					done = r7 != ""
					stays = done
				8: done = await _act8(p, m)
			if not done:
				if t == 0:
					_fail(p, z)
				break
			changed.emit()
		if not stays:
			_return_meeple(p, e["m"])
		changed.emit()
		await _pace(0.2)


# ---------------------------------------------------------------- zona 2

func copies(t: String) -> int:
	var k := 2 if n <= 2 else n
	return D.COPIES[D.TECHS[t]["col"]][k]


func tech_left(t: String) -> int:
	if tech_owner[t] == -1:
		return copies(t)
	return copies(t) - tech_sold[t]


func visible_techs() -> Array:
	var out := []
	for t in tech_slots:
		if t != "":
			out.append(t)
	return out


func tech_costs(p: int, m: Dictionary, t: String) -> Dictionary:
	var c: Dictionary = D.TECHS[t]
	var disc := 2 if expert(m, 2) else 0
	var own: int = tech_owner[t]
	var out := {}
	if own == -1:
		out["dev"] = maxi(0, c["d"] - disc)
		out["combo"] = maxi(0, c["d"] + c["g"] + c["h"] - disc)
	elif tech_left(t) > 0:
		out["buy"] = maxi(0, c["g"] - disc) + (0 if own == p else c["h"])
	return out


func z2_options(p: int, m: Dictionary) -> Dictionary:
	var opts := {}
	for t in visible_techs():
		var cs := tech_costs(p, m, t)
		var ok := {}
		for k in cs:
			if can_pay(p, "rd", cs[k]):
				ok[k] = cs[k]
		if not ok.is_empty():
			opts[t] = ok
	return opts


func _act2(p: int, m: Dictionary) -> String:
	var opts := z2_options(p, m)
	var can_res := reserve.is_empty() and not deck.is_empty() and period <= 5
	if opts.is_empty() and not can_res:
		return ""
	var r = await decide(p, {"type": "z2", "options": opts, "can_res": can_res, "m": m["id"]})
	var a := str(r.get("a", "none")) if r is Dictionary else "none"
	if a == "res" and can_res:
		reserve = {"p": p, "m": m["id"]}
		m["loc"] = "deck"
		log_msg("%s prenota la prossima carta tecnologia." % pname(p))
		return "res"
	var t := str(r.get("t", "")) if r is Dictionary else ""
	if not opts.has(t) or not opts[t].has(a):
		return ""
	var cost: int = opts[t][a]
	var c: Dictionary = D.TECHS[t]
	match a:
		"dev":
			pay(p, "rd", cost)
			tech_owner[t] = p
			tech_sold[t] = 0
			log_msg("%s sviluppa il brevetto: %s (%d$)." % [pname(p), D.ITEMS[t]["name"], cost])
		"combo":
			pay(p, "rd", cost)
			tech_owner[t] = p
			tech_sold[t] = 1
			_gain_item(p, t)
			log_msg("%s sviluppa %s e ne compra il prototipo (%d$)." % [pname(p), D.ITEMS[t]["name"], cost])
		"buy":
			var own: int = tech_owner[t]
			var royal: int = 0 if own == p else c["h"]
			pay(p, "rd", cost)
			if own >= 0 and own < n and own != p:
				earn(own, royal, "royalty su %s" % D.ITEMS[t]["name"])
			tech_sold[t] += 1
			_gain_item(p, t)
			log_msg("%s compra: %s (%d$)." % [pname(p), D.ITEMS[t]["name"], cost])
	fx.emit("tech", {"p": p, "t": t, "a": a})
	if t == "satellite" and a != "dev":
		await _satellite(p)
	return a


func _gain_item(p: int, t: String) -> void:
	var st: Dictionary = ps[p]["stock"]
	st[t] = st.get(t, 0) + 1


func _satellite(p: int) -> void:
	var r = await decide(p, {"type": "sat", "pool": sat_pool.duplicate()})
	var nums := []
	if r is Dictionary:
		for x in r.get("nums", []):
			if int(x) in sat_pool and not (int(x) in nums):
				nums.append(int(x))
	for x in sat_pool:
		if nums.size() >= 2:
			break
		if not (x in nums):
			nums.append(x)
	for x in nums.slice(0, 2):
		sat_pool.erase(x)
		ps[p]["sat"].append(x)
		await _gain_card(p, x, true)


# ---------------------------------------------------------------- carte tesoro e siti

func market_slots(p: int, m: Dictionary) -> Dictionary:
	var out := {}
	for i in market.size():
		if market[i].is_empty():
			continue
		var c: int = maxi(0, L["market_price"][i] - (2 if expert(m, 3) else 0))
		if can_pay(p, "gp", c):
			out[i] = c
	return out


func _market_add(k: int) -> void:
	for i in market.size():
		if not market[i].is_empty() and market[i][0] == k:
			market[i].append(k)
			# domanda e offerta: la pila scende alla prima casella libera più economica
			for j in range(i - 1, -1, -1):
				if market[j].is_empty():
					market[j] = market[i]
					market[i] = []
					return
			return
	var a: int = L["market_arrow"]
	for i in range(a, market.size()):
		if market[i].is_empty():
			market[i] = [k]
			return
	for i in range(a - 1, -1, -1):
		if market[i].is_empty():
			market[i] = [k]
			return
	card_pool.push_front(k)


func _act3(p: int, m: Dictionary) -> bool:
	var slots := market_slots(p, m)
	if slots.is_empty():
		return false
	var r = await decide(p, {"type": "z3", "slots": slots, "m": m["id"]})
	if not (r is Dictionary) or not slots.has(int(r.get("slot", -1))):
		return false
	var i := int(r["slot"])
	pay(p, "gp", slots[i])
	var k: int = market[i].pop_back()
	if not market[i].is_empty():
		for j in range(i + 1, market.size()):
			if market[j].is_empty():
				market[j] = market[i]
				market[i] = []
				break
	log_msg("%s compra la carta tesoro %d (%d$)." % [pname(p), k, slots[i]])
	await _gain_card(p, k, false)
	return true


func _gain_card(p: int, k: int, sat: bool) -> void:
	ps[p]["cards"].append(k)
	fx.emit("card", {"p": p, "k": k})
	if not sites.has(k):
		return
	var s: Dictionary = sites[k]
	if not (p in s["access"]):
		s["access"].append(p)
	if s["tile"] == -1:
		var pile: Array = piles["large" if s["large"] else "small"]
		var draw: Array = pile.slice(0, 3)
		for x in draw:
			pile.erase(x)
		var r = await decide(p, {"type": "dig", "site": k, "tiles": draw, "large": s["large"]})
		var ch := int(r.get("i", 0)) if r is Dictionary else 0
		ch = clampi(ch, 0, draw.size() - 1)
		var chosen: int = draw[ch]
		draw.remove_at(ch)
		pile.append_array(draw)
		s["tile"] = chosen
		var src: Array = SitesData.get_tiles(s["large"])
		s["grid"] = src[chosen].duplicate(true)
		log_msg("   %s sceglie in segreto la tessera del sito %d." % [pname(p), k])
	if sat:
		log_msg("   %s riceve la carta satellite %d." % [pname(p), k])


func has_card(p: int, k: int) -> bool:
	return k in ps[p]["cards"]


# ---------------------------------------------------------------- gommoni e mare

func zod(id: int) -> Dictionary:
	return zods[id]


func zods_of(p: int, where := "") -> Array:
	var out := []
	for z in zods:
		if z["owner"] == p and (where == "" or (where == "sea" and is_sea(z["loc"])) or z["loc"] == where):
			out.append(z)
	return out


func is_sea(loc: String) -> bool:
	return loc != "port" and loc != "shop" and loc != "spare" and not loc.begins_with("lag:")


func port_free_zods(p: int) -> Array:
	var out := []
	for z in zods_of(p, "port"):
		if z["crew"] == -1:
			out.append(z)
	return out


func engines(z: Dictionary) -> Array:
	var out := []
	for k in z["items"]:
		if D.ITEMS.has(k) and D.ITEMS[k].get("engine", false):
			for c in z["items"][k]:
				out.append(k)
	return out


## Caselle gratuite e opzioni a pagamento (1$ ciascuna) di un gommone.
func move_profile(z: Dictionary) -> Dictionary:
	var free := 2
	var paid := [1]
	for k in engines(z).slice(0, 2):
		free += D.ITEMS[k]["free"]
		if D.ITEMS[k]["paid"] > 0:
			paid.append(D.ITEMS[k]["paid"])
	paid.sort()
	paid.reverse()
	return {"free": free, "paid": paid}


func move_cost(z: Dictionary, dist: int) -> int:
	var pr := move_profile(z)
	if dist <= pr["free"]:
		return 0
	var need: int = dist - pr["free"]
	var c := 0
	for v in pr["paid"]:
		if need <= 0:
			break
		need -= v
		c += 1
	return c if need <= 0 else -1


func move_max(z: Dictionary) -> int:
	var pr := move_profile(z)
	var t: int = pr["free"]
	for v in pr["paid"]:
		t += v
	return t


## Grafo del mare: nodi numerati, aree di pesca, caselle d'immersione dei siti e porto.
func neighbors(node: String) -> Array:
	var out := []
	for e in L["edges"]:
		if e[0] == node:
			out.append(e[1])
		elif e[1] == node:
			out.append(e[0])
	if node.begins_with("N"):
		var k := int(node.substr(1))
		if sites.has(k):
			for c in _site_cols(k):
				out.append("D%d_%d" % [k, c])
	var extra: Dictionary = L.get("extra_links", {})
	if extra.has(node):
		var k2: int = extra[node]
		for c in _site_cols(k2):
			out.append("D%d_%d" % [k2, c])
	if node.begins_with("D"):
		var k := int(node.substr(1, node.find("_") - 1))
		var c := int(node.substr(node.find("_") + 1))
		out.append("N%d" % k)
		for kk in extra:
			if extra[kk] == k:
				out.append(kk)
		if c > 0:
			out.append("D%d_%d" % [k, c - 1])
		if c < _site_cols(k).size() - 1:
			out.append("D%d_%d" % [k, c + 1])
	return out


func _site_cols(k: int) -> Array:
	return range(5 if sites[k]["large"] else 4)


func node_site(node: String) -> int:
	if node.begins_with("N"):
		return int(node.substr(1))
	if node.begins_with("D"):
		return int(node.substr(1, node.find("_") - 1))
	return 0


func can_enter(p: int, node: String) -> bool:
	var k := node_site(node)
	return k == 0 or has_card(p, k)


func occupied(node: String, except_id := -1) -> bool:
	if node == "PORT" or node.begins_with("F"):
		return false
	for z in zods:
		if z["id"] != except_id and z["loc"] == node:
			return true
	return false


## Distanze dal punto di partenza, rispettando le carte tesoro possedute.
func distances(p: int, from: String) -> Dictionary:
	var dist := {from: 0}
	var q := [from]
	while not q.is_empty():
		var a: String = q.pop_front()
		for b in neighbors(a):
			if dist.has(b) or not can_enter(p, b):
				continue
			dist[b] = dist[a] + 1
			q.append(b)
	return dist


func path_to(p: int, from: String, to: String) -> Array:
	var prev := {from: ""}
	var q := [from]
	while not q.is_empty():
		var a: String = q.pop_front()
		if a == to:
			break
		for b in neighbors(a):
			if prev.has(b) or not can_enter(p, b):
				continue
			prev[b] = a
			q.append(b)
	if not prev.has(to):
		return []
	var path := [to]
	while path[0] != from:
		path.push_front(prev[path[0]])
	return path


## Destinazioni raggiungibili da un gommone: nodo -> costo in dollari.
func destinations(p: int, z: Dictionary) -> Dictionary:
	var out := {}
	var from: String = z["loc"]
	var dist := distances(p, from)
	var mx := move_max(z)
	for node in dist:
		var d: int = dist[node]
		if d > mx:
			continue
		if node != from and occupied(node, z["id"]):
			continue
		var c := move_cost(z, d)
		if c < 0 or not can_pay(p, "me", c):
			continue
		out[node] = c
	return out


func _zone5() -> void:
	var any := mine_owner >= 0
	for z in zods:
		if z["owner"] >= 0 and is_sea(z["loc"]):
			any = true
	if not any:
		return
	log_msg("--- Alto mare ---")
	for p in order:
		if mine_owner == p:
			await _use_mine(p)
		var mine := zods_of(p, "sea")
		if mine.is_empty():
			continue
		# idrovolante nero: solo per chi l'ha rubato, gratis
		if black_plane == p and _has_spare_items(p):
			var bids := []
			for z in mine:
				bids.append(z["id"])
			var rb = await decide(p, {"type": "plane", "zods": bids, "swap": false, "cost": 0, "black": true})
			if rb is Dictionary and not rb.get("none", false) and int(rb.get("zod", -1)) in bids:
				if rb.get("items") is Dictionary:
					set_loadout(p, zod(int(rb["zod"])), rb["items"])
				log_msg("%s usa l'idrovolante nero." % pname(p))
				fx.emit("blackplane", {"p": p, "zod": int(rb["zod"])})
		# idrovolante a noleggio (solo oggetti)
		var free_planes := planes.count("home")
		var cost := 3 if (side == "12" or free_planes >= 2) else 4
		if free_planes > 0 and can_pay(p, "me", cost) and _has_spare_items(p):
			var ids := []
			for z in mine:
				ids.append(z["id"])
			var r = await decide(p, {"type": "plane", "zods": ids, "swap": false, "cost": cost})
			if r is Dictionary and not r.get("none", false) and int(r.get("zod", -1)) in ids:
				pay(p, "me", cost)
				_use_plane(p, zod(int(r["zod"])), r.get("items", {}))
				log_msg("%s noleggia un idrovolante (%d$)." % [pname(p), cost])
		for z in zods_of(p, "sea"):
			await _sea_turn(p, z)
			changed.emit()
			if abort:
				return


func _has_spare_items(p: int) -> bool:
	for k in ps[p]["stock"]:
		if ps[p]["stock"][k] > 0:
			return true
	return false


func _use_plane(p: int, z: Dictionary, items) -> void:
	var i := planes.find("home")
	if i >= 0:
		planes[i] = z["id"]
	if items is Dictionary:
		set_loadout(p, z, items)


## Nuova dotazione di un gommone: ciò che manca torna nel magazzino della compagnia.
func valid_loadout(p: int, z: Dictionary, items: Dictionary) -> bool:
	var eng := 0
	for k in items:
		if not D.ITEMS.has(k):
			return false
		var v := int(items[k])
		if v < 0 or v > int(z["items"].get(k, 0)) + int(ps[p]["stock"].get(k, 0)):
			return false
		if D.ITEMS[k].get("engine", false):
			eng += v
	return eng <= 2


func set_loadout(p: int, z: Dictionary, items: Dictionary) -> void:
	if not valid_loadout(p, z, items):
		return
	var st: Dictionary = ps[p]["stock"]
	for k in z["items"]:
		st[k] = st.get(k, 0) + z["items"][k]
	var nz := {}
	for k in items:
		var v := int(items[k])
		if v > 0:
			nz[k] = v
			st[k] -= v
	for k in st.keys():
		if st[k] <= 0:
			st.erase(k)
	z["items"] = nz


func _sea_turn(p: int, z: Dictionary) -> void:
	var dests := destinations(p, z)
	var here_dive := _dive_targets(p, z).size() > 0
	var r = await decide(p, {"type": "sea", "zod": z["id"], "dests": dests, "can_dive_here": here_dive})
	var dest: String = str(r.get("dest", z["loc"])) if r is Dictionary else str(z["loc"])
	if not dests.has(dest):
		dest = z["loc"]
	var dive_first: bool = r is Dictionary and bool(r.get("dive_first", false)) and here_dive
	if dive_first:
		await _dive(p, z)
	if dest != z["loc"]:
		var c: int = dests[dest]
		pay(p, "me", c)
		var path := path_to(p, z["loc"], dest)
		fx.emit("move", {"zod": z["id"], "path": path})
		log_msg("%s muove il gommone %s verso %s%s." % [pname(p), z["color"], node_name(dest), (" (%d$)" % c) if c > 0 else ""])
		z["loc"] = dest
		await _pace(0.4)
		if dest == "PORT":
			_dock(p, z)
			return
		_arrive(p, dest)
	if not dive_first and _dive_targets(p, z).size() > 0:
		await _dive(p, z)
	if z["loc"].begins_with("F"):
		earn(p, 2, "pesca con la lenza")
		ps[p]["fish"] += 2


func node_name(node: String) -> String:
	if node == "PORT":
		return "il porto"
	if node.begins_with("F"):
		return "l'area di pesca"
	if node.begins_with("N"):
		return "la casella %s" % node.substr(1)
	if node.begins_with("D"):
		return "il sito %d" % node_site(node)
	return node


func _dock(p: int, z: Dictionary) -> void:
	z["loc"] = "port"
	if z["crew"] != -1:
		_return_meeple(p, z["crew"])
	z["crew"] = -1
	log_msg("   il gommone rientra in porto.")


func _arrive(p: int, node: String) -> void:
	if not node.begins_with("D"):
		return
	var k := node_site(node)
	var s: Dictionary = sites[k]
	if not s["up"] and s["tile"] >= 0:
		s["up"] = true
		log_msg("   il sito %d viene scoperto." % k)
		fx.emit("reveal", {"site": k})


func zod_depth(z: Dictionary) -> int:
	var d := 1
	for k in ["maschera", "bombola", "scafandro"]:
		if z["items"].get(k, 0) > 0:
			d = maxi(d, D.ITEMS[k]["depth"])
	return d


func zod_has(z: Dictionary, k: String) -> bool:
	return z["items"].get(k, 0) > 0


## Tesori raggiungibili dalla casella d'immersione: [{r, v, cost, kind}].
func _dive_targets(p: int, z: Dictionary) -> Array:
	var loc: String = z["loc"]
	if not loc.begins_with("D"):
		return []
	var k := node_site(loc)
	var col := int(loc.substr(loc.find("_") + 1))
	var s: Dictionary = sites[k]
	if s["grid"].is_empty():
		return []
	var depth := zod_depth(z)
	var shark_ok := zod_has(z, "arpione") or zod_has(z, "fucile") or zod_has(z, "fucile_plus") or zod_has(z, "gabbia")
	var out := []
	var rows: int = s["grid"].size()
	for r in rows:
		if s["grid"][r][col] == "M":
			break
		if r + 1 > depth:
			break
		var c: String = s["grid"][r][col]
		if c == "S":
			if not shark_ok:
				break
			continue
		if c.begins_with("T"):
			out.append({"r": r, "v": int(c.substr(1)), "cost": 0, "kind": "T"})
		elif c.begins_with("N"):
			var dc := _detect_cost(z, r)
			if k in ps[p]["merc_cards"] and r + 1 <= depth:
				dc = 0
			if dc >= 0:
				out.append({"r": r, "v": int(c.substr(1)), "cost": dc, "kind": "N"})
		elif c.begins_with("I"):
			var xc := _dig_cost(z, r)
			if xc >= 0:
				out.append({"r": r, "v": int(c.substr(1)), "cost": xc, "kind": "I"})
			else:
				break
		elif c == "R":
			# si passa la roccia solo per arrivare a un tesoro incastrato più in basso
			var deeper := false
			for r2 in range(r + 1, mini(rows, depth)):
				var c2: String = s["grid"][r2][col]
				if c2.begins_with("I") and _dig_cost(z, r2) >= 0:
					deeper = true
			if not deeper:
				break
	return out


func _detect_cost(z: Dictionary, r: int) -> int:
	var best := -1
	for k in ["satellite", "sonar", "sonar_plus", "sonar_av"]:
		if zod_has(z, k) and r + 1 <= D.ITEMS[k]["range"]:
			var u: int = D.ITEMS[k]["use"]
			if best < 0 or u < best:
				best = u
	return best


func _dig_cost(z: Dictionary, r: int) -> int:
	var best := -1
	for k in ["trapano", "martello"]:
		if zod_has(z, k) and r + 1 <= D.ITEMS[k]["dig"]:
			var u: int = D.ITEMS[k]["use"]
			if best < 0 or u < best:
				best = u
	return best


func _dive(p: int, z: Dictionary) -> void:
	var targets := _dive_targets(p, z)
	if targets.is_empty():
		return
	var crew := meeple(p, z["crew"])
	var take := 2 if expert(crew, 5) else 1
	var r = await decide(p, {"type": "dive", "zod": z["id"], "targets": targets, "take": take})
	var rows := []
	if r is Dictionary:
		for x in r.get("take", []):
			rows.append(int(x))
	var chosen := []
	for t in targets:
		if t["r"] in rows and chosen.size() < take and can_pay(p, "me", _sum_cost(chosen) + t["cost"]):
			chosen.append(t)
	if chosen.is_empty():
		return
	var loc: String = z["loc"]
	var k := node_site(loc)
	var col := int(loc.substr(loc.find("_") + 1))
	var s: Dictionary = sites[k]
	var deepest := 0
	for t in chosen:
		deepest = maxi(deepest, t["r"])
	log_msg("%s si immerge nel sito %d." % [pname(p), k])
	# squali incontrati scendendo
	for rr in range(0, deepest):
		if s["grid"][rr][col] == "S":
			_shark(p, z, crew, s, rr, col)
	for t in chosen:
		pay(p, "me", t["cost"])
		s["grid"][t["r"]][col] = "X"
		ps[p]["treasures"].append(t["v"])
		log_msg("   recupera un tesoro di %s (%d$)%s." % [D.TREASURE_NAMES[t["v"]], t["v"], (" usando l'attrezzatura (%d$)" % t["cost"]) if t["cost"] > 0 else ""])
		fx.emit("treasure", {"p": p, "v": t["v"], "site": k, "r": t["r"], "c": col})
	await _pace(0.4)


func _sum_cost(a: Array) -> int:
	var s := 0
	for t in a:
		s += t["cost"]
	return s


func _shark(p: int, z: Dictionary, crew: Dictionary, s: Dictionary, r: int, col: int) -> void:
	var gun := zod_has(z, "fucile") or zod_has(z, "fucile_plus")
	var harp := zod_has(z, "arpione")
	var cage := zod_has(z, "gabbia")
	if not gun and not harp:
		log_msg("   la gabbia lo protegge da uno squalo.")
		return
	var need := 4 if gun else 6
	var bonus := (2 if cage else 0) + (1 if expert(crew, 5) else 0) + (1 if zod_has(z, "fucile_plus") else 0)
	var die := 1
	if need - bonus > 1:
		die = rng.randi_range(1, 6)
	last_dice = [die]
	if die + bonus >= need:
		s["grid"][r][col] = "K"
		ps[p]["sharks"] += 1
		log_msg("   uccide uno squalo (dado %d%s)." % [die, (" +%d" % bonus) if bonus > 0 else ""])
		fx.emit("shark", {"p": p, "kill": true, "die": die})
	else:
		log_msg("   lo squalo fugge spaventato (dado %d%s)." % [die, (" +%d" % bonus) if bonus > 0 else ""])
		fx.emit("shark", {"p": p, "kill": false, "die": die})


# ---------------------------------------------------------------- zona 4

func _act4(p: int, m: Dictionary, slot: int) -> String:
	var mine := zods_of(p, "sea")
	var i := planes.find("home")
	if mine.is_empty() or i < 0:
		return ""
	var cost: int = queue_cost(4, slot) - (2 if m["boss"] else 0)
	if side == "12":
		cost = 3 - (2 if m["boss"] else 0)
	if not can_pay(p, "me", cost):
		return ""
	var ids := []
	for z in mine:
		ids.append(z["id"])
	var r = await decide(p, {"type": "plane", "zods": ids, "swap": true, "cost": cost, "m": m["id"]})
	if not (r is Dictionary) or r.get("none", false) or not (int(r.get("zod", -1)) in ids):
		return ""
	pay(p, "me", cost)
	var z := zod(int(r["zod"]))
	_use_plane(p, z, r.get("items", {}))
	log_msg("%s prenota un idrovolante (%d$) per il gommone %s." % [pname(p), cost, z["color"]])
	if bool(r.get("swap", false)) and z["crew"] != -1:
		var old: int = z["crew"]
		_return_meeple(p, old)
		z["crew"] = m["id"]
		m["loc"] = "sea"
		log_msg("   il pilota prende il posto dell'equipaggio, che rientra in sede.")
		return "swap"
	return "ok"


# ---------------------------------------------------------------- zona 6 e 9

func _zone6() -> void:
	if z6.is_empty():
		return
	for e in z6:
		var p: int = e["p"]
		var m := meeple(p, e["m"])
		var times := 2 if e["dbl"] else 1
		for t in times:
			match z6_idx:
				0: earn(p, 1, "cozze")
				1: earn(p, 2, "cozze")
				2: add_rep(p, 1, "cozze")
			if m["boss"]:
				earn(p, 2, "cozze, bonus del capo")
			ps[p]["fish"] += [1, 2, 0][z6_idx]
		_return_meeple(p, e["m"])
	z6_idx = mini(2, z6_idx + 1)


func _zone9() -> void:
	var any := false
	for i in queues[9].size():
		var e = queues[9][i]
		if e == null:
			continue
		any = true
		var p: int = e["p"]
		var m := meeple(p, e["m"])
		var times := 2 if e["dbl"] else 1
		for t in times:
			var cost: int = queue_cost(9, i) - (2 if m["boss"] else 0)
			if pay(p, "gp", cost):
				log_msg("%s paga %d$ di pubblicità." % [pname(p), cost])
				add_rep(p, D.Z9_REP[z9_idx], "pubblicità")
			elif t == 0:
				_fail(p, 9)
		_return_meeple(p, e["m"])
	if any:
		z9_idx = mini(3, z9_idx + 1)


# ---------------------------------------------------------------- zona 7

func lagoon_free(spot: String) -> bool:
	return not lagoon_used.has(spot)


func z7_options(p: int, m: Dictionary) -> Dictionary:
	var out := {}
	var disc := 2 if expert(m, 7) else 0
	var shop := []
	for i in 2:
		if shop_used[i] == -1:
			var c: int = maxi(0, D.SHOP_COST[i] - disc)
			if can_pay(p, "me", c) and _spare_zod() >= 0:
				shop.append({"i": i, "cost": c})
	if not shop.is_empty():
		out["shop"] = shop
	var free := port_free_zods(p)
	if not free.is_empty():
		var lag := []
		for spot in D.LAGOON:
			if lagoon_free(spot):
				lag.append(spot)
		if not lag.is_empty():
			out["lagoon"] = lag
		out["sea"] = true
		var ids := []
		for z in free:
			ids.append(z["id"])
		out["zods"] = ids
	return out


func _spare_zod() -> int:
	for z in zods:
		if z["owner"] == -1:
			return z["id"]
	return -1


## Requisito di un posto della laguna con la dotazione data.
func lagoon_gain(spot: String, items: Dictionary, exp: bool) -> int:
	var bonus := 2 if exp else 0
	match spot:
		"aragoste":
			return 8 + bonus if items.get("nassa", 0) > 0 else -1
		"pesce":
			if items.get("fucile", 0) > 0 or items.get("fucile_plus", 0) > 0:
				return 6 + bonus
			return 5 + bonus if items.get("arpione", 0) > 0 else -1
		"turisti":
			return 4 + bonus
		"isola1", "isola2":
			return 0 if items.get("metal", 0) > 0 and island.count(-1) < 9 else -1
	return -1


func _act7(p: int, m: Dictionary) -> String:
	var opts := z7_options(p, m)
	if opts.is_empty():
		return ""
	var r = await decide(p, {"type": "z7", "options": opts, "m": m["id"]})
	if not (r is Dictionary):
		return ""
	var a := str(r.get("a", "none"))
	match a:
		"shop":
			if not opts.has("shop"):
				return ""
			var pick: Dictionary = opts["shop"][0]
			for s in opts["shop"]:
				if s["i"] == int(r.get("i", pick["i"])):
					pick = s
			var sz := _spare_zod()
			pay(p, "me", pick["cost"])
			shop_used[pick["i"]] = p
			var z := zod(sz)
			z["owner"] = p
			z["loc"] = "port"
			ps[p]["zods"].append(sz)
			m["loc"] = "shop"
			add_rep(p, 1, "nuovo gommone")
			log_msg("%s compra un gommone %s (%d$)." % [pname(p), z["color"], pick["cost"]])
			fx.emit("buyzod", {"p": p, "zod": sz})
			return "shop"
		"lagoon":
			if not opts.has("lagoon"):
				return ""
			var spot := str(r.get("spot", ""))
			var zid := int(r.get("zod", -1))
			if not (spot in opts["lagoon"]) or not (zid in opts["zods"]):
				return ""
			var z := zod(zid)
			if r.get("items") is Dictionary:
				set_loadout(p, z, r["items"])
			var g := lagoon_gain(spot, z["items"], expert(m, 7))
			if g < 0:
				return ""
			lagoon_used[spot] = zid
			z["loc"] = "lag:" + spot
			z["crew"] = m["id"]
			m["loc"] = "lagoon"
			fx.emit("move", {"zod": zid, "path": ["PORT", "lag:" + spot]})
			if spot.begins_with("isola"):
				await _island(p, m)
			else:
				earn(p, g, D.LAGOON[spot]["name"])
				ps[p]["fish"] += g
			return "lagoon"
		"sea":
			if not opts.has("sea"):
				return ""
			var zid := int(r.get("zod", -1))
			if not (zid in opts["zods"]):
				return ""
			var z := zod(zid)
			if r.get("items") is Dictionary:
				set_loadout(p, z, r["items"])
			z["crew"] = m["id"]
			z["loc"] = "PORT"
			m["loc"] = "sea"
			log_msg("%s prende il largo con il gommone %s." % [pname(p), z["color"]])
			await _sea_turn(p, z)
			if z["loc"] == "PORT":
				_dock(p, z)
			return "sea"
	return ""


func _island(p: int, m: Dictionary) -> void:
	var left := []
	for i in 9:
		if island[i] >= 0:
			left.append(i)
	if left.is_empty():
		return
	var pick: int = left[rng.randi_range(0, left.size() - 1)]
	if expert(m, 7) and left.size() >= 2:
		var other: int = pick
		while other == pick:
			other = left[rng.randi_range(0, left.size() - 1)]
		var r = await decide(p, {"type": "island", "tiles": [pick, other], "objs": [island[pick], island[other]]})
		var ch := int(r.get("i", pick)) if r is Dictionary else pick
		if ch == other:
			pick = other
	var o: Dictionary = D.ISLAND[island[pick]]
	island[pick] = -1
	if o.has("money"):
		earn(p, o["money"], o["name"])
	elif o.has("treasure"):
		ps[p]["treasures"].append(o["treasure"])
		log_msg("%s trova sull'isola: %s." % [pname(p), o["name"]])
	else:
		_gain_item(p, o["item"])
		log_msg("%s trova sull'isola: %s." % [pname(p), o["name"]])
	fx.emit("island", {"p": p, "k": o["k"]})


# ---------------------------------------------------------------- zona 8

func room_active(i: int) -> bool:
	var mp: int = rooms[i]["cfg"]["minp"]
	if solo:
		return i < 3
	return mp == 0 or n >= mp


func room_free_slot(i: int) -> int:
	var sl: Array = rooms[i]["slots"]
	for k in sl.size():
		if sl[k] == null:
			return k
	return -1


func z8_options(p: int, m: Dictionary) -> Dictionary:
	var disc := 2 if expert(m, 8) else 0
	var sp := {}
	for i in rooms.size():
		if room_active(i) and rooms[i]["sponsor"] == -1:
			var c: int = maxi(0, rooms[i]["cfg"]["cost"] - disc)
			if can_pay(p, "gp", c):
				sp[i] = c
	var sell := []
	if not ps[p]["treasures"].is_empty():
		sell.append(-1)
		for i in rooms.size():
			if room_active(i) and rooms[i]["sponsor"] != -1 and room_free_slot(i) >= 0:
				sell.append(i)
	return {"sponsor": sp, "sell": sell, "bonus": disc}


func _act8(p: int, m: Dictionary) -> bool:
	var o := z8_options(p, m)
	if o["sponsor"].is_empty() and o["sell"].is_empty():
		return false
	var r = await decide(p, {"type": "z8", "options": o, "m": m["id"]})
	if not (r is Dictionary):
		return false
	var a := str(r.get("a", "none"))
	if a == "sponsor":
		var i := int(r.get("room", -1))
		if not o["sponsor"].has(i):
			return false
		pay(p, "gp", o["sponsor"][i])
		rooms[i]["sponsor"] = p
		log_msg("%s finanzia una sala del museo (%d$)." % [pname(p), o["sponsor"][i]])
		fx.emit("sponsor", {"p": p, "room": i})
		return true
	if a == "sell":
		var v := int(r.get("v", 0))
		var i := int(r.get("room", -1))
		if not (v in ps[p]["treasures"]) or not (i in o["sell"]):
			return false
		ps[p]["treasures"].erase(v)
		earn(p, v + (2 if expert(m, 8) else 0))
		if i == -1:
			storage.append({"p": p, "v": v})
			log_msg("%s vende al museo un tesoro di %s (%d$), che finisce in deposito." % [pname(p), D.TREASURE_NAMES[v], v + o["bonus"]])
		else:
			var k := room_free_slot(i)
			rooms[i]["slots"][k] = {"p": p, "v": v}
			log_msg("%s vende al museo un tesoro di %s (%d$) e lo espone in una sala." % [pname(p), D.TREASURE_NAMES[v], v + o["bonus"]])
			if room_free_slot(i) < 0:
				rooms[i]["open"] = true
				var sp: int = rooms[i]["sponsor"]
				add_rep(sp, rooms[i]["cfg"]["rp"], "sala aperta al pubblico")
				fx.emit("open", {"room": i})
		fx.emit("sell", {"p": p, "v": v, "room": i})
		return true
	return false


func _museum_full() -> bool:
	for i in rooms.size():
		if room_active(i) and not rooms[i]["open"]:
			return false
	return true


# ---------------------------------------------------------------- zona 10

func _zone10() -> void:
	if envelopes.is_empty() or solo:
		return
	log_msg("--- Autorità locali: buste sotto il tavolo ---")
	var bids := {}
	for p in envelopes:
		var mx: int = ps[p]["acc"]["bc"]
		if mx < 2:
			add_rep(p, -1, "busta senza almeno 2$ in cassa nera")
			continue
		var r = await decide(p, {"type": "bid", "max": mx, "envelopes": envelopes.duplicate()})
		var b := int(r.get("bid", 2)) if r is Dictionary else 2
		if b < 2:
			add_rep(p, -1, "busta ritirata")
			continue
		b = mini(b, mx)
		bids[p] = b
	if bids.is_empty():
		return
	for p in bids:
		ps[p]["acc"]["bc"] -= bids[p]
	var bidders: Array = bids.keys()
	bidders.sort_custom(func(a, b):
		if bids[a] != bids[b]:
			return bids[a] > bids[b]
		return envelopes.find(a) < envelopes.find(b))
	var rest := []
	for p in order:
		if not bids.has(p):
			rest.append(p)
	order = bidders + rest
	var parts := []
	for p in bidders:
		parts.append("%s %d$" % [pname(p), bids[p]])
	log_msg("Offerte: %s. Nuovo ordine di turno: %s." % [", ".join(parts), ", ".join(order.map(func(x): return pname(x)))])
	fx.emit("auction", {"bids": bids})


# ================================================================ variante «Senza fede né legge»

## Zone con la casella del mercenario ancora libera (e non già usata in partita).
func merc_zones() -> Array:
	var out := []
	if not variant:
		return out
	for z in MERC_ZONES:
		if merc_used.has(z) or merc_q.has(z):
			continue
		if L["queues"].has(z) or z == 9:
			out.append(z)
	return out


func mercs_of(p: int) -> int:
	var c := 0
	for m in ps[p]["meeples"]:
		if m.get("merc", false) and m["loc"] in ["room", "idle"]:
			c += 1
	return c


## Asta a voce per un mercenario, in ordine di turno, con la cassa nera.
func _merc_auction() -> void:
	if mercs_left <= 0:
		return
	phase = "merc"
	zone_now = 0
	log_msg("--- Asta per un mercenario (ne restano %d) ---" % mercs_left)
	var high := 0
	var by := -1
	var out := {}
	var guard := 0
	while guard < 200:
		guard += 1
		var active := 0
		for p in order:
			if not out.has(p):
				active += 1
		if active == 0 or (active == 1 and by >= 0):
			break
		var moved := false
		for p in order:
			if out.has(p) or p == by:
				continue
			var bc: int = ps[p]["acc"]["bc"]
			if bc <= high:
				out[p] = true
				continue
			var r = await decide(p, {"type": "merc_bid", "high": high, "by": by, "max": bc, "zones": merc_zones()})
			if abort:
				return
			var b := int(r.get("bid", 0)) if r is Dictionary else 0
			if b > high and b <= bc:
				high = b
				by = p
				moved = true
				log_msg("   %s offre %d$." % [pname(p), b])
			else:
				out[p] = true
				log_msg("   %s passa." % pname(p))
			changed.emit()
			var still := 0
			for q in order:
				if not out.has(q):
					still += 1
			if still <= 1 and by >= 0:
				break
		if not moved:
			break
	if by < 0:
		log_msg("Nessuno compra il mercenario.")
		phase = "maint"
		return
	ps[by]["acc"]["bc"] -= high
	mercs_left -= 1
	var mid: int = by * 10 + 6 + ps[by]["merc_n"]
	ps[by]["merc_n"] += 1
	ps[by]["meeples"].append({"id": mid, "boss": false, "hat": 0, "loc": "room", "merc": true})
	log_msg("%s ingaggia un mercenario per %d$." % [pname(by), high])
	fx.emit("merc", {"p": by})
	phase = "maint"
	changed.emit()


func _merc_act(z: int) -> void:
	var e: Dictionary = merc_q[z]
	var p: int = e["p"]
	var m := meeple(p, e["m"])
	m["loc"] = "gone"
	merc_used[z] = p
	merc_q.erase(z)
	match z:
		1:
			var got := 0
			for q in n:
				if q != p:
					got += ps[q]["dbl"]
					ps[q]["dbl"] = 0
				if ps[q]["hired"] < 2 and not ps[q].get("dbl_stolen", false):
					ps[q]["dbl_stolen"] = true
					got += 1
			ps[p]["dbl"] += got
			log_msg("Il mercenario di %s ruba %d segnalini doppia azione." % [pname(p), got])
		2:
			var opts := visible_techs()
			if opts.is_empty():
				return
			var r = await decide(p, {"type": "merc2", "techs": opts})
			var t: String = str(r.get("t", opts[0])) if r is Dictionary else str(opts[0])
			if not (t in opts):
				t = opts[0]
			var own: int = tech_owner[t]
			if own == -1:
				tech_owner[t] = p
				tech_sold[t] = 1
				_gain_item(p, t)
			else:
				tech_owner[t] = p
				if tech_left(t) > 0:
					tech_sold[t] += 1
					_gain_item(p, t)
			log_msg("Il mercenario di %s ruba il brevetto: %s%s." % [pname(p), D.ITEMS[t]["name"], (" a " + pname(own)) if own >= 0 and own < n else ""])
		3:
			if merc_pool.is_empty():
				return
			var r = await decide(p, {"type": "merc3", "pool": merc_pool.duplicate()})
			var nums := []
			if r is Dictionary:
				for x in r.get("nums", []):
					if int(x) in merc_pool and not (int(x) in nums):
						nums.append(int(x))
			for x in merc_pool:
				if nums.size() >= 2:
					break
				if not (x in nums):
					nums.append(x)
			for x in nums.slice(0, 2):
				merc_pool.erase(x)
				ps[p]["merc_cards"].append(x)
				log_msg("Il mercenario di %s ruba la carta tesoro %d." % [pname(p), x])
				await _gain_card(p, x, false)
		4:
			planes = ["off", "off"]
			black_plane = p
			log_msg("Il mercenario di %s sabota gli idrovolanti grigi e ruba l'idrovolante nero." % pname(p))
		7:
			mine_owner = p
			log_msg("Il mercenario di %s recupera una mina subacquea." % pname(p))
		8:
			await _merc8(p)
		9:
			for q in n:
				if q != p:
					add_rep(q, -4, "campagna diffamatoria")
			log_msg("Il mercenario di %s scatena una campagna diffamatoria contro gli avversari." % pname(p))
	fx.emit("mercact", {"p": p, "z": z})
	changed.emit()
	await _pace(0.4)


## Posizioni dei tesori del museo: "r<sala>_<posto>" e "s<indice>" per il deposito.
func museum_spots() -> Dictionary:
	var out := {}
	for i in rooms.size():
		for k in rooms[i]["slots"].size():
			if rooms[i]["slots"][k] != null:
				out["r%d_%d" % [i, k]] = rooms[i]["slots"][k]
	for j in storage.size():
		out["s%d" % j] = storage[j]
	return out


func museum_free() -> Array:
	var out := []
	for i in rooms.size():
		if room_active(i) and rooms[i]["sponsor"] != -1:
			for k in rooms[i]["slots"].size():
				if rooms[i]["slots"][k] == null:
					out.append("r%d_%d" % [i, k])
	return out


func _spot_get(id: String):
	if id.begins_with("s"):
		return storage[int(id.substr(1))]
	var a := id.substr(1).split("_")
	return rooms[int(a[0])]["slots"][int(a[1])]


func _spot_set(id: String, v) -> void:
	if id.begins_with("s"):
		storage[int(id.substr(1))] = v
		return
	var a := id.substr(1).split("_")
	rooms[int(a[0])]["slots"][int(a[1])] = v


## Ricontrolla le sale: una sala piena apre, una sala aperta rimasta con un buco chiude.
func _museum_recheck() -> void:
	for i in rooms.size():
		var full := room_free_slot(i) < 0
		var sp: int = rooms[i]["sponsor"]
		if rooms[i]["open"] and not full:
			rooms[i]["open"] = false
			if sp >= 0:
				add_rep(sp, -rooms[i]["cfg"]["rp"], "sala richiusa al pubblico")
		elif not rooms[i]["open"] and full and sp >= 0:
			rooms[i]["open"] = true
			add_rep(sp, rooms[i]["cfg"]["rp"], "sala aperta al pubblico")


## Applica una mossa del mercenario del museo: {"a": "swap", "x", "y"} oppure {"a": "move", "x", "to"}.
func apply_merc8(r: Dictionary) -> bool:
	var spots := museum_spots()
	var x := str(r.get("x", ""))
	if not spots.has(x):
		return false
	if r.get("a", "") == "swap":
		var y := str(r.get("y", ""))
		if not spots.has(y) or x == y:
			return false
		var a = _spot_get(x)
		_spot_set(x, _spot_get(y))
		_spot_set(y, a)
	elif r.get("a", "") == "move":
		var to := str(r.get("to", ""))
		if not (to in museum_free()):
			return false
		_spot_set(to, _spot_get(x))
		_spot_set(x, null)
		storage = storage.filter(func(v): return v != null)
	else:
		return false
	_museum_recheck()
	return true


func _merc8(p: int) -> void:
	if museum_spots().is_empty():
		return
	var r = await decide(p, {"type": "merc8", "spots": museum_spots().keys(), "free": museum_free()})
	if r is Dictionary and apply_merc8(r):
		log_msg("Il mercenario di %s rimescola i tesori del museo." % pname(p))


## Mina subacquea: copre 3x3 caselle sotto la superficie di un sito.
func mine_options() -> Dictionary:
	var out := {}
	for k in sites:
		if sites[k]["tile"] >= 0:
			out[k] = range(_site_cols(k).size() - 2)
	return out


func _use_mine(p: int) -> void:
	var opts := mine_options()
	if opts.is_empty():
		return
	var r = await decide(p, {"type": "mine", "options": opts})
	if not (r is Dictionary) or r.get("none", false):
		return
	var k := int(r.get("site", -1))
	var c0 := int(r.get("col", -1))
	if not opts.has(k) or not (c0 in opts[k]):
		return
	mine_owner = -1
	var s: Dictionary = sites[k]
	var sharks := 0
	var lost := 0
	for row in 3:
		for c in range(c0, c0 + 3):
			var v: String = s["grid"][row][c]
			if v == "S":
				s["grid"][row][c] = "K"
				sharks += 1
			elif v.begins_with("T") or v.begins_with("N") or v.begins_with("I"):
				s["grid"][row][c] = "X"
				lost += 1
	ps[p]["sharks"] += sharks
	s["up"] = true
	log_msg("%s fa esplodere la mina nel sito %d: %d squali uccisi, %d tesori distrutti." % [pname(p), k, sharks, lost])
	fx.emit("mine", {"p": p, "site": k})
	changed.emit()


# ================================================================ stipendi, manutenzione, fine anno

func _phase_salary() -> void:
	phase = "salary"
	zone_now = 0
	for p in n:
		var w := workers(p)
		var k := w
		while k > 0 and not can_pay(p, "hr", 2 * k):
			k -= 1
		pay(p, "hr", 2 * k)
		var unpaid := w - k
		if w > 0:
			log_msg("%s paga %d$ di stipendi%s." % [pname(p), (w - unpaid) * 2, (", %d lavoratori senza paga" % unpaid) if unpaid > 0 else ""])
		if unpaid > 0:
			add_rep(p, -unpaid, "stipendi non pagati")
	changed.emit()


func _phase_maint() -> void:
	phase = "maint"
	# tecnologie
	var k: int = D.REVEAL.get(period, 0)
	for i in k:
		if deck.is_empty():
			break
		var t: String
		if i == 0 and not reserve.is_empty():
			var rp: int = reserve["p"]
			var r = await decide(rp, {"type": "reserve", "cards": deck.duplicate()})
			t = str(r.get("t", deck[0])) if r is Dictionary else deck[0]
			if not (t in deck):
				t = deck[0]
			deck.erase(t)
			log_msg("%s sceglie dal mazzo la tecnologia %s." % [pname(rp), D.ITEMS[t]["name"]])
		else:
			t = deck.pop_front()
		var slot := tech_slots.find("")
		if slot >= 0:
			tech_slots[slot] = t
			_solo_claim(slot)
		else:
			deck.push_front(t)
		log_msg("Nuova tecnologia disponibile: %s." % D.ITEMS[t]["name"])
	if not reserve.is_empty():
		reserved_next = reserve
		reserve = {}
	# mercatino
	for i in 2:
		if card_pool.is_empty():
			break
		_market_add(card_pool.pop_back())
	# idrovolanti, laguna e negozio
	planes = ["home", "home"]
	for z in zods:
		if z["loc"].begins_with("lag:"):
			if z["owner"] >= 0 and z["crew"] != -1:
				_return_meeple(z["owner"], z["crew"])
			z["crew"] = -1
			z["loc"] = "port"
	for p in n:
		for m in meeples_at(p, "shop") + meeples_at(p, "lagoon"):
			m["loc"] = "room"
	lagoon_used.clear()
	shop_used = [-1, -1]
	changed.emit()
	await _pace(0.3)


func order_rp() -> Array:
	return L["order_rp"].get(n, [0, 0, 0, 0])


func _year_end() -> void:
	var rp := order_rp()
	for i in order.size():
		if i < rp.size() and rp[i] > 0:
			add_rep(order[i], rp[i], "influenza sulle autorità a fine anno")


# ================================================================ punteggio finale

func final_score(p: int) -> Dictionary:
	var s := {"rep": ps[p]["rep"], "tesori": 0, "brevetti": 0, "squali": 0, "carte": 0, "denaro": 0, "influenza": 0}
	for room in rooms:
		for i in room["slots"].size():
			var e = room["slots"][i]
			if e != null and e["p"] == p:
				s["tesori"] += room["cfg"]["vp"][i] if room["open"] else 2
	for e in storage:
		if e["p"] == p:
			s["tesori"] += 1
	s["tesori"] += 2 * ps[p]["treasures"].size()
	for t in tech_owner:
		if tech_owner[t] == p:
			s["brevetti"] += D.TECHS[t]["vp"]
	s["squali"] = 2 * ps[p]["sharks"]
	var cnt := {}
	for k in ps[p]["cards"]:
		cnt[k] = cnt.get(k, 0) + 1
	s["carte"] = ps[p]["cards"].size()
	for k in cnt:
		if cnt[k] >= 3:
			s["carte"] += 2
	s["denaro"] = int(money(p) / 10)
	if not solo:
		var rp := order_rp()
		var i := order.find(p)
		s["influenza"] = rp[i] if i >= 0 and i < rp.size() else 0
	var tot := 0
	for k in s:
		tot += s[k]
	s["totale"] = tot
	return s


func _end_game() -> void:
	phase = "over"
	over = true
	var scores := []
	var best := -1
	for p in n:
		var s := final_score(p)
		scores.append(s)
		ps[p]["rep"] = s["totale"]
	var ranking := range(n)
	ranking.sort_custom(func(a, b):
		if scores[a]["totale"] != scores[b]["totale"]:
			return scores[a]["totale"] > scores[b]["totale"]
		return order.find(a) < order.find(b))
	best = ranking[0]
	result = {"scores": scores, "ranking": ranking, "winner": best, "period": period}
	if solo:
		var goal: bool = _museum_full() and scores[0]["totale"] > 80
		var bonus := 0
		if goal:
			bonus = 30 if period <= 6 else (20 if period == 7 else (10 if period == 8 else 0))
		result["solo_win"] = goal
		result["solo_bonus"] = bonus
		result["solo_total"] = scores[0]["totale"] + bonus
		log_msg("Fine della partita: %d punti reputazione%s." % [scores[0]["totale"],
			(" — obiettivo raggiunto, bonus %d (totale %d)" % [bonus, scores[0]["totale"] + bonus]) if goal else " — obiettivo non raggiunto (serve aprire tutte le sale e superare 80)"])
	else:
		log_msg("Fine della partita! Vince %s con %d punti reputazione." % [pname(best), scores[best]["totale"]])
	_snap()
	changed.emit()
	game_ended.emit(result)


## Impronta dello stato (per controllare che due dispositivi giochino la stessa partita).
func fingerprint() -> String:
	var parts := []
	for p in n:
		parts.append("%d:%d:%d" % [p, money(p), ps[p]["rep"]])
	return "%d|%d|%s" % [period, zone_now, ";".join(parts)]
