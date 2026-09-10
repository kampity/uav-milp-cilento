#!/usr/bin/env python3
"""Рис. 4.1 — треугольник скоростей; рис. 4.5 — цена фиксированного выбора скорости."""

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
plt.rcParams['font.family'] = 'DejaVu Sans'; plt.rcParams['font.size'] = 8.5

P0, Pi, k, v0, A_r, rho0, P_sens, U_tip = np.load(str(RESULTS / 'calib.npy'))
Pprop = lambda v: (P0*(1+3*v**2/U_tip**2)
                   + Pi*(np.sqrt(1+v**4/(4*v0**4))-v**2/(2*v0**2))**0.5
                   + k*0.5*rho0*A_r*v**3)
Pobs = lambda v: Pprop(v) + P_sens
H = np.array([8., 10., 12., 14., 15.])
W = [(2.0,245,0.52), (5.0,245,0.24), (7.5,240,0.04), (3.5,50,0.20)]

def kin(cd, v, w, psi):
    th = np.radians(cd)
    e  = np.array([np.sin(th), np.cos(th)]); ep = np.array([np.cos(th), -np.sin(th)])
    pt = np.radians(psi+180); wv = w*np.array([np.sin(pt), np.cos(pt)])
    wpar, wperp = wv@e, wv@ep
    if abs(wperp) >= v: return None
    g = np.sqrt(v**2 - wperp**2) + wpar
    return (g, (w <= 12) and (g >= 3.0))

# ================= Рис. 4.1 — треугольник скоростей =================
fig, ax = plt.subplots(figsize=(6.0, 3.4))
v, wperp, wpar = 15.0, 5.0, -3.0
vpar = np.sqrt(v**2 - wperp**2)          # 14,142
O = (0.0, 0.0)
A = (vpar, -wperp)                        # конец вектора воздушной скорости
B = (vpar + wpar, 0.0)                    # конец вектора путевой скорости

ax.plot([-0.5, 17.0], [0, 0], 'k:', lw=.9)
ax.annotate('линия пути $i \\to j$', xy=(14.6, 0.55), fontsize=8, color='#555')

# проекция воздушной скорости на линию пути
ax.plot([0, vpar], [0, 0], color='#2166ac', lw=1.0, ls='--')
ax.plot([vpar, vpar], [0, -wperp], color='#2166ac', lw=1.0, ls='--')

ax.annotate('', xy=A, xytext=O,
            arrowprops=dict(arrowstyle='-|>', lw=2.4, color='#b2182b'))
ax.annotate('', xy=B, xytext=A,
            arrowprops=dict(arrowstyle='-|>', lw=2.2, color='#2166ac'))
ax.annotate('', xy=B, xytext=O,
            arrowprops=dict(arrowstyle='-|>', lw=2.8, color='#1b7837'))

# разложение вектора ветра
ax.plot([A[0], A[0]+wpar], [A[1], A[1]], color='#4393c3', lw=1.0, ls=':')
ax.plot([A[0]+wpar, B[0]], [A[1], B[1]], color='#4393c3', lw=1.0, ls=':')
ax.annotate('$w^{\\parallel}$', xy=(A[0]+wpar/2, A[1]-1.05), fontsize=9,
            color='#4393c3', ha='center')
ax.annotate('$w^{\\perp}$', xy=(A[0]+wpar-0.5, A[1]/2), fontsize=9,
            color='#4393c3', ha='right', va='center')
ax.annotate('$w^{\\perp}$', xy=(A[0]+0.45, A[1]/2), fontsize=9,
            color='#2166ac', ha='left', va='center')

ax.annotate('$\\mathbf{v}_h$ — воздушная скорость\n(с упреждением на снос)',
            xy=(6.6, -3.05), fontsize=8.5, color='#b2182b', ha='center',
            rotation=-np.degrees(np.arctan2(wperp, vpar)))
ax.annotate('$\\mathbf{w}$', xy=(13.55, -2.4), fontsize=10,
            color='#2166ac', ha='center', weight='bold')
ax.annotate('$g$ — путевая скорость', xy=(3.4, 0.55), fontsize=9,
            color='#1b7837', weight='bold')
ax.annotate('$\\sqrt{v_h^2-(w^{\\perp})^2}$', xy=(7.6, -0.95), fontsize=8.5,
            color='#2166ac', ha='center')

ax.plot(*O, 'o', ms=6, mfc='k'); ax.plot(*B, 'o', ms=6, mfc='#1b7837', mec='k', mew=.6)
ax.annotate('$i$', xy=(-0.9, -0.4), fontsize=10)
ax.set_xlim(-1.8, 17.5); ax.set_ylim(-6.6, 2.0)
ax.set_aspect('equal'); ax.axis('off')
ax.set_title('Компенсация сноса: поперечная составляющая воздушной скорости\n'
             'полностью гасит поперечный ветер', fontsize=8.5)
plt.tight_layout(); plt.savefig(str(FIGURES / 'fig_triangle.pdf'), bbox_inches='tight')
plt.savefig(str(FIGURES / 'fig_triangle.png'), dpi=150, bbox_inches='tight'); plt.close()

# ================= Рис. 4.5 — цена фиксированной скорости =================
courses = np.arange(0, 360.5, 2.0)
cols = plt.cm.viridis(np.linspace(0.05, 0.9, len(H)))

def exp_energy(cd, v):
    num = pw = 0.0
    for (w, psi, p) in W:
        r = kin(cd, v, w, psi)
        if r is None or not r[1] or r[0] <= 0: return np.nan
        num += p*Pobs(v)/r[0]; pw += p
    return num/pw*1000/3600

def best_energy(cd):
    num = pw = 0.0
    for (w, psi, p) in W:
        es = []
        for v in H:
            r = kin(cd, v, w, psi)
            es.append(np.inf if (r is None or not r[1] or r[0] <= 0) else Pobs(v)/r[0])
        num += p*min(es); pw += p
    return num/pw*1000/3600

fig, (a1, a2) = plt.subplots(1, 2, figsize=(7.6, 3.1),
                             gridspec_kw={'width_ratios': [1.45, 1]})
env = np.array([best_energy(c) for c in courses])
for v, c in zip(H, cols):
    e = np.array([exp_energy(c_, v) for c_ in courses])
    a1.plot(courses, e, color=c, lw=1.3, label=f'{v:.0f} м/с')
a1.plot(courses, env, 'k--', lw=1.6, label='поуровневый\nоптимум')
a1.set_xlim(0, 360); a1.set_xticks([0,90,180,270,360])
a1.set_xticklabels(['С','В','Ю','З','С'])
a1.set_ylim(2.5, 10); a1.set_xlabel('курс полёта')
a1.set_ylabel('ожидаемая энергия, Вт$\\cdot$ч на км')
a1.grid(alpha=.2, lw=.5); a1.legend(fontsize=6.8, ncol=2, loc='upper left')
a1.set_title('ожидание по сценариям $\\Omega$', fontsize=8.5)

over, frac = [], []
for v in H:
    ee = np.array([exp_energy(c, v) for c in courses])
    ok = ~np.isnan(ee)
    frac.append(100*ok.mean())
    over.append(100*(np.nansum(ee[ok])/np.sum(env[ok]) - 1))
x = np.arange(len(H))
b = a2.bar(x-0.2, over, width=0.4, color='#b2182b', alpha=.85,
           edgecolor='k', lw=.5, label='перерасход, %')
a2.bar(x+0.2, frac, width=0.4, color='#4393c3', alpha=.85,
       edgecolor='k', lw=.5, label='допустимых курсов, %')
for xi, o in zip(x, over):
    a2.annotate(f'{o:.0f}', (xi-0.2, o), xytext=(0,2), textcoords='offset points',
                ha='center', fontsize=7)
for xi, f in zip(x, frac):
    a2.annotate(f'{f:.0f}', (xi+0.2, f), xytext=(0,2), textcoords='offset points',
                ha='center', fontsize=7)
a2.set_xticks(x); a2.set_xticklabels([f'{v:.0f}' for v in H])
a2.set_xlabel('фиксированная воздушная скорость, м/с')
a2.set_ylabel('%'); a2.set_ylim(0, 132)
a2.grid(axis='y', alpha=.2, lw=.5); a2.legend(fontsize=7, loc='upper left', framealpha=.95)
a2.set_title('цена фиксированного выбора', fontsize=8.5)
plt.tight_layout(); plt.savefig(str(FIGURES / 'fig_fixedspeed.pdf'), bbox_inches='tight')
plt.savefig(str(FIGURES / 'fig_fixedspeed.png'), dpi=150, bbox_inches='tight'); plt.close()

print('перерасход по уровням:', [f'{v:.0f}: {o:.1f}%' for v, o in zip(H, over)])
print('доля допустимых курсов:', [f'{v:.0f}: {f:.1f}%' for v, f in zip(H, frac)])
print('ok')
