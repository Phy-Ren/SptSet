# SptSet

GAP package for computing the classification of SPT and SET phases.

## Status

SptSet package is still work in progress. There are still planned functions missing.
Currently, it can be used to compute fermion SPT classification in 2D, and in 3D if the symmetry group is a direct product of bosonic symmetries and fermion parity. Since the package is still incomplete, we do not provide release packages, and recommend accessing the most current version by cloning the git repository.

## Installation

1. Clone this git repository.
1. Copy (or make a symbolic link) the entire repository under the pkg/ directory of your gap installation. Obviously these two steps can be combined together by directly cloning the repository under the pkg/ directory.

## Examples

After the package is installed, one can run the scripts under the examples/ directory in the package to do some computation. In particular, the scripts fspt_2d_ez.g and fspt_2d_s12.g were used to generate results in [arXiv:2005.06572](https://arxiv.org/abs/2005.06572).

## Development Setup

This section describes how to set up your development environment after cloning the repository for development. Mainly we use pre-commit and gaplint for linter check.

### Prerequisites

- Python 3.10+ (for development tools)
- [uv](https://docs.astral.sh/uv/) (recommended) or pip

### First-time Setup

After cloning the repository, run these commands to set up the development environment:

```bash
# Navigate to the repository
cd /path/to/SptSet

# Install uv if you don't have it (one-time)
pip install --user uv

# Create a virtual environment and install dev tools
~/.local/bin/uv venv .venv
source .venv/bin/activate
uv pip install pre-commit gaplint

# Install the pre-commit git hooks
pre-commit install
```

This installs:
- **pre-commit**: Runs automatic checks before each commit (trailing whitespace, EOF newlines, etc.)
- **gaplint**: A linter for GAP code that checks formatting and style

### Making Commits

You need to activate the virtual environment before committing so that the pre-commit hooks can find `gaplint`:

```bash
# Activate the virtual environment
source .venv/bin/activate

# Stage your changes
git add <files>

# Commit - pre-commit hooks will run automatically
git commit -m "Your commit message"
```

If you forget to activate the venv, the gaplint hook will skip (with a warning) but other hooks will still run.

### Running Checks Manually

You can run the pre-commit checks manually at any time:

```bash
source .venv/bin/activate

# Run on staged files only
pre-commit run

# Run on all files in the repo
pre-commit run --all-files

# Run gaplint directly on specific files
gaplint lib/cochain.gi examples/fspt_2d_ez.g
```

### Linting Modes

By default, gaplint runs in **warn-only mode**: it displays warnings but won't block your commits. This is useful during development when the codebase has existing style issues.

To enable **strict mode** (block commits on lint errors), set the environment variable before committing:

```bash
# Enable strict mode (fail on gaplint errors)
export STRICT_GAPLINT=1
git commit -m "Your message"

# Or as a one-liner
STRICT_GAPLINT=1 git commit -m "Your message"
```

To customize which rules gaplint checks, create a `.gaplint.yml` file at the repo root:

```yaml
# Example: relax some rules
columns: 100          # Allow longer lines (default: 80)
disable:
  - W004              # Don't require aligned assignments
  - W034              # Don't warn about one-line functions
```

See [gaplint documentation](https://github.com/james-d-mitchell/gaplint) for all available rules.

### Quick Reference

| Task | Command |
|------|---------|
| Activate environment | `source .venv/bin/activate` |
| Deactivate environment | `deactivate` |
| Run all checks | `pre-commit run --all-files` |
| Lint specific file | `gaplint path/to/file.g` |
| Update pre-commit hooks | `pre-commit autoupdate` |
