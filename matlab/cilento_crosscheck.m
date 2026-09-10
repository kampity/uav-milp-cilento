function R = cilento_crosscheck(level)
%CILENTO_CROSSCHECK  Сверка реализации MATLAB/YALMIP/Gurobi с эталоном Python/HiGHS.
%
%   cilento_crosscheck(0)   препроцессинг, без солвера   ~5 секунд
%   cilento_crosscheck(1)   + основной инстанс           ~2-5 минут
%   cilento_crosscheck(2)   + выбор базы и резерв        ~15-30 минут
%
%   Печатает построчно PASS/FAIL и пишет crosscheck_matlab.csv.
%
%   ЧТО СРАВНИВАЕТСЯ.  Значения целевых функций, коэффициенты препроцессинга и
%   статусы экранов - величины, которые обязаны совпасть у двух корректных
%   реализаций.  Маршруты НЕ сравниваются: при альтернативных оптимумах Gurobi
%   и HiGHS законно возвращают разные планы с одинаковыми f1, f2, f3.  Если
%   расходятся именно маршруты, а числа совпадают - это не ошибка.
%
%   Эталон получен на Python + HiGHS; источник каждого числа указан в столбце
%   "откуда" итогового CSV.

if nargin < 1, level = 1; end
R = struct('name',{},'got',{},'want',{},'tol',{},'unit',{},'ok',{},'src',{});

fprintf('\n=== 0. Окружение ===\n');
try
    fprintf('  YALMIP  : %s\n', yalmip('version'));
catch
    error('YALMIP не на path. addpath(genpath(''...\\YALMIP''))');
end
try
    o = sdpsettings('solver','gurobi','verbose',0);
    x = sdpvar(1,1); b = binvar(1,1);
    d = optimize([x >= 2*b, b == 1, x <= 10], x, o);
    if d.problem ~= 0
        error('Gurobi вернул код %d на тривиальной задаче: %s', ...
              d.problem, d.info);
    end
    fprintf('  Gurobi  : отвечает, тривиальный MILP решён (x = %.0f)\n', value(x));
catch ME
    error('Gurobi недоступен из YALMIP: %s', ME.message);
end

% ------------------------------------------------------------------ 1. --
fprintf('\n=== 1. Калибровка винтокрылой модели (§5.3.1) ===\n');
inst = cilento_baseline();
[inst, pre] = cilento_prepare(inst);

R = add(R,'P_0 (профильная)',        pre.P0_0, 67.9,  0.5, 'W','§5.3.1');
R = add(R,'P_i (индуктивная)',       pre.Pi_0, 93.5,  0.5, 'W','§5.3.1');
R = add(R,'d_0*s_r (паразитная)',    pre.k_0,  0.0831,0.002,'-','§5.3.1');
R = add(R,'P_obs на висении',        pre.P_obs,191.4, 1.0, 'W','паспорт 4TD');

% ------------------------------------------------------------------ 2. --
fprintf('\n=== 2. Экраны выполнимости, северный сектор (§10.1.6) ===\n');
sc = pre.screens;
R = add(R,'tau_bat север',      sc.tau_bat,        1446.47, 1.0,  's','§10.12');
R = add(R,'tau_eff север',      sc.tau_eff,        1446.00, 1.0,  's','§10.12');
R = add(R,'R_LB север',         sc.R_LB,           3,       0,    '-','§10.1.6');
R = add(R,'полёт до C1',        sc.P1_min_travel,  219.50,  1.0,  's','§10.10');
R = add(R,'запас P6 север', ...
        sc.P6_min_slack_Wh,18.803,0.05,'Wh','§10.1.6');
R = add(R,'экранов пройдено',   sum([sc.P1_ok sc.P2_ok sc.P3_ok ...
                                     sc.P4_ok sc.P5_ok sc.P6_ok]), 6, 0, '-','§10.1.6');

fprintf('\n=== 3. Экраны, центральный сектор Велия (§10.12) ===\n');
instV = cilento_baseline('sector','centre');
[instV, preV] = cilento_prepare(instV);  %#ok<ASGLU>
scV = preV.screens;
R = add(R,'tau_bat Велия', ...
        scV.tau_bat,-65.501,0.10,'s','§10.12');

R = add(R,'запас P6 Велия', ...
        scV.P6_min_slack_Wh,-35.222,0.05,'Wh','§10.12');
R = add(R,'экранов пройдено',   sum([scV.P1_ok scV.P2_ok scV.P3_ok ...
                                     scV.P4_ok scV.P5_ok scV.P6_ok]), 0, 0, '-','§10.12');
R = add(R,'R_LB Велия бесконечен', double(isinf(scV.R_LB)), 1, 0, '-','§10.12');

fprintf('\n=== 4. Модульные проверки препроцессинга (§10.5) ===\n');
try
    ok20 = cilento_pretests();
    R = add(R,'17 pretests пройдены', double(ok20), 1, 0, '-','§10.5');
catch ME
    fprintf('  cilento_pretests упал: %s\n', ME.message);
    R = add(R,'pretests запустились', 0, 1, 0, '-','§10.5');
end

if level < 1, R = finish(R); return, end

% ------------------------------------------------------------------ 5. --
fprintf('\n=== 5. Основной инстанс: северный сектор (§10.9, §10.11) ===\n');
opts = sdpsettings('solver','gurobi','verbose',0, ...
                   'savesolveroutput',1, ...
                   'gurobi.TimeLimit',300, ...
                   'gurobi.MIPGap',1e-4, ...
                   'gurobi.NumericFocus',1);
r = cilento_solve_case( ...
        cilento_baseline(), ...
        opts, ...
        true, ...
        0, ...
        []);
fprintf('  статус: %s, %.1f c\n', r.status, r.seconds);
R = add(R,'f1 флот',        r.f1, 4,       0,    'UAV','§10.9');
R = add(R,'f2 makespan',    r.f2, 63.361,  0.05, 'min','§10.9');
R = add(R,'f3 энергия',     r.f3, 426.933, 0.60, 'Wh','§10.9');
R = add(R,'проверок',       r.checks,     125,   0,   '-','§10.4');
R = add(R,'нарушений',      r.violations, 0,     0,   '-','§10.4');
R = add(R,'зарядок в плане',r.charges,    1,     0,   '-','§10.7');
R = add(R,'доказанный оптимум', double(r.proven), 1, 0, '-','§10.9');

fprintf('\n=== 6. Payoff table и утопия/надир (§8.2, §10.9) ===\n');
% Три строки строгого последовательного лексикографического прохода.
% На этом инстансе цели не конфликтуют, поэтому все три строки обязаны
% совпасть, а диапазоны нормировки - обратиться в нуль.
P = nan(3,3);
for j = 1:3
    order = [j, setdiff(1:3, j)];
    fx = struct('i',{},'v',{});
    for pos = 1:3
        M = cilento_milp(inst, pre, round(r.f1), inst.N_res, opts);
        objs = {M.f1, M.f2, M.f3};
        C = M.Con;
        for q = 1:numel(fx), C = [C, objs{fx(q).i} <= fx(q).v]; end %#ok<AGROW>
        d = optimize(C, objs{order(pos)}, opts);
        [~, inc] = cilento_status(d, objs{order(pos)});
        if ~inc, error('payoff строка %d шаг %d не решена', j, pos); end
        v = value(objs{order(pos)});
        fx(end+1) = struct('i', order(pos), 'v', v + 1e-6 + 1e-7*abs(v)); %#ok<AGROW>
        if pos == 3
            for m = 1:3, P(j,m) = value(objs{m}); end
        end
    end
    fprintf('  lex(f%d,f%d,f%d): f1=%.0f  f2=%.1f мин  f3=%.1f Вт·ч\n', ...
            order(1), order(2), order(3), P(j,1), P(j,2), P(j,3));
end
zs = [P(1,1) P(2,2) P(3,3)];
zn = max(P, [], 1);
R = add(R,'диапазон надир-утопия f1', zn(1)-zs(1), 0, 1e-6, 'UAV','§10.9');
R = add(R,'диапазон надир-утопия f2', zn(2)-zs(2), 0, 1e-3, 'min','§10.9');
R = add(R,'диапазон надир-утопия f3', zn(3)-zs(3), 0, 1e-2, 'Wh','§10.9');

if level < 2, R = finish(R); return, end

% ------------------------------------------------------------------ 7. --
fprintf('\n=== 7. Выбор базы (§10.10) ===\n');
names = {'Centola_AIB','VVF_Vallo','VVF_Agropoli','Elis_Pattano', ...
         'CM_Futani','CM_Laureana'};
want  = [0 0 0 0 0 1];                 % проходит ли все шесть экранов
for q = 1:numel(names)
    iq = cilento_baseline('base', names{q});
    [~, pq] = cilento_prepare(iq);
    s = pq.screens;
    all6 = all([s.P1_ok s.P2_ok s.P3_ok s.P4_ok s.P5_ok s.P6_ok]);
    R = add(R, ['база ' names{q}], double(all6), want(q), 0, '-','§10.10');
end

fprintf('\n=== 8. Аварийный резерв (§10.8.2) ===\n');
for n = 0:2
    rr = cilento_solve_case( ...
        cilento_baseline('N_res',n,'K_max',7), ...
        opts, ...
        false, ...
        0, ...
        []);
    R = add(R, sprintf('N_res=%d -> f1', n), rr.f1, 4+n,   0,    'UAV','§10.8.2');
    R = add(R, sprintf('N_res=%d -> f3', n), rr.f3, 426.933, 0.60,'Wh','§10.8.2');
end

R = finish(R);
end

% ======================================================================= %
function R = add(R, name, got, want, tol, unit, src)
if isempty(got), got = NaN; end
got = double(got);
ok = (isnan(got) == isnan(want)) && (isnan(got) || abs(got - want) <= tol);
if isinf(want), ok = isinf(got) && sign(got) == sign(want); end
R(end+1) = struct('name',name,'got',got,'want',want,'tol',tol, ...
                  'unit',unit,'ok',ok,'src',src); %#ok<AGROW>
if ok, mark = 'PASS'; else, mark = '<< FAIL'; end
fprintf('  %-28s %12.3f  (эталон %.3f %s)  %s\n', name, got, want, unit, mark);
end

function R = finish(R)
n = numel(R); nf = sum(~[R.ok]);
fprintf('\n=======================================================\n');
fprintf('  сверок: %d, расхождений: %d\n', n, nf);
if nf == 0
    fprintf('  Gurobi воспроизводит эталон HiGHS полностью.\n');
else
    fprintf('  Расходятся:\n');
    for q = 1:n
        if ~R(q).ok
            fprintf('    %-28s получено %.4f, ожидалось %.4f %s (%s)\n', ...
                    R(q).name, R(q).got, R(q).want, R(q).unit, R(q).src);
        end
    end
end
f = fopen('crosscheck_matlab.csv','w');
fprintf(f, 'check,got,expected,tol,unit,pass,source\n');
for q = 1:n
    fprintf(f, '"%s",%.6f,%.6f,%.6f,%s,%d,%s\n', R(q).name, R(q).got, ...
            R(q).want, R(q).tol, R(q).unit, R(q).ok, R(q).src);
end
fclose(f);
fprintf('  записано crosscheck_matlab.csv\n');
fprintf('=======================================================\n\n');
end
