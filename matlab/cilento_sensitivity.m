function T = cilento_sensitivity(tl, tag)
%CILENTO_SENSITIVITY  Section 10.3 - one-at-a-time sensitivity analysis.
%
%   T = cilento_sensitivity()        300 s per solve
%   T = cilento_sensitivity(120)     shorter limit, faster sweep
%
%   Scalability asks how hard the MILP is to SOLVE.  This asks how far the
%   OPTIMUM MOVES when an assumption moves.  One parameter is varied at a time,
%   everything else stays at cilento_baseline, and every setting reports the
%   minimum fleet, the makespan and the energy at that fleet, the number of
%   charging visits and whether the independent checker accepted the solution.
%
%   Sweep F is also the answer to "how fine should the speed grid be": it puts
%   the accuracy gain and the extra binary variables in the same table.

if nargin < 1 || isempty(tl),  tl  = 300; end
if nargin < 2 || isempty(tag), tag = 'sensitivity_matlab.csv'; end

opts = sdpsettings('solver','gurobi','verbose',0, ...
                   'savesolveroutput',1, ...
                   'gurobi.TimeLimit',tl,'gurobi.MIPGap',1e-4, ...
                   'gurobi.NumericFocus',1);

cases = {};   % {sweep, label, instance}
% A. usable fraction of the nameplate battery -- the least certain input
for g = [0.60 0.70 0.80 0.90 1.00]
    cases(end+1,:) = {'A gamma_use', sprintf('%.2f',g), ...
                      cilento_baseline('gamma_use',g)}; %#ok<AGROW>
end
% B. untouchable reserve: what safety costs
for rr = [0.10 0.20 0.30]
    cases(end+1,:) = {'B rho_res', sprintf('%.2f',rr), ...
                      cilento_baseline('rho_res',rr)}; %#ok<AGROW>
end
% C. hand-over overlap: what continuity of surveillance costs
for o = [300 420 600]
    cases(end+1,:) = {'C O_C1 [s]', sprintf('%d',o), ...
                      cilento_baseline('O_C1',o)}; %#ok<AGROW>
end
% D. wind severity -- directions kept, magnitudes scaled, so the experiment
%    isolates strength from geometry
b0 = cilento_baseline();
for f = [0 0.5 1.0 1.5 2.0]
    om = b0.Omega;  om(:,1) = om(:,1)*f;
    cases(end+1,:) = {'D wind scale', sprintf('x%.1f',f), ...
                      cilento_baseline('Omega',om)}; %#ok<AGROW>
end
% E. number of C1 keeper copies: large enough to close the coverage, small
%    enough not to distort the optimum.  Feasibility is not monotone in R.
for R = 2:5
    cases(end+1,:) = {'E R copies', sprintf('%d',R), ...
                      cilento_baseline('R',R,'K_max',7)}; %#ok<AGROW>
end
% F. speed grid: discretization against model size
Hs = {12, [8 12 15], [8 10 12 14 15], [8 9 10 12 13 14 15]};
for i = 1:numel(Hs)
    cases(end+1,:) = {'F speed levels', ...
                      sprintf('%d: %s', numel(Hs{i}), mat2str(Hs{i})), ...
                      cilento_baseline('H',Hs{i})}; %#ok<AGROW>
end
% G. charging infrastructure -- real facilities, not invented pads
sets = {{}, {'VVF_Agropoli'}, {'VVF_Agropoli','Elis_Pattano'}};
for i = 1:3
    cases(end+1,:) = {'G stations', sprintf('%d',i-1), ...
                      cilento_baseline('charge',sets{i})}; %#ok<AGROW>
end
% H. arc admissibility level (the chance-constraint filter of Section 5.2)
for ea = [0.60 0.80 0.90 1.00]
    cases(end+1,:) = {'H eta_adm', sprintf('%.2f',ea), ...
                      cilento_baseline('eta_adm',ea)}; %#ok<AGROW>
end
% I. emergency reserve
for nr = [0 1 2]
    cases(end+1,:) = {'I N_res', sprintf('%d',nr), ...
                      cilento_baseline('N_res',nr,'K_max',7)}; %#ok<AGROW>
end

fprintf('sector: %s\n', 'north (real Cilento data, see cilento_case.m)');
fprintf('%-16s %-26s %s %3s %9s %9s %7s %4s %8s %8s  %s\n', ...
        'sweep','value','','f1','f2 [min]','f3 [Wh]','dE %','chg','checks', ...
        'time','status');
fprintf('%s\n', repmat('-',1,110));

% The reference for dE is the BASELINE value of each parameter, not the first
% row of the sweep: otherwise "+0.0 %" lands on whichever setting happens to be
% listed first and the column cannot be read.
BASE_AT = containers.Map( ...
  {'A gamma_use','B rho_res','C O_C1 [s]','D wind scale','E R copies', ...
   'F speed levels','G stations','H eta_adm','I N_res'}, ...
  {'0.90','0.20','420','x1.0','3','5: [8 10 12 14 15]','1','0.90','0'});

res = cell(size(cases,1), 1);
for c = 1:size(cases,1)

    % Screen policy is selected automatically inside cilento_solve_case:
    % N_res = 0  -> P1,P2,P3,P6
    % N_res > 0  -> P1,...,P6

    res{c} = cilento_solve_case( ...
        cases{c,3}, opts, true, 0, []);
end
ref = containers.Map('KeyType','char','ValueType','double');
for c = 1:size(cases,1)
    nm = cases{c,1};
    if isKey(BASE_AT, nm) && strcmp(cases{c,2}, BASE_AT(nm)) && isfinite(res{c}.f3)
        ref(nm) = res{c}.f3;
    end
end

rows = {};
for c = 1:size(cases,1)
    name = cases{c,1};  label = cases{c,2};  r = res{c};
    dE = NaN;
    if isfinite(r.f3) && isKey(ref, name) && ref(name) > 0
        dE = 100*(r.f3 - ref(name))/ref(name);
    end
    if isKey(BASE_AT, name) && strcmp(label, BASE_AT(name)), isbase = '<';
    else, isbase = ' '; end
    if isfinite(r.f3) && ~r.proven, mk = '*'; else, mk = ' '; end
    if r.checks > 0
        chk = sprintf('%d/%d', r.checks - r.violations, r.checks);
    else
        chk = '-';
    end
    fprintf('%-16s %-26s %s %3s %9s %9s %7s %4s %8s %7.1fs  %s\n', ...
            name, label, isbase, num(r.f1,'%d'), [num(r.f2,'%.1f') mk], ...
            [num(r.f3,'%.1f') mk], num(dE,'%+.1f'), num(r.charges,'%d'), ...
            chk, r.seconds, r.status);
    if r.violations > 0
        fprintf('    !! the independent checker rejected %d properties\n', ...
                r.violations);
    end
    rows(end+1,:) = {name, label, r.f1, r.f2, r.f3, dE, r.charges, r.bins, ...
                     r.checks, r.violations, double(r.proven), r.seconds, ...
                     r.status}; %#ok<AGROW>
end
fprintf(['\n''<'' marks the baseline row of each sweep; ''*'' marks a value ' ...
         'that is an incumbent,\nnot a proven optimum.\n']);

T = cell2table(rows, 'VariableNames', ...
      {'sweep','value','f1','f2_min','f3_Wh','dE_pct','charges','bins', ...
       'checks','violations','proven','seconds','status'});
writetable(T, tag);
fprintf('\nsaved %s\n', tag);
end

% -------------------------------------------------------------------------
function s = num(v, f)
if isnan(v), s = '-'; else, s = sprintf(f, v); end
end
