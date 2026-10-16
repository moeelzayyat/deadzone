# CURRENT PHASE

**Stage:** A1 — Foundation
**Substage:** A1.8 — Clock, network, platform wrappers
**Status:** ⬜ Not started
**Last checkpoint passed:** A1.7 (2026-10-16, auto-approved)
**Started:** —
**Planned stage start:** A1 2026-10-19 (D-013)

## Deliverables (from ROADMAP.md)
- `SimulationClock` (pause/resume/tick tests); contract registry + token buckets + `buffer` codec helpers; remotes created in phase 8 only; `MetricsService`, `ErrorReportService`, `RemoteConfigService`, `FeatureFlagService` wrappers.

## Checkpoint — passes when
Tests: paused clock does not advance; bucket rejects the N+1th request; codec round-trips all field types; a remote does not exist before phase 8.

## Verify via
TestRunner, `search_game_tree`.

## Notes for this substage
- Architecture: §9.1 (SimulationClock: one pausable clock per match; run code reads `match.Clock`, never `os.clock()`), §7.2 (transport, per-player token bucket per remote), §19 (validation order), §5.1/§5.2 (Platform and Telemetry domains, phase 8 network), `docs/API_CONTRACTS.md` Rules (rows, rates, guards; remotes under `ReplicatedStorage/Net/<Name>`). D-017: the Telemetry wrapper is `MetricsService` (it wraps Roblox AnalyticsService); `ErrorReportService` and `RemoteConfigService` exist as A1.4 placeholders; `FeatureFlagService` is new (Platform). The Lifecycle boot rejects Roblox built-in service names (`game:FindService`); check new names the same way.
- Exit check for A1: 0 boot errors, 0 analysis warnings, TestRunner ≥ 40 tests / 0 failures (196 now), broken-definition boot failure demonstrated (A1.6). After A1.8 passes, `CURRENT_PHASE.md` = A2.1.
- A1.7 (D-020): stats come from `Shared/Stats/StatPipeline`; vocabularies from `Shared/Types/Common` (lists are frozen `{ string }`; Luau arrays are invariant, so build typed lists through typed varargs). Guards for numbers can reuse the "finite" checks (NaN/inf rejected). `tools/check_stats.py` must print MATCH whenever STATS.md or StatRegistry changes.
- No remote exists yet (phase 8 prints `0 remotes`). A remote needs its API_CONTRACTS row, guard and rate before it is created, in phase 8 only (CLAUDE.md rule 6).
- Mirror export: `docs/MIRROR.md` (D-015). The A1.7 export took three calls (94K + 94K + 66K, `START = 37`, then `49`); expect three or four. Then `bash tools/analyze.sh` → `diagnostics: 0` (D-014). The place has 51 scripts: the export's DataModel count is the reference.
- `multi_edit` splits dotted script names; create `*.spec` modules with `execute_luau` (`Instance.new` + `Source` + `Name`). Long sources go in one execute_luau call per file or two, inside `[==[ ... ]==]`, and are hash-checked against the local draft.
- Tests: run on a clone of `ServerStorage.Tests` in Edit mode. Modules outside `Tests` hit the Edit-mode require cache: specs require a clone of `Shared` and take types with `typeof(require(...))`.
- Backups: `SerializationService:SerializeInstancesAsync(service:GetChildren())` → `EncodingService:Base64Encode` → JSON padded past 66K so the harness saves it to a file; decode locally and verify length + FNV-1a. ServerStorage is now 79.8 KB (106K base64): three calls at 48,000 characters. Copy unchanged services from the previous backup after a hash match.
- Every module `--!strict`. Vendor code (`*/Vendor/*`) is out of the zero-warning rule.
- Open owner item: D-012 (paid random items; before B1). D-020 lists A1.7 readings the owner may overrule.

## On pass
Set this file to **A2.1**, update `docs/ROADMAP.md`, append the checkpoint record to `docs/HANDOFF_REPORT.md`, add the approval line to `docs/DECISION_LOG.md`.
