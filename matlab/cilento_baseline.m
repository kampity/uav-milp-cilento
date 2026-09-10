function inst = cilento_baseline(varargin)
%CILENTO_BASELINE  The real Cilento instance every Section 10 experiment uses.
%
%   inst = cilento_baseline()                       northern sector
%   inst = cilento_baseline('sector','south')       another sector
%   inst = cilento_baseline('gamma_use', 0.7)       any field override
%   inst = cilento_baseline('base','VVF_Agropoli')  another base, same sector
%
%   Geography, wind and base come from cilento_case (all sourced).  The
%   operational parameters are those of Section 4.

% ---- which sector, which base -------------------------------------------
sector = 'north';
basename = '';
chargenames = [];
charge_given = false;
keep = true(1, numel(varargin));
for i = 1:2:numel(varargin)
    switch varargin{i}
        case 'sector',  sector      = varargin{i+1}; keep(i:i+1) = false;
        case 'base',    basename    = varargin{i+1}; keep(i:i+1) = false;
        case 'charge'
    chargenames = varargin{i+1};
    charge_given = true;
    keep(i:i+1) = false;
    end
end
varargin = varargin(keep);

L = cilento_case('sectors');
k = strcmp({L.name}, sector);
if ~isempty(basename),    L(k).base   = basename;    end
if charge_given
    if ischar(chargenames) || isstring(chargenames)
        chargenames = cellstr(chargenames);
    end
    L(k).charge = chargenames;
end
g = local_geom(L, sector);

inst.depot = g.depot;
inst.c1    = g.c1;
inst.F     = g.F;
nStations = size(g.charge,1);

if nStations == 0
    inst.stations = struct( ...
        'xy',{}, ...
        'bays',{}, ...
        'visits',{}, ...
        'P_rated',{}, ...
        'eta_ch',{}, ...
        'dmin',{}, ...
        'dmax',{});
else
    inst.stations = repmat(struct( ...
        'xy',[], ...
        'bays',1, ...
        'visits',2, ...
        'P_rated',900, ...
        'eta_ch',0.90, ...
        'dmin',300, ...
        'dmax',3600), 1, nStations);

    for q = 1:nStations
        inst.stations(q).xy = g.charge(q,:);
    end
end

% A pass over a historical fire site is a survey, not a stakeout: five minutes
% at 400 m covers the scar.  Fifteen minutes would cost 48 Wh, more than a
% third of the usable battery, and is not compatible with 10-15 km legs.
inst.tau_obs    = 300;   inst.O_C1       = 420;
inst.tau_C1_min = 600;   inst.tau_C1_max = 1500;
inst.T_C1_start = 900;   inst.T_C1_end   = 3600;
inst.T_max      = 14400; inst.K_max      = 6;    inst.R = g.R;
inst.T_resp     = 900;   inst.N_res      = 0;

inst.Q_nom  = 149.9*3600;  inst.gamma_use = 0.90;  inst.rho_res = 0.20;
inst.P_sens = 30;          inst.E_TO = 4800;       inst.E_LD = 5700;

inst.H = [8 10 12 14 15];  inst.w_max = 12;  inst.g_min = 3;  inst.eta_adm = 0.90;
inst.Omega = g.wind;
inst.wind_mode = 'hybrid';

inst.mass = 1.85;  inst.d_prop = 0.328;
inst.alt_op = round(g.mean_terrain + 150);   % 150 m AGL over the mean terrain

inst.meta = struct('sector',sector,'base',g.base,'c1',g.c1name, ...
                   'F',{g.Fnames},'note',g.note);

for i = 1:2:numel(varargin)
    f = varargin{i};
    assert(isfield(inst, f), 'unknown instance field %s', f);
    inst.(f) = varargin{i+1};
end
end

% -------------------------------------------------------------------------
function g = local_geom(L, sector)
%LOCAL_GEOM  cilento_case geometry, honouring a base substitution.
k = find(strcmp({L.name}, sector), 1);
B = cilento_case('bases');  S = cilento_case('sites');  W = cilento_case('wind');
bi = find(strcmp(B(:,1), L(k).base), 1);
lat0 = B{bi,2};  lon0 = B{bi,3};
g.depot = [0 0];
g.c1 = ll(S, L(k).c1, lat0, lon0);
g.F = zeros(numel(L(k).F), 2);
for q = 1:numel(L(k).F), g.F(q,:) = ll(S, L(k).F{q}, lat0, lon0); end
g.charge = zeros(numel(L(k).charge), 2);   % 0x2 when the list is empty
for q = 1:numel(L(k).charge)
    j = find(strcmp(B(:,1), L(k).charge{q}), 1);
    g.charge(q,:) = [(B{j,3}-lon0)*111320*cosd(lat0), (B{j,2}-lat0)*110540];
end
g.R = L(k).R;  g.wind = W;  g.base = L(k).base;  g.c1name = L(k).c1;
g.Fnames = L(k).F;  g.note = L(k).note;
els = zeros(1, numel(L(k).F)+2);
for q = 1:numel(L(k).F), els(q) = S{strcmp(S(:,1), L(k).F{q}), 4}; end
els(end-1) = S{strcmp(S(:,1), L(k).c1), 4};
els(end)   = B{bi,4};
g.mean_terrain = mean(els);
end

function p = ll(S, name, lat0, lon0)
i = find(strcmp(S(:,1), name), 1);
assert(~isempty(i), 'unknown site %s', name);
p = [(S{i,3}-lon0)*111320*cosd(lat0), (S{i,2}-lat0)*110540];
end
