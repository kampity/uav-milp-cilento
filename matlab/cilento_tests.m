function results = cilento_tests(verbose)
%CILENTO_TESTS  Section 10.1 - small-instance debugging protocol.
%
%   results = cilento_tests()      runs the whole table and prints PASS/FAIL
%
%   Each test builds the smallest instance that exercises one constraint
%   block.  The expected outcome is stated per test, so an unexpected
%   FEASIBLE is as much a failure as an unexpected INFEASIBLE.

if nargin < 1, verbose = true; end
CALM   = [0 0 1];                       % windless single scenario
BREEZE = [4 270 0.6; 8 315 0.4];
results = struct([]);  nP = 0; nF = 0;

%% 01 - routing, 3 points, 1 UAV.  R>=2 needs two distinct keepers -> must fail
in = base(); in.F = [800 200; 1200 900; 400 1100]; in.stations = [];
in.R = 2; in.K_max = 1; in.tau_C1_min = 600; in.tau_C1_max = 3000;
in.T_C1_start = 200; in.T_C1_end = 1200; in.T_max = 9000; in.Omega = CALM;
[results,nP,nF] = t(results,nP,nF,'01 routing 3 pts 1 UAV', in,1,'f1','infeasible',verbose);

%% 02 - routing + C1 relay with 3 UAVs
in = base(); in.F = [800 200; 1200 900]; in.stations = [];
in.R = 3; in.K_max = 3; in.tau_C1_min = 600; in.tau_C1_max = 3000;
in.T_C1_start = 200; in.T_C1_end = 1200; in.T_max = 9000; in.Omega = CALM;
[results,nP,nF] = t(results,nP,nF,'02 routing + C1 relay', in,3,'f1','feasible',verbose,true);

%% 03 - late C1 start: the planned backup must wait on the ground, tdep > 0
in = base(); in.F = [800 200]; in.stations = [];
in.R = 2; in.K_max = 2; in.tau_C1_min = 600; in.tau_C1_max = 2000;
in.T_C1_start = 3000; in.T_C1_end = 4200; in.T_max = 9000; in.Omega = CALM;
[results,nP,nF] = t(results,nP,nF,'03 depot standby', in,2,'f1','feasible',verbose,true);

%% 04 - speed selection under minimum energy
in = base(); in.F = [3000 0]; in.stations = [];
in.R = 2; in.K_max = 2; in.tau_C1_min = 600; in.tau_C1_max = 2000;
in.T_C1_start = 400; in.T_C1_end = 1400; in.T_max = 9000; in.Omega = CALM;
[results,nP,nF] = t(results,nP,nF,'04 speed selection', in,2,'f3','feasible',verbose,true);

%% 05 - wind: arcs become directional
in = base(); in.F = [3000 0];
in.stations = st(2000,300,1,2,900);
in.R = 3; in.K_max = 3; in.tau_C1_min = 600; in.tau_C1_max = 1500;
in.T_C1_start = 400; in.T_C1_end = 1400; in.T_max = 9000; in.Omega = BREEZE;
[results,nP,nF] = t(results,nP,nF,'05 wind directional arcs', in,3,'f3','feasible',verbose,true);

%% 06 - reduced usable battery must make a long mission infeasible
in = base(); in.F = [9000 6000]; in.stations = []; in.gamma_use = 0.25;
in.R = 2; in.K_max = 2; in.tau_C1_min = 600; in.tau_C1_max = 2000;
in.T_C1_start = 400; in.T_C1_end = 1400; in.T_max = 9000; in.Omega = CALM;
[results,nP,nF] = t(results,nP,nF,'06 battery too small', in,2,'f1','infeasible',verbose);

%% 07 - charging station used inside a route
in = base(); in.F = [2500 1500; 3000 200]; in.gamma_use = 0.60;
in.stations = st(1800,600,1,2,900);
in.R = 3; in.K_max = 4; in.tau_C1_min = 600; in.tau_C1_max = 1200;
in.T_C1_start = 400; in.T_C1_end = 1600; in.T_max = 9000; in.Omega = CALM;
[results,nP,nF] = t(results,nP,nF,'07 charging in route', in,4,'f1','feasible',verbose,true);

%% 08 - emergency reserve: test N_res = 0 and N_res = 1 as ONE test
in = base();
in.F = [800 200];
in.stations = [];
in.R = 2;
in.K_max = 3;
in.tau_C1_min = 600;
in.tau_C1_max = 2000;
in.T_C1_start = 400;
in.T_C1_end = 1400;
in.T_max = 9000;
in.Omega = CALM;

% Run the two subcases separately, but do NOT add them separately
% to the global test counter.
tmp08 = struct([]);
p08 = 0;
f08 = 0;

[tmp08,p08,f08] = t(tmp08,p08,f08, ...
    '08a reserve Nres=0', ...
    in,3,'f1','feasible',verbose,false,0);

[tmp08,p08,f08] = t(tmp08,p08,f08, ...
    '08b reserve Nres=1', ...
    in,3,'f1','feasible',verbose,true,1);

% Test 08 passes only if BOTH subcases pass
ok08 = all([tmp08.ok]);

if ok08
    nP = nP + 1;
else
    nF = nF + 1;
end

% Add ONE combined row to the final results table.
% Copy results(1) first so the structure has exactly the same fields.
r08 = results(1);

r08.name = '08 emergency reserve Nres=0/1';
r08.ok = ok08;
r08.time = sum([tmp08.time]);
r08.obj = NaN;
r08.status = max([tmp08.status]);
r08.expected = 'feasible';

if all(strcmp({tmp08.observed},'feasible'))
    r08.observed = 'feasible';
else
    r08.observed = 'failed';
end

% Keep checks from BOTH subcases, so the total number
% of independent checks is not lost.
r08.checks = sum([tmp08.checks]);
r08.violations = sum([tmp08.violations]);

results(end+1) = r08;

%% 09 - structural: no zero-distance arcs between copies of one location
in = base(); in.F = [800 200]; in.stations = st(1200,400,2,2,900);
in.R = 3; in.K_max = 2; in.tau_C1_min = 600; in.tau_C1_max = 2000;
in.T_C1_start = 400; in.T_C1_end = 1400; in.T_max = 9000; in.Omega = CALM;
p = cilento_pre(in);
bad = 0;
for ia = 1:size(p.A,1)
    if norm(p.xy(p.A(ia,2),:) - p.xy(p.A(ia,1),:)) < 1e-9, bad = bad + 1; end
end
ok = (bad == 0);
if ok, nP = nP+1; else, nF = nF+1; end
fprintf('[%s] %-28s zero-distance arcs: %d\n', tf(ok), '09 same-location copies', bad);
% Add test 09 to the final summary table and CSV.
% It is a structural test, so it has no solver objective
% and no independent replay checks.

r09 = results(1);

r09.name = '09 same-location copies';
r09.ok = ok;
r09.time = 0;
r09.obj = NaN;
r09.status = 0;
r09.expected = 'zero arcs';

if ok
    r09.observed = 'zero arcs';
else
    r09.observed = sprintf('%d arcs', bad);
end

r09.checks = 0;
r09.violations = 0;

results(end+1) = r09;
%% 10 - MTZ under the conditions in which a disconnected cycle would be cheapest
in = base(); in.F = [700 300; 1400 250; 2100 700; 1800 1500; 600 1400];
in.stations = st(1500,100,1,2,900);
in.R = 3; in.K_max = 4; in.tau_C1_min = 600; in.tau_C1_max = 1800;
in.T_C1_start = 600; in.T_C1_end = 2400; in.T_max = 14400; in.Omega = CALM;
[results,nP,nF] = t(results,nP,nF,'10 MTZ, 5 optional points', in,4,'f3','feasible',verbose,true);

%% 11 - K deliberately larger than needed: surplus vehicles must stay on the ground
in = base(); in.F = [800 200]; in.stations = [];
in.R = 2; in.K_max = 5; in.tau_C1_min = 600; in.tau_C1_max = 2000;
in.T_C1_start = 400; in.T_C1_end = 1400; in.T_max = 9000; in.Omega = CALM;
[results,nP,nF] = t(results,nP,nF,'11 surplus fleet stays idle', in,5,'f1','feasible',verbose);

%% 12 - reserve counts towards the fleet but must not fly
in = base(); in.F = [800 200]; in.stations = [];
in.R = 2; in.K_max = 4; in.tau_C1_min = 600; in.tau_C1_max = 2000;
in.T_C1_start = 400; in.T_C1_end = 1400; in.T_max = 9000; in.Omega = CALM;
[results,nP,nF] = t(results,nP,nF,'12 reserve in fleet, not routed', in,4,'f1','feasible',verbose,false,1);

%% ---------------------------------------------------------- summary table
fprintf('\n%s\n', repmat('=',1,92));
fprintf('%-34s %-12s %-12s %8s %8s  result\n', ...
        'test','expected','observed','checks','time');
tot = 0; bad = 0;
for q = 1:numel(results)
    rr = results(q);
    if rr.checks > 0, c = sprintf('%d/%d', rr.checks-rr.violations, rr.checks);
    else,             c = '-'; end
    fprintf('%-34s %-12s %-12s %8s %7.1fs  %s\n', ...
            rr.name, rr.expected, rr.observed, c, rr.time, tf(rr.ok));
    tot = tot + rr.checks; bad = bad + rr.violations;
end
fprintf('\n%d passed, %d failed, %d independent checks, %d violations\n', ...
        nP, nF, tot, bad);
if ~isempty(results)
    writetable(struct2table(results), 'tests_matlab.csv');
    fprintf('saved tests_matlab.csv\n');
end
end

% =========================================================================
function in = base()
in.depot = [0 0];  in.c1 = [1500 800];  in.F = [];  in.stations = [];
in.tau_obs = 900;  in.O_C1 = 420;  in.tau_C1_min = 420;  in.tau_C1_max = 1800;
in.T_C1_start = 0; in.T_C1_end = 14400;  in.T_max = 14400;
in.K_max = 6;  in.R = 4;  in.T_resp = 900;  in.N_res = 0;
in.Q_nom = 149.9*3600;  in.gamma_use = 0.90;  in.rho_res = 0.20;
in.P_sens = 30;  in.E_TO = 4800;  in.E_LD = 5700;
in.H = [8 10 12 14 15];  in.w_max = 12;  in.g_min = 3;  in.eta_adm = 0.90;
in.Omega = [0 0 1];
in.mass = 1.85;  in.d_prop = 0.328;  in.alt_op = 400;
end

function S = st(x,y,bays,visits,P)
S = struct('xy',[x y],'bays',bays,'visits',visits,'P_rated',P, ...
           'eta_ch',0.90,'dmin',300,'dmax',3600);
end

function s = tf(ok), if ok, s = 'PASS'; else, s = 'FAIL'; end, end

% -------------------------------------------------------------------------
function [res,nP,nF] = t(res,nP,nF,name,in,K,obj,expect,verbose,show,Nres)
if nargin < 10, show = false; end
if nargin < 11, Nres = in.N_res; end

pre = cilento_pre(in);
% Section 4.5: cap tau_C1_max by the P2 battery screen before building
if isfinite(pre.screens.tau_bat) && pre.screens.tau_bat < in.tau_C1_max
    in.tau_C1_max = floor(pre.screens.tau_bat);
    pre = cilento_pre(in);
end

M = cilento_milp(in, pre, K, Nres);
switch obj, case 'f1', o = M.f1; case 'f2', o = M.f2; otherwise, o = M.f3; end

tic; d = optimize(M.Con, o, M.opts); el = toc;
feas = (d.problem == 0) || (d.problem == 3);          % optimal, or limit+incumbent
got = 'infeasible';  if feas, got = 'feasible'; end
ok  = strcmp(got, expect);

% Every feasible answer is additionally replayed by the independent checker.
% A point that satisfies the rows but not the physics is a FAILURE of the
% test, not a success -- that is the whole reason the checker exists.
nchk = 0; nbad = 0; ck = [];
if feas
    plan = cilento_extract(in, pre, M);
    ck = cilento_verify(in, pre, plan, strcmp(obj,'f2'));
    nchk = ck.n;  nbad = ck.nfail;
    ok = ok && ck.ok;
end
if ok, nP = nP+1; else, nF = nF+1; end

val = NaN;  if feas, val = value(o); end
if nchk > 0, chk = sprintf('checks %d/%d', nchk-nbad, nchk); else, chk = ''; end
fprintf('[%s] %-28s %-11s obj=%-10.4g %5.1fs  %-12s %s\n', ...
        tf(ok), name, got, val, el, chk, yalmiperror(d.problem));
if nbad > 0
    for q = 1:numel(ck.rows)
        if ~ck.rows{q}{2}
            fprintf('        [FAIL] %s -- %s\n', ck.rows{q}{1}, ck.rows{q}{3});
        end
    end
end

if show && feas && verbose
    print_solution(M, pre, in);
end
res(end+1).name = name; res(end).ok = ok; res(end).time = el;
res(end).obj = val; res(end).status = d.problem;
res(end).expected = expect; res(end).observed = got;
res(end).checks = nchk; res(end).violations = nbad;
end

% -------------------------------------------------------------------------
function print_solution(M, pre, in)
A = pre.A;
for k = 1:M.K
    used = find(value(M.x(:,k)) > 0.5).';
    if isempty(used), continue, end
    succ = containers.Map(num2cell(A(used,1)), num2cell(A(used,2)));
    cur = pre.dplus; path = pre.tag{cur}; guard = 0;
    while isKey(succ, cur) && guard < 50
        cur = succ(cur); path = [path ' -> ' pre.tag{cur}]; guard = guard + 1; %#ok
    end
    sp = '';
    Z = value(M.z{k});
    for ia = used
        h = find(Z(ia,:) > 0.5, 1);
        if ~isempty(h)
            sp = [sp sprintf(' %s->%s:%gm/s', pre.tag{A(ia,1)}, ...
                             pre.tag{A(ia,2)}, in.H(h))]; %#ok
        end
    end
    fprintf('       UAV%d: %s  tdep=%.1f min |%s\n', k, path, ...
            value(M.tdep(k)), sp);
end
fprintf('       C1 windows:');
for r = 1:in.R
    who = find(value(M.r(pre.C(r),:)) > 0.5);
    fprintf(' [%.1f,%.1f]->UAV%d', value(M.alpha(r)), value(M.beta(r)), who);
end
fprintf('\n');
end
