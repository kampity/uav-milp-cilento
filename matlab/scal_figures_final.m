function scal_figures_final(T)

%% 1. Runtime
f1 = figure('Color','w','Position',[100 100 560 400]);
plot(T.nF,T.time_s,'-o','LineWidth',1.5,'MarkerSize',6);
xlabel('Number of historical points |F|');
ylabel('Runtime [s]');
title('Computational time vs instance size');
grid on;
set(gca,'YScale','log');
exportgraphics(f1,'fig_scal_final_time.png','Resolution',200);
close(f1);

%% 2. MIP gap
f2 = figure('Color','w','Position',[100 100 560 400]);

gap_pct = 100*T.gap;

plot(T.nF,gap_pct,'-o','LineWidth',1.5,'MarkerSize',6);
xlabel('Number of historical points |F|');
ylabel('MIP gap [%]');
title('Optimality gap vs instance size');
grid on;

exportgraphics(f2,'fig_scal_final_gap.png','Resolution',200);
close(f2);

%% 3. Number of binary variables
f3 = figure('Color','w','Position',[100 100 560 400]);

plot(T.nF,T.bins,'-o','LineWidth',1.5,'MarkerSize',6);
xlabel('Number of historical points |F|');
ylabel('Binary variables');
title('MILP size vs instance size');
grid on;

exportgraphics(f3,'fig_scal_final_bins.png','Resolution',200);
close(f3);

fprintf('\nSaved final scalability figures:\n');
fprintf('  fig_scal_final_time.png\n');
fprintf('  fig_scal_final_gap.png\n');
fprintf('  fig_scal_final_bins.png\n');

end