# CURRENT PHASE

**Stage:** A2 — Combat Feel
**Substage:** A2.4 — Client rendering
**Status:** ⬜ Not started
**Last checkpoint passed:** A2.3 (2026-10-16 21:20 UTC, auto-approved under D-022)
**Started:** —
**Planned stage start:** A2 2026-11-02 (D-013)

## Deliverables (from ROADMAP.md)
- Pooled enemy renderers; snapshot interpolation; procedural animation; despawn policy.

## Checkpoint — passes when
90 enemies move smoothly at 60 FPS on PC and ≥ 30 FPS in low-end emulation; no visible teleporting at 12 Hz snapshots.

## Verify via
Play test, FPS overlay.

## Notes for this substage
- Architecture: §8.1 (clients render pooled models with interpolation and locally driven animation; enemies are never Humanoids), §6.4 (client presentation state), §7.2 (EnemySnapshot over UnreliableRemoteEvent), §22 (art pipeline, ART_BIBLE silhouettes: Walker hunched with arms forward, Runner thin and leaning 45°), §23 (object pooling measured, client FPS 60 PC / 30 low-end).
- Snapshot source (A2.3, D-025): `Client/Controllers/EnemyController` already decodes every packet and keeps the latest record per enemy (`enemies()` → `{ [id]: { Id, DefId, Position, Yaw, State, HpPct, T, SeenAt } }`), forgets an enemy unseen for 1 s, and sends `RequestEnemySnapshots` once its handler is connected (keep that). Snapshot `T` is SimulationClock seconds; packets of one snapshot share `seq` and `T`; at most 49 enemies per packet (90 = 889 + 745 B); 12 Hz (Tunable `EnemySnapshotHz`, 10–15). `def` indexes `EnemySnapshot.DEF_IDS`; `state` indexes `EnemySnapshot.STATES`; `yaw` decodes with `EnemySnapshot.decodeYaw` (CFrame.Angles(0, yaw, 0)).
- Server side: the `EnemyTest` flag keeps 90 enemies (60 Walkers, 30 Runners) chasing the players in TestArena slot 0 at (0, 0, 1600). Spawn lasts 0.6 s (a rise animation fits there); Telegraph = the definition's TelegraphTime (Walker 0.4 s, Runner 0.3 s); Attack 0.2 s; positions are feet on the floor (world Y 0). Enemies never die before A2.5.
- Auto-aim: EnemyController already feeds `InputController.setTargetProvider` with the nearest enemy within 60 studs.
- Measuring: server heartbeat with `Tests/perf/HeartbeatProbe` (run it in a `task.spawn` and poll an attribute: execute_luau times out on a 60 s call). Client FPS: Studio's viewport has not rendered in the last two sessions (RenderStepped 0 frames, screen_capture times out); A2.4's checkpoint needs the viewport, so check `RenderStepped` first and ask the owner to bring Studio to the front if it is 0.
- Camera stays 55° / 44 studs / FOV 50 (D-023, D-024 point 8; still not checked by eye).
- Unattended mode (D-022): take the recommended option at a fork, record it as "Decided by Claude under owner delegation of 2026-10-16 (revisable)", log it, mention it in one line, keep going. Real-money spend, publishing to the live game or real players, and player-data-loss risks still wait for the owner; GO/NO-GO gates stay the owner's.
- Mirror export: `docs/MIRROR.md` (D-015). A2.3's export took eleven calls (`START = 1, 16, 27, 54, 57, 69, 78, 85, 90, 95, 103`); the place has 102 scripts. Then `bash tools/analyze.sh` → `diagnostics: 0` (D-014). `python tools/check_contracts.py` must stay MATCH.
- Installing code: draft locally (copy of `mirror/src`), check with luau-lsp against a temp sourcemap that adds the new draft files, send to Studio in execute_luau calls of ≤ 40 KB inside `[==[ ... ]==]`, hash-checked. Existing scripts: exact snippet replacements against the Studio source, then replace the module with a fresh clone (the Edit require cache). Long Bash heredocs fail to parse; write Python edit scripts with the Write tool.
- Tests: run on a clone of `ServerStorage.Tests` in Edit mode. `EventBus.server()` is server-only, so nothing that runs in a spec's Init may touch it. In a play session execute_luau has its own require cache (use log lines, Instances or the EnemyTestProbe). Edit is not available during play; patch in Edit after stopping.
- Backups (D-010): `SerializationService:SerializeInstancesAsync(children)` (skip Terrain and Camera; StarterPlayer without StarterPlayerScripts) → `EncodingService:Base64Encode`, kept in `_G` between calls and sent in slices of ≤ 64K characters padded to 66K, decoded locally and verified by length + FNV-1a. ServerStorage is now 145 KB (three slices), ReplicatedStorage 86 KB and ServerScriptService 79 KB (two each).
- Every module `--!strict`. Vendor code (`*/Vendor/*`) is out of the zero-warning rule.

## On pass
Set this file to **A2.5**, update `docs/ROADMAP.md`, append the checkpoint record to `docs/HANDOFF_REPORT.md`, add the approval line to `docs/DECISION_LOG.md`.
