# Checkpoint Thorough Test — Phase 1: Save checkpoints at every step
#
# Runs SG #10 (C2h) ez computation, saving a SEPARATE checkpoint file
# at each step. This produces:
#   ~/checkpoints/test_sg10/step_00.ws  (after resolution + SS creation)
#   ~/checkpoints/test_sg10/step_01.ws  (after page 1)
#   ...
#   ~/checkpoints/test_sg10/step_NN.ws  (after final page)
#   ~/checkpoints/test_sg10/step_ext.ws (after group structure)
#   ~/checkpoints/test_sg10/reference.txt (final results for verification)
#
# Usage:
#   gap -q -r -b test_ckpt_sg10_save.g
#
# Expected time: ~60-90 min on compute node (JOBS=24), ~2-3h on cluster3 (JOBS=8)

if not IsBound(SPTSET_PARALLEL_JOBS) then
    SPTSET_PARALLEL_JOBS := 0;;
fi;;
if not IsBound(SPTSET_PARALLEL_THRESHOLD) then
    SPTSET_PARALLEL_THRESHOLD := 10;;
fi;;
if not IsBound(SPTSET_PHASE2_ENABLED) then
    SPTSET_PHASE2_ENABLED := true;;
fi;;

LoadPackage("HAP");;
LoadPackage("IO");;
LoadPackage("SptSet");;
Read("res_space_group.g");;

ModuleSig_ := function(M)
    if SptSetFpZModuleIsZero(M) then return []; fi;
    if not SptSetFpZModuleIsCanonical(M) then SptSetFpZModuleCanonicalForm(M); fi;
    return DiagonalOfMat(M!.relations);
end;;

if not IsBound(CKPT_TEST_DIR) then
    CKPT_TEST_DIR := Concatenation(GAPInfo.UserHome, "/checkpoints/test_sg10");;
fi;;
Exec(Concatenation("mkdir -p ", CKPT_TEST_DIR));;

Print("============================================================\n");;
Print("Checkpoint Test Phase 1: Full computation with per-step saves\n");;
Print("  SPTSET_PARALLEL_JOBS = ", SPTSET_PARALLEL_JOBS, "\n");;
Print("  SPTSET_PHASE2_ENABLED = ", SPTSET_PHASE2_ENABLED, "\n");;
Print("  Save directory: ", CKPT_TEST_DIR, "\n");;
Print("============================================================\n\n");;

# ---- Build resolution and SS ----
Print("Building resolution for SG #10...\n");;
t0_ := NanosecondsSinceEpoch();;
SG := SpaceGroupBBNWZ(3, 10);;
fSG := IsomorphismPcpGroup(SG);;
SG1 := Image(fSG);;
R := Resolution3DSpaceGroup(fSG, 7);;
dt_ := Int((NanosecondsSinceEpoch() - t0_) / 1000000);;
Print("  Resolution built in ", dt_, " ms\n");;
Print("  Dimensions: ");;
for d_ in [0..6] do Print(R!.dimension(d_), " "); od;;
Print("\n");;

gs := GeneratorsOfGroup(SG);;
f := GroupHomomorphismByImagesNC(SG1, GL(1, Integers),
    List(gs, x -> Image(fSG, x)),
    List(gs, x -> [[DeterminantMat(x)]]));;
SS := FermionEZSPTSpecSeq(R, f);;
Print("SS object created.\n");;

# Save step 0: resolution + SS, before any page computation
CKPT_STEP := 0;;
SaveWorkspace(Concatenation(CKPT_TEST_DIR, "/step_00.ws"));;
Print("  step_00.ws saved (resolution + SS, no pages yet).\n\n");;

# ---- Compute pages one by one ----
layerNames := ["Bosonic:", "Complex fermion:", "Majorana:", "p+ip:"];;
pages := [];;
for p_ in [1..4] do
    q_ := 4 - p_;;
    if q_ >= 0 and q_ <= 3 then
        rmax_ := Maximum(q_+2, p_+1);;
        for r_ in [2..rmax_] do
            Add(pages, [r_, p_, q_]);;
        od;;
    fi;;
od;;

nPages := Length(pages);;
Print("Total classification pages: ", nPages, "\n\n");;

# Track results for each page
pageResults := [];;
pageTimes := [];;
tClassStart := NanosecondsSinceEpoch();;

for i in [1..nPages] do
    r_ := pages[i][1];; p_ := pages[i][2];; q_ := pages[i][3];;
    Print("[", i, "/", nPages, "] E^{", p_, ",", q_, "}_", r_,
        " (", layerNames[q_+1], ")\n");;
    t_ := NanosecondsSinceEpoch();;
    Erpq := SptSetSpecSeqComponent(SS, r_, p_, q_);;
    SptSetFpZModuleCanonicalForm(Erpq);;
    dt_ := Int((NanosecondsSinceEpoch() - t_) / 1000000);;
    Print("  Result: ");;  Display(Erpq);;
    Print("  Time: ", dt_, " ms\n");;

    pageResults[i] := ModuleSig_(Erpq);;
    pageTimes[i] := dt_;;

    CKPT_STEP := i;;
    fname_ := "";;
    if i < 10 then
        fname_ := Concatenation(CKPT_TEST_DIR, "/step_0", String(i), ".ws");;
    else
        fname_ := Concatenation(CKPT_TEST_DIR, "/step_", String(i), ".ws");;
    fi;;
    SaveWorkspace(fname_);;
    Print("  Checkpoint saved: step_", String(i), ".ws\n\n");;
od;;

tClassEnd := NanosecondsSinceEpoch();;
Print("============================================================\n");;
Print("Classification complete: ", Int((tClassEnd-tClassStart)/1000000), " ms\n");;
Print("============================================================\n\n");;

# ---- Group structure ----
Print("Computing group structure (SptSetSpecSeqResult)...\n");;
tExtStart := NanosecondsSinceEpoch();;
M := SptSetSpecSeqResult(SS, 4, [1,2,3,4]);;
SptSetFpZModuleCanonicalForm(M);;
tExtEnd := NanosecondsSinceEpoch();;
Print("  Group structure: ");;  Display(M);;
Print("  Time: ", Int((tExtEnd-tExtStart)/1000000), " ms\n");;

CKPT_STEP := nPages + 1;;
SaveWorkspace(Concatenation(CKPT_TEST_DIR, "/step_ext.ws"));;
Print("  step_ext.ws saved.\n\n");;

# ---- Write reference file ----
refFile := OutputTextFile(Concatenation(CKPT_TEST_DIR, "/reference.txt"), false);;
PrintTo(refFile, "# SG #10 ez checkpoint test reference\n");;
PrintTo(refFile, "# Generated: ", StringTime(Runtime()), "\n");;
PrintTo(refFile, "CKPT_REF_NSTEPS := ", nPages + 1, ";;\n");;
PrintTo(refFile, "CKPT_REF_PAGES := ", pages, ";;\n");;
PrintTo(refFile, "CKPT_REF_TORSIONS := ", pageResults, ";;\n");;
PrintTo(refFile, "CKPT_REF_EXT_TORSIONS := ", ModuleSig_(M), ";;\n");;
CloseStream(refFile);;

Print("============================================================\n");;
Print("Phase 1 COMPLETE\n");;
Print("============================================================\n");;
Print("Checkpoint files saved in: ", CKPT_TEST_DIR, "/\n");;
Print("Reference file: ", CKPT_TEST_DIR, "/reference.txt\n");;
Print("Total time: ", Int((tExtEnd-t0_)/1000000000), " s\n");;
Print("\nPage-by-page results:\n");;
for i in [1..nPages] do
    Print("  Step ", i, ": E^{", pages[i][2], ",", pages[i][3],
        "}_", pages[i][1], " torsions=", pageResults[i],
        " (", pageTimes[i], " ms)\n");;
od;;
Print("  Step ext: group structure torsions=", ModuleSig_(M), "\n");;

SptSetPrintStats();;
FORCE_QUIT_GAP(0);;
