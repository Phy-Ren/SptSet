# Compare code s1-quarter vs locked s1-half: G=Z4, s1=l1, n3=l2*l1
G := CyclicGroup(4);;
R := ResolutionFiniteGroup(G, 10);;
brMap := SptSetBarResolutionMap(R);;
triv := SptSetTrivialGroupAction(G);;
coeffZ := SptSetCoefficientZn(0, triv);;
coeffZ2 := SptSetCoefficientZn(2, triv);;
f1 := GeneratorsOfGroup(G)[1];;
elts := List([0..3], i -> f1^i);;
ex := g -> Position(elts, g) - 1;;
auAlpha := GroupHomomorphismByImagesNC(G, GL(1, Integers), [f1], [[[-1]]]);;
s := g -> (1-(g^auAlpha)[1][1])/2;;
smod := g -> s(g) mod 2;;
l1 := g -> ex(g) mod 2;;
l2 := function(g1, g2)
  if ex(g1) + ex(g2) >= 4 then return 1; fi;
  return 0;
end;;
n3m := function(g1,g2,g3)
  return (l2(g1,g2) * l1(g3)) mod 2;
end;;
beta := ScaleInhomoCochain@(1/2, InhomoCoboundary@(coeffZ, n3m));;
betam := function(args...) return CallFuncList(beta, args) mod 2; end;;
s2 := Cup0@(1, 1, coeffZ2, smod, smod);;
s3 := Cup0@(2, 1, coeffZ2, s2, smod);;

# code version terms
quarterS2Beta := Cup0@(2, 4, coeffZ2, s2, betam);;
quarterS3N3 := Cup0@(3, 3, coeffZ2, s3, n3m);;

# locked version: beta_+ = (beta + betam)/2 per-face, then s1^2 cup beta_+ mod 2, times 1/2
betaPlus := function(args...)
  local B;
  B := CallFuncList(beta, args);
  return Int((B + (B mod 2)) / 2) mod 2;
end;;
lockedS := Cup0@(2, 4, coeffZ2, s2, betaPlus);;

# enumerate all 6-tuples
elts := Elements(G);;
cnt := 0; mm := 0; mma := 0; mmb := 0;
for g1 in elts do for g2 in elts do for g3 in elts do for g4 in elts do for g5 in elts do for g6 in elts do
  cnt := cnt + 1;
  codev := (1/4)*((quarterS2Beta(g1,g2,g3,g4,g5,g6)) mod 2) + (1/4)*((quarterS3N3(g1,g2,g3,g4,g5,g6)) mod 2);
  lockv := (1/2)*((lockedS(g1,g2,g3,g4,g5,g6)) mod 2);
  d := (codev - lockv) mod 1;
  if d <> 0 then
    mm := mm + 1;
    if d = 1/2 then mma := mma + 1; else mmb := mmb + 1; fi;
    if mm <= 5 then
      Print("DIFF at ", [g1,g2,g3,g4,g5,g6], " code=", codev, " locked=", lockv, "\n");
    fi;
  fi;
od; od; od; od; od; od;
Print("TOTAL tuples=", cnt, " mismatches=", mm, " (half=", mma, ", quarter=", mmb, ")\n");
FORCE_QUIT_GAP(0);
