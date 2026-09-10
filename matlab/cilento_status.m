function [label, has_inc, proven, gap] = cilento_status(d, obj)
%CILENTO_STATUS  Honest reading of a YALMIP/Gurobi termination.
%
%   [label, has_inc, proven, gap] = cilento_status(d)
%   [label, has_inc, proven, gap] = cilento_status(d, obj)
%
%   YALMIP's problem codes are:  0 solved, 1 infeasible, 2 unbounded,
%   3 maximum iterations / time limit exceeded, 4 numerical problems.
%
%   Code 3 is NOT by itself proof that a feasible solution exists -- Gurobi can
%   hit the time limit with an empty solution pool.  The distinction matters
%   for every scalability and sensitivity row, so it is made here once:
%
%     'optimal'                     proven optimal
%     'time-limit (incumbent)'      stopped early, a feasible point is in hand
%     'time-limit (no incumbent)'   stopped early with nothing to report
%     'infeasible' / 'unbounded' / 'solver problem N'
%
%   Where the solver output is available the incumbent is decided by Gurobi's
%   own SolCount / objval rather than guessed.

if nargin < 2, obj = []; end
gap = NaN;  has_inc = false;  proven = false;

solcount = [];
if isfield(d, 'solveroutput') && isstruct(d.solveroutput) ...
        && isfield(d.solveroutput, 'result')
    gr = d.solveroutput.result;
    if isfield(gr, 'solcount'), solcount = gr.solcount; end
    if isfield(gr, 'mipgap'),   gap = gr.mipgap; end
    if isempty(solcount) && isfield(gr, 'objval'), solcount = 1; end
end

switch d.problem
    case 0
        label = 'optimal';  has_inc = true;  proven = true;
    case 1
        label = 'infeasible';
    case 2
        label = 'unbounded';
    case 3
        if ~isempty(solcount)
            has_inc = solcount >= 1;
        else
            % no solver output to consult: fall back to whether the objective
            % actually carries a value
            has_inc = ~isempty(obj) && all(isfinite(value(obj)));
        end
        if has_inc
            label = 'time-limit (incumbent)';
        else
            label = 'time-limit (no incumbent)';
        end
    otherwise
        label = sprintf('solver problem %d', d.problem);
end
end
