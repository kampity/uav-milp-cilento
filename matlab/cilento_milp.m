function M = cilento_milp(inst, pre, K, Nres, opts)
% CILENTO_MILP  Wind-aware multi-UAV routing MILP (YALMIP + Gurobi).
%
%   M = cilento_milp(inst, pre, K, Nres, opts)
%
%   Mirrors the Python reference implementation constraint for constraint.
%   Every block carries the section number of the mathematical formalization.
%
%   UNITS.  The formalization is written in seconds and joules; the model is
%   BUILT AND SOLVED in minutes and watt-hours (scaling done in cilento_pre).
%   Unscaled, the coefficients span six orders of magnitude and the solver
%   becomes numerically unreliable.
%
%   NOTE.  z is a 1-by-K CELL array of nA-by-nH binary matrices.  YALMIP does
%   not support three-dimensional binvar, so z{k}(ia,h) is used throughout.

if nargin < 4 || isempty(Nres), Nres = 0; end
if nargin < 5 || isempty(opts)
    opts = sdpsettings('solver','gurobi','verbose',0, ...
                       'gurobi.TimeLimit',300,'gurobi.MIPGap',1e-4, ...
                       'gurobi.NumericFocus',1);
end

n  = pre.n;   No = pre.No;   A = pre.A;   nA = size(A,1);
nH = pre.nH;  R  = inst.R;
MT = pre.M_T; Q  = pre.Q;    rho = inst.rho_res;
Ph = pre.P_obs_min;                      % Wh per minute

%% ------------------------------------------- Section 6: decision variables
u = binvar(K,1); s = binvar(K,1); e = binvar(K,1);
x = binvar(nA,K,'full');
z = cell(1,K);  for k = 1:K, z{k} = binvar(nA,nH,'full'); end
r = binvar(n,K,'full');
q = sdpvar(n,K,'full');

tdep = sdpvar(K,1);
tarr = sdpvar(n,K,'full');  W  = sdpvar(n,K,'full');
tt   = sdpvar(n,K,'full');  Cc = sdpvar(n,K,'full');
tret = sdpvar(K,1);         Tmake = sdpvar(1,1);
barr = sdpvar(n,K,'full');  bdep  = sdpvar(n,K,'full');
alpha = sdpvar(R,1);        beta  = sdpvar(R,1);
delta = sdpvar(n,K,'full'); gch   = sdpvar(n,K,'full');
a = binvar(n,1);

% ---- arc index lookups (built once; avoids find() inside every loop) -----
outA = cell(1,n); inA = cell(1,n);
for i = 1:n, outA{i} = find(A(:,1)==i).'; inA{i} = find(A(:,2)==i).'; end

C = {};   % constraints are collected in a cell and concatenated ONCE:
          % repeated  Con = [Con, ...]  inside nested loops is quadratic.

%% ------------------------------ 7.1 activation and depot routing
for k = 1:K
    C{end+1} = sum(x(outA{pre.dplus},k)) == u(k)-e(k);
    C{end+1} = sum(x(inA{pre.dminus},k)) == u(k)-e(k);
    C{end+1} = 0 <= tdep(k) <= pre.T_max*(u(k)-e(k));
end
C{end+1} = sum(u) <= inst.K_max;
if K > 1, C{end+1} = u(1:end-1) >= u(2:end); end

%% ------------------------------ 7.2 assignment, copies, flow conservation
for i = No
    for k = 1:K
        C{end+1} = sum(x(inA{i},k))  == r(i,k);
        C{end+1} = sum(x(outA{i},k)) == r(i,k);
        C{end+1} = r(i,k) <= u(k)-e(k);
    end
end
for i = [pre.F pre.C], C{end+1} = sum(r(i,:)) == 1; end
for i = pre.S,         C{end+1} = a(i) == sum(r(i,:)); end

%% ------------------------------ 7.3 MTZ subtour elimination
MN = numel(No);
for i = No
    for k = 1:K, C{end+1} = [r(i,k) <= q(i,k), q(i,k) <= MN*r(i,k)]; end
end
for ia = 1:nA
    i = A(ia,1); j = A(ia,2);
    if any(No==i) && any(No==j)
        for k = 1:K
            C{end+1} = q(i,k) - q(j,k) + MN*x(ia,k) <= MN - 1 + MN*(1-r(j,k));
        end
    end
end

%% ------------------------------ 7.4 exactly one speed on each used arc
for ia = 1:nA
    on  = pre.Hok{ia};
    off = setdiff(1:nH, on);
    for k = 1:K
        C{end+1} = sum(z{k}(ia,on)) == x(ia,k);
        if ~isempty(off), C{end+1} = z{k}(ia,off) == 0; end
    end
end

%% ------------------------------ 7.5 service and completion times
for k = 1:K
    for i = pre.F
        C{end+1} = bigM_eq(Cc(i,k)-tt(i,k)-pre.tau_obs, MT, r(i,k));
    end
    for ridx = 1:R
        i = pre.C(ridx);
        C{end+1} = bigM_eq(tt(i,k)-alpha(ridx), MT, r(i,k));
        C{end+1} = bigM_eq(Cc(i,k)-beta(ridx),  MT, r(i,k));
    end
    for i = pre.S
        C{end+1} = bigM_eq(Cc(i,k)-tt(i,k)-delta(i,k), MT, r(i,k));
    end
    for i = No
        C{end+1} = [0 <= tarr(i,k) <= pre.T_max*r(i,k), ...
                    0 <= tt(i,k)   <= pre.T_max*r(i,k), ...
                    0 <= Cc(i,k)   <= pre.T_max*r(i,k), ...
                    0 <= W(i,k)    <= (pre.Wbar*pre.chi(i) + ...
                                       pre.T_max*(1-pre.chi(i)))*r(i,k)];
    end
end

%% ------------------------------ 7.6 departure, arrival, waiting, precedence
for k = 1:K
    for i = No, C{end+1} = tt(i,k) == tarr(i,k) + W(i,k); end
    for ia = 1:nA
        i = A(ia,1); j = A(ia,2);
        Tf = pre.Tsched(ia,:) * z{k}(ia,:).';
        if i == pre.dplus
            C{end+1} = bigM_eq(tarr(j,k)-tdep(k)-Tf, MT, x(ia,k));
        elseif j == pre.dminus
            C{end+1} = bigM_eq(tret(k)-Cc(i,k)-Tf,   MT, x(ia,k));
        else
            C{end+1} = bigM_eq(tarr(j,k)-Cc(i,k)-Tf, MT, x(ia,k));
        end
    end
    C{end+1} = Tmake >= tret(k) - MT*(1-u(k)+e(k));
end

%% ------------------------------ 7.7 unified node energy balance
MBn = pre.MB_node;
for k = 1:K
    for i = No
        switch pre.kind(i)
            case 'F', Esrv = Ph*pre.tau_obs;
            case 'C', Esrv = Ph*(beta(pre.Cidx(i)) - alpha(pre.Cidx(i)));
            otherwise, Esrv = 0;
        end
        if pre.kind(i)=='S', g = gch(i,k); else, g = 0; end
        expr = bdep(i,k) - barr(i,k) + Esrv + Ph*pre.chi(i)*W(i,k) - g;
        C{end+1} = bigM_eq(expr, MBn, r(i,k));
        C{end+1} = [0 <= barr(i,k) <= Q*r(i,k), 0 <= bdep(i,k) <= Q*r(i,k)];
    end
end

%% ------------------------------ 7.8 continuous C1 surveillance and relay
C{end+1} = pre.tau_C1_min <= beta - alpha <= pre.tau_C1_max;
C{end+1} = alpha(1) == pre.T_C1_start;
C{end+1} = beta(R)  >= pre.T_C1_end;
if R > 1
    C{end+1} = alpha(2:end) >= alpha(1:end-1);
    C{end+1} = beta(2:end)  >= beta(1:end-1);
    C{end+1} = beta(1:end-1) - alpha(2:end) >= pre.O_C1;
    for ridx = 1:R-1
        for k = 1:K
            C{end+1} = r(pre.C(ridx),k) + r(pre.C(ridx+1),k) <= 1;
        end
    end
end
for i = pre.F
    for k = 1:K, C{end+1} = beta(R) >= Cc(i,k) - MT*(1-r(i,k)); end
end
MBr = pre.MB_ready;
for ridx = 1:R
    i = pre.C(ridx);
    for k = 1:K
        C{end+1} = barr(i,k) >= Ph*W(i,k) + Ph*(beta(ridx)-alpha(ridx)) ...
                                + pre.Esafe(i) + rho*Q - MBr*(1-r(i,k));
    end
end

%% ------------------------------ 7.9 initial planned backup
C{end+1} = [sum(s) == 1, s <= u - e, s(1) == 1];
if R >= 2
    c2 = pre.C(2);
    ia = find(A(:,1)==pre.dplus & A(:,2)==c2, 1);
    for k = 1:K
        C{end+1} = r(c2,k) == s(k);
        if ~isempty(ia), C{end+1} = x(ia,k) == s(k); end
        C{end+1} = s(k) + r(pre.C(1),k) <= 1;
    end
end

%% ------------------------------ 7.10 battery propagation on flight arcs
MBa = pre.MB_arc;
for k = 1:K
    for ia = 1:nA
        i = A(ia,1); j = A(ia,2);
        Ew = pre.Ehatwc(ia,:) * z{k}(ia,:).';
        if i == pre.dplus
            C{end+1} = bigM_eq(barr(j,k)-Q*(u(k)-e(k))+Ew, MBa, x(ia,k));
        elseif j == pre.dminus
            C{end+1} = bdep(i,k) - Ew >= rho*Q - MBa*(1-x(ia,k));
        else
            C{end+1} = bigM_eq(barr(j,k)-bdep(i,k)+Ew, MBa, x(ia,k));
        end
    end
end

%% ------------------------------ 7.11 charging dynamics and bay capacity
for i = pre.S
    si = pre.station_of(i);
    for k = 1:K
        C{end+1} = [pre.dmin(si)*r(i,k) <= delta(i,k), ...
                    delta(i,k) <= pre.dmax(si)*r(i,k)];
        C{end+1} = gch(i,k) == pre.chg_rate(si)*delta(i,k);
    end
end
for b = 1:numel(pre.bayseq)
    sq = pre.bayseq{b};
    for m = 1:numel(sq)-1
        C{end+1} = a(sq(m+1)) <= a(sq(m));
        C{end+1} = sum(tt(sq(m+1),:)) >= sum(Cc(sq(m),:)) - MT*(1-a(sq(m+1)));
    end
end

%% ------------------------------ 7.12 safe recovery and reserve
MBs = pre.MB_safe;

for i = No
    for k = 1:K

        % Untouchable battery reserve must also hold on ARRIVAL.
        % This is essential at charging stations: a UAV is not allowed
        % to arrive below the reserve and restore feasibility by charging.
        C{end+1} = barr(i,k) >= rho*Q*r(i,k);

        % After service/charging, enough battery must remain to preserve
        % the reserve and, where defined, safely reach a recovery site.
        if isfinite(pre.Esafe(i))
            C{end+1} = bdep(i,k) >= rho*Q + pre.Esafe(i) ...
                       - MBs*(1-r(i,k));
        end

    end
end

%% ------------------------------ 7.13 mission horizon
for k = 1:K, C{end+1} = 0 <= tret(k) <= pre.T_max*(u(k)-e(k)); end
C{end+1} = beta(R) <= pre.T_max;

%% ------------------------------ 7.14 optional emergency reserve
C{end+1} = [sum(e) == Nres, e <= u, e + s <= 1, e(1) == 0];
if K >= 3, C{end+1} = e(2:end-1) >= e(3:end); end

Con = [C{:}];

%% ------------------------------------------ Section 8: objective functions
f1 = sum(u);
f2 = Tmake;

f3 = 0;
isGplus  = false(1,n); isGplus(pre.dplus) = true; isGplus(pre.S) = true;
isGminus = false(1,n); isGminus(pre.dminus) = true; isGminus(pre.S) = true;
for k = 1:K
    f3 = f3 + sum(sum(pre.Eexp .* z{k}));                       % E^flight
    for ia = 1:nA
        if isGplus(A(ia,1)),  f3 = f3 + pre.E_TO*x(ia,k); end   % E^ground
        if isGminus(A(ia,2)), f3 = f3 + pre.E_LD*x(ia,k); end
    end
    for i = pre.F,         f3 = f3 + Ph*pre.tau_obs*r(i,k); end % E^hist
    for i = [pre.F pre.C], f3 = f3 + Ph*W(i,k);             end % E^wait
end
f3 = f3 + Ph*sum(beta - alpha);                                 % E^C1

% build the output field by field: struct(...) replicates over cell values,
% which would silently turn M into a struct array.
M.Con = Con;  M.f1 = f1;  M.f2 = f2;  M.f3 = f3;  M.opts = opts;
M.K = K;      M.Nres = Nres;
M.u = u;  M.s = s;  M.e = e;  M.x = x;  M.z = z;  M.r = r;  M.q = q;  M.a = a;
M.tdep = tdep;  M.tarr = tarr;  M.W = W;  M.t = tt;  M.C = Cc;  M.tret = tret;
M.Tmake = Tmake;  M.barr = barr;  M.bdep = bdep;
M.alpha = alpha;  M.beta = beta;  M.delta = delta;  M.gch = gch;
end

% =========================================================================
function C = bigM_eq(expr, M, ind)
%BIGM_EQ  expr == 0 when the binary ind equals 1; free in [-M,M] otherwise.
%
%   Two SEPARATE rows are required.  The coefficient of `ind` has opposite
%   signs in the two halves of  -M(1-ind) <= expr <= M(1-ind),  so writing it
%   as one double inequality gives  expr <= 0  instead of  expr == 0  when
%   ind = 1, which silently removes feasible solutions.
C = [expr + M*ind <= M, expr - M*ind >= -M];
end
