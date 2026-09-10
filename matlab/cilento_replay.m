function rp = cilento_replay(inst, pre_true, plan)
%CILENTO_REPLAY  Fly a plan in a wind it was not planned for (Section 10.4).
%
%   rp = cilento_replay(inst, pre_true, plan)
%
%   The routes, speeds and C1 windows are held fixed and re-evaluated against
%   `pre_true`.  This is the only comparison between wind treatments that means
%   anything operationally: a plan that ignores the wind is cheap on its own
%   optimistic coefficients and may still be unflyable in the real air.
%
%   rp.complete is false when the plan uses a leg the true wind does not admit
%   at all; the energy figure is then not comparable, the plan simply cannot be
%   flown.

d = cilento_derive(inst, pre_true, plan);
Q = pre_true.Q;  rho = inst.rho_res;
bad = {};

for m = 1:numel(d.missing)
    mi = d.missing{m};
    bad{end+1} = sprintf(['leg %s->%s at the planned speed is not admissible ' ...
                          'under the true wind (UAV%d)'], ...
                         pre_true.tag{mi.i}, pre_true.tag{mi.j}, mi.k); %#ok<AGROW>
end
for k = 1:plan.K
    if d.veh(k).idle, continue, end
    for q = 1:numel(d.veh(k).trace)
        st = d.veh(k).trace(q);
        if st.node == pre_true.dminus
            if st.batt < rho*Q - 1e-6
                bad{end+1} = sprintf('UAV%d lands %.1f Wh below the reserve', ...
                                     k, rho*Q - st.batt); %#ok<AGROW>
            end
        elseif st.bdep < 0
            bad{end+1} = sprintf('UAV%d runs the battery flat at %s', ...
                                 k, pre_true.tag{st.node}); %#ok<AGROW>
        elseif st.bdep < rho*Q
            bad{end+1} = sprintf('UAV%d breaks the reserve at %s', ...
                                 k, pre_true.tag{st.node}); %#ok<AGROW>
        end
    end
end
if d.makespan > pre_true.T_max + 1e-6
    bad{end+1} = sprintf('mission overruns the horizon by %.1f min', ...
                         d.makespan - pre_true.T_max);
end

rp = struct('f3', d.f3, 'makespan', d.makespan, 'margin', d.margin, ...
            'land_margin', d.land_margin, 'complete', isempty(d.missing));
rp.violations = bad;
end
