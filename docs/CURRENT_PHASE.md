# CURRENT PHASE

**Stage:** A2 — Combat Feel
**Substage:** A2.3 — Enemy simulation core
**Status:** ⬜ Not started
**Last checkpoint passed:** A2.2 (2026-10-16 20:25 UTC, auto-approved under D-022)
**Started:** —
**Planned stage start:** A2 2026-11-02 (D-013)

## Deliverables (from ROADMAP.md)
- `EnemyService` table sim on `SimulationClock`; Walker + Runner definitions; steering + separation; tiered update rates; snapshot packing.

## Checkpoint — passes when
90 Walkers/Runners alive pursuing one player; server heartbeat ≤ 8 ms avg / ≤ 16 ms p99 (record both).

## Verify via
`execute_luau` profiler script, console.

## Notes for this substage
- Architecture: §8.1–§8.4 (enemies are table rows, not Humanoids; the §8.2 record; fodder steering + separation + wall slide on the arena collision grid, no per-enemy PathfindingService; stuck enemies teleport to a valid spawn edge, logged; §8.4 EnemyDefinition), §9.1 (SimulationClock per match, MaxStep 0.25 s), §7.2 (snapshot `buffer` packing; 90-enemy snapshot measured at 1,532 B in A1.8), §23 (server heartbeat budget, tiered update rates, interest filtering per arena).
- Arena (A2.2, D-024): `Encounter/ArenaService:grid("TestArena")` returns the `Util/ArenaGrid` grid (76 × 76 cells of 2 studs, centred on the arena origin; `isOpen`, `cellAt`, `openAt`, `center`, `edgeCells(edgeId)`, `reach`). Steer in arena-local space and convert with `ArenaService:toLocal/toWorld(placed, …)`; the flag `TestArena` places TestArena in slot 0 at (0, 0, 1600) and spawns the player on cell (38,38). Spawn edges: North, South, East, West (156–168 open cells each). Walker definition exists (A1.6 placeholder numbers, Radius 1.5); Runner needs a definition (CONTENT_BIBLE §2), validated by `_Registry`.
- Enemy targets for auto-aim: `InputController.setTargetProvider` (A2.1) is the hook for A2.3/A2.4.
- Snapshot remote: API_CONTRACTS already has the `EnemySnapshot` row (U, `buffer` `[count][id u16, x f32, y f32, z f32, yaw u8, state u8, hpPct u8]...`, 10–15 Hz, interest-filtered per arena, since A2.3), so `check_contracts.py` reports DIFFER from now until A2.3 adds its contract (`--through A2.2` → MATCH). A new S→C remote needs an API_CONTRACTS row, a `Net/Contracts` entry, a guard and a spec in the same change; remotes only in boot phase 8 through `Server/Gateway` (D-021). `check_contracts.py` must stay MATCH.
- Camera stays 55° / 44 studs / FOV 50 (D-023, kept in D-024, revisable).
- Unattended mode (D-022): take the recommended option at a fork, record it as "Decided by Claude under owner delegation of 2026-10-16 (revisable)", log it, mention it in one line, keep going. Real-money spend, publishing to the live game or real players, and player-data-loss risks still wait for the owner; GO/NO-GO gates stay the owner's.
- Mirror export: `docs/MIRROR.md` (D-015). A2.2's export took eight calls (`START = 22, 51, 54, 66, 74, 80, 86`); the place has 89 scripts. Then `bash tools/analyze.sh` → `diagnostics: 0` (D-014). `python tools/check_contracts.py` must stay MATCH.
- Installing code: draft locally (copy of `mirror/src`), check with luau-lsp against a temp sourcemap, send to Studio in execute_luau calls of ≤ 40 KB inside `[==[ ... ]==]`, hash-checked. Existing scripts: send only the changed line ranges (byte offsets against the mirror copy) or exact snippet replacements, after the Studio source matches the mirror. `multi_edit` splits dotted script names; create `*.spec` modules with `execute_luau`.
- Tests: run on a clone of `ServerStorage.Tests` in Edit mode. Specs require clones (`Shared:Clone()`, `Server:Clone()`). The Edit require cache keeps old versions of changed Shared modules; replace a changed module with an identical clone before an Edit run. In a play session execute_luau has its own require cache (use log lines or Instances). Injected input cannot move analog sticks or touch, and mouse Delta is 0 for injected moves.
- Viewport: during A2.2 Studio's viewport did not render (RenderStepped 0 frames, `screen_capture` timed out, injected WASD did nothing). Client `Humanoid:MoveTo` still works for movement tests; check `RenderStepped` first and ask the owner to bring Studio to the front if screenshots are needed.
- Backups (D-010): `SerializationService:SerializeInstancesAsync(children)` (skip Terrain and Camera) → `EncodingService:Base64Encode`, base64 chunks of ≤ 90,000 characters per call, padded past 66K so the harness saves them to a file, decoded locally and verified by length + FNV-1a. Since A2.2 there is a seventh file, `StarterPlayer.rbxm` (StarterCharacter + StarterCharacterScripts). ServerStorage is 126 KB (two calls), ReplicatedStorage 74 KB (two calls).
- Model pivots: a Model's `GetPivot()` follows its PrimaryPart, not the `WorldPivot` property; arena templates leave PrimaryPart unset.
- Every module `--!strict`. Vendor code (`*/Vendor/*`) is out of the zero-warning rule.

## On pass
Set this file to **A2.4**, update `docs/ROADMAP.md`, append the checkpoint record to `docs/HANDOFF_REPORT.md`, add the approval line to `docs/DECISION_LOG.md`.
