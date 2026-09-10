function pre = cilento_pre(inst)
% CILENTO_PRE  Section 5 preprocessing: propulsion calibration, wind
% decomposition, ground speed, per-arc/per-speed coefficients, safe-recovery
% energies and the explicit bounds of Section 4.6.
%
% OUTPUT UNITS ARE MINUTES AND WATT-HOURS.  The formalization is stated in
% seconds and joules; scaling is applied here because the unscaled coefficient
% range spans six orders of magnitude and the solver becomes numerically
% unreliable.

SC_T = 1/60;  SC_E = 1/3600;  g0 = 9.80665;  rho0 = 1.225;

% Section 10.4: how the scenario set becomes planning coefficients.
%   'nowind'   wind ignored at planning time (single calm scenario)
%   'expected' expectation used for timing AND for battery feasibility
%   'hybrid'   expectation for timing, worst case for arrivals at C1 and for
%              every battery constraint -- the formulation of Section 5.4
if isfield(inst,'wind_mode') && ~isempty(inst.wind_mode)
    mode = inst.wind_mode;
else
    mode = 'hybrid';
end
assert(any(strcmp(mode,{'nowind','expected','hybrid'})), ...
       'unknown wind_mode %s', mode);
if strcmp(mode,'nowind'), Omega = [0 0 1]; else, Omega = inst.Omega; end
pre.wind_mode = mode;

%% ---------------------------------------- 5.3 propulsion calibration
A_r  = 4*pi*(inst.d_prop/2)^2;
v0_0 = sqrt(inst.mass*g0/(2*rho0*A_r));
U_tip = 100;                         % fixed, see Section 5.3.1
hoverW = 191.4; c12W = 166.6; c16W = 200.8;      % Matrice 4TD checks [6]

aa = @(v) 1 + 3*v.^2/U_tip^2;
bb = @(v,v0) sqrt(max(sqrt(1+v.^4./(4*v0^4)) - v.^2./(2*v0^2), 0));
cc = @(v,rho) 0.5*rho*A_r*v.^3;

Mcal = [1,               1,                0;
        aa(12), bb(12,v0_0), cc(12,rho0);
        aa(16), bb(16,v0_0), cc(16,rho0)];
rhs  = [hoverW - inst.P_sens; c12W - inst.P_sens; c16W - inst.P_sens];
if rcond(Mcal) < 1e-12
    warning('calibration matrix is ill-conditioned; check U_tip and v_0');
end
sol  = Mcal \ rhs;
pre.P0_0 = sol(1); pre.Pi_0 = sol(2); pre.k_0 = sol(3);
pre.residuals = (Mcal*sol - rhs).';

% altitude correction (Section 5.3.1)
rho_a = rho0*(1 - 2.25577e-5*inst.alt_op)^4.2559;
rr    = rho_a/rho0;
P0 = pre.P0_0*rr;  Pi = pre.Pi_0/sqrt(rr);  v0 = v0_0/sqrt(rr);
Pprop = @(v) P0*aa(v) + Pi*bb(v,v0) + pre.k_0*cc(v,rho_a);

pre.P_hover = P0 + Pi;
pre.P_obs   = pre.P_hover + inst.P_sens;          % W
pre.P_obs_min = pre.P_obs/60;                     % Wh per minute
nH = numel(inst.H);  pre.nH = nH;
Pv = arrayfun(@(v) Pprop(v) + inst.P_sens, inst.H);   % W

%% ---------------------------------------- node layout (Section 3)
XY = inst.depot;  kind = 'd';  tagS = {'d+'};
Fi = []; Ci = []; Si = []; station_of = []; bay_of = [];
for i = 1:size(inst.F,1)
    XY(end+1,:) = inst.F(i,:); kind(end+1) = 'F'; Fi(end+1) = size(XY,1); %#ok
    tagS{end+1} = sprintf('F%d',i);
end
for r = 1:inst.R
    XY(end+1,:) = inst.c1; kind(end+1) = 'C'; Ci(end+1) = size(XY,1); %#ok
    tagS{end+1} = sprintf('c%d',r);
end
for si = 1:numel(inst.stations)
    st = inst.stations(si);
    for b = 1:st.bays
        for m = 1:st.visits
            XY(end+1,:) = st.xy; kind(end+1) = 'S'; %#ok
            Si(end+1) = size(XY,1); station_of(size(XY,1)) = si; %#ok
            bay_of(size(XY,1),:) = [si b m]; %#ok
            tagS{end+1} = sprintf('s%db%dm%d',si,b,m);
        end
    end
end
XY(end+1,:) = inst.depot; kind(end+1) = 'd'; tagS{end+1} = 'd-';
n = size(XY,1);
pre.n = n; pre.xy = XY; pre.kind = kind; pre.tag = tagS;
pre.dplus = 1; pre.dminus = n; pre.F = Fi; pre.C = Ci; pre.S = Si;
pre.No = [Fi Ci Si];
pre.station_of = station_of;
pre.chi = double(kind=='F' | kind=='C');
pre.Cidx = zeros(1,n); pre.Cidx(Ci) = 1:numel(Ci);

%% ---------------------------------------- 5.1-5.2, 5.4 coefficients
A = []; Tsched = []; Ehatwc = []; Eexp = []; Hok = {}; Twc = [];
Gplus  = [pre.dplus Si];  Gminus = [Si pre.dminus];
for i = 1:n
    for j = 1:n
        if i==j || j==pre.dplus || i==pre.dminus, continue, end
        if i==pre.dplus && j==pre.dminus, continue, end
        if kind(i)=='C' && kind(j)=='C', continue, end
        if kind(i)=='S' && kind(j)=='S' && station_of(i)==station_of(j), continue, end
        d = norm(XY(j,:)-XY(i,:));  if d < 1e-9, continue, end
        ev = (XY(j,:)-XY(i,:))/d;  eperp = [-ev(2) ev(1)];
        Ts = nan(1,nH); Ee = nan(1,nH); Ew = nan(1,nH); Tw = nan(1,nH);
        ok = false(1,nH);
        for h = 1:nH
            v = inst.H(h);  Tk = []; Ek = []; pk = [];
            for w = 1:size(Omega,1)
                % METEOROLOGICAL convention: Omega(:,2) is the direction the
                % wind blows FROM, degrees clockwise from north, in a frame
                % x = east, y = north.  A compass bearing b is the unit vector
                % [sin(b) cos(b)]; using [cos(b) sin(b)] would measure
                % counterclockwise from east and rotate every scenario.
                ws = Omega(w,1); psi = deg2rad(Omega(w,2) + 180);
                Wv = ws*[sin(psi) cos(psi)];
                wpar = Wv*ev.'; wperp = Wv*eperp.';
                feas = ws <= inst.w_max && abs(wperp) < v;
                if feas
                    gsp = sqrt(v^2 - wperp^2) + wpar;
                    feas = gsp >= inst.g_min;
                end
                if feas
                    Tk(end+1) = d/gsp; Ek(end+1) = Pv(h)*d/gsp; %#ok
                    pk(end+1) = Omega(w,3); %#ok
                end
            end
            piv = sum(pk);
            if piv + 1e-12 < inst.eta_adm, continue, end
            pm = pk/sum(pk);
            if strcmp(mode,'hybrid')
                % worst case only where a late arrival breaks the relay chain
                Ts(h) = (kind(j)=='C')*max(Tk) + (kind(j)~='C')*(pm*Tk.');
                Ebat  = max(Ek);
            else
                Ts(h) = pm*Tk.';
                Ebat  = pm*Ek.';
            end
            Ee(h) = pm*Ek.';
            Ew(h) = Ebat + inst.E_TO*any(Gplus==i) + inst.E_LD*any(Gminus==j);
            Tw(h) = max(Tk);                    % worst case, needed by P4
            ok(h) = true;
        end
        if ~any(ok), continue, end
        A(end+1,:) = [i j]; %#ok
        Tsched(end+1,:) = Ts*SC_T; %#ok
        Twc(end+1,:)    = Tw*SC_T; %#ok
        Eexp(end+1,:)   = Ee*SC_E; %#ok
        Ehatwc(end+1,:) = Ew*SC_E; %#ok
        Hok{end+1} = find(ok); %#ok
    end
end
Tsched(isnan(Tsched)) = 0; Eexp(isnan(Eexp)) = 0; Ehatwc(isnan(Ehatwc)) = 0;
Twc(isnan(Twc)) = 0;
pre.A = A; pre.Tsched = Tsched; pre.Eexp = Eexp; pre.Ehatwc = Ehatwc;
pre.Twc = Twc;
pre.Hok = Hok; pre.nAH = sum(cellfun(@numel,Hok));

%% ---------------------------------------- 5.5 safe recovery
ground = [Si pre.dminus];
pre.Esafe = inf(1,n);
for i = pre.No
    if kind(i)=='S', pre.Esafe(i) = 0; continue, end
    m = inf;
    for ia = 1:size(A,1)
        if A(ia,1)==i && any(ground==A(ia,2))
            m = min(m, min(Ehatwc(ia, Hok{ia})));
        end
    end
    pre.Esafe(i) = m;
end

%% ---------------------------------------- 4.6 explicit bounds
pre.T_max = inst.T_max*SC_T;  pre.tau_obs = inst.tau_obs*SC_T;
pre.O_C1 = inst.O_C1*SC_T;
pre.tau_C1_min = inst.tau_C1_min*SC_T;  pre.tau_C1_max = inst.tau_C1_max*SC_T;
pre.T_C1_start = inst.T_C1_start*SC_T;  pre.T_C1_end = inst.T_C1_end*SC_T;
pre.Q = inst.gamma_use*inst.Q_nom*SC_E;
pre.E_TO = inst.E_TO*SC_E;  pre.E_LD = inst.E_LD*SC_E;
pre.dmin = arrayfun(@(s) s.dmin*SC_T, inst.stations);
pre.dmax = arrayfun(@(s) s.dmax*SC_T, inst.stations);
pre.chg_rate = arrayfun(@(s) s.eta_ch*s.P_rated/60, inst.stations);   % Wh/min

Tbar = max(Tsched(:));  taubar = max([pre.tau_obs pre.tau_C1_max pre.dmax]);
pre.M_T  = pre.T_max + Tbar + taubar;
pre.Wbar = min(pre.T_max, pre.Q*(1-inst.rho_res)/pre.P_obs_min);
Ewaitmax = pre.P_obs_min*pre.Wbar;
Ebarfly  = max(Ehatwc(:));
Esrvmax  = pre.P_obs_min*max(pre.tau_obs, pre.tau_C1_max);
EC1max   = pre.P_obs_min*pre.tau_C1_max;
Esafemax = max(pre.Esafe(isfinite(pre.Esafe)));
pre.MB_arc   = pre.Q + Ebarfly;
pre.MB_node  = Esrvmax + Ewaitmax;
pre.MB_ready = Ewaitmax + EC1max + Esafemax + inst.rho_res*pre.Q;
pre.MB_safe  = Esafemax + inst.rho_res*pre.Q;

%% ---------------------------------------- bay sequences (7.11)
pre.bayseq = {};
for si = 1:numel(inst.stations)
    for b = 1:inst.stations(si).bays
        sq = Si(bay_of(Si,1)==si & bay_of(Si,2)==b);
        if numel(sq) > 1, pre.bayseq{end+1} = sq; end %#ok
    end
end

%% ---------------------------------------- 2.3 screens
c1 = Ci(1);
cand = [];
for ia = 1:size(A,1)
    if A(ia,1)==pre.dplus && A(ia,2)==c1
        cand(end+1) = min(Tsched(ia,Hok{ia}))/SC_T; %#ok
    end
end
if isempty(cand), sc.P1_min_travel = inf; else, sc.P1_min_travel = min(cand); end
sc.P1_ok = ~isempty(cand) && inst.T_C1_start >= sc.P1_min_travel;
Ein = []; Eout = [];
for ia = 1:size(A,1)
    if A(ia,2)==c1 && any([Si pre.dplus pre.dminus]==A(ia,1))
        Ein(end+1) = min(Ehatwc(ia,Hok{ia})); end %#ok
    if A(ia,1)==c1 && any([Si pre.dplus pre.dminus]==A(ia,2))
        Eout(end+1) = min(Ehatwc(ia,Hok{ia})); end %#ok
end
if ~isempty(Ein) && ~isempty(Eout)
    sc.tau_bat = (pre.Q*(1-inst.rho_res) - min(Ein) - min(Eout))/pre.P_obs_min/SC_T;
else, sc.tau_bat = -inf; end
sc.tau_eff = min(inst.tau_C1_max, sc.tau_bat);
sc.P2_ok   = sc.tau_eff >= max(inst.tau_C1_min, inst.O_C1);
L = inst.T_C1_end - inst.T_C1_start;
if sc.tau_eff > inst.O_C1
    sc.R_LB = max(2, ceil((L - inst.O_C1)/(sc.tau_eff - inst.O_C1)));
else, sc.R_LB = inf; end
sc.P3_ok = inst.R >= sc.R_LB;

%% ---------------------------------------- 7.14 emergency response (P4/P5)
% The MILP puts a reserve airframe in the fleet and forbids it a working
% route, which proves it EXISTS.  It does not prove it could do the job.
% Section 7.14 asks two things of the chosen base, and both are preprocessing
% questions: they depend on the base and the airframe, not on the routing.
%   P4  some cruise speed reaches C1 within T_resp in the worst wind
%   P5  at THAT speed the battery covers the flight out, the minimum duty,
%       the safe-recovery leg and the untouchable reserve
% Both must hold for the same speed, otherwise the reserve meets the deadline
% only by flying a leg it has not the energy for.
E_need = pre.P_obs*inst.tau_C1_min + pre.Esafe(c1)/SC_E;
usable = inst.Q_nom*inst.gamma_use*(1 - inst.rho_res);
best_t = inf; best_m = -inf; ok_any = false;
for ia = 1:size(A,1)
    if A(ia,1) ~= pre.dplus || A(ia,2) ~= c1, continue, end
    for h = Hok{ia}
        t_h = Twc(ia,h)/SC_T;
        m_h = usable - Ehatwc(ia,h)/SC_E - E_need;
        best_t = min(best_t, t_h);
        if t_h <= inst.T_resp
            best_m = max(best_m, m_h);
            if m_h >= 0, ok_any = true; end
        end
    end
end
sc.P4_travel = best_t;
sc.P4_ok = isfinite(best_t) && best_t <= inst.T_resp;
if isfinite(best_m), sc.P5_margin = best_m; else, sc.P5_margin = -inf; end
sc.P5_ok = ok_any;

%% ---------------------------------------- 2.3 reachability screen (P6)
% P1-P5 are all about C1.  Nothing above looks at an ordinary monitoring
% site, and a single out-of-range site makes the MILP infeasible for every
% fleet size with no indication of which site is at fault.  For each node take
% the cheapest way in from a launch point, the service it must receive and the
% cheapest way out to a landing point; if that already exceeds the usable
% battery, no routing decision can rescue it.
launch = [pre.dplus Si];
landing = [Si pre.dminus];

min_slack = inf;
bad = {};

% P6 applies only to mandatory nodes:
% historical fire points F and C1 copies C.
% Optional charging copies S must not make the instance infeasible.
for i = [pre.F pre.C]

    ein = inf;
    eout = inf;

    for ia = 1:size(A,1)
        if A(ia,2)==i && any(launch==A(ia,1))
            ein = min(ein, min(Ehatwc(ia,Hok{ia}))/SC_E);
        end
        if A(ia,1)==i && any(landing==A(ia,2))
            eout = min(eout, min(Ehatwc(ia,Hok{ia}))/SC_E);
        end
    end
    switch kind(i)
        case 'F', esrv = pre.P_obs*inst.tau_obs;
        case 'C', esrv = pre.P_obs*inst.tau_C1_min;
        otherwise, esrv = 0;
    end
    slack_Wh = (usable - (ein + esrv + eout))/3600;
    min_slack = min(min_slack, slack_Wh);
    if ~(slack_Wh >= 0), bad{end+1} = tagS{i}; end %#ok<AGROW>
end
sc.P6_ok = isempty(bad);
sc.P6_min_slack_Wh = min_slack;      % positive = headroom, negative = deficit
sc.P6_unreachable = bad;

pre.screens = sc;
end
