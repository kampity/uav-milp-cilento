%RUN_CILENTO  Driver for the wind-aware multi-UAV routing MILP.
%
%   Section 5   preprocessing and propulsion calibration
%   Section 2.3 feasibility screens
%   Section 9.1 exact fleet search
%   Section 8.2 payoff table, utopia and approximate nadir
%   Section 8.3 normalized lexicographic stages with tolerance eps2
%   Section 7.14 cost of one emergency reserve UAV
%
%   Requires YALMIP on the path and Gurobi installed.
%   Everything is solved in MINUTES and WATT-HOURS (see cilento_pre.m).

clear; clc;

%% ============================================ instance (Sections 3-4)
% One shared definition, so run_cilento, the tests and every experiment of
% Section 10 speak about the same instance.
inst = cilento_baseline();

opts = sdpsettings('solver','gurobi','verbose',0, ...
                   'gurobi.TimeLimit',300,'gurobi.MIPGap',1e-4, ...
                   'gurobi.NumericFocus',1);

%% ============================================ Section 5 preprocessing
[inst, pre] = cilento_prepare(inst);   % includes the Section 4.5 tau_C1_max cap

fprintf('=== Section 5.3 calibration ===\n');
fprintf('  P_0 = %.2f W, P_i = %.2f W, d0*sr = %.5f\n', ...
        pre.P0_0, pre.Pi_0, pre.k_0);
fprintf('  residuals = [%s] W  (must be ~1e-10)\n', ...
        num2str(pre.residuals, '%.1e '));
fprintf('  P_hover = %.1f W, P_obs = %.1f W at %.0f m\n', ...
        pre.P_hover, pre.P_obs, inst.alt_op);
fprintf('  nodes %d, arcs %d, arc-speed pairs %d\n', ...
        pre.n, size(pre.A,1), pre.nAH);

%% ============================================ Section 2.3 screens
sc = pre.screens;
fprintf('\n=== Section 2.3 feasibility screens ===\n');
fprintf('  P1 %d  (min travel to C1 %.0f s vs T_C1_start %.0f s)\n', ...
        sc.P1_ok, sc.P1_min_travel, inst.T_C1_start);
fprintf('  P2 %d  (tau_bat %.0f s, tau_max %.0f s -> tau_eff %.0f s)\n', ...
        sc.P2_ok, sc.tau_bat, inst.tau_C1_max, sc.tau_eff);
fprintf('  P3 %d  (R_LB %d vs R %d)\n', sc.P3_ok, sc.R_LB, inst.R);

assert(pre.screens.P1_ok && pre.screens.P2_ok, ...
       'preprocessing screen failed: reject this depot candidate');
if ~pre.screens.P3_ok
    warning('R = %d is below R_LB = %d; C1 coverage cannot be closed', ...
            inst.R, pre.screens.R_LB);
end

%% ============================================ Section 9.1 fleet search
fprintf('\n=== Section 9.1 exact fleet search ===\n');
Kstar = []; f1star = NaN;
for K = 2:inst.K_max
    M = cilento_milp(inst, pre, K, inst.N_res, opts);
    d = optimize(M.Con, M.f1, opts);
    [lab, feas] = cilento_status(d, M.f1);
    fprintf('  K = %d: %s\n', K, lab);
    if feas, Kstar = K; f1star = value(M.f1); break, end
end
assert(~isempty(Kstar), 'no feasible fleet size up to K_max');
fprintf('  minimum fleet f1* = %g\n', f1star);

%% ============================================ Section 8.2 payoff table
% Row j: minimise f_j, fix it, then minimise the remaining objectives in
% index order.  This is the tie-broken payoff table; a plain payoff table
% over-estimates the nadir.
fprintf('\n=== Section 8.2 payoff table ===\n');
P = nan(3,3);
for j = 1:3
    order = [j setdiff(1:3, j)];
    % ONE model per payoff row.  Rebuilding the model between tie-breaking
    % stages and then adding a constraint saved from the previous build is
    % unsafe in YALMIP: every rebuild creates NEW sdpvar objects, so the saved
    % expression would constrain variables that are no longer in the model.
    M = cilento_milp(inst, pre, Kstar, inst.N_res, opts);
    objs = {M.f1, M.f2, M.f3};
    Cx = M.Con;
    for pos = 1:3
        d = optimize(Cx, objs{order(pos)}, opts);
        [lab, inc] = cilento_status(d, objs{order(pos)});
        assert(inc, 'payoff row %d step %d: %s', j, pos, lab);
        v = value(objs{order(pos)});
        % fix this objective, then optimise the next one over what is left
        Cx = [Cx, objs{order(pos)} <= v + 1e-6 + 1e-7*abs(v)]; %#ok<AGROW>
    end
    P(j,:) = [value(M.f1) value(M.f2) value(M.f3)];
    fprintf('  row lex(f%d,f%d,f%d): f1=%.0f UAV  f2=%.1f min  f3=%.1f Wh\n', ...
            order, P(j,1), P(j,2), P(j,3));
end
z_star = diag(P).';
z_nad  = max(P, [], 1);
rngv   = z_nad - z_star;
active = find(rngv > 1e-9);
fprintf('  utopia [%.0f %.1f %.1f], nadir [%.0f %.1f %.1f]\n', z_star, z_nad);
if isempty(active)
    fprintf(['  all payoff ranges are zero: the objectives do not conflict on\n' ...
             '  this instance and every objective is removed from the active\n' ...
             '  ranking (Section 8.2).  Loosen the instance to exercise eps2.\n']);
else
    fprintf('  active objectives: %s\n', mat2str(active));
end

%% ============================================ Section 8.3 lexicographic
fprintf('\n=== Section 8.3 normalized lexicographic stages ===\n');
for eps2 = [0 0.05 0.10]
    M1 = cilento_milp(inst, pre, Kstar, inst.N_res, opts);
    optimize(M1.Con, M1.f1, opts);  f1v = value(M1.f1);

    M2 = cilento_milp(inst, pre, Kstar, inst.N_res, opts);
    optimize([M2.Con, M2.f1 <= f1v + 1e-6], M2.f2, opts);  f2v = value(M2.f2);

    slack = 0;
    if any(active == 2), slack = eps2 * rngv(2); end

    M3 = cilento_milp(inst, pre, Kstar, inst.N_res, opts);
    d3 = optimize([M3.Con, M3.f1 <= f1v + 1e-6, ...
                   M3.f2 <= f2v + slack + 1e-6], M3.f3, opts);
    fn = nan(1,3);
    for m = 1:3
        if any(active == m)
            vv = [value(M3.f1) value(M3.f2) value(M3.f3)];
            fn(m) = (vv(m) - z_star(m)) / rngv(m);
        else
            fn(m) = 0;
        end
    end
    fprintf('  eps2=%.2f -> f1=%.0f, f2=%.1f min, f3=%.1f Wh, norm=[%.3f %.3f %.3f]  (%s)\n', ...
            eps2, value(M3.f1), value(M3.f2), value(M3.f3), fn, ...
            yalmiperror(d3.problem));
end

%% ============================================ Section 7.14 reserve cost
fprintf('\n=== Section 7.14 cost of one emergency reserve ===\n');
for Nres = [0 1]
    M = cilento_milp(inst, pre, min(Kstar+1, inst.K_max), Nres, opts);
    d = optimize(M.Con, M.f1, opts);
    [lab, inc] = cilento_status(d, M.f1);
    if inc
        fprintf('  N_res = %d -> f1 = %g   (%s)\n', Nres, value(M.f1), lab);
    else
        fprintf('  N_res = %d -> %s\n', Nres, lab);
    end
end

%% ============================================ solution report
fprintf('\n=== solution (minimum fleet) ===\n');
M = cilento_milp(inst, pre, Kstar, inst.N_res, opts);
optimize(M.Con, M.f3, opts);
A = pre.A;
for k = 1:M.K
    used = find(value(M.x(:,k)) > 0.5).';
    if isempty(used), continue, end
    succ = containers.Map(num2cell(A(used,1)), num2cell(A(used,2)));
    cur = pre.dplus; path = pre.tag{cur}; guard = 0;
    while isKey(succ, cur) && guard < 100
        cur = succ(cur); path = [path ' -> ' pre.tag{cur}]; guard = guard+1; %#ok
    end
    Z = value(M.z{k});  sp = '';
    for ia = used
        h = find(Z(ia,:) > 0.5, 1);
        if ~isempty(h)
            sp = [sp sprintf(' %s:%g', pre.tag{A(ia,2)}, inst.H(h))]; %#ok
        end
    end
    fprintf('  UAV%d  tdep=%6.1f min  %s\n        speeds:%s\n', ...
            k, value(M.tdep(k)), path, sp);
end
fprintf('  C1 windows [min]:');
for r = 1:inst.R
    who = find(value(M.r(pre.C(r),:)) > 0.5);
    fprintf('  [%.1f, %.1f] UAV%d', value(M.alpha(r)), value(M.beta(r)), who);
end
fprintf('\n');

%% ============================================ independent verification
% The solver reporting "optimal" only means the point satisfies the rows that
% were written.  cilento_verify rebuilds the schedule from the routing
% decisions alone and checks it against the physics.
plan = cilento_extract(inst, pre, M);
ck = cilento_verify(inst, pre, plan);
fprintf('\n=== independent check ===\n');
fprintf('  %d/%d properties hold\n', ck.n - ck.nfail, ck.n);
for q = 1:numel(ck.rows)
    if ~ck.rows{q}{2}
        fprintf('  [FAIL] %s -- %s\n', ck.rows{q}{1}, ck.rows{q}{3});
    end
end

%% ============================================ Section 10.6 figures
r = struct('inst',inst,'pre',pre,'plan',plan,'f1',f1star, ...
           'f2',NaN,'f3',value(M.f3),'checks',ck.n,'violations',ck.nfail, ...
           'status','solved');
d = cilento_derive(inst, pre, plan);  r.f2 = d.makespan;
try
    cilento_plots(r);
catch err
    fprintf('  (figures skipped: %s)\n', err.message);
end

% -------------------------------------------------------------------------
function s = ternary(c, a, b)
if c, s = a; else, s = b; end
end
