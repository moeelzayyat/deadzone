# CURRENT PHASE

**Stage:** A1 — Foundation
**Substage:** A1.6 — Definitions registry
**Status:** ⬜ Not started
**Last checkpoint passed:** A1.5 (2026-10-16, auto-approved)
**Started:** —
**Planned stage start:** A1 2026-10-19 (D-013)

## Deliverables (from ROADMAP.md)
- `_Registry` loads every `Definitions/*` folder, validates schema, detects duplicate IDs; one sample per folder.

## Checkpoint — passes when
A deliberately broken sample (missing field / duplicate ID) makes boot fail with a clear message; fixing it boots clean.

## Verify via
Play test ×2.

## Notes for this substage
- `_Registry` lives in `ReplicatedStorage/Shared/Definitions` (§4.3) next to the 18 definition folders. Bootstrap runs phase 3 through the `definitions` hook of `Lifecycle.boot` (A1.4, D-016); today the hook only counts folders. A registry failure must stop the boot ("server refuses to start on failure", §5.2).
- The bus is ready (A1.5, D-018): the registry publishes `DefinitionsValidated { Count: integer }` through `EventBus.server():publisher("Definitions")`. Publishing from any other identity throws in Studio.
- Rule 8: every new definition type gets validation in `_Registry`; a bad definition fails boot. Schemas for content (classes, weapons, enemies, ...) are owner-visible content data: keep sample entries minimal and take names from `docs/CONTENT_BIBLE.md`.
- Mirror export: `docs/MIRROR.md` (D-015). Paste `tools/mirror_export.luau` into `execute_luau` (Edit), then `python tools/mirror_write.py <result files>`; it must print `ALL OK` with `MATCH`. The last export was 94.5K characters in one call, so expect two calls (`START = next`). Then `bash tools/analyze.sh` → `diagnostics: 0` (D-014). The place has 20 scripts: the export's DataModel count is the reference.
- `multi_edit` splits dotted script names (`EventBus.spec` became Folder + `spec`); create such modules under a plain name and rename with `execute_luau`.
- Tests: run on a clone of `ServerStorage.Tests` in Edit mode (Studio caches `require` per ModuleScript across `execute_luau` calls); in a play test plain `require` is fresh. Modules outside `Tests` (`Shared/*`, `Server/Lifecycle`) hit the same cache: run them in a play test or point a spec clone at a module clone.
- Backups: `SerializationService:SerializeInstancesAsync(service:GetChildren())` (StarterPlayerScripts too) → `EncodingService:Base64Encode` → JSON padded past 66K so the harness saves it to a file; decode locally and verify length + FNV-1a. ServerStorage is ~85K in base64, so give it its own call. Copy unchanged services from the previous backup after a hash match.
- Every module `--!strict`. Vendor code (`*/Vendor/*`) is out of the zero-warning rule.
- Open owner item: D-012 (paid random items; before B1).

## On pass
Set this file to **A1.7**, update `docs/ROADMAP.md`, append the checkpoint record to `docs/HANDOFF_REPORT.md`, add the approval line to `docs/DECISION_LOG.md`.
