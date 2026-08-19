# 4+1D FSPT scan for G_b = D_4, order 8.
# H^1 = Z2^2 (alpha, beta), H^2 = Z2^3.
# omega2 = DicyclicCocycle -> G_f = Dic_4 = Q16 (generalized quaternion, SU(2) subgroup)
# Also product classes a^2, b^2, and sums with the dicyclic class.
# s1 = 0 for all rows in this scan.

LoadPackage("HAP");
LoadPackage("SptSet");

_sptset_path := GAPInfo.PackagesInfo.sptset[1].InstallationPath;;
Read(Concatenation(_sptset_path, "/examples/dihedral_lib.g"));

SumCocycle := function(w1, w2)
  return {g1, g2} -> (w1(g1, g2) + w2(g1, g2)) mod 2;
end;

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

n := 4;;
DD := DihedralData(n);;
G := DD.G;;
Print("G = ", StructureDescription(G), "  |G| = ", Order(G), "\n");
R := ResolutionFiniteGroup(G, 10);;

ab := AlphaBeta(DD);;
alpha := ab[1];; beta := ab[2];;
zero2 := {g1, g2} -> 0;;

a2 := ProductCocycle(alpha, alpha);;
b2 := ProductCocycle(beta, beta);;
wDic := DicyclicCocycle(n, DD);;

wlist := [
  ["0", zero2],
  ["a^2", a2],
  ["b^2", b2],
  ["a^2+b^2", SumCocycle(a2, b2)],
  ["Dic_4=Q16", wDic],
  ["Dic+a^2", SumCocycle(wDic, a2)],
  ["Dic+b^2", SumCocycle(wDic, b2)],
  ["Dic+a^2+b^2", SumCocycle(wDic, SumCocycle(a2, b2))]
];;

for pair in wlist do
  if not CheckCocycle(G, pair[2]) then
    Print("!!! not a cocycle: ", pair[1], "\n");
  fi;
od;
Print("cocycle check done\n");
for pair in wlist do
  extgrp := ExtensionGroup(G, pair[2]);;
  Print("omega2 = ", pair[1], "  ->  G_f = ", StructureDescription(extgrp), "\n");
od;

s1zero := SptSetTrivialGroupAction(G);;

for pair in wlist do
  Print("\n##### D_4: omega2 = ", pair[1], ", s1 = 0 #####\n");
  t0 := NanosecondsSinceEpoch();;
  if pair[1] = "0" then
    ss := FermionEZSPTSpecSeq(R, s1zero);;
  else
    ss := FermionSPTSpecSeq(R, s1zero, pair[2]);;
  fi;
  FermionSPTLayersVerbose(ss, 4);;
  Print("TIME=", Int((NanosecondsSinceEpoch()-t0)/1000000), " ms\n");
od;
Print("\nALL DONE\n");
FORCE_QUIT_GAP(0);
