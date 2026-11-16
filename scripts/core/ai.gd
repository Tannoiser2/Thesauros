class_name THAI
extends RefCounted
## Intelligenza artificiale di Thesauros.
## Valuta ogni scelta con un punteggio fatto di pesi (W): carte tesoro per i siti, attrezzature,
## gommoni in mare, museo, pubblicità, laguna e cozze per riempire i buchi. I pesi della IA normale e
## difficile sono stati tarati con migliaia di partite simulate (tests/tara_ia.gd); la facile usa i pesi
## di partenza e sbaglia di più. La difficile in più guarda avanti di una mossa nelle scelte del museo e
## dei mercenari, calcolando il punteggio finale che ne risulterebbe.
## Gli stessi ragionamenti alimentano il «consiglio del tutor» del tutorial.

const D = preload("res://scripts/data/th_data.gd")

## Pesi di partenza (IA facile).
const BASE := {
	"rec": 5.0, "rec_t": 0.4, "rec_money": 20.0,
	"t_vp": 1.2, "t_want": 1.0, "t_dev_want": 0.3, "t_cost": 0.35,
	"c1": 7.5, "c2": 5.5, "c3": 3.5, "c4": 2.0, "c_cost": 0.35,
	"sea": 3.5, "sea_v": 0.7, "sea_try": 2.0, "lag": 0.67, "zod_buy": 3.2,
	"m_sell": 5.0, "m_sell_v": 0.4, "m_spon": 3.0, "m_spon_c": 0.15,
	"adv": 1.1, "adv_c": 0.3, "mus": 1.2, "plane": 4.0, "boss_pen": 0.6,
	"rd0": 0.5, "rd1": 0.35, "rd2": 0.12, "bc0": 5.0, "bc1": 6.0, "bc2": 4.0, "me0": 6.0, "me1": 9.0, "me2": 8.0,
	"hr_extra": 4.0, "store_end": 0.5, "merc_rep": 2.2,
}

## Pesi tarati con le partite simulate (IA normale e difficile).
const TUNED := {
	"rec": 6.75, "rec_t": 0.4, "rec_money": 20.0, "t_vp": 0.84, "t_want": 0.7, "t_dev_want": 0.3, "t_cost": 0.472,
	"c1": 13.669, "c2": 5.5, "c3": 3.5, "c4": 2.0, "c_cost": 0.245, "sea": 3.5, "sea_v": 0.7, "sea_try": 2.0,
	"lag": 0.67, "zod_buy": 3.2, "m_sell": 5.0, "m_sell_v": 0.4, "m_spon": 3.0, "m_spon_c": 0.15, "adv": 1.1,
	"adv_c": 0.3, "mus": 0.84, "plane": 4.0, "boss_pen": 0.6, "rd0": 0.5, "rd1": 0.35, "rd2": 0.12, "bc0": 5.0,
	"bc1": 6.0, "bc2": 4.0, "me0": 6.0, "me1": 9.0, "me2": 8.0, "hr_extra": 4.0, "store_end": 0.5, "merc_rep": 2.2,
}

var level := 1
var rng := RandomNumberGenerator.new()
var W: Dictionary


func _init(lv := 1, seed_v := 0, weights := {}) -> void:
	level = lv
	W = (BASE if lv == 0 else TUNED).duplicate()
	if lv == 1:
		# la normale sta a metà fra i pesi di partenza e quelli tarati
		for k in W:
			W[k] = (float(BASE[k]) + float(TUNED[k])) * 0.5
	for k in weights:
		W[k] = weights[k]
	if seed_v != 0:
		rng.seed = seed_v
	else:
		rng.randomize()


func _noise() -> float:
	return rng.randf_range(-1.5, 1.5) * (1.0 if level == 0 else (0.5 if level == 1 else 0.06))


func decide(e, p: int, req: Dictionary):
	match req["type"]:
		"budget": return default_budget(e, p, req["money"])
		"place": return _place(e, p, req)
		"recruit": return _recruit(e, p, req)
		"z2": return _z2(e, p, req)
		"sat": return _sat(e, p, req)
		"dig": return _dig(e, p, req)
		"z3": return _z3(e, p, req)
		"plane": return _plane(e, p, req)
		"sea": return _sea(e, p, req)
		"dive": return _dive(e, p, req)
		"z7": return _z7(e, p, req)
		"island": return _island(e, p, req)
		"z8": return _z8(e, p, req)
		"bid": return _bid(e, p, req)
		"reserve": return _reserve(e, p, req)
		"merc_bid": return _merc_bid(e, p, req)
		"merc2": return _merc2(e, p, req)
		"merc3": return _sat(e, p, {"pool": req["pool"]})
		"merc8": return _merc8(e, p, req)
		"mine": return _mine(e, p, req)
	return {}


# ================================================================ budget

func default_budget(e, p: int, tot: int) -> Dictionary:
	var y: int = e.year
	var w: int = e.workers(p)
	var hr: int = 2 * w * 3
	if e.reserve_left(p) > 0 and y < 3 and w < 4:
		hr += int(W["hr_extra"])
	var bc := 0
	if not e.solo:
		bc = int(W["bc%d" % (y - 1)])
		if e.variant:
			bc += [4, 8, 6][y - 1] if level > 0 else 2
	var me: int = int(W["me%d" % (y - 1)]) + 2 * e.zods_of(p).size()
	var rest: int = tot - hr - bc - me
	if rest < 0:
		# poco denaro: prima gli stipendi
		var b := {"hr": mini(tot, hr), "rd": 0, "gp": 0, "me": 0, "bc": 0, "inc": "gp"}
		var left: int = tot - b["hr"]
		b["me"] = mini(left, me)
		left -= b["me"]
		b["gp"] = left
		return b
	var rd := int(rest * float(W["rd%d" % (y - 1)]))
	var gp: int = rest - rd
	return {"hr": hr, "rd": rd, "gp": gp, "me": me, "bc": bc, "inc": "gp"}


# ================================================================ valutazioni

func gear(e, p: int) -> Dictionary:
	var g: Dictionary = e.ps[p]["stock"].duplicate()
	for z in e.zods_of(p):
		for k in z["items"]:
			g[k] = g.get(k, 0) + z["items"][k]
	return g


func want(e, p: int, t: String) -> float:
	var g := gear(e, p)
	var nz: int = e.zods_of(p).size()
	var have: int = g.get(t, 0)
	if have >= nz:
		return 0.0
	var depth := 1
	for k in ["maschera", "bombola", "scafandro"]:
		if g.get(k, 0) > 0:
			depth = maxi(depth, D.ITEMS[k]["depth"])
	var shark: bool = g.get("arpione", 0) + g.get("fucile", 0) + g.get("fucile_plus", 0) + g.get("gabbia", 0) > 0
	var detect: bool = g.get("sonar", 0) + g.get("sonar_av", 0) + g.get("satellite", 0) + g.get("sonar_plus", 0) > 0
	var late: float = 1.0 if e.period <= 6 else 0.4
	match t:
		"maschera": return 9.0 if depth < 2 else 1.0
		"bombola": return (6.0 if depth == 2 else (2.0 if depth < 2 else 0.5)) * late
		"scafandro": return (4.0 if depth == 3 else 1.0) * late
		"arpione": return 6.5 if not shark else 1.0
		"fucile": return 4.0 * late if g.get("fucile", 0) == 0 else 0.5
		"gabbia": return 4.5 * late if g.get("gabbia", 0) == 0 else 0.5
		"sonar": return 4.0 * late if not detect else 0.5
		"sonar_av": return 3.0 * late if g.get("sonar_av", 0) == 0 else 0.5
		"satellite": return 3.0 * late
		"trapano": return 3.5 * late if g.get("trapano", 0) + g.get("martello", 0) == 0 else 0.5
		"martello": return 2.5 * late
		"mot_piccolo": return 2.5 * late
		"mot_medio": return 3.5 * late
		"mot_super": return 4.0 * late
		"nassa": return 4.0 * late
	return 1.0


## Valore dei tesori raggiungibili dal gommone se fosse nel nodo indicato.
func dive_value(e, p: int, z: Dictionary, node: String) -> float:
	var old: String = z["loc"]
	z["loc"] = node
	var t: Array = e._dive_targets(p, z)
	z["loc"] = old
	if t.is_empty():
		return 0.0
	var vals := []
	for x in t:
		vals.append(float(x["v"]) - x["cost"] * 0.8)
	vals.sort()
	vals.reverse()
	var crew: Dictionary = e.meeple(p, z["crew"])
	var take := 2 if e.expert(crew, 5) else 1
	var s := 0.0
	for i in mini(take, vals.size()):
		s += vals[i]
	return s


## Il miglior valore d'immersione raggiungibile da un nodo con la dotazione data.
func best_reachable(e, p: int, z: Dictionary, from: String) -> Array:
	var old: String = z["loc"]
	z["loc"] = from
	var dests: Dictionary = e.destinations(p, z)
	var best := 0.0
	var where := ""
	for d in dests:
		if not d.begins_with("D"):
			continue
		var v: float = dive_value(e, p, z, d) - dests[d]
		if v > best:
			best = v
			where = d
	z["loc"] = old
	return [best, where]


## Il miglior sito raggiungibile anche in più quadrimestri: [valore, nodo, distanza].
func potential(e, p: int, z: Dictionary, from: String) -> Array:
	var dist: Dictionary = e.distances(p, from)
	var mx: int = maxi(1, e.move_max(z))
	var best := 0.0
	var where := ""
	var wd := 0
	for d in dist:
		if not d.begins_with("D") or (d != from and e.occupied(d, z["id"])):
			continue
		var dv := dive_value(e, p, z, d)
		if dv <= 0.0:
			continue
		var turns := maxi(1, ceili(float(dist[d]) / mx))
		var v := dv / turns - (turns - 1) * 0.8
		if v > best:
			best = v
			where = d
			wd = dist[d]
	return [best, where, wd]


func full_load(e, p: int, z: Dictionary) -> Dictionary:
	var tot: Dictionary = z["items"].duplicate()
	for k in e.ps[p]["stock"]:
		tot[k] = tot.get(k, 0) + e.ps[p]["stock"][k]
	# al massimo due motori aggiuntivi: i migliori
	var eng := []
	for k in ["mot_isola", "mot_super", "mot_medio", "mot_piccolo"]:
		for c in tot.get(k, 0):
			eng.append(k)
		tot.erase(k)
	for k in eng.slice(0, 2):
		tot[k] = tot.get(k, 0) + 1
	# una sola copia di ciascun oggetto per gommone, il resto resta in magazzino per gli altri
	var out := {}
	for k in tot:
		if D.ITEMS.has(k) and D.ITEMS[k].get("engine", false):
			out[k] = tot[k]
		else:
			out[k] = mini(1, tot[k]) if e.port_free_zods(p).size() > 1 else tot[k]
	return out


func lagoon_best(e, p: int, m: Dictionary, z: Dictionary) -> Array:
	var items := full_load(e, p, z)
	var best := -1.0
	var spot := ""
	for s in D.LAGOON:
		if not e.lagoon_free(s):
			continue
		var g: int = e.lagoon_gain(s, items, e.expert(m, 7))
		var v := float(g)
		if s.begins_with("isola"):
			v = 6.0 if g >= 0 else -1.0
		if v > best:
			best = v
			spot = s
	return [best, spot]


func zone_value(e, p: int, z: int, m: Dictionary, mine_in: Dictionary) -> float:
	var already: int = mine_in.get(z, 0)
	match z:
		1:
			if e.reserve_left(p) == 0 or e.period > 6 or e.workers(p) >= 4:
				return -5.0
			var slot: int = e.queue_free_slot(1)
			var c: int = e.queue_cost(1, slot) - (2 if m["boss"] else 0)
			if not e.can_pay(p, "hr", c + 6) or e.money(p) < W["rec_money"] + 6 * (3 - (e.period - 1) % 3):
				return -5.0
			return W["rec"] - e.period * W["rec_t"] - c * 0.3 + (1.0 if e.ps[p]["hired"] == 1 else 0.0) - already * 4.0
		2:
			var best := -5.0
			for t in e.visible_techs():
				var cs: Dictionary = e.tech_costs(p, m, t)
				for a in cs:
					if not e.can_pay(p, "rd", cs[a]):
						continue
					best = maxf(best, tech_value(e, p, t, a, cs[a]))
			return best - already * 2.0 + (0.8 if m["boss"] or m["hat"] == 2 else 0.0)
		3:
			var nc: int = e.ps[p]["cards"].size()
			var cheap := 99
			var slots: Dictionary = e.market_slots(p, m)
			for i in slots:
				cheap = mini(cheap, slots[i])
			if cheap == 99:
				return -5.0
			var base: float = W["c1"] if nc == 0 else (W["c2"] if nc == 1 else (W["c3"] if nc <= 3 else W["c4"]))
			if e.period >= 8:
				base -= 1.5
			return base - cheap * W["c_cost"] - already * 2.5 + (0.6 if m["boss"] or m["hat"] == 3 else 0.0)
		4:
			if e.zods_of(p, "sea").is_empty() or e.planes.count("home") == 0:
				return -5.0
			var useful := 0.0
			for k in e.ps[p]["stock"]:
				useful += want(e, p, k) * 0.5 + 1.0
			return minf(W["plane"], useful) - already * 3.0
		6:
			return W["mus"] + (2.0 if m["boss"] else 0.0) + (0.5 if e.z6_idx >= 1 else 0.0)
		7:
			var free: Array = e.port_free_zods(p)
			var v := -5.0
			if not free.is_empty() and already < free.size():
				var z0: Dictionary = free[0]
				var saved: Dictionary = z0["items"]
				z0["items"] = full_load(e, p, z0)
				var br := potential(e, p, z0, "PORT")
				z0["items"] = saved
				var sea_v := 0.0
				if br[0] > 0.0:
					sea_v = W["sea"] + br[0] * W["sea_v"]
				elif not e.ps[p]["cards"].is_empty() and e.period <= 7:
					sea_v = W["sea_try"]
				var lb := lagoon_best(e, p, m, z0)
				v = maxf(sea_v, lb[0] * W["lag"])
				if e.expert(m, 7):
					v += 1.0
			if e.zods_of(p).size() <= 1 and e.period <= 5 and e.can_pay(p, "me", 8) and not e.ps[p]["cards"].is_empty():
				v = maxf(v, W["zod_buy"])
			return v - (already * 1.0 if free.size() <= already else 0.0)
		8:
			var o: Dictionary = e.z8_options(p, m)
			var tr: Array = e.ps[p]["treasures"]
			if tr.size() > already:
				var mx := 0
				for x in tr:
					mx = maxi(mx, x)
				return W["m_sell"] + mx * W["m_sell_v"] + (1.0 if m["boss"] or m["hat"] == 8 else 0.0)
			if not o["sponsor"].is_empty() and e.period <= 7 and already == 0:
				var cheap := 99
				for i in o["sponsor"]:
					cheap = mini(cheap, o["sponsor"][i])
				return W["m_spon"] - cheap * W["m_spon_c"] + (0.8 if e.period >= 3 else 0.0)
			return -5.0
		9:
			var slot: int = e.queue_free_slot(9)
			if slot < 0:
				return -5.0
			var c: int = e.queue_cost(9, slot) - (2 if m["boss"] else 0)
			if not e.can_pay(p, "gp", c):
				return -5.0
			var gain: int = D.Z9_REP[e.z9_idx]
			return gain * W["adv"] - c * W["adv_c"] - already * 2.0
	return -5.0


func tech_value(e, p: int, t: String, a: String, c: int) -> float:
	var w := want(e, p, t)
	if a == "dev":
		return D.TECHS[t]["vp"] * W["t_vp"] + w * W["t_dev_want"] - c * W["t_cost"]
	return w * W["t_want"] + (D.TECHS[t]["vp"] * W["t_vp"] if a == "combo" else 0.0) - c * W["t_cost"]


## Valore (in punti) di usare un mercenario in una zona, adesso.
func merc_value(e, p: int, z: int) -> float:
	match z:
		1:
			var got := 0
			for q in e.n:
				if q != p:
					got += e.ps[q]["dbl"]
				if e.ps[q]["hired"] < 2 and not e.ps[q].get("dbl_stolen", false):
					got += 1
			return got * 1.5
		2:
			var best := 0.0
			for t in e.visible_techs():
				var v: float = D.TECHS[t]["vp"] + (want(e, p, t) * 0.4 if e.tech_left(t) > 0 or e.tech_owner[t] == -1 else 0.0)
				if e.tech_owner[t] >= 0 and e.tech_owner[t] < e.n and e.tech_owner[t] != p:
					v += D.TECHS[t]["vp"] * 0.5
				best = maxf(best, v)
			return best
		3:
			if e.merc_pool.is_empty():
				return 0.0
			return 2.0 + (4.0 if e.year < 3 else 1.0) + (2.0 if e.period <= 6 else 0.0)
		4:
			return 3.0 if not e.zods_of(p, "sea").is_empty() and e.period <= 7 else 1.0
		7:
			var best := 0.0
			var opts: Dictionary = e.mine_options()
			for k in opts:
				for c0 in opts[k]:
					best = maxf(best, _mine_score(e, p, k, c0))
			return best
		8:
			return 2.0
		9:
			return 4.0 * W["merc_rep"] * 0.5
	return 0.0


# ================================================================ piazzamento

func _place(e, p: int, req: Dictionary) -> Dictionary:
	var mine_in := {}
	for z in e.queues:
		for x in e.queues[z]:
			if x != null and x["p"] == p:
				mine_in[z] = mine_in.get(z, 0) + 1
	for x in e.z6:
		if x["p"] == p:
			mine_in[6] = mine_in.get(6, 0) + 1
	var best := -99.0
	var pick := {"m": req["meeples"][0], "z": 6}
	var mz: Array = req.get("merc_zones", [])
	for mid in req["meeples"]:
		var m: Dictionary = e.meeple(p, mid)
		if m.get("merc", false):
			for z in mz:
				var v := merc_value(e, p, z) + _noise()
				if v > best:
					best = v
					pick = {"m": mid, "z": z}
			continue
		for z in req["zones"]:
			var v := zone_value(e, p, z, m, mine_in) + _noise()
			# il capo e gli specialisti vanno dove contano
			if m["boss"] and not (z in [2, 3, 7, 8, 6]):
				v -= W["boss_pen"]
			if not m["boss"] and m["hat"] != 0 and e.expert(m, z):
				v += 0.7
			if v > best:
				best = v
				pick = {"m": mid, "z": z}
	var env := false
	if req["can_env"] and e.ps[p]["acc"]["bc"] >= 2:
		env = level > 0 or rng.randf() < 0.5
		var k: int = (e.period - 1) % 3
		var keep: int = 6 if e.variant and e.period in [3, 5, 7, 8] and level > 0 else 0
		if k < 2 and e.ps[p]["acc"]["bc"] < 4 + keep and level > 0:
			env = false
	var dbl: bool = req["can_dbl"] and pick["z"] in [2, 3, 8, 9] and best > 4.0 and not e.meeple(p, pick["m"]).get("merc", false)
	pick["env"] = env
	pick["dbl"] = dbl
	return pick


func _recruit(e, p: int, req: Dictionary) -> Dictionary:
	var m: Dictionary = e.meeple(p, req["m"])
	var best := -99.0
	var z0 := 6
	for z in req["zones"]:
		var v := zone_value(e, p, z, m, {})
		if v > best:
			best = v
			z0 = z
	return {"z": z0, "env": req["can_env"] and e.ps[p]["acc"]["bc"] >= 2 and (e.period - 1) % 3 == 2, "dbl": false}


# ================================================================ azioni

func _z2(e, p: int, req: Dictionary) -> Dictionary:
	var best := -99.0
	var pick := {"a": "none"}
	for t in req["options"]:
		for a in req["options"][t]:
			var v := tech_value(e, p, t, a, req["options"][t][a]) + _noise() * 0.5
			if v > best:
				best = v
				pick = {"a": a, "t": t}
	return pick


func _sat(e, p: int, req: Dictionary) -> Dictionary:
	var pool: Array = req["pool"]
	var cnt := {}
	for k in e.ps[p]["cards"]:
		cnt[k] = cnt.get(k, 0) + 1
	var sorted := pool.duplicate()
	sorted.sort_custom(func(a, b):
		var va: float = cnt.get(a, 0) * 2.0 + _site_score(e, a)
		var vb: float = cnt.get(b, 0) * 2.0 + _site_score(e, b)
		return va > vb)
	return {"nums": sorted.slice(0, 2)}


func _site_score(e, k: int) -> float:
	var s: Dictionary = e.sites.get(k, {})
	if s.is_empty():
		return 0.0
	if s["tile"] >= 0:
		return _tile_score(s["grid"]) * 0.1
	return 1.0 if s["large"] else 0.6


func _tile_score(grid: Array) -> float:
	var s := 0.0
	for r in grid.size():
		for c in grid[r].size():
			var x: String = grid[r][c]
			if x.begins_with("T"):
				s += int(x.substr(1)) * (1.0 if r < 2 else 0.6)
			elif x.begins_with("N") or x.begins_with("I"):
				s += int(x.substr(1)) * 0.4
			elif x == "S" and r == 0:
				s -= 2.0
	return s


func _dig(e, p: int, req: Dictionary) -> Dictionary:
	var src: Array = SitesData.get_tiles(req["large"])
	var best := -999.0
	var pick := 0
	for i in req["tiles"].size():
		var v := _tile_score(src[req["tiles"][i]])
		if v > best:
			best = v
			pick = i
	return {"i": pick}


func _z3(e, p: int, req: Dictionary) -> Dictionary:
	var best := -99.0
	var pick := -1
	var cnt := {}
	for k in e.ps[p]["cards"]:
		cnt[k] = cnt.get(k, 0) + 1
	for i in req["slots"]:
		var k: int = e.market[i][e.market[i].size() - 1]
		var v := -float(req["slots"][i]) * 0.6
		if cnt.get(k, 0) == 0:
			v += 3.0 if e.ps[p]["cards"].size() < 3 else 0.5
		elif cnt[k] == 2:
			v += 2.0
		if k <= 3:
			v += 0.8
		var s: Dictionary = e.sites.get(k, {})
		if not s.is_empty() and s["tile"] >= 0:
			v += _tile_score(s["grid"]) * 0.05
		v += _noise() * 0.3
		if v > best:
			best = v
			pick = i
	if pick < 0:
		return {"none": true}
	return {"slot": pick}


func _plane(e, p: int, req: Dictionary) -> Dictionary:
	var useful := 0.0
	for k in e.ps[p]["stock"]:
		useful += want(e, p, k)
	var best_id: int = req["zods"][0]
	var bv := -1.0
	for id in req["zods"]:
		var z: Dictionary = e.zod(id)
		var v: float = best_reachable(e, p, z, z["loc"])[0]
		if v > bv:
			bv = v
			best_id = id
	var z: Dictionary = e.zod(best_id)
	if not req["swap"] and useful < (0.5 if req.get("black", false) else 3.0):
		return {"none": true}
	var swap := false
	if req["swap"] and req.has("m"):
		var pilot: Dictionary = e.meeple(p, req["m"])
		var crew: Dictionary = e.meeple(p, z["crew"])
		swap = e.expert(pilot, 5) and not e.expert(crew, 5)
	return {"zod": best_id, "items": full_load(e, p, z), "swap": swap}


func _sea(e, p: int, req: Dictionary) -> Dictionary:
	var z: Dictionary = e.zod(req["zod"])
	var here: String = z["loc"]
	var here_v := dive_value(e, p, z, here) if req["can_dive_here"] else 0.0
	var best := -99.0
	var pick := {"dest": here, "dive_first": false}
	var any_target := false
	for d in req["dests"]:
		var c: int = req["dests"][d]
		var v := dive_value(e, p, z, d) - c
		if v > 0.0:
			any_target = true
		var v2 := here_v + (0.0 if d == here else 0.1) - c * 0.5
		if d.begins_with("F"):
			v = maxf(v, 2.0 - c)
		if d == "PORT":
			v = 0.5 - c
		if v > best:
			best = v
			pick = {"dest": d, "dive_first": false}
		if here_v > 0.0 and d != here and v2 + 0.5 * dive_value(e, p, z, d) > best:
			best = v2 + 0.5 * dive_value(e, p, z, d)
			pick = {"dest": d, "dive_first": true}
	if not any_target and here_v <= 0.0:
		# niente da recuperare subito: verso il sito più promettente, altrimenti a pesca o in porto
		var pt := potential(e, p, z, here)
		if pt[0] > 0.0 and pt[1] != "":
			var goal: String = pt[1]
			var bd := 999
			var bc := 99
			for d in req["dests"]:
				var dd: Dictionary = e.distances(p, d)
				if not dd.has(goal):
					continue
				var c: int = req["dests"][d]
				if dd[goal] < bd or (dd[goal] == bd and c < bc):
					bd = dd[goal]
					bc = c
					pick = {"dest": d, "dive_first": false}
			return pick
		if req["dests"].has("PORT") and e.period < 9 and (e.zods_of(p, "sea").size() > 1 or e.ps[p]["cards"].is_empty()):
			return {"dest": "PORT", "dive_first": false}
		for d in req["dests"]:
			if d.begins_with("F") and req["dests"][d] == 0:
				return {"dest": d, "dive_first": false}
	return pick


func _dive(e, p: int, req: Dictionary) -> Dictionary:
	var ts: Array = req["targets"].duplicate()
	ts.sort_custom(func(a, b): return a["v"] - a["cost"] > b["v"] - b["cost"])
	var out := []
	var spent := 0
	for t in ts:
		if out.size() >= req["take"]:
			break
		if t["v"] - t["cost"] <= 1:
			continue
		if not e.can_pay(p, "me", spent + t["cost"]):
			continue
		spent += t["cost"]
		out.append(t["r"])
	return {"take": out}


func _z7(e, p: int, req: Dictionary) -> Dictionary:
	var o: Dictionary = req["options"]
	var m: Dictionary = e.meeple(p, req["m"])
	var best := -99.0
	var pick := {"a": "none"}
	if o.has("zods"):
		var zid: int = o["zods"][0]
		var z: Dictionary = e.zod(zid)
		var load := full_load(e, p, z)
		var saved: Dictionary = z["items"]
		z["items"] = load
		var br := potential(e, p, z, "PORT")
		z["items"] = saved
		if br[0] > 0.0:
			best = 4.0 + br[0]
			pick = {"a": "sea", "zod": zid, "items": load}
		elif not e.ps[p]["cards"].is_empty() and e.period <= 7:
			best = 2.5
			pick = {"a": "sea", "zod": zid, "items": load}
		if o.has("lagoon"):
			for s in o["lagoon"]:
				var g: int = e.lagoon_gain(s, load, e.expert(m, 7))
				var v := float(g)
				if s.begins_with("isola"):
					v = 6.0 if g >= 0 else -1.0
				if v > best:
					best = v
					pick = {"a": "lagoon", "spot": s, "zod": zid, "items": load}
	if o.has("shop"):
		var c: int = o["shop"][0]["cost"]
		var v := 5.0 - c * 0.3 if e.zods_of(p).size() <= 1 else 1.0
		if v > best:
			best = v
			pick = {"a": "shop", "i": o["shop"][0]["i"]}
	return pick


func _island(e, p: int, req: Dictionary) -> Dictionary:
	var best := -1.0
	var pick: int = req["tiles"][0]
	for i in req["tiles"].size():
		var o: Dictionary = D.ISLAND[req["objs"][i]]
		var v := float(o.get("money", 0) + o.get("treasure", 0) * 1.6) + (5.0 if o.has("item") else 0.0)
		if v > best:
			best = v
			pick = req["tiles"][i]
	return {"i": pick}


## Differenza fra il mio punteggio finale e quello del migliore avversario (stato attuale).
func margin(e, p: int) -> float:
	var me: int = e.final_score(p)["totale"]
	var best := -999
	for q in e.n:
		if q != p:
			best = maxi(best, e.final_score(q)["totale"])
	return me - (best if best > -999 else 0)


func _z8(e, p: int, req: Dictionary) -> Dictionary:
	var o: Dictionary = req["options"]
	var tr: Array = e.ps[p]["treasures"]
	if not o["sell"].is_empty() and not tr.is_empty():
		var v: int = tr.max()
		var best := -99.0
		var room := -1
		for i in o["sell"]:
			var sc := 0.0
			if i == -1:
				sc = W["store_end"] if e.period < 9 else -0.5
			else:
				var k: int = e.room_free_slot(i)
				sc = float(e.rooms[i]["cfg"]["vp"][k]) + 0.5
				var left := 0
				for x in e.rooms[i]["slots"]:
					if x == null:
						left += 1
				if left == 1:
					sc += 1.5 if e.rooms[i]["sponsor"] == p else 0.8
				if e.rooms[i]["sponsor"] == p:
					sc += 0.7
			if sc > best:
				best = sc
				room = i
		if room == -1 and e.period < 9 and o["sell"].size() == 1 and not o["sponsor"].is_empty():
			pass
		else:
			return {"a": "sell", "v": v, "room": room}
	if not o["sponsor"].is_empty():
		var best_i := -1
		var bs := -99.0
		for i in o["sponsor"]:
			var cfg: Dictionary = e.rooms[i]["cfg"]
			var s: float = cfg["rp"] * 1.0 + cfg["vp"].size() * 0.3 - o["sponsor"][i] * 0.4
			if s > bs:
				bs = s
				best_i = i
		return {"a": "sponsor", "room": best_i}
	if not o["sell"].is_empty() and not tr.is_empty():
		return {"a": "sell", "v": tr.max(), "room": -1}
	return {"a": "none"}


func _bid(e, p: int, req: Dictionary) -> Dictionary:
	var mx: int = req["max"]
	var k: int = (e.period - 1) % 3
	var b := 2
	if k == 2:
		b = mx
		if e.variant and e.period in [3, 6] and level > 0:
			b = mini(mx, maxi(2, mx - 8))
	elif level >= 1:
		b = mini(mx, 2 + rng.randi_range(0, 2))
	return {"bid": maxi(2, mini(b, mx))}


func _reserve(e, p: int, req: Dictionary) -> Dictionary:
	var best := -1.0
	var pick: String = req["cards"][0]
	for t in req["cards"]:
		var v: float = want(e, p, t) + D.TECHS[t]["vp"]
		if v > best:
			best = v
			pick = t
	return {"t": pick}


# ================================================================ variante

func _merc_bid(e, p: int, req: Dictionary) -> Dictionary:
	var best := 0.0
	for z in req["zones"]:
		best = maxf(best, merc_value(e, p, z))
	# un punto di reputazione vale circa 2$; si tiene qualcosa per le buste
	var worth := int(best * (2.0 if level > 0 else 1.6)) - (2 if level > 0 else 0)
	var cap: int = mini(req["max"], worth)
	var b: int = req["high"] + 1
	if b > cap:
		return {"bid": 0}
	if level == 0 and rng.randf() < 0.3:
		return {"bid": 0}
	return {"bid": b}


func _merc2(e, p: int, req: Dictionary) -> Dictionary:
	var best := -99.0
	var pick: String = req["techs"][0]
	for t in req["techs"]:
		var v: float = D.TECHS[t]["vp"] + (want(e, p, t) * 0.4 if e.tech_left(t) > 0 or e.tech_owner[t] == -1 else 0.0)
		if e.tech_owner[t] >= 0 and e.tech_owner[t] < e.n and e.tech_owner[t] != p:
			v += D.TECHS[t]["vp"] * 0.5
		if e.tech_owner[t] == p:
			v -= 10.0
		if v > best:
			best = v
			pick = t
	return {"t": pick}


func _merc8(e, p: int, req: Dictionary) -> Dictionary:
	# prova ogni mossa sul museo e tiene quella che migliora di più il margine
	var base := margin(e, p)
	var best := 0.5
	var pick := {}
	var spots: Array = req["spots"]
	var cands := []
	for x in spots:
		for to in req["free"]:
			cands.append({"a": "move", "x": x, "to": to})
		if level >= 2:
			for y in spots:
				if str(x) < str(y):
					cands.append({"a": "swap", "x": x, "y": y})
	for c in cands:
		var snap := _museum_snap(e)
		var reps := []
		for q in e.n:
			reps.append(e.ps[q]["rep"])
		if e.apply_merc8(c):
			var v := margin(e, p) - base
			if v > best:
				best = v
				pick = c
		_museum_restore(e, snap)
		for q in e.n:
			e.ps[q]["rep"] = reps[q]
	return pick if not pick.is_empty() else {"a": "none"}


func _museum_snap(e) -> Array:
	var r := []
	for room in e.rooms:
		r.append({"open": room["open"], "slots": room["slots"].duplicate()})
	return [r, e.storage.duplicate()]


func _museum_restore(e, snap: Array) -> void:
	for i in e.rooms.size():
		e.rooms[i]["open"] = snap[0][i]["open"]
		e.rooms[i]["slots"] = snap[0][i]["slots"]
	e.storage = snap[1]


func _mine_score(e, p: int, k: int, c0: int) -> float:
	var s: Dictionary = e.sites[k]
	var v := 0.0
	var mine: bool = p in s["access"]
	var others: int = s["access"].size() - (1 if mine else 0)
	for row in 3:
		for c in range(c0, c0 + 3):
			var x: String = s["grid"][row][c]
			if x == "S":
				v += 2.0
			elif x.begins_with("T") or x.begins_with("N") or x.begins_with("I"):
				var val := int(x.substr(1))
				v -= val * 0.25 if mine else 0.0
				v += val * 0.08 * others
	return v


func _mine(e, p: int, req: Dictionary) -> Dictionary:
	var best := 2.5 if e.period < 9 else 0.5
	var pick := {"none": true}
	for k in req["options"]:
		for c0 in req["options"][k]:
			var v := _mine_score(e, p, k, c0)
			if v > best:
				best = v
				pick = {"site": k, "col": c0}
	return pick
