CKPT_SG_NUM := 210;;
CKPT_MODE := "ez";;
CKPT_DO_EXT := true;;
SPTSET_PARALLEL_JOBS := 26;;
SPTSET_PARALLEL_THRESHOLD := 5;;
SPTSET_PHASE2_ENABLED := true;;
CKPT_FILE := Concatenation(GAPInfo.UserHome, "/checkpoints/sg210fix.ws");;
Read("/home/user/xyren/software/gap-4.13.1/pkg/SptSet/jobs/checkpoint_driver.g");;
