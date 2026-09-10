#!/usr/bin/env python3
"""Рис. 9.1 — что определяет выполнимость и размер флота (синтез главы 8)."""

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


base_f3 = 426.9334437404257

sm = list(csv.DictReader(open(BASE+'sensitivity_matlab.csv')))
sw = {}
for r in sm:
    sw.setdefault(r['sweep'], []).append(r)

names = {'A gamma_use':   'доля ёмкости $\\gamma^{use}$:  0,6 – 1,0',
         'B rho_res':     'обязательный резерв $\\rho$:  0,1 – 0,3',
         'C O_C1 [s]':    'перекрытие $O_{C1}$:  300 – 600 с',
         'D wind scale':  'масштаб ветра:  ×0 – ×2',
         'E R copies':    'число копий $R$:  2 – 5',
         'F speed levels':'уровней скорости:  1 – 7',
         'G stations':    'зарядных станций:  0 – 2',
         'H eta_adm':     'порог допустимости $\\eta$:  0,6 – 1,0',
         'I N_res':       'аварийных резервов:  0 – 2'}

items = []
for k, rr in sw.items():
    d = [(float(r['f3_Wh'])-base_f3)/base_f3*100 for r in rr if r['f3_Wh'] not in ('', 'NaN')]
    f1 = [int(float(r['f1'])) for r in rr if r['f1'] not in ('', 'NaN')]
    nscr = sum(1 for r in rr if r['f3_Wh'] in ('', 'NaN'))
    items.append(dict(key=k, lo=min(d), hi=max(d), span=max(d)-min(d),
                      f1min=min(f1), f1max=max(f1), nscr=nscr))
items.sort(key=lambda a: a['span'])

fig, ax = plt.subplots(figsize=(7.4, 4.0))
y = np.arange(len(items))
for i, it in enumerate(items):
    ax.plot([it['lo'], it['hi']], [i, i], '-', lw=7, solid_capstyle='butt',
            color=('#b2182b' if it['f1max'] > 4 else '#4393c3'), alpha=.85, zorder=2)
    ax.plot([0], [i], '|', ms=13, color='k', mew=1.4, zorder=4)
    lab = f"$f_1$: {it['f1min']}"
    if it['f1max'] != it['f1min']: lab = f"$f_1$: {it['f1min']}–{it['f1max']}"
    if it['nscr']: lab += f",  экран ×{it['nscr']}"
    ax.annotate(lab, (max(it['hi'], 0.6)+1.2, i), va='center', fontsize=7.3,
                color=('#b2182b' if it['f1max'] > 4 else '#333'))

ax.set_yticks(y); ax.set_yticklabels([names[it['key']] for it in items], fontsize=7.8)
ax.axvline(0, color='k', lw=.8)
ax.set_xlabel('изменение энергопотребления $\\Delta f_3$ относительно базового решения, %')
ax.set_xlim(-11, 46)
ax.grid(axis='x', alpha=.2, lw=.5)
ax.set_title('Чувствительность результата к параметрам: размах $\\Delta f_3$,\n'
             'диапазон размера флота и число строк, отвергнутых экранами',
             fontsize=9)
from matplotlib.patches import Patch
ax.legend(handles=[Patch(fc='#b2182b', alpha=.85, label='параметр меняет размер флота'),
                   Patch(fc='#4393c3', alpha=.85, label='размер флота неизменен')],
          loc='lower right', fontsize=7.5, framealpha=.95)
plt.tight_layout()
plt.savefig(str(FIGURES / 'fig_tornado.pdf'), bbox_inches='tight')
plt.savefig(str(FIGURES / str(FIGURES / 'fig_tornado.png')), dpi=150, bbox_inches='tight')

print(f"{'параметр':<18}{'Δf3 мин':>9}{'Δf3 макс':>10}{'размах':>8}{'f1':>10}{'экранов':>9}")
for it in reversed(items):
    print(f"{it['key']:<18}{it['lo']:9.2f}{it['hi']:10.2f}{it['span']:8.2f}"
          f"{str(it['f1min'])+'-'+str(it['f1max']):>10}{it['nscr']:>9}")
