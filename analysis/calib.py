#!/usr/bin/env python3
"""Калибровка модели мощности Matrice 4TD и производные величины главы 4."""

# --- repo-relative paths (added for public release) ---
from pathlib import Path as _Path
ROOT = _Path(__file__).resolve().parents[1]
RESULTS = ROOT / 'results'
FIGURES = ROOT / 'figures'
FIGURES.mkdir(exist_ok=True)
BASE = str(RESULTS) + '/'
# ------------------------------------------------------

import numpy as np

# ---------- паспортные данные ----------
Q_nom = 149.9          # Вт*ч
m     = 1.85           # кг
D_eff = 0.328          # м, эффективный диаметр винта
t_hov = 47/60          # ч
t_12  = 54/60          # ч
R_16  = 43000          # м при 16 м/с
P_sens= 30.0           # Вт
U_tip = 100.0          # м/с
rho0  = 1.225          # кг/м^3
g_acc = 9.80665

A_r = 4*np.pi*(D_eff/2)**2
W   = m*g_acc
v0_0= np.sqrt(W/(2*rho0*A_r))

t_16_h = (R_16/16)/3600
P_hov = Q_nom/t_hov
P_12  = Q_nom/t_12
P_16  = Q_nom/t_16_h

print("=== геометрия и опорные величины")
print(f"A_r            = {A_r:.5f} м^2")
print(f"W = m g        = {W:.4f} Н")
print(f"v0 (уровень моря) = {v0_0:.4f} м/с")
print(f"t(16 м/с)      = {R_16/16:.1f} с = {t_16_h:.6f} ч")
print(f"P_avg^hover    = {P_hov:.3f} Вт")
print(f"P_avg^12       = {P_12:.3f} Вт")
print(f"P_avg^16       = {P_16:.3f} Вт")

# ---------- линейная система по (P0, Pi, k=d0*s_r) ----------
def prof_coef(v): return 1 + 3*v**2/U_tip**2
def ind_coef(v, v0):
    return (np.sqrt(1 + v**4/(4*v0**4)) - v**2/(2*v0**2))**0.5
def par_coef(v, rho): return 0.5*rho*A_r*v**3

rows, rhs = [], []
for v, Ptot in ((0.0, P_hov), (12.0, P_12), (16.0, P_16)):
    rows.append([prof_coef(v), ind_coef(v, v0_0), par_coef(v, rho0)])
    rhs.append(Ptot - P_sens)
A = np.array(rows); b = np.array(rhs)
sol = np.linalg.solve(A, b)
P0, Pi, k = sol
res = A@sol - b

print("\n=== результат калибровки (условия уровня моря)")
print(f"P_0        = {P0:.4f} Вт")
print(f"P_i        = {Pi:.4f} Вт")
print(f"d_0 * s_r  = {k:.6f}")
print(f"P_0 + P_i  = {P0+Pi:.4f} Вт   (висение, без нагрузки)")
print(f"невязки    = {np.abs(res).max():.3e} Вт")
print(f"положительность: P0>0 {P0>0}, Pi>0 {Pi>0}, k>0 {k>0}")

def Pprop(v, P0=P0, Pi=Pi, k=k, v0=v0_0, rho=rho0):
    return P0*prof_coef(v) + Pi*ind_coef(v, v0) + k*par_coef(v, rho)

print("\n=== таблица мощности (уровень моря)")
print(f"{'v':>5} {'P_profile':>10} {'P_induced':>10} {'P_parasite':>11} {'P_prop':>9} {'P_obs':>9}")
for v in (0,2,4,6,8,9,10,12,14,15,16,18,20):
    pp = P0*prof_coef(v); pin = Pi*ind_coef(v,v0_0); ppa = k*par_coef(v,rho0)
    print(f"{v:5.0f} {pp:10.2f} {pin:10.2f} {ppa:11.2f} {pp+pin+ppa:9.2f} {pp+pin+ppa+P_sens:9.2f}")

vv = np.linspace(0.01, 20, 20000)
PP = Pprop(vv)
imin = np.argmin(PP)
print(f"\nминимум кривой: v* = {vv[imin]:.3f} м/с, P_prop = {PP[imin]:.3f} Вт, "
      f"P_obs = {PP[imin]+P_sens:.3f} Вт")

# минимум удельной энергии на километр в штиль
Ekm = (PP + P_sens)/vv
jmin = np.argmin(Ekm)
print(f"минимум удельной энергии (штиль): v = {vv[jmin]:.3f} м/с, "
      f"{Ekm[jmin]:.2f} Дж/м = {Ekm[jmin]*1000/3600:.3f} Вт*ч/км")

# ---------- коррекция по плотности ----------
def isa_rho(h):
    return rho0*(1 - 2.25577e-5*h)**4.25588

elev_north = [452, 313, 24, 479, 540, 50]     # база, C1, F..., ЗС
z_rep = np.mean(elev_north) + 150
rho_z = isa_rho(z_rep)
print("\n=== коррекция по плотности (северный сектор)")
print(f"средняя высота узлов = {np.mean(elev_north):.2f} м; репрезентативная z = {z_rep:.2f} м")
print(f"rho_a(z) = {rho_z:.5f} кг/м^3;  rho_a/rho_0 = {rho_z/rho0:.5f}")
P0z = P0*rho_z/rho0
Piz = Pi*np.sqrt(rho0/rho_z)
v0z = v0_0*np.sqrt(rho0/rho_z)
print(f"P_0(z) = {P0z:.3f} Вт  ({100*(P0z/P0-1):+.2f} %)")
print(f"P_i(z) = {Piz:.3f} Вт  ({100*(Piz/Pi-1):+.2f} %)")
print(f"v_0(z) = {v0z:.4f} м/с ({100*(v0z/v0_0-1):+.2f} %)")
print(f"P_hover(z) = {P0z+Piz:.3f} Вт ({100*((P0z+Piz)/(P0+Pi)-1):+.2f} %)")

print(f"\n{'v':>5} {'P_prop(0 м)':>12} {'P_prop(z)':>11} {'разн., %':>9}")
for v in (8,10,12,14,15,16):
    a = Pprop(v)
    bz = Pprop(v, P0z, Piz, k, v0z, rho_z)
    print(f"{v:5.0f} {a:12.2f} {bz:11.2f} {100*(bz/a-1):9.2f}")

# ---------- энергетический бюджет ----------
gamma, rho_res = 0.90, 0.20
Q = gamma*Q_nom
Ework = Q*(1-rho_res)
print("\n=== энергетический бюджет")
print(f"Q = {gamma}*{Q_nom} = {Q:.3f} Вт*ч ;  Q(1-rho) = {Ework:.3f} Вт*ч")
Pobs_hov = P_hov     # проверочная мощность висения (весь аппарат)
for tau in (300, 900):
    Eo = Pobs_hov*tau/3600
    print(f"tau_obs = {tau:4d} с -> E_obs = {Pobs_hov*tau:8.0f} Дж = {Eo:6.3f} Вт*ч "
          f"= {100*Eo/Q_nom:5.2f} % номинала = {100*Eo/Ework:5.2f} % рабочего бюджета")
print(f"предел чистого висения: {Ework*3600/Pobs_hov:.1f} с = {Ework*3600/Pobs_hov/60:.2f} мин")
for g95 in (0.95,):
    Ew2 = g95*Q_nom*(1-rho_res)
    print(f"при gamma={g95}: Q(1-rho) = {Ew2:.3f} Вт*ч, "
          f"предел висения {Ew2*3600/Pobs_hov/60:.2f} мин")

print("\n=== симметричный радиус одной миссии, штиль")
print(f"{'v, м/с':>7} {'P_obs, Вт':>10} {'L(300 с), км':>13} {'L(900 с), км':>13}")
for v in (8,10,12,14,15,16):
    Po = Pprop(v)+P_sens
    for tau, store in ((300,[]),(900,[])):
        pass
    L300 = (Ework - Pobs_hov*300/3600)*3600*v/(2*Po)/1000
    L900 = (Ework - Pobs_hov*900/3600)*3600*v/(2*Po)/1000
    print(f"{v:7.0f} {Po:10.2f} {L300:13.2f} {L900:13.2f}")

np.save(str(RESULTS / 'calib.npy'), np.array([P0,Pi,k,v0_0,A_r,rho0,P_sens,U_tip]))
