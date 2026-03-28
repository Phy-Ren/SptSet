InstallGlobalFunction(SptSetBockstein,
  function(hapResolution, deg, gAction, v)
    local v2, n, i, dei, bdry, elts, x, vx, _frac_idx, _input_ok;
    _input_ok := ForAll(v, IsInt);
    n := Dimension(hapResolution)(deg+1);
    v2 := [];
    bdry := BoundaryMap(hapResolution);
    elts := hapResolution!.elts;
    for i in [1..n] do
      v2[i] := 0;
      dei := bdry(deg+1, i);
      for x in dei do
        vx := SignInt(x[1]) * (elts[x[2]]^gAction)[1][1] * v[AbsInt(x[1])];
        v2[i] := v2[i] + vx;
      od;
    od;
    if _input_ok then
      _frac_idx := Filtered([1..n], i -> not IsInt(v2[i]));
      if _frac_idx <> [] then
        Print("!! DIAG Bockstein BUG(deg=", deg,
              "): integer input -> FRAC output at indices ",
              _frac_idx, " values=", v2{_frac_idx}, "\n");
      fi;
    fi;
    return v2;
  end);
