if not IsBound(SPTSET_PARALLEL_JOBS) then
  SPTSET_PARALLEL_JOBS := 0;
fi;
if not IsBound(SPTSET_PARALLEL_THRESHOLD) then
  SPTSET_PARALLEL_THRESHOLD := 20;
fi;
if not IsBound(SPTSET_PHASE2_ENABLED) then
  SPTSET_PHASE2_ENABLED := true;
fi;
if not IsBound(SPTSET_CHECKPOINT_HOOK) then
  SPTSET_CHECKPOINT_HOOK := false;
fi;
if not IsBound(SPTSET_DEBUG_PURIFY) then
  SPTSET_DEBUG_PURIFY := false;
fi;

SPTSET_STATS := rec(
  p1_par_calls := 0, p1_par_time := 0,
  p1_seq_calls := 0, p1_seq_time := 0,
  p2_calls := 0, p2_time := 0, p2_max_m := 0,
  p2b_calls := 0, p2b_time := 0, p2b_max_ngens := 0
);

BindGlobal("SptSetPrintStats", function()
  Print("=== SptSet Parallel Stats ===\n");
  Print("Config: JOBS=", SPTSET_PARALLEL_JOBS,
    " THRESHOLD=", SPTSET_PARALLEL_THRESHOLD,
    " PHASE2=", SPTSET_PHASE2_ENABLED, "\n");
  Print("P1 (MapFromBarCocycle): ",
    SPTSET_STATS.p1_par_calls, " parallel calls (",
    SPTSET_STATS.p1_par_time, "ms), ",
    SPTSET_STATS.p1_seq_calls, " sequential calls (",
    SPTSET_STATS.p1_seq_time, "ms)\n");
  Print("P2 (BuildDerivative): ",
    SPTSET_STATS.p2_calls, " calls (",
    SPTSET_STATS.p2_time, "ms), max_m=",
    SPTSET_STATS.p2_max_m, "\n");
  Print("P2b (SpecSeqResult ext): ",
    SPTSET_STATS.p2b_calls, " calls (",
    SPTSET_STATS.p2b_time, "ms), max_ngens=",
    SPTSET_STATS.p2b_max_ngens, "\n");
end);

ReadPackage("SptSet", "lib/module.gi");
ReadPackage("SptSet", "lib/zlmap.gi");
ReadPackage("SptSet", "lib/coefficient.gi");
ReadPackage("SptSet", "lib/cochain.gi");
ReadPackage("SptSet", "lib/inhomo_cocycle.gi");
ReadPackage("SptSet", "lib/group_cohomology.gi");
ReadPackage("SptSet", "lib/spectral_sequence.gi");
ReadPackage("SptSet", "lib/bar_resolution_map_common.gi");
ReadPackage("SptSet", "lib/bar_resolution_map_hap.gi");
ReadPackage("SptSet", "lib/bar_resolution_map_mine.gi");
ReadPackage("SptSet", "lib/bar_resolution_map_debug.gi");
ReadPackage("SptSet", "lib/bar_resolution_map_choice.gi");
ReadPackage("SptSet", "lib/fermion_ez.gi");
ReadPackage("SptSet", "lib/bockstein.gi");
ReadPackage("SptSet", "lib/ss_cochain.gi");
ReadPackage("SptSet", "lib/ss_class.gi");
ReadPackage("SptSet", "lib/ss_vanilla.gi");
ReadPackage("SptSet", "lib/ss_fermion_ez.gi");
ReadPackage("SptSet", "lib/ss_fermion.gi");
ReadPackage("SptSet", "lib/ss_u1sl.gi");
ReadPackage("SptSet", "lib/ss_ti.gi");
ReadPackage("SptSet", "lib/ss_afermion.gi");
ReadPackage("SptSet", "lib/spin12.gi");
ReadPackage("SptSet", "lib/ext_data.gi");
# ReadPackage("SptSet", "lib/module_ext.gi");
ReadPackage("SptSet", "lib/ss_module.gi");
ReadPackage("SptSet", "lib/ss_disorder_fermion.gi");
ReadPackage("SptSet", "lib/ss_disorder_ti.gi");
#DeclareAutoreadableVariables("SptSet", "lib/ext_data.gi", ["AddTwister2DTable@"]);
