# CURRENT PHASE

**Stage:** A1 — Foundation
**Substage:** A1.5 — Event bus
**Status:** ⬜ Not started
**Last checkpoint passed:** A1.4 (2026-10-16, auto-approved)
**Started:** —
**Planned stage start:** A1 2026-10-19 (D-013)

## Deliverables (from ROADMAP.md)
- Typed `Events` module; `EVENTS.md` with the §5.3 catalog; publish/subscribe tests; misuse (publish from wrong domain) asserts in strict mode.

## Checkpoint — passes when
Tests: subscribe → publish → receive; wrong-type payload rejected.

## Verify via
TestRunner.

## Notes for this substage
- The bus lives in `ReplicatedStorage/Shared/Events` (§4.3). Publishers are the authoritative domain only (§5.3); "publish from wrong domain" needs to know the caller's domain. Services boot through `ServerScriptService/Server/Lifecycle` (A1.4, D-016): Init resolves dependencies with `Lifecycle.get` and must not yield; subscriptions belong in `Start`.
- Placeholder services exist per domain (A1.4); give them no bus behaviour unless the substage needs it.
- Mirror export: `docs/MIRROR.md` (D-015). Paste `tools/mirror_export.luau` into `execute_luau` (Edit), then `python tools/mirror_write.py <result files>`; it must print `ALL OK` with `MATCH`. Then `bash tools/analyze.sh` → `diagnostics: 0` (D-014). The place has 17 scripts, past `script_search`'s cap of 10: the export's DataModel count is the reference.
- Tests: run on a clone of `ServerStorage.Tests` in Edit mode (Studio caches `require` per ModuleScript across `execute_luau` calls); in a play test plain `require` is fresh. Modules under test outside `Tests` (e.g. `Shared/Events`, `Server/Lifecycle`) hit the same cache: run them in a play test or require a clone.
- Backups: `SerializationService:SerializeInstancesAsync` → `EncodingService:Base64Encode` → JSON padded past 66K so the harness saves it to a file; decode locally and verify length + FNV-1a. Copy unchanged services from the previous backup after a hash match.
- Every module `--!strict`. Vendor code (`*/Vendor/*`) is out of the zero-warning rule.
- Open owner item: D-012 (paid random items; before B1). D-017 accepted: Telemetry `MetricsService`, Data `ProfileDataService`, Social `MatchmakerService` (Roblox built-in names are rejected at boot).

## On pass
Set this file to **A1.6**, update `docs/ROADMAP.md`, append the checkpoint record to `docs/HANDOFF_REPORT.md`, add the approval line to `docs/DECISION_LOG.md`.
