# 4+1D FSPT classification: G_b = Z_2, omega2 = n1^2, s1 = n1 (anti-unitary)
# G_f = Z_4^{Tf}: time reversal with T^2 = P_f (fermion parity)
# Twisted coefficients: H^2(Z2,Z^T)=0, H^5(Z2,U(1)^T)=0.
# MC obstruction: dn4 = n3 cup_1 n3 + omega2 cup n3 + s1 cup (n3 cup_2 n3).

LoadPackage("HAP");
LoadPackage("SptSet");

G := CyclicGroup(2);;
R := ResolutionFiniteGroup(G, 10);;
f1 := GeneratorsOfGroup(G)[1];;

# s1 = n1: generator acts anti-unitarily
auMapT := GroupHomomorphismByImagesNC(G, GL(1, Integers), [f1], [[[ -1 ]]]);;

# omega2 = n1^2 (T^2 = P_f)
omega2 := function(g1, g2)
  if g1 = f1 and g2 = f1 then
    return 1;
  fi;
  return 0;
end;;

ss := FermionSPTSpecSeq(R, auMapT, omega2);;
Print("=== Z2 anti-unitary (omega2=n1^2, s1=n1) ===\n");
FermionSPTLayersVerbose(ss, 4);;
