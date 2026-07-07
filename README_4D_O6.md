# 4+1D FSPT classification extension

This working copy adds the 4+1D classification layer structure

```text
(n2, n3, n4, nu5)
```

where

- `n2 in C^2(G_b, Z^T)` is the p+ip layer;
- `n3 in C^3(G_b, Z2)` is the Majorana-chain layer;
- `n4 in C^4(G_b, Z2)` is the complex-fermion layer;
- `nu5 in C^5(G_b, U(1)_T)` is the bosonic layer.

Implemented classification differentials:

```text
d n2 = 0,
d n3 = n2 cup n2 + omega2 cup n2 + s1 cup (n2 cup_1 n2)        mod 2,
d n4 = n3 cup_1 n3 + omega2 cup n3 + s1 cup (n3 cup_2 n3)       mod 2.
```

The 4+1D complex-to-bosonic contribution is

```text
1/2 * (omega2 cup n4 + n4 cup_2 n4 + d n4 cup_3 n4 + d n4 cup_4 d n4).
```

The pure Majorana `O6^gamma` piece no longer uses the numerical 25-bit table.
It is implemented from the equivalent Cartan-Adem cochain representative:

```text
O6^gamma =
  1/2 [ zeta_{2,3}(omega2,n3) + x(n3)
      + (n3 cup_1 n3) cup_4 (omega2 cup n3)
      + (n3 cup_1 n3) cup_4 (s1 cup [beta n3]_2)
      + (omega2 cup n3) cup_4 (s1 cup [beta n3]_2)
      + zeta_{1,4}(s1,[beta n3]_2)
      + (omega2 cup_1 s1) cup [beta n3]_2
      + s1 cup (n3 cup_1 n3) ]
  + 1/4 [ omega2 cup beta n3 - (beta n3) cup_2 (beta n3)
      + s1^2 cup [beta n3]_2 + s1^3 cup n3 ].
```

Here `beta n3 = d(tilde n3)/2` is the integral Bockstein of the canonical
0/1 lift. The half-valued bracket is reduced mod 2. In the quarter-valued
bracket, the first two terms use the integral Bockstein, while the last two
are computed mod 2 and lifted as 0/1 cochains.

The May-Steenrod terms are evaluated by a small generic mod-2 surjection
product implementation in `lib/inhomo_cocycle.gi`:

```text
zeta_{2,3}(a,b) = <12313434>(a,a,b,b),
zeta_{1,4}(a,b) = <12324343>(a,a,b,b),
x(n3) = <1213243142 + 1213431412 + 1232431421 + 1234314212>(n3,n3,n3,n3).
```

Stacking is intentionally not implemented for the 4+1D p+ip extension in this
working copy. The existing 4D add-twisters remain placeholders; in particular
`N3 = n3 + n3'` is kept additive and no incorrect `m3` term is introduced.

## Requirements

- **Resolution depth ≥ 6** for 4+1D O6 tests.  The d_3 differential reaches
  E_3^{3,2} → E_3^{6,0}, requiring bar resolution degree 6.  Using a shallower
  resolution will produce misleading failures.

## FermionSPTSpecSeqNoPip caveat

`FermionSPTSpecSeqNoPip` removes the q=3 (p+ip) layer by unbinding
`ss!.spectrum[4]`.  This **must** be called on a freshly constructed spectral
sequence, before any page or component is built.  Calling it after pages have
been computed is unsafe.  A cleaner long-term solution is a dedicated no-p+ip
constructor that never installs the q=3 spectrum or the d_2(2,3) differential.

## Examples

### Full quadruplet (with p+ip)

```gap
Read("pkg/SptSet/examples/fspt_4d_z4f.g");
```

Expected: `(Z2, Z2, Z2, Z2)` for `G_f = Z_4^f`.

### Triplet (no p+ip)

```gap
Read("pkg/SptSet/examples/fspt_4d_z4f_nopip.g");
```

Expected: `(Z2, Z2, Z2)` for `G_f = Z_4^f`.

Both examples use `G_b = Z_2`, non-trivial `omega2`, `s1=0`;
they print the classification layer view.  Stacking is not tested.
