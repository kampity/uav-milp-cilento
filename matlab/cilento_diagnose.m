function cilento_diagnose(in, K, Nres)
%CILENTO_DIAGNOSE  Locate the constraint block that makes a model infeasible.
%
%   cilento_diagnose(inst, K, Nres)
%
%   Gurobi's IIS is the proper tool, but it works on the flattened model and
%   the constraint names are lost through YALMIP.  This does the cheap thing
%   instead: rebuild the model with one section relaxed at a time and report
%   which relaxation restores feasibility.
%
%   Reading the output: a block that restores feasibility is IMPLICATED, not
%   necessarily wrong.  Relaxing 7.4, 7.7 or 7.10 always restores feasibility
%   because it makes travel or energy free, so those three are not diagnostic
%   on their own - look at the others first.

if nargin < 2, K = 3; end
if nargin < 3, Nres = 0; end

BLOCKS = {'7.1','7.2','7.3','7.4','7.5','7.6','7.7', ...
          '7.8','7.9','7.10','7.11','7.12','7.13','7.14'};

pre = cilento_pre(in);
sc = pre.screens;
fprintf('--- preprocessing screens (Section 2.3) ---\n');
fprintf('  P1 reachability : %d   (min travel to C1 %.0f s, T_C1_start %.0f s)\n', ...
        sc.P1_ok, sc.P1_min_travel, in.T_C1_start);
fprintf('  P2 keeper energy: %d   (tau_bat %.0f s, tau_max %.0f s, tau_eff %.0f s)\n', ...
        sc.P2_ok, sc.tau_bat, in.tau_C1_max, sc.tau_eff);
fprintf('  P3 keeper count : %d   (R_LB %d, R %d)\n', sc.P3_ok, sc.R_LB, in.R);
if ~sc.P2_ok || ~sc.P3_ok || ~sc.P1_ok
    fprintf('  >> a screen already fails: fix the instance before blaming the model\n');
end

M = cilento_milp(in, pre, K, Nres);
d = optimize(M.Con, M.f1, M.opts);
if d.problem == 0 || d.problem == 3
    fprintf('\nfull model is FEASIBLE (f1 = %g) - nothing to diagnose\n', value(M.f1));
    return
end

fprintf('\n--- drop-one test ---\n');
for b = 1:numel(BLOCKS)
    Mb = cilento_milp_skip(in, pre, K, Nres, BLOCKS{b});
    db = optimize(Mb.Con, Mb.f1, Mb.opts);
    if db.problem == 0 || db.problem == 3
        fprintf('  without %-5s -> FEASIBLE  (block %s implicated)\n', ...
                BLOCKS{b}, BLOCKS{b});
    else
        fprintf('  without %-5s -> still infeasible\n', BLOCKS{b});
    end
end
end

% -------------------------------------------------------------------------
function M = cilento_milp_skip(in, pre, K, Nres, block)
%CILENTO_MILP_SKIP  Rebuild with one section relaxed.
%
%   Implemented by loosening the parameters that generate the block rather
%   than by editing the model file, so cilento_milp.m stays the single source
%   of truth.  Sections that cannot be relaxed parametrically are handled by
%   widening their right-hand sides.
in2 = in;
switch block
    case '7.8'                          % drop the C1 relay requirements
        in2.O_C1 = 0; in2.tau_C1_min = 0; in2.tau_C1_max = in.T_max;
        in2.T_C1_end = in.T_C1_start;
    case '7.11'                         % unlimited charging
        for s = 1:numel(in2.stations)
            in2.stations(s).dmin = 0;
            in2.stations(s).P_rated = in2.stations(s).P_rated*100;
        end
    case '7.13'
        in2.T_max = in.T_max*10;
    case '7.14'
        Nres = 0;
    otherwise
        % energy / timing blocks: relax by giving the aircraft a huge battery
        if any(strcmp(block, {'7.7','7.10','7.12'}))
            in2.gamma_use = 100;
        end
        if any(strcmp(block, {'7.5','7.6'}))
            in2.T_max = in.T_max*10;
        end
end
pre2 = cilento_pre(in2);
M = cilento_milp(in2, pre2, K, Nres);
end
