# Thesauros — versione digitale

Versione digitale di **Thesauros** (Cédric Millet, Super Meeple, 2025): ogni giocatore guida un'agenzia di
recupero di relitti e in tre anni cerca di farsi la reputazione migliore con i tesori sommersi.

Si gioca qui: https://tannoiser2.github.io/Thesauros/

## Cosa c'è

- Regole complete del gioco base da 1 a 4 compagnie: reddito, budget su cinque conti con le tasse dei
  trasferimenti, piazzamento con capo, lavoratori, specialisti e doppia azione, le dieci zone (reclutamento,
  ricerca e sviluppo con brevetti e royalty, mercatino con domanda e offerta, idrovolanti, alto mare con
  movimento, squali, sonar e rocce, cozze, porto e laguna con l'isola, museo, pubblicità, buste per le
  autorità), stipendi, manutenzione, punteggio di fine anno e finale.
- Modo **Iniziazione**, **solitario** ufficiale (obiettivo museo pieno e più di 80 punti, con i bonus) e la
  variante **«Senza fede né legge»** con i mercenari: aste con la cassa nera dopo i quadrimestri 3, 5, 7 e 8,
  colpi per zona (doppie azioni, brevetti, carte del mercenario, idrovolante nero, mina subacquea, museo,
  campagna diffamatoria).
- **IA** in tre livelli per i posti vuoti: pesi tarati con migliaia di partite simulate (`tests/tara.py`);
  la difficile guarda avanti di una mossa nelle scelte del museo e dei mercenari.
- **Tutorial**: partita guidata (Iniziazione, contro due IA facili) con lezioni che si aprono al momento giusto,
  il **consiglio del tutor** con il perché e «Segui il consiglio»; il tutor si può accendere anche nelle partite
  normali (pulsante «Tutor»). Il **manuale** raccoglie regole, tecnologie, strategia e lezioni.
- **Online** con gli amici (stanze con codice di 4 lettere, chi esce può rientrare; se uno sparisce gioca l'IA).
- **Partite salvate** su Firebase: «Salva» dà un codice di 6 lettere da usare in «Carica partita», da
  qualsiasi dispositivo.
- Tabellone originale in **2D** (trascinare, pizzicare e ruotare con due dita anche su iPad) e vista **3D**
  con i modelli del modulo per gommoni, idrovolanti, capi e lavoratori.
- Tutto in italiano: interfaccia, diario, regole e carte tecnologia descritte.

## Materiale

Dal modulo di Tabletop Simulator in `Desktop/Ludoteca/Thesauros` (file `.ttsmod`, che è uno zip).
`tools/estrai_materiale.py <cartella Mods> .` ritaglia tabelloni, carte, oggetti, tesori e gommoni e
copia i modelli 3D. Le tessere dei siti di scavo sono trascritte in `data/siti.json` e ridisegnate dallo
script con le icone originali (il foglio delle tessere grandi del modulo è a bassa risoluzione).

## Struttura

- `scripts/core/engine.gd` — il motore delle regole (senza grafica); ogni scelta passa da `decide()`.
- `scripts/core/ai.gd` — l'IA.
- `scripts/data/th_data.gd` — tecnologie, costi e coordinate dei due lati del tabellone.
- `scripts/ui/` — menu, schermata di gioco, tabellone 2D e 3D, regole.
- `scripts/net/` — Firebase (stanze `thesauros/rooms`, partite salvate `thesauros/partite`).

## Prove

```
godot --headless --path . -s tests/check.gd                 # compila tutti gli script
godot --headless --path . -s tests/sim.gd -- 4 10 -1 2      # partite fra IA (giocatori, partite, livello -1 = misti, modo 2 = variante)
xvfb-run godot --path . -s tests/shot_tut.gd -- /tmp/tut     # tutorial giocato tutto seguendo il tutor
python3 tools/controlla_glifi.py                            # ogni carattere esiste nei font
xvfb-run godot --path . -s tests/shot.gd -- /tmp/foto 3     # fotografie dell'interfaccia
python3 tests/firebase_mock.py 8765                         # finto Firebase per online_play.gd e save_load.gd
```

## Pubblicazione

Il workflow `Pubblica` parte a mano (Actions → Pubblica → Run workflow) oppure con un commit che contiene
`[pubblica]` nel messaggio; costruisce la versione web con Godot 4.7 e la mette su GitHub Pages (e sulla
ludoteca privata di Cloudflare, se ci sono i segreti).
