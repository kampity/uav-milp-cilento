function ok = cilento_pretests()
%CILENTO_PRETESTS  Section 10.1b - unit tests of the preprocessing itself.
%
%   ok = cilento_pretests()
%
%   cilento_verify replays a solution against the SAME precomputed
%   coefficients the MILP used.  That catches a wrong constraint but not a
%   wrong coefficient: an error in the wind decomposition, the ground speed or
%   the worst-case energy would land in the model and in the checker alike and
%   cancel out.  These tests close that gap -- every geometry here is simple
%   enough to compute by hand.

SC_T = 1/60;  SC_E = 1/3600;
N = 0;  BAD = 0;

%% -------------------------------------------------- wind decomposition ----
% Frame: x = east, y = north.  Direction is where the wind blows FROM,
% clockwise from north.  On an EASTBOUND leg:
%   FROM 270 (west)  -> pure tailwind,  ground speed v + w
%   FROM  90 (east)  -> pure headwind,  ground speed v - w
%   FROM 180 (south) -> pure crosswind, ground speed sqrt(v^2 - w^2)
v = 12; w = 4; d = 3000;
cases = {270, 'tailwind  (FROM west)',  v + w
          90, 'headwind  (FROM east)',  v - w
         180, 'crosswind (FROM south)', sqrt(v^2 - w^2)};
for c = 1:3
    pre = one_arc(cases{c,1}, w, v, d);
    ia = arc(pre, pre.dplus, pre.F(1));
    T = pre.Tsched(ia,1)/SC_T;
    near(sprintf('5.2 ground speed, %s', cases{c,2}), d/T, cases{c,3}, 'm/s');
end

pre = one_arc(270, w, v, d);
ia = arc(pre, pre.dplus, pre.F(1));  ib = arc(pre, pre.F(1), pre.dminus);
near('5.2 outbound leg with tailwind', d/(pre.Tsched(ia,1)/SC_T), v+w, 'm/s');
near('5.2 return leg becomes headwind', d/(pre.Tsched(ib,1)/SC_T), v-w, 'm/s');

%% ------------------------------------------ worst case over scenarios -----
Om = [4 270 0.7; 4 90 0.3];            % tailwind fast, headwind slow
pre = one_arc(270, 4, v, d, Om);
ia = arc(pre, pre.dplus, pre.F(1));  ib = arc(pre, pre.F(1), pre.dminus);
t_fast = d/(v+4);  t_slow = d/(v-4);
near('5.4 T_exp is the probability weighted mean', ...
     pre.Tsched(ia,1)/SC_T, 0.7*t_fast + 0.3*t_slow, 's');
near('5.4 T_wc is the worst admissible scenario', ...
     pre.Twc(ia,1)/SC_T, t_slow, 's');
Pv = power_at(pre, v);
near('5.4 E_hat_wc adds take-off leaving the depot', ...
     pre.Ehatwc(ia,1)/SC_E, Pv*t_slow + 4800, 'J');
% on the RETURN leg the scenarios swap roles, so the worst case is the same
% slow time, now carrying the landing energy instead of take-off
near('5.4 E_hat_wc adds landing entering the depot', ...
     pre.Ehatwc(ib,1)/SC_E, Pv*t_slow + 5700, 'J');

%% -------------------------------------------- admissibility filter --------
Om = [4 270 0.85; 7 90 0.15];          % headwind 7 m/s -> ground speed 1 m/s
pre = one_arc(270, 4, 8, d, Om, 0.90, 3);
yes('5.2 arc dropped when pi < eta_adm (0.85 < 0.90)', ...
    isempty(arc(pre, pre.dplus, pre.F(1))));
pre = one_arc(270, 4, 8, d, Om, 0.80, 3);
ia = arc(pre, pre.dplus, pre.F(1));
yes('5.2 arc kept when pi >= eta_adm (0.85 >= 0.80)', ~isempty(ia));
if ~isempty(ia)
    near('5.2 expectation renormalised over admissible scenarios', ...
         pre.Tsched(ia,1)/SC_T, d/(8+4), 's');
end

%% ----------------------------------------------- emergency response -------
in = still_air(15, 6000);  in.T_resp = 600;
pre = cilento_pre(in);
near('7.14 P4 worst-case response flight time', ...
     pre.screens.P4_travel, 6000/15, 's');
yes('7.14 P4 passes when the flight fits T_resp', pre.screens.P4_ok);
in2 = in;  in2.T_resp = 300;
pre2 = cilento_pre(in2);
yes('7.14 P4 rejects when T_resp is too short', ~pre2.screens.P4_ok);

Pv = power_at(pre, 15);  Pobs = pre.P_obs;
t = 6000/15;
margin = in.Q_nom*in.gamma_use*(1-in.rho_res) ...
         - (Pv*t + in.E_TO) - Pobs*in.tau_C1_min - (Pv*t + in.E_LD);
near('7.14 P5 reserve battery margin', pre.screens.P5_margin, margin, 'J');

%% ------------------------------------------------ reachability screen -----
in = still_air(15, 4000);
in.F = [3000 0; 30000 0];
pre = cilento_pre(in);
yes('2.3 P6 names exactly the out-of-range node', ...
    isequal(pre.screens.P6_unreachable, {'F2'}));

fprintf('\n%d/%d preprocessing checks passed\n', N - BAD, N);
ok = (BAD == 0);

% =========================================================================
    function near(name, got, want, unit)
        N = N + 1;
        good = abs(got - want) <= 1e-6 + 1e-6*abs(want);
        if ~good, BAD = BAD + 1; end
        fprintf('[%s] %-52s got %12.6f %-4s expected %12.6f\n', ...
                tf(good), name, got, unit, want);
    end
    function yes(name, good)
        N = N + 1;
        if ~good, BAD = BAD + 1; end
        fprintf('[%s] %-52s\n', tf(good), name);
    end
end

% =========================================================================
function s = tf(ok), if ok, s = 'PASS'; else, s = 'FAIL'; end, end

function ia = arc(pre, i, j)
ia = find(pre.A(:,1)==i & pre.A(:,2)==j, 1);
end

function P = power_at(pre, v)
%POWER_AT  Rebuild the calibrated propulsion power at speed v, sea level.
U = 100;  rho0 = 1.225;  A_r = 4*pi*(0.328/2)^2;  g0 = 9.80665;
v0 = sqrt(1.85*g0/(2*rho0*A_r));
P = pre.P0_0*(1 + 3*v^2/U^2) ...
    + pre.Pi_0*sqrt(sqrt(1 + v^4/(4*v0^4)) - v^2/(2*v0^2)) ...
    + pre.k_0*0.5*rho0*A_r*v^3 + 30;
end

function in = still_air(v, d)
in.depot = [0 0];  in.c1 = [d 0];  in.F = [d d];  in.stations = struct([]);
in.tau_obs = 300;  in.O_C1 = 120;  in.tau_C1_min = 600;  in.tau_C1_max = 1200;
in.T_C1_start = 900;  in.T_C1_end = 2400;  in.T_max = 14400;
in.K_max = 2;  in.R = 2;  in.T_resp = 900;  in.N_res = 0;
in.Q_nom = 149.9*3600;  in.gamma_use = 0.90;  in.rho_res = 0.20;
in.P_sens = 30;  in.E_TO = 4800;  in.E_LD = 5700;
in.H = v;  in.w_max = 30;  in.g_min = 0;  in.eta_adm = 1.0;
in.Omega = [0 0 1];  in.wind_mode = 'hybrid';
in.mass = 1.85;  in.d_prop = 0.328;  in.alt_op = 0;
end

function pre = one_arc(psi_from, w, v, d, Om, eta, gmin)
%ONE_ARC  One F node d metres due EAST of the depot, one wind scenario, one
%cruise speed: everything about that leg is then hand computable.
if nargin < 5 || isempty(Om),   Om   = [w psi_from 1]; end
if nargin < 6 || isempty(eta),  eta  = 1.0; end
if nargin < 7 || isempty(gmin), gmin = 0;   end
in = still_air(v, d);
in.c1 = [0 2*d];  in.F = [d 0];
in.tau_C1_min = 300;  in.T_C1_start = 600;  in.T_C1_end = 1800;
in.Omega = Om;  in.eta_adm = eta;  in.g_min = gmin;
pre = cilento_pre(in);
end
