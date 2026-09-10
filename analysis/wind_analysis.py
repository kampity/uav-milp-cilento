#!/usr/bin/env python3
"""Ветровая кинематика: путевая скорость, время и энергия по курсу.
Рисунки 4.2-4.5 главы 4."""

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
plt.rcParams['font.family'] = 'DejaVu Sans'
plt.rcParams['font.size'] = 8.5

P0, Pi, k, v0, A_r, rho0, P_sens, U_tip = np.load(str(RESULTS / 'calib.npy'))

def Pprop(v):
    prof = P0*(1 + 3*v**2/U_tip**2)
    ind  = Pi*(np.sqrt(1 + v**4/(4*v0**4)) - v**2/(2*v0**2))**0.5
    par  = k*0.5*rho0*A_r*v**3
    return prof + ind + par
Pobs = lambda v: Pprop(v) + P_sens

H = np.array([8., 10., 12., 14., 15.])          # сетка воздушных скоростей
W = [(2.0, 245, 0.52), (5.0, 245, 0.24), (7.5, 240, 0.04), (3.5, 50, 0.20)]
W_MAX, G_MIN, ETA = 12.0, 3.0, 0.90

def wind_vec(w, psi_from_deg):
    """Вектор ветра в осях (восток, север). psi_from -- метеорологический пеленг."""
    psi_to = np.radians(psi_from_deg + 180.0)
    return w*np.array([np.sin(psi_to), np.cos(psi_to)])

def kinematics(course_deg, v, w, psi_from):
    """course_deg -- пеленг направления полёта (по часовой от севера)."""
    th = np.radians(course_deg)
    e  = np.array([np.sin(th), np.cos(th)])           # единичный вектор курса
    ep = np.array([np.cos(th), -np.sin(th)])          # правая нормаль
    wv = wind_vec(w, psi_from)
    w_par, w_perp = wv @ e, wv @ ep
    if abs(w_perp) >= v: return None
    g = np.sqrt(v**2 - w_perp**2) + w_par
    ok = (w <= W_MAX) and (abs(w_perp) < v) and (g >= G_MIN)
    return (g, w_par, w_perp, ok)

# ---------------- Рис. 4.2: кривая мощности ----------------
fig, ax = plt.subplots(1, 2, figsize=(7.4, 3.3))
vv = np.linspace(0, 20, 800)
prof = P0*(1 + 3*vv**2/U_tip**2)
ind  = Pi*(np.sqrt(1 + vv**4/(4*v0**4)) - vv**2/(2*v0**2))**0.5
par  = k*0.5*rho0*A_r*vv**3
ax[0].plot(vv, prof, '--', color='#2166ac', lw=1.2, label='профильная $P^{profile}$')
ax[0].plot(vv, ind,  '--', color='#1b7837', lw=1.2, label='индуктивная $P^{induced}$')
ax[0].plot(vv, par,  '--', color='#b2182b', lw=1.2, label='паразитная $P^{parasite}$')
ax[0].plot(vv, prof+ind+par, '-', color='k', lw=1.8, label='сумма $P^{prop}$')
ax[0].set_xlabel('воздушная скорость $v$, м/с'); ax[0].set_ylabel('мощность, Вт')
ax[0].legend(fontsize=7, loc='upper left'); ax[0].grid(alpha=.2, lw=.5)
ax[0].set_xlim(0, 20); ax[0].set_ylim(0, 250)
ax[0].set_title('три составляющие модели', fontsize=8.5)

Pt = Pobs(vv)
ax[1].plot(vv, Pt, '-', color='k', lw=1.8, label='$P^{obs}(v)=P^{prop}(v)+P^{sens}$')
spec = [(0, 191.362), (12, 166.556), (16, 200.796)]
ax[1].plot([s[0] for s in spec], [s[1] for s in spec], 'o', ms=8, mfc='#d73027',
           mec='k', mew=.8, zorder=5, label='паспортные точки')
im = np.argmin(Pt)
ax[1].plot(vv[im], Pt[im], 'v', ms=8, mfc='#fdae61', mec='k', mew=.8, zorder=5,
           label=f'внутренний минимум\n$v^*={vv[im]:.1f}$ м/с, {Pt[im]:.0f} Вт')
for h in H: ax[1].axvline(h, color='#888', lw=.6, ls=':')
ax[1].annotate('сетка $H$', xy=(11.5, 232), fontsize=7, color='#666')
ax[1].set_xlabel('воздушная скорость $v$, м/с'); ax[1].set_ylabel('$P^{obs}$, Вт')
ax[1].legend(fontsize=7, loc='upper left'); ax[1].grid(alpha=.2, lw=.5)
ax[1].set_xlim(0, 20); ax[1].set_ylim(140, 245)
ax[1].set_title('калиброванная кривая и паспортные точки', fontsize=8.5)
plt.tight_layout(); plt.savefig(str(FIGURES / 'fig_power.pdf'), bbox_inches='tight')
plt.savefig(str(FIGURES / 'fig_power.png'), dpi=150, bbox_inches='tight'); plt.close()

# ---------------- Рис. 4.3: путевая скорость по курсу ----------------
courses = np.arange(0, 360.5, 1.0)
fig = plt.figure(figsize=(7.4, 3.6))
cols = ['#92c5de', '#4393c3', '#b2182b', '#1b7837']
labs = ['$\\omega_1$: 2,0 м/с', '$\\omega_2$: 5,0 м/с',
        '$\\omega_3$: 7,5 м/с', '$\\omega_4$: 3,5 м/с']
for pi_, v in enumerate((10.0, 15.0)):
    axp = fig.add_subplot(1, 2, pi_+1, projection='polar')
    axp.set_theta_zero_location('N'); axp.set_theta_direction(-1)
    for (w, psi, p), c, lb in zip(W, cols, labs):
        g = []
        for cd in courses:
            r = kinematics(cd, v, w, psi)
            g.append(r[0] if r else np.nan)
        axp.plot(np.radians(courses), g, color=c, lw=1.5, label=lb)
    axp.plot(np.radians(courses), np.full_like(courses, v), 'k:', lw=.9,
             label='штиль')
    axp.plot(np.radians(courses), np.full_like(courses, G_MIN), 'r--', lw=.9,
             label='предел $g^{\\min}=3$ м/с')
    axp.set_rlim(0, v+9)
    axp.set_xticks(np.radians([0,45,90,135,180,225,270,315]))
    axp.set_xticklabels(['С','СВ','В','ЮВ','Ю','ЮЗ','З','СЗ'], fontsize=7.5)
    axp.tick_params(labelsize=6.5)
    axp.grid(alpha=.3, lw=.5)
    axp.set_title(f'$v_h={v:.0f}$ м/с', fontsize=9, pad=12)
    if pi_ == 1:
        axp.legend(fontsize=6.6, loc='upper left', bbox_to_anchor=(1.08, 1.12))
fig.suptitle('путевая скорость $g$ в зависимости от курса полёта', fontsize=9, y=1.02)
plt.tight_layout(); plt.savefig(str(FIGURES / 'fig_groundspeed.pdf'), bbox_inches='tight')
plt.savefig(str(FIGURES / 'fig_groundspeed.png'), dpi=150, bbox_inches='tight'); plt.close()

# ---------------- Рис. 4.4: удельная энергия по курсу и скорости ----------------
fig, axs = plt.subplots(1, 3, figsize=(7.6, 2.9), sharey=True)
scen_show = [(0, '$\\omega_1$: 2,0 м/с от 245°'),
             (1, '$\\omega_2$: 5,0 м/с от 245°'),
             (2, '$\\omega_3$: 7,5 м/с от 240°')]
speed_cols = plt.cm.viridis(np.linspace(0.05, 0.9, len(H)))
for ax_, (si, ttl) in zip(axs, scen_show):
    w, psi, p = W[si]
    for v, c in zip(H, speed_cols):
        e = []
        for cd in courses:
            r = kinematics(cd, v, w, psi)
            if r is None or not r[3] or r[0] <= 0: e.append(np.nan)
            else: e.append(Pobs(v)/r[0]*1000/3600)   # Вт*ч на километр
        ax_.plot(courses, e, color=c, lw=1.3, label=f'{v:.0f} м/с')
    ax_.set_title(ttl, fontsize=8)
    ax_.set_xlim(0, 360); ax_.set_xticks([0,90,180,270,360])
    ax_.set_xticklabels(['С','В','Ю','З','С'])
    ax_.grid(alpha=.2, lw=.5); ax_.set_xlabel('курс полёта')
axs[0].set_ylabel('энергия, Вт$\\cdot$ч на км')
axs[0].set_ylim(2, 14)
axs[2].legend(fontsize=6.8, title='$v_h$', title_fontsize=7, loc='upper right')
plt.tight_layout(); plt.savefig(str(FIGURES / 'fig_energy_course.pdf'), bbox_inches='tight')
plt.savefig(str(FIGURES / 'fig_energy_course.png'), dpi=150, bbox_inches='tight'); plt.close()

# ---------------- Рис. 4.5: оптимальный уровень скорости по курсу ----------------
fig, axs = plt.subplots(1, 2, figsize=(7.4, 3.0))
for ax_, (si, ttl) in zip(axs, [(1, '$\\omega_2$: 5,0 м/с от 245°'),
                                (2, '$\\omega_3$: 7,5 м/с от 240°')]):
    w, psi, p = W[si]
    best_v, best_e, worst_e = [], [], []
    for cd in courses:
        es = []
        for v in H:
            r = kinematics(cd, v, w, psi)
            es.append(np.nan if (r is None or not r[3] or r[0] <= 0)
                      else Pobs(v)/r[0]*1000/3600)
        es = np.array(es)
        if np.all(np.isnan(es)):
            best_v.append(np.nan); best_e.append(np.nan); worst_e.append(np.nan)
        else:
            best_v.append(H[np.nanargmin(es)])
            best_e.append(np.nanmin(es)); worst_e.append(np.nanmax(es))
    ax_.plot(courses, best_v, color='#b2182b', lw=1.8)
    ax_.set_ylim(7, 16); ax_.set_yticks(H)
    ax_.set_xlim(0, 360); ax_.set_xticks([0,90,180,270,360])
    ax_.set_xticklabels(['С','В','Ю','З','С'])
    ax_.set_xlabel('курс полёта'); ax_.set_ylabel('оптимальный $v_h$, м/с')
    ax_.grid(alpha=.2, lw=.5); ax_.set_title(ttl, fontsize=8.5)
    ax2 = ax_.twinx()
    ax2.fill_between(courses, best_e, worst_e, color='#4393c3', alpha=.18, lw=0)
    ax2.plot(courses, np.array(worst_e)/np.array(best_e), color='#2166ac', lw=1.1, ls='--')
    ax2.set_ylabel('худший / лучший уровень', color='#2166ac', fontsize=7.5)
    ax2.tick_params(axis='y', labelcolor='#2166ac', labelsize=7)
    ax2.set_ylim(1.0, 2.4)
plt.tight_layout(); plt.savefig(str(FIGURES / 'fig_optspeed.pdf'), bbox_inches='tight')
plt.savefig(str(FIGURES / 'fig_optspeed.png'), dpi=150, bbox_inches='tight'); plt.close()

# ---------------- числовые сводки для текста ----------------
print("=== удельная энергия (Вт*ч/км) на встречном / попутном / боковом курсе")
print(f"{'сценарий':>12} {'v':>4} {'встречный':>10} {'попутный':>9} {'боковой':>8} {'отн.':>6}")
for (w, psi, p), nm in zip(W, ['w1 2.0','w2 5.0','w3 7.5','w4 3.5']):
    head = (psi) % 360            # лететь ПРОТИВ ветра = курс на источник
    tail = (psi + 180) % 360
    side = (psi + 90) % 360
    for v in H:
        vals = []
        for cd in (head, tail, side):
            r = kinematics(cd, v, w, psi)
            vals.append(np.nan if (r is None or not r[3] or r[0] <= 0)
                        else Pobs(v)/r[0]*1000/3600)
        rel = vals[0]/vals[1] if not np.isnan(vals[0]) else np.nan
        print(f"{nm:>12} {v:4.0f} {vals[0]:10.3f} {vals[1]:9.3f} {vals[2]:8.3f} {rel:6.2f}")

print("\n=== вероятность допустимости pi по курсу (минимум и где)")
for v in H:
    pis = []
    for cd in courses:
        s = 0.0
        for (w, psi, p) in W:
            r = kinematics(cd, v, w, psi)
            if r and r[3]: s += p
        pis.append(s)
    pis = np.array(pis)
    print(f"v={v:4.0f} м/с: min pi = {pis.min():.2f} на курсе {courses[np.argmin(pis)]:.0f}°, "
          f"доля курсов с pi>=eta: {100*np.mean(pis>=ETA):.1f} %")

print("\n=== ожидаемое и наихудшее время на 10 км по курсу (v=15 м/с)")
print(f"{'курс':>6} {'T_exp, с':>9} {'T_wc, с':>8} {'отн.':>6}")
for cd in (0, 45, 65, 90, 135, 180, 225, 245, 270, 315):
    ts, ps = [], []
    for (w, psi, p) in W:
        r = kinematics(cd, 15.0, w, psi)
        if r and r[3]:
            ts.append(10000/r[0]); ps.append(p)
    if not ts: continue
    ts, ps = np.array(ts), np.array(ps)
    Texp = (ts*ps).sum()/ps.sum(); Twc = ts.max()
    print(f"{cd:6.0f} {Texp:9.1f} {Twc:8.1f} {Twc/Texp:6.3f}")
print("\nготово")
