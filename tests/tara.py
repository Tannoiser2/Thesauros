#!/usr/bin/env python3
"""Taratura dei pesi dell'IA per salita: per ogni peso prova ×1.35 e ×0.7 contro i pesi attuali;
tiene la modifica se migliora il margine medio. Le partite girano in parallelo su più processi.
Uso: python3 tests/tara.py <giri> <partite per prova>"""
import json, os, subprocess, sys, re, random
from concurrent.futures import ThreadPoolExecutor
G = os.environ.get('GODOT', '/home/claude/Godot_v4.7-stable_linux.x86_64')
R = os.path.join(os.path.dirname(__file__), '..')
src = open(os.path.join(R, 'scripts/core/ai.gd')).read()
tuned = dict(re.findall(r'"(\w+)": ([\d.]+)', src[src.index('const TUNED'):src.index('var level')]))
tuned = {k: float(v) for k, v in tuned.items()}
rounds = int(sys.argv[1]) if len(sys.argv) > 1 else 1
games = int(sys.argv[2]) if len(sys.argv) > 2 else 40
CHUNK = 10

def run(w, seed, n, np, var):
    out = subprocess.run([G, '--headless', '--path', R, '-s', 'tests/tara_ia.gd', '--', json.dumps(w), str(n), str(seed), str(np), '1' if var else '0'],
                         capture_output=True, text=True, timeout=600).stdout
    m = re.search(r'RISULTATO ([-\d.]+) ([-\d.]+)', out)
    return float(m.group(1)) if m else -99.0

def evaluate(w, seed0):
    jobs = []
    with ThreadPoolExecutor(max_workers=os.cpu_count()) as ex:
        for i in range(games // CHUNK):
            np = [2, 3, 4][i % 3]
            jobs.append(ex.submit(run, w, seed0 + i * 1000, CHUNK, np, i % 4 == 3))
        return sum(j.result() for j in jobs) / len(jobs)

STATE = '/tmp/tara_stato.json'
cur = json.load(open(STATE)) if os.path.exists(STATE) else dict(tuned)
keys = os.environ.get('CHIAVI', '').split(',') if os.environ.get('CHIAVI') else list(cur.keys())
random.seed(7)
for r in range(rounds):
    random.shuffle(keys)
    for k in keys:
        seed = random.randint(1, 10**6)
        best = None
        for f in (1.35, 0.7):
            w = dict(cur); w[k] = round(cur[k] * f, 3)
            # confronto con i pesi correnti (che sono quelli di riferimento nel file solo al primo giro)
            diff = {kk: vv for kk, vv in w.items() if tuned.get(kk) != vv}
            base_diff = {kk: vv for kk, vv in cur.items() if tuned.get(kk) != vv}
            v = evaluate(diff, seed) - evaluate(base_diff, seed)
            print(f'{k} x{f}: {v:+.2f}', flush=True)
            if v > 0.8 and (best is None or v > best[0]):
                best = (v, w[k])
        if best:
            cur[k] = best[1]
            print(f'  -> {k} = {best[1]}', flush=True)
        json.dump(cur, open(STATE, 'w'))
    print('GIRO', r, json.dumps(cur), flush=True)
json.dump(cur, open('/tmp/tuned.json', 'w'))
