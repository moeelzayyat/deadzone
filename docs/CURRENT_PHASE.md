# CURRENT PHASE

**Stage:** A1 — Foundation
**Substage:** A1.7 — Types and StatPipeline
**Status:** ⬜ Not started
**Last checkpoint passed:** A1.6 (2026-10-16, auto-approved)
**Started:** —
**Planned stage start:** A1 2026-10-19 (D-013)

## Deliverables (from ROADMAP.md)
- All §6 types with no `any`; `StatPipeline` + `DamageCalculator`; `STATS.md` seeded with every §10.2 stat, layer and cap.

## Checkpoint — passes when
Tests cover: each layer alone, all layers combined, every cap, zero/negative inputs; 100% of `STATS.md` rows have a test.

## Verify via
TestRunner.

## Notes for this substage
- Types go in `ReplicatedStorage/Shared/Types`, `StatPipeline` and `DamageCalculator` in `Shared/Stats` (§4.3). Formula and layer order: architecture §7.3 and `docs/STATS.md`. No formula in UI code; every stat value comes from `StatPipeline` (CLAUDE.md rule 7).
- `_Registry` (A1.6, D-019) keeps its own copies of the stat ids, layers, damage tags, rarity, archetypes, targeting and wallet currencies. Once `Shared/Stats` (and the §6 types) exist, point `_Registry` at them so each list exists once, and keep `Registry.spec` green.
- Definition Luau types (ClassDefinition §7.5, WeaponDefinition §10.1, EnemyDefinition §8.4) are not in `_Registry`; the registry returns `{ [string]: unknown }`. §6 types are this substage's scope; add definition types only where A1.7 code needs them.
- §6.1 profile types are schema v1: do not change a field (STOP AND ASK). Write them exactly as §6.1 says, with `Serum` (D-011).
- Mirror export: `docs/MIRROR.md` (D-015). The last export took two calls (92K + 77K characters, `START = 37`); expect two or three. Then `bash tools/analyze.sh` → `diagnostics: 0` (D-014). The place has 41 scripts: the export's DataModel count is the reference.
- `multi_edit` splits dotted script names; create `*.spec` modules with `execute_luau` (`Instance.new` + `Source` + `Name`).
- Tests: run on a clone of `ServerStorage.Tests` in Edit mode. Modules outside `Tests` hit the Edit-mode require cache (a load error stays cached too): have the spec require a clone of `Shared` (as `Registry.spec` does) and take types with `typeof(require(...))` in a type alias.
- Backups: `SerializationService:SerializeInstancesAsync(service:GetChildren())` → `EncodingService:Base64Encode` → JSON padded past 66K so the harness saves it to a file; decode locally and verify length + FNV-1a. ServerStorage is now 69 KB (92 KB base64): send it in two calls (`string.sub` at 48,000). Copy unchanged services from the previous backup after a hash match.
- Every module `--!strict`. Vendor code (`*/Vendor/*`) is out of the zero-warning rule.
- Open owner item: D-012 (paid random items; before B1).

## On pass
Set this file to **A1.8**, update `docs/ROADMAP.md`, append the checkpoint record to `docs/HANDOFF_REPORT.md`, add the approval line to `docs/DECISION_LOG.md`.
