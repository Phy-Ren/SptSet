LoadPackage("IO");;
if IsBoundGlobal("ParListByFork") then
  Print("DIAG: IO_OK ParListByFork=true\n");;
  r := ParListByFork([1..4], i -> i^2, rec(NumberJobs := 2));;
  Print("DIAG: ParListByFork test=", r = [1,4,9,16], "\n");;
else
  Print("DIAG: FATAL ParListByFork NOT FOUND\n");;
fi;
FORCE_QUIT_GAP(0);
