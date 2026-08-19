# dihedral_lib.g — helpers for 4+1D FSPT computations with G_b = D_n.
#
# Conventions:
#   D_n = DihedralGroup(2n) in GAP = symmetries of the n-gon, order 2n,
#         <r, s | r^n = s^2 = 1, s r s = r^{-1}>.
#   Elements are enumerated as r^i s^eps, i in [0..n-1], eps in {0,1}.
#
# Contents:
#   DihedralData(n)        -> record(G, r, s, elts, exp) with exp: element -> [i, eps]
#   AlphaBeta(DD)         -> degree-1 classes [alpha, beta] as functions G -> {0,1}
#                             alpha(r^i s^eps) = i mod 2   (only a cocycle for even n)
#                             beta(r^i s^eps)  = eps
#   ProductCocycle(f1, f2) -> (g,h) -> f1(g)*f2(h) mod 2  (automatic 2-cocycle)
#   DicyclicCocycle(n)     -> omega2 for the extension 1->Z2^f->Dic_n->D_n->1,
#                             built as the factor set of Dic_n (automatic cocycle)
#   CheckCocycle(G, w)     -> verifies dw = 0 mod 2 on all triples
#   S1FromAlphaBeta(f)     -> auMap sending g -> [[(-1)^f(g)]]  (anti-unitary grading)

DihedralData := function(n)
  local G, perms, r, s, elts, exp, i, eps, g;
  G := DihedralGroup(2*n);
  # identify the rotation r (order n) and a reflection s (order 2, inverting r)
  r := fail; s := fail;
  for g in GeneratorsOfGroup(G) do
    if Order(g) = n then r := g; fi;
  od;
  if r = fail then
    # DihedralGroup may return 2 generators neither of order n for tiny n; find any order-n element
    for g in Elements(G) do if Order(g) = n then r := g; break; fi; od;
  fi;
  for g in Elements(G) do
    if Order(g) = 2 and s = fail and not (g in Group(r)) then
      if g*r*g = r^(-1) or n <= 2 then s := g; fi;
    fi;
  od;
  if s = fail then
    # fallback: any element outside <r>
    for g in Elements(G) do if not (g in Group(r)) then s := g; break; fi; od;
  fi;
  elts := [];
  for eps in [0,1] do
    for i in [0..n-1] do
      Add(elts, r^i * s^eps);
    od;
  od;
  exp := function(g)
    local p;
    p := Position(elts, g);
    return [(p-1) mod n, Int((p-1)/n)];
  end;
  return rec(G := G, r := r, s := s, elts := elts, exp := exp, n := n);
end;

AlphaBeta := function(DD)
  local alpha, beta;
  alpha := g -> DD.exp(g)[1] mod 2;
  beta  := g -> DD.exp(g)[2];
  return [alpha, beta];
end;

ProductCocycle := function(f1, f2)
  return {g1, g2} -> (f1(g1) * f2(g2)) mod 2;
end;

DicyclicCocycle := function(n, DD)
  # Dic_n = <a, x | a^{2n}=1, x^2=a^n, x a x^{-1} = a^{-1}>, order 4n.
  # Factor set for the section t of pi: Dic_n -> D_n, a |-> r, x |-> s:
  #   t(r^i s^eps) = a^i x^eps   (i in [0..n-1]).
  # Multiplication in Dic_n:
  #   (a^i x^e)(a^j x^d) = a^{i + (-1)^e j} x^{e+d}
  # and x^2 = a^n.  Writing the result as a^{?} x^{(e+d) mod 2} times z^w
  # (z = a^n the central fermion parity), w is the cocycle value.
  return function(g1, g2)
    local e1, d1, e2, d2, i, j, e, d, w, k;
    e1 := DD.exp(g1); i := e1[1]; e := e1[2];
    e2 := DD.exp(g2); j := e2[1]; d := e2[2];
    # exponent of a in the product before reducing x's
    if e = 0 then
      k := i + j;
    else
      k := i - j;
    fi;
    w := 0;
    # reduce x^{e+d}: if e=d=1, x^2 = a^n contributes z
    if e = 1 and d = 1 then
      k := k + n;   # x^2 = a^n = z
    fi;
    # reduce a^k to a^{k mod n} times z^{floor(k/n)} (k may be negative)
    while k < 0 do k := k + 2*n; od;
    while k >= 2*n do k := k - 2*n; od;
    if k >= n then
      w := w + 1;
      k := k - n;
    fi;
    return w mod 2;
  end;
end;

CheckCocycle := function(G, w)
  local elts, g1, g2, g3, lhs;
  elts := Elements(G);
  for g1 in elts do for g2 in elts do for g3 in elts do
    lhs := ( w(g2,g3) + w(g1*g2,g3) + w(g1,g2*g3) + w(g1,g2) ) mod 2;
    if lhs <> 0 then
      Print("COCYCLE FAIL at ", g1, g2, g3, "\n");
      return false;
    fi;
  od; od; od;
  return true;
end;

S1FromAlphaBeta := function(f)
  # anti-unitary grading from a degree-1 class f: G -> {0,1}
  return function(g)
    if f(g) = 1 then
      return [[ -1 ]];
    fi;
    return [[ 1 ]];
  end;
end;
