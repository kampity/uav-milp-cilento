#!/usr/bin/env python3

# --- repo-relative paths (added for public release) ---
from pathlib import Path as _Path
ROOT = _Path(__file__).resolve().parents[1]
RESULTS = ROOT / 'results'
FIGURES = ROOT / 'figures'
FIGURES.mkdir(exist_ok=True)
BASE = str(RESULTS) + '/'
# ------------------------------------------------------

# Рисунок 3.1 — обзорная схема района работ.
# Проекция: локальная плоскость «восток—север» относительно 40°12' с.ш., 15°13' в.д.
import numpy as np, matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon as MPoly
from matplotlib.lines import Line2D
plt.rcParams['font.family'] = 'DejaVu Sans'
plt.rcParams['font.size'] = 8

S = [('Агрополи',40.34917,14.99056),('Коперсито',40.31472,15.06250),
     ('Сан-Мартино',40.30000,15.04833),('Косте',40.25056,15.11250),
     ('Черазо',40.19417,15.25583),('Террадура',40.15611,15.21694),
     ('Элея-Велия',40.16111,15.15987),('Роккаглориоза',40.10611,15.43639),
     ('Палинуро',40.03667,15.28806),('Скарио',40.06207,15.47421),
     ('Лентискоза',40.02194,15.38278)]
B = [('Чентола AIB',40.06972,15.31167),('VVF Валло',40.22778,15.26611),
     ('VVF Агрополи',40.38556,15.02472),('Элис. Паттано',40.22778,15.23500),
     ('CM Футани',40.15139,15.32361),('CM Лауреана',40.30111,15.03861)]

lat0, lon0 = 40.20, 15.22
pr = lambda la, lo: ((lo-lon0)*111320*np.cos(np.radians(lat0))/1000,
                     (la-lat0)*110540/1000)
Sp = {n: pr(a,b) for n,a,b in S}
Bp = {n: pr(a,b) for n,a,b in B}
ALL = {**Sp, **Bp}

sec = {
 'Северный':    dict(base='CM Лауреана', c1='Коперсито',
                     F=['Агрополи','Сан-Мартино','Косте'], ch='VVF Агрополи', col='#2166ac'),
 'Центральный': dict(base='VVF Валло', c1='Элея-Велия',
                     F=['Черазо','Косте'], ch='Элис. Паттано', col='#b2182b'),
 'Южный':       dict(base='Чентола AIB', c1='Палинуро',
                     F=['Лентискоза','Скарио','Роккаглориоза'], ch='CM Футани', col='#1b7837')}

def hull(pts):
    pts = sorted(set(pts))
    cr = lambda o,a,b: (a[0]-o[0])*(b[1]-o[1]) - (a[1]-o[1])*(b[0]-o[0])
    lo = []
    for p in pts:
        while len(lo) >= 2 and cr(lo[-2], lo[-1], p) <= 0: lo.pop()
        lo.append(p)
    up = []
    for p in reversed(pts):
        while len(up) >= 2 and cr(up[-2], up[-1], p) <= 0: up.pop()
        up.append(p)
    return lo[:-1] + up[:-1]

off = {'Элис. Паттано': (-11,-4,'right'), 'VVF Валло': (10,-4,'left'),
       'VVF Агрополи': (12,-3,'left'),    'CM Лауреана': (-9,-13,'right'),
       'CM Футани': (10,-4,'left'),       'Чентола AIB': (10,-4,'left'),
       'Агрополи': (-7,3,'right'),        'Сан-Мартино': (-9,5,'right'),
       'Коперсито': (7,4,'left'),         'Скарио': (-7,4,'right'),
       'Лентискоза': (7,-9,'left'),       'Палинуро': (-10,3,'right'),
       'Косте': (7,3,'left'),             'Черазо': (7,-2,'left'),
       'Террадура': (7,-3,'left'),        'Роккаглориоза': (7,2,'left'),
       'Элея-Велия': (8,3,'left')}

fig, ax = plt.subplots(figsize=(7.2, 7.2))

for k, v in sec.items():
    pts = [ALL[v['base']], ALL[v['c1']], ALL[v['ch']]] + [ALL[f] for f in v['F']]
    ax.add_patch(MPoly(hull(pts), closed=True, facecolor=v['col'], alpha=.085,
                       edgecolor=v['col'], lw=1.1, ls='--', zorder=1))

ax.text(-19.5, -2.0, 'Тирренское море', fontsize=9.5, style='italic',
        color='#3b6ea5', rotation=42, ha='center')
ax.annotate('', xy=(-19.0,-7.5), xytext=(-14.0,-2.5),
            arrowprops=dict(arrowstyle='-|>', color='#3b6ea5', lw=1.3))

c1s = [v['c1'] for v in sec.values()]
chs = [v['ch'] for v in sec.values()]

for i, (n, a, b) in enumerate(S, 1):
    x, y = Sp[n]
    if n in c1s: ax.plot(x, y, marker='*', ms=16, mfc='#d73027', mec='k', mew=.6, zorder=5)
    else:        ax.plot(x, y, marker='o', ms=6.5, mfc='#fdae61', mec='k', mew=.6, zorder=5)
    dx, dy, ha = off.get(n, (6,4,'left'))
    ax.annotate(f'{i}. {n}', (x,y), xytext=(dx,dy), textcoords='offset points',
                fontsize=7.4, ha=ha, zorder=6)

for n, a, b in B:
    x, y = Bp[n]
    ax.plot(x, y, marker='s', ms=7.5,
            mfc=('#4393c3' if n == 'CM Лауреана' else '#d9d9d9'), mec='k', mew=.7, zorder=5)
    if n in chs:
        ax.plot(x, y, marker='s', ms=13, mfc='none', mec='#1b7837', mew=1.4, zorder=4)
    dx, dy, ha = off.get(n, (6,-10,'left'))
    ax.annotate(n, (x,y), xytext=(dx,dy), textcoords='offset points',
                fontsize=7.4, ha=ha, color='#333', zorder=6)

x0, y0 = 9.0, -23.2
ax.plot([x0, x0+10], [y0, y0], 'k-', lw=2.2)
for xx in (x0, x0+5, x0+10): ax.plot([xx,xx], [y0-.55, y0+.55], 'k-', lw=1.6)
for xx, lb in ((x0,'0'), (x0+5,'5'), (x0+10,'10 км')):
    ax.annotate(lb, (xx, y0+1.0), ha='center', fontsize=7.5)

ax.annotate('С', xy=(22.2, 21.3), ha='center', fontsize=10.5, weight='bold')
ax.annotate('', xy=(22.2, 20.6), xytext=(22.2, 16.4),
            arrowprops=dict(arrowstyle='-|>', color='k', lw=1.7))

ax.text(-11.0, 15.0, 'СЕВЕРНЫЙ',    color=sec['Северный']['col'],    fontsize=9.5, weight='bold', alpha=.9)
ax.text(-3.5,   1.4, 'ЦЕНТРАЛЬНЫЙ', color=sec['Центральный']['col'], fontsize=9.5, weight='bold', alpha=.9)
ax.text(13.5, -12.0, 'ЮЖНЫЙ',       color=sec['Южный']['col'],       fontsize=9.5, weight='bold', alpha=.9)

leg = [Line2D([],[],marker='o',ls='',mfc='#fdae61',mec='k',ms=6.5,label='историческая точка пожара'),
       Line2D([],[],marker='*',ls='',mfc='#d73027',mec='k',ms=13,label='точка постоянного наблюдения C1'),
       Line2D([],[],marker='s',ls='',mfc='#d9d9d9',mec='k',ms=7.5,label='кандидат базы'),
       Line2D([],[],marker='s',ls='',mfc='#4393c3',mec='k',ms=7.5,label='база северного сектора (CM Лауреана)'),
       Line2D([],[],marker='s',ls='',mfc='none',mec='#1b7837',ms=12,mew=1.4,label='точка восстановления энергии сектора')]
ax.legend(handles=leg, loc='lower left', fontsize=7.3, framealpha=.96,
          borderpad=.65, handletextpad=.8)

ax.set_xlabel('восток, км (относительно 15°13′ в.д.)')
ax.set_ylabel('север, км (относительно 40°12′ с.ш.)')
ax.set_xlim(-22, 29); ax.set_ylim(-26, 23)
ax.set_aspect('equal'); ax.grid(alpha=.16, lw=.5)
plt.tight_layout()
plt.savefig(str(FIGURES / 'fig_map.pdf'), bbox_inches='tight')
plt.savefig(str(FIGURES / 'fig_map.png'), dpi=150, bbox_inches='tight')
print('ok')
