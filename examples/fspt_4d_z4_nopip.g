# 4+1D FSPT classification: G_b = Z_4, omega2 nontrivial, s1 = 0, no p+ip
# G_f = Z_8, same as z4_full but with p+ip layer removed.
# NOTE: no-p+ip != EZ.  omega2 is still nontrivial here.

LoadPackage("HAP");
LoadPackage("SptSet");

G := CyclicGroup(4);;
R := ResolutionFiniteGroup(G, 10);;
s1Trivial := SptSetTrivialGroupAction(G);;

f1 := GeneratorsOfGroup(G)[1];;
elts := [Identity(G), f1, f1^2, f1^3];;
exp := g -> Position(elts, g) - 1;

omega2 := function(g1, g2)
  if exp(g1) + exp(g2) >= 4 then
    return 1;
  fi;
  return 0;
end;;

ss := FermionSPTSpecSeqNoPip(R, s1Trivial, omega2);;
Print("=== Z4 non-EZ no-p+ip (omega2 nontrivial, s1=0) ===\n");
FermionSPTLayersNoPipVerbose(ss, 4);;
