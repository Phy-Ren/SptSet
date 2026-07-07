# 4+1D FSPT classification test WITHOUT the p+ip layer.
# Symmetry: G_f = Z_4^f, so G_b = Z_2.
# This is NON-EZ: omega2 = n1^2 is the non-trivial central extension
# cocycle, and s1 = 0 (unitary action, no anti-unitary symmetry).
# NOTE: no-p+ip ≠ EZ.  no-p+ip removes the n2 layer; EZ sets omega2=0.
# This example keeps omega2 ≠ 0 and only drops the p+ip quadruplet.
# Expected cohomological layer structure for the triplet (no p+ip):
#   Majorana n3:        Z_2
#   Complex fermion n4: Z_2
#   Bosonic nu5:        Z_2
# Stacking is not tested here.

LoadPackage("HAP");
LoadPackage("SptSet");

G := CyclicGroup(2);;
R := ResolutionFiniteGroup(G, 8);;
# s1Trivial = trivial anti-unitary action  =>  s1 = 0
s1Trivial := SptSetTrivialGroupAction(G);;
f1 := GeneratorsOfGroup(G)[1];;

# Non-trivial omega2 = n1^2  (characteristic of Z_4^f extension)
omega2 := function(g1, g2)
  if g1 = f1 and g2 = f1 then
    return 1;
  fi;
  return 0;
end;;

# FermionSPTSpecSeqNoPip = non-EZ, p+ip layer removed
ss := FermionSPTSpecSeqNoPip(R, s1Trivial, omega2);;
FermionSPTLayersNoPipVerbose(ss, 4);;
