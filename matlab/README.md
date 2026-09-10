# MATLAB / YALMIP / Gurobi implementation

25 modules, ~3,800 lines. Requires YALMIP on the path and Gurobi with a valid license.
All `.m` files live in one folder, which must also be the current folder.

```matlab
addpath(genpath('...\YALMIP'))
gurobi_setup                  % once, after installing Gurobi
cd  ...\uav-milp-cilento\matlab
savepath
```

CSV outputs are written next to the scripts; the copies committed to this repository
live in `../results/`.

## Run order — cheapest checks first

Each step is meaningful only if the previous one passed.

```matlab
cilento_crosscheck(0)   % ~5 s, no solver: environment + 13 preprocessing
                        % quantities against the Python/HiGHS reference
cilento_crosscheck(1)   % 2-5 min: main instance + payoff table
cilento_crosscheck(2)   % 15-30 min: depot selection + emergency reserve
cilento_pretests        % preprocessing unit tests against hand-computed values
cilento_tests           % 12 debug tests + independent checker
cilento_depots          % depot selection among real candidate sites
cilento_ablation        % model-variant comparison
cilento_sensitivity     % 9 parameter sweeps (33 runs)
cilento_scalability     % scalability limit — run last, ideally overnight
run_cilento             % full run + route map, C1 Gantt chart, battery profile
```

`cilento_crosscheck(0)` needs no solver and reports within seconds whether
preprocessing is correct. If it fails, the problem is in the installation or in
preprocessing and the MILP has not yet been reached — the easiest case to fix.

`cilento_sensitivity` is 33 runs and `cilento_scalability` hits the time limit on
several points; both belong at the end.

## Modules

| File | Role |
|---|---|
| `cilento_case.m` | Real case data: fire sites, depot candidates, wind rose — each value with its source |
| `cilento_baseline.m` | Instance assembly (sector, depot, charging stations) |
| `cilento_pre.m` | Preprocessing: calibration, wind coefficients, feasibility screens P1–P6 |
| `cilento_prepare.m` | Preprocessing plus the shift-endurance cap from the battery screen |
| `cilento_milp.m` | Decision variables, the seven constraint blocks, the three objectives |
| `cilento_solve_case.m` | Exact fleet-size search, then energy minimisation at that fleet size |
| `cilento_extract.m` | Solution snapshot: discrete decisions and reported values |
| `cilento_derive.m` | **Independent** schedule re-derivation from the routes alone |
| `cilento_verify.m` | Checks the re-derived schedule against the physics |
| `cilento_replay.m` | Replays a plan under a different wind realisation |
| `cilento_status.m` | Honest reading of the YALMIP/Gurobi exit code |
| `cilento_diagnose.m` | Disables constraint blocks one by one to localise infeasibility |
| `cilento_crosscheck.m` | Three-level comparison against the Python/HiGHS reference |
| `cilento_pretests.m` | Preprocessing unit tests |
| `cilento_tests.m` | The 12 debug tests |
| `cilento_scalability.m` | Scalability experiment |
| `cilento_sensitivity.m` | Parameter sweeps |
| `cilento_ablation.m` | Model-variant comparison |
| `cilento_depots.m` | Depot selection |
| `cilento_velia_scenarios.m` | Infeasible-sector diagnosis and design scenarios |
| `cilento_velia_v4.m` | The design configuration that restores feasibility |
| `cilento_f8_diagnostic.m` | Diagnostic run for the numerically unstable \|F\| = 8 instance |
| `cilento_plots.m` | Route map, C1 duty Gantt chart, battery profile |
| `scal_figures_final.m` | Scalability figures |
| `run_cilento.m` | Driver: fleet search → objectives → verification → figures |

## First-run sanity checks

1. **Calibration.** `P_0 ≈ 67.9 W`, `P_i ≈ 93.5 W`, `d0·sr ≈ 0.0831`, residuals
   `~1e-10`. The residuals are this small because with `U_tip` and `v_0` fixed the
   system is linear in `(P_0, P_i, d_0 s_r)` — an exact 3×3 solution, not a fit.
   Residuals of order unity mean `U_tip` or `v_0` are set incorrectly.
2. **Model size.** Baseline instance: ~2,100 variables, ~1,800 binaries.
3. **Tests.** 12 PASS, zero checker violations. Tests 01 and 06 *must* return
   `infeasible` — that is the check that the model can refuse, not only solve.

If something reports `infeasible` where it should not:
`cilento_diagnose(cilento_baseline(), 4, 0)` disables constraint blocks one at a time
and shows which block cuts the solution.

## Four implementation facts that matter

**1. Scaling.** The formulation is written in seconds and joules but solved in
**minutes and watt-hours**. Without this the coefficients span six orders of magnitude
and the solver becomes numerically unreliable. Scaling is applied once, in
`cilento_pre`; the formulation itself is unchanged. `NumericFocus = 1` prioritises
stability over speed.

**2. Two-sided Big-M requires two rows, not one.** The condition
`-M(1-y) <= expr <= M(1-y)` cannot be written as a single two-sided constraint,
because `y` carries opposite signs in the two halves. Correct form:

```
expr + M*y <=  M
expr - M*y >= -M
```

Written as one row, `y = 1` yields `expr <= 0` instead of `expr = 0`, and the model
silently cuts off feasible solutions. See `bigM_eq` in `cilento_milp.m`.

**3. Wind direction is meteorological.** `Omega(:,2)` is the bearing the wind comes
*from*, clockwise from north. In an (x = east, y = north) frame a bearing `b` gives
the vector `[sin(b) cos(b)]`, **not** `[cos(b) sin(b)]`. The second form measures
counter-clockwise from east and silently reverses every scenario. This was one of the
six defects the verification scheme found, and it was invisible on arbitrarily chosen
directions.

**4. `problem == 3` is a time limit, not a solution.** Gurobi can hit `TimeLimit` with
an empty solution pool. `cilento_status.m` distinguishes `optimal`,
`time-limit (incumbent)` and `time-limit (no incumbent)` via `result.solcount`. Values
without proven optimality are marked `*` in all tables. Reading the status naively
would have recorded the numerically failed \|F\| = 8 instance as infeasible, which it
is not: a separate diagnostic run found a feasible incumbent at 546.62 Wh against a
lower bound of 479.53 Wh.

## MATLAB-specific pitfalls already handled

Do not undo these when editing.

- `z` is a **cell array**, not a 3-D `binvar`: YALMIP does not support 3-D binaries.
  Access as `z{k}(ia,h)`.
- Constraints accumulate in a cell and are concatenated once (`Con = [C{:}]`). Growing
  `Con = [Con, ...]` inside a loop gives quadratic assembly time.
- `struct(...)` with cell values creates a struct array, not a struct with a cell
  field. `M` is therefore built one field at a time.
- Row vs column in a logical `&`: in `cilento_derive/local_walk` both operands are
  forced to row form. Mixing a column and a row yields a matrix and silently selects
  the wrong arc.
- `NaN*0 = NaN` — presence flags are handled with `if`, never by multiplying by a flag.
- YALMIP expressions do not carry across rebuilt models: each rebuild creates new
  `sdpvar`. The payoff table therefore uses one model per row, with constraints added
  sequentially.

## Comparing against the reference

`../results/python-reference/` holds the CSV outputs of the independent Python/HiGHS
run. Compare the columns `f1`, `f2_min`, `f3_Wh`, `checks`, `violations` and the screen
statuses.

A disagreement in these numbers means an error in one of the two implementations;
`cilento_diagnose` then localises the constraint block responsible. A disagreement in
routes or solve times is expected and is not an error.

## Troubleshooting

| Symptom | Action |
|---|---|
| `Undefined function 'sdpsettings'` | YALMIP is not on the path |
| Gurobi not reachable from YALMIP | `gurobi_setup` not run, or the license is not visible |
| `infeasible` where a plan was expected | `cilento_diagnose(cilento_baseline(), 4, 0)` |
| Preprocessing coefficients disagree | Error upstream of the MILP; check with `cilento_pretests` |
| Everything agrees except solve time | Expected — report it as a result |

## Environment

MATLAB R2026a Update 4, win64, 12 cores | YALMIP 20250626 | Gurobi 13.0.3
`TimeLimit = 300 s` (600 and 3600 s in the scalability experiment) ·
`MIPGap = 1e-4` · `NumericFocus = 1` · synthetic instance seed `20260815`
