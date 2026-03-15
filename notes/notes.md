A pedagogical note on how to use this SptSet package.

## Prompts for Chat
1. I am new to GAP and this package, so my goal is to learn it and then develop upon it.

2. This is a Physics project, but involving deep math and coding, please combine them together to give a good note.

3. The notes.md should only contain commands with minimal explanation, which serves as a short quick start and overview.

4. While Latex_note.tex should contain line by line very detailed code explanatins, which serves as the final detailed publishable note.

5. Figure out the roles of notes.md and Latex_note.tex, do not write large overlaping things into them.

6. To save tokens, do not output the code explanations in the chat, directly write into Latex_note.tex. The chat output should only be a very brief summary of what you have done.

7. Try to add comments if we go through specific parts of the code to make the code more readable.

8. Check any related files by yourself if needed. Ask me if you have any important questions.

9. Use rigorous, commonly used and unified notations accross all files (notes.md, Latex_note.tex, code comments). Use '\begin{equation}', '\end{equation}' instead of '\[', '\]' for non-inline equations.

10. In Latex_note.tex, each sentence take a single line in the text editor for better looking. \label{} use eq:___, tab:___, fig:___, sec:___, ap:___.

## Goal
1. Add appropriate comments to the current code, which is still under development.

2. Write a very detailed practical teaching manual in the Latex note for every detail of the code. Containing all related physics, math and coding.

3. Debug and develop new functions based on the current code.

## References
1. Original paper for this SptSet package.
https://arxiv.org/abs/2005.06572

2. GAP system documentation.
https://www.gap-system.org/doc/

3. Paper related to group_ex branch.
https://arxiv.org/abs/2310.19058

4. Latex note for both GAP and SptSet.
SptSet/notes/Latex_note.tex

5. Paper related to O5 obstruction function and 3D classification
https://arxiv.org/abs/2512.25069

---

## Learning Plan for Beginners

### Phase 1: GAP System Basics (Prerequisite)
Before diving into SptSet, you need to learn GAP fundamentals:

1. **Basic GAP syntax**: Variables, lists, records, functions
2. **Group theory in GAP**: Creating groups, group homomorphisms, generators
3. **GAP package structure**: `.gd` files (declarations) vs `.gi` files (implementations)
4. **HAP package basics**: Understanding resolutions, cohomology computations

**Resources**:
- GAP Tutorial: https://www.gap-system.org/Manuals/doc/tut/chap0.html
- HAP Package: https://docs.gap-system.org/pkg/hap/doc/chap0.html

### Phase 2: SptSet Package Overview

#### 2.1 Package Structure
```
SptSet/
├── init.g              # Loads all .gd declaration files
├── read.g              # Loads all .gi implementation files
├── lib/                # Core library files
│   ├── *.gd            # Function/operation declarations
│   └── *.gi            # Function implementations
├── examples/           # Example scripts to run
├── debug/              # Debugging scripts
└── tst/                # Test files
```

#### 2.2 Core Modules (in dependency order)
| Module | Purpose |
|--------|---------|
| `module.g*` | Basic module operations |
| `zlmap.g*` | Z-linear maps between abelian groups |
| `coefficient.g*` | Coefficient systems for cohomology (U(1), Z_n, etc.) |
| `cochain.g*` | Cochains and cochain operations |
| `inhomo_cocycle.g*` | Inhomogeneous cocycles |
| `group_cohomology.g*` | Group cohomology cochain complexes |
| `bar_resolution_map*.g*` | Bar resolution computations |
| `spectral_sequence.g*` | Spectral sequence framework |
| `ss_*.g*` | Specific spectral sequence implementations |

#### 2.3 Key Concepts Mapping (Physics → Code)
| Physics Concept | Code Implementation |
|-----------------|---------------------|
| Symmetry group G | GAP group objects (`SpaceGroupBBNWZ`, etc.) |
| Group cohomology H^n(G,M) | `SptSetCohomology(cochainComplex, n)` |
| Coefficient module | `SptSetCoefficient*` functions |
| Spectral sequence | `SptSetSpecSeq*` objects |
| SPT classification layers | `FermionSPTLayersVerbose(SS, dim)` |
| Fermion parity | `auMap` (automorphism to GL(1,Z)) |
| Spin structure (w) | `Spin12Factor` function |

### Phase 3: Running Examples

Start with these examples in order of complexity:

1. **`examples/fspt_2d_ez.g`** - 2D fermion SPT with easy fermion parity
   - Uses `FermionEZSPTSpecSeq` for simple cases

2. **`examples/fspt_2d_s12.g`** - 2D fermion SPT with spin-1/2
   - Uses `FermionSPTSpecSeq` with spin structure

3. **`examples/simple_3d.g`** - 3D example (if exists)

**How to run**:
```bash
cd /opt/gap-4.15.1

./gap pkg/SptSet/examples/fspt_2d_ez.g
```

### Phase 4: Code Deep Dive (Recommended Order)

1. **Start with coefficient systems** (`lib/coefficient.g*`)
   - Understand how U(1), Z_n coefficients are represented

2. **Group cohomology** (`lib/group_cohomology.g*`)
   - How HAP resolutions connect to cohomology

3. **Spectral sequence framework** (`lib/spectral_sequence.g*`)
   - The E_r^{p,q} pages and differentials

4. **Fermion implementations** (`lib/ss_fermion*.g*`)
   - How physical coboundary maps are installed

### Phase 5: Practical Tasks

- [ ] Run all examples and understand output format
- [ ] Trace through one example step-by-step with GAP debugger
- [ ] Add comments to `lib/coefficient.gi` as first documentation task
- [ ] Write a simple new example for a familiar symmetry group

---

## Quick Reference: Key Functions

### Loading the Package
```gap
LoadPackage("SptSet");
```

### Creating a Space Group (2D wallpaper groups)
```gap
SG := SpaceGroupBBNWZ(2, it);  # it = 2..17 for 2D wallpaper groups
fSG := IsomorphismPcpGroup(SG);
SG1 := Image(fSG);
```

### Computing a Resolution
```gap
R := ResolutionAlmostCrystalGroup(SG1, 6);  # 6 = dimension bound
```

### Setting Up Fermion Parity Map
```gap
gs := GeneratorsOfGroup(SG);
f := GroupHomomorphismByImagesNC(SG1, GL(1, Integers),
  List(gs, x -> Image(fSG, x)),
  List(gs, x -> [[DeterminantMat(x)]]));
```

### Running SPT Classification
```gap
SS := FermionEZSPTSpecSeq(R, f);       # Easy fermion parity
SS := FermionSPTSpecSeq(R, f, w);      # With spin structure w
FermionSPTLayersVerbose(SS, 2);        # Compute layers up to dimension 2
```

---

## Current Development Status

- ✅ 2D fermion SPT classification working
- ✅ 3D classification for G_b × Z_2^f (direct product cases)
- 🔄 General 3D classification (in development)
- 🔄 Group extension branch features (see arXiv:2310.19058)
- 🔄 O5 obstruction function (see arXiv:2512.25069)


## Comments for Code Structure

1. Mostly in master branch. Some new thing in group_ext branch, especially ss_module

2. fermion_ez is not needed, just comment out.

3. Top layer ss_fermion, containing all physical inputs: differentials, twisters. Next layer ss_vanilla for general AHSS. Then bar_resolution_map_mine, build resolution (arXiv:2005.06572). Bottom layer zlmap for coefficient systems.

4. group_ext branch, ss_module, ss_class, ss_cochain for stacking.


Most important examples:
2+1D FSPT group structure:
internal spinless wallpaper: fspt_2d_ez_ext.g (group 13 and 16 are CORRECT, see debug/debug_2d_wp13_wp16.g)
internal spin-1/2 wallpaper: fspt_2d_s12_ext.g (group 13 and 16 are CORRECT, same group different presentation)
  Note: SptSet uses Smith normal form (d1|d2|...), other algorithms may use primary decomposition.
  Group 13: Z_3 x Z_3 x Z_6 ≅ Z_2 x Z_3^3 (elementary divisors [2,3,3,3])
  Group 16 ez: Z_12 x Z_24 ≅ Z_3 x Z_8 x Z_12 (elementary divisors [3,3,4,8])
  Group 16 s12: Z_6 x Z_6 ≅ Z_2 x Z_3 x Z_6 (elementary divisors [2,2,3,3])
internal spinless wallpaper with Z2T: wp_z2t_cs12.g
internal spin-1/2 wallpaper with Z2T: wp_z2t_cs0.g

3+1D FSPT classification only: 
internal spinless space group: fspt_3d_simple_ez.g
internal spin-1/2 space group: fspt_3d_simple_s12.g

3+1D FSPT group structure:
internal spinless point group: fspt_ez_ext.g
internal spin-1/2 point group: fspt_s12_ext.g
  Bug fix: SptSetSpecSeqResult rewritten with layer-wise extension (ss_module.gi).
  Old method (SptSetSpecSeqResultOld) used sequential extension creating mixed generators
  whose Z-lift artifacts caused non-physical cancellations in stacking twisters.
  New method computes each layer's extension independently, then assembles via SNF.
  Fixed examples:
    Cs: Z_4 x Z_4 -> Z_16 (with p+ip), Z_8 unchanged (without p+ip)
    S4 s12: Z_4 -> Z_2 x Z_2 (correct, CF layer is trivial so no MC->CF extension)
    S4 ez: Z_4 unchanged (p+ip skips trivial MC to extend to CF correctly)
    C2h: Z_8 unchanged, no more rational (-47/2) in extension computation
  Remaining issue: C4v has ASSERTION WARNING (rational in cochain), result Z_2^4 is correct.
    C3v has FATAL ERROR (rational propagates into SNF), same root cause as C4v.
    This is a differential/coboundary formula issue, not an extension issue.
  See debug/debug_cs_layerwise.g, debug/debug_test_layerwise.g for verification.

Known issue: p+ip layer
  The d3 and d4 differentials originating from the p+ip layer are currently unknown
  (we assume they are unobstructed, but cannot derive the corresponding coboundary equations).
  Similarly, the stacking rules involving the p+ip layer at those levels are not understood.
  This may cause issues when p+ip is included, but should NOT affect examples without p+ip.

Assertion check "top layer is not a cocycle" explained:
  In SptSetPurifySpecSeqClass, the assertion ForAll(cp, IsInt) checks whether the
  OBSTRUCTION (not the trivialization alpha) is a well-defined cocycle in integer coefficients.
  Physically: given d(alpha) = O5, the O5 obstruction must be closed (dO5 = 0) for the
  equation to be consistent. The assertion checks this by verifying that the Bockstein image
  of the U(1)-valued O5 cochain is an integer vector.
  UPDATED: The root cause is NOT Bockstein normalization (that was a wrong direction).
  The actual root cause is in the stacking computation (addTwister) — see debug_cluster.md §12.
  The stacking result violates dO5=0 because addTwister(4,0) produces wrong Bosonic phase
  when Majorana cochains n21/n22 are non-zero. This bug is masked when CF≠0 because
  PurifySpecSeqClass breaks at p=3 (CF) without ever validating p=4 (Bosonic).
  Same root cause as C3v/C4v s12 assertion errors.