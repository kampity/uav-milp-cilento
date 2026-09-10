# Python / HiGHS reference implementation

The model was implemented a second time, independently, in Python with the HiGHS
solver. That implementation was used for development and debugging, and its outputs
serve as the reference against which the MATLAB/YALMIP/Gurobi results are checked.

The reference outputs are committed in [`../results/python-reference/`](../results/python-reference/)
and are compared column by column by `matlab/cilento_crosscheck.m`.

The source of this implementation is not yet included in the repository.
