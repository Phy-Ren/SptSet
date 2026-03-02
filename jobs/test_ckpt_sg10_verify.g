# Checkpoint Thorough Test — Phase 2: Verify resume from each checkpoint
#
# Loads a checkpoint file and completes the remaining computation.
# Compares final results against the reference.
#
# Usage (called by test_ckpt_sg10_runner.sh, not directly):
#   gap -q -r -L <checkpoint.ws> -b test_ckpt_sg10_verify.g
#
# Expects CKPT_STEP to be set in the workspace.

Print("============================================================\n");;
Print("Checkpoint Verify: resuming from step ", CKPT_STEP, "\n");;
Print("============================================================\n\n");;

ModuleSig_ := function(M_)
    if SptSetFpZModuleIsZero(M_) then return []; fi;
    if not SptSetFpZModuleIsCanonical(M_) then SptSetFpZModuleCanonicalForm(M_); fi;
    return DiagonalOfMat(M_!.relations);
end;;

if not IsBound(CKPT_TEST_DIR) then
    CKPT_TEST_DIR := Concatenation(GAPInfo.UserHome, "/checkpoints/test_sg10");;
fi;;
Read(Concatenation(CKPT_TEST_DIR, "/reference.txt"));;

layerNames := ["Bosonic:", "Complex fermion:", "Majorana:", "p+ip:"];;

allMatch := true;;
nPages := Length(CKPT_REF_PAGES);;

# ---- Complete remaining classification pages ----
for i in [1..nPages] do
    if i > CKPT_STEP then
        r_ := CKPT_REF_PAGES[i][1];;
        p_ := CKPT_REF_PAGES[i][2];;
        q_ := CKPT_REF_PAGES[i][3];;
        t_ := NanosecondsSinceEpoch();;
        Erpq := SptSetSpecSeqComponent(SS, r_, p_, q_);;
        SptSetFpZModuleCanonicalForm(Erpq);;
        dt_ := Int((NanosecondsSinceEpoch() - t_) / 1000000);;
        got_ := ModuleSig_(Erpq);;
        if got_ = CKPT_REF_TORSIONS[i] then
            Print("  Step ", i, " E^{", p_, ",", q_, "}_", r_,
                ": PASS (", dt_, " ms)\n");;
        else
            Print("  Step ", i, " E^{", p_, ",", q_, "}_", r_,
                ": *** FAIL *** got ", got_,
                " expected ", CKPT_REF_TORSIONS[i], "\n");;
            allMatch := false;;
        fi;;
    else
        r_ := CKPT_REF_PAGES[i][1];;
        p_ := CKPT_REF_PAGES[i][2];;
        q_ := CKPT_REF_PAGES[i][3];;
        Erpq := SptSetSpecSeqComponent(SS, r_, p_, q_);;
        SptSetFpZModuleCanonicalForm(Erpq);;
        got_ := ModuleSig_(Erpq);;
        if got_ = CKPT_REF_TORSIONS[i] then
            Print("  Step ", i, " E^{", p_, ",", q_, "}_", r_,
                ": CACHED OK\n");;
        else
            Print("  Step ", i, " E^{", p_, ",", q_, "}_", r_,
                ": *** CACHE MISMATCH *** got ", got_,
                " expected ", CKPT_REF_TORSIONS[i], "\n");;
            allMatch := false;;
        fi;;
    fi;;
od;;

# ---- Complete group structure ----
if CKPT_STEP < nPages + 1 then
    Print("\n  Computing group structure...\n");;
    t_ := NanosecondsSinceEpoch();;
    M := SptSetSpecSeqResult(SS, 4, [1,2,3,4]);;
    SptSetFpZModuleCanonicalForm(M);;
    dt_ := Int((NanosecondsSinceEpoch() - t_) / 1000000);;
    got_ := ModuleSig_(M);;
    if got_ = CKPT_REF_EXT_TORSIONS then
        Print("  Group structure: PASS (", dt_, " ms)\n");;
    else
        Print("  Group structure: *** FAIL *** got ", got_,
            " expected ", CKPT_REF_EXT_TORSIONS, "\n");;
        allMatch := false;;
    fi;;
else
    if IsBound(M) then
        SptSetFpZModuleCanonicalForm(M);;
        got_ := ModuleSig_(M);;
        if got_ = CKPT_REF_EXT_TORSIONS then
            Print("  Group structure: CACHED OK\n");;
        else
            Print("  Group structure: *** CACHE MISMATCH ***\n");;
            allMatch := false;;
        fi;;
    else
        Print("  Group structure: variable M not bound after ext checkpoint\n");;
        allMatch := false;;
    fi;;
fi;;

Print("\n============================================================\n");;
if allMatch then
    Print("VERDICT: ALL PASS (resumed from step ", CKPT_STEP, ")\n");;
else
    Print("VERDICT: *** FAILED *** (resumed from step ", CKPT_STEP, ")\n");;
fi;;
Print("============================================================\n");;
FORCE_QUIT_GAP(0);;
