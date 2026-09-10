function T = cilento_velia_v4()

% Find the minimum small battery increase that makes
% V2 pass all mandatory screens P1,P2,P3,P6.

lat0 = 40.22778;
lon0 = 15.26611;

project = @(lat,lon) [ ...
    (lon-lon0)*111320*cosd(lat0), ...
    (lat-lat0)*110540 ];

xyRecovery = project(40.14540,15.16793); % Ascea-Marina
xyForward  = project(40.14102,15.17255); % Ascea station

base = cilento_baseline('sector','centre');

base.stations(end+1) = struct( ...
    'xy',xyRecovery, ...
    'bays',1, ...
    'visits',2, ...
    'P_rated',900, ...
    'eta_ch',0.90, ...
    'dmin',300, ...
    'dmax',3600);

base.depot = xyForward;

Q0_Wh = base.Q_nom/3600;
m0 = base.mass;

% Very small increases first
mults = 1.00:0.005:1.10;

rows = {};
firstOK = NaN;

fprintf('\nV4: forward base + recovery point + small battery increase\n\n');
fprintf('%7s %8s %8s %5s %5s %5s %5s %12s %12s\n', ...
    'Qscale','Q[Wh]','mass','P1','P2','P3','P6','P6 slack','R_LB');

for q = 1:numel(mults)

    mult = mults(q);

    inst = base;

    inst.Q_nom = base.Q_nom*mult;

    % Battery mass grows with specific energy 220 Wh/kg
    addedWh = Q0_Wh*(mult-1);
    inst.mass = m0 + addedWh/220;

    [inst,pre] = cilento_prepare(inst);
    sc = pre.screens;

    fprintf('%7.3f %8.2f %8.3f %5d %5d %5d %5d %12.3f %12g\n', ...
        mult,inst.Q_nom/3600,inst.mass, ...
        sc.P1_ok,sc.P2_ok,sc.P3_ok,sc.P6_ok, ...
        sc.P6_min_slack_Wh,sc.R_LB);

    rows(end+1,:) = { ...
        mult,inst.Q_nom/3600,inst.mass, ...
        sc.P1_ok,sc.P2_ok,sc.P3_ok,sc.P6_ok, ...
        sc.P6_min_slack_Wh,sc.R_LB}; %#ok<AGROW>

    if sc.P1_ok && sc.P2_ok && sc.P3_ok && sc.P6_ok
        firstOK = mult;
        fprintf('\nFIRST FULLY SCREEN-FEASIBLE SCALE = %.3f\n',mult);
        fprintf('Battery = %.2f Wh\n',inst.Q_nom/3600);
        fprintf('Mass    = %.3f kg\n',inst.mass);
        fprintf('P6 slack = %.3f Wh\n',sc.P6_min_slack_Wh);
        break
    end
end

T = cell2table(rows,'VariableNames', ...
    {'Q_scale','Q_Wh','mass_kg','P1','P2','P3','P6', ...
     'P6_slack_Wh','R_LB'});

writetable(T,'velia_v4_battery_search.csv');

if isnan(firstOK)
    fprintf('\nNo feasible multiplier found up to x1.10\n');
    return
end

%% Solve MILP for the first feasible V4 configuration

inst = base;
inst.Q_nom = base.Q_nom*firstOK;
inst.mass = m0 + Q0_Wh*(firstOK-1)/220;

opts = sdpsettings( ...
    'solver','gurobi', ...
    'verbose',1, ...
    'savesolveroutput',1, ...
    'gurobi.TimeLimit',1800, ...
    'gurobi.MIPGap',1e-4, ...
    'gurobi.NumericFocus',1);

fprintf('\nSolving final V4 MILP...\n');

r = cilento_solve_case( ...
    inst,opts,true,0,{'P1','P2','P3','P6'});

fprintf('\n================ FINAL V4 ================\n');
fprintf('battery scale = %.3f\n',firstOK);
fprintf('battery       = %.2f Wh\n',inst.Q_nom/3600);
fprintf('mass          = %.3f kg\n',inst.mass);
fprintf('status        = %s\n',r.status);
fprintf('f1            = %.0f UAV\n',r.f1);
fprintf('f2            = %.3f min\n',r.f2);
fprintf('f3            = %.3f Wh\n',r.f3);
fprintf('charges       = %.0f\n',r.charges);
fprintf('checks        = %.0f\n',r.checks);
fprintf('violations    = %.0f\n',r.violations);
fprintf('proven        = %d\n',r.proven);
fprintf('==========================================\n');

save('velia_v4_final.mat','r','firstOK');

end