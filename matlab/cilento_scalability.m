function T = cilento_scalability(sizes, K, tl, obj)
%CILENTO_SCALABILITY  Section 10.2 - planned scalability experiment.
%
%   T = cilento_scalability([2 3 4 5 6 8 10], 4, 300, 'f3')
%
%   |F| is increased with everything else held fixed.  For every size the
%   table records model size, runtime, termination status, incumbent, best
%   bound and MIP gap, which is exactly what Section 10.2 asks to report.
%
%   The point layout is deterministic (fixed seed), so runs are comparable.

if nargin < 1 || isempty(sizes), sizes = [2 3 4 5 6 8 10]; end
if nargin < 2 || isempty(K),     K = 4;    end
if nargin < 3 || isempty(tl),    tl = 300; end
if nargin < 4 || isempty(obj),   obj = 'f3'; end

rng(20260815);

MAXF = 20;

base = [rand(MAXF,1)*8000-4000, ...
        rand(MAXF,1)*6000-2500];

% Timings without a machine and a solver version are not reportable numbers.
env = cilento_env(tl);
fprintf('environment: %s\n', env.text);
fid = fopen('scalability_env.txt','w'); fprintf(fid,'%s\n',env.text); fclose(fid);

fprintf('\n%4s %4s %6s %8s %8s %8s %9s %10s %24s %12s %12s %8s\n', ...
        '|F|','|N|','arcs','vars','bins','cons','time','nodes','status', ...
        'incumbent','bound','gap');

rows = {};
for nF = sizes
    in = make_instance(base(1:nF,:));
    pre = cilento_pre(in);
    if isfinite(pre.screens.tau_bat) && pre.screens.tau_bat < in.tau_C1_max
        in.tau_C1_max = floor(pre.screens.tau_bat);
        pre = cilento_pre(in);
    end

    o = sdpsettings('solver','gurobi','verbose',0, ...
                'savesolverinput',1, ...
                'savesolveroutput',1, ...
                'gurobi.TimeLimit',tl, ...
                'gurobi.MIPGap',1e-4, ...
                'gurobi.NumericFocus',1);
    M = cilento_milp(in, pre, K, in.N_res, o);
    switch obj
        case 'f1', f = M.f1; case 'f2', f = M.f2; otherwise, f = M.f3;
    end

    tic; d = optimize(M.Con, f, M.opts); el = toc;

    % ---- model size and solver statistics -------------------------------
    % Exact dimensions of the model passed by YALMIP to Gurobi
% Exact dimensions of the numerical model sent to Gurobi
gm = d.solverinput;

% In some YALMIP/Gurobi versions the actual Gurobi model
% is stored inside solverinput.model
if isstruct(gm) && isfield(gm,'model')
    gm = gm.model;
end

% Total number of variables
if isfield(gm,'obj')
    nv = numel(gm.obj);
elseif isfield(gm,'A')
    nv = size(gm.A,2);
elseif isfield(gm,'lb')
    nv = numel(gm.lb);
else
    nv = NaN;
end

% Number of binary variables
if isfield(gm,'vtype')
    vt = gm.vtype;

    if iscell(vt)
        vt = char(vt);
    end

    nb = sum(vt(:) == 'B');
else
    nb = NaN;
end

% Number of scalar linear constraints
if isfield(gm,'A')
    nc = size(gm.A,1);
else
    nc = NaN;
end
% ---- Gurobi solution status and statistics ----------------------------
inc   = NaN;
bnd   = NaN;
gap   = NaN;
nodes = NaN;

if isfield(d,'solveroutput') && ...
        isstruct(d.solveroutput) && ...
        isfield(d.solveroutput,'result')

    gr = d.solveroutput.result;

    % Branch-and-bound nodes
    if isfield(gr,'nodecount') && ~isempty(gr.nodecount)
        nodes = gr.nodecount;
    end

    % Best proven bound
    if isfield(gr,'objbound') && ~isempty(gr.objbound) ...
            && isfinite(gr.objbound)
        bnd = gr.objbound;
    end

    % Feasible incumbent reported directly by Gurobi
    if isfield(gr,'objval') && ~isempty(gr.objval) ...
            && isfinite(gr.objval)
        inc = gr.objval;
    end

    % Gurobi-reported MIP gap, when available
    if isfield(gr,'mipgap') && ~isempty(gr.mipgap) ...
            && isfinite(gr.mipgap)
        gap = gr.mipgap;
    end
end

% ---- termination status -----------------------------------------------
switch d.problem

    case 0
        status = 'optimal';

        % Safe fallback for a proven optimal solution
        if ~isfinite(inc)
            inc = value(f);
        end

        if ~isfinite(bnd)
            bnd = inc;
        end

        gap = 0;

    case 1
        status = 'infeasible';
        inc = NaN;
        gap = NaN;

    case 2
        status = 'unbounded';
        inc = NaN;
        gap = NaN;

    case 3
        % Do NOT use value(f) here.
        % For a time-limited run only Gurobi's reported objval
        % is accepted as a valid incumbent.
        if isfinite(inc)
            status = 'time-limit (incumbent)';

            % Reconstruct gap only when Gurobi did not report one
            if ~isfinite(gap) && isfinite(bnd)
                gap = max(0, (inc - bnd) / max(abs(inc),1));
            end
        else
            status = 'time-limit (no incumbent)';
            inc = NaN;
            gap = NaN;
        end

    otherwise
        status = sprintf('problem %d', d.problem);
        inc = NaN;
        gap = NaN;
end

    fprintf('%4d %4d %6d %8d %8d %8d %8.1fs %10.0f %24s %12.4g %12.4g %7.2f%%\n', ...
            nF, pre.n, size(pre.A,1), nv, nb, nc, el, nodes, status, inc, ...
            bnd, 100*gap);

    rows(end+1,:) = {nF, pre.n, size(pre.A,1), nv, nb, nc, el, nodes, ...
                     status, inc, bnd, gap}; %#ok
    Tpartial = cell2table(rows, 'VariableNames', ...
        {'nF','nN','arcs','vars','bins','cons','time_s','nodes','status', ...
        'incumbent','bound','gap'});

    writetable(Tpartial,'scalability_matlab.csv');
    if d.problem == 1
        fprintf('      (infeasible - continuing to the next size)\n');
    end
    if d.problem == 3
       fprintf('      (time limit reached - continuing to the next size)\n');
    end
end

T = cell2table(rows, 'VariableNames', ...
      {'nF','nN','arcs','vars','bins','cons','time_s','nodes','status', ...
       'incumbent','bound','gap'});
writetable(T, 'scalability_matlab.csv');
fprintf('\nsaved scalability_matlab.csv and scalability_env.txt\n');
scal_figures(T);
end

% =========================================================================
function env = cilento_env(tl)
%CILENTO_ENV  Machine and solver fingerprint that has to accompany timings.
%
%   Gurobi exposes no version function to MATLAB, so the install path is
%   reported instead -- it carries the version (…/gurobi1103/…) and is what a
%   reader needs in order to reproduce the run.
try, yv = yalmip('version'); catch, yv = 'unknown'; end
if isnumeric(yv), yv = num2str(yv); end
gp = which('gurobi');
if isempty(gp), gp = 'gurobi NOT on the path'; end
try, ncpu = feature('numcores'); catch, ncpu = NaN; end
env.matlab = version;  env.arch = computer('arch');  env.cores = ncpu;
env.yalmip = yv;  env.gurobi = gp;  env.time_limit = tl;
env.text = sprintf(['MATLAB %s on %s, %d cores | YALMIP %s | %s | ' ...
                    'TimeLimit %g s, MIPGap 1e-4, seed 20260815'], ...
                   version, computer('arch'), ncpu, yv, gp, tl);
end

% =========================================================================
function scal_figures(T)
%SCAL_FIGURES  Runtime, gap and model size against the instance size.
keys = {'time_s','solve time [s]','Runtime against instance size',true; ...
        'gap','MIP gap [%]','Optimality gap against instance size',false; ...
        'bins','binary variables','Model size against instance size',false};
files = cell(1,3);
for q = 1:3
    y = T.(keys{q,1});
    if strcmp(keys{q,1},'gap'), y = 100*y; end
    f = figure('Color','w','Position',[100 100 540 380]); ax = axes(f); hold(ax,'on');
    plot(ax, T.nF, y, '-o', 'Color',[0 0.45 0.70], 'LineWidth',1.5, ...
         'MarkerFaceColor',[0 0.45 0.70], 'MarkerSize',5);
    notopt = ~strcmp(T.status, 'optimal');
    if any(notopt)
        plot(ax, T.nF(notopt), y(notopt), 'x', 'Color',[0.84 0.37 0], ...
             'MarkerSize',11, 'LineWidth',1.8);
    end
    xlabel(ax,'number of historical points |F|'); ylabel(ax, keys{q,2});
    title(ax, keys{q,3}, 'FontSize',10);
    if keys{q,4}, set(ax,'YScale','log'); end
    grid(ax,'on'); ax.GridLineStyle = ':';
    files{q} = sprintf('fig_scal_%s.png', keys{q,1});
    exportgraphics(f, files{q}, 'Resolution',170); close(f);
end
fprintf('saved: %s  (x marks a run that did not prove optimality)\n', ...
        strjoin(files, ', '));
end

% =========================================================================
function in = make_instance(pts)

% Real north-sector baseline.
% For scalability, only the number/locations of historical
% fire points are changed.

in = cilento_baseline('sector','north');

% Synthetic historical points generated with a fixed seed
in.F = pts;

end

% -------------------------------------------------------------------------

