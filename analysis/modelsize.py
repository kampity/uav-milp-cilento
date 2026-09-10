#!/usr/bin/env python3
"""Проверка априорной оценки размера модели (§5.14) по измеренным данным
эксперимента масштабируемости."""

# --- repo-relative paths (added for public release) ---
from pathlib import Path as _Path
ROOT = _Path(__file__).resolve().parents[1]
RESULTS = ROOT / 'results'
FIGURES = ROOT / 'figures'
FIGURES.mkdir(exist_ok=True)
BASE = str(RESULTS) + '/'
# ------------------------------------------------------

import csv, numpy as np, matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
plt.rcParams['font.family'] = 'DejaVu Sans'; plt.rcParams['font.size'] = 8.5

K, H, R, Sp = 4, 5, 3, 2          # флот, уровни скорости, копии C1, зарядные копии

rows = []
with open(str(RESULTS / 'scalability_final.csv')) as f:
    for d in csv.DictReader(f):
        rows.append({k: d[k] for k in d})

print(f"{'|F|':>4} {'|N|':>4} {'|N^o|':>6} {'|A|':>5} "
      f"{'бинарных изм.':>13} {'бинарных расч.':>14} {'совпад.':>8} {'огранич.':>9}")
FF, meas, pred = [], [], []
for r in rows:
    nF = int(r['nF']); nN = int(r['nN']); A = int(r['arcs']); bins = int(r['bins'])
    No = nN - 2
    calc = 3*K + A*K + No*K + A*K*H + Sp
    FF.append(nF); meas.append(bins); pred.append(calc)
    print(f"{nF:4d} {nN:4d} {No:6d} {A:5d} {bins:13d} {calc:14d} "
          f"{'да' if calc == bins else 'НЕТ':>8} {int(r['cons']):9d}")

print(f"\nсовпадений: {sum(m == p for m, p in zip(meas, pred))} из {len(meas)}")

# проверка структуры |N|
print(f"\n|N| = 2 + |F| + R + |S'| при R = {R}, |S'| = {Sp}:")
for r in rows:
    nF = int(r['nF']); nN = int(r['nN'])
    print(f"  |F|={nF:2d}: расчёт {2+nF+R+Sp:3d}, измерено {nN:3d}  "
          f"{'ok' if 2+nF+R+Sp == nN else 'РАСХОЖДЕНИЕ'}")

# плотность дуг
print("\nплотность множества дуг (|A| против плотной верхней оценки |N|(|N|-1)):")
for r in rows:
    nN = int(r['nN']); A = int(r['arcs'])
    print(f"  |N|={nN:2d}: |A|={A:4d}, плотно {nN*(nN-1):4d}, доля {100*A/(nN*(nN-1)):5.1f} %")

# показатель роста
lf, lb = np.log(np.array(FF, float)), np.log(np.array(meas, float))
sl = np.polyfit(lf, lb, 1)[0]
print(f"\nэмпирический показатель роста числа бинарных переменных по |F|: {sl:.2f}")
lN = np.log(np.array([int(r['nN']) for r in rows], float))
print(f"тот же показатель по |N|: {np.polyfit(lN, lb, 1)[0]:.2f}  (теоретический: 2)")

# ---- априорная оценка §5.14 для гипотетической конфигурации ----
print("\n=== априорная оценка для конфигураций")
for (n, Rr, Sq, Kk) in ((10, 12, 6, 6), (10, 4, 6, 6), (3, 3, 2, 4), (10, 3, 2, 4)):
    N = 2 + n + Rr + Sq
    Adense = N*(N-1)
    z = Adense*Kk*H
    print(f"  |F|={n:2d}, R={Rr:2d}, |S'|={Sq}, |K|={Kk}: |N|={N:2d}, "
          f"|A|<={Adense:4d}, z<={z:6d}")

# ---- рисунок ----
fig, (a1, a2) = plt.subplots(1, 2, figsize=(7.4, 3.0))
a1.plot(FF, meas, 'o-', color='#b2182b', lw=1.5, ms=6, label='измерено (Gurobi)')
a1.plot(FF, pred, 's--', color='#2166ac', lw=1.2, ms=5, mfc='none',
        label='априорная оценка (5.62)')
a1.set_xlabel('$|F|$ — число исторических точек')
a1.set_ylabel('число бинарных переменных')
a1.grid(alpha=.2, lw=.5); a1.legend(fontsize=7.5)
a1.set_title('число бинарных переменных', fontsize=8.5)

comp = {'$z_{ijhk}$ (скорость)': [int(r['arcs'])*K*H for r in rows],
        '$x_{ijk}$ (маршрут)':   [int(r['arcs'])*K for r in rows],
        '$r_{ik}$ (назначение)': [(int(r['nN'])-2)*K for r in rows],
        'прочие':                [3*K + Sp]*len(rows)}
bot = np.zeros(len(rows))
colz = ['#2166ac', '#4393c3', '#92c5de', '#d9d9d9']
for (lb_, vals), c in zip(comp.items(), colz):
    a2.bar(range(len(rows)), vals, bottom=bot, color=c, edgecolor='k',
           lw=.4, label=lb_, width=.7)
    bot += np.array(vals, float)
a2.set_xticks(range(len(rows))); a2.set_xticklabels([str(f) for f in FF])
a2.set_xlabel('$|F|$'); a2.set_ylabel('число бинарных переменных')
a2.legend(fontsize=7, loc='upper left'); a2.grid(axis='y', alpha=.2, lw=.5)
a2.set_title('структура: чем задача набирает размер', fontsize=8.5)
plt.tight_layout(); plt.savefig(str(FIGURES / 'fig_modelsize.pdf'), bbox_inches='tight')
plt.savefig(str(FIGURES / str(FIGURES / 'fig_modelsize.png')), dpi=150, bbox_inches='tight')

print("\nдоля скоростных переменных в общем числе бинарных:")
for r, m in zip(rows, meas):
    print(f"  |F|={int(r['nF']):2d}: {100*int(r['arcs'])*K*H/m:5.1f} %")
