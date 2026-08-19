InstallGlobalFunction(FermionSPTSpecSeq,
function(R, auMap, w)
  local brMap, spectrum, ss, s, G, trivialMap, coeffZ, coeffZ2;
  brMap := SptSetBarResolutionMap(R);
  G := GroupOfResolution(R);
  trivialMap := SptSetTrivialGroupAction(G);
  coeffZ := SptSetCoefficientZn(0, trivialMap);
  coeffZ2 := SptSetCoefficientZn(2, trivialMap);
  spectrum := [];
  spectrum[0+1] := SptSetCoefficientU1(auMap);
  spectrum[1+1] := SptSetCoefficientZn(2, auMap);
  spectrum[2+1] := SptSetCoefficientZn(2, auMap);
  spectrum[3+1] := SptSetCoefficientZn(0, auMap);

  ss := SptSetSpecSeqVanilla(R, spectrum);

  s := g -> (1-(g^auMap)[1][1])/2;

  SptSetInstallCoboundary(ss, 2, 0, 1,
  function(n0, dn0)
    return {g1, g2} -> 1/2 * n0() * w(g1, g2);
  end);

  SptSetInstallCoboundary(ss, 2, 1, 1,
  function(n1, dn1)
    if dn1 = ZeroCocycle@ then
      return {g1, g2, g3} -> 1/2 * w(g1, g2) * n1(g3);
    else
      return {g1, g2, g3} -> 1/2 * (w(g1, g2) + dn1(g1, g2)) * n1(g3);
    fi;
  end);
  SptSetInstallCoboundary(ss, 2, 0, 2,
  function(n0, dn0)
    return {g1, g2} -> n0() * w(g1, g2);
  end);
  SptSetInstallCoboundary(ss, 3, 0, 2,
  function(n0, dn0)
    return ZeroCocycle@;
  end);

  SptSetInstallCoboundary(ss, 2, 1, 2,
  function(n1, dn1)
    return {g1, g2, g3} -> (s(g1) * n1(g2) * n1(g3) + w(g1, g2) * n1(g3));
  end);
  SptSetInstallCoboundary(ss, 3, 1, 2,
  function(n1, dn1)
      local dn2;
      dn2 := {g1, g2, g3} -> (s(g1) * n1(g2) * n1(g3) + w(g1, g2) * n1(g3));
      return function(g1, g2, g3, g4)
        local val;
        val := 1/2 * s(g1) * dn2(g2, g3, g4);
        val := val + 1/2 * (w(g1, g2*g3) * dn2(g2, g3, g4));
        val := val + 1/2 * dn2(g1, g2, g3*g4) * dn2(g1*g2, g3, g4);
        val := val - 1/4 * ((dn2(g1, g2, g3) * (1 - dn2(g1, g2, g3*g4))) mod 2);
        return val;
      end;
  end);
  SptSetInstallCoboundary(ss, 2, 2, 1,
  function(n2, dn2)
      local c4, coeff;
      coeff := spectrum[1+1];
      c4 := {g1, g2, g3, g4} -> ((w(g1, g2) + n2(g1, g2)) * n2(g3, g4));
      if dn2 <> ZeroCocycle@ then
        c4 := AddInhomoCochain@(c4, Cup1@(3, 2, coeff, dn2, n2));
      fi;
      return ScaleInhomoCochain@(1/2, c4);
  end);


  SptSetInstallCoboundary(ss, 2, 0, 3,
  function(n0, dn0)
    return {g1, g2} -> (n0() * w(g1, g2));
  end);
  SptSetInstallCoboundary(ss, 3, 0, 3,
  function(n0, dn0)
    local n02, coeff, w1w;
    n02 := Int(n0()/2);
    coeff := ss!.spectrum[1+1];
    w1w := Cup1@(2, 2, coeff, w, w);
    return {g1, g2, g3} -> (n02 * w1w(g1, g2, g3));
  end);
  SptSetInstallCoboundary(ss, 4, 0, 3,
  function(n0, dn0)
    return {g1, g2, g3, g4} -> 0;
    # TODO: fill in the formula: w u w + Dw u1 w?
  end);

  SptSetInstallCoboundary(ss, 2, 1, 3,
  function(n1, dn1)

    if dn1 = ZeroCocycle@ then
      return {g1, g2, g3} -> (w(g1, g2) * n1(g3) + s(g1) * n1(g2) * n1(g3));
    else
      return function(g1, g2, g3)
        local val;
        val := w(g1, g2) * n1(g3);
        val := val + s(g1) * n1(g2) * n1(g3);
        val := val + n1(g1) * dn1(g2, g3);
        # val := val + s(g1) * n1 cup1 dn1;
        return val;
      end;
    fi;
  end);

  SptSetInstallCoboundary(ss, 3, 1, 3,
  function(n1, dn1)
    return {g1, g2, g3, g4} -> 0;
  end);

  SptSetInstallCoboundary(ss, 4, 1, 3,
  function(n1, dn1)
    return {g1, g2, g3, g4, g5} -> 0;
  end);

  # 4+1D p+ip -> Majorana-chain obstruction:
  #   dn2 = 0 on the E_2 page (ordinary Z^T cocycle condition), and
  #   dn3 = n2 cup n2 + omega2 cup n2 + s1 cup (n2 cup_1 n2)  (mod 2).
  SptSetInstallCoboundary(ss, 2, 2, 3,
  function(n2, dn2)
    local n2m, wmod, c4;
    n2m := function(args...)
      return CallFuncList(n2, args) mod 2;
    end;
    wmod := function(args...)
      return CallFuncList(w, args) mod 2;
    end;
    c4 := AddInhomoCochain@(Cup0@(2, 2, coeffZ2, n2m, n2m),
      Cup0@(2, 2, coeffZ2, wmod, n2m));
    c4 := AddInhomoCochain@(c4,
      Cup0@(1, 3, coeffZ2, s, Cup1@(2, 2, coeffZ2, n2m, n2m)));
    return {g1, g2, g3, g4} -> (c4(g1, g2, g3, g4) mod 2);
  end);

  SptSetInstallCoboundary(ss, 2, 2, 2,
  function(n2, dn2)
    return
    function(g1, g2, g3, g4)
      local w2n2, n2n2, n2c1n2;
      # we are ignoring the G-action because Z2 can only have a trivial G-action.
      w2n2 := w(g1, g2) * n2(g3, g4);
      n2n2 := n2(g1, g2) * n2(g3, g4);
      #n2c1n2 := ??;
      #f c1 g (0123) = B[f(023),g(012)]−B[f(013),g(123)]
      #n2 c1 n2(g1, g2, g3) = n2(g1*g2, g3)n2(g1, g2) - n2(g1, g2*g3)n2(g2, g3);
      n2c1n2 := n2(g2*g3, g4) * n2(g2, g3) - n2(g2, g3*g4) * n2(g3, g4);
      # TODO: need to add dn2
      return w2n2 + n2n2 + s(g1) * n2c1n2;
    end;
  end);

  # -- old InstallCoboundary(ss, 3, 2, 2) using o5sym formula + O5gamma@ table --
  # SptSetInstallCoboundary(ss, 3, 2, 2,
  # function(n2, dn2)
  #   return function(g1, g2, g3, g4, g5)
  #     local n2_123, n2_134, n2_125, n2_145,
  #       n2_234, n2_245, n2_235, n2_345,
  #       a4, b4, N2345, L12345, a4t, b4t, o5sym, t5;
  #     n2_123 := n2(g2, g3) mod 2;
  #     n2_134 := n2(g2*g3, g4) mod 2;
  #     n2_125 := n2(g2, g3*g4*g5) mod 2;
  #     n2_145 := n2(g2*g3*g4, g5) mod 2;
  #     n2_234 := n2(g3, g4) mod 2;
  #     n2_245 := n2(g3*g4, g5) mod 2;
  #     n2_235 := n2(g3, g4*g5) mod 2;
  #     n2_345 := n2(g4, g5) mod 2;
  #     a4 := ((n2_123 + w(g2, g3) + s(g2) * n2_235) * n2_345) mod 2;
  #     b4 := (s(g2) * n2_245 * n2_234) mod 2;
  #     N2345 := (n2_234 * n2_235 * n2_245 * n2_345) mod 2;
  #     L12345 := (n2_123 * n2_134 * (1-n2_125) * (1-n2_145)
  #               + n2_134 * n2_145 * (1-n2_123) * (1-n2_125)
  #               + (1-n2_123) * (1-n2_125) * (1-n2_134) * (1-n2_145)) mod 2;
  #     a4t := a4 + N2345 * (1-L12345) * b4;
  #     b4t := b4 + N2345 * (L12345-1) * b4;
  #     o5sym := 1/2 * (s(g1) * a4t + w(g1, g2*g3) * a4t + w(g1, g2) * b4t);
  #     t5 := ExtData@(O5gamma@, s(g1*g2), s(g1), w(g1*g2, g3), w(g1, g2*g3), w(g1, g2),
  #       n2(g1, g2), n2(g1, g2*g3), n2(g1, g2*g3*g4), n2(g1, g2*g3*g4*g5),
  #       n2(g1*g2, g3), n2(g1*g2, g3*g4), n2(g1*g2, g3*g4*g5),
  #       n2(g1*g2*g3, g4), n2(g1*g2*g3, g4*g5), n2(g1*g2*g3*g4, g5));
  #     return o5sym + t5;
  #   end;
  # end);

  # xingyu 2026 0319: direct C++ classification_Majorana table lookup
  # replaces o5sym formula + O5gamma@ with unified O5gamma_xingyu@ table
  # bit order follows C++ exactly: s1[1] s1[0] omega2[2..0] n2[9..0]
  SptSetInstallCoboundary(ss, 3, 2, 2,
  function(n2, dn2)
    return function(g1, g2, g3, g4, g5)
      return ExtData@(O5gamma_xingyu@,
        s(g1*g2), s(g1),
        w(g1*g2, g3), w(g1, g2*g3), w(g1, g2),
        n2(g1*g2*g3*g4, g5), n2(g1*g2*g3, g4*g5), n2(g1*g2*g3, g4),
        n2(g1*g2, g3*g4*g5), n2(g1*g2, g3*g4), n2(g1*g2, g3),
        n2(g1, g2*g3*g4*g5), n2(g1, g2*g3*g4), n2(g1, g2*g3), n2(g1, g2));
    end;
  end);

  # 4+1D Majorana-chain -> complex-fermion obstruction:
  #   dn4 = n3 cup_1 n3 + omega2 cup n3 + s1 cup (n3 cup_2 n3)  (mod 2).
  # This is the d_2 differential out of E^{3,2}; it is the direct
  # one-dimension-up analogue of InstallCoboundary(ss, 2, 2, 2).
  SptSetInstallCoboundary(ss, 2, 3, 2,
  function(n3, dn3)
    local coeff, c5;
    coeff := spectrum[1+1];
    c5 := AddInhomoCochain@(Cup1@(3, 3, coeff, n3, n3),
      Cup0@(2, 3, coeff, w, n3));
    c5 := AddInhomoCochain@(c5,
      Cup0@(1, 4, coeff, s, Cup2@(3, 3, coeff, n3, n3)));
    return {g1, g2, g3, g4, g5} -> (c5(g1, g2, g3, g4, g5) mod 2);
  end);

  # 4+1D pure Majorana phase O^gamma_6 from the Cartan-Adem representative.
  # This replaces the numerical O6 table.  The n4-dependent complex-fermion
  # terms are installed separately in InstallCoboundary(ss, 2, 4, 1), so this
  # d_3 contains only the n3-, omega2-, and s1-dependent part of Eq. (126).
  #
  # DOMAIN: n3 must be a Z2 cocycle (dn3 = 0 mod 2).  In the spectral
  # sequence this holds on the E_3 source E_3^{3,2} because the d_2
  # obstruction (dn4 = n3 cup1 n3 + ...) has already been killed.  Do not
  # evaluate this formula on a total-cochain trivialization where dn3 may
  # contain d_2(n2) contributions — the Bockstein beta n3 = d(tilde n3)/2
  # would then be half-integer valued and the formula is no longer valid.
  SptSetInstallCoboundary(ss, 3, 3, 2,
  function(n3, dn3)
    local n3m, wmod, smod, beta, betam,
          zeta23, x6, n3c1n3, omegaN3, sBeta, zeta14,
          omegaCup1s, s2, s3, half6,
          quarterOmegaBeta, quarterBetaBeta, quarterS2Beta, quarterS3N3,
          n3v, dn3v;

    n3m := function(args...)
      return CallFuncList(n3, args) mod 2;
    end;

    # Canonical cocycle representative (two steps).
    # 1) coordinate-level cocycle correction: the machinery may pass a wild
    #    representative whose coboundary is nonzero even on the bar basis;
    #    its coordinate vector then lies in im(d_1) (the class survives to
    #    E_3), so subtract the d_1-preimage to get a genuine cocycle class;
    # 2) round-trip through the bar resolution to get an honest equivariant
    #    cocycle function of that class, so beta = d(tilde n3)/2 below is
    #    integral (otherwise ModRat crash).
    n3v := SptSetMapFromBarCocycle(brMap, 3, spectrum[3], n3m);
    dn3v := SptSetMapFromBarCocycle(brMap, 4, spectrum[3],
      function(args...) return CallFuncList(dn3, args) mod 2; end);
    if not ForAll(dn3v, x -> IsZero(x mod 2)) then
      n3v := n3v - SptSetZLMapInverse(SptSetSpecSeqDerivative(ss, 1, 3, 2), dn3v);
    fi;
    n3m := SptSetMapToBarCocycle(brMap, 3, spectrum[3], n3v);

    wmod := function(args...)
      return CallFuncList(w, args) mod 2;
    end;
    smod := function(g)
      return s(g) mod 2;
    end;

    # Integral Bockstein beta n3 = d(tilde n3)/2, using the canonical 0/1 lift.
    beta := ScaleInhomoCochain@(1/2, InhomoCoboundary@(coeffZ, n3m));
    betam := function(args...)
      return CallFuncList(beta, args) mod 2;
    end;

    # zeta_{2,3}(omega2,n3) = <12313434>(omega2,omega2,n3,n3).
    zeta23 := SurjectionProductZ2@([2, 2, 3, 3],
      [wmod, wmod, n3m, n3m], [1, 2, 3, 1, 3, 4, 3, 4]);

    # x(n3), the four-word Adem primitive from the notes.
    x6 := SurjectionProductZ2@([3, 3, 3, 3],
      [n3m, n3m, n3m, n3m], [1, 2, 1, 3, 2, 4, 3, 1, 4, 2]);
    x6 := AddInhomoCochain@(x6, SurjectionProductZ2@([3, 3, 3, 3],
      [n3m, n3m, n3m, n3m], [1, 2, 1, 3, 4, 3, 1, 4, 1, 2]));
    x6 := AddInhomoCochain@(x6, SurjectionProductZ2@([3, 3, 3, 3],
      [n3m, n3m, n3m, n3m], [1, 2, 3, 2, 4, 3, 1, 4, 2, 1]));
    x6 := AddInhomoCochain@(x6, SurjectionProductZ2@([3, 3, 3, 3],
      [n3m, n3m, n3m, n3m], [1, 2, 3, 4, 3, 1, 4, 2, 1, 2]));

    n3c1n3 := Cup1@(3, 3, coeffZ2, n3m, n3m);
    omegaN3 := Cup0@(2, 3, coeffZ2, wmod, n3m);
    sBeta := Cup0@(1, 4, coeffZ2, smod, betam);

    zeta14 := SurjectionProductZ2@([1, 1, 4, 4],
      [smod, smod, betam, betam], [1, 2, 3, 2, 4, 3, 4, 3]);
    omegaCup1s := Cup1@(2, 1, coeffZ2, wmod, smod);

    half6 := AddInhomoCochain@(zeta23, x6);
    half6 := AddInhomoCochain@(half6, Cup4@(5, 5, coeffZ2, n3c1n3, omegaN3));
    half6 := AddInhomoCochain@(half6, Cup4@(5, 5, coeffZ2, n3c1n3, sBeta));
    half6 := AddInhomoCochain@(half6, Cup4@(5, 5, coeffZ2, omegaN3, sBeta));
    half6 := AddInhomoCochain@(half6, zeta14);
    half6 := AddInhomoCochain@(half6, Cup0@(2, 4, coeffZ2, omegaCup1s, betam));
    # The extra 1/2 s1 cup (n3 cup_1 n3) term is half-valued and reduced mod 2.
    half6 := AddInhomoCochain@(half6, Cup0@(1, 5, coeffZ2, smod, n3c1n3));

    quarterOmegaBeta := Cup0@(2, 4, coeffZ, wmod, beta);
    quarterBetaBeta := Cup2@(4, 4, coeffZ, beta, beta);
    s2 := Cup0@(1, 1, coeffZ2, smod, smod);
    s3 := Cup0@(2, 1, coeffZ2, s2, smod);
    quarterS2Beta := Cup0@(2, 4, coeffZ2, s2, betam);
    quarterS3N3 := Cup0@(3, 3, coeffZ2, s3, n3m);

    return function(g1, g2, g3, g4, g5, g6)
      return 1/2 * (half6(g1, g2, g3, g4, g5, g6) mod 2)
        + 1/4 * (quarterOmegaBeta(g1, g2, g3, g4, g5, g6)
          - quarterBetaBeta(g1, g2, g3, g4, g5, g6)
          + (quarterS2Beta(g1, g2, g3, g4, g5, g6) mod 2)
          + (quarterS3N3(g1, g2, g3, g4, g5, g6) mod 2));
    end;
  end);

  # xingyu 2026 0314: translated from C++ classification_others()
  # in 260310 Consistency Check.cpp lines 204-216
  # replaces Cup0/Cup1/Cup2 and addTwister(5,0) Cup3 with direct Z2 expansion
  # O5c = w cup0 n3 + n3 cup1 n3 + dn3 cup2 n3
  # O5cgamma = dn3 cup3 dn3  (was generated by addTwister(5,0), now included here)
  SptSetInstallCoboundary(ss, 2, 3, 1, function(n3, dn3)
    return function(g1, g2, g3, g4, g5)
      local phase;
      # O5c: w cup0 n3
      phase := w(g1, g2) * n3(g3, g4, g5);
      # O5c: n3 cup1 n3
      phase := phase
             + n3(g1*g2*g3, g4, g5) * n3(g1, g2, g3)
             + n3(g1, g2*g3*g4, g5) * n3(g2, g3, g4)
             + n3(g1, g2, g3*g4*g5) * n3(g3, g4, g5);
      if dn3 <> ZeroCocycle@ then
        # O5c: dn3 cup2 n3
        phase := phase
               + dn3(g1, g2, g3, g4) * n3(g1, g2*g3*g4, g5)
               + dn3(g1*g2, g3, g4, g5) * n3(g1, g2, g3*g4*g5)
               + dn3(g1, g2, g3, g4) * n3(g2, g3*g4, g5)
               + dn3(g1, g2*g3, g4, g5) * n3(g2, g3, g4*g5)
               + dn3(g1, g2, g3, g4) * n3(g3, g4, g5)
               + dn3(g1, g2, g3*g4, g5) * n3(g3, g4, g5);
        # O5cgamma: dn3 cup3 dn3
        phase := phase
               + dn3(g1, g2, g3*g4, g5) * dn3(g1, g2, g3, g4)
               + dn3(g1, g2, g3, g4*g5) * dn3(g1, g2*g3, g4, g5)
               + dn3(g1*g2, g3, g4, g5) * dn3(g1, g2, g3, g4)
               + dn3(g1*g2, g3, g4, g5) * dn3(g1, g2, g3*g4, g5)
               + dn3(g1, g2, g3, g4*g5) * dn3(g2, g3, g4, g5)
               + dn3(g1, g2*g3, g4, g5) * dn3(g2, g3, g4, g5);
      fi;
      return 1/2 * (phase mod 2);
    end;

    # -- old code using Cup products --
    # local c5, coeff;
    # coeff := spectrum[1+1];
    # c5 := AddInhomoCochain@(Cup0@(2, 3, coeff, w, n3), Cup1@(3, 3, coeff, n3, n3));
    # if dn3 <> ZeroCocycle@ then
    #   c5 := AddInhomoCochain@(c5, Cup2@(4, 3, coeff, dn3, n3));
    # fi;
    # return ScaleInhomoCochain@(1/2, c5);
  end);

  # 4+1D complex-fermion contribution to the bosonic obstruction:
  #   O^c_6 = 1/2[ omega2 cup n4 + n4 cup_2 n4 + dn4 cup_3 n4 ],
  #   O^{c gamma}_6 = 1/2[ dn4 cup_4 dn4 ].
  SptSetInstallCoboundary(ss, 2, 4, 1,
  function(n4, dn4)
    local coeff, c6;
    coeff := spectrum[1+1];
    c6 := AddInhomoCochain@(Cup0@(2, 4, coeff, w, n4),
      Cup2@(4, 4, coeff, n4, n4));
    if dn4 <> ZeroCocycle@ then
      c6 := AddInhomoCochain@(c6, Cup3@(5, 4, coeff, dn4, n4));
      c6 := AddInhomoCochain@(c6, Cup4@(5, 5, coeff, dn4, dn4));
    fi;
    return {g1, g2, g3, g4, g5, g6} ->
      (1/2 * (c6(g1, g2, g3, g4, g5, g6) mod 2));
  end);

  SptSetInstallAddTwister(ss, 1, 1, {l1, l2} -> ZeroCocycle@);
    
  SptSetInstallAddTwister(ss, 2, 0,
    function(l1, l2)
      local n11, n12;
      n11 := l1[1+1];
      n12 := l2[1+1];
      return {g1, g2} -> 1/2 * n11(g1) * n12(g2);
    end);

  SptSetInstallAddTwister(ss, 1, 2,
      function(l1, l2)
          return ZeroCocycle@;
      end);

  SptSetInstallAddTwister(ss, 2, 1,
  function(l1, l2)
    local n11, n12, coeff;
    n11 := l1[1+1];
    n12 := l2[1+1];
    coeff := spectrum[1+1];
    if n11 = ZeroCocycle@ or n12 = ZeroCocycle@ then
      return ZeroCocycle@;
    fi;
    return {g1, g2} -> (n11(g1) * n12(g2) + s(g1) * n11(g2) * n12(g2));
  end);

  SptSetInstallAddTwister
    (ss, 3, 0, 
    function(l1, l2)
      local coeff, n11, n12, n21, n22, c3, t3, dn21, dn22, m2, N2;

      n11 := l1[1+1];
      n12 := l2[1+1];
      n21 := l1[2+1];
      n22 := l2[2+1];
      coeff := spectrum[0+1];

      dn21 := {g1, g2, g3} -> (s(g1) * n11(g2) * n11(g3) + w(g1, g2) * n11(g3));
      dn22 := {g1, g2, g3} -> (s(g1) * n12(g2) * n12(g3) + w(g1, g2) * n12(g3));
      m2 := {g1, g2} -> (n11(g1) * n12(g2) + s(g1) * n11(g2) * n12(g2));
      N2 := {g1, g2} -> (n21(g1, g2) + n22(g1, g2) + m2(g1, g2));

      # c3 := AddInhomoCochain@(Cup1@(2, 2, coeff, n22, n21), Cup2@(3, 2, coeff, dn22, n21));
      # c3 := AddInhomoCochain@(c3, Cup1@(2, 2, coeff, N2, m2));
      # c3 := AddInhomoCochain@(c3, Cup0@(1, 2, coeff, s, m2));
      # if n11 <> n12 and n21 <> n22 then
      #   c3 := AddInhomoCochain@(c3, Cup2@(3, 2, coeff,
      #     {g1, g2, g3} -> (s(g1) * (n11(g2)*n12(g3)-n12(g2)*n11(g3))),
      #     {g1, g2} -> (n21(g1, g2) + n22(g1, g2))));
      # fi;

      c3 := AddInhomoCochain@(Cup1@(2, 2, coeff, n22, n21), Cup2@(3, 2, coeff, dn22, n21));
      c3 := AddInhomoCochain@(c3, Cup2@(2, 3, coeff, n22, dn21));
      c3 := AddInhomoCochain@(c3, Cup2@(2, 3, coeff, n21, dn22));
      c3 := AddInhomoCochain@(c3, Cup1@(2, 2, coeff, m2, N2));
      c3 := AddInhomoCochain@(c3, Cup2@(2, 3, coeff, m2, InhomoCoboundary@(coeff, N2)));
      c3 := AddInhomoCochain@(c3, Cup2@(3, 2, coeff, AddInhomoCochain@(dn21, dn22), m2));

      t3 := function(g1, g2, g3)
        local g03;
        g03 := g1*g2*g3;
        return ExtData@(AddTwister2DTable@,
          n11(g1), n11(g03), n11(g2),
          n12(g1), n12(g03), n12(g2),
          w(g1, g2), s(g1), s(g2));
      end;

      return {g1, g2, g3} -> (1/2*c3(g1, g2, g3) + t3(g1, g2, g3));
    end);

    # place holders for twisters in (3+1)D
    SptSetInstallAddTwister(ss, 1, 3, {l1, l2} -> ZeroCocycle@);
    SptSetInstallAddTwister(ss, 2, 2, {l1, l2} -> ZeroCocycle@);
    SptSetInstallAddTwister(ss, 3, 1, function(l1, l2)
      local coeff, n21, n22, m3a, m3b;

      coeff := spectrum[1+1];
      n21 := l1[2+1];
      n22 := l2[2+1];

      m3a := Cup1@(2, 2, coeff, n21, n22);
      m3b := Cup0@(1, 2, coeff, s, Cup2@(2, 2, coeff, n21, n22));

      return AddInhomoCochain@(m3a, m3b);
    end);

    SptSetInstallAddTwister(ss, 4, 0,
    function(l1, l2)
      local coeff, n21, n31, n22, n32, dn31, dn32, m3, N3, dm3, dN3, e4c, e4cg, t4;

      # Assert(0, l1[2+1] = ZeroCocycle@ or l2[2+1] = ZeroCocycle@);
      # Assert(0, l1[1+1] = ZeroCocycle@ or l2[1+1] = ZeroCocycle@);

      coeff := spectrum[1+1];
      n21 := l1[2+1];
      n31 := l1[3+1];
      n22 := l2[2+1];
      n32 := l2[3+1];
      dn31 := AddInhomoCochain@(Cup0@(2, 2, coeff, n21, n21),
        Cup0@(1, 3, coeff, s, Cup1@(2, 2, coeff, n21, n21)));
      dn31 := AddInhomoCochain@(dn31, Cup0@(2, 2, coeff, w, n21));
      dn32 := AddInhomoCochain@(Cup0@(2, 2, coeff, n22, n22),
        Cup0@(1, 3, coeff, s, Cup1@(2, 2, coeff, n22, n22)));
      dn32 := AddInhomoCochain@(dn32, Cup0@(2, 2, coeff, w, n22));
      m3 := AddInhomoCochain@(Cup1@(2, 2, coeff, n21, n22),
        Cup0@(1, 2, coeff, s, Cup2@(2, 2, coeff, n21, n22)));
      dm3 := InhomoCoboundary@(coeff, m3);
      N3 := {g1, g2, g3} -> (n31(g1, g2, g3) + n32(g1, g2, g3) + m3(g1, g2, g3));
      dN3 := {g1, g2, g3, g4} -> (dn31(g1, g2, g3, g4) + dn32(g1, g2, g3, g4)
        + dm3(g1, g2, g3, g4));
      # -- old Cup product formula (commented out) --
      # e4c := Cup2@(3, 3, coeff, m3, N3);
      # e4c := AddInhomoCochain@(e4c, Cup2@(3, 3, coeff, n31, n32));
      # e4c := AddInhomoCochain@(e4c, Cup3@(3, 4, coeff, n31, dn32));
      #
      # e4cg := Cup3@(3, 4, coeff, m3, AddInhomoCochain@(dn31, dn32));
      # # e4cg := AddInhomoCochain@(e4cg, Cup4@(3, 3, coeff, dn31, dn32));
      # e4cg := AddInhomoCochain@(e4cg, {g1, g2, g3, g4} ->
      #   (dn31(g1, g2, g3, g4) * dn32(g1, g2, g3, g4)));
      # e4cg := AddInhomoCochain@(e4cg, Cup3@(4, 3, coeff, dN3, m3));
      # e4cg := AddInhomoCochain@(e4cg, Cup2@(3, 3, coeff, m3, m3));
      # e4cg := AddInhomoCochain@(e4cg, dm3);

      t4 := {g1, g2, g3, g4} -> ExtData@(AddTwister3DTable@,
        s(g1*g2), s(g1), w(g1, g2), n22(g1*g2*g3, g4), n22(g1*g2, g3*g4), n22(g1*g2, g3),
        n22(g1, g2*g3*g4), n22(g1, g2*g3), n22(g1, g2),
        n21(g1*g2*g3, g4), n21(g1*g2, g3*g4), n21(g1*g2, g3),
        n21(g1, g2*g3*g4), n21(g1, g2*g3), n21(g1, g2));

      # xingyu 2026 0312: translated from C++ stacking_others()
      # in 260310 Consistency Check.cpp lines 191-202
      # replaces 1/2*(e4c + e4cg) with direct Z2 expansion
      return {g1, g2, g3, g4} -> (
        1/2 * ((
          (m3(g1*g2,g3,g4) + m3(g1,g2,g3*g4) + dn32(g1,g2,g3,g4)) * dn31(g1,g2,g3,g4)
          + (m3(g1*g2,g3,g4) + m3(g1,g2,g3*g4)) * (m3(g1,g2,g3*g4) + dn32(g1,g2,g3,g4))
          + m3(g1*g2,g3,g4)
          + (dN3(g1,g2,g3,g4) + m3(g1,g2,g3) + m3(g1,g2*g3,g4) + 1) * m3(g2,g3,g4)
          + (dN3(g1,g2,g3,g4) + m3(g1,g2,g3) + 1) * m3(g1,g2*g3,g4)
          + (dN3(g1,g2,g3,g4) + 1) * m3(g1,g2,g3)
          + n32(g1,g2,g3*g4) * n31(g1,g2,g3*g4)
          + N3(g1,g2,g3) * (N3(g1,g2*g3,g4) + N3(g2,g3,g4))
          + n32(g1*g2,g3,g4) * (n31(g1*g2,g3,g4) + N3(g1,g2,g3*g4) + n31(g1,g2,g3*g4))
          + N3(g1,g2*g3,g4) * (N3(g2,g3,g4) + n32(g1,g2,g3) + n31(g1,g2,g3))
          + n31(g1,g2,g3*g4) * (n32(g1,g2,g3) + n32(g1,g2*g3,g4) + n32(g2,g3,g4))
          + N3(g2,g3,g4) * (n32(g1,g2,g3) + n31(g1,g2,g3) + n32(g1,g2*g3,g4) + n31(g1,g2*g3,g4))
          + n31(g1*g2,g3,g4) * (N3(g1,g2,g3*g4) + n32(g1,g2,g3) + n32(g1,g2*g3,g4) + n32(g2,g3,g4))
          + N3(g1*g2,g3,g4) * N3(g1,g2,g3*g4)
          + n31(g1,g2,g3) * (n32(g1,g2*g3,g4) + n32(g2,g3,g4))
          + n32(g2,g3,g4) * n31(g1,g2*g3,g4)
        ) mod 2)
        + t4(g1, g2, g3, g4));
    end);

    # place holders for twisters in (4+1)D
    SptSetInstallAddTwister(ss, 1, 4, {l1, l2} -> ZeroCocycle@);
    SptSetInstallAddTwister(ss, 2, 3, {l1, l2} -> ZeroCocycle@);
    # 4+1D Majorana stacking: N3 = n3 + n3'.  There is no m3 correction.
    SptSetInstallAddTwister(ss, 3, 2, {l1, l2} -> ZeroCocycle@);
    SptSetInstallAddTwister(ss, 4, 1, {l1, l2} -> ZeroCocycle@);
    # xingyu 2026 0314: O5cgamma now included in InstallCoboundary(ss, 2, 3, 1, ...)
    # SptSetInstallAddTwister(ss, 5, 0,
    # function(l1, l2)
    #   local coeff, n41, n42;
    #   coeff := spectrum[1+1];
    #   n41 := l1[4+1];
    #   n42 := l2[4+1];
    #   return ScaleInhomoCochain@(1/2, Cup3@(4, 4, coeff, n41, n42));
    # end);
    SptSetInstallAddTwister(ss, 5, 0, {l1, l2} -> ZeroCocycle@);
    

  return ss;
end);


InstallGlobalFunction(FermionSPTSpecSeqNoPip,
function(R, auMap, w)
  # Build the ordinary fermionic spectral sequence but remove the q=3 p+ip
  # layer.  This gives the no-p+ip triplet (n3,n4,nu5) used for the 4+1D
  # classification implemented here, rather than quotienting by p+ip data.
  local ss;
  ss := FermionSPTSpecSeq(R, auMap, w);
  if IsBound(ss!.spectrum[4]) then
    Unbind(ss!.spectrum[4]);
  fi;
  return ss;
end);
