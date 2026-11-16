#!/usr/bin/env python3
"""Prepara il materiale grafico di Thesauros a partire dal modulo Tabletop Simulator.

Uso: python3 tools/estrai_materiale.py <cartella Mods del modulo estratto> [cartella del progetto]

Il modulo (file .ttsmod in Desktop/Ludoteca/Thesauros) è un archivio zip: estratto, contiene
Mods/Images, Mods/Models e Mods/Assetbundles. Le immagini hanno per nome l'indirizzo d'origine;
qui si riconoscono dalla parte finale (l'impronta del file su Steam).

Le tessere «sito di scavo» non si ritagliano dal foglio del modulo (quello delle tessere grandi è
a bassa risoluzione): si ridisegnano a partire da data/siti.json con le icone originali, così il
disegno corrisponde sempre ai dati usati dal motore delle regole.
"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

MODS = sys.argv[1] if len(sys.argv) > 1 else 'mod/Mods'
R = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), '..')
IMG = os.path.join(MODS, 'Images')
OUT = os.path.join(R, 'assets')
_files = os.listdir(IMG)


def img(key):
    for f in _files:
        if key in f:
            return Image.open(os.path.join(IMG, f))
    raise SystemExit('immagine non trovata: ' + key)


def save(im, rel, q=88):
    p = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    if rel.endswith('.jpg'):
        im.convert('RGB').save(p, quality=q, optimize=True)
    else:
        im.save(p, optimize=True)


def fit(im, w):
    if im.size[0] <= w:
        return im
    return im.resize((w, round(im.size[1] * w / im.size[0])), Image.LANCZOS)


def upscale(im, k):
    return im.resize((im.size[0] * k, im.size[1] * k), Image.LANCZOS).filter(ImageFilter.UnsharpMask(1.2, 60, 2))


# ------------------------------------------------------------------ tabelloni e plance
# I lati del tabellone sono 3484x5137: si portano a 2717 di larghezza perché la versione web
# (WebGL, anche su iPad) accetta trame fino a 4096 pixel. Le coordinate del gioco restano quelle
# dell'originale e si scalano nel codice.
for side, key in (('34', '96B8043E3C142773E89BA5E57914BE'), ('12', '98960BCC0CB8310F9B54239B2DEBD7')):
    b = img(key).convert('RGB')
    save(b.resize((2717, 4006), Image.LANCZOS), f'tabellone/tabellone_{side}.jpg', 86)
save(fit(img('A69C141D01C99BF0AD75B7F05903CA').convert('RGB'), 1800), 'plancia/plancia.jpg', 86)
save(fit(img('D48FFEAB718D21DB4AD73009A37591').convert('RGB'), 900), 'misc/copertina.jpg', 90)
save(fit(img('httpsiimgurcomeHXDjyy'), 2200).convert('RGB'), 'misc/tavolo.jpg', 80)

# ------------------------------------------------------------------ carte tecnologia (foglio 4x4)
TECH = ['bombola', 'arpione', 'mot_medio', 'gabbia', 'sonar', 'maschera', 'trapano', 'scafandro',
        'mot_super', 'sonar_av', 'fucile', 'nassa', 'martello', 'satellite', 'mot_piccolo']
sheet = img('8CA5DD053F4A4C79D10E27A6356C83').convert('RGB')
cw, ch = sheet.size[0] / 4, sheet.size[1] / 4
for i, t in enumerate(TECH):
    c, r = i % 4, i // 4
    card = sheet.crop((round(c * cw), round(r * ch), round((c + 1) * cw), round((r + 1) * ch)))
    save(upscale(card, 2), f'tecnologie/{t}.jpg', 90)
save(upscale(img('F526DBF12A86E0105B3EAE69C85737255BB24E4').convert('RGB'), 2), 'tecnologie/retro.jpg', 90)

# ------------------------------------------------------------------ oggetti, tesori, segnalini
ITEMS = {'maschera': '3C745115F7AC22B8E12B6A1D5FF871', 'scafandro': '999799FD1CF4E0A9D5F523F8BD1C0C', 'bombola': '1ECA4E36044325A926C5D4759CD3A1', 'mot_super': '0625DB063ECA847A7D87B8343C534D', 'mot_piccolo': '2164C896CE546E8DDC5EC088AA6F84', 'mot_medio': '125490195B12B17AB94546D9C5E0F7', 'arpione': '721E0ACE841B638D000D7505FF08C2', 'fucile': 'E4041EAE268C9BA76AB11AC7B0B4FF', 'trapano': '26A2BD751AAB7B8CE3928DEF5B427F', 'martello': '9B0CE8F5B726A2FDAFD9218A9EE5E2', 'gabbia': '1B312FE7FDFAB7E034FB8D718F57E3', 'nassa': '85E7D1868264AA03A3052F32497FD9', 'sonar': 'C42701B9A5B723832CA032F23B57EF', 'sonar_av': 'B80BEB81FF8F0ABB6DA5D5B65EBFF1', 'satellite': 'CAA081E063F9242E874EE9963CAB5E', 'metal': 'EDCB8C2E4ABF99373CFDC95D4F0649', 'mot_isola': 'E271E19F369E327D1B225789BB8776', 'fucile_plus': '86476F2C47212106DAB9BBFC757CBF', 'sonar_plus': 'AD241C26B8EB8D76085A697D44B727'}
for k, key in ITEMS.items():
    save(img(key).convert('RGBA'), f'oggetti/{k}.png')
ISLAND = {'moneta': '2F52DB0CD304B96EDA74F8FC366FD8', 'collana': '7CF7CCA1B24BA0D51B58C5AEA8A5F3', 'orologio': '3A6F86DEC611F78B24F0836BA8FAB3', 'bracciale': '4660A64A8E3679A536FF6498E52519', 'isola_t3': '80C3E46D0D15172F8DAC3BB81F4D34', 'isola_t5': '3800DC2A0AAAFA4BD2C4ED8F921BCA', 'isola_retro': '489FB0415BE8589A8C83A279CC4FED'}
for k, key in ISLAND.items():
    save(img(key).convert('RGBA'), f'isola/{k}.png')
CHESTS = {3: '1025FA92A868F15C312383AE22F058', 5: '9BEA01647BE7969742924F4F69DFE3', 7: '0DC2DEF908C287DAA1A34E52EEFA35', 9: '9139F617AB1F14BFBE78E8B513BF9A'}
for v, key in CHESTS.items():
    save(img(key).convert('RGBA'), f'tesori/tesoro_{v}.png')
save(img('A44A1A271CFDC21CA33642519189A1').convert('RGBA'), 'tesori/squalo.png')
save(img('3C1264DA9C36F3B4A5CA771BC0B4FE').convert('RGBA'), 'tesori/copertura.png')
save(img('6D00AB37625C5ACAB430AAB76CF49ECA09B04C7').convert('RGBA'), 'segnalini/doppia.png')
SAT = ['48F66F89D8995B679E09E1862FD2EA', '101AB16F5C1326F9D72D3AEB0AAFB1', '054A8D2D9C7BE9F08E5FC1A90B11E1', 'F6B9F95233AD9F8F05564216AD29F2', '10CCACCDEBEDE8FD95986F7FECD5DF', '8F592FE1BD8B8E8A3FF1324FD58069', 'B3BA9A70D0506B10FBDB81CD7646A8']
for i, key in enumerate(SAT):
    save(img(key).convert('RGBA'), f'carte/satellite_{i + 1}.png')
# buste e gommoni nei colori
for col, key in (('verde', '6E6B521FA85CF3D5D05FFF2A8CABDB'), ('bianco', 'A0DD215915615180C366586FC1996E'),
                 ('rosso', '43F78D2EB09770BE673334EB96F648'), ('blu', '01FB1EFA508C88CF2A35FAA4D5A73E')):
    try:
        save(fit(img(key).convert('RGBA'), 256), f'segnalini/busta_{col}.png')
    except SystemExit:
        pass
ZOD = {'bianco': 'CE2FF1D9554B2F65EE3DD9AF618DED', 'rosso': 'E8CDEC0ABE12A9FEC87C17AC7C3B54',
       'marrone': 'F152B4689705518267EE0EDA0D44A3', 'rosa': 'C2C701EF8CBDAE09803B675FB4AAF1',
       'verde': 'B97571CC10778DA9A7137D5FBABCF1', 'lime': 'FAA32308FDDD4064BD647AB65EA36F',
       'blu': '27F18A8372A6C5DC3CF9F2FCBBA3AE', 'giallo': '94C9D542308ED837709A6939ACEC41'}
for col, key in ZOD.items():
    save(fit(img(key).convert('RGBA'), 360), f'gommoni/{col}.png')

# ------------------------------------------------------------------ carte tesoro (numeri 1-7)
# Le tessere del modulo sono minuscole (65 px): si usa lo sfondo di pergamena della «1» (206 px)
# e si scrive il numero con il carattere del gioco.
base = img('C5DDEC85FF3961DCB6BECC00C62ED5').convert('RGBA')
fpath = os.path.join(R, 'assets/fonts/Cinzel.ttf')
for n in range(1, 8):
    c = base.copy()
    d = ImageDraw.Draw(c)
    cx, cy, rr = c.size[0] / 2, c.size[1] / 2, 68
    d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=(58, 36, 18, 235), outline=(214, 170, 90, 255), width=6)
    f = ImageFont.truetype(fpath, 118)
    f.set_variation_by_axes([900])
    bb = d.textbbox((0, 0), str(n), font=f)
    d.text((cx - (bb[0] + bb[2]) / 2, cy - (bb[1] + bb[3]) / 2), str(n), font=f, fill=(250, 226, 160, 255))
    save(c, f'carte/carta_{n}.png')

# ------------------------------------------------------------------ tessere sito di scavo
small = img('202540E0490C60541E3F0457BF080D').convert('RGBA')   # foglio delle piccole: icone di squali e sonar
sw, sh = small.size[0] / 2, small.size[1] / 5
cell_w, cell_h = sw / 4, sh / 3


def cell_of(tile, col, row, inset=0.12):
    tc, tr = tile % 2, tile // 2
    x0 = tc * sw + col * cell_w
    y0 = tr * sh + row * cell_h
    return small.crop((round(x0 + cell_w * inset), round(y0 + cell_h * inset), round(x0 + cell_w * (1 - inset)), round(y0 + cell_h * (1 - inset))))


def cutout(im):
    """toglie lo sfondo d'acqua tenendo l'icona (pixel lontani dal colore medio dei bordi)"""
    im = im.convert('RGBA')
    px = im.load()
    w, h = im.size
    border = [px[x, 0] for x in range(w)] + [px[x, h - 1] for x in range(w)]
    br = sum(p[0] for p in border) / len(border)
    bg = sum(p[1] for p in border) / len(border)
    bb = sum(p[2] for p in border) / len(border)
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            dist = abs(r - br) + abs(g - bg) + abs(b - bb)
            px[x, y] = (r, g, b, 0 if dist < 70 else (255 if dist > 120 else int((dist - 70) * 5)))
    return im


ICON = {
    'S1': cutout(cell_of(1, 1, 0, 0.02)),   # squalo di profilo (piccola 2, prima riga)
    'S2': cutout(cell_of(1, 3, 0, 0.02)),   # squalo di fronte
}
# sonar colorati: piccola 1 (nero, arancio), piccola 9 (bianco), grande (giallo) da disegno proprio
ICON['N3'] = cutout(cell_of(0, 2, 0))
ICON['N5'] = cutout(cell_of(0, 3, 0))
ICON['N7'] = cutout(cell_of(2, 2, 2))


def sonar_icon(col):
    im = Image.new('RGBA', (120, 120), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((44, 20, 76, 52), fill=col)
    for k, r in enumerate((26, 38, 50)):
        d.arc((60 - r, 70 - r * 0.45, 60 + r, 70 + r * 0.45), 0, 180, fill=col, width=7)
    return im


SONAR = {3: (20, 20, 25, 255), 5: (230, 150, 90, 255), 7: (235, 240, 245, 255), 9: (245, 205, 40, 255)}
chests = {v: Image.open(os.path.join(OUT, f'tesori/tesoro_{v}.png')).convert('RGBA') for v in CHESTS}
shark_imgs = [ICON['S1'], ICON['S2']]


def chest_only(v):
    """il forziere senza il riquadro azzurro della tessera"""
    c = chests[v].copy()
    w, h = c.size
    inner = c.crop((int(w * 0.12), int(h * 0.16), int(w * 0.88), int(h * 0.84)))
    return cutout(inner)


CHEST_ONLY = {v: chest_only(v) for v in CHESTS}


def render_tile(grid, cw=120, chh=96):
    rows, cols = len(grid), len(grid[0])
    W, H = cols * cw, rows * chh
    im = Image.new('RGBA', (W, H))
    d = ImageDraw.Draw(im)
    water = [(178, 222, 236), (120, 190, 222), (70, 140, 190), (40, 100, 150)]
    rock = (92, 64, 48)
    for r in range(rows):
        for c in range(cols):
            x0, y0 = c * cw, r * chh
            v = grid[r][c]
            solid = v == 'R' or v.startswith('I')
            d.rectangle((x0, y0, x0 + cw, y0 + chh), fill=rock if solid else water[r])
            if solid:
                for k in range(5):
                    xx = x0 + (k * 37 + r * 13 + c * 29) % cw
                    yy = y0 + (k * 23 + c * 17) % chh
                    d.ellipse((xx, yy, xx + 9, yy + 5), fill=(110, 80, 60))
            else:
                # fondale sotto un tesoro appoggiato o sopra la roccia
                below = grid[r + 1][c] if r + 1 < rows else 'R'
                if below == 'R' or below.startswith('I') or r + 1 == rows:
                    d.rectangle((x0, y0 + chh - 14, x0 + cw, y0 + chh), fill=rock)
            if v.startswith('T') or v.startswith('I'):
                ic = CHEST_ONLY[int(v[1:])].copy()
                ic.thumbnail((int(cw * 0.72), int(chh * 0.78)))
                if v.startswith('I'):
                    ic = ic.rotate(-18, expand=True, resample=Image.BICUBIC)
                    halo = Image.new('RGBA', (ic.size[0] + 10, ic.size[1] + 10), (0, 0, 0, 0))
                    m = ic.split()[3].filter(ImageFilter.MaxFilter(9))
                    halo.paste((20, 12, 8, 255), (0, 0), m.resize(halo.size))
                    im.alpha_composite(halo, (x0 + (cw - halo.size[0]) // 2, y0 + (chh - halo.size[1]) // 2))
                im.alpha_composite(ic, (x0 + (cw - ic.size[0]) // 2, y0 + (chh - ic.size[1]) // 2))
            elif v == 'S':
                ic = shark_imgs[(r + c) % 2].copy()
                ic.thumbnail((int(cw * 0.95), int(chh * 0.95)))
                im.alpha_composite(ic, (x0 + (cw - ic.size[0]) // 2, y0 + (chh - ic.size[1]) // 2))
            elif v.startswith('N'):
                ic = sonar_icon(SONAR[int(v[1:])])
                ic.thumbnail((int(cw * 0.6), int(chh * 0.7)))
                im.alpha_composite(ic, (x0 + (cw - ic.size[0]) // 2, y0 + (chh - ic.size[1]) // 2 - 4))
    for c in range(1, cols):
        d.line((c * cw, 0, c * cw, H), fill=(110, 160, 210), width=3)
    for r in range(1, rows):
        d.line((0, r * chh, W, r * chh), fill=(110, 160, 210), width=3)
    d.rectangle((0, 0, W - 1, H - 1), outline=(60, 110, 160), width=4)
    return im


siti = json.load(open(os.path.join(R, 'data/siti.json')))
for kind in ('piccole', 'grandi'):
    for i, g in enumerate(siti[kind]):
        save(render_tile(g), f'siti/{kind}_{i}.png')
retro = Image.new('RGBA', (600, 384), (34, 82, 110, 255))
d = ImageDraw.Draw(retro)
for k in range(0, 600, 40):
    d.line((k, 0, k - 200, 384), fill=(44, 98, 128, 255), width=12)
save(retro, 'siti/retro.png')

# ------------------------------------------------------------------ modelli 3D
MOD = os.path.join(MODS, 'Models')
MODELS = {'gommone': 'CCE65289BD18AB11432', 'idrovolante': '583261CF51E0DFF5A62', 'lavoratore': 'D33D16F5BBE2',
          'capo': 'C9CD2DC6841E132F352', 'cappello': 'DA287F34EA7B5ECB252'}
os.makedirs(os.path.join(OUT, 'modelli'), exist_ok=True)
for k, key in MODELS.items():
    for f in os.listdir(MOD):
        if f.replace('.obj', '').endswith(key.upper()) or key.upper() in f.upper():
            src = open(os.path.join(MOD, f), errors='ignore').read()
            # niente materiali esterni: Godot importa la sola geometria
            src = '\n'.join(l for l in src.splitlines() if not l.startswith(('mtllib', 'usemtl')))
            open(os.path.join(OUT, 'modelli', k + '.obj'), 'w').write(src)
            break
print('materiale pronto in', OUT)
