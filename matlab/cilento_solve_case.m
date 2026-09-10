function r = cilento_solve_case(inst, opts, docheck, eps2, screens)
%CILENTO_SOLVE_CASE  Section 9.1 fleet search, then minimum energy at that fleet.
%
%   r = cilento_solve_case(inst, opts)
%
%   One place defines what "solving an instance" means, so the sensitivity,
%   ablation and depot tables are comparable by construction.
%
%   r.f1 r.f2 r.f3   NaN when no feasible fleet exists
%   The pipeline is the lexicographic hierarchy of Section 8.3, not a shortcut:
%        stage 1  minimise f1                                     -> f1*
%        stage 2  f1 = f1*, minimise f2                           -> f2*
%        stage 3  f1 = f1*, f2 <= f2* + eps2*|f2*|, minimise f3   -> f3*
%   With eps2 = 0 this is the strict lexicographic optimum.  Reporting the
%   makespan of a minimum-energy solution instead of f2* would put a number in
%   the f2 column that is NOT the minimum makespan.
%
%   r.proven is true only when EVERY stage was solved to proven optimality;
%   otherwise the values are incumbents and must be reported as such.

if nargin < 2 || isempty(opts)
    opts = sdpsettings('solver','gurobi','verbose',0, ...
                'savesolveroutput',1, ...
                'gurobi.TimeLimit',300, ...
                'gurobi.MIPGap',1e-4, ...
                'gurobi.NumericFocus',1);
end

if nargin < 3 || isempty(docheck), docheck = true; end
if nargin < 4 || isempty(eps2), eps2 = 0; end

if nargin < 5 || isempty(screens)
    if isfield(inst,'N_res') && inst.N_res > 0
        screens = {'P1','P2','P3','P4','P5','P6'};
    else
        screens = {'P1','P2','P3','P6'};
    end
end

t0 = tic;
r = struct('f1',NaN,'f2',NaN,'f3',NaN,'charges',NaN,'status','infeasible', ...
           'seconds',0,'checks',0,'violations',0,'K',NaN,'inst',inst, ...
           'pre',[],'plan',[],'bins',NaN,'proven',false,'gap',NaN, ...
           'makespan_realised',NaN);

[inst, pre] = cilento_prepare(inst);
r.inst = inst;  r.pre = pre;
sc = pre.screens;
bad = {};
for q = 1:numel(screens)
    if ~sc.([screens{q} '_ok']), bad{end+1} = screens{q}; end %#ok<AGROW>
end
if ~isempty(bad)
    r.status = ['screen fail: ' strjoin(bad, ',')];
    r.seconds = toc(t0);  return
end

% ---- exact fleet-size search -------------------------------------------
% We increase K one by one.
%
% Only a PROVEN infeasible K allows us to continue to K+1.
% If Gurobi reaches the time limit with NO incumbent, we must stop:
% otherwise a larger K could be incorrectly reported as the minimum fleet.

Kstar = [];
f1 = NaN;
labels = {};

for K = 1:inst.K_max

    M = cilento_milp(inst, pre, K, inst.N_res, opts);
    d = optimize(M.Con, M.f1, opts);

    [lab, has_inc] = cilento_status(d, M.f1);

    % ---------------------------------------------------------------
    % Case 1: K is PROVEN infeasible
    % It is safe to test K+1.
    % ---------------------------------------------------------------
    if d.problem == 1
        fprintf('K = %d: proven infeasible\n', K);
        continue
    end

    % ---------------------------------------------------------------
    % Case 2: time limit and NO feasible incumbent
    % We cannot know whether this K is feasible or infeasible.
    % Therefore the exact minimum fleet is unresolved.
    % STOP instead of continuing to a larger K.
    % ---------------------------------------------------------------
    if d.problem == 3 && ~has_inc
        r.status = sprintf( ...
            'fleet search unresolved at K=%d: %s', K, lab);

        r.seconds = toc(t0);

        fprintf(['K = %d: time limit with no incumbent.\n' ...
                 'Exact minimum fleet cannot be established.\n'], K);

        return
    end

    % ---------------------------------------------------------------
    % Case 3: another solver/numerical failure with no incumbent
    % Do not silently skip this K.
    % ---------------------------------------------------------------
    if ~has_inc
        r.status = sprintf( ...
            'fleet search stopped at K=%d: %s', K, lab);

        r.seconds = toc(t0);

        fprintf('K = %d: %s\n', K, lab);

        return
    end

    % ---------------------------------------------------------------
    % Case 4: a feasible solution exists.
    %
    % Because every smaller K was PROVEN infeasible, this is the
    % minimum feasible fleet capacity.
    % ---------------------------------------------------------------
    Kstar = K;

    % f1 is an integer fleet-size objective; round numerical noise.
    f1 = round(value(M.f1));

    labels{end+1} = lab; %#ok<AGROW>

    fprintf('K = %d: feasible (%s), f1 = %.0f\n', ...
            K, lab, f1);

    break
end

% No feasible K up to K_max
if isempty(Kstar)
    r.status = sprintf( ...
        'infeasible for all K = 1,...,%d', inst.K_max);

    r.seconds = toc(t0);

    return
end

% ---- stage 2: minimum makespan at that fleet ---------------------------
M2 = cilento_milp(inst, pre, Kstar, inst.N_res, opts);
d2 = optimize([M2.Con, M2.f1 <= f1 + 1e-6], M2.f2, opts);
[lab2, inc2] = cilento_status(d2, M2.f2);
if ~inc2, r.status = ['stage 2: ' lab2]; r.seconds = toc(t0); return, end
f2 = value(M2.f2);
labels{end+1} = lab2;

% ---- stage 3: minimum energy, makespan within eps2 ---------------------
M3 = cilento_milp(inst, pre, Kstar, inst.N_res, opts);
d3 = optimize([M3.Con, M3.f1 <= f1 + 1e-6, ...
               M3.f2 <= f2 + eps2*abs(f2) + 1e-6], M3.f3, opts);
[lab3, inc3, ~, gap3] = cilento_status(d3, M3.f3);
if ~inc3, r.status = ['stage 3: ' lab3]; r.seconds = toc(t0); return, end
labels{end+1} = lab3;

plan = cilento_extract(inst, pre, M3);
der  = cilento_derive(inst, pre, plan);
r.f1 = f1;  r.f2 = f2;  r.f3 = value(M3.f3);
r.makespan_realised = der.makespan;
r.K = Kstar;  r.plan = plan;  r.gap = gap3;
r.charges = 0;
for k = 1:plan.K
    r.charges = r.charges + numel(intersect(plan.veh(k).served, pre.S));
end
r.proven = all(strcmp(labels, 'optimal'));
if r.proven, r.status = 'optimal'; else, r.status = 'time-limit (incumbent)'; end
r.bins = numel(intersect(depends(M3.Con), yalmip('binvariables')));

if docheck
    ck = cilento_verify(inst, pre, r.plan);
    r.checks = ck.n;  r.violations = ck.nfail;
    r.check = ck;
end
r.seconds = toc(t0);
end
