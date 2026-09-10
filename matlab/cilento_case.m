function out = cilento_case(what, arg)
%CILENTO_CASE  Real Cilento data: sites, base candidates, wind, sectors.
%
%   S = cilento_case('sites')            struct array of monitoring sites
%   B = cilento_case('bases')            struct array of base candidates
%   W = cilento_case('wind')             [speed m/s, dir FROM deg, prob]
%   L = cilento_case('sectors')          sector definitions
%   g = cilento_case('geometry', 'north')  projected geometry of one sector
%
%   EVERY number here is sourced.  Coordinates come from the GeoNames gazetteer
%   applied to the place named in the fire report -- the reports themselves
%   publish no coordinates, and that distinction is stated rather than hidden.
%
%   FRAME.  Latitude/longitude are projected to a local east-north plane about
%   a reference point:
%       x = (lon - lon0)*111320*cos(lat0)
%       y = (lat - lat0)*110540
%   Over a 45 km box at 40 deg N this is accurate to better than 0.1 %, far
%   below the uncertainty of the site coordinates themselves.
%
%   SOURCES
%     fires   InfoCilento 18/07/2017 (damage assessment of the July 2017
%             emergency); InfoCilento 08/07/2022 (Velia); InfoCilento
%             18/12/2023 (Monte Bulgheria); Fanpage 16/08/2024 (Centola);
%             InfoCilento 02/07/2025 (Omignano); InfoCilento 20/07/2026
%             (Lentiscosa, 13 ha)
%     coords  GeoNames gazetteer, https://www.geonames.org
%     bases   Regione Campania Protezione Civile (regional AIB helicopter
%             bases, Centola SA); Corpo Nazionale VVF (Vallo della Lucania);
%             SalernoToday 20/07/2020 (VVF Agropoli, loc. Mattine);
%             InfoCilento 08/07/2017 (elisuperficie Ospedale San Luca)
%     wind    Iowa Environmental Mesonet wind rose, station LIRI
%             (Salerno-Pontecagnano), Jun-Sep 1993-2026, 16 sectors, m/s;
%             Capo Palinuro CLINO 1961-1990 monthly means as a speed check
%     terrain Monte Bulgheria 1225 m, Monte Stella 1131 m; park reaches the sea

if nargin < 1, what = 'sectors'; end

% ------------------------------------------------------------------ sites --
% name, lat, lon, elevation m, documented event
S = { 'Agropoli',      40.34917, 14.99056,  24, 'Jul 2017, Collina San Marco'
      'Copersito',     40.31472, 15.06250, 313, 'Jul 2017, >1000 olive trees'
      'SanMartino',    40.30000, 15.04833, 479, 'Jul 2017, loc. Acquasanta'
      'Coste',         40.25056, 15.11250, 540, 'Jul 2025, ~2 ha macchia'
      'Ceraso',        40.19417, 15.25583, 340, 'Jul 2017, front >2 km'
      'Terradura_Ascea',40.15611,15.21694, 205, 'Jul 2017, residents evacuated'
      'Elea_Velia',    40.16111, 15.15987,  30, 'Jul 2022, fire near archaeological park'
      'Roccagloriosa', 40.10611, 15.43639, 430, 'Jul 2017 foci'
      'Palinuro',      40.03667, 15.28806,  53, 'Jul 2017; Aug 2024 Lacci'
      'Scario',        40.06207, 15.47421,   3, 'Jul 2017; Dec 2023 Bulgheria'
      'Lentiscosa',    40.02194, 15.38278, 230, 'Jul 2026, 13 ha macchia' };


% name, lat, lon, elevation m, type
B = { 'Centola_AIB',  40.06972, 15.31167, 336, 'regional AIB helicopter base'
      'VVF_Vallo',    40.22778, 15.26611, 380, 'permanent fire station'
      'VVF_Agropoli', 40.38556, 15.02472,  50, 'fire station, loc. Mattine'
      'Elis_Pattano', 40.22778, 15.23500, 166, 'hospital helipad, San Luca'
      'CM_Futani',    40.15139, 15.32361, 431, 'CM Bussento-Lambro-Mingardo'
      'CM_Laureana',  40.30111, 15.03861, 452, 'CM Alento-Monte Stella' };

% Jun-Sep wind rose at LIRI, partitioned exactly: the onshore half
% (169-348 deg) split by the source's own speed bins, plus the offshore half.
% Columns: speed m/s, direction the wind blows FROM in degrees, probability.
W = [2.0 245 0.52      % calm + light onshore (1.0-3.9 m/s bin)
     5.0 245 0.24      % established afternoon sea breeze
     7.5 240 0.04      % strong SW ponente, the wind-limit case
     3.5  50 0.20];    % offshore N-E land breeze / tramontana

% Sectors.  The whole coastal strip spans 41 km, which no single Matrice 4TD
% sortie can cross and return from; sectors are how a real deployment is
% organised, and the screens of Section 2.3 say which ones work.
% R is not a free choice -- it is read off screen P3.
L = struct( ...
 'name',   {'north','south','centre','full'}, ...
 'base',   {'CM_Laureana','Centola_AIB','VVF_Vallo','Centola_AIB'}, ...
 'c1',     {'Copersito','Palinuro','Elea_Velia','Elea_Velia'}, ...
 'R',      {3, 4, 3, 3}, ...
 'F',      {{'Agropoli','SanMartino','Coste'}, ...
          {'Lentiscosa','Scario','Roccagloriosa'}, ...
          {'Ceraso','Coste'}, ...
          {'Agropoli','Copersito','SanMartino','Coste','Ceraso', ...
           'Terradura_Ascea','Roccagloriosa','Palinuro','Scario','Lentiscosa'}}, ...
 'charge', {{'VVF_Agropoli'},{'CM_Futani'},{'Elis_Pattano'}, ...
            {'VVF_Vallo','CM_Futani','VVF_Agropoli'}}, ...
 'note',   {'Monte Stella massif; every screen passes, R_LB = 3', ...
            'around the regional AIB base at Centola; R_LB = 4', ...
            'Velia UNESCO site; NO existing base passes P2', ...
            'whole 41 km strip; fails P2/P3/P6, kept as evidence'});

switch what
    case 'sites',   out = S;
    case 'bases',   out = B;
    case 'wind',    out = W;
    case 'sectors', out = L;
    case 'geometry'
        if nargin < 2, arg = 'north'; end
        out = local_geometry(S, B, L, W, arg);
    otherwise
        error('unknown request %s', what);
end
end

% =========================================================================
function g = local_geometry(S, B, L, W, sector)
k = find(strcmp({L.name}, sector), 1);
assert(~isempty(k), 'unknown sector %s', sector);
s = L(k);
bi = find(strcmp(B(:,1), s.base), 1);
lat0 = B{bi,2};  lon0 = B{bi,3};

g.depot = [0 0];
g.c1    = local_project(S, s.c1, lat0, lon0);
g.F     = zeros(numel(s.F), 2);
for q = 1:numel(s.F)
    g.F(q,:) = local_project(S, s.F{q}, lat0, lon0);
end
g.charge = zeros(numel(s.charge), 2);
for q = 1:numel(s.charge)
    j = find(strcmp(B(:,1), s.charge{q}), 1);
    g.charge(q,:) = local_ll2xy(B{j,2}, B{j,3}, lat0, lon0);
end
g.R = s.R;  g.wind = W;  g.base = s.base;  g.c1name = s.c1;
g.Fnames = s.F;  g.note = s.note;  g.lat0 = lat0;  g.lon0 = lon0;

% mean site elevation of the sector, used to set the air-density altitude
els = zeros(1, numel(s.F) + 2);
for q = 1:numel(s.F)
    els(q) = S{strcmp(S(:,1), s.F{q}), 4};
end
els(end-1) = S{strcmp(S(:,1), s.c1), 4};
els(end)   = B{bi,4};
g.mean_terrain = mean(els);
end

function p = local_project(S, name, lat0, lon0)
i = find(strcmp(S(:,1), name), 1);
assert(~isempty(i), 'unknown site %s', name);
p = local_ll2xy(S{i,2}, S{i,3}, lat0, lon0);
end

function p = local_ll2xy(lat, lon, lat0, lon0)
p = [(lon - lon0)*111320*cosd(lat0), (lat - lat0)*110540];
end
