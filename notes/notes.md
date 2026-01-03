A pedagogical note on how to use this SptSet package.

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

4. Latex note for both GAP and SptSet. Note the notes.md should only contain commands with minimal explanation; while Latex_note.tex should contain line by line very detailed code explanatins. Do not output the code explanations in the chat, directly write into Latex_note.tex.
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

