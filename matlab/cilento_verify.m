function ck = cilento_verify(inst, pre, plan, makespan_tight)
%CILENTO_VERIFY  Independent check of a solved plan (Section 10.1).
%
%   ck = cilento_verify(inst, pre, plan)
%   ck = cilento_verify(inst, pre, plan, true)   % also pin f2 to the makespan
%
%   `plan` comes from cilento_extract.  The schedule is rebuilt from the
%   discrete decisions alone by cilento_derive and then compared against what
%   the solver reported and against the physical limits.  A wrong Big-M or a
%   mis-signed constraint shows up here, because none of the constraint rows of
%   cilento_milp.m are reused.
%
%   ck.n, ck.nfail, ck.ok, ck.rows{i} = {name, ok, detail}

if nargin < 4, makespan_tight = false; end
TOL_T = 1e-4;  TOL_E = 1e-3;  TOL_B = 0.5;

ck.rows = {};  ck.n = 0;  ck.nfail = 0;
d = cilento_derive(inst, pre, plan);
Q = pre.Q;  rho = inst.rho_res;  Ph = pre.P_obs_min;  R = inst.R;
A = pre.A;

% ------------------------------------------------ fleet-level structure ----
nu = sum(arrayfun(@(v) double(v.u), plan.veh));
ne = sum(arrayfun(@(v) double(v.e), plan.veh));
ns = sum(arrayfun(@(v) double(v.s), plan.veh));
add_near('7.14 reserve count equals N_res', ne, plan.Nres, TOL_B);
add_near('8.1 f1 equals the number of active UAV', plan.f1, nu, TOL_B);
add_near('7.9 exactly one planned backup', ns, 1, TOL_B);

served_by = cell(1, pre.n);
for k = 1:plan.K
    for i = plan.veh(k).served, served_by{i}(end+1) = k; end %#ok<AGROW>
end
for i = [pre.F pre.C]
    add(sprintf('7.2 %s served exactly once', pre.tag{i}), ...
        numel(served_by{i}) == 1, sprintf('served by %s', mat2str(served_by{i})));
end
for i = pre.S
    add_le(sprintf('7.2 charging copy %s used at most once', pre.tag{i}), ...
           numel(served_by{i}), 1, TOL_B);
end
add('7.3 no subtour on any vehicle', isempty(d.subtours), ...
    sprintf('%d vehicle(s) carry arcs unreachable from the depot', ...
            numel(d.subtours)));
add('7.4 every used arc carries exactly one speed', isempty(d.missing), ...
    sprintf('%d arc(s) without a unique admissible speed', numel(d.missing)));

% ------------------------------------------------------------ per vehicle --
for k = 1:plan.K
    v = plan.veh(k);  dv = d.veh(k);  tg = sprintf('UAV%d', k);
    if dv.idle
        add(sprintf('7.1/7.14 %s idle carries no arcs', tg), isempty(v.arcs));
        add(sprintf('7.2 %s idle serves no node', tg), isempty(v.served));
        continue
    end
    add(sprintf('7.1 %s route ends at the depot', tg), ...
        ~isempty(dv.path) && A(dv.path(end),2) == pre.dminus);
    visited = A(dv.path(1:end-1),2).';
    add(sprintf('7.2 %s visited set matches the route', tg), ...
        isequal(sort(visited), sort(v.served)));

    for q = 1:numel(dv.trace)
        st = dv.trace(q);  j = st.node;  nm = pre.tag{j};
        if j == pre.dminus
            add_near(sprintf('7.6 %s return time', tg), v.tret, st.tarr, TOL_T);
            add_ge(sprintf('7.10 %s lands above the reserve', tg), ...
                   st.batt, rho*Q, TOL_E);
            add_le(sprintf('7.13 %s within the mission horizon', tg), ...
                   st.tarr, pre.T_max, TOL_T);
            continue
        end
        add_near(sprintf('7.6 %s arrival at %s', tg, nm), v.tarr(j), st.tarr, TOL_T);
        add_near(sprintf('7.10 %s battery on arrival at %s', tg, nm), ...
                 v.barr(j), st.barr, TOL_E);
        add_ge(sprintf('7.12 %s arrival battery above reserve at %s', tg, nm), ...
            st.barr, rho*Q, TOL_E);
        add_ge(sprintf('7.6 %s waiting at %s non-negative', tg, nm), st.W, 0, TOL_T);
        add_near(sprintf('7.6 %s service start at %s', tg, nm), v.t(j), st.tstart, TOL_T);
        add_near(sprintf('7.5 %s completion at %s', tg, nm), v.C(j), st.C, TOL_T);
        add_near(sprintf('7.7 %s battery on departure from %s', tg, nm), ...
                 v.bdep(j), st.bdep, TOL_E);
        add_le(sprintf('7.7 %s battery never exceeds capacity at %s', tg, nm), ...
               st.bdep, Q, TOL_E);
        add_ge(sprintf('battery non-negative at %s (%s)', nm, tg), st.bdep, 0, TOL_E);
        if isfinite(pre.Esafe(j))
            add_ge(sprintf('7.12 %s can still reach a landing site from %s', tg, nm), ...
                   st.bdep - rho*Q - pre.Esafe(j), 0, TOL_E);
        end
        if pre.kind(j) == 'C'
            ridx = pre.Cidx(j);
            add_near(sprintf('7.5 %s C1 window starts at %s', tg, nm), ...
                     st.tstart, plan.alpha(ridx), TOL_T);
            add_near(sprintf('7.5 %s C1 window ends at %s', tg, nm), ...
                     st.C, plan.beta(ridx), TOL_T);
            add_ge(sprintf('7.8 %s ready for the %s duty', tg, nm), ...
                   st.barr - Ph*st.W - Ph*st.dur - pre.Esafe(j) - rho*Q, 0, TOL_E);
        end
        if pre.kind(j) == 'S'
            si = pre.station_of(j);
            add_ge(sprintf('7.11 %s charge at %s at least dmin', tg, nm), ...
                   st.dur, pre.dmin(si), TOL_T);
            add_le(sprintf('7.11 %s charge at %s at most dmax', tg, nm), ...
                   st.dur, pre.dmax(si), TOL_T);
            add_near(sprintf('7.11 %s energy gained at %s', tg, nm), ...
                     v.gch(j), pre.chg_rate(si)*st.dur, TOL_E);
        end
    end
end

% ------------------------------------------------- C1 persistent cover -----
add_near('7.8 first duty starts at T_C1_start', plan.alpha(1), pre.T_C1_start, TOL_T);
add_ge('7.8 last duty covers T_C1_end', plan.beta(R), pre.T_C1_end, TOL_T);
for r = 1:R
    add_ge(sprintf('7.8 duty %d at least tau_C1_min', r), ...
           plan.beta(r)-plan.alpha(r), pre.tau_C1_min, TOL_T);
    add_le(sprintf('7.8 duty %d at most tau_C1_max', r), ...
           plan.beta(r)-plan.alpha(r), pre.tau_C1_max, TOL_T);
end
for r = 1:R-1
    add_ge(sprintf('7.8 hand-over %d->%d overlap at least O_C1', r, r+1), ...
           plan.beta(r)-plan.alpha(r+1), pre.O_C1, TOL_T);
    ka = served_by{pre.C(r)};  kb = served_by{pre.C(r+1)};
    add(sprintf('7.8 hand-over %d->%d between two different UAV', r, r+1), ...
        ~isempty(ka) && ~isempty(kb) && ka(1) ~= kb(1));
end
for k = 1:plan.K
    for i = intersect(plan.veh(k).served, pre.F)
        add_le(sprintf('7.8 %s finished before the C1 mission ends', pre.tag{i}), ...
               plan.veh(k).C(i), plan.beta(R), TOL_T);
    end
end

% -------------------------------------- charging bay non-overlap (7.11) ----
for b = 1:numel(pre.bayseq)
    sq = pre.bayseq{b};
    for q = 1:numel(sq)-1
        ia = sq(q);  ib = sq(q+1);
        ka = served_by{ia};  kb = served_by{ib};
        if ~isempty(kb)
            add(sprintf('7.11 bay copies %s/%s used in order', ...
                        pre.tag{ia}, pre.tag{ib}), ~isempty(ka));
            if ~isempty(ka)
                add_ge(sprintf('7.11 bay %s occupancy does not overlap', ...
                               pre.tag{ib}), ...
                       plan.veh(kb(1)).t(ib), plan.veh(ka(1)).C(ia), TOL_T);
            end
        end
    end
end

% ------------------------------------------- objectives, recomputed --------
add_ge('8.1 f2 bounds the recomputed makespan', plan.f2, d.makespan, 1e-2);
if makespan_tight
    add_near('8.1 f2 equals the recomputed makespan', plan.f2, d.makespan, 1e-2);
end
add_near('8.1 f3 equals the recomputed energy', plan.f3, d.f3, 1e-2);

ck.ok = (ck.nfail == 0);
ck.derived = d;

% =========================================================== local helpers ==
    function add(name, ok, detail)
        if nargin < 3, detail = ''; end
        ck.n = ck.n + 1;
        ck.rows{end+1} = {name, logical(ok), detail};
        if ~ok, ck.nfail = ck.nfail + 1; end
    end
    function add_near(name, got, want, tol)
        add(name, abs(got-want) <= tol + tol*abs(want), ...
            sprintf('got %.6g, expected %.6g', got, want));
    end
    function add_ge(name, got, want, tol)
        add(name, got >= want - tol, sprintf('got %.6g < %.6g', got, want));
    end
    function add_le(name, got, want, tol)
        add(name, got <= want + tol, sprintf('got %.6g > %.6g', got, want));
    end
end
