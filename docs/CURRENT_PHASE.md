# CURRENT PHASE

**Stage:** A2 — Combat Feel
**Substage:** A2.2 — Test arena
**Status:** ⬜ Not started
**Last checkpoint passed:** A2.1 (2026-10-16, owner-approved "A2.1 OK" 19:33 UTC)
**Started:** —
**Planned stage start:** A2 2026-11-02 (D-013)

## Deliverables (from ROADMAP.md)
- Greybox arena with spawn edges and collision grid; placeholder survivor model.

## Checkpoint — passes when
Player walks the arena with no stuck spots; arena grid exported for steering.

## Verify via
Play test.

## Notes for this substage
- Architecture: §4.4 (one place; arenas are instanced per party as CFrame-offset copies from `ServerStorage`, streaming enabled), §8.3 (enemy steering + separation + wall slide against a precomputed arena collision grid; no per-enemy PathfindingService for fodder; stuck enemies teleport to a valid spawn edge), §22 and `docs/ART_BIBLE.md` (greybox and silhouette rules: survivor ≈ 7 studs, player gets its own light and a white outline), §23 (budgets measured in A2.3/A2.4, not here).
- The grid is the input for A2.3 `EnemyService` steering: export it as data a module can read (e.g. a `Definitions/Zones` or arena data module with cell size, bounds, blocked cells, spawn edges), validated in `_Registry` if it is a new definition type (bad data fails boot).
- Camera from A2.1 (D-023): pitch 55°, distance 44, FOV 50. ART_BIBLE §2 says "~35° pitch, ~40 studs out"; the arena is the first place to judge it with real geometry. If it changes, change `CameraController` constants and record it (revisable under D-022).
- Input (A2.1): `InputController` gives Move/Aim intent and `setTargetProvider` for auto-aim (A2.3/A2.4 fill it). `InputTestPanel` (flag `InputTestPanel`) stays on through Alpha.
- Network (D-021): remotes only through `Server/Gateway` in phase 8; every new remote needs an API_CONTRACTS row, a contract, a handler and a spec. A2.2 has no API_CONTRACTS row.
- Unattended mode (D-022): take the recommended option at a fork, record it as "Decided by Claude under owner delegation of 2026-10-16 (revisable)", log it, mention it in one line, keep going. Real-money spend, publishing to the live game or real players, and player-data-loss risks still wait for the owner; GO/NO-GO gates stay the owner's.
- Mirror export: `docs/MIRROR.md` (D-015). A2.1's export took seven calls (`START = 23, 49, 52, 64, 71, 77`); the place has 80 scripts. Then `bash tools/analyze.sh` → `diagnostics: 0` (D-014). `python tools/check_contracts.py` must stay MATCH.
- Installing code: draft locally, check with luau-lsp against a temp sourcemap, send to Studio in execute_luau calls of ≤ 40 KB inside `[==[ ... ]==]`, hash-checked; patch existing scripts by exact replacement only after their Studio source matches the mirror. `multi_edit` splits dotted script names; create `*.spec` modules with `execute_luau`.
- Tests: run on a clone of `ServerStorage.Tests` in Edit mode. Specs require clones (`Shared:Clone()`, `Server:Clone()`). The Edit require cache keeps old versions of changed Shared modules; replace a changed module with an identical clone before an Edit run. In a play session execute_luau has its own require cache (use log lines or Instances). Injected input cannot move analog sticks or touch, and mouse Delta is 0 for injected moves.
- Workspace changes (the arena) go into the Workspace or ServerStorage backups (D-010); Workspace was 7831 B at A2.1.
- Backups (D-010): `SerializationService:SerializeInstancesAsync(service:GetChildren())` (skip Terrain and Camera) → `EncodingService:Base64Encode`, base64 chunks of ≤ 90,000 characters per call, decoded locally and verified by length + FNV-1a. ServerStorage is 111 KB (148K base64, two calls). StarterPlayer properties (D-023) are not in any .rbxm; InputRules.spec checks them.
- Every module `--!strict`. Vendor code (`*/Vendor/*`) is out of the zero-warning rule.

## On pass
Set this file to **A2.3**, update `docs/ROADMAP.md`, append the checkpoint record to `docs/HANDOFF_REPORT.md`, add the approval line to `docs/DECISION_LOG.md`.
