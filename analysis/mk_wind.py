#!/usr/bin/env python3

# --- repo-relative paths (added for public release) ---
from pathlib import Path as _Path
ROOT = _Path(__file__).resolve().parents[1]
RESULTS = ROOT / 'results'
FIGURES = ROOT / 'figures'
FIGURES.mkdir(exist_ok=True)
BASE = str(RESULTS) + '/'
# ------------------------------------------------------

# Рисунок 3.2 — четыре ветровых сценария (свёртка розы ветров LIRI).
import numpy as np, matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
plt.rcParams['font.family']='DejaVu Sans'; plt.rcParams['font.size']=8.5

# скорость м/с, направление ОТКУДА (град), вероятность, подпись
W = [(2.0,245,0.52,'$\\omega_1$  штиль и слабый\nприбрежный поток'),
     (5.0,245,0.24,'$\\omega_2$  установившийся\nдневной бриз'),
     (7.5,240,0.04,'$\\omega_3$  сильный ЮЗ\nponente'),
     (3.5, 50,0.20,'$\\omega_4$  мористый ночной\nбриз (NE)')]
cols=['#92c5de','#4393c3','#b2182b','#1b7837']

fig=plt.figure(figsize=(7.0,3.6))
ax=fig.add_subplot(121, projection='polar')
ax.set_theta_zero_location('N'); ax.set_theta_direction(-1)
nudge=[9,0,-9,0]
for (v,d,p,lb),c,nd in zip(W,cols,nudge):
    th=np.radians(d+nd)
    ax.bar(th, v, width=np.radians(11), bottom=0.0, color=c, alpha=.9,
           edgecolor='k', lw=.5)
    ax.annotate(f'{p:.0%}', xy=(th, v), xytext=(th, v+1.15),
                ha='center', fontsize=8, color=c, weight='bold')
ax.set_rlim(0,9.5)
ax.set_rticks([2,4,6,8]); ax.set_yticklabels(['2','4','6','8 м/с'], fontsize=7)
ax.set_xticks(np.radians([0,45,90,135,180,225,270,315]))
ax.set_xticklabels(['С','СВ','В','ЮВ','Ю','ЮЗ','З','СЗ'], fontsize=8)
ax.grid(alpha=.3, lw=.5)
ax.set_title('направление ОТКУДА дует ветер\nи скорость сценария', fontsize=8.5, pad=14)

ax2=fig.add_subplot(122)
ys=np.arange(len(W))[::-1]*1.0
for (v,d,p,lb),c,y in zip(W,cols,ys):
    ax2.barh(y, p, color=c, alpha=.9, edgecolor='k', lw=.5, height=.34)
    ax2.annotate(f'{p:.2f}', xy=(p,y), xytext=(4,0), textcoords='offset points',
                 va='center', fontsize=8)
    ax2.annotate(lb, xy=(0,y), xytext=(2,17), textcoords='offset points',
                 va='center', fontsize=7.3)
ax2.set_yticks([]); ax2.set_xlim(0,0.63); ax2.set_ylim(-0.6,3.7)
ax2.set_xlabel('вероятность сценария $p_\\omega$')
ax2.spines[['top','right','left']].set_visible(False)
ax2.grid(axis='x', alpha=.2, lw=.5)
ax2.set_title('распределение вероятностей', fontsize=8.5, pad=14)
plt.tight_layout()
plt.savefig(str(FIGURES / 'fig_wind.pdf'), bbox_inches='tight')
plt.savefig(str(FIGURES / 'fig_wind.png'), dpi=150, bbox_inches='tight')
print('ok')
