# CURRENT PHASE

**Stage:** A1 — Foundation
**Substage:** A1.4 — Domains and lifecycle
**Status:** ⬜ Not started
**Last checkpoint passed:** A1.3 (2026-10-16, auto-approved)
**Started:** —
**Planned stage start:** A1 2026-10-19 (D-013)

## Deliverables (from ROADMAP.md)
- 10 domain folders, `Init`/`Start` contract, bootstrap asserts order, one placeholder service per domain.

## Checkpoint — passes when
Deliberately swapping two services' phases triggers the assertion in a test.

## Verify via
TestRunner.

## Notes for this substage
- The 10 domain folders already exist under `Server/Domains` (A1.1). `Server/Bootstrap` walks phases 0–8 in §5.2 order and lists ModuleScripts directly inside each domain folder as services; `Vendor` subfolders are not services.
- Mirror export: `docs/MIRROR.md` (D-015). Paste `tools/mirror_export.luau` into `execute_luau` (Edit), then `python tools/mirror_write.py <result files>`; it must print `ALL OK` with `MATCH`. Then `bash tools/analyze.sh` → `diagnostics: 0` (D-014).
- Tests: run on a clone of `ServerStorage.Tests` in Edit mode (Studio caches `require` per ModuleScript across `execute_luau` calls); in a play test plain `require` is fresh. Modules under test outside `Tests` hit the same cache: run them in a play test or clone what you require.
- Every module `--!strict`. Vendor code (`*/Vendor/*`) is out of the zero-warning rule.
- Open owner item: D-012 (paid random items). Doesn't block A1; must be decided before B1.

## On pass
Set this file to **A1.5**, update `docs/ROADMAP.md`, append the checkpoint record to `docs/HANDOFF_REPORT.md`, add the approval line to `docs/DECISION_LOG.md`.
