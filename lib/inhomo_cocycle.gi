InstallGlobalFunction(ZeroCocycle@,
function(arg...) return 0; end);

InstallGlobalFunction(BarResolutionBoundary@,
function(gid, glist)
  local n, dglist, gl2, glext, i;
  n := Length(glist);
  dglist := [];
  if n > 0 then
    gl2 := StructuralCopy(glist);
    Add(gl2, 1, 1);
    Add(dglist, gl2);

    glext := StructuralCopy(glist);
    Add(glext, 1, 1);
    Add(glext, gid, 2);

    for i in [1..(n-1)] do
      gl2 := StructuralCopy(glext);
      gl2[i+2] := gl2[i+2] * Remove(gl2, i+3);
      if i mod 2 = 1 then
        gl2[1] := -1;
      fi;
      Add(dglist, gl2);
    od;

    gl2 := StructuralCopy(glext);
    if n mod 2 = 1 then
      gl2[1] := -1;
    fi;
    Remove(gl2, n+2);
    Add(dglist, gl2);
  fi;
  return dglist;
end);

InstallGlobalFunction(InhomoCoboundary@,
function(coeff, a)
  local gAction, gid, da;
  gAction := coeff!.gAction;
  gid := Identity(PreImage(gAction));
  da := function(glist...)
    local n, dglist, result, x, xs, xg, xgl;
    n := Length(glist);
    dglist := BarResolutionBoundary@(gid, glist);
    result := 0;
    for x in dglist do
      xs := x[1];
      xg := x[2];
      xgl := x{[3..(n+1)]};
      result := result + xs * (xg^gAction)[1][1] * CallFuncList(a, xgl);
    od;

    return result;
  end;

  return da;
end);

InstallGlobalFunction(NegativeInhomoCochain@,
function(a)
  if a = ZeroCocycle@ then
    return ZeroCocycle@;
  else
    return {glist...} -> (-CallFuncList(a, glist));
  fi;
end);

InstallGlobalFunction(ScaleInhomoCochain@,
function(k, a)
  if a = ZeroCocycle@ then
    return ZeroCocycle@;
  else
    return {glist...} -> (k * CallFuncList(a, glist));
  fi;
end);

InstallGlobalFunction(AddInhomoCochain@,
function(a, b)
  if a = ZeroCocycle@ then
    return b;
  elif b = ZeroCocycle@ then
    return a;
  fi;
  return {glist...} -> (CallFuncList(a, glist) + CallFuncList(b, glist));
end);

InstallGlobalFunction(Cup0@,
function(p, q, coeff, a, b)
  local gAction, f, gid;
  gAction := coeff!.gAction;
  gid := Identity(PreImage(gAction));
  f := function(glist...)
    local gp, gq, gpp;
    gp := glist{[1..p]};
    gq := glist{[(p+1)..(p+q)]};
    gpp := Product(gp, gid);
    return CallFuncList(a, gp) *
      ((gpp^gAction)[1][1] * CallFuncList(b, gq));
  end;
  return f;
end);

InstallGlobalFunction(Cup1@,
function(p, q, coeff, a, b)
  local gAction, f, gid;
  gAction := coeff!.gAction;
  gid := Identity(PreImage(gAction));
  f := function(glist...)
    local g1, g2, g3, g1p, g2p, s, i, result;
    result := 0;
    for i in [0..(p-1)] do
      g1 := glist{[1..i]};
      g2 := glist{[(i+1)..(i+q)]};
      g3 := glist{[(i+q+1)..(p+q-1)]};
      g1p := Product(g1, gid);
      g2p := Product(g2, gid);
      s := (-1)^((p-i)*(q+1));
      result := result + s * CallFuncList(a, Concatenation(g1, [g2p], g3))
        * ((g1p^gAction)[1][1] * CallFuncList(b, g2));
    od;
    return result;
  end;
  return f;
end);

InstallGlobalFunction(Cup2@,
function(p, q, coeff, a, b)
  local gAction, f, gid;
  gAction := coeff!.gAction;
  gid := Identity(PreImage(gAction));
  return function(glist...)
    local gl1, gl2, gl3, gl4, gl1p, gl2p, gl3p, i, j, s, result;
    result := 0;
    # Display([p, q]);
    for i in [0..(p-2)] do
      for j in [(i+1)..(q+i-1)] do
        # Display([[1..i], [(i+1)..j], [(j+1)..(j-i+p-1)], [(j-i+p)..(p+q-2)]]);
        gl1 := glist{[1..i]};
        gl2 := glist{[(i+1)..j]};
        gl3 := glist{[(j+1)..(j-i+p-1)]};
        gl4 := glist{[(j-i+p)..(p+q-2)]};

        gl1p := Product(gl1, gid);
        gl2p := Product(gl2, gid);
        gl3p := Product(gl3, gid);

        s:= (-1)^((p-i)*(j-i+1));
        result := result + s * CallFuncList(a, Concatenation(gl1, [gl2p], gl3))
          * ((gl1p^gAction)[1][1] * CallFuncList(b, Concatenation(gl2, [gl3p], gl4)));
      od;
    od;
    return result;
  end;
end);

InstallGlobalFunction(Cup3@,
function(p, q, coeff, a, b)
  local gAction, f, gid;
  gAction := coeff!.gAction;
  gid := Identity(PreImage(gAction));
  return function(glist...)
    local gl1, gl2, gl3, gl4, gl5, gl1p, gl2p, gl3p, gl4p, i, j, k, m, s, result;
    result := 0;

    for i in [0..(p-3)] do
      gl1 := glist{[1..i]};
      gl1p := Product(gl1, gid);
      for j in [(i+1)..(q+i-2)] do
        gl2 := glist{[(i+1)..j]};
        gl2p := Product(gl2, gid);
        for k in [(j+1)..(p-2+j-i)] do
          gl3 := glist{[(j+1)..k]};
          gl3p := Product(gl3, gid);
          m := q + i - j + k - 1;
          gl4 := glist{[(k+1)..m]};
          gl4p := Product(gl4, gid);
          gl5 := glist{[(m+1)..(p+q-3)]};

          s := (-1)^((p-i) * (j-i+1) + (q+i-j) * (p-i+j-k-3));
          result := result + s * CallFuncList(a, Concatenation(gl1, [gl2p], gl3, [gl4p], gl5))
            * ((gl1p^gAction)[1][1] * CallFuncList(b, Concatenation(gl2, [gl3p], gl4)));
        od;
      od;
    od;

    return result;
  end;
end);

InstallGlobalFunction(Cup4@,
function(p, q, coeff, a, b)
  # Signed integral higher cup product a cup_4 b in the inhomogeneous bar
  # convention.  Signs are kept for integral cochains; all current FSPT uses
  # reduce the result mod 2, where the sign convention is invisible.  The
  # signed integral convention has not been independently tested.
  local gAction, gid;
  gAction := coeff!.gAction;
  gid := Identity(PreImage(gAction));
  return function(glist...)
    local gl1, gl2, gl3, gl4, gl5, gl6,
          gl1p, gl2p, gl3p, gl4p, gl5p,
          i, j, k, l, m, n, s, result;
    result := 0;

    for i in [0..(p-4)] do
      gl1 := glist{[1..i]};
      gl1p := Product(gl1, gid);
      for j in [(i+1)..(q+i-3)] do
        gl2 := glist{[(i+1)..j]};
        gl2p := Product(gl2, gid);
        for k in [(j+1)..(p-2+j-i)] do
          gl3 := glist{[(j+1)..k]};
          gl3p := Product(gl3, gid);
          l := q + i - j + k - 2;
          for m in [(k+1)..l] do
            gl4 := glist{[(k+1)..m]};
            gl4p := Product(gl4, gid);
            n := p - i + j - k + m - 2;
            gl5 := glist{[(m+1)..n]};
            gl5p := Product(gl5, gid);
            gl6 := glist{[(n+1)..(p+q-4)]};

            s := (-1)^((p-i) * (j-i+1)
                   + (q+i-j) * (p-i+j-k-3)
                   + (p-i+j-k+m-n-4) * (q+i-j+k-m));
            result := result + s *
              CallFuncList(a, Concatenation(gl1, [gl2p], gl3, [gl4p], gl5))
              * ((gl1p^gAction)[1][1] *
              CallFuncList(b, Concatenation(gl2, [gl3p], gl4, [gl5p], gl6)));
          od;
        od;
      od;
    od;

    return result;
  end;
end);

# Cache for SurjectionCuts@ results, keyed by "degs:word".
BindGlobal("SurjectionCutsCache@", rec());

InstallGlobalFunction(SurjectionCuts@,
function(degs, word)
  # Return all interval-cut vertex lists for the mod-2 surjection product.
  # Convention: 0=i0<=...<=iL=N, with labelled interval unions having
  # exactly degree+1 vertices for every input.
  local N, L, arity, result, AddCut, Recurse;
  N := Sum(degs) - (Length(word) - Length(degs));
  L := Length(word);
  arity := Length(degs);

  # Input validation: fail loudly on invalid word/degs, don't silently return [].
  Assert(0, N >= 0,
    Concatenation("SurjectionCuts@: invalid degree sum, N=", String(N),
      " < 0. Check degs=", String(degs), " word=", String(word)));
  Assert(0, ForAll(word, x -> IsInt(x) and 1 <= x and x <= arity),
    Concatenation("SurjectionCuts@: word labels out of range [1..", String(arity),
      "], word=", String(word)));

  result := [];

  AddCut := function(cut)
    local vs, ell, label, v, ok, j;
    vs := List([1..arity], j -> []);
    for ell in [1..L] do
      label := word[ell];
      for v in [cut[ell]..cut[ell+1]] do
        if Position(vs[label], v) = fail then
          Add(vs[label], v);
        fi;
      od;
    od;
    ok := true;
    for j in [1..arity] do
      if Length(vs[j]) <> degs[j] + 1 then
        ok := false;
        break;
      fi;
    od;
    if ok then
      Add(result, vs);
    fi;
  end;

  Recurse := function(pos, last, cut)
    local x, cut2;
    if pos = L + 1 then
      cut2 := ShallowCopy(cut);
      cut2[L+1] := N;
      AddCut(cut2);
      return;
    fi;
    for x in [last..N] do
      cut2 := ShallowCopy(cut);
      cut2[pos] := x;
      Recurse(pos + 1, x, cut2);
    od;
  end;

  Recurse(2, 0, [0]);
  return result;
end);

InstallGlobalFunction(SurjectionCutsCached@,
function(degs, word)
  local key;
  key := Concatenation(String(degs), ":", String(word));
  if not IsBound(SurjectionCutsCache@.(key)) then
    SurjectionCutsCache@.(key) := SurjectionCuts@(degs, word);
  fi;
  return SurjectionCutsCache@.(key);
end);

InstallGlobalFunction(SurjectionProductZ2@,
function(degs, cochains, word)
  # Mod-2 May-Steenrod/surjection product in inhomogeneous bar coordinates.
  # `word` is a list of labels, e.g. [1,2,3,1,3,4,3,4] for 12313434.
  # Uses cached cut enumeration via SurjectionCutsCached@.
  local cuts, arity;
  cuts := SurjectionCutsCached@(degs, word);
  arity := Length(degs);
  return function(glist...)
    local N, gid, prefixes, i, cut, value, total, j, V, args;
    N := Length(glist);
    if N = 0 then
      return 0;
    fi;
    gid := glist[1]^0;
    prefixes := [gid];
    for i in [1..N] do
      Add(prefixes, prefixes[i] * glist[i]);
    od;

    total := 0;
    for cut in cuts do
      value := 1;
      for j in [1..arity] do
        V := cut[j];
        args := [];
        for i in [1..Length(V)-1] do
          Add(args, prefixes[V[i]+1]^-1 * prefixes[V[i+1]+1]);
        od;
        value := value * (CallFuncList(cochains[j], args) mod 2);
        if (value mod 2) = 0 then
          break;
        fi;
      od;
      total := total + value;
    od;
    return total mod 2;
  end;
end);

InstallGlobalFunction(CheckCochainEqOverBasisListZ2@,
function(c1, c2, basislist)
  local deg, glist;
  if c1 = ZeroCocycle@ then
    if c2 = ZeroCocycle@ then return;
    else
      deg := NumberArgumentsFunction(c2);
    fi;
  else
    deg := NumberArgumentsFunction(c1);
  fi;

  for glist in basislist do
    if (CallFuncList(c1, glist) mod 2) <> (CallFuncList(c2, glist) mod 2) then
      Error("CheckCochainEqOverSubset fails!");
    fi;
  od;
end);

InstallGlobalFunction(CheckCochainEqOverBasisListU1@,
function(c1, c2, basislist)
  local deg, glist;
  if c1 = ZeroCocycle@ then
    if c2 = ZeroCocycle@ then return;
    else
      deg := NumberArgumentsFunction(c2);
    fi;
  else
    deg := NumberArgumentsFunction(c1);
  fi;

  for glist in basislist do
    if not IsInt(CallFuncList(c1, glist) - CallFuncList(c2, glist)) then
      Error("CheckCochainEqOverSubset fails!");
    fi;
  od;
end);

InstallGlobalFunction(ShortBasisListFromResolution@,
function(brMap, deg)
  local R, n, i, bl, bwl, bw;
  R := brMap!.hapResolution;
  n := Dimension(R)(deg);
  bl := SSortedList([]);
  for i in [1..n] do
    bwl := SptSetMapToBarWord(brMap, deg, i);
    for bw in bwl do
      AddSet(bl, bw{[3..(deg+2)]});
    od;
  od;
  return bl;
end);

InstallGlobalFunction(MapInhomoCochainByGroupHomomorphism@,
function(a, f)
  # a: a cochain in C^n(G); f: H -> G is a group homomorphism.
  if a = ZeroCocycle@ then
    return ZeroCocycle@;
  else
    return function(glist...)
      return CallFuncList(a, List(glist, h -> h^f));
    end;
  fi;
end);

InstallGlobalFunction(InhomoCochainGroupAction@,
function(a, coeff, g)
  # a: a cochain in C^n(G, coeff); g: a group element
  local gAction;
  gAction := coeff!.gAction;

  if a = ZeroCocycle@ then
    return ZeroCocycle@;
  else
    return function(glist...)
      return (g^gAction)[1][1] * CallFuncList(a, List(glist, h -> h^g));
    end;
  fi;
end);