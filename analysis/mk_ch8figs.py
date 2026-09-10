#!/usr/bin/env python3
"""Рис. 8.x — масштабируемость и чувствительность (перерисовка имеющихся CSV)."""

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


# ---------------- масштабируемость ----------------
rows = list(csv.DictReader(open(BASE+'scalability_final.csv')))
nF   = np.array([int(r['nF']) for r in rows])
tsec = np.array([float(r['time_s']) for r in rows])
bins = np.array([int(r['bins']) for r in rows])
nodes= np.array([int(r['nodes']) for r in rows])
st   = [r['status'] for r in rows]
opt  = np.array([s == 'optimal' for s in st])
num  = np.array(['infeasible' in s for s in st])
lim  = np.array(['time-limit' in s for s in st])

fig, axs = plt.subplots(1, 3, figsize=(7.8, 2.9))

def mark(ax, y, ylab, logy=True):
    ax.plot(nF, y, '-', color='#999', lw=1.0, zorder=1)
    ax.plot(nF[opt], y[opt], 'o', ms=7, mfc='#1b7837', mec='k', mew=.5,
            zorder=3, label='доказан оптимум')
    ax.plot(nF[num], y[num], 's', ms=7, mfc='#fdae61', mec='k', mew=.5,
            zorder=3, label='численный отказ')
    ax.plot(nF[lim], y[lim], 'D', ms=7, mfc='#b2182b', mec='k', mew=.5,
            zorder=3, label='лимит без инкумбента')
    if logy: ax.set_yscale('log')
    ax.set_xlabel('$|F|$'); ax.set_ylabel(ylab)
    ax.grid(alpha=.2, lw=.5)

mark(axs[0], tsec, 'время решения, с')
axs[0].axhline(300, color='#666', ls=':', lw=.9)
axs[0].annotate('300 с', (2.3, 330), fontsize=6.8, color='#666')
axs[0].axhline(3600, color='#666', ls=':', lw=.9)
axs[0].annotate('3600 с', (2.3, 4000), fontsize=6.8, color='#666')
axs[0].set_title('время решения', fontsize=8.5)

mark(axs[1], bins, 'бинарных переменных', logy=False)
axs[1].set_title('размер задачи', fontsize=8.5)

mark(axs[2], np.maximum(nodes, 1), 'узлов дерева B\\&B')
axs[2].set_title('перебор', fontsize=8.5)
axs[2].legend(fontsize=6.6, loc='lower right')

plt.tight_layout()
plt.savefig(str(FIGURES / 'fig_scal.pdf'), bbox_inches='tight')
plt.savefig(str(FIGURES / str(FIGURES / 'fig_scal.png')), dpi=150, bbox_inches='tight')
plt.close()

print('=== масштабируемость (scalability_final.csv)')
for r in rows:
    inc = r['incumbent']; bnd = r['bound']
    inc = f"{float(inc):.2f}" if inc not in ('', 'NaN') else '—'
    bnd = f"{float(bnd):.2f}" if bnd not in ('', 'NaN') else '—'
    print(f"  |F|={int(r['nF']):2d} |N|={int(r['nN']):2d} дуг={int(r['arcs']):3d} "
          f"бин={int(r['bins']):5d} огр={int(r['cons']):5d} "
          f"t={float(r['time_s']):8.1f}с узлов={int(r['nodes']):7d} "
          f"инк={inc:>7} гран={bnd:>7}  {r['status']}")

r8 = list(csv.DictReader(open(BASE+'scalability_final_7p12.csv')))
r8 = [r for r in r8 if r['nF'] == '8'][0]
print(f"\n  отдельный прогон |F|=8, лимит 600 с: t={float(r8['time_s']):.1f} с, "
      f"инкумбент {float(r8['incumbent']):.2f} Вт*ч, граница {float(r8['bound']):.2f}, "
      f"зазор {100*float(r8['gap']):.2f} %")

# ---------------- чувствительность ----------------
sm = list(csv.DictReader(open(BASE+'sensitivity_matlab.csv')))
base = 426.9334437404257
sweeps = {}
for r in sm:
    sweeps.setdefault(r['sweep'], []).append(r)

order = ['A gamma_use', 'B rho_res', 'C O_C1 [s]', 'D wind scale',
         'E R copies', 'F speed levels', 'G stations', 'H eta_adm', 'I N_res']
titles = {'A gamma_use': 'A: доля ёмкости $\\gamma^{use}$',
          'B rho_res':   'B: резерв $\\rho$',
          'C O_C1 [s]':  'C: перекрытие $O_{C1}$, с',
          'D wind scale':'D: масштаб ветра',
          'E R copies':  'E: число копий $R$',
          'F speed levels':'F: уровней скорости',
          'G stations':  'G: зарядных станций',
          'H eta_adm':   'H: порог $\\eta$',
          'I N_res':     'I: резервов $N^{res}$'}

fig, axs = plt.subplots(3, 3, figsize=(7.8, 6.4))
for ax, key in zip(axs.ravel(), order):
    rr = sweeps[key]
    labs = [r['value'].split(':')[0] for r in rr]
    vals, cols, f1s = [], [], []
    for r in rr:
        if r['f3_Wh'] in ('', 'NaN'):
            vals.append(0.0); cols.append('#cccccc'); f1s.append('экран')
        else:
            d = (float(r['f3_Wh']) - base)/base*100
            vals.append(d)
            cols.append('#b2182b' if d > 0.05 else ('#2166ac' if d < -0.05 else '#a1d99b'))
            f1s.append(r['f1'])
    x = np.arange(len(rr))
    ax.bar(x, vals, color=cols, edgecolor='k', lw=.4, width=.62)
    for xi, (v, f) in enumerate(zip(vals, f1s)):
        if f == 'экран':
            ax.annotate('экран', (xi, 0.6), ha='center', fontsize=6.2,
                        color='#777', rotation=90)
        else:
            ax.annotate(f'{int(float(f))}', (xi, v), xytext=(0, 3 if v >= 0 else -9),
                        textcoords='offset points', ha='center', fontsize=6.6,
                        color='#333')
    ax.axhline(0, color='k', lw=.7)
    ax.set_xticks(x); ax.set_xticklabels(labs, fontsize=6.6)
    ax.set_title(titles[key], fontsize=7.8)
    ax.grid(axis='y', alpha=.2, lw=.5)
    ax.set_ylim(min(-9, min(vals)-4), max(34, max(vals)+6))
    if key in ('A gamma_use', 'D wind scale', 'G stations'):
        ax.set_ylabel('$\\Delta f_3$, %', fontsize=7.5)
fig.suptitle('Анализ чувствительности: изменение энергии относительно базового '
             'решения; цифра над столбцом — размер флота $f_1$',
             fontsize=8.5, y=1.005)
plt.tight_layout()
plt.savefig(str(FIGURES / 'fig_sens.pdf'), bbox_inches='tight')
plt.savefig(str(FIGURES / str(FIGURES / 'fig_sens.png')), dpi=150, bbox_inches='tight')
print('\nрисунки сохранены')
