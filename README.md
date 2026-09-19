# SptSet

GAP package for computing the classification of SPT and SET phases.

## Status

SptSet package is still work in progress. There are still planned functions missing.
Currently, it can be used to compute fermion SPT classification in 2D, and in 3D if the symmetry group is a direct product of bosonic symmetries and fermion parity. Since the package is still incomplete, we do not provide release packages, and recommend accessing the most current version by cloning the git repository.

## Installation

1. Clone this git repository.
1. Copy (or make a symbolic link) the entire repository under the pkg/ directory of your gap installation. Obviously these two steps can be combined together by directly cloning the repository under the pkg/ directory.

## Required local patch: GAP's `io` package

Code on this branch — `SptSetParListByForkSafe` in `lib/bar_resolution_map_common.gi` —
depends on one local modification to the `io` package. That package is **not** part of
this repository, so a fresh clone will not have it.

| | |
|---|---|
| Package | `io` 4.8.2 |
| File | `gap/background.gi` |
| Function | `ParListByFork` |

**What the patch does.** A worker that dies without delivering its pickled result
(OOM kill, a GAP error raised inside the worker, ...) leaves `fail` bound in the
result list. The original completeness test only checked `IsBound`, so it accepted
that `fail` entry, and the final `Concatenation(res)` then aborted the whole session
with the misleading error `Concatenation: arguments must be lists`. The patch
additionally requires each entry to be a list, so `ParListByFork` returns `fail`
instead — which `SptSetParListByForkSafe` catches and handles by falling back to a
sequential `List`.

**How to apply it.** From the root of your `io` package directory (e.g. `<gap>/pkg/io/`):

```sh
patch -p1 < /path/to/SptSet/patches/io-ParListByFork-return-fail.patch
```

The patch is a single changed condition plus an explanatory comment. It has been
verified to apply cleanly to the pristine `io` 4.8.2 `gap/background.gi`, and to
reproduce the working patched file exactly.

**If you do not apply it.** The code still runs. The difference only appears when a
parallel worker dies: instead of degrading gracefully to sequential evaluation, the
whole session aborts with the misleading `Concatenation` error above.

## Examples

After the package is installed, one can run the scripts under the examples/ directory in the package to do some computation. In particular, the scripts fspt_2d_ez.g and fspt_2d_s12.g were used to generate results in [arXiv:2005.06572](https://arxiv.org/abs/2005.06572).
