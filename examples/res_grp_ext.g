BindGlobal("ResolutionCTCWall", function(fGN, RQ, RN)
    local G, N, Q, nMax, partitionSum, dimension, bdryK, bdryKWord;
    N := GroupOfResolution(RN);
    Q := GroupOfResolution(RQ);
    G := PreImage(fGN);

    nMax := Minimum(Length(RQ), Length(RN));
    partitionSum := [];
    for nn in 0:nMax do
        partitionSum[nn+1] := [Dimension(RN)(0)*Dimension(RQ)(nn)];
        for pp in 1:nn do
            partitionSum[nn+1][pp+1] := partitionSum[nn+1][pp] + Dimension(RN)(pp)*Dimension(RQ)(nn-pp);
        od;
    od;

    dimension := function(n)
        return partitionSum[n+1][n+1];
    end;

    bdryRN := BoundaryMap(RN);
    bdryRQ := BoundaryMap(RQ);

    # tensor word: [ [coeff, g_idx, p, q, ip, iq] ]

    # freeWord2tensorWord := function()

    RNWord2tensorWord := function(n, w)
        local x, tw;
        tw := [];
        for x in w do
            n := SignInt(x[1]);
            gid := AbsInt(x[1]);
            eid := x[2];
            pqid := idx2part(n, eid);
            
        od;
    end;

    bdryK := function(k, p, q, ip, iq)
        local i, w, v1, v, x;
    
        if k = 0 then
            return RNWord2tensorWord(bdryRN(p, iq));
        fi;

        # most general case
        w := [];
        for i in [0:k-1] do
            v1 := bdryComponent(i, p, q, ip, iq);
            v := [];
            for x in v1 do
                v := AddFreeWords(v, bdryComponent(k-i, p-i+1, q+i, ?, ?));
            od;
            AddFreeWords(w, v);
        od;
        w := AlgebraicReduction(w);
        w := NegateWord(w);
        return homotopyNWord(w);
    end;

    bdryKWord := function(k, w)
        local x, idg, dkw;
        dkw := [];
        for x in w do

        od;
    end;

    bdry := function(n, i)
    end;
end);