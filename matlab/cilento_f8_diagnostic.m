function cilento_f8_diagnostic
%CILENTO_F8_DIAGNOSTIC
% Distinguishes infeasibility from objective-related unboundedness
% for the |F| = 8 scalability instance.

rng(20260815);

% IMPORTANT:
% Use the same fixed pool as the corrected scalability experiment.
MAXF = 20;
base = [rand(MAXF,1)*8000-4000, ...
        rand(MAXF,1)*6000-2500];

nF = 8;
K  = 4;
tl = 600;

% Same instance construction as cilento_scalability
in = cilento_baseline('sector','north');
in.F = base(1:nF,:);

pre = cilento_pre(in);

if isfinite(pre.screens.tau_bat) && ...
        pre.screens.tau_bat < in.tau_C1_max
    in.tau_C1_max = floor(pre.screens.tau_bat);
    pre = cilento_pre(in);
end

o = sdpsettings( ...
    'solver','gurobi', ...
    'verbose',1, ...
    'savesolverinput',1, ...
    'savesolveroutput',1, ...
    'gurobi.TimeLimit',tl, ...
    'gurobi.MIPGap',1e-4, ...
    'gurobi.NumericFocus',1);

M = cilento_milp(in, pre, K, in.N_res, o);

fprintf('\n========================================\n');
fprintf('F8 FEASIBILITY DIAGNOSTIC\n');
fprintf('|F| = %d, K = %d\n',nF,K);
fprintf('Nodes = %d, arcs = %d\n',pre.n,size(pre.A,1));
fprintf('========================================\n\n');

%% TEST 1: feasibility only — no objective
fprintf('TEST 1: constraints only, NO objective\n');

tic;
d0 = optimize(M.Con, [], M.opts);
t0 = toc;

fprintf('\nYALMIP problem code = %d\n',d0.problem);
fprintf('YALMIP message      = %s\n',yalmiperror(d0.problem));
fprintf('runtime             = %.3f s\n',t0);

if d0.problem == 0
    fprintf('\nRESULT: F8 IS FEASIBLE.\n');
    fprintf(['Therefore the previous "problem 12" was not proof of ' ...
             'infeasibility.\n']);
else
    fprintf('\nFeasibility solve did not return an optimal feasible point.\n');
end

%% TEST 2: original energy objective
fprintf('\n----------------------------------------\n');
fprintf('TEST 2: original objective f3\n');

tic;
d3 = optimize(M.Con, M.f3, M.opts);
t3 = toc;

fprintf('\nYALMIP problem code = %d\n',d3.problem);
fprintf('YALMIP message      = %s\n',yalmiperror(d3.problem));
fprintf('runtime             = %.3f s\n',t3);

if d3.problem == 0
    fprintf('f3 = %.6f Wh\n',value(M.f3));
end

%% Print raw Gurobi status when available
if isfield(d0,'solveroutput') && ...
        isstruct(d0.solveroutput) && ...
        isfield(d0.solveroutput,'result')

    gr0 = d0.solveroutput.result;

    if isfield(gr0,'status')
        fprintf('\nGurobi feasibility status = %s\n',string(gr0.status));
    end
end

if isfield(d3,'solveroutput') && ...
        isstruct(d3.solveroutput) && ...
        isfield(d3.solveroutput,'result')

    gr3 = d3.solveroutput.result;

    if isfield(gr3,'status')
        fprintf('Gurobi f3 status          = %s\n',string(gr3.status));
    end

    if isfield(gr3,'objval') && ~isempty(gr3.objval)
        fprintf('Gurobi incumbent          = %.6f\n',gr3.objval);
    end

    if isfield(gr3,'objbound') && ~isempty(gr3.objbound)
        fprintf('Gurobi best bound         = %.6f\n',gr3.objbound);
    end
end

fprintf('\n========================================\n');
fprintf('END F8 DIAGNOSTIC\n');
fprintf('========================================\n');

end