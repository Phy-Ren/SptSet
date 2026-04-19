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
    local omega_n3, n3c1n3;
    omega_n3 := Cup0@(2, 3, spectrum[1+1], omega_, n3);
    n3c1n3 := Cup1@(3, 3, spectrum[1+1], n3, n3);
    return AddInhomoCochain@(omega_n3, ScaleInhomoCochain@(1/2, n3c1n3));
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
