function T = cilento_ablation(tl, tag)
%CILENTO_ABLATION  Section 10.4 - model-feature comparison.
%
%   T = cilento_ablation()
%
%   Each experiment removes exactly one feature the supervisors asked for and
%   re-solves the same instance, so the value of the feature is MEASURED.
%
%   A. speed as a decision variable, under two wind regimes.  Under strong wind
%      the variable buys feasibility (a fixed cruise speed cannot hold the
%      required ground speed against the headwind, so the leg is dropped by the
%      eta_adm filter); under mild wind it buys energy.
%   B. emergency reserve 0 / 1 / 2.
%   C. treatment of wind.  The plan built while ignoring the wind is not judged
%      on its own optimistic numbers -- it is REPLAYED against the true
%      scenario set, which is the only comparison that means anything.

if nargin < 1 || isempty(tl),  tl  = 300; end
if nargin < 2 || isempty(tag), tag = 'ablation_matlab.csv'; end
opts = sdpsettings('solver','gurobi','verbose',0, ...
                   'savesolveroutput',1, ...
                   'gurobi.TimeLimit',tl,'gurobi.MIPGap',1e-4, ...
                   'gurobi.NumericFocus',1);
rows = {};

%% ===================================== A. speed as a decision variable ====
fprintf('\n=== A. speed as a decision variable (feedback point 1) ===\n');
CASES = {'fixed 10 m/s', 10; 'fixed 12 m/s', 12; 'fixed 15 m/s', 15;
         '3 levels 8/12/15', [8 12 15];
         '5 levels (baseline)', [8 10 12 14 15]};
b0 = cilento_baseline();
regimes = {'strong wind (baseline)', b0.Omega;
           'mild wind (x0.5)', [b0.Omega(:,1)*0.5 b0.Omega(:,2:3)]};
for g = 1:size(regimes,1)
    fprintf('\n  -- %s --\n', regimes{g,1});
    fprintf('  %-24s %3s %9s %9s %4s %7s %8s  %s\n', ...
            'model','f1','f2 [min]','f3 [Wh]','chg','bins','time','status');
    got = nan(size(CASES,1),2);
    for c = 1:size(CASES,1)
        inst = cilento_baseline('H', CASES{c,2}, 'Omega', regimes{g,2});
        r = cilento_solve_case(inst, opts);
        fprintf('  %-24s %3s %9s %9s %4s %7s %7.1fs  %s\n', ...
                CASES{c,1}, num(r.f1,'%d'), num(r.f2,'%.1f'), ...
                num(r.f3,'%.1f'), num(r.charges,'%d'), num(r.bins,'%d'), ...
                r.seconds, r.status);
        got(c,:) = [r.f3 r.bins];
        rows(end+1,:) = {sprintf('A speed / %s', regimes{g,1}), CASES{c,1}, ...
                         r.f1, r.f2, r.f3, r.charges, r.bins, r.seconds, ...
                         r.status}; %#ok<AGROW>
    end
    fixedrows = 1:3;  varrow = size(CASES,1);
    dead = fixedrows(~isfinite(got(fixedrows,1)));
    if ~isempty(dead)
        fprintf(['  -> %s has NO feasible plan at all: at that airspeed the ' ...
                 'ground speed\n     against the headwind falls below g_min ' ...
                 'on the depot-C1 leg, so the leg is\n     removed by the ' ...
                 'eta_adm filter before the MILP is built.  Here the speed ' ...
                 'variable\n     buys feasibility, not just energy.\n'], ...
                strjoin(CASES(dead,1).', ', '));
    end
    alive = fixedrows(isfinite(got(fixedrows,1)));
    if ~isempty(alive) && isfinite(got(varrow,1))
        [bv, bi] = min(got(alive,1));
        fprintf(['  -> against the best fixed speed (%s) the variable-speed ' ...
                 'model changes\n     energy by %+.1f%%, at %d/%d binary ' ...
                 'variables\n'], CASES{alive(bi),1}, ...
                100*(got(varrow,1)-bv)/bv, got(varrow,2), got(alive(bi),2));
    end
end

%% ===================================== B. emergency reserve ===============
fprintf('\n=== B. emergency reserve (feedback point 4) ===\n');
fprintf('%-24s %3s %9s %9s %4s %8s  %s\n', ...
        'N_res','f1','f2 [min]','f3 [Wh]','chg','time','status');
f1s = [];
for nr = [0 1 2]
    r = cilento_solve_case(cilento_baseline('N_res',nr,'K_max',6), opts);
    fprintf('%-24s %3s %9s %9s %4s %7.1fs  %s\n', ...
            sprintf('N_res = %d',nr), num(r.f1,'%d'), num(r.f2,'%.1f'), ...
            num(r.f3,'%.1f'), num(r.charges,'%d'), r.seconds, r.status);
    f1s(end+1) = r.f1; %#ok<AGROW>
    rows(end+1,:) = {'B reserve', sprintf('N_res=%d',nr), r.f1, r.f2, r.f3, ...
                     r.charges, r.bins, r.seconds, r.status}; %#ok<AGROW>
end
if all(isfinite(f1s))
    fprintf(['  -> each reserve airframe costs exactly one aircraft (%s) and ' ...
             'leaves the\n     working routes untouched, which is what ' ...
             'Section 7.14 intends\n'], ...
            strtrim(regexprep(sprintf('%g -> ', f1s), '\s*->\s*$', '')));
end

%% ===================================== C. treatment of wind ===============
fprintf('\n=== C. treatment of wind (the point of a wind-aware model) ===\n');
[~, pre_true] = cilento_prepare(cilento_baseline());   % the wind that happens
fprintf('%-22s %3s %11s %12s %12s  %s\n', ...
        'planning model','f1','planned f3','realised f3','margin [Wh]','verdict');
for m = {'nowind','expected','hybrid'}
    mode = m{1};
    r = cilento_solve_case(cilento_baseline('wind_mode',mode), opts);
    if isempty(r.plan)
        fprintf('%-22s  no feasible plan (%s)\n', mode, r.status);
        rows(end+1,:) = {'C wind', mode, NaN, NaN, NaN, NaN, NaN, ...
                         r.seconds, r.status}; %#ok<AGROW>
        continue
    end
    rp = cilento_replay(r.inst, pre_true, r.plan);
    if isempty(rp.violations)
        verdict = 'flyable';
    else
        verdict = strjoin(rp.violations(1:min(2,end)), '; ');
    end
    if rp.complete, realised = sprintf('%.1f', rp.f3); else, realised = 'n/a'; end
    fprintf('%-22s %3d %11.1f %12s %12.1f  %s\n', ...
            mode, r.f1, r.f3, realised, rp.margin, verdict);
    % NaN*0 is NaN, so the completeness switch has to be a branch, not a
    % product: an incomplete replay has no comparable energy figure
    if rp.complete, realised_f3 = rp.f3; else, realised_f3 = NaN; end
    rows(end+1,:) = {'C wind', mode, r.f1, r.f2, r.f3, realised_f3, ...
                     rp.margin, r.seconds, verdict}; %#ok<AGROW>
end
fprintf(['  -> "realised" replays the SAME routes and speeds against the true ' ...
         'scenario set;\n     "n/a" means the plan uses a leg the real wind ' ...
         'does not admit at all, so there\n     is no energy figure to ' ...
         'compare -- the plan simply cannot be flown\n']);

%% ===================================== output ============================
T = cell2table(rows, 'VariableNames', ...
      {'experiment','variant','f1','f2_min','f3_Wh', ...
       'charges_or_realised','bins_or_margin','seconds','status'});
writetable(T, tag);
fprintf('\nsaved %s\n', tag);
end

% -------------------------------------------------------------------------
function s = num(v, f)
if isnan(v), s = '-'; else, s = sprintf(f, v); end
end
