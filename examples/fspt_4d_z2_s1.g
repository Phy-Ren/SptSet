# 4+1D FSPT classification: G_b = Z_2, omega2 = 0, s1 = n1 (anti-unitary)
# G_f = Z_2^T x Z_2^f with T^2 = 1 (bosonic time reversal, separate parity)
# s1 = n1 means the generator of Z_2 acts anti-unitarily.
# Twisted coefficients: H^2(Z2,Z^T)=0, H^5(Z2,U(1)^T)=0, so p+ip and
# bosonic layers start trivial; MC and CF layers are Z2 at E2.

LoadPackage("HAP");
LoadPackage("SptSet");

G := CyclicGroup(2);;
R := ResolutionFiniteGroup(G, 10);;
f1 := GeneratorsOfGroup(G)[1];;

# s1 = n1: generator acts anti-unitarily (g -> [[-1]])
auMapT := GroupHomomorphismByImagesNC(G, GL(1, Integers), [f1], [[[ -1 ]]]);;

# EZ constructor: omega2 = 0 built-in, but s1 from auMapT is nontrivial
ss := FermionEZSPTSpecSeq(R, auMapT);;
Print("=== Z2 anti-unitary (omega2=0, s1=n1) ===\n");
FermionSPTLayersVerbose(ss, 4);;
