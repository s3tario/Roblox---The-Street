#!/usr/bin/env bash
# Installs the build toolchain: Rojo, Lune, StyLua (cargo) and luau-lsp (built from source).
# Safe to re-run; skips tools already on PATH.
set -euo pipefail
command -v cargo >/dev/null || { echo "Install Rust first: https://rustup.rs"; exit 1; }
[[ -f /root/.ccr/ca-bundle.crt ]] && export CARGO_HTTP_CAINFO=/root/.ccr/ca-bundle.crt
command -v rojo   >/dev/null || cargo install rojo --locked &
command -v lune   >/dev/null || cargo install lune --locked &
command -v stylua >/dev/null || cargo install stylua --locked --features luau &
wait
if ! command -v luau-lsp >/dev/null; then
  TMP=$(mktemp -d)
  git clone --depth 1 --recurse-submodules --shallow-submodules https://github.com/JohnnyMorganz/luau-lsp "$TMP/luau-lsp"
  (cd "$TMP/luau-lsp" && CC=clang CXX=clang++ cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS="-Wno-error" \
    && cmake --build build --target Luau.LanguageServer.CLI -j "$(nproc)")
  install -m 755 "$TMP/luau-lsp/build/luau-lsp" "${CARGO_HOME:-$HOME/.cargo}/bin/luau-lsp"
fi
rojo --version; lune --version; stylua --version; luau-lsp --version
