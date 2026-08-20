# 4+1D FSPT: G_b = Q8 (quaternion), omega2 = 0, s1 = 0 (EZ)
# Cobordism check: Omega_5^{Spin}(BQ8) = Z2 x Z2 (arXiv:2207.10700)
LoadPackage("HAP");
LoadPackage("IO");
LoadPackage("SptSet");
SPTSET_PARALLEL_JOBS := 10;;
SPTSET_PARALLEL_THRESHOLD := 10;;
SPTSET_PHASE2_ENABLED := true;;
SPTSET_CHECKPOINT_HOOK := function() end;;
G := QuaternionGroup(8);;
R := ResolutionFiniteGroup(G, 10);;
auMap := SptSetTrivialGroupAction(G);;
ss := FermionEZSPTSpecSeq(R, auMap);;
Print("=== Q8 EZ (omega2=0, s1=0); cobordism predicts Z2 x Z2 ===\n");
t0 := NanosecondsSinceEpoch();;
FermionSPTLayersVerbose(ss, 4);;
Print("TIME=", Int((NanosecondsSinceEpoch()-t0)/1000000), " ms\n");
FORCE_QUIT_GAP(0);
