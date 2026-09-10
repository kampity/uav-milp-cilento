function T = cilento_depots(sector, tl, tag)
%CILENTO_DEPOTS  Section 10.5 - depot comparison for the Cilento case study.
%
%   T = cilento_depots()
%
%   Feedback point 5 asked whether the depot is unique.  In the formulation it
%   is: one d+ and one d-, both at the same site.  WHICH site is not a routing
%   decision but a design decision, and this is how it is answered -- the same
%   mission is re-solved from every candidate base and the candidates are
%   ranked lexicographically by fleet and then energy, the hierarchy of
%   Section 8.3.  Candidates rejected by the Section 2.3 screens never reach
%   the MILP.

if nargin < 1 || isempty(sector), sector = 'north'; end
if nargin < 2 || isempty(tl),     tl  = 300; end
if nargin < 3 || isempty(tag),    tag = 'depots_matlab.csv'; end
opts = sdpsettings('solver','gurobi','verbose',0, ...
                   'savesolveroutput',1, ...
                   'gurobi.TimeLimit',tl,'gurobi.MIPGap',1e-4, ...
                   'gurobi.NumericFocus',1);

B = cilento_case('bases');
L = cilento_case('sectors');
k = find(strcmp({L.name}, sector), 1);
fprintf('sector ''%s'': %s\n', sector, L(k).note);
fprintf('C1 = %s, F = %s, R = %d\n\n', L(k).c1, strjoin(L(k).F, ', '), L(k).R);

fprintf('%-14s %3s %3s %3s %3s %3s %3s %8s %3s %9s %9s %8s  %s\n', ...
        'candidate','P1','P2','P3','P4','P5','P6','toC1','f1','f2 [min]', ...
        'f3 [Wh]','time','status');
fprintf('%s\n', repmat('-',1,104));

rows = {};
for c = 1:size(B,1)
    name = B{c,1};
    inst = cilento_baseline('sector', sector, 'base', name);
    [~, pre] = cilento_prepare(inst);
    sc = pre.screens;
    flags = [sc.P1_ok sc.P2_ok sc.P3_ok sc.P4_ok sc.P5_ok sc.P6_ok];
    r = cilento_solve_case(inst, opts, true, 0, []);
    if r.proven, mk = ''; else, mk = '*'; end
    fprintf('%-14s %3d %3d %3d %3d %3d %3d %7.0fs %3s %9s %9s %7.1fs  %s\n', ...
            name, flags, sc.P1_min_travel, num(r.f1,'%d'), ...
            [num(r.f2,'%.1f') mk], [num(r.f3,'%.1f') mk], r.seconds, r.status);
    rows(end+1,:) = {name, B{c,5}, double(flags(1)), double(flags(2)), ...
                     double(flags(3)), double(flags(4)), double(flags(5)), ...
                     double(flags(6)), sc.P1_min_travel, sc.P6_min_slack_Wh, ...
                     r.f1, r.f2, r.f3, double(r.proven), r.seconds, ...
                     r.status}; %#ok<AGROW>
end

f1v = cell2mat(rows(:,11));  f2v = cell2mat(rows(:,12));
f3v = cell2mat(rows(:,13));  pv = cell2mat(rows(:,14));
ok  = find(isfinite(f3v));
if ~isempty(ok)
    % Fleet, then MAKESPAN, then energy -- the full hierarchy of Section 8.3.
    % f1 is rounded first: it comes back with floating-point noise and a raw
    % comparison would break ties arbitrarily.
    [~, order] = sortrows([round(f1v(ok)) f2v(ok) f3v(ok)]);
    best = ok(order(1));
    fprintf('\nbest base: %s (%s)\n', rows{best,1}, rows{best,2});
    if pv(best), extra = ''; else, extra = '   (incumbent, not proven)'; end
    fprintf('  %g UAV, %.1f min, %.1f Wh%s\n', ...
            f1v(best), f2v(best), f3v(best), extra);
    if numel(ok) == 1
        fprintf(['  it is the ONLY candidate that survives the screens: ' ...
                 'every other base is\n  too far from this sector for the ' ...
                 'airframe.\n']);
    end
else
    fprintf('\nno candidate base survives the screens for this sector.\n');
end

T = cell2table(rows, 'VariableNames', ...
      {'base','type','P1','P2','P3','P4','P5','P6','min_travel_to_C1_s', ...
       'P6_min_slack_Wh','f1','f2_min','f3_Wh','proven','seconds','status'});
writetable(T, tag);
fprintf('saved %s\n', tag);
end

% -------------------------------------------------------------------------
function s = num(v, f)
if isnan(v), s = '-'; else, s = sprintf(f, v); end
end
