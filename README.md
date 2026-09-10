# Wind-Dependent Multi-UAV Routing with Continuous Surveillance

**A spatial MILP routing and scheduling model — Cilento National Park case study**

M.Sc. thesis, University of Genoa, 2026
Author: Aliya Nurbolatkyzy
Supervisors: Prof. Michela Robba, Prof. Giulio Ferro

---

## Problem

A UAV fleet must observe a set of recorded historical wildfire sites while keeping
one critical site under **uninterrupted** surveillance for a fixed window. No single
aircraft has the endurance to cover that window, so continuity requires a sequence of
overlapping duty shifts flown by distinct aircraft. Flights take place in a real wind
field, onboard energy is finite, and energy can be recovered only at fixed ground
stations — not at the base.

The distinction that drives the formulation: continuity of observation is a **hard
constraint**, not an objective. Consequently the problem can be infeasible, and
establishing *why* it is infeasible is part of the answer rather than a failure.

## Model

A single MILP formulation jointly determines:

- fleet size, routing and visit assignment
- discrete airspeed selection with wind-dependent precomputed coefficients
- scheduling, ground waiting and shift handover with guaranteed overlap
- energy balance with recharging, station capacity and a protected reserve

7 constraint blocks · 90 numbered relations · 5 separately derived Big-M constants,
2 of them tight.

**Uncertainty handling.** Direction-dependent wind scenarios with
criticality-differentiated conservatism: expected values on routine transfers,
worst-case values on safety-critical arrivals and battery-feasibility constraints.

**Objectives.** Normalised sequential lexicographic optimisation over
fleet size → mission completion time → expected energy consumption.

## Key results

| | |
|---|---|
| Northern Cilento instance | 4 UAVs, proven optimal |
| Mission completion time | 63.361 min |
| Expected energy consumption | 426.933 Wh |
| Recharging visits in plan | 1 |
| Infeasibility of 1–3 UAVs | formally proven |
| Proven optimality up to | 6 sites / 13 nodes / 4 UAVs in 22.7 s |
| Scalability tested to | 20 sites (valid lower bounds) |
| Independent solution checks | 4,933 — zero violations |

Of the four aircraft, three are occupied by the single persistent-observation site and
one serves the remaining historical sites. That ratio is what makes the problem
non-trivial: servicing three ordinary sites needs one aircraft, while covering one
critical site continuously for 45 minutes needs three.

### Why wind-aware planning is necessary, not decorative

Each plan replayed against the full scenario set:

| Planning scheme | Landing margin vs protected reserve |
|---|---|
| Wind-agnostic | −16.8 Wh — infeasible |
| Expected-value | −2.8 Wh — infeasible |
| Criticality-differentiated | +0.025 Wh — feasible |

Uniform worst-case treatment of all arcs would cost ~36% additional schedule time.
The differentiation is therefore a necessary condition, not a refinement.

### Structural finding

Feasibility is governed neither by fleet size nor by territory extent, but by the
distance from the persistent-observation site to the nearest energy-recovery point.
Across three sectors of comparable extent (16.68 / 16.19 / 13.69 km), a 15% increase
in that distance (8.46 → 9.75 km) inverts limiting shift endurance from +1,446 s to
−65.5 s. The cause is structural: that quantity is the difference of two comparable
terms, and is therefore small relative to each of them.

### Two speed optima are not the same point

The interior minimum of the power curve and the minimum of energy per unit distance
are separated by 7.2 m/s for the calibrated aircraft. Flying near minimum power is
the wrong policy when the objective is energy per distance rather than hover time.

## Feasibility screens (P1–P6)

Six analytical conditions separate infrastructure- and endurance-driven infeasibility
from scheduling-driven infeasibility **before** the optimisation model is built,
returning a numerical deficit rather than a binary verdict. All six concern the
capability of a *single* aircraft and therefore cannot be repaired by enlarging the
fleet.

Screening rejected 5 of 6 candidate depot sites in under 0.02 s each, where proving
the corresponding MILPs infeasible would have taken minutes to hours.

## Infrastructure design, not only planning

For a sector proven infeasible at any fleet size, the screens localised the structural
cause (limiting shift endurance −65.5 s, implying an unbounded lower bound on required
duty copies), analytically delimited the admissible region for a new energy-recovery
point (3.00 km), and identified the minimum design intervention restoring feasibility:
a forward base, a recovery point, and a 2% increase in modelled energy budget. The
resulting configuration was then solved to proven optimality with three aircraft.

## Verification

The model was implemented **twice and independently** — in MATLAB/YALMIP with Gurobi
(this repository, `matlab/`) and in Python with HiGHS (reference run). Reference
outputs are archived in `results/python-reference/` and compared column by column
against the MATLAB results by `matlab/cilento_crosscheck.m`.

**Must agree** across implementations: objective values, preprocessing coefficients,
screen statuses, checker counts, violation counts.
**Need not agree**: routes and solve times — with alternative optima, two correct
solvers legitimately return different plans with identical f₁, f₂, f₃.

Four verification levels: debug tests on minimal instances · independent schedule
re-derivation reusing no constraint row · unit tests on preprocessing against hand
computation · cross-implementation comparison.

| Set | runs | checks | violations |
|---|---|---|---|
| Preprocessing unit tests | — | 17 | 0 |
| Debug tests (MATLAB/Gurobi) | 12 | 898 | 0 |
| Debug tests (Python/HiGHS) | 12 | 854 | 0 |
| Sensitivity sweep | 30 | 4,018 | 0 |
| **Total** | | **4,933** | **0** |

The scheme surfaced six implementation defects, **three of which produced no solver
error, no infeasibility and no visible output anomaly** — including a wind-direction
convention error (mathematical instead of meteorological bearing) and a unit mismatch
that made screen P1 pass unconditionally. The list of defects actually found is
reported in the thesis rather than omitted: a verification scheme about which only
"it passed" is reported cannot be assessed.

## A note on units and conditioning

The formulation is written in seconds and joules; the implementation solves in
**minutes and watt-hours**. This is numerical conditioning, not convenience: the ratio
of largest to smallest coefficient drops from ~2.3·10⁷ to ~6.1·10³. Scaling is applied
in exactly one place — the preprocessing module — and all downstream code works in
scaled units. `NumericFocus = 1` prioritises numerical stability over speed.

## Repository layout

```
matlab/                 MATLAB/YALMIP/Gurobi implementation — 25 modules, ~3,800 lines
  README.md             module map, run order, first-run sanity checks
analysis/               Python scripts regenerating every figure and table number
results/                CSV outputs of all experiments
  python-reference/     reference outputs from the independent Python/HiGHS run
  scalability_env.txt   exact environment of the scalability run
figures/                figures used in the thesis
python_ref/             (reserved for the Python/HiGHS source)
```

## Reproducibility

MATLAB R2026a Update 4 · YALMIP 20250626 · Gurobi 13.0.3 · Windows 64-bit, 12 cores.
Reference implementation: Python + HiGHS.

Solver settings: `TimeLimit = 300 s` (600 and 3600 s in the scalability experiment) ·
`MIPGap = 1e-4` · `NumericFocus = 1` · synthetic instance seed `20260815`.

For the MATLAB run order see [`matlab/README.md`](matlab/README.md).

Figure and table regeneration (requires `numpy` and `matplotlib`, run from the
repository root):

```
python3 analysis/calib.py            # calibration; writes results/calib.npy
python3 analysis/wind_analysis.py    # wind kinematics figures
python3 analysis/mk_fig45.py         # speed triangle, fixed-speed cost
python3 analysis/mk_blocks.py        # constraint-block dependency figure
python3 analysis/modelsize.py        # model-size verification
python3 analysis/mk_ch6figs.py       # pipeline and cross-check figures
python3 analysis/mk_ch7figs.py       # verification-level figures
python3 analysis/mk_ch8figs.py       # scalability and sensitivity figures
python3 analysis/mk_ch9fig.py        # sensitivity synthesis (tornado)
python3 analysis/mk_map.py           # study-area schematic
python3 analysis/mk_wind.py          # wind scenarios
```

`calib.py` must run first — the remaining scripts read `results/calib.npy`. Each
script prints to console exactly the numbers that appear in the thesis tables, so a
chapter can be recomputed after any input change. `modelsize.py` reports 10 of 10
exact matches between the a-priori model-size estimate and the measured
binary-variable counts.

## Known open item

Configuration V4 was solved twice with differing completion time and energy
(85.949 min / 474.356 Wh vs 94.234 min / 508.516 Wh), while screens, model size and
fleet size agreed. A single control re-run is pending. Reported rather than omitted.

Coordinates are geocoded at settlement level, i.e. accurate to a few hundred metres,
while the P6 deficit in one scenario is 1.97 Wh and the final margin of configuration
V4 is +0.179 Wh. Both are comparable to input uncertainty, so the conclusion that a
2% energy-budget increase is required should be read as an order of magnitude.

## Scope of contribution

This work does not propose a new MILP algorithm, nor a heuristic for large instances;
solving is done by a general-purpose commercial solver. The contribution lies in the
formulation, in the analytical feasibility screens, in the criticality-differentiated
treatment of uncertainty, and in a reproducible implementation-verification protocol.

## License

Code released under the MIT License (see `LICENSE`). Case-study data are cited to
their official sources in `matlab/cilento_case.m`.
