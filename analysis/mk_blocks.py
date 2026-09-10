#!/usr/bin/env python3
"""Рис. 5.1 — какие блоки ограничений какие группы переменных связывают."""

# --- repo-relative paths (added for public release) ---
from pathlib import Path as _Path
ROOT = _Path(__file__).resolve().parents[1]
RESULTS = ROOT / 'results'
FIGURES = ROOT / 'figures'
FIGURES.mkdir(exist_ok=True)
BASE = str(RESULTS) + '/'
# ------------------------------------------------------

import numpy as np, matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
plt.rcParams['font.family'] = 'DejaVu Sans'; plt.rcParams['font.size'] = 8

blocks = [
 ('Б1  маршрутизация, поток, подтуры',  'route'),
 ('Б2  выбор воздушной скорости',       'speed'),
 ('Б3  время и расписание',             'time'),
 ('Б4  энергетический баланс',          'energy'),
 ('Б5  непрерывность наблюдения $C1$',  'c1'),
 ('Б6  зарядка и пропускная способность','charge'),
 ('Б7  горизонт миссии и резерв',       'horizon'),
]
varz = [
 ('$u_k,\\,s_k,\\,e_k$\nактивация',   'act'),
 ('$x_{ijk},\\,r_{ik},\\,q_{ik}$\nмаршрут',      'route'),
 ('$z_{ijhk}$\nскорость',             'speed'),
 ('$t^{arr},t,C,W$\nвремя',           'time'),
 ('$b^{arr},b^{dep}$\nзаряд',         'batt'),
 ('$\\alpha_r,\\beta_r$\nокна $C1$',  'c1'),
 ('$\\delta,g^{ch},a$\nзарядка',      'chg'),
]
# 2 = определяющая связь, 1 = вспомогательная
M = np.array([
 [2,2,0,0,0,0,0],   # Б1
 [0,2,2,0,0,0,0],   # Б2
 [1,1,2,2,0,1,1],   # Б3
 [0,1,2,1,2,1,1],   # Б4
 [1,1,0,2,1,2,0],   # Б5
 [0,1,0,2,0,0,2],   # Б6
 [2,1,0,1,0,1,0],   # Б7
])

fig, ax = plt.subplots(figsize=(7.4, 3.9))
cmap = {0: '#f7f7f7', 1: '#c6dbef', 2: '#2166ac'}
for i in range(M.shape[0]):
    for j in range(M.shape[1]):
        ax.add_patch(plt.Rectangle((j, M.shape[0]-1-i), 1, 1,
                                   facecolor=cmap[M[i, j]],
                                   edgecolor='white', lw=1.6))
        if M[i, j] == 2:
            ax.plot(j+.5, M.shape[0]-1-i+.5, 'o', ms=5, mfc='white', mec='none')

ax.set_xlim(0, M.shape[1]); ax.set_ylim(0, M.shape[0])
ax.set_xticks(np.arange(M.shape[1])+.5)
ax.set_xticklabels([v[0] for v in varz], fontsize=7.2)
ax.set_yticks(np.arange(M.shape[0])+.5)
ax.set_yticklabels([b[0] for b in reversed(blocks)], fontsize=7.6)
ax.tick_params(length=0)
for s in ax.spines.values(): s.set_visible(False)
ax.xaxis.set_ticks_position('top'); ax.xaxis.set_label_position('top')

from matplotlib.patches import Patch
ax.legend(handles=[Patch(fc=cmap[2], label='определяющая связь'),
                   Patch(fc=cmap[1], label='вспомогательная связь'),
                   Patch(fc=cmap[0], ec='#ccc', label='не связаны')],
          loc='upper left', bbox_to_anchor=(0, -0.04), ncol=3, fontsize=7.5,
          frameon=False)
plt.tight_layout()
plt.savefig(str(FIGURES / 'fig_blocks.pdf'), bbox_inches='tight')
plt.savefig(str(FIGURES / str(FIGURES / 'fig_blocks.png')), dpi=150, bbox_inches='tight')
print('ok')
