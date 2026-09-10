function plan = cilento_extract(inst, pre, M)
%CILENTO_EXTRACT  Snapshot of a solved model: discrete decisions + reported values.
%
%   plan = cilento_extract(inst, pre, M)   must be called straight after
%   optimize(), while the YALMIP values are still those of this solution.
%
%   Everything downstream (cilento_derive, cilento_verify, cilento_replay)
%   works on this snapshot, never on the sdpvar objects, so a plan can be
%   replayed against a different coefficient set.

A = pre.A;  nA = size(A,1);  nH = pre.nH;  n = pre.n;
plan.K = M.K;  plan.Nres = M.Nres;
plan.alpha = zeros(1,inst.R);  plan.beta = zeros(1,inst.R);
for r = 1:inst.R
    plan.alpha(r) = value(M.alpha(r));
    plan.beta(r)  = value(M.beta(r));
end
plan.f1 = value(M.f1);  plan.f2 = value(M.f2);  plan.f3 = value(M.f3);

X = value(M.x);  Rr = value(M.r);
% plan.veh is grown by assignment: every element gets exactly the same fields
% in the same order, so no pre-declaration is needed (and a pre-declaration
% whose field order differed would make the assignment fail).
for k = 1:M.K
    v.u = value(M.u(k)) > 0.5;
    v.e = value(M.e(k)) > 0.5;
    v.s = value(M.s(k)) > 0.5;
    v.arcs  = find(X(:,k) > 0.5).';           % row indices into pre.A
    Z = value(M.z{k});
    v.speed = zeros(1,nA);                    % 0 = no speed selected
    v.nspeed = zeros(1,nA);
    for ia = v.arcs
        hh = find(Z(ia,:) > 0.5);
        v.nspeed(ia) = numel(hh);
        if numel(hh) >= 1, v.speed(ia) = hh(1); end
    end
    v.served = find(Rr(:,k).' > 0.5);
    v.tdep = value(M.tdep(k));  v.tret = value(M.tret(k));
    v.W = zeros(1,n); v.tarr = zeros(1,n); v.t = zeros(1,n);
    v.C = zeros(1,n); v.barr = zeros(1,n); v.bdep = zeros(1,n);
    v.delta = zeros(1,n); v.gch = zeros(1,n);
    for i = pre.No
        v.W(i) = value(M.W(i,k));    v.tarr(i) = value(M.tarr(i,k));
        v.t(i) = value(M.t(i,k));    v.C(i)    = value(M.C(i,k));
        v.barr(i) = value(M.barr(i,k)); v.bdep(i) = value(M.bdep(i,k));
    end
    for i = pre.S
        v.delta(i) = value(M.delta(i,k));  v.gch(i) = value(M.gch(i,k));
    end
    plan.veh(k) = v;
end
end
