function [inst, pre] = cilento_prepare(inst)
%CILENTO_PREPARE  Preprocessing plus the Section 4.5 cap on tau_C1_max.
%
%   The C1 residence time may not exceed what the battery admits.  Without the
%   cap an instance can be specified that is physically impossible, and the
%   resulting "infeasible" is blamed on the model instead of on the data.

pre = cilento_pre(inst);
tb = pre.screens.tau_bat;
if isfinite(tb) && tb < inst.tau_C1_max
    inst.tau_C1_max = max(inst.O_C1, floor(tb));
    pre = cilento_pre(inst);
end
end
