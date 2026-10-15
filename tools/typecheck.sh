#!/usr/bin/env bash
# Strict type-check against the Roblox API definitions, reporting only errors in the given paths.
#   tools/typecheck.sh                      # whole src/
#   tools/typecheck.sh src/server/Services/MarketService.luau src/shared/Logic/Market
# Safe to run concurrently (uses a private sourcemap file).
set -uo pipefail
cd "$(dirname "$0")/.."
[[ -f build/World.rbxm ]] || { mkdir -p build; lune run tools/bake >/dev/null 2>&1 || true; }
SM=$(mktemp --suffix=.sourcemap.json)
trap 'rm -f "$SM"' EXIT
rojo sourcemap default.project.json --output "$SM" >/dev/null 2>&1 || { echo "rojo sourcemap failed"; exit 2; }
PATHS=("$@"); [[ ${#PATHS[@]} -eq 0 ]] && PATHS=(src)
OUT=$(luau-lsp analyze --sourcemap="$SM" --definitions=@roblox=tools/types/globalTypes.d.luau \
  --base-luaurc=.luaurc --no-strict-dm-types "${PATHS[@]}" 2>&1)
ERRS=$(echo "$OUT" | grep -E "(TypeError|SyntaxError)" | sed "s#$(pwd)/##")
if [[ -n "$ERRS" ]]; then
  echo "$ERRS" | head -300
  echo "type errors: $(echo "$ERRS" | wc -l)"
  exit 1
fi
echo "type errors: 0"
