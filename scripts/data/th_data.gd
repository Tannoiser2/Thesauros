extends RefCounted
## Dati fissi di Thesauros: tecnologie, oggetti, museo, code delle zone e posizioni sul tabellone.
## Le coordinate sono in pixel del tabellone originale (3484 × 5137); il disegno le scala.

const BOARD_W := 3484.0
const BOARD_H := 5137.0

## Colori delle compagnie, nell'ordine del regolamento (Verde, Bianco, Rosso, Blu).
const COLORS := [
	{"key": "verde", "name": "Verde", "company": "Mare Nostrum", "col": Color("#4fae3c"), "dark": Color("#24601a"), "text": Color("#ffffff")},
	{"key": "bianco", "name": "Bianco", "company": "Abyss Labs", "col": Color("#ecebe4"), "dark": Color("#8d8a80"), "text": Color("#1d2a33")},
	{"key": "rosso", "name": "Rosso", "company": "Deep Sea", "col": Color("#d8352a"), "dark": Color("#7a1610"), "text": Color("#ffffff")},
	{"key": "blu", "name": "Blu", "company": "Mermaids Society", "col": Color("#2f6fd1"), "dark": Color("#163a78"), "text": Color("#ffffff")},
]
## Gommoni: i primi quattro sono quelli dei giocatori, gli altri quattro si comprano al porto.
const ZODIAC_COLORS := ["verde", "bianco", "rosso", "blu", "marrone", "rosa", "lime", "giallo"]

## Conti della compagnia
const ACCOUNTS := ["hr", "rd", "gp", "me", "bc"]
const ACC_NAMES := {"hr": "Risorse umane", "rd": "Ricerca e sviluppo", "gp": "Acquisti generali", "me": "Spese di missione", "bc": "Cassa nera"}
const ACC_SHORT := {"hr": "RU", "rd": "R&S", "gp": "AG", "me": "SM", "bc": "CN"}
const ACC_COLORS := {"hr": Color("#7b4fb0"), "rd": Color("#2e4f9c"), "gp": Color("#c2452c"), "me": Color("#1f8f86"), "bc": Color("#3a3a3a")}
## Consigli della modalità Iniziazione (minimi suggeriti per il primo anno)
const INIT_HINT := {"hr": 12, "rd": 10, "gp": 10, "me": 3, "bc": 2}

## Oggetti tecnologici
const ITEMS := {
	"maschera": {"name": "Maschera", "depth": 2},
	"bombola": {"name": "Bombola", "depth": 3},
	"scafandro": {"name": "Scafandro", "depth": 4},
	"arpione": {"name": "Arpione", "kill": 6},
	"fucile": {"name": "Fucile subacqueo", "kill": 4},
	"fucile_plus": {"name": "Fucile migliorato", "kill": 4, "bonus": 1},
	"gabbia": {"name": "Gabbia antisqualo"},
	"sonar": {"name": "Sonar", "range": 2, "use": 1},
	"sonar_plus": {"name": "Sonar migliorato", "range": 3, "use": 1},
	"sonar_av": {"name": "Sonar avanzato", "range": 4, "use": 2},
	"satellite": {"name": "Rilevamento satellitare", "range": 9, "use": 0},
	"trapano": {"name": "Trapano", "dig": 3, "use": 1},
	"martello": {"name": "Martello pneumatico", "dig": 4, "use": 2},
	"mot_piccolo": {"name": "Motore booster", "engine": true, "paid": 1, "free": 0},
	"mot_medio": {"name": "Motore medio", "engine": true, "paid": 2, "free": 0},
	"mot_super": {"name": "Super motore", "engine": true, "paid": 0, "free": 2},
	"mot_isola": {"name": "Motore dell'isola", "engine": true, "paid": 3, "free": 0},
	"nassa": {"name": "Nassa per aragoste"},
	"metal": {"name": "Metal detector"},
}
const ITEM_ORDER := ["maschera", "bombola", "scafandro", "arpione", "fucile", "fucile_plus", "gabbia", "sonar", "sonar_plus",
	"sonar_av", "satellite", "trapano", "martello", "mot_piccolo", "mot_medio", "mot_super", "mot_isola", "nassa", "metal"]

## Carte tecnologia: livello, brevetto (D), prezzo al banco (G), royalty (H), punti, tipo di colonna delle copie.
const TECHS := {
	"maschera": {"lv": 0, "d": 4, "g": 3, "h": 2, "vp": 1, "col": 5, "diver": "verde", "text": "Immersione fino al 2º livello"},
	"arpione": {"lv": 0, "d": 4, "g": 3, "h": 2, "vp": 1, "col": 4, "diver": "verde", "text": "Contro gli squali (6 uccide). Pesca in laguna: 5$"},
	"sonar": {"lv": 0, "d": 3, "g": 3, "h": 2, "vp": 1, "col": 5, "diver": "blu", "text": "Tesori nascosti fino al 2º livello, 1$ a uso"},
	"mot_piccolo": {"lv": 0, "d": 4, "g": 3, "h": 2, "vp": 1, "col": 5, "diver": "verde", "text": "+1 casella per 1$"},
	"bombola": {"lv": 1, "d": 6, "g": 3, "h": 3, "vp": 2, "col": 4, "diver": "blu", "text": "Immersione fino al 3º livello"},
	"mot_medio": {"lv": 1, "d": 5, "g": 3, "h": 3, "vp": 2, "col": 4, "diver": "", "text": "+2 caselle per 1$"},
	"trapano": {"lv": 1, "d": 5, "g": 3, "h": 3, "vp": 2, "col": 4, "diver": "", "text": "Libera dalla roccia fino al 3º livello, 1$"},
	"sonar_av": {"lv": 1, "d": 5, "g": 3, "h": 3, "vp": 2, "col": 4, "diver": "", "text": "Tesori nascosti fino al 4º livello, 2$ a uso"},
	"fucile": {"lv": 1, "d": 5, "g": 3, "h": 3, "vp": 2, "col": 4, "diver": "blu", "text": "Contro gli squali (4-6 uccide). Pesca: 6$"},
	"nassa": {"lv": 1, "d": 7, "g": 3, "h": 4, "vp": 3, "col": 3, "diver": "blu", "text": "Pesca delle aragoste in laguna: 8$"},
	"gabbia": {"lv": 2, "d": 8, "g": 4, "h": 4, "vp": 3, "col": 3, "diver": "", "text": "Ignora gli squali; +2 al dado"},
	"scafandro": {"lv": 2, "d": 8, "g": 4, "h": 4, "vp": 3, "col": 3, "diver": "", "text": "Immersione fino al 4º livello"},
	"mot_super": {"lv": 2, "d": 8, "g": 3, "h": 4, "vp": 3, "col": 3, "diver": "", "text": "+2 caselle gratis"},
	"martello": {"lv": 2, "d": 9, "g": 4, "h": 4, "vp": 3, "col": 3, "diver": "", "text": "Libera dalla roccia fino al fondo, 2$"},
	"satellite": {"lv": 2, "d": 9, "g": 9, "h": 4, "vp": 3, "col": 3, "diver": "", "text": "Tesori nascosti a ogni profondità; 2 carte tesoro"},
}
## Copie disponibili secondo il tipo di colonna e il numero di giocatori (il solitario vale come 2).
const COPIES := {5: {4: 5, 3: 4, 2: 3}, 4: {4: 4, 3: 3, 2: 2}, 3: {4: 3, 3: 2, 2: 2}}

## Oggetti dell'isola (9 su 12 per partita)
const ISLAND := [
	{"k": "moneta", "name": "Moneta da collezione", "money": 6}, {"k": "collana", "name": "Collana", "money": 7},
	{"k": "orologio", "name": "Orologio antico", "money": 8}, {"k": "bracciale", "name": "Bracciale", "money": 9},
	{"k": "isola_t3", "name": "Tesoro di ossidiana", "treasure": 3}, {"k": "isola_t3", "name": "Tesoro di ossidiana", "treasure": 3},
	{"k": "isola_t3", "name": "Tesoro di ossidiana", "treasure": 3}, {"k": "isola_t5", "name": "Tesoro di bronzo", "treasure": 5},
	{"k": "isola_t5", "name": "Tesoro di bronzo", "treasure": 5}, {"k": "mot_isola", "name": "Motore dell'isola", "item": "mot_isola"},
	{"k": "fucile_plus", "name": "Fucile migliorato", "item": "fucile_plus"}, {"k": "sonar_plus", "name": "Sonar migliorato", "item": "sonar_plus"},
]
const TREASURE_NAMES := {3: "ossidiana", 5: "bronzo", 7: "argento", 9: "oro"}

const ZONE_NAMES := {1: "Reclutamento", 2: "Ricerca e sviluppo", 3: "Mercatino", 4: "Idrovolanti", 5: "Alto mare",
	6: "Pesca delle cozze", 7: "Porto e laguna", 8: "Museo", 9: "Pubblicità", 10: "Autorità locali"}
const ZONE_HINT := {1: "Assumi un nuovo lavoratore (paga dal conto RU).",
	2: "Sviluppa un brevetto o compra un oggetto tecnologico (conto R&S).",
	3: "Compra una carta tesoro per raggiungere un sito di scavo (conto AG).",
	4: "Noleggia un idrovolante: porta oggetti a un gommone in mare e scambia il pilota (conto SM).",
	6: "Pesca delle cozze: piccolo guadagno sicuro.",
	7: "Compra un gommone, esci in laguna oppure parti per l'alto mare (conto SM).",
	8: "Finanzia una sala del museo oppure vendi un tesoro.",
	9: "Pubblicità: guadagni reputazione (conto AG)."}

const LAGOON := {
	"isola1": {"name": "Isola", "need": "metal"}, "isola2": {"name": "Isola", "need": "metal"},
	"turisti": {"name": "Gita turistica", "money": 4}, "pesce": {"name": "Pesca costiera", "need": "arpione"},
	"aragoste": {"name": "Pesca delle aragoste", "need": "nassa", "money": 8},
}

## ------------------------------------------------------------------ disposizione per lato del tabellone
## Code delle zone: posizioni, costo (dove serve) e numero minimo di giocatori per la casella.
const SIDES := {
	"34": {
		"queues": {
			1: {"pos": [Vector2(1181, 1347), Vector2(1181, 1421), Vector2(1181, 1491)], "cost": [3, 4, 6], "minp": [0, 0, 4]},
			2: {"pos": [Vector2(2462, 1065), Vector2(2462, 1135), Vector2(2462, 1206), Vector2(2462, 1275), Vector2(2462, 1346)], "minp": [0, 0, 0, 0, 4]},
			3: {"pos": [Vector2(3225, 650), Vector2(3225, 721), Vector2(3225, 791), Vector2(3225, 862), Vector2(3225, 932)], "minp": [0, 0, 0, 0, 4]},
			4: {"pos": [Vector2(3262, 1831), Vector2(3262, 1904)], "cost": [3, 4], "minp": [0, 0]},
			7: {"pos": [Vector2(450, 3681), Vector2(450, 3752), Vector2(450, 3825), Vector2(450, 3897), Vector2(450, 3969)], "minp": [0, 0, 0, 0, 4]},
			8: {"pos": [Vector2(694, 2077), Vector2(694, 2150), Vector2(694, 2221), Vector2(694, 2290), Vector2(694, 2360), Vector2(694, 2431)], "minp": [0, 0, 0, 0, 0, 4]},
			9: {"pos": [Vector2(322, 179), Vector2(322, 254), Vector2(322, 328), Vector2(322, 400)], "cost": [7, 8, 9, 10], "minp": [0, 0, 0, 4]},
		},
		"env": [Vector2(891, 571), Vector2(979, 571), Vector2(1066, 571), Vector2(1154, 571)],
		"order": [Vector2(900, 740), Vector2(981, 740), Vector2(1060, 740), Vector2(1141, 740)],
		"order_rp": {4: [4, 2, 1, 0], 3: [4, 2, 0], 2: [2, 0], 1: [0]},
		"comp": [0, 2, 4, 6],
		"market_x": 2979.0,
		"market_y": [354, 472, 591, 710, 829, 946, 1066, 1182, 1294],
		"market_price": [3, 3, 4, 5, 6, 7, 8, 9, 10],
		"market_arrow": 2, "market_start": 9, "cards_max": 7,
		"rooms": [
			{"cost": 6, "vp": [4, 2, 4], "rp": 4, "minp": 0, "door": Vector2(169, 981), "spots": [Vector2(175, 1112), Vector2(175, 1231), Vector2(175, 1347)], "open": Vector2(169, 1450)},
			{"cost": 5, "vp": [3, 5, 2], "rp": 3, "minp": 0, "door": Vector2(344, 981), "spots": [Vector2(344, 1112), Vector2(344, 1231), Vector2(344, 1347)], "open": Vector2(344, 1450)},
			{"cost": 5, "vp": [2, 2], "rp": 3, "minp": 0, "door": Vector2(519, 981), "spots": [Vector2(520, 1170), Vector2(520, 1290)], "open": Vector2(519, 1450)},
			{"cost": 4, "vp": [3, 4, 3], "rp": 2, "minp": 4, "door": Vector2(696, 981), "spots": [Vector2(696, 1112), Vector2(696, 1231), Vector2(696, 1347)], "open": Vector2(694, 1450)},
			{"cost": 4, "vp": [5, 2], "rp": 2, "minp": 0, "door": Vector2(175, 1587), "spots": [Vector2(175, 1712), Vector2(175, 1837)], "open": Vector2(175, 1950)},
			{"cost": 3, "vp": [4, 4], "rp": 1, "minp": 0, "door": Vector2(350, 1587), "spots": [Vector2(350, 1712), Vector2(350, 1837)], "open": Vector2(350, 1950)},
			{"cost": 3, "vp": [5], "rp": 1, "minp": 0, "door": Vector2(525, 1587), "spots": [Vector2(525, 1769)], "open": Vector2(525, 1950)},
			{"cost": 3, "vp": [4], "rp": 1, "minp": 0, "door": Vector2(700, 1587), "spots": [Vector2(700, 1769)], "open": Vector2(700, 1950)},
		],
		"storage": Vector2(200, 2237),
		"hats": {2: [Vector2(2375, 1637), Vector2(2475, 1637)], 3: [Vector2(3175, 1200), Vector2(3269, 1200)],
			57: [Vector2(600, 3600), Vector2(694, 3600)], 8: [Vector2(412, 2150), Vector2(519, 2150)]},
		"nodes": {"PORT": Vector2(1060, 3700), "N1": Vector2(1612, 4112), "N2": Vector2(1837, 3950), "N3": Vector2(1844, 4325),
			"N4": Vector2(2327, 3952), "N5": Vector2(2309, 4294), "N6": Vector2(2537, 3952), "N7": Vector2(2554, 4281),
			"F1": Vector2(1887, 4125), "F2": Vector2(2387, 4125)},
		"edges": [["PORT", "N1"], ["PORT", "N2"], ["PORT", "F1"], ["N2", "N4"], ["N2", "F1"], ["N4", "N6"], ["N4", "F2"],
			["N6", "F2"], ["F1", "F2"], ["F1", "N1"], ["F1", "N3"], ["N1", "N3"], ["N3", "N5"], ["N5", "F2"], ["N7", "F2"]],
		"sites": {1: {"c": Vector2(1320, 4353), "rot": 45.0, "large": false}, 2: {"c": Vector2(1735, 3553), "rot": 180.0, "large": false},
			3: {"c": Vector2(1767, 4716), "rot": 0.0, "large": false}, 4: {"c": Vector2(2265, 3525), "rot": 180.0, "large": true},
			5: {"c": Vector2(2331, 4706), "rot": 0.0, "large": true}, 6: {"c": Vector2(2943, 3692), "rot": 225.0, "large": true},
			7: {"c": Vector2(2983, 4436), "rot": 315.0, "large": true}},
	},
	"12": {
		"queues": {
			1: {"pos": [Vector2(1181, 1435)], "cost": [3], "minp": [0]},
			2: {"pos": [Vector2(2462, 1129), Vector2(2462, 1197), Vector2(2462, 1269)], "minp": [0, 0, 2]},
			3: {"pos": [Vector2(3225, 650), Vector2(3225, 721), Vector2(3225, 791)], "minp": [0, 0, 2]},
			4: {"pos": [Vector2(3262, 1831)], "cost": [3], "minp": [0]},
			7: {"pos": [Vector2(450, 3681), Vector2(450, 3752), Vector2(450, 3825)], "minp": [0, 0, 2]},
			8: {"pos": [Vector2(694, 2144), Vector2(694, 2219), Vector2(694, 2287)], "minp": [0, 0, 2]},
			9: {"pos": [Vector2(322, 272), Vector2(322, 350)], "cost": [7, 9], "minp": [0, 0]},
		},
		"env": [Vector2(987, 571), Vector2(1066, 571)],
		"order": [Vector2(987, 737), Vector2(1066, 737)],
		"order_rp": {2: [2, 0], 1: [0]},
		"comp": [0, 3],
		"market_x": 2979.0,
		"market_y": [472, 591, 710, 829, 946, 1066],
		"market_price": [3, 4, 5, 6, 8, 10],
		"market_arrow": 1, "market_start": 5, "cards_max": 5,
		"rooms": [
			{"cost": 6, "vp": [4, 2, 4], "rp": 4, "minp": 0, "door": Vector2(269, 956), "spots": [Vector2(272, 1081), Vector2(272, 1206), Vector2(272, 1325)], "open": Vector2(269, 1425)},
			{"cost": 5, "vp": [3, 5, 2], "rp": 3, "minp": 0, "door": Vector2(444, 956), "spots": [Vector2(446, 1081), Vector2(446, 1206), Vector2(446, 1325)], "open": Vector2(446, 1425)},
			{"cost": 5, "vp": [3], "rp": 3, "minp": 0, "door": Vector2(625, 956), "spots": [Vector2(637, 1143)], "open": Vector2(631, 1331)},
			{"cost": 4, "vp": [2, 3], "rp": 2, "minp": 2, "door": Vector2(344, 1531), "spots": [Vector2(347, 1712), Vector2(347, 1835)], "open": Vector2(344, 1994)},
			{"cost": 3, "vp": [5], "rp": 1, "minp": 2, "door": Vector2(537, 1531), "spots": [Vector2(540, 1712)], "open": Vector2(537, 1897)},
		],
		"storage": Vector2(200, 2250),
		"hats": {2: [Vector2(2375, 1637), Vector2(2475, 1637)], 3: [Vector2(3162, 1075), Vector2(3262, 1075)],
			57: [Vector2(600, 3600), Vector2(694, 3600)], 8: [Vector2(412, 2162), Vector2(512, 2162)]},
		"nodes": {"PORT": Vector2(1060, 3700), "N1": Vector2(1837, 4325), "N2": Vector2(2090, 3950), "N3": Vector2(2237, 4325),
			"N4": Vector2(2546, 3946), "N5": Vector2(2640, 4200), "F1": Vector2(1887, 4125), "F2": Vector2(2331, 4125)},
		"edges": [["PORT", "F1"], ["PORT", "N2"], ["PORT", "N1"], ["N2", "N4"], ["N2", "F1"], ["N4", "F2"], ["F1", "F2"],
			["F1", "N1"], ["F2", "N3"], ["F2", "N5"], ["N1", "N3"], ["N3", "N5"]],
		"sites": {1: {"c": Vector2(1805, 4728), "rot": 0.0, "large": false}, 2: {"c": Vector2(2083, 3554), "rot": 180.0, "large": false},
			3: {"c": Vector2(2319, 4716), "rot": 0.0, "large": false}, 4: {"c": Vector2(2943, 3692), "rot": 225.0, "large": true},
			5: {"c": Vector2(2958, 4467), "rot": 315.0, "large": true}},
		"extra_links": {"N5": 4},
	},
}

## Posizioni comuni ai due lati
const TECH_SLOTS := [Vector2(1592, 394), Vector2(1879, 394), Vector2(2165, 394), Vector2(2452, 394),
	Vector2(1592, 806), Vector2(1879, 806), Vector2(2165, 806), Vector2(2452, 806), Vector2(1592, 1218), Vector2(1879, 1218)]
const TECH_DECK := Vector2(2165, 1218)
const TECH_SIZE := Vector2(240, 346)
## caselle del giocatore virtuale (solitario)
const SOLO_SLOTS := [0, 4, 6, 8, 9]
## carte rivelate a fine quadrimestre 1..5
const REVEAL := {1: 1, 2: 1, 3: 2, 4: 1, 5: 2}
const WORKER_ROW_X := [1062, 1181, 1294]
const WORKER_ROW_Y := [1806, 1735, 1666, 1597]   # verde, bianco, rosso, blu
const Z6_TRACK := [Vector2(272, 4669), Vector2(350, 4669), Vector2(427, 4669)]
const Z6_AREA := Vector2(369, 4775)
const Z9_TRACK := [Vector2(272, 612), Vector2(352, 612), Vector2(431, 612), Vector2(507, 612)]
const Z9_REP := [4, 3, 3, 2]
const SHOP := [Vector2(850, 3519), Vector2(987, 3519)]
const SHOP_COST := [6, 8]
const DOCK_X := 1019.0
const SPARE_X := 762.0
const DOCK_Y := [3870, 3987, 4094, 4200]
const LAGOON_POS := {"isola1": Vector2(1277, 2919), "isola2": Vector2(1312, 3037), "turisti": Vector2(2056, 2919),
	"pesce": Vector2(2256, 3085), "aragoste": Vector2(2531, 3219)}
const ISLAND_X := [1525, 1656, 1787]
const ISLAND_Y := [2644, 2769, 2894]
const PLANES := [Vector2(3119, 2650), Vector2(3119, 2762)]
const CELL := Vector2(88, 70)

## Tracciato della reputazione: 0 in alto a destra, poi giù, in basso verso sinistra e su a sinistra.
const REP_RIGHT := [3122, 3210, 3269, 3325, 3385, 3471, 3556, 3615, 3672, 3731, 3890, 4006, 4066, 4125, 4183, 4271, 4355,
	4413, 4471, 4530, 4618, 4703, 4761, 4820, 4878]
const REP_BOTTOM := [3219, 3159, 3100, 3041, 2956, 2871, 2812, 2754, 2696, 2606, 2521, 2462, 2404, 2346, 2260, 2175, 2116,
	2058, 2000, 1910, 1825, 1766, 1707, 1647, 1559, 1475, 1416, 1358, 1300, 1212, 1127, 1069, 1010, 951, 866, 779, 721, 663,
	605, 519, 434, 375, 316, 258]
const REP_LEFT := [4887, 4827, 4767, 4708, 4620, 4536, 4477, 4417, 4358, 4272, 4187, 4130, 4065, 4012, 3925, 3837, 3781,
	3725, 3666, 3575, 3490, 3434, 3375, 3319, 3225, 3146, 3081, 3025, 2969]


static func rep_pos(v: int) -> Vector2:
	var n := posmod(v, 100)
	if n <= 24:
		return Vector2(3310, REP_RIGHT[n])
	if n == 25:
		return Vector2(3310, 4965)
	if n <= 69:
		return Vector2(REP_BOTTOM[n - 26], 4965)
	if n == 70:
		return Vector2(170, 4965)
	return Vector2(169, REP_LEFT[n - 71])


## Asse orizzontale e verso la superficie di un sito ruotato (gradi in senso orario).
static func site_axes(rot: float) -> Array:
	var a := deg_to_rad(rot)
	return [Vector2(cos(a), sin(a)), Vector2(sin(a), -cos(a))]


## Centro della cella (riga, colonna) di un sito; la riga 0 è quella in superficie.
static func cell_pos(site: Dictionary, row: int, col: int) -> Vector2:
	var rows := 4 if site["large"] else 3
	var cols := 5 if site["large"] else 4
	var ax := site_axes(site["rot"])
	return site["c"] + ax[0] * (col - (cols - 1) * 0.5) * CELL.x + ax[1] * ((rows - 1) * 0.5 - row) * CELL.y


## Casella d'immersione (sopra la colonna col) di un sito.
static func dive_pos(site: Dictionary, col: int) -> Vector2:
	var rows := 4 if site["large"] else 3
	var cols := 5 if site["large"] else 4
	var ax := site_axes(site["rot"])
	return site["c"] + ax[0] * (col - (cols - 1) * 0.5) * CELL.x + ax[1] * (rows * CELL.y * 0.5 + 88.0)
