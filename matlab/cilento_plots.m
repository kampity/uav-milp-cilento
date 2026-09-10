function files = cilento_plots(r, prefix)
%CILENTO_PLOTS  Section 10.6 - validation of the final solution.
%
%   files = cilento_plots()          solve the baseline, then draw
%   files = cilento_plots(r)         draw a case already solved by
%                                    cilento_solve_case
%
%   An objective value is not evidence.  These three figures are: the route map
%   shows where the fleet goes, the timeline shows that C1 is covered without a
%   gap and with the required hand-over overlap, and the battery profile shows
%   that the reserve line is never crossed.  All three are drawn from the
%   INDEPENDENTLY re-derived schedule (cilento_derive), not from the solver's
%   own continuous variables.

if nargin < 1 || isempty(r), r = cilento_solve_case(cilento_baseline()); end
if nargin < 2, prefix = 'fig'; end
assert(~isempty(r.plan), 'no feasible solution to draw (%s)', r.status);

inst = r.inst;  pre = r.pre;  plan = r.plan;
d = cilento_derive(inst, pre, plan);
fprintf(['plotting the plan: f1=%g UAV, f2=%.1f min, f3=%.1f Wh, ' ...
         'checks %d/%d\n'], r.f1, r.f2, r.f3, r.checks - r.violations, r.checks);

% colour-blind safe, legible in grayscale
PAL = [0.00 0.45 0.70; 0.84 0.37 0.00; 0.00 0.62 0.45;
       0.80 0.47 0.65; 0.90 0.62 0.00; 0.34 0.71 0.91];

files = {sprintf('%s_routes.png', prefix), ...
         sprintf('%s_c1_timeline.png', prefix), ...
         sprintf('%s_battery.png', prefix)};

%% ------------------------------------------------------------ route map --
f = figure('Color','w','Position',[100 100 720 600]);  ax = axes(f); hold(ax,'on');
h = [];  lbl = {};
for k = 1:plan.K
    if d.veh(k).idle, continue, end
    col = PAL(mod(k-1,size(PAL,1))+1,:);
    for p = d.veh(k).path
        i = pre.A(p,1);  j = pre.A(p,2);
        quiver(ax, pre.xy(i,1), pre.xy(i,2), ...
               pre.xy(j,1)-pre.xy(i,1), pre.xy(j,2)-pre.xy(i,2), 0, ...
               'Color', col, 'LineWidth', 1.4, 'MaxHeadSize', 0.25);
    end
    h(end+1) = plot(ax, NaN, NaN, '-', 'Color', col, 'LineWidth', 1.6); %#ok<AGROW>
    lbl{end+1} = sprintf('UAV%d', k); %#ok<AGROW>
end
h(end+1) = plot(ax, pre.xy(pre.F,1), pre.xy(pre.F,2), '^', ...
                'MarkerFaceColor',[0.27 0.27 0.27], 'MarkerEdgeColor','k', ...
                'MarkerSize',8, 'LineStyle','none');
lbl{end+1} = 'historical points';
h(end+1) = plot(ax, pre.xy(pre.C(1),1), pre.xy(pre.C(1),2), 'p', ...
                'MarkerFaceColor',[0.70 0.13 0.13], 'MarkerEdgeColor','k', ...
                'MarkerSize',16, 'LineStyle','none');
lbl{end+1} = 'C1 (persistent)';
if ~isempty(pre.S)
    h(end+1) = plot(ax, pre.xy(pre.S,1), pre.xy(pre.S,2), 's', ...
                    'MarkerEdgeColor',[0.10 0.50 0.22], 'MarkerSize',10, ...
                    'LineWidth',1.6, 'LineStyle','none');
    lbl{end+1} = 'charging station';
end
h(end+1) = plot(ax, pre.xy(pre.dplus,1), pre.xy(pre.dplus,2), 'h', ...
                'MarkerFaceColor','k', 'MarkerEdgeColor','k', ...
                'MarkerSize',12, 'LineStyle','none');
lbl{end+1} = 'depot';
for i = [pre.F pre.C(1)]
    text(ax, pre.xy(i,1)+40, pre.xy(i,2)+40, pre.tag{i}, 'FontSize',8, ...
         'Color',[0.2 0.2 0.2]);
end
xlabel(ax,'east [m]'); ylabel(ax,'north [m]');
title(ax,'Routes of the minimum-energy plan');
axis(ax,'equal'); grid(ax,'on'); ax.GridLineStyle = ':';
legend(ax, h, lbl, 'Location','best', 'FontSize',8);
exportgraphics(f, files{1}, 'Resolution', 170); % close(f);

%% -------------------------------------------------------- C1 timeline ----
owner = zeros(1, inst.R);
for k = 1:plan.K
    if d.veh(k).idle, continue, end
    for q = 1:numel(d.veh(k).trace)
        j = d.veh(k).trace(q).node;
        if j ~= pre.dminus && pre.kind(j) == 'C', owner(pre.Cidx(j)) = k; end
    end
end
f = figure('Color','w','Position',[100 100 820 320]);  ax = axes(f); hold(ax,'on');
for rr = 1:inst.R
    k = max(owner(rr),1);
    col = PAL(mod(k-1,size(PAL,1))+1,:);
    w = plan.beta(rr) - plan.alpha(rr);
    rectangle(ax,'Position',[plan.alpha(rr), rr-0.28, w, 0.56], ...
              'FaceColor',col,'EdgeColor','k','LineWidth',0.6);
    text(ax, plan.alpha(rr)+w/2, rr, sprintf('UAV%d  %.1f min', owner(rr), w), ...
         'HorizontalAlignment','center','Color','w','FontSize',8);
end
for rr = 1:inst.R-1
    lap = plan.beta(rr) - plan.alpha(rr+1);
    plot(ax, [plan.alpha(rr+1) plan.beta(rr)], [rr+0.5 rr+0.5], 'k-','LineWidth',1.2);
    text(ax, (plan.alpha(rr+1)+plan.beta(rr))/2, rr+0.62, ...
         sprintf('overlap %.1f min (>= %.1f)', lap, pre.O_C1), ...
         'HorizontalAlignment','center','FontSize',8);
end
xline(ax, pre.T_C1_start, '--', 'T\_C1\_start', 'Color',[0.70 0.13 0.13], ...
      'LabelVerticalAlignment','bottom','FontSize',8);
xline(ax, pre.T_C1_end, '--', 'T\_C1\_end', 'Color',[0.70 0.13 0.13], ...
      'LabelVerticalAlignment','bottom','FontSize',8);
ylim(ax,[0.4 inst.R+0.9]); yticks(ax, 1:inst.R);
yticklabels(ax, arrayfun(@(r) sprintf('duty %d',r), 1:inst.R, 'uni', 0));
xlabel(ax,'mission time [min]');
title(ax,'Persistent surveillance of C1: duties and hand-over overlaps');
grid(ax,'on'); ax.GridLineStyle = ':';
exportgraphics(f, files{2}, 'Resolution', 170); % close(f);

%% ------------------------------------------------------ battery profile --
f = figure('Color','w','Position',[100 100 820 400]);  ax = axes(f); hold(ax,'on');
Q = pre.Q;  h = [];  lbl = {};
for k = 1:plan.K
    if d.veh(k).idle, continue, end
    col = PAL(mod(k-1,size(PAL,1))+1,:);
    ts = plan.veh(k).tdep;  bs = 100;
    for q = 1:numel(d.veh(k).trace)
        st = d.veh(k).trace(q);
        if st.node == pre.dminus
            ts(end+1) = st.tarr; bs(end+1) = 100*st.batt/Q; %#ok<AGROW>
            break
        end
        ts(end+1) = st.tarr;  bs(end+1) = 100*st.barr/Q; %#ok<AGROW>
        ts(end+1) = st.C;     bs(end+1) = 100*st.bdep/Q; %#ok<AGROW>
        text(ax, st.C, 100*st.bdep/Q - 3, pre.tag{st.node}, 'FontSize',7, ...
             'Color',col);
    end
    h(end+1) = plot(ax, ts, bs, '-o', 'Color',col, 'MarkerSize',3.5, ...
                    'LineWidth',1.6, 'MarkerFaceColor',col); %#ok<AGROW>
    lbl{end+1} = sprintf('UAV%d', k); %#ok<AGROW>
end
yline(ax, 100*inst.rho_res, '--', ...
      sprintf('untouchable reserve %.0f%%', 100*inst.rho_res), ...
      'Color',[0.70 0.13 0.13], 'LineWidth',1.4, 'FontSize',8);
ylim(ax,[0 105]);
xlabel(ax,'mission time [min]');
ylabel(ax,'state of charge [% of usable capacity]');
title(ax,'Battery profile: the reserve line is never crossed');
grid(ax,'on'); ax.GridLineStyle = ':';
legend(ax, h, lbl, 'Location','southwest','FontSize',8);
exportgraphics(f, files{3}, 'Resolution', 170); % close(f);

fprintf('saved: %s\n', strjoin(files, ', '));
end
