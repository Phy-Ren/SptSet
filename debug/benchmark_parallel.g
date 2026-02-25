# Benchmark: Cs s12, SptSetSpecSeqResult [1,2,3,4]
# Set SPTSET_PARALLEL_JOBS before Read()ing this file.
#
# Usage (from pkg/SptSet/examples/ directory):
#   echo 'SPTSET_PARALLEL_JOBS := 0;; Read("../debug/benchmark_parallel.g");;' \
#     | gap -q -r -b
#   echo 'SPTSET_PARALLEL_JOBS := 8;; Read("../debug/benchmark_parallel.g");;' \
#     | gap -q -r -b
#
# Or use the bash wrapper:
#   bash ../debug/run_benchmark.sh

LoadPackage("HAP");;
LoadPackage("IO");;
LoadPackage("SptSet");;

Print("============================================================\n");;
Print("Benchmark: Cs s12, SptSetSpecSeqResult [1,2,3,4]\n");;
Print("SPTSET_PARALLEL_JOBS = ", SPTSET_PARALLEL_JOBS, "\n");;
Print("SPTSET_PARALLEL_THRESHOLD = ", SPTSET_PARALLEL_THRESHOLD, "\n");;
Print("============================================================\n");;

SG := SpaceGroupBBNWZ(3, 6);;
PG := PointGroup(SG);;
R := ResolutionFiniteGroup(PG, 7);;

gens := GeneratorsOfGroup(PG);;
signs := List(gens, x -> [[DeterminantMat(x)]]);;
f := GroupHomomorphismByImagesNC(PG, GL(1, Integers), gens, signs);;
w2 := Spin12FactorForPointGroup(PG);;
ss := FermionSPTSpecSeq(R, f, w2);;

Print("Setup complete. Starting computation...\n");;

t0 := NanosecondsSinceEpoch();;
FermionSPTLayersVerbose(ss, 3);;
t1 := NanosecondsSinceEpoch();;
M := SptSetSpecSeqResult(ss, 4, [1,2,3,4]);;
SptSetFpZModuleCanonicalForm(M);;
t2 := NanosecondsSinceEpoch();;

Print("\n============================================================\n");;
Print("RESULTS\n");;
Print("============================================================\n");;
Print("SPTSET_PARALLEL_JOBS = ", SPTSET_PARALLEL_JOBS, "\n");;
Print("LayersVerbose:  ", Int((t1-t0)/1000000), " ms\n");;
Print("SpecSeqResult:  ", Int((t2-t1)/1000000), " ms\n");;
Print("Total:          ", Int((t2-t0)/1000000), " ms\n");;
Print("Result: ");;
Display(M);;

FORCE_QUIT_GAP(0);
