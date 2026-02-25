LoadPackage("HAP");;
LoadPackage("IO");;
LoadPackage("SptSet");;
Read("res_space_group.g");;
Print("============================================================\n");;
Print("Benchmark: SG #10 (P2/m, C2h) ezSpinless\n");;
Print("SPTSET_PARALLEL_JOBS = ", SPTSET_PARALLEL_JOBS, "\n");;
Print("SPTSET_PARALLEL_THRESHOLD = ", SPTSET_PARALLEL_THRESHOLD, "\n");;
Print("============================================================\n");;
SG := SpaceGroupBBNWZ(3, 10);;
fSG := IsomorphismPcpGroup(SG);;
SG1 := Image(fSG);;
t_res := NanosecondsSinceEpoch();;
R := Resolution3DSpaceGroup(fSG, 7);;
t_res_end := NanosecondsSinceEpoch();;
Print("Resolution built: ", Int((t_res_end - t_res)/1000000), " ms\n");;
for d in [0..7] do
  Print("  deg ", d, ": n = ", Dimension(R)(d), "\n");;
od;
gs := GeneratorsOfGroup(SG);;
f := GroupHomomorphismByImagesNC(SG1, GL(1, Integers),
    List(gs, x -> Image(fSG, x)),
    List(gs, x -> [[DeterminantMat(x)]]));;
SS := FermionEZSPTSpecSeq(R, f);;
Print("Setup complete.\n\n");;
t0 := NanosecondsSinceEpoch();;
FermionSPTLayersVerbose(SS, 3);;
t1 := NanosecondsSinceEpoch();;
layers := FermionSPTLayers(SS, 3);;
Print("\n============================================================\n");;
Print("RESULTS\n");;
Print("============================================================\n");;
Print("SPTSET_PARALLEL_JOBS = ", SPTSET_PARALLEL_JOBS, "\n");;
Print("Resolution time:    ", Int((t_res_end - t_res)/1000000), " ms\n");;
Print("LayersVerbose time: ", Int((t1 - t0)/1000000), " ms\n");;
Print("Layers: ");;
Display(layers);;
FORCE_QUIT_GAP(0);
