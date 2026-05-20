InstallMethod(InsulatorSPTSpecSeq,
"build topological-insulator SPT spectral sequence",
[IsHapResolution, IsGeneralMapping, IsGeneralMapping, IsFunction],
function(R, auMap, u1cMap, omega_)
  local brMap, spectrum, G, trivialMap, au_u1cMap, ss, s;
  brMap := SptSetBarResolutionMap(R);

  G := GroupOfResolution(R);
  trivialMap := SptSetTrivialGroupAction(G);

  au_u1cMap := GroupHomomorphismByFunction(G, GL(1, Integers), {g} -> auMap(g)*u1cMap(g));
  spectrum := [];
  spectrum[0+1] := SptSetCoefficientU1(auMap);
  spectrum[1+1] := SptSetCoefficientZn(0, u1cMap);
  # spectrum[2+1] is 0;
  spectrum[3+1] := SptSetCoefficientZn(0, auMap);
  ss := SptSetSpecSeqVanilla(R, spectrum);

  s := g -> (1-(g^auMap)[1][1])/2;

  SptSetInstallCoboundary(ss, 2, 1, 1,
  function(n1, dn1)
    if dn1 = ZeroCocycle@ then
      return {g1, g2, g3} -> omega_(g1, g2) * n1(g3);
    else
      return {g1, g2, g3} -> omega_(g1, g2) * n1(g3)
        + 1/2 * dn1(g1, g2) * n1(g3);
    fi;
  end);

  SptSetInstallCoboundary(ss, 2, 2, 1,
  function(n2, dn2)
    return {g1, g2, g3, g4}
    -> omega_(g1, g2) * n2(g3, g4) + 1/2 * n2(g1, g2) * n2(g3, g4);
  end);

  # [xingyu 2026-04-19] d_2^{3,1}: omega_2 cup n_3 + 1/2 n_3 cup_1 n_3
  # source: n_3 in C^3(G, Z_sigma_C) at (p,q)=(3,1)
  # target: C^5(G, U(1)_sigma_T) at (p,q)=(5,0); needed in 3+1D
  SptSetInstallCoboundary(ss, 2, 3, 1,
  function(n3, dn3)
    local omega_n3, n3c1n3, _result, _sample_vals, _i, _brMap, _bw, _j, _v;
    omega_n3 := Cup0@(2, 3, spectrum[1+1], omega_, n3);
    n3c1n3 := Cup1@(3, 3, spectrum[1+1], n3, n3);
    _result := AddInhomoCochain@(omega_n3, ScaleInhomoCochain@(1/2, n3c1n3));
    # DIAG: sample cup1 values and the 1/2-scaled result on bar basis
    _brMap := ss!.brMap;;
    _sample_vals := [];;
    for _i in [1..Minimum(10, Dimension(_brMap!.hapResolution)(5))] do
      _bw := SptSetMapToBarWord(_brMap, 5, _i);;
      _v := 0;;
      for _j in [1..Length(_bw)] do
        _v := _v + _bw[_j][1] * (_bw[_j][2]^(spectrum[0+1]!.gAction))[1][1]
          * CallFuncList(n3c1n3, _bw[_j]{[3..7]});
      od;
      Add(_sample_vals, _v);
    od;
    Print("    DIAG d2(3,1): cup1 sample (first 10 bar)=", _sample_vals,
          " anyOdd=", ForAny(_sample_vals, x->x mod 2 <> 0), "\n");
    return _result;
  end);

  # [xingyu 2026-04-19] d_2^{4,1}: omega_2 cup n_4 + 1/2 n_4 cup_2 n_4
  # source: n_4 in C^4(G, Z_sigma_C) at (p,q)=(4,1)
  # target: C^6(G, U(1)_sigma_T) at (p,q)=(6,0); needed in 4+1D
  # 与 d_2^{2,1}, d_2^{3,1} 同族: d_2^{p,1} = omega cup_0 n_p + 1/2 n_p cup_{p-2} n_p
  SptSetInstallCoboundary(ss, 2, 4, 1,
  function(n4, dn4)
    local omega_n4, n4c2n4;
    omega_n4 := Cup0@(2, 4, spectrum[1+1], omega_, n4);
    n4c2n4 := Cup2@(4, 4, spectrum[1+1], n4, n4);
    return AddInhomoCochain@(omega_n4, ScaleInhomoCochain@(1/2, n4c2n4));
  end);

  SptSetInstallAddTwister(ss, 1, 1, {l1, l2} -> ZeroCocycle@);

  # [xingyu 2026-04-19] d_3^{0,3}: beta(omega_2) cup n_0
  # source: n_0 in C^0(G, Z_sigma_T) at (p,q)=(0,3) -- the p+ip root datum
  # target: C^3(G, Z_sigma_C) at (p,q)=(3,1); n_0 used as-is (no halving)
  SptSetInstallCoboundary(ss, 3, 0, 3,
  function(n0, dn0)
    local coeff_omega_, beta_omega_;
    coeff_omega_ := SptSetCoefficientZn(0, au_u1cMap);
    beta_omega_ := InhomoCoboundary@(coeff_omega_, omega_);
    return Cup0@(3, 0, spectrum[3+1], beta_omega_, n0);
  end);

  SptSetInstallCoboundary(ss, 2, 1, 3,
  function(n1, dn1)
    return ZeroCocycle@;
  end);

  SptSetInstallCoboundary(ss, 3, 1, 3,
  function(n1, dn1)
    local coeff_omega_, coeff_s, beta_omega_, beta_s;
    coeff_omega_ := SptSetCoefficientZn(0, au_u1cMap);
    coeff_s := SptSetCoefficientZn(2, trivialMap);
    beta_omega_ := InhomoCoboundary@(coeff_omega_, omega_);
    beta_s := ScaleInhomoCochain@(1/2, InhomoCoboundary@(coeff_s, s));
    return AddInhomoCochain@(Cup0@(3, 1, spectrum[3+1], beta_omega_, n1),
      Cup0@(3, 1, spectrum[3+1], Cup0@(2, 1, spectrum[3+1], beta_s, n1), n1));
  end);
    
  SptSetInstallAddTwister(ss, 2, 0,
    function(l1, l2)
      local n11, n12;
      n11 := l1[1+1];
      n12 := l2[1+1];
      return {g1, g2} -> 1/2 * n11(g1) * n12(g2);
    end);

  SptSetInstallAddTwister(ss, 1, 2, {l1, l2} -> ZeroCocycle@);
  SptSetInstallAddTwister(ss, 2, 1, {l1, l2} -> ZeroCocycle@);

  # place holders for twisters in (3+1)D
  SptSetInstallAddTwister(ss, 1, 3, {l1, l2} -> ZeroCocycle@);
  SptSetInstallAddTwister(ss, 2, 2, {l1, l2} -> ZeroCocycle@);
  SptSetInstallAddTwister(ss, 3, 1, {l1, l2} -> ZeroCocycle@);

  # [xingyu 2026-04-19] twister(4,0): 1/2 n_3^(1) cup_2 n_3^(2)
  # n_3 lives in q=1 layer, p=3 slot in total degree 4 (so l[3+1])
  # coeff = spectrum[0+1] (target U(1)_sigma_T), aligned with twister(3,0)
  SptSetInstallAddTwister(ss, 4, 0,
  function(l1, l2)
    local coeff, n31, n32;
    n31 := l1[3+1];
    n32 := l2[3+1];
    coeff := spectrum[0+1];

    if n31 = ZeroCocycle@ or n32 = ZeroCocycle@ then
      return ZeroCocycle@;
    else
      return ScaleInhomoCochain@(1/2, Cup2@(3, 3, coeff, n31, n32));
    fi;
  end);

  SptSetInstallAddTwister(ss, 3, 0,
  function(l1, l2)
    local coeff, n21, n22, n2c1n2;
    n21 := l1[2+1];
    n22 := l2[2+1];
    coeff := spectrum[0+1];

    if n21 = ZeroCocycle@ or n22 = ZeroCocycle@ then
      return ZeroCocycle@;
    else
      n2c1n2 :=  Cup1@(2, 2, coeff, n21, n22);
      return ScaleInhomoCochain@(1/2, n2c1n2);
    fi;
  end);

  # [xingyu 2026-04-19] (p+q)=5 zero placeholders for PartialPurifyCoboundary
  # stacking on intermediate deg+1=5 cochains in 3+1D Phase B (mirrors the
  # ss_fermion_ez.gi:387..401 strategy). 物理上 SPT 只到 4D, 这些是技术性补丁,
  # 缺它们 StackInplace 在 deg=5 cochain 上会 access addTwister[?][5] 越界.
  SptSetInstallAddTwister(ss, 1, 4, {l1, l2} -> ZeroCocycle@);
  SptSetInstallAddTwister(ss, 2, 3, {l1, l2} -> ZeroCocycle@);
  SptSetInstallAddTwister(ss, 3, 2, {l1, l2} -> ZeroCocycle@);
  SptSetInstallAddTwister(ss, 4, 1, {l1, l2} -> ZeroCocycle@);

  # [xingyu 2026-04-19] twister(5,0): 1/2 n_4^(1) cup_3 n_4^(2)
  # n_4 lives in q=1 layer, p=4 slot in total degree 5 (so l[4+1])
  # 与 T_{2,0}/T_{3,0}/T_{4,0} 同族: T_{p,0} = 1/2 n_{p-1}^(1) cup_{p-2} n_{p-1}^(2)
  # coeff = spectrum[0+1] (target U(1)_sigma_T), 与同族其他 twister 风格一致
  SptSetInstallAddTwister(ss, 5, 0,
  function(l1, l2)
    local coeff, n41, n42;
    n41 := l1[4+1];
    n42 := l2[4+1];
    coeff := spectrum[0+1];

    if n41 = ZeroCocycle@ or n42 = ZeroCocycle@ then
      return ZeroCocycle@;
    else
      return ScaleInhomoCochain@(1/2, Cup3@(4, 4, coeff, n41, n42));
    fi;
  end);

  # [xingyu 2026-04-19] (p+q)=6 zero placeholders for d_2^{4,1} 引发的
  # deg=6 intermediate cochain stacking. d_2^{4,1} target 落在 (p,q)=(6,0),
  # 故 PartialPurify 在 4+1D Phase B 的 stacking chain 中会访问 addTwister[?][6].
  # 3+1D Phase B 不会触发 (验证: PurifyCoboundary 只调 deg-1=4 上的 SpecSeqCoboundarySL,
  # 而 d_2^{4,1} source (4,1) 需要 input deg=5, 不在 3+1D Phase B 链上).
  # 真实 4+1D 公式 (T_{6,0} = 1/2 n_5 cup_4 n_5 等) 按需后续填.
  SptSetInstallAddTwister(ss, 1, 5, {l1, l2} -> ZeroCocycle@);
  SptSetInstallAddTwister(ss, 2, 4, {l1, l2} -> ZeroCocycle@);
  SptSetInstallAddTwister(ss, 3, 3, {l1, l2} -> ZeroCocycle@);
  SptSetInstallAddTwister(ss, 4, 2, {l1, l2} -> ZeroCocycle@);
  SptSetInstallAddTwister(ss, 5, 1, {l1, l2} -> ZeroCocycle@);
  SptSetInstallAddTwister(ss, 6, 0, {l1, l2} -> ZeroCocycle@);

  return ss;
end);

InstallGlobalFunction(InsulatorSPTLayersVerbose,
function(ss, dim)
  local layerNames, p, q, rmax, r, Erpq;
  layerNames := ["Bosonic:", "Complex fermion:", "Empty:", "p+ip:"];
  for p in [1..(dim+1)] do
    q := dim + 1 - p;
    if q >= 0 and q <= 3 then
      Display(layerNames[q+1]);
      rmax := Maximum(q+2, p+1);
      for r in [2..rmax] do
        Erpq := SptSetSpecSeqComponent(ss, r, p, q);
        SptSetFpZModuleCanonicalForm(Erpq);
        Display(Erpq);
      od;
    fi;
  od;
end);
