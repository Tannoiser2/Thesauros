extends Control
## Le regole di Thesauros riassunte in italiano, con le carte tecnologia.

const D = preload("res://scripts/data/th_data.gd")

var main
var popup := false

const TEXT := """[font_size=34][color=#f5d27c]Thesauros in breve[/color][/font_size]
Guidate un'agenzia di recupero di relitti. In [b]3 anni[/b] (9 quadrimestri) assumete personale, sviluppate tecnologie, comprate le carte tesoro che vi aprono i siti di scavo, mandate i gommoni in alto mare a immergersi fra gli squali e vendete i tesori al museo. Vince chi ha più [b]reputazione[/b] alla fine. Si gioca da 1 a 4: il lato del tabellone per 1-2 giocatori ha meno caselle e meno siti.
Ogni compagnia parte con il capo, 2 lavoratori, un gommone (con costume e lenza), un metal detector e 10 punti di reputazione. Il primo anno riceve 50$ (55$ in Iniziazione e in solitario) più il compenso dell'ordine di turno.

[font_size=26][color=#e2674a]1 · Reddito (inizio di ogni anno)[/color][/font_size]
Anno 1: 50$. Anno 2: 30$ + 5$ per ogni carta tesoro posseduta. Anno 3: 10$ + 5$ per carta.

[font_size=26][color=#e2674a]2 · Budget[/color][/font_size]
Tutto il denaro si ripartisce fra cinque conti per l'intero anno: [b]Risorse umane[/b] (assunzioni e stipendi), [b]Ricerca e sviluppo[/b] (brevetti e oggetti), [b]Acquisti generali[/b] (carte tesoro, sale del museo, pubblicità), [b]Spese di missione[/b] (idrovolanti, motori, sonar, attrezzi, gommoni) e la [b]cassa nera[/b] (buste per le autorità), che si riempie solo in questa fase.
Se un conto non basta si trasferisce denaro dagli altri (mai da o verso la cassa nera, salvo in Iniziazione) pagando per ogni trasferimento una tassa di 1$ il primo anno, 2$ il secondo, 3$ il terzo. Nella versione digitale si sceglie anche il conto dove finiscono gli incassi dell'anno.

[font_size=26][color=#e2674a]3 · Quadrimestri: piazzamento[/color][/font_size]
In ordine di turno ognuno mette un meeple alla volta nella prima casella libera di una coda (zone 1-4, 6-9; la zona 6 non ha limiti) finché tutti li hanno piazzati. Prima di piazzare si può lasciare la [b]busta[/b] in zona 10. Il segnalino [b]doppia azione[/b] permette al meeple di agire due volte nella stessa zona.
Il [b]capo[/b] ha vantaggi in quasi tutte le zone (di solito 2$). Nelle zone 2, 3, 7 e 8, se il capo e un lavoratore della stessa compagnia sono nella stessa coda, il lavoratore diventa [b]specialista[/b] di quella zona (finché ci sono cappelli) e da allora ha gli stessi vantaggi del capo lì. Gli specialisti 5/7 valgono in mare e al porto.

[font_size=26][color=#e2674a]Risoluzione, zona per zona[/color][/font_size]
[b]1 Reclutamento[/b]: assumi un lavoratore (costo della casella, il capo 2$ in meno). Il secondo assunto porta la doppia azione, il terzo 1 reputazione. Il nuovo lavoratore entra subito in una coda.
[b]2 Ricerca e sviluppo[/b]: sviluppa un brevetto (costo sulla medaglia), compra un oggetto di un brevetto già sviluppato (prezzo al banco + royalty al proprietario) oppure fai entrambe le cose insieme; oppure prenota la prossima carta tecnologia (la scegli dal mazzo a fine quadrimestre). Le copie sono limitate. Il capo e gli specialisti 2 pagano 2$ in meno.
[b]3 Mercatino[/b]: compra una carta tesoro: dà accesso al sito di scavo con quel numero. Domanda e offerta: le carte uguali impilate costano meno, comprarne una fa salire il prezzo delle altre. Il primo ad avere la carta di un sito sceglie in segreto la tessera fra tre.
[b]4 Idrovolanti[/b]: porta oggetti a un tuo gommone in mare e scambia il pilota con l'equipaggio.
[b]5 Alto mare[/b]: in ordine di turno ogni gommone in mare si muove e si immerge (o prima si immerge e poi si muove). Movimento: 2 caselle gratis + 1 per 1$, più i motori (al massimo 2 aggiunti). Le caselle numerate e i siti si attraversano solo con la carta tesoro giusta. Nelle aree di pesca si guadagnano 2$. Prima di muovere si può noleggiare un idrovolante libero.
[b]Immersione[/b]: dalla casella sopra una colonna del sito si scende: senza attrezzi solo il 1º livello, con maschera il 2º, bombola il 3º, scafandro il 4º. Gli squali bloccano la colonna senza arpione, fucile o gabbia: l'arpione uccide con 6, il fucile con 4-6, la gabbia dà +2 (da sola protegge), il capo o lo specialista 5/7 +1. Ogni squalo ucciso vale 2 punti. Si recupera un tesoro (due nella stessa colonna con il capo o lo specialista 5/7); quelli nascosti richiedono un sonar (2 livelli, avanzato 4, satellite ovunque), quelli incastrati nella roccia il trapano (fino al 3º) o il martello pneumatico.
[b]6 Cozze[/b]: si guadagna quanto indicato sopra il cubetto (1$, 2$, poi 1 reputazione); il capo prende 2$ in più.
[b]7 Porto e laguna[/b]: compra un gommone (+1 reputazione), esci in laguna (aragoste 8$ con la nassa, pesce 5$ con l'arpione o 6$ con il fucile, gita turistica 4$, isola con il metal detector; il capo o lo specialista 5/7 guadagna 2$ in più o sceglie fra due oggetti dell'isola) oppure prendi il largo: il meeple resta in mare finché non rientra in porto.
[b]8 Museo[/b]: finanzia una sala libera oppure vendi un tesoro (ne incassi il valore, +2$ per il capo o lo specialista 8) e mettilo nel primo posto libero di una sala finanziata o nel deposito. Quando una sala è piena apre al pubblico e chi l'ha finanziata guadagna subito la reputazione indicata.
[b]9 Pubblicità[/b]: paga e guadagni la reputazione sopra il cubetto (4, 3, 3, 2: chi arriva prima guadagna di più).
[b]10 Autorità locali[/b]: chi ha lasciato la busta fa un'offerta segreta dalla cassa nera (almeno 2$). Si paga tutto; il nuovo ordine di turno va dall'offerta più alta.
Un meeple che non può o non vuole agire fa perdere 1 reputazione.

[font_size=26][color=#e2674a]Stipendi, manutenzione, fine anno[/color][/font_size]
Ogni lavoratore costa 2$ a quadrimestre (il capo no); ogni stipendio non pagato costa 1 reputazione. Poi si scoprono nuove tecnologie (1, 1, 2, 1, 2 carte dopo i primi cinque quadrimestri), arrivano 2 carte tesoro al mercatino, gli idrovolanti tornano e i gommoni della laguna rientrano. Alla fine dei primi due anni l'ordine di turno dà reputazione (4/2/1/0 in quattro, 4/2/0 in tre, 2/0 in due).

[font_size=26][color=#e2674a]Fine della partita[/color][/font_size]
Dopo il 9º quadrimestre, oppure dopo il quadrimestre in cui tutte le sale del museo si aprono. Si aggiunge: per ogni tesoro in una sala aperta i punti del posto, in una sala chiusa 2, in deposito 1, in sede 2; i punti dei brevetti; 2 per squalo; 1 per carta tesoro e 2 per ogni gruppo di almeno 3 carte uguali; 1 ogni 10$; l'influenza finale come a fine anno. A parità vince chi è più avanti nell'ordine di turno.

[font_size=26][color=#e2674a]Solitario[/color][/font_size]
Si gioca sul lato 1-2 senza zona 10. Un giocatore virtuale possiede i brevetti delle caselle segnate (royalty al banco). Ci sono solo 2 tipi di cappello. Si vince aprendo tutte e 3 le sale del museo e superando 80 punti; bonus +30 se succede entro il 6º quadrimestre, +20 nel 7º, +10 nell'8º.

[font_size=26][color=#e2674a]Iniziazione[/color][/font_size]
Consigliata per la prima partita: 55$ iniziali con i minimi suggeriti per ogni conto, maschera, arpione e motore booster disponibili subito, le carte tesoro 1-4 al mercatino, trasferimenti possibili anche dalla cassa nera.

[font_size=26][color=#e2674a]Note della versione digitale[/color][/font_size]
• La variante «Senza fede né legge» (mercenari) non è inclusa.
• Le tessere dei siti di scavo sono ridisegnate dai dati del modulo: la riga in alto è la superficie. Le tessere coperte le vedono solo i possessori della carta tesoro.
• In immersione si sceglie quali tesori raggiungibili prendere; gli squali incontrati scendendo si affrontano con l'attrezzatura a bordo.
• I gommoni stanno in porto finché non escono in laguna o al largo; in porto gli oggetti si caricano e scaricano liberamente.
"""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if popup:
		z_index = 30
		mouse_filter = Control.MOUSE_FILTER_STOP
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, 0.82)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(shade)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.dark_style(8, 0.97))
	pc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pc.offset_left = 80
	pc.offset_right = -80
	pc.offset_top = 40
	pc.offset_bottom = -40
	add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pc.add_child(vb)
	var hh := HBoxContainer.new()
	vb.add_child(hh)
	var t := UI.title("Regole", 44)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(t)
	var back := UI.primary(UI.button("Chiudi" if popup else "Torna al menu", 240, 52, 22))
	back.pressed.connect(func():
		if popup:
			queue_free()
		else:
			main.show_menu())
	hh.add_child(back)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 18)
	sc.add_child(inner)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_size_override("normal_font_size", 22)
	rt.add_theme_font_size_override("bold_font_size", 22)
	rt.text = TEXT
	inner.add_child(rt)
	inner.add_child(UI.title("Le tecnologie", 34))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 14)
	flow.add_theme_constant_override("v_separation", 14)
	inner.add_child(flow)
	for tk in D.TECHS:
		var c: Dictionary = D.TECHS[tk]
		var v := VBoxContainer.new()
		v.custom_minimum_size.x = 240
		v.add_child(UI.icon_rect(UI.tech_tex(tk), Vector2(220, 318)))
		v.add_child(UI.label(D.ITEMS[tk]["name"], 20, UI.GOLD_L, UI.font_bold))
		v.add_child(UI.wrap(UI.label("Livello %d · brevetto %d$ · oggetto %d$ + %d$ di royalty · %d punti" % [c["lv"], c["d"], c["g"], c["h"], c["vp"]], 17, UI.SAND), 230))
		v.add_child(UI.wrap(UI.label(c["text"], 17, UI.MUTED), 230))
		flow.add_child(v)
