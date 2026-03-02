# SptSet Checkpoint Driver for 3D FSPT Space Group Computation
#
# Usage:
#   Fresh start:  gap -q -r -b checkpoint_driver.g
#   Resume:       gap -q -r -L <checkpoint_file> -b checkpoint_driver.g
#
# Configuration (set before Read or via setup script):
#   CKPT_SG_NUM      - space group number (1-230), REQUIRED
#   CKPT_FILE        - checkpoint file path (default: ~/checkpoints/sg<N>.ws)
#   CKPT_MODE        - "ez" (spinless) or "s12" (spin-1/2), default "ez"
#   CKPT_DO_EXT      - compute group structure (default: true)
#   SPTSET_PARALLEL_JOBS      - parallel workers (default: 0)
#   SPTSET_PARALLEL_THRESHOLD - minimum n for parallelism (default: 20)
#   SPTSET_PHASE2_ENABLED     - enable Phase 2 (default: true)

if not IsBound(CKPT_SG_NUM) then
    Print("ERROR: CKPT_SG_NUM not set. Usage:\n");
    Print("  CKPT_SG_NUM := 210;; Read(\"checkpoint_driver.g\");;\n");
    FORCE_QUIT_GAP(1);
fi;

if not IsBound(CKPT_STEP) then
    # ---- FRESH START ----
    LoadPackage("HAP");;
    LoadPackage("IO");;
    LoadPackage("SptSet");;
    Read("res_space_group.g");;

    if not IsBound(CKPT_FILE) then
        Exec("mkdir -p ~/checkpoints");
        CKPT_FILE := Concatenation(GAPInfo.UserHome,
            "/checkpoints/sg", String(CKPT_SG_NUM), ".ws");
    fi;
    if not IsBound(CKPT_MODE) then CKPT_MODE := "ez"; fi;
    if not IsBound(CKPT_DO_EXT) then CKPT_DO_EXT := true; fi;

    CKPT_STEP := 0;
    CKPT_T_START := NanosecondsSinceEpoch();
    CKPT_SAVE_COUNT_ := 0;;

    Print("============================================================\n");
    Print("SptSet Checkpoint Driver\n");
    Print("  Space group: #", CKPT_SG_NUM, "\n");
    Print("  Mode: ", CKPT_MODE, "\n");
    Print("  Checkpoint file: ", CKPT_FILE, "\n");
    Print("  Parallel: JOBS=", SPTSET_PARALLEL_JOBS,
        " THRESHOLD=", SPTSET_PARALLEL_THRESHOLD,
        " PHASE2=", SPTSET_PHASE2_ENABLED, "\n");
    Print("  Group structure: ", CKPT_DO_EXT, "\n");
    Print("============================================================\n");

    Print("Building resolution for SG #", CKPT_SG_NUM, "...\n");
    t_ := NanosecondsSinceEpoch();;
    CKPT_SG := SpaceGroupBBNWZ(3, CKPT_SG_NUM);;
    CKPT_fSG := IsomorphismPcpGroup(CKPT_SG);;
    CKPT_SG1 := Image(CKPT_fSG);;
    CKPT_R := Resolution3DSpaceGroup(CKPT_fSG, 7);;
    Print("  Resolution built in ", Int((NanosecondsSinceEpoch()-t_)/1000000), " ms\n");
    Print("  Dimensions: ");
    for d_ in [0..6] do Print(CKPT_R!.dimension(d_), " "); od;
    Print("\n");

    CKPT_gs := GeneratorsOfGroup(CKPT_SG);;
    CKPT_f := GroupHomomorphismByImagesNC(CKPT_SG1, GL(1, Integers),
        List(CKPT_gs, x -> Image(CKPT_fSG, x)),
        List(CKPT_gs, x -> [[DeterminantMat(x)]]));;

    if CKPT_MODE = "ez" then
        CKPT_SS := FermionEZSPTSpecSeq(CKPT_R, CKPT_f);;
    else
        Print("ERROR: s12 mode not yet implemented in checkpoint driver.\n");
        FORCE_QUIT_GAP(1);
    fi;
    Print("Spectral sequence created.\n\n");
    Print("FRESH START — beginning computation.\n\n");
else
    # ---- RESUMED ----
    Print("============================================================\n");
    Print("RESUMED from checkpoint at step ", CKPT_STEP, "\n");
    Print("  Space group: #", CKPT_SG_NUM, "\n");
    Print("  Checkpoint file: ", CKPT_FILE, "\n");
    Print("  Parallel: JOBS=", SPTSET_PARALLEL_JOBS,
        " THRESHOLD=", SPTSET_PARALLEL_THRESHOLD,
        " PHASE2=", SPTSET_PHASE2_ENABLED, "\n");
    Print("============================================================\n\n");
    if not IsBound(CKPT_SAVE_COUNT_) then CKPT_SAVE_COUNT_ := 0; fi;
fi;

# Enable fine-grained checkpoint hook: library functions call this
# after each generator computation, ComponentEx class, and extension row.
# Uses atomic write (save to .tmp then rename) to prevent corruption.
SPTSET_CHECKPOINT_HOOK := function()
    local tmpFile;
    tmpFile := Concatenation(CKPT_FILE, ".tmp");
    SaveWorkspace(tmpFile);
    Exec(Concatenation("mv -f ", tmpFile, " ", CKPT_FILE));
    CKPT_SAVE_COUNT_ := CKPT_SAVE_COUNT_ + 1;
    Print("    [checkpoint #", CKPT_SAVE_COUNT_, "]\n");
end;;

# ---- PHASE A: Classification (FermionSPTLayersVerbose equivalent) ----
# Build the page list for dim=3 FSPT
CKPT_PAGES_ := [];;
CKPT_LAYER_NAMES_ := ["Bosonic:", "Complex fermion:", "Majorana:", "p+ip:"];;
for p_ in [1..4] do
    q_ := 4 - p_;;
    if q_ >= 0 and q_ <= 3 then
        rmax_ := Maximum(q_+2, p_+1);;
        for r_ in [2..rmax_] do
            Add(CKPT_PAGES_, [r_, p_, q_]);;
        od;;
    fi;;
od;;

CKPT_N_CLASS_ := Length(CKPT_PAGES_);;

Print("Phase A: Classification (", CKPT_N_CLASS_, " pages)\n");
Print("------------------------------------------------------------\n");

for i_ in [1..CKPT_N_CLASS_] do
    if i_ > CKPT_STEP then
        r_ := CKPT_PAGES_[i_][1];;
        p_ := CKPT_PAGES_[i_][2];;
        q_ := CKPT_PAGES_[i_][3];;
        Print("[", i_, "/", CKPT_N_CLASS_, "] Computing E^{",
            p_, ",", q_, "}_", r_, " (", CKPT_LAYER_NAMES_[q_+1], ")...\n");;
        t_ := NanosecondsSinceEpoch();;
        Erpq_ := SptSetSpecSeqComponent(CKPT_SS, r_, p_, q_);;
        SptSetFpZModuleCanonicalForm(Erpq_);;
        dt_ := Int((NanosecondsSinceEpoch() - t_) / 1000000);;
        Print("  E^{", p_, ",", q_, "}_", r_, " = ");;
        Display(Erpq_);;
        if not SptSetFpZModuleIsZero(Erpq_) then
            ngens_ := SptSetNumberOfGenerators(Erpq_);;
            Print("  Generators: ", ngens_,
                ", torsion: ", List([1..ngens_],
                  j_ -> Erpq_!.relations[j_][j_]), "\n");;
        fi;;
        Print("  Time: ", dt_, " ms");;
        if IsBound(CKPT_T_START) then
            Print("  (elapsed: ",
                Int((NanosecondsSinceEpoch()-CKPT_T_START)/1000000000), "s)");;
        fi;;
        Print("\n");;
        CKPT_STEP := i_;;
        SaveWorkspace(CKPT_FILE);;
        Print("  Checkpoint saved (step ", i_, "/", CKPT_N_CLASS_, ").\n\n");;
    fi;;
od;;

Print("============================================================\n");
Print("Phase A COMPLETE: Classification done.\n");
Print("============================================================\n\n");

# ---- PHASE B: Group Structure (SptSetSpecSeqResult equivalent) ----
if CKPT_DO_EXT then
    CKPT_EXT_STEP_ := CKPT_N_CLASS_ + 1;;
    if CKPT_STEP < CKPT_EXT_STEP_ then
        Print("Phase B: Computing group structure...\n");
        Print("------------------------------------------------------------\n");
        Print("  Parallel config: JOBS=", SPTSET_PARALLEL_JOBS,
            " THRESHOLD=", SPTSET_PARALLEL_THRESHOLD,
            " PHASE2=", SPTSET_PHASE2_ENABLED, "\n");;
        t_ := NanosecondsSinceEpoch();;
        CKPT_M := SptSetSpecSeqResult(CKPT_SS, 4, [1,2,3,4]);;
        SptSetFpZModuleCanonicalForm(CKPT_M);;
        dt_ := Int((NanosecondsSinceEpoch() - t_) / 1000000);;
        Print("\n============================================================\n");;
        Print("Group structure: ");;
        Display(CKPT_M);;
        Print("  Phase B time: ", dt_, " ms");;
        if IsBound(CKPT_T_START) then
            Print("  (total elapsed: ",
                Int((NanosecondsSinceEpoch()-CKPT_T_START)/1000000000), "s)");;
        fi;;
        Print("\n");;
        CKPT_STEP := CKPT_EXT_STEP_;;
        SaveWorkspace(CKPT_FILE);;
        Print("  Checkpoint saved (group structure done).\n\n");;
    fi;;

    Print("============================================================\n");
    Print("Phase B COMPLETE: Group structure done.\n");
    Print("============================================================\n\n");
fi;

# ---- FINAL SUMMARY ----
CKPT_T_END := NanosecondsSinceEpoch();;
Print("============================================================\n");
Print("ALL DONE: SG #", CKPT_SG_NUM, " (", CKPT_MODE, ")\n");
Print("============================================================\n");

if IsBound(CKPT_T_START) then
    Print("Total elapsed: ", Int((CKPT_T_END - CKPT_T_START)/1000000000), " s\n");
fi;

Print("\nClassification layers:\n");
for p_ in [1..4] do
    q_ := 4 - p_;;
    if q_ >= 0 and q_ <= 3 then
        rmax_ := Maximum(q_+2, p_+1);;
        Erpq_ := SptSetSpecSeqComponent(CKPT_SS, rmax_, p_, q_);;
        SptSetFpZModuleCanonicalForm(Erpq_);;
        Print("  ", CKPT_LAYER_NAMES_[q_+1], " E^{", p_, ",", q_, "}_inf = ");;
        Display(Erpq_);;
    fi;;
od;;

if CKPT_DO_EXT and IsBound(CKPT_M) then
    Print("Group structure: ");;
    Display(CKPT_M);;
fi;

SptSetPrintStats();;
Print("\nCheckpoint file: ", CKPT_FILE, "\n");

FORCE_QUIT_GAP(0);
