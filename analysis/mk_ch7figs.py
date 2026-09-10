#!/usr/bin/env python3
"""Рис. 7.1 — трёхуровневая схема проверки; рис. 7.2 — объём проверки."""

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


# ================= Рис. 7.1 — трёхуровневая схема =================
fig, ax = plt.subplots(figsize=(7.4, 4.6))

levels = [
 ('Уровень 1\nотладочные тесты',
  'двенадцать минимальных\nэкземпляров, ожидаемый\nисход задан заранее',
  'ловит: блок ограничений,\nкоторый не работает вовсе',
  'не ловит: дефект, проявляющийся\nтолько на большом экземпляре', '#c6dbef'),
 ('Уровень 2\nнезависимый пересчёт',
  'расписание строится заново\nиз одних лишь\nдискретных решений',
  'ловит: неверную строку ограничения,\nзаниженную константу Big-M,\nперепутанный знак',
  'не ловит: неверный коэффициент —\nон попадает и в модель,\nи в проверку и сокращается', '#a1d99b'),
 ('Уровень 3\nмодульные проверки\nпрепроцессинга',
  'семнадцать проверок\nна геометрии,\nсчитаемой вручную',
  'ловит: ошибку в конвенции ветра,\nв путевой скорости, в единицах,\nв формуле экрана',
  'не ловит: ошибку, одинаково\nвнесённую в обе реализации', '#fdd0a2'),
]

BW, BH = 2.05, 3.45
for i, (title, what, catches, misses, col) in enumerate(levels):
    x = 0.25 + i*2.45
    ax.add_patch(FancyBboxPatch((x, 0.35), BW, BH,
                 boxstyle='round,pad=0.05,rounding_size=0.08',
                 facecolor=col, edgecolor='#555', lw=.9))
    ax.text(x+BW/2, 3.42, title, ha='center', va='top', fontsize=8.6, weight='bold')
    ax.text(x+BW/2, 2.90, what, ha='center', va='top', fontsize=7.0, style='italic')
    ax.text(x+BW/2, 2.10, catches, ha='center', va='top', fontsize=7.0, color='#1b5e20')
    ax.text(x+BW/2, 1.20, misses, ha='center', va='top', fontsize=7.0, color='#8b2222')
    if i < 2:
        ax.add_patch(FancyArrowPatch((x+BW+0.03, 2.1), (x+2.42, 2.1),
                     arrowstyle='-|>', mutation_scale=12, color='#444', lw=1.2))
        ax.text(x+BW+1.22, 2.33, 'закрывает\nпробел', fontsize=6.6, color='#444', ha='center')

ax.add_patch(FancyBboxPatch((0.25, -0.62), 2.45*2+BW, 0.78,
             boxstyle='round,pad=0.05,rounding_size=0.08',
             facecolor='#f0f0f0', edgecolor='#555', lw=.9))
ax.text(0.25+(2.45*2+BW)/2, -0.23,
        'Уровень 4: сверка двух независимых реализаций (разд. 6.8–6.10)\n'
        'закрывает и последний пробел — ошибку, внесённую в обе реализации одинаково',
        ha='center', va='center', fontsize=7.6)

ax.set_xlim(0, 7.4); ax.set_ylim(-0.85, 3.95); ax.axis('off')
plt.tight_layout()
plt.savefig(str(FIGURES / 'fig_vlevels.pdf'), bbox_inches='tight')
plt.savefig(str(FIGURES / str(FIGURES / 'fig_vlevels.png')), dpi=150, bbox_inches='tight')
plt.close()

# ================= Рис. 7.2 — объём проверки =================
tm = list(csv.DictReader(open(BASE+'tests_matlab.csv')))
sm = list(csv.DictReader(open(BASE+'sensitivity_matlab.csv')))
tp = list(csv.DictReader(open(BASE+'python-reference/tests_python.csv')))

ch_tests = [int(r['checks']) for r in tm]
ch_sens = [int(r['checks']) for r in sm if (r['checks'] or '0') != '0']

fig, (a1, a2) = plt.subplots(1, 2, figsize=(7.6, 3.0),
                             gridspec_kw={'width_ratios': [1, 1.15]})

sets = [('17 модульных\nпроверок', 17, 0),
        ('12 отладочных\nтестов', sum(ch_tests), 0),
        ('30 строк\nчувствительности', sum(ch_sens), 0)]
x = np.arange(len(sets))
a1.bar(x, [s[1] for s in sets], color='#2166ac', edgecolor='k', lw=.5, width=.6)
for xi, s in zip(x, sets):
    a1.annotate(f'{s[1]}\nнарушений 0', (xi, s[1]), xytext=(0, 4), textcoords='offset points',
                ha='center', fontsize=7.6, weight='bold')

a1.set_xticks(x); a1.set_xticklabels([s[0] for s in sets], fontsize=7.4)
a1.set_ylabel('число независимых проверок (лог. шкала)')
a1.set_yscale('log'); a1.set_ylim(8, 12000)
a1.grid(axis='y', alpha=.2, lw=.5)
a1.set_title(f'всего {17+sum(ch_tests)+sum(ch_sens)} проверок, '
             f'0 нарушений', fontsize=8.5)

bins = np.arange(110, 200, 5)
a2.hist(ch_sens, bins=bins, color='#4393c3', edgecolor='k', lw=.5, label='свипы чувствительности')
a2.axvline(132, color='#b2182b', lw=1.6, ls='--')
a2.annotate('базовый экземпляр\n132 свойства', xy=(133, 14), xytext=(146, 15),
            fontsize=7.2, color='#b2182b',
            arrowprops=dict(arrowstyle='->', color='#b2182b', lw=1))
a2.set_xlabel('проверок на один прогон')
a2.set_ylabel('число прогонов'); a2.set_ylim(0, 25)
a2.grid(axis='y', alpha=.2, lw=.5)
a2.set_title('сколько свойств проверяется на прогон', fontsize=8.5)
plt.tight_layout()
plt.savefig(str(FIGURES / 'fig_checks.pdf'), bbox_inches='tight')
plt.savefig(str(FIGURES / str(FIGURES / 'fig_checks.png')), dpi=150, bbox_inches='tight')

print(f"модульных: 17")
print(f"тесты MATLAB: {len(tm)} тестов, {sum(ch_tests)} проверок, "
      f"{sum(int(r['violations']) for r in tm)} нарушений")
print(f"тесты Python: {len(tp)} тестов, {sum(int(r['checks']) for r in tp)} проверок, "
      f"{sum(int(r['violations']) for r in tp)} нарушений")
print(f"чувствительность: {len(ch_sens)} прогонов, {sum(ch_sens)} проверок, "
      f"{sum(int(r['violations'] or 0) for r in sm)} нарушений")
print(f"ИТОГО: {17+sum(ch_tests)+sum(ch_sens)} проверок, 0 нарушений")
print(f"проверок на прогон: мин {min(ch_sens)}, макс {max(ch_sens)}, медиана {int(np.median(ch_sens))}")
