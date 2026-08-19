# 4+1D FSPT scan for G_b = D_3 = S_3, order 6.
# H^1(S3, Z2) = Z2 (beta only, n odd), H^2(S3, Z2) = Z2 = {0, beta^2}.
# omega2 = beta^2  ->  G_f = Dic_3 = Z3 : Z4 (binary dihedral, order 12, SU(2) subgroup)
# s1 in {0, beta}: 4 combos total.

LoadPackage("HAP");
LoadPackage("SptSet");

_sptset_path := GAPInfo.PackagesInfo.sptset[1].InstallationPath;;
Read(Concatenation(_sptset_path, "/examples/dihedral_lib.g"));

SumCocycle := function(w1, w2)
  return {g1, g2} -> (w1(g1, g2) + w2(g1, g2)) mod 2;
end;

n := 3;;
DD := DihedralData(n);;
G := DD.G;;
Print("G = ", StructureDescription(G), "  |G| = ", Order(G), "\n");
R := ResolutionFiniteGroup(G, 10);;

ab := AlphaBeta(DD);;
beta := ab[2];;
zero2 := {g1, g2} -> 0;;
b2 := ProductCocycle(beta, beta);;

# Dicyclic cocycle from the extension (should be cohomologous to b2)
wDic := DicyclicCocycle(n, DD);;

for pair in [["0", zero2], ["b^2", b2], ["Dic_3(ext)", wDic]] do
  if CheckCocycle(G, pair[2]) then
    Print("cocycle OK: ", pair[1], "\n");
  else
    Print("!!! not a cocycle: ", pair[1], "\n");
  fi;
od;

s1zero := SptSetTrivialGroupAction(G);;
auBeta := GroupHomomorphismByImagesNC(G, GL(1, Integers),
  [DD.r, DD.s], [[[1]], [[-1]]]);;

for run in [["b^2 (=Dic_3)", "0"], ["0", "beta"], ["b^2 (=Dic_3)", "beta"]] do
  pair := First([["0", zero2], ["b^2 (=Dic_3)", b2]], x -> x[1] = run[1]);;
  spair := First([["0", s1zero], ["beta", auBeta]], x -> x[1] = run[2]);;
    Print("\n##### D_3: omega2 = ", pair[1], ", s1 = ", spair[1], " #####\n");
    t0 := NanosecondsSinceEpoch();;
    if pair[1] = "0" then
      ss := FermionEZSPTSpecSeq(R, spair[2]);;
    else
      ss := FermionSPTSpecSeq(R, spair[2], pair[2]);;
    fi;
    FermionSPTLayersVerbose(ss, 4);;
    Print("TIME=", Int((NanosecondsSinceEpoch()-t0)/1000000), " ms\n");
  od;
od;
Print("\nALL DONE\n");
FORCE_QUIT_GAP(0);
