#!/usr/bin/env python3
"""Рис. 6.1 — конвейер; рис. 6.2 — сверка двух реализаций."""

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
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
plt.rcParams['font.family'] = 'DejaVu Sans'; plt.rcParams['font.size'] = 8


# ==================== Рис. 6.1 — конвейер ====================
fig, ax = plt.subplots(figsize=(7.0, 8.2))
BW, BH = 5.6, 0.78
COL = {'in': '#d9d9d9', 'pre': '#c6dbef', 'screen': '#fdd0a2',
       'milp': '#9ecae1', 'lex': '#a1d99b', 'ver': '#fcbba1', 'out': '#d9d9d9'}

steps = [
 ('Загрузка экземпляра\nточки $F$, $C1$, кандидаты базы, станции, ветер, аппарат', 'in',  'cilento_case, cilento_baseline'),
 ('Препроцессинг\nплотность, калибровка, ветровая кинематика, коэффициенты', 'pre', 'cilento_pre'),
 ('Кэп $\\tau^{\\max}_{C1}$ по батарейному экрану', 'pre', 'cilento_prepare'),
 ('Предварительные экраны P1–P6', 'screen', 'внутри cilento_pre'),
 ('Точный поиск флота\n$K = 1, 2, \\dots$ до первого допустимого', 'milp', 'cilento_solve_case'),
 ('Этап 2: минимум makespan при $f_1 = f_1^*$', 'lex', 'cilento_solve_case'),
 ('Этап 3: минимум энергии при $f_1 = f_1^*$, $f_2 \\leq f_2^* + \\varepsilon_2$', 'lex', 'cilento_solve_case'),
 ('Извлечение плана: дуги, скорости, окна, зарядки', 'ver', 'cilento_extract'),
 ('Независимый пересчёт расписания', 'ver', 'cilento_derive'),
 ('Проверка против физики: 125–137 свойств', 'ver', 'cilento_verify'),
 ('Выход: $f_1$, $f_2$, $f_3$, маршруты, CSV, рисунки', 'out', 'run_cilento, cilento_plots'),
]

y = len(steps)*1.0
for i, (txt, kind, mod) in enumerate(steps):
    yy = y - i*1.0
    ax.add_patch(FancyBboxPatch((0.35, yy-BH/2), BW, BH,
                 boxstyle='round,pad=0.06,rounding_size=0.10',
                 facecolor=COL[kind], edgecolor='#555', lw=.8))
    ax.text(0.35+BW/2, yy, txt, ha='center', va='center', fontsize=7.6)
    ax.text(0.35+BW+0.25, yy, mod, ha='left', va='center', fontsize=6.6,
            color='#444', family='monospace')
    if i < len(steps)-1:
        ax.add_patch(FancyArrowPatch((0.35+BW/2, yy-BH/2-0.02),
                                     (0.35+BW/2, yy-1+BH/2+0.02),
                                     arrowstyle='-|>', mutation_scale=11,
                                     color='#444', lw=1.1))

# ветка отказа экранов
ys = y - 3*1.0
ax.add_patch(FancyArrowPatch((0.35, ys), (-0.75, ys),
             arrowstyle='-|>', mutation_scale=11, color='#b2182b', lw=1.2))
ax.text(-0.80, ys, 'экран\nне пройден:\nдиагноз без\nрешателя',
        ha='right', va='center', fontsize=6.9, color='#b2182b')

# ветка недоказанной невыполнимости
yk = y - 4*1.0
ax.add_patch(FancyArrowPatch((0.35, yk), (-0.75, yk),
             arrowstyle='-|>', mutation_scale=11, color='#b2182b', lw=1.2))
ax.text(-0.80, yk, 'лимит времени\nбез инкумбента:\nостановка,\nминимум не\nустановлен',
        ha='right', va='center', fontsize=6.9, color='#b2182b')

ax.set_xlim(-3.1, 10.2); ax.set_ylim(y-len(steps)+0.1, y+0.75)
ax.axis('off')
ax.set_title('Алгоритмический конвейер и соответствующие модули', fontsize=9, pad=6)
plt.tight_layout()
plt.savefig(str(FIGURES / 'fig_pipeline.pdf'), bbox_inches='tight')
plt.savefig(str(FIGURES / str(FIGURES / 'fig_pipeline.png')), dpi=150, bbox_inches='tight')
plt.close()

# ==================== Рис. 6.2 — сверка реализаций ====================
am = list(csv.DictReader(open(BASE+'ablation_matlab.csv')))
ap = list(csv.DictReader(open(BASE+'python-reference/ablation_python.csv')))
sm = list(csv.DictReader(open(BASE+'sensitivity_matlab.csv')))
sp = list(csv.DictReader(open(BASE+'python-reference/sensitivity_python.csv')))
tm = list(csv.DictReader(open(BASE+'tests_matlab.csv')))
tp = list(csv.DictReader(open(BASE+'python-reference/tests_python.csv')))

fig, (a1, a2) = plt.subplots(1, 2, figsize=(7.6, 3.1),
                             gridspec_kw={'width_ratios': [1.15, 1]})

# (a) f3 MATLAB против f3 Python
xs, ys_, ok = [], [], []
for a, b in zip(am+sm, ap+sp):
    fa, fb = a.get('f3_Wh', ''), b.get('f3_Wh', '')
    try:
        fa, fb = float(fa), float(fb)
    except (TypeError, ValueError):
        continue
    if not (np.isfinite(fa) and np.isfinite(fb)):
        continue
    xs.append(fa); ys_.append(fb); ok.append(abs(fa-fb) < 0.6)
xs, ys_, ok = np.array(xs), np.array(ys_), np.array(ok)
lim = [min(xs.min(), ys_.min())-15, max(xs.max(), ys_.max())+15]
a1.plot(lim, lim, 'k--', lw=.8, zorder=1, label='совпадение')
a1.scatter(xs[ok], ys_[ok], s=34, c='#2166ac', edgecolor='k', lw=.4,
           zorder=3, label=f'совпало ({ok.sum()})')
a1.scatter(xs[~ok], ys_[~ok], s=52, c='#b2182b', marker='D', edgecolor='k',
           lw=.5, zorder=4, label=f'расходится ({(~ok).sum()})')
a1.set_xlim(lim); a1.set_ylim(lim)
a1.set_xlabel('$f_3$, MATLAB / Gurobi, Вт$\\cdot$ч')
a1.set_ylabel('$f_3$, Python / HiGHS, Вт$\\cdot$ч')
a1.grid(alpha=.2, lw=.5); a1.legend(fontsize=7, loc='upper left')
a1.set_title('энергия: 44 сопоставимые строки', fontsize=8.5)

# (b) суммарное время по наборам экспериментов
sets = [('12 тестов\n(§7.2)',
         sum(float(r['time']) for r in tm), sum(float(r['seconds']) for r in tp)),
        ('ablation\n(16 прогонов)',
         sum(float(r['seconds']) for r in am), sum(float(r['seconds']) for r in ap)),
        ('чувствительность\n(34 строки)',
         sum(float(r['seconds'] or 0) for r in sm),
         sum(float(r['seconds'] or 0) for r in sp))]
x = np.arange(len(sets))
a2.bar(x-0.2, [s[1] for s in sets], width=0.4, color='#2166ac',
       edgecolor='k', lw=.5, label='MATLAB / Gurobi')
a2.bar(x+0.2, [s[2] for s in sets], width=0.4, color='#fdae61',
       edgecolor='k', lw=.5, label='Python / HiGHS')
for xi, s in zip(x, sets):
    a2.annotate(f'{s[1]:.0f}', (xi-0.2, s[1]), xytext=(0, 2),
                textcoords='offset points', ha='center', fontsize=7)
    a2.annotate(f'{s[2]:.0f}', (xi+0.2, s[2]), xytext=(0, 2),
                textcoords='offset points', ha='center', fontsize=7)
    a2.annotate(f'×{s[2]/s[1]:.1f}', (xi, max(s[1], s[2])), xytext=(0, 15),
                textcoords='offset points', ha='center', fontsize=7.5,
                color='#b2182b', weight='bold')
a2.set_xticks(x); a2.set_xticklabels([s[0] for s in sets], fontsize=7.5)
a2.set_ylabel('суммарное время решения, с')
a2.set_ylim(0, 1150)
a2.grid(axis='y', alpha=.2, lw=.5); a2.legend(fontsize=7.5)
a2.set_title('время решения по наборам', fontsize=8.5)
plt.tight_layout()
plt.savefig(str(FIGURES / 'fig_crosscheck.pdf'), bbox_inches='tight')
plt.savefig(str(FIGURES / str(FIGURES / 'fig_crosscheck.png')), dpi=150, bbox_inches='tight')

print(f'сопоставимых строк: {len(xs)}, совпало {ok.sum()}, расходится {(~ok).sum()}')
for a, b, o in zip(xs, ys_, ok):
    if not o: print(f'   MATLAB {a:.2f} vs Python {b:.2f}  (разница {abs(a-b):.2f} Вт*ч)')
for nm, m_, p_ in sets:
    print(f'{nm.splitlines()[0]:<20} MATLAB {m_:7.1f} c   Python {p_:7.1f} c   ×{p_/m_:.2f}')
