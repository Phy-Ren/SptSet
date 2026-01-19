#!/usr/bin/env bash
set -euo pipefail

if ! command -v gaplint >/dev/null 2>&1; then
  if [[ "${REQUIRE_GAPLINT:-0}" == "1" ]]; then
    echo "gaplint is required but not installed (REQUIRE_GAPLINT=1)." >&2
    echo "Install gaplint and ensure it's on PATH, then re-run." >&2
    exit 1
  fi
  echo "gaplint not found; skipping GAP lint. (Set REQUIRE_GAPLINT=1 to require it.)" >&2
  exit 0
fi

# Forward filenames from pre-commit.
# If you want to customize rules, add a .gaplint.yml at repo root.
# By default run in silent mode (suppress warnings). Set STRICT_GAPLINT=1 to fail on errors.
if [[ "${STRICT_GAPLINT:-0}" == "1" ]]; then
  exec gaplint "$@"
else
  gaplint --silent "$@" || true
fi
