class_name Tutorial
extends RefCounted
## Il tutorial: lezioni a pagine che compaiono al momento giusto di una partita guidata, il consiglio
## del tutor per ogni decisione (la mossa che farebbe l'IA difficile, spiegata) e il manuale di strategia.

const D = preload("res://scripts/data/th_data.gd")

## Partita del tutorial: tu (Mare Nostrum) contro due IA facili, modo Iniziazione, sempre la stessa partita.
const SEED := 2025
static func config() -> Dictionary:
	return {"seats": [{"name": "Tu", "ai": false, "level": 1, "color": 0},
		{"name": "Abyss Labs (IA)", "ai": true, "level": 0, "color": 1},
		{"name": "Deep Sea (IA)", "ai": true, "level": 0, "color": 2}],
		"seed": SEED, "initiation": true, "tutorial": true, "ai_delay": 0.5, "anim": 1.0}


# ================================================================ lezioni
## chiave -> elenco di pagine [titolo, testo]
const LESSONS := {
	"intro": [
		["Benvenuto in Thesauros", """In questa partita guidata dirigi [b]Mare Nostrum[/b], un'agenzia di recupero di relitti. Contro di te giocano [b]Abyss Labs[/b] e [b]Deep Sea[/b], guidate dall'IA.

In [b]tre anni[/b] (nove quadrimestri) devi farti la reputazione migliore: alla fine vince chi ha più punti sul tracciato che corre attorno al tabellone, sommati ai punti di fine partita.

La partita è in modo [b]Iniziazione[/b], quello consigliato per la prima volta: 55$ per cominciare, le prime tecnologie già pronte (maschera, arpione, motore booster) e le carte tesoro 1-4 al mercatino.

Ogni volta che arriva una decisione nuova si apre una lezione come questa. In più, nel riquadro [b]Consiglio del tutor[/b] trovi sempre la mossa che farebbe un giocatore esperto e il perché: puoi seguirla con un tocco oppure fare di testa tua."""],
		["Come si guadagna reputazione", """Le vie principali sono quattro, e si intrecciano:
- [b]I tesori al museo[/b]. Recuperi i tesori dai relitti, li vendi al museo (incassando il loro valore) e li esponi nelle sale: a fine partita un tesoro in una sala aperta vale da 2 a 5 punti. Chi [b]finanzia[/b] una sala guadagna subito dei punti quando la sala si riempie e apre al pubblico.
- [b]La pubblicità[/b] (zona 9): punti subito, di più per chi la fa per primo.
- [b]I brevetti[/b] (zona 2): a fine partita valgono da 1 a 3 punti ciascuno, e intanto incassi le royalty da chi compra i tuoi oggetti.
- [b]Le carte tesoro[/b], gli [b]squali[/b] uccisi, il [b]denaro[/b] avanzato e l'[b]influenza[/b] sulle autorità valgono punti a fine partita.

E si perdono punti: ogni meeple che non riesce a fare la sua azione e ogni stipendio non pagato costano 1 punto."""],
		["Il tabellone", """In alto ci sono gli edifici delle zone d'azione, numerati da [b]1 a 10[/b]: reclutamento, ricerca e sviluppo, mercatino, idrovolanti, pesca delle cozze, porto, museo, pubblicità, autorità locali. Sotto, il [b]porto[/b] con la laguna e l'isola, e il mare aperto con i [b]siti di scavo[/b] dove giacciono i relitti.

[b]Muoversi sul tabellone[/b]: trascina con un dito o con il mouse, pizzica con due dita o usa la rotella per ingrandire, ruota con due dita (o con il tasto destro). «Tutto» rimette il tabellone per intero, «2D / 3D» cambia vista.

Quando una decisione riguarda il tabellone, le scelte possibili sono [b]cerchiate in oro[/b]: puoi toccarle direttamente, oppure usare i pulsanti nella barra in basso.

A destra vedi le compagnie (tocca un nome per i dettagli), i conti e il materiale della tua, e il diario di tutto quello che succede."""],
		["Come si svolge un anno", """Ogni anno:
1. [b]Reddito[/b]: il primo anno 55$; il secondo 30$ + 5$ per carta tesoro; il terzo 10$ + 5$ per carta.
2. [b]Budget[/b]: dividi tutto il denaro fra cinque conti, per tutto l'anno.
3. [b]Tre quadrimestri[/b], ognuno con: piazzamento dei meeple, risoluzione delle zone dalla 1 alla 10, stipendi, manutenzione.
4. Alla fine dei primi due anni l'[b]ordine di turno[/b] dà reputazione.

Cominciamo dal budget."""],
	],
	"budget": [
		["Il budget: cinque conti", """Il denaro va diviso fra cinque conti, e la divisione vale per [b]tutto l'anno[/b]:
- [b]Risorse umane (RU)[/b]: assunzioni (zona 1) e stipendi, 2$ a lavoratore a ogni quadrimestre. Il capo non costa.
- [b]Ricerca e sviluppo (R&S)[/b]: brevetti e oggetti (zona 2).
- [b]Acquisti generali (AG)[/b]: carte tesoro (zona 3), sale del museo (zona 8), pubblicità (zona 9).
- [b]Spese di missione (SM)[/b]: idrovolanti (zona 4), motori, sonar e attrezzi in mare, nuovi gommoni (zona 7).
- [b]Cassa nera (CN)[/b]: le buste per le autorità (zona 10). Si riempie [b]solo adesso[/b]: quello che non metti ora non ci sarà per tutto l'anno.

Se un conto non basta puoi spostare denaro dagli altri, ma ogni trasferimento costa una tassa: 1$ il primo anno, 2$ il secondo, 3$ il terzo. Pianificare bene fa risparmiare."""],
		["Come ripartire", """Un buon punto di partenza:
- [b]RU[/b]: 2$ × lavoratori × 3 quadrimestri, più qualcosa se pensi di assumere. Con 2 lavoratori sono 12$.
- [b]R&S[/b]: il primo anno conta molto, servono maschera e arpione per immergersi. Poi cala.
- [b]AG[/b]: le prime [b]carte tesoro[/b] sono la cosa più importante della partita: senza carta non puoi raggiungere nessun sito di scavo. Poi museo e pubblicità.
- [b]SM[/b]: qualche dollaro per i motori e gli attrezzi in mare.
- [b]CN[/b]: 2-5$ per giocarsi l'ordine di turno.

Il pulsante [b]Ripartizione consigliata[/b] parte dai calcoli del tutor; puoi ritoccare con +1, +5, «Il resto». Gli incassi dell'anno (vendite, pesca, royalty) vanno nel conto che scegli in fondo."""],
	],
	"place": [
		["Il piazzamento", """A turno, un meeple alla volta, mandi il tuo personale nelle zone: il meeple prende la [b]prima casella libera[/b] della coda. Le code si riempiono e chi arriva prima sceglie meglio. Nella zona 6 (cozze) c'è sempre posto. Il piazzamento continua finché tutti hanno piazzato tutto.

Hai tre tipi di meeple:
- il [b]capo[/b] (con il berretto da capitano): in quasi tutte le zone ha un vantaggio, di solito 2$;
- i [b]lavoratori[/b];
- gli [b]specialisti[/b] (con il tocco colorato): nelle zone 2, 3, 7 e 8, se il capo e un tuo lavoratore stanno nella stessa coda, il lavoratore impara e da allora ha gli stessi vantaggi del capo in quella zona. Gli specialisti 5/7 valgono al porto e in mare.

Tocca il nome del meeple nella barra per sceglierlo, poi la zona (sul tabellone o con il pulsante)."""],
		["Busta e doppia azione", """Prima di piazzare un meeple puoi lasciare la [b]busta[/b] alle autorità (zona 10): a fine quadrimestre chi ha lasciato la busta fa un'offerta segreta dalla cassa nera e chi offre di più gioca per primo il quadrimestre seguente. A fine anno l'ordine di turno dà anche reputazione (in tre: 4, 2 e 0 punti).

Il segnalino [b]doppia azione[/b] (lo prendi assumendo il secondo lavoratore) fa agire due volte un meeple nella stessa zona: due carte tesoro, due brevetti, due vendite al museo.

Le zone si risolvono [b]in ordine, dalla 1 alla 10[/b], e nella coda dal primo all'ultimo. Un meeple che al suo turno non può pagare o non ha niente da fare ti costa 1 punto: se non sai dove mandarlo, mandalo alle cozze."""],
	],
	"recruit": [
		["Il nuovo lavoratore", """Hai assunto un lavoratore: entra subito in una coda libera e agisce già in questo quadrimestre. Ricorda però che da ora costa 2$ di stipendio a ogni quadrimestre.

Il [b]secondo[/b] assunto porta il segnalino doppia azione, il [b]terzo[/b] 1 punto reputazione. Assumere presto rende di più: un lavoratore preso nel primo anno lavora otto quadrimestri."""],
	],
	"z2": [
		["Ricerca e sviluppo", """Le carte tecnologia sono le attrezzature. Su ogni carta: il costo del [b]brevetto[/b] (la medaglia), il prezzo dell'[b]oggetto[/b] al banco e la [b]royalty[/b] per il proprietario del brevetto, quante copie esistono, i punti di fine partita.

Quattro azioni:
- [b]Sviluppare il brevetto[/b]: diventa tuo; a fine partita vale 1-3 punti e incassi la royalty ogni volta che un avversario compra l'oggetto.
- [b]Comprare l'oggetto[/b] di un brevetto già sviluppato (paghi prezzo + royalty; solo il prezzo se il brevetto è tuo).
- [b]Sviluppare e comprare[/b] insieme: costa tutto, ma in un'azione sola.
- [b]Prenotare[/b] la prossima carta: la scegli tu dal mazzo e il quadrimestre dopo sei il primo in coda.

Per immergerti servono almeno la [b]maschera[/b] (2º livello) e un [b]arpione[/b] contro gli squali. Il capo e gli specialisti 2 pagano 2$ in meno."""],
	],
	"z3": [
		["Il mercatino delle carte tesoro", """Le [b]carte tesoro[/b] sono le mappe dei relitti: ogni numero apre il sito di scavo con lo stesso numero. Senza la carta non puoi entrare né passare dalle sue caselle.

Il prezzo segue la [b]domanda e l'offerta[/b]: carte uguali impilate costano meno; quando ne compri una, quelle rimaste salgono di prezzo. A ogni quadrimestre ne arrivano due nuove.

Le carte rendono anche dopo: [b]5$ ciascuna[/b] di reddito negli anni 2 e 3, [b]1 punto[/b] ciascuna a fine partita e 2 in più per ogni gruppo di tre uguali. Il capo e gli specialisti 3 pagano 2$ in meno."""],
	],
	"dig": [
		["Il sito di scavo", """Sei il primo ad avere la carta di questo sito: peschi tre tessere e ne tieni una, in segreto. La vedranno solo i possessori della carta, finché un gommone non arriva sul sito e la scopre per tutti.

Come leggere la tessera: la riga in alto è la superficie, si scende verso il fondo.
- Forzieri: [b]tesori[/b] da 3$ (ossidiana), 5$ (bronzo), 7$ (argento), 9$ (oro).
- Forzieri inclinati nella roccia: [b]incastrati[/b], servono trapano o martello pneumatico.
- Cerchi colorati: tesori [b]nascosti[/b], serve un sonar.
- [b]Squali[/b]: bloccano la colonna se non hai arpione, fucile o gabbia.
Scegli la tessera con tesori ricchi e poco profondi."""],
	],
	"z7": [
		["Il porto e la laguna", """Dal porto puoi:
- [b]comprare un gommone[/b] in più (+1 reputazione): più gommoni vuol dire più immersioni a ogni quadrimestre;
- [b]uscire in laguna[/b] solo per questo quadrimestre: aragoste 8$ (con la nassa), pesce 5$ o 6$ (con arpione o fucile), gita turistica 4$, oppure l'[b]isola[/b] con il metal detector, dove trovi monete, gioielli, tesori o attrezzi;
- [b]prendere il largo[/b]: il meeple sale sul gommone e resta in mare per tutti i quadrimestri che vuoi, immergendosi ogni volta.

Prima di partire scegli cosa caricare: in porto gli oggetti si caricano e scaricano liberamente; in mare servirà un idrovolante. Il capo e gli specialisti 5/7 guadagnano 2$ in più in laguna e in mare prendono due tesori della stessa colonna."""],
	],
	"sea": [
		["L'alto mare", """Ogni quadrimestre, in zona 5, ogni gommone in mare [b]si muove e si immerge[/b] (o prima si immerge e poi si muove).

[b]Movimento[/b]: 2 caselle gratis, una terza per 1$; i motori aggiunti (al massimo due) danno caselle in più. Le caselle con un numero e i siti si attraversano solo con la carta tesoro giusta. Le caselle piccole ospitano un gommone solo, le aree di pesca quanti vuoi e danno 2$ di pesca.

Le destinazioni possibili sono cerchiate: quelle azzurre sono le caselle d'immersione sopra le colonne dei siti. Tocca dove andare."""],
	],
	"dive": [
		["L'immersione", """Dalla casella sopra una colonna scendi verso il fondo: senza attrezzi solo il primo livello, con la [b]maschera[/b] il 2º, la [b]bombola[/b] il 3º, lo [b]scafandro[/b] il 4º.

Gli [b]squali[/b] della colonna si affrontano scendendo: l'arpione uccide con un 6, il fucile con 4-6; la gabbia dà +2 (e da sola ti protegge), il capo o lo specialista 5/7 +1. Ogni squalo ucciso vale 2 punti a fine partita.

Recuperi [b]un tesoro[/b] (due nella stessa colonna con il capo o lo specialista 5/7). Gli attrezzi con un costo d'uso (sonar, trapano) si pagano dal conto Spese di missione. Il tesoro va nella tua sede: vale 2 punti se lo tieni, di più se lo esponi al museo."""],
	],
	"z8": [
		["Il museo", """Il museo ha diverse [b]sale[/b], ognuna da 1 a 3 posti. Due azioni:
- [b]Finanziare una sala[/b] (il costo rosso): metti il tuo cubetto sulla porta. Quando la sala si riempie apre al pubblico e tu guadagni subito i punti indicati.
- [b]Vendere un tesoro[/b]: incassi il suo valore e lo metti nel primo posto libero di una sala finanziata (da chiunque) oppure nel deposito.

A fine partita un tesoro in una [b]sala aperta[/b] vale i punti del suo posto (da 2 a 5), in una sala chiusa 2, in deposito solo 1. Riempire le sale conviene a tutti, ma soprattutto a chi le ha finanziate. Quando tutte le sale sono aperte la partita finisce subito."""],
	],
	"bid": [
		["La busta sotto il tavolo", """Hai lasciato la busta: ora offri in segreto dalla cassa nera (almeno 2$). Le offerte si pagano tutte, anche quelle perdenti; il nuovo ordine di turno va dall'offerta più alta (a parità vince chi ha lasciato la busta prima), e chi non ha offerto finisce in coda.

Giocare primi vuol dire scegliere per primi le caselle migliori. Ma l'ordine conta soprattutto alla [b]fine di ogni anno[/b] e della partita, quando dà reputazione: l'offerta del terzo quadrimestre di ogni anno è quella che vale di più."""],
	],
	"plane": [
		["L'idrovolante", """Con l'idrovolante porti gli oggetti dal magazzino a un tuo gommone in mare (e viceversa): così puoi cambiare l'attrezzatura senza tornare in porto. Prenotandolo in zona 4 puoi anche [b]scambiare il pilota[/b] con l'equipaggio del gommone: per esempio portare il capo in mare al posto di un lavoratore."""],
	],
	"island": [
		["L'isola", """Il capo (o lo specialista 5/7) sull'isola guarda due oggetti sepolti e ne tiene uno. Le monete e i gioielli si cambiano subito in denaro, i tesori vanno in sede come gli altri, gli attrezzi nel magazzino."""],
	],
	"reserve": [
		["La carta prenotata", """Il tuo meeple sul mazzo ti permette di scegliere la prossima tecnologia che compare. Il quadrimestre prossimo sarà il primo in coda alla zona 2: potrai comprarla per primo."""],
	],
	"p2": [
		["Fine del primo quadrimestre", """Hai visto un quadrimestre completo. Dopo la risoluzione delle zone:
- [b]Stipendi[/b]: 2$ a lavoratore dal conto RU. Se non bastano i soldi, 1 punto in meno per ogni stipendio mancato.
- [b]Manutenzione[/b]: compaiono nuove tecnologie, arrivano due carte tesoro al mercatino, gli idrovolanti tornano a casa, i gommoni della laguna rientrano in porto.

Ora il secondo quadrimestre. Pensa a un piano: carte tesoro e attrezzature adesso, gommoni in mare il prima possibile, il museo quando arrivano i tesori."""],
	],
	"p4": [
		["Il secondo anno", """Fine del primo anno: l'ordine di turno ha dato reputazione e gli investitori hanno pagato il nuovo reddito, [b]30$ più 5$ per ogni carta tesoro[/b].

Il secondo anno è quello della caccia ai tesori: i gommoni dovrebbero già essere in mare, e i tesori recuperati vanno al museo, meglio nelle sale finanziate da te. La pubblicità rende sempre meno: chi la fa prima prende di più."""],
	],
	"p7": [
		["L'ultimo anno", """Terzo e ultimo anno: il reddito è solo [b]10$ più 5$ per carta[/b]. Ora si raccoglie:
- vendi i tesori al museo e cerca di riempire le sale (le sale aperte valgono di più a fine partita);
- i brevetti e le carte valgono punti, il denaro avanzato 1 punto ogni 10$: non tenere soldi fermi se puoi trasformarli in punti;
- l'ordine di turno finale dà ancora reputazione.
La partita può finire prima del nono quadrimestre, se tutte le sale del museo si aprono."""],
	],
	"fine": [
		["Fine della partita", """Ecco il punteggio finale. Alla reputazione accumulata sul tracciato si aggiungono:
- i [b]tesori[/b]: i punti del posto in una sala aperta, 2 in una sala chiusa o in sede, 1 in deposito;
- i [b]brevetti[/b] (1-3 punti), gli [b]squali[/b] (2 ciascuno), le [b]carte tesoro[/b] (1 ciascuna, +2 per ogni tris);
- il [b]denaro[/b] (1 punto ogni 10$) e l'[b]influenza[/b] finale.

Ora sai giocare a Thesauros. Per ripassare c'è il [b]Manuale[/b] nel menu, con le regole, queste lezioni e i consigli di strategia. Prova una partita normale, magari contro l'IA difficile, oppure la variante «Senza fede né legge» con i mercenari."""],
	],
}

## Manuale di strategia: capitoli [titolo, testo]
const STRATEGY := [
	["Strategia: il piano in tre anni", """[b]Primo anno: le fondamenta.[/b] Le prime carte tesoro sono la scelta più importante: senza carta non si raggiunge nessun sito. Due carte di siti vicini al porto valgono più di una carta di un sito lontano. Insieme, maschera e arpione (o il loro brevetto). Un lavoratore in più assunto presto lavora per otto quadrimestri.

[b]Secondo anno: la caccia.[/b] Gommoni in mare, attrezzati per i siti che conosci. Un secondo gommone raddoppia le immersioni. Il capo o uno specialista 5/7 in mare prende due tesori della stessa colonna.

[b]Terzo anno: il raccolto.[/b] Tesori al museo, sale riempite, denaro trasformato in punti. Le carte e i brevetti contano anche a fine partita."""],
	["Strategia: il denaro", """Il budget è il cuore del gioco. Ogni trasferimento fra conti costa 1, 2 o 3$: se a metà anno sposti soldi tre volte nel terzo anno hai buttato 9$, quasi un punto.

- Calcola gli stipendi per tre quadrimestri e aggiungi l'assunzione che hai in mente.
- Metti in Acquisti generali quello che ti serve per carte, sale e pubblicità; in R&S quello che serve per le attrezzature dell'anno.
- La cassa nera serve solo per le buste (e per i mercenari nella variante): l'offerta che conta davvero è quella del terzo quadrimestre di ogni anno.
- Gli incassi vanno nel conto che hai scelto: mettili dove sai che mancherà qualcosa.
A fine partita ogni 10$ avanzati valgono 1 punto: è il cambio peggiore, meglio spendere bene prima."""],
	["Strategia: il mare", """- Scegli le tessere dei siti con tesori nei primi due livelli: si raggiungono con la sola maschera.
- Un sito scoperto da te è visibile a tutti quelli con la carta: arrivaci per primo.
- Le caselle piccole ospitano un solo gommone: occupare quella sopra la colonna migliore blocca gli altri.
- Gli squali senza arpione chiudono la colonna; con fucile e gabbia (e il capo a bordo) li uccidi sempre, e ogni squalo vale 2 punti.
- Sonar, trapano e martello aprono i tesori più ricchi, che gli altri non possono prendere.
- Un gommone che non ha più niente da recuperare può pescare (2$) o tornare in porto per cambiare attrezzatura."""],
	["Strategia: museo, pubblicità, brevetti", """[b]Museo.[/b] Finanziare una sala costa poco e rende due volte: i punti dell'apertura e i posti migliori per i tuoi tesori. Riempire la sala di un avversario lo premia: preferisci le tue, ma un posto da 4-5 punti in una sala quasi piena vale la pena.

[b]Pubblicità.[/b] Rende di più all'inizio (4 punti) e sempre meno: se vuoi farla, falla presto.

[b]Brevetti.[/b] Un brevetto sviluppato da solo costa poco e vale 1-3 punti più le royalty: i brevetti delle attrezzature che servono a tutti (maschera, arpione, bombola) si ripagano da soli."""],
	["Strategia: la variante dei mercenari", """Nella variante «Senza fede né legge» la cassa nera serve anche per i [b]mercenari[/b], all'asta dopo i quadrimestri 3, 5, 7 e 8: tieni qualche dollaro in più per quei momenti.

- La [b]campagna diffamatoria[/b] (zona 9) toglie 4 punti a tutti gli avversari: in quattro vale 12 punti di distacco.
- Il [b]furto di carte[/b] (zona 3) dà due siti, 10$ di reddito l'anno e i tesori nascosti senza sonar.
- La [b]mina[/b] (zona 7) uccide gli squali e distrugge i tesori: usala sui siti degli avversari.
- Il [b]furto del brevetto[/b] (zona 2) e l'[b]idrovolante nero[/b] (zona 4) rendono per tutta la partita.
Ogni zona può essere colpita una volta sola: chi arriva prima sceglie il colpo migliore."""],
]


# ================================================================ consiglio del tutor
## Descrizione della mossa consigliata (r = decisione dell'IA) e del perché: [mossa, perché].
static func advice(e, p: int, req: Dictionary, r) -> Array:
	var t: String = req["type"]
	if not (r is Dictionary):
		return ["", ""]
	match t:
		"budget":
			return ["RU %d$, R&S %d$, AG %d$, SM %d$, cassa nera %d$" % [r["hr"], r["rd"], r["gp"], r["me"], r["bc"]],
				"Gli stipendi dei tuoi %d lavoratori per tre quadrimestri sono %d$: il conto RU li copre%s. %s La cassa nera serve per l'offerta del terzo quadrimestre, quella che dà reputazione a fine anno; Spese di missione copre motori e attrezzi in mare." % [
					e.workers(p), e.workers(p) * 6, (" con un margine per un'assunzione" if r["hr"] > e.workers(p) * 6 else ""),
					["Il primo anno R&S è alto: servono maschera, arpione e brevetti.", "Il secondo anno si punta sulle carte tesoro e sul museo.", "Nell'ultimo anno quasi tutto va al museo e alla pubblicità."][e.year - 1]]]
		"place", "recruit":
			var m: Dictionary = e.meeple(p, r.get("m", req.get("m", -1)))
			var z := int(r.get("z", 6))
			var who := "il mercenario" if m.get("merc", false) else ("il capo" if m.get("boss", false) else ("lo specialista" if m.get("hat", 0) != 0 else "un lavoratore"))
			var mv := "Manda %s in zona %d (%s)" % [who, z, D.ZONE_NAMES.get(z, "")]
			if r.get("env", false):
				mv += ", con la busta"
			if r.get("dbl", false):
				mv += ", con la doppia azione"
			var why := _zone_why(e, p, z, m)
			if r.get("env", false):
				why += " La busta: " + ("è il terzo quadrimestre dell'anno, l'ordine di turno di adesso dà reputazione." if (e.period - 1) % 3 == 2 else "giocare primi il prossimo quadrimestre permette di prendere le caselle migliori.")
			if r.get("dbl", false):
				why += " La doppia azione raddoppia un'azione che rende bene."
			return [mv, why]
		"z2":
			if r.get("a", "") == "res":
				return ["Prenota la prossima carta", "Nessuna tecnologia visibile vale la spesa: scegliere la prossima ti dà la prima mossa su quella che serve."]
			if r.get("a", "") == "none":
				return ["Nessuna azione", "Non c'è niente che valga il prezzo; costa 1 punto, ma spendere male costa di più."]
			var tk: String = r["t"]
			var names := {"dev": "Sviluppa il brevetto", "buy": "Compra l'oggetto", "combo": "Sviluppa e compra"}
			var why2: String = "%s: %s." % [D.ITEMS[tk]["name"], D.TECHS[tk]["text"]]
			if r["a"] == "dev":
				why2 += " Il brevetto vale %d punti a fine partita e ti fa incassare %d$ di royalty da chi compra l'oggetto." % [D.TECHS[tk]["vp"], D.TECHS[tk]["h"]]
			elif r["a"] == "combo":
				why2 += " Sviluppando e comprando insieme hai subito l'attrezzo e il brevetto da %d punti." % D.TECHS[tk]["vp"]
			else:
				why2 += " Ti serve per i siti che conosci."
			return ["%s: %s" % [names[r["a"]], D.ITEMS[tk]["name"]], why2]
		"z3":
			if r.has("none"):
				return ["Nessuna carta", "Nessuna carta vale il prezzo adesso."]
			var i := int(r["slot"])
			var k: int = e.market[i][e.market[i].size() - 1]
			var cnt: int = e.ps[p]["cards"].count(k)
			var why3 := "La carta %d apre il sito %d" % [k, k]
			if cnt == 0 and e.ps[p]["cards"].size() < 2:
				why3 += ": senza carte non si va per mare, le prime sono le più importanti della partita."
			elif cnt == 2:
				why3 += " e completa un tris: 2 punti in più a fine partita."
			else:
				why3 += " e vale 5$ di reddito negli anni seguenti e 1 punto a fine partita."
			return ["Compra la carta %d (%d$)" % [k, req["slots"][i]], why3]
		"dig":
			return ["Tieni la tessera %d" % (int(r["i"]) + 1), "È quella con più valore nei primi livelli, raggiungibili con meno attrezzatura e meno squali in superficie."]
		"sat", "merc3":
			return ["Prendi le carte %s" % ", ".join(r.get("nums", []).map(func(x): return str(x))), "Completano gruppi che hai già o aprono i siti più ricchi."]
		"plane":
			if r.get("none", false):
				return ["Non usare l'idrovolante", "In magazzino non c'è niente che cambi davvero le immersioni di questo quadrimestre."]
			return ["Usa l'idrovolante per il gommone %s" % e.zod(int(r["zod"]))["color"], "Porta a bordo l'attrezzatura del magazzino" + (" e scambia il pilota con l'equipaggio, per avere un esperto in mare." if r.get("swap", false) else ".")]
		"sea":
			var dest: String = r.get("dest", "")
			var z0: Dictionary = e.zod(req["zod"])
			if dest == z0["loc"]:
				return ["Resta qui", "Da qui c'è ancora qualcosa da recuperare."]
			return ["Vai verso %s%s" % [e.node_name(dest), " (prima immergiti qui)" if r.get("dive_first", false) else ""],
				("Da lì puoi immergerti su un tesoro raggiungibile con la tua attrezzatura." if dest.begins_with("D") else
				("Nell'area di pesca guadagni 2$ con la lenza mentre ti avvicini al sito." if dest.begins_with("F") else
				("In porto cambi attrezzatura senza idrovolante." if dest == "PORT" else "È la strada più breve verso il sito migliore che conosci.")))]
		"dive":
			var rows: Array = r.get("take", [])
			if rows.is_empty():
				return ["Non recuperare nulla", "I tesori raggiungibili costano più di quanto valgono."]
			var parts := []
			for tt in req["targets"]:
				if tt["r"] in rows:
					parts.append("%s (%d$) al livello %d" % [D.TREASURE_NAMES[tt["v"]], tt["v"], tt["r"] + 1])
			return ["Recupera: " + ", ".join(parts), "È il tesoro di valore più alto fra quelli raggiungibili, contando il costo d'uso degli attrezzi."]
		"z7":
			match r.get("a", ""):
				"shop": return ["Compra un gommone", "Un gommone in più vuol dire un'immersione in più a ogni quadrimestre, e 1 punto subito."]
				"lagoon": return ["Laguna: %s" % D.LAGOON[r["spot"]]["name"], "Un guadagno sicuro in questo quadrimestre, e il gommone torna in porto per la prossima uscita."]
				"sea": return ["Prendi il largo", "In mare il gommone si immergerà a ogni quadrimestre: prima si parte, più tesori si recuperano."]
			return ["Nessuna azione", ""]
		"island":
			return ["Tieni l'oggetto che vale di più", "Gli attrezzi migliorati e i tesori valgono più delle monete."]
		"z8":
			if r.get("a", "") == "sponsor":
				var cfg: Dictionary = e.rooms[int(r["room"])]["cfg"]
				return ["Finanzia la sala %d" % (int(r["room"]) + 1), "Quando si riempie guadagni %d punti, e i suoi posti (%s punti) sono i migliori per i tuoi tesori." % [cfg["rp"], "/".join(cfg["vp"].map(func(x): return str(x)))]]
			if r.get("a", "") == "sell":
				var rr := int(r["room"])
				if rr < 0:
					return ["Vendi il tesoro e mettilo in deposito", "Incassi il valore del tesoro; in deposito vale 1 punto, ma non c'è un posto migliore libero."]
				var k8: int = e.room_free_slot(rr)
				return ["Vendi il tesoro di %s nella sala %d" % [D.TREASURE_NAMES[int(r["v"])], rr + 1], "Incassi %d$ e il posto vale %d punti a fine partita se la sala apre al pubblico." % [int(r["v"]), e.rooms[rr]["cfg"]["vp"][k8]]]
			return ["Nessuna azione", ""]
		"bid":
			return ["Offri %d$" % int(r["bid"]), ("È il terzo quadrimestre dell'anno: l'ordine di turno di adesso dà reputazione, vale la pena spendere la cassa nera." if (e.period - 1) % 3 == 2 else "Un'offerta piccola: l'ordine conta di più a fine anno.")]
		"reserve":
			return ["Scegli: %s" % D.ITEMS[r["t"]]["name"], "È la tecnologia che ti serve di più adesso."]
		"merc_bid":
			return ["Offri %d$" % int(r["bid"]) if int(r["bid"]) > 0 else "Passa", "Il tutor stima quanto rende il miglior colpo possibile di un mercenario e non va oltre."]
		"merc2":
			return ["Ruba il brevetto: %s" % D.ITEMS[r["t"]]["name"], "Vale più punti a fine partita e toglie royalty a chi lo possedeva."]
		"merc8":
			return ["Muovi i tesori del museo" if r.get("a", "none") != "none" else "Nessuna mossa", "La mossa che migliora di più il tuo distacco a fine partita."]
		"mine":
			return ["Fai esplodere la mina nel sito %d" % int(r["site"]) if r.has("site") else "Tieni la mina", "Conta gli squali uccisi (2 punti l'uno) e i tesori tolti agli avversari, meno quelli che perderesti tu."]
	return ["", ""]


static func _zone_why(e, p: int, z: int, m: Dictionary) -> String:
	match z:
		1: return "Un lavoratore in più è un'azione in più a ogni quadrimestre: assunto presto si ripaga."
		2:
			return "In ricerca e sviluppo c'è un'attrezzatura o un brevetto che vale il prezzo%s." % (" (il capo o lo specialista paga 2$ in meno)" if m.get("boss", false) or m.get("hat", 0) == 2 else "")
		3:
			if e.ps[p]["cards"].is_empty():
				return "Senza carte tesoro nessun sito è raggiungibile: la prima carta è la mossa più importante."
			return "Un'altra carta tesoro apre un sito in più, dà 5$ di reddito l'anno e 1 punto."
		4: return "L'idrovolante porta in mare l'attrezzatura che serve ai tuoi gommoni."
		6: return "Non c'è un'azione migliore che valga il costo: le cozze danno un piccolo guadagno sicuro, meglio di un meeple che non agisce."
		7:
			if not e.port_free_zods(p).is_empty() and not e.ps[p]["cards"].is_empty():
				return "Hai un gommone libero in porto e almeno una carta: è ora di prendere il largo (o di guadagnare in laguna)."
			return "Al porto c'è un guadagno sicuro in laguna o un gommone da comprare."
		8:
			if not e.ps[p]["treasures"].is_empty():
				return "Hai tesori in sede: venderli al museo li trasforma in denaro e in punti."
			return "Finanziare adesso una sala del museo ti darà punti quando si riempirà e i posti migliori per i tuoi tesori."
		9: return "La pubblicità dà %d punti subito: rende di più finché il cubetto è a sinistra." % D.Z9_REP[e.z9_idx]
	return ""


## Chiavi delle lezioni da mostrare per una decisione.
static func keys_for(e, req: Dictionary, seen: Dictionary) -> Array:
	var out := []
	if not seen.has("intro"):
		out.append("intro")
	if req["type"] == "place":
		for k in [2, 4, 7]:
			if e.period == k:
				out.append("p%d" % k)
	if req["type"] == "sea":
		out.append("sea")
	out.append(req["type"])
	var res := []
	for k in out:
		if LESSONS.has(k) and not seen.has(k) and not (k in res):
			res.append(k)
	return res
