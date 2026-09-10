function T = cilento_velia_scenarios(tl)
%CILENTO_VELIA_SCENARIOS
% Final Gurobi rerun of Section 10.12 infrastructure scenarios V0-V3.
%
% V0 = existing infrastructure
% V1 = V0 + Ascea-Marina recovery/charging point
% V2 = V1 + forward base at Ascea railway station
% V3 = existing infrastructure + larger battery and corresponding mass
%
% Mandatory screens for N_res = 0:
% P1, P2, P3, P6.
% P4 and P5 are reported only as diagnostics.

if nargin < 1 || isempty(tl)
    tl = 1800;
end

opts = sdpsettings( ...
    'solver','gurobi', ...
    'verbose',1, ...
    'savesolveroutput',1, ...
    'gurobi.TimeLimit',tl, ...
    'gurobi.MIPGap',1e-4, ...
    'gurobi.NumericFocus',1);

%% ------------------------------------------------------------------------
% Common coordinate frame:
% centre-sector baseline is projected relative to VVF Vallo.
lat0 = 40.22778;
lon0 = 15.26611;

project = @(lat,lon) [ ...
    (lon-lon0)*111320*cosd(lat0), ...
    (lat-lat0)*110540 ];

% Scenario recovery point:
% Marina di Ascea
lat_recovery = 40.14540;
lon_recovery = 15.16793;
xy_recovery = project(lat_recovery,lon_recovery);

% Scenario forward base:
% Ascea railway station
lat_forward = 40.14102;
lon_forward = 15.17255;
xy_forward = project(lat_forward,lon_forward);

%% ------------------------------------------------------------------------
% Corrected centre-sector baseline:
% C1 = Elea_Velia, NOT Terradura.
inst0 = cilento_baseline('sector','centre');

d_recovery = norm(xy_recovery-inst0.c1)/1000;
d_forward  = norm(xy_forward-inst0.c1)/1000;

fprintf('\n============================================================\n');
fprintf('VELIA FINAL INFRASTRUCTURE SCENARIOS\n');
fprintf('============================================================\n');
fprintf('C1              : %s\n', inst0.meta.c1);
fprintf('Existing base   : %s\n', inst0.meta.base);
fprintf('Recovery point  : Ascea-Marina, %.3f km from C1\n', d_recovery);
fprintf('Forward base    : Ascea railway station, %.3f km from C1\n', d_forward);

% These reproduce the distances documented in Section 10.12.
assert(abs(d_recovery-1.87) < 0.05, ...
    'Ascea-Marina recovery point is not approximately 1.87 km from C1.');

assert(abs(d_forward-2.47) < 0.05, ...
    'Ascea railway station is not approximately 2.47 km from C1.');

rows = {};

%% ============================== V0 ======================================
% Existing infrastructure only.
rows(end+1,:) = evaluate_case( ...
    'V0 existing infrastructure', ...
    inst0, 1.0, opts);

%% ============================== V1 ======================================
% Add one recovery/charging point at Ascea-Marina.
inst1 = inst0;

inst1.stations(end+1) = make_station(xy_recovery);

inst1.meta.note = ...
    'V1: existing infrastructure + Ascea-Marina recovery point';

rows(end+1,:) = evaluate_case( ...
    'V1 + Ascea-Marina recovery point', ...
    inst1, 1.0, opts);

%% ============================== V2 ======================================
% Same recovery point, but move the operational base forward
% to Ascea railway station.
%
% All coordinates remain in the same local east-north frame.
% Only the depot coordinate changes; distances are therefore correct.
%
% Representative aerodynamic altitude is kept fixed so that this
% experiment isolates the effect of infrastructure geometry.

inst2 = inst1;

inst2.depot = xy_forward;
inst2.meta.base = 'Ascea_railway_station_forward';
inst2.meta.note = ...
    'V2: forward base at Ascea railway station + Ascea-Marina recovery point';

rows(end+1,:) = evaluate_case( ...
    'V2 forward base + recovery point', ...
    inst2, 1.0, opts);

%% ============================== V3 ======================================
% Increase battery without adding new infrastructure.
% Specific battery energy = 220 Wh/kg.
%
% Q_new = multiplier * Q_nom
% added mass = added battery energy [Wh] / 220 [Wh/kg]

mults = [1.2 1.4 1.6 1.8 2.0];

base_Wh   = inst0.Q_nom/3600;
base_mass = inst0.mass;

for mult = mults

    inst3 = inst0;

    inst3.Q_nom = inst0.Q_nom * mult;

    added_Wh = base_Wh*(mult-1);
    inst3.mass = base_mass + added_Wh/220;

    inst3.meta.note = sprintf( ...
        'V3 battery x%.1f, no new infrastructure', mult);

    rows(end+1,:) = evaluate_case( ...
        sprintf('V3 battery x%.1f',mult), ...
        inst3, mult, opts);
end

%% ------------------------------------------------------------------------
T = cell2table(rows, ...
    'VariableNames', { ...
    'scenario', ...
    'Q_scale', ...
    'mass_kg', ...
    'P1', ...
    'P2', ...
    'P3', ...
    'P4', ...
    'P5', ...
    'P6', ...
    'tau_bat_s', ...
    'tau_eff_s', ...
    'R_LB', ...
    'P6_slack_Wh', ...
    'f1_UAV', ...
    'f2_min', ...
    'f3_Wh', ...
    'charges', ...
    'proven', ...
    'status'});

fprintf('\n============================================================\n');
disp(T);
fprintf('============================================================\n');

writetable(T,'velia_scenarios_gurobi.csv');

fprintf('\nsaved velia_scenarios_gurobi.csv\n');

end


% =========================================================================
function row = evaluate_case(name, inst, Qscale, opts)

[inst,pre] = cilento_prepare(inst);
sc = pre.screens;

fprintf('\n------------------------------------------------------------\n');
fprintf('%s\n',name);
fprintf('------------------------------------------------------------\n');

fprintf('P1 = %d\n',sc.P1_ok);
fprintf('P2 = %d\n',sc.P2_ok);
fprintf('P3 = %d\n',sc.P3_ok);
fprintf('P4 = %d   (diagnostic because N_res=0)\n',sc.P4_ok);
fprintf('P5 = %d   (diagnostic because N_res=0)\n',sc.P5_ok);
fprintf('P6 = %d\n',sc.P6_ok);

fprintf('tau_bat  = %.3f s\n',sc.tau_bat);
fprintf('tau_eff  = %.3f s\n',sc.tau_eff);
fprintf('R_LB     = %g\n',sc.R_LB);
fprintf('P6 slack = %.3f Wh\n',sc.P6_min_slack_Wh);
fprintf('mass     = %.3f kg\n',inst.mass);

% Mandatory screens in the base experiment N_res = 0.
mandatory_ok = ...
    sc.P1_ok && ...
    sc.P2_ok && ...
    sc.P3_ok && ...
    sc.P6_ok;

f1 = NaN;
f2 = NaN;
f3 = NaN;
charges = NaN;
proven = false;

if mandatory_ok

    fprintf('Mandatory screens passed -> solving MILP...\n');

    r = cilento_solve_case( ...
        inst, ...
        opts, ...
        true, ...
        0, ...
        {'P1','P2','P3','P6'});

    status = r.status;

    f1 = r.f1;
    f2 = r.f2;
    f3 = r.f3;
    charges = r.charges;
    proven = r.proven;

    fprintf('status  = %s\n',status);
    fprintf('f1      = %.3f UAV\n',f1);
    fprintf('f2      = %.3f min\n',f2);
    fprintf('f3      = %.3f Wh\n',f3);
    fprintf('charges = %.0f\n',charges);
    fprintf('proven  = %d\n',proven);

else

    bad = {};

    if ~sc.P1_ok, bad{end+1} = 'P1'; end
    if ~sc.P2_ok, bad{end+1} = 'P2'; end
    if ~sc.P3_ok, bad{end+1} = 'P3'; end
    if ~sc.P6_ok, bad{end+1} = 'P6'; end

    status = ['screen fail: ' strjoin(bad,',')];

    fprintf('MILP not built: %s\n',status);
end

row = { ...
    name, ...
    Qscale, ...
    inst.mass, ...
    sc.P1_ok, ...
    sc.P2_ok, ...
    sc.P3_ok, ...
    sc.P4_ok, ...
    sc.P5_ok, ...
    sc.P6_ok, ...
    sc.tau_bat, ...
    sc.tau_eff, ...
    sc.R_LB, ...
    sc.P6_min_slack_Wh, ...
    f1, ...
    f2, ...
    f3, ...
    charges, ...
    proven, ...
    status};

end


% =========================================================================
function st = make_station(xy)

st = struct( ...
    'xy',xy, ...
    'bays',1, ...
    'visits',2, ...
    'P_rated',900, ...
    'eta_ch',0.90, ...
    'dmin',300, ...
    'dmax',3600);

end