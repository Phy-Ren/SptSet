# 4+1D FSPT: G_b = D_6, omega2 = Dicyclic class, s1 = 0
# G_f = Dic_6 subset SU(2) - SU(2) approximation sequence
LoadPackage("HAP");
LoadPackage("IO");
LoadPackage("SptSet");
SPTSET_PARALLEL_JOBS := 10;;
SPTSET_PARALLEL_THRESHOLD := 10;;
SPTSET_PHASE2_ENABLED := true;;
SPTSET_CHECKPOINT_HOOK := function() end;;
_sptset_path := GAPInfo.PackagesInfo.sptset[1].InstallationPath;;
Read(Concatenation(_sptset_path, "/examples/dihedral_lib.g"));
n := 6;;
DD := DihedralData(n);;
G := DD.G;;
R := ResolutionFiniteGroup(G, 10);;
w := DicyclicCocycle(n, DD);;
if not CheckCocycle(G, w) then Print("COCYCLE FAIL\n"); FORCE_QUIT_GAP(1); fi;
s1zero := SptSetTrivialGroupAction(G);;
Print("=== D_6: omega2 = Dic_6 class, s1 = 0 ===\n");
t0 := NanosecondsSinceEpoch();;
ss := FermionSPTSpecSeq(R, s1zero, w);;
FermionSPTLayersVerbose(ss, 4);;
Print("TIME=", Int((NanosecondsSinceEpoch()-t0)/1000000), " ms\n");
FORCE_QUIT_GAP(0);
