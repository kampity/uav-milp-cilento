function res = cilento_derive(inst, pe, plan)
%CILENTO_DERIVE  Replay routing decisions against a coefficient set.
%
%   res = cilento_derive(inst, pe, plan)
%
%   `pe` is the preprocessing structure the plan is replayed against.  Passing
%   the one the plan was built with re-derives the schedule for verification;
%   passing a different one replays the SAME routes under different wind, which
%   is the out-of-sample experiment of Section 10.4.
%
%   Nothing here reuses the constraint rows of cilento_milp.m -- times, battery
%   levels and objectives are rebuilt from the raw coefficients.

A = pe.A;  Q = pe.Q;  rho = inst.rho_res;  Ph = pe.P_obs_min;
res.missing = {};  res.subtours = {};  res.makespan = 0;  res.f3 = 0;
res.margin = inf;  res.land_margin = inf;
res.alpha = plan.alpha;  res.beta = plan.beta;

Gp = [pe.dplus pe.S];  Gm = [pe.S pe.dminus];

for k = 1:plan.K
    v = plan.veh(k);
    res.veh(k).idle = ~v.u || v.e || isempty(v.arcs);
    res.veh(k).trace = struct('node',{},'tarr',{},'W',{},'tstart',{}, ...
                              'dur',{},'C',{},'barr',{},'bdep',{},'batt',{});
    res.veh(k).path = [];
    if res.veh(k).idle, continue, end

    [path, left] = local_walk(pe, v.arcs);
    if ~isempty(left)
        res.subtours{end+1} = struct('k',k,'arcs',left); %#ok<AGROW>
    end
    res.veh(k).path = path;

    tcur = v.tdep;  bcur = Q;
    for p = 1:numel(path)
        ia = path(p);  i = A(ia,1);  j = A(ia,2);
        h = v.speed(ia);
        if v.nspeed(ia) ~= 1 || h == 0 || ~any(pe.Hok{ia} == h)
            res.missing{end+1} = struct('k',k,'i',i,'j',j,'h',h); %#ok<AGROW>
            break
        end
        tcur = tcur + pe.Tsched(ia,h);
        bcur = bcur - pe.Ehatwc(ia,h);
        res.f3 = res.f3 + pe.Eexp(ia,h) ...
                 + pe.E_TO*any(Gp == i) + pe.E_LD*any(Gm == j);

        if j == pe.dminus
            res.makespan = max(res.makespan, tcur);
            res.land_margin = min(res.land_margin, bcur - rho*Q);
            st = empty_step(); st.node = j; st.tarr = tcur; st.batt = bcur;
            res.veh(k).trace(end+1) = st;
            break
        end

        barr = bcur;
        W = v.W(j);
        tstart = tcur + W;
        bcur = bcur - Ph*pe.chi(j)*W;
        if pe.chi(j), res.f3 = res.f3 + Ph*W; end

        switch pe.kind(j)
            case 'F'
                dur = pe.tau_obs;  drain = Ph*pe.tau_obs;
                res.f3 = res.f3 + Ph*pe.tau_obs;
            case 'C'
                ridx = pe.Cidx(j);
                dur = plan.beta(ridx) - plan.alpha(ridx);
                drain = Ph*dur;
            otherwise
                dur = v.delta(j);  drain = -v.gch(j);
        end
        tcur = tstart + dur;
        bcur = bcur - drain;
        safe = pe.Esafe(j);  if ~isfinite(safe), safe = 0; end
        res.margin = min(res.margin, bcur - rho*Q - safe);

        st = empty_step();
        st.node = j; st.tarr = tstart - W; st.W = W; st.tstart = tstart;
        st.dur = dur; st.C = tcur; st.barr = barr; st.bdep = bcur;
        res.veh(k).trace(end+1) = st;
    end
end
res.f3 = res.f3 + Ph*sum(plan.beta - plan.alpha);
end

% -------------------------------------------------------------------------
function st = empty_step()
st = struct('node',NaN,'tarr',NaN,'W',NaN,'tstart',NaN,'dur',NaN, ...
            'C',NaN,'barr',NaN,'bdep',NaN,'batt',NaN);
end

% -------------------------------------------------------------------------
function [path, left] = local_walk(pe, arcs)
%LOCAL_WALK  Follow the successor map from d+.  Arcs never reached are a
%subtour, which is the direct structural test of Section 7.3.
A = pe.A;
path = [];  used = false(1,numel(arcs));
cur = pe.dplus;  guard = 0;
while guard < numel(arcs) + 2
    guard = guard + 1;
    % both operands kept as ROW vectors: mixing a column with a row would
    % broadcast into a matrix and silently pick the wrong arc
    heads = reshape(A(arcs,1), 1, []);
    nxt = find(heads == cur & ~used, 1);
    if isempty(nxt), break, end
    used(nxt) = true;
    ia = arcs(nxt);
    path(end+1) = ia; %#ok<AGROW>
    cur = A(ia,2);
    if cur == pe.dminus, break, end
end
left = arcs(~used);
end
