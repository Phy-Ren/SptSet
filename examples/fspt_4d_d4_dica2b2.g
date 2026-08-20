LoadPackage("HAP");
LoadPackage("SptSet");
LoadPackage("IO");
SPTSET_PARALLEL_JOBS := 10;;
SPTSET_PARALLEL_THRESHOLD := 10;;
SPTSET_PHASE2_ENABLED := true;;
SPTSET_CHECKPOINT_HOOK := function() end;;
_sptset_path := GAPInfo.PackagesInfo.sptset[1].InstallationPath;;
Read(Concatenation(_sptset_path, "/examples/dihedral_lib.g"));
SumCocycle := function(w1, w2)
  return {g1, g2} -> (w1(g1, g2) + w2(g1, g2)) mod 2;
end;
n := 4;;
DD := DihedralData(n);;
G := DD.G;;
R := ResolutionFiniteGroup(G, 10);;
ab := AlphaBeta(DD);;
alpha := ab[1];; beta := ab[2];;
zero2 := {g1, g2} -> 0;;
a2 := ProductCocycle(alpha, alpha);;
b2 := ProductCocycle(beta, beta);;
wDic := DicyclicCocycle(n, DD);;
w := SumCocycle(wDic, SumCocycle(a2, b2));;
s1zero := SptSetTrivialGroupAction(G);;
Print("=== D_4: omega2 = Dic+a^2+b^2, s1 = 0 ===\n");
t0 := NanosecondsSinceEpoch();;
if "Dic+a^2+b^2" = "0" then
  ss := FermionEZSPTSpecSeq(R, s1zero);;
else
  ss := FermionSPTSpecSeq(R, s1zero, w);;
fi;
FermionSPTLayersVerbose(ss, 4);;
Print("TIME=", Int((NanosecondsSinceEpoch()-t0)/1000000), " ms\n");
Print("DONE
");
FORCE_QUIT_GAP(0);
