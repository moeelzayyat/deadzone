# CURRENT PHASE

**Stage:** A1 — Foundation
**Substage:** A1.3 — Git mirror
**Status:** ⬜ Not started
**Last checkpoint passed:** A1.2 (2026-10-16, auto-approved)
**Started:** —
**Planned stage start:** A1 2026-10-19 (D-013)

## Deliverables (from ROADMAP.md)
- Export procedure (Claude reads every script and writes `mirror/src/...`); first export committed.

## Checkpoint — passes when
Mirror tree matches the Studio tree one-to-one (script count equal).

## Verify via
`script_search` count vs mirror file count.

## Notes for this substage
- Mirror mapping in use since A1.1: `Shared`→`mirror/src/shared`, `Server`→`src/server`, `Client`→`src/client`, `Tests`→`src/tests`; Script→`.server.luau`, LocalScript→`.client.luau`, ModuleScript→`.luau`, StringValue (license text)→`.txt`. Names keep dots (`TestRunner.spec.luau`).
- A1.2 exported with one `execute_luau` call that returns the tree of the 4 roots plus every non-vendor source with length + FNV-1a (padded past 64K so the harness saves it to a file), then a local Python script wrote the files, verified every hash (vendor files hash-checked in place) and regenerated `mirror/sourcemap.json`. That script lived in the session scratchpad; A1.3 should put the procedure in the repo and document it.
- Tests: run on a clone of `ServerStorage.Tests` in Edit mode (Studio caches `require` per ModuleScript across `execute_luau` calls); in a play test plain `require` is fresh. See the TestRunner header comment.
- Step 2 uses `tools/analyze.sh` (luau-lsp, D-014) after the export; it must print `diagnostics: 0`.
- Every module `--!strict`. Vendor code (`*/Vendor/*`) is out of the zero-warning rule.
- Open owner item: D-012 (paid random items). Doesn't block A1; must be decided before B1.

## On pass
Set this file to **A1.4**, update `docs/ROADMAP.md`, append the checkpoint record to `docs/HANDOFF_REPORT.md`, add the approval line to `docs/DECISION_LOG.md`.
