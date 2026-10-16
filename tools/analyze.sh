#!/usr/bin/env bash
# Checkpoint step 2 (D-014): run luau-lsp over the mirrored project scripts.
# Run after the mirror export. Vendor code (Domains/*/Vendor) is excluded: it is not --!strict (ROADMAP §0 step 2).
# Usage: tools/analyze.sh   (from the repo root; LUAU_LSP_HOME overrides the install folder)
set -euo pipefail
L="${LUAU_LSP_HOME:-$HOME/tools/luau-lsp/1.70.1}"
mapfile -t FILES < <(find mirror/src -name '*.luau' -not -path '*/Vendor/*' | sort)
echo "files: ${#FILES[@]}"
OUT=$("$L/bin/luau-lsp.exe" analyze --platform=roblox --sourcemap=mirror/sourcemap.json \
  --definitions=@roblox="$L/globalTypes.None.d.luau" "${FILES[@]}" 2>&1 | grep -v -e '^\[INFO\]' -e 'didChangeWatchedFiles' || true)
if [ -n "$OUT" ]; then echo "$OUT"; echo "diagnostics: $(echo "$OUT" | wc -l)"; exit 1; fi
echo "diagnostics: 0"
