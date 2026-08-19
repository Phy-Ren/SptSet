# 4+1D FSPT scan for G_b = D_2 = Z2 x Z2 (Klein), order 4.
# omega2 choices: all 8 classes in H^2(Z2xZ2, Z2) = Z2^3 = {a^2, ab, b^2 sums}.
# Extension groups: 0 -> Z2^3; a^2,b^2,a^2+b^2 -> Z4xZ2; ab,a^2+ab,ab+b^2 -> D4;
#                   a^2+ab+b^2 -> Q8 = Dic_2  (the SU(2) case!)
# s1 choices: 0, alpha, beta, alpha+beta (alpha,beta symmetric by S3 automorphism).

LoadPackage("HAP");
LoadPackage("SptSet");

_sptset_path := GAPInfo.PackagesInfo.sptset[1].InstallationPath;;
Read(Concatenation(_sptset_path, "/examples/dihedral_lib.g"));

SumCocycle := function(w1, w2)
  return {g1, g2} -> (w1(g1, g2) + w2(g1, g2)) mod 2;
end;

# Build the extension group of G by Z2 via cocycle w (regular action), for labeling
ExtensionGroup := function(G, w)
  local elts, N, perms, i, a, g1, imgs, j, b, g2, k, c;
  elts := Elements(G);
  N := Length(elts);
  perms := [];
  for i in [1..N] do
    for a in [0,1] do
      g1 := elts[i];
      imgs := [];
      for j in [1..N] do
        for b in [0,1] do
          g2 := elts[j];
          k := Position(elts, g1*g2);
          c := (a + b + w(g1, g2)) mod 2;
          imgs[2*(j-1)+b+1] := 2*(k-1)+c+1;
        od;
      od;
      Add(perms, PermList(imgs));
    od;
  od;
  return Group(perms);
end;

n := 2;;
DD := DihedralData(n);;
G := DD.G;;
Print("G = ", StructureDescription(G), "  |G| = ", Order(G), "\n");
R := ResolutionFiniteGroup(G, 10);;

ab := AlphaBeta(DD);;
alpha := ab[1];; beta := ab[2];;
zero2 := {g1, g2} -> 0;;

a2 := ProductCocycle(alpha, alpha);;
b2 := ProductCocycle(beta, beta);;
pab := ProductCocycle(alpha, beta);;

wlist := [
  ["0", zero2],
  ["a^2", a2],
  ["b^2", b2],
  ["ab", pab],
  ["a^2+b^2", SumCocycle(a2, b2)],
  ["a^2+ab", SumCocycle(a2, pab)],
  ["ab+b^2", SumCocycle(pab, b2)],
  ["a^2+ab+b^2 (Q8=Dic_2)", SumCocycle(SumCocycle(a2, pab), b2)]
];;

# verify all are cocycles
for pair in wlist do
  if not CheckCocycle(G, pair[2]) then
    Print("!!! not a cocycle: ", pair[1], "\n");
  fi;
od;
Print("cocycle check done\n");

# label extension groups
for pair in wlist do
  extgrp := ExtensionGroup(G, pair[2]);;
  Print("omega2 = ", pair[1], "  ->  G_f = ", StructureDescription(extgrp), "\n");
od;

s1zero := SptSetTrivialGroupAction(G);;

# anti-unitary gradings: s1 = alpha, beta, alpha+beta
auAlpha := GroupHomomorphismByImagesNC(G, GL(1, Integers),
  [DD.r, DD.s], [[[-1]], [[1]]]);;
auBeta := GroupHomomorphismByImagesNC(G, GL(1, Integers),
  [DD.r, DD.s], [[[1]], [[-1]]]);;
auAB := GroupHomomorphismByImagesNC(G, GL(1, Integers),
  [DD.r, DD.s], [[[-1]], [[-1]]]);;

s1list := [
  ["0", s1zero],
  ["alpha", auAlpha],
  ["beta", auBeta],
  ["alpha+beta", auAB]
];;

# orbit-covering runlist: [omega2 label, s1 label]
runlist := [
  ["0", "0"], ["a^2", "0"], ["b^2", "0"], ["ab", "0"],
  ["a^2+b^2", "0"], ["a^2+ab", "0"], ["ab+b^2", "0"], ["a^2+ab+b^2 (Q8=Dic_2)", "0"],
  ["0", "alpha"], ["a^2", "alpha"], ["a^2", "beta"],
  ["ab", "alpha"], ["ab", "alpha+beta"],
  ["a^2+ab+b^2 (Q8=Dic_2)", "alpha"]
];;

for run in runlist do
  pair := First(wlist, x -> x[1] = run[1]);;
  spair := First(s1list, x -> x[1] = run[2]);;
  Print("\n##### D_2: omega2 = ", pair[1], ", s1 = ", spair[1], " #####\n");
  t0 := NanosecondsSinceEpoch();;
  if pair[1] = "0" then
    ss := FermionEZSPTSpecSeq(R, spair[2]);;
  else
    ss := FermionSPTSpecSeq(R, spair[2], pair[2]);;
  fi;
  FermionSPTLayersVerbose(ss, 4);;
  Print("TIME=", Int((NanosecondsSinceEpoch()-t0)/1000000), " ms\n");
od;
Print("\nALL DONE\n");
FORCE_QUIT_GAP(0);
