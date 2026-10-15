#!/usr/bin/env bash
# Full verification: unit tests, world bake, type-check, format check, place build.
#   tools/check.sh            # everything
#   tools/check.sh --quick    # tests + typecheck only (no bake/build)
set -uo pipefail
cd "$(dirname "$0")/.."

QUICK=0
[[ "${1:-}" == "--quick" ]] && QUICK=1
FAIL=0
step() { printf "\n\033[1m== %s ==\033[0m\n" "$1"; }

step "Unit tests (Lune)"
lune run tools/test || FAIL=1

if [[ $QUICK -eq 0 ]]; then
  step "World bake"
  lune run tools/bake || FAIL=1
else
  # rojo sourcemap still needs the file to exist
  [[ -f build/World.rbxm ]] || { mkdir -p build; lune run tools/bake >/dev/null || true; }
fi

step "Type check (luau-lsp + Roblox definitions)"
rojo sourcemap default.project.json --output sourcemap.json >/dev/null 2>&1 || { echo "rojo sourcemap failed"; FAIL=1; }
ANALYZE_OUT=$(luau-lsp analyze \
  --sourcemap=sourcemap.json \
  --definitions=@roblox=tools/types/globalTypes.d.luau \
  --base-luaurc=.luaurc \
  --no-strict-dm-types \
  src 2>&1)
echo "$ANALYZE_OUT" | grep -E "TypeError|SyntaxError" | sed "s#$(pwd)/##" | head -300
ERRS=$(echo "$ANALYZE_OUT" | grep -cE "(TypeError|SyntaxError)" || true)
echo "type errors: $ERRS"
[[ "$ERRS" -gt 0 ]] && FAIL=1

step "Format check (StyLua)"
stylua --check src tools tests >/dev/null 2>&1 && echo "formatted" || { echo "run: stylua src tools tests"; FAIL=1; }

if [[ $QUICK -eq 0 ]]; then
  step "Place build (Rojo)"
  rojo build default.project.json --output build/TheStreet.rbxl && ls -la build/TheStreet.rbxl || FAIL=1
fi

if [[ $FAIL -ne 0 ]]; then
  printf "\n\033[31mCHECK FAILED\033[0m\n"; exit 1
fi
printf "\n\033[32mALL CHECKS PASSED\033[0m\n"
