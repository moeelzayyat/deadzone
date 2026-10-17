# CURRENT PHASE

**Stage:** A2 — Combat Feel
**Substage:** A2.5 — Primary attack with prediction
**Status:** ⬜ Not started
**Last checkpoint passed:** A2.4 (2026-10-17 13:30 UTC, auto-approved under D-022)
**Started:** —
**Planned stage start:** A2 2026-11-02 (D-013)

## Deliverables (from ROADMAP.md)
- Sharpshooter rifle: client predicted VFX/SFX; `RequestAttack` with seq + timestamp; server lag-compensated hit test with 250 ms ring buffer; `CombatResult` batched over `UnreliableRemoteEvent`.

## Checkpoint — passes when
With 100 ms simulated RTT (Studio network settings): input→feedback ≤ 1 frame; request→result ≤ 150 ms; server rejects attacks with spoofed origin in tests.

## Verify via
See the A2.5 row in `docs/ROADMAP.md` (TestRunner, play test, LatencyProbe per `docs/PERFORMANCE_BUDGETS.md`).

## Notes for this substage
- Architecture: §7.1 (combat pipeline with prediction: the client sends intent + seq + timestamp, never damage or hits; server rewinds ≤ 250 ms, clamps higher latency), §7.2 (RequestAttack / CombatResult contracts, rate limits), §7.3 (DamageCalculator), §8.2 (enemy History = PositionRing), §23 (input → feedback ≤ 1 frame, request → result ≤ 150 ms).
- New remotes need an API_CONTRACTS row, type guard and rate limit first, created in boot phase 8 only (`Server/Gateway`); `tools/check_contracts.py` reads DIFFER until A2.5 adds the ClientHeartbeat, CombatResult and RequestAttack contracts (through A2.4 it is MATCH), and must read MATCH at the A2.5 checkpoint.
- Already in place: `InputController` fires Primary (mouse/RT/auto-fire) with a target provider fed by `EnemyController` (nearest within 60 studs, D-023); `AimController` aim marker; `Shared/Util/PositionRing` (16 samples per enemy, `History` in EnemyService) for the rewind query; `DamageCalculator.damage(stats, hit)` (A1.7); Walker/Runner MaxHealth 20/12. Enemies never die yet: A2.5 adds damage, Stagger and Dying in `EnemyService`, and the snapshots already carry those states (`EnemySnapshot.STATES`).
- Client rendering (A2.4, D-026): `Client/Render/EnemyRenderer` draws `EnemyController.enemies()` two snapshot intervals (167 ms) behind with a ±10 % render-clock slew; `EnemyPose` already has Stagger and Dying poses (Dying is a generic topple and sink; ART_BIBLE rule 7 wants a dissolve, and the kill pop is A2.8). Predicted hit sparks should target the rendered enemy position (what the player sees), while the server rewinds to the request time; the render delay is part of the latency the rewind must cover.
- Measuring: Studio throttles a background window to 15 FPS, so FPS and input→feedback checks need the Studio window in front (ask the owner if RenderStepped shows ~15 FPS). Walking in play: injected keys (`user_keyboard_input`), not `Humanoid:MoveTo` (ControlModule cancels it while the viewport renders). execute_luau drops calls near 60 s: run probes in a background thread and poll `_G`. FPS overlay: flag `PerfOverlay`. Network lag: Studio Settings → Network → Incoming Replication Lag (owner-side setting; ask if it cannot be set through MCP).
- Unattended mode (D-022): take the recommended option at a fork, record it as "Decided by Claude under owner delegation of 2026-10-16 (revisable)", log it, mention it in one line, keep going. Real-money spend, publishing to the live game or real players, and player-data-loss risks still wait for the owner; GO/NO-GO gates stay the owner's.
- Installing code: draft locally (copy of `mirror/src`), check with luau-lsp against a temp sourcemap that adds the new files, install in execute_luau calls of ≤ 40 KB inside `[==[ ... ]==]` with length + FNV-1a checks; changed scripts by diff-based snippet patches checked against the old and new hashes, modules replaced by fresh instances (require cache). Long Bash heredocs fail to parse: write scripts with the Write tool. Mirror (D-015, D-026 point 10): copy the verified drafts into `mirror/src`, run `tools/mirror_export.luau` with `MANIFEST_ONLY = true`, then `python tools/mirror_write.py <result>` → `ALL OK` + `MATCH`; then `bash tools/analyze.sh` → `diagnostics: 0`.
- Tests: run on a clone of `ServerStorage.Tests` in Edit mode; client render libraries are tested through `fixtures/RenderFixture` (clones of `Client/Render/Lib`).
- Backups (D-010): `SerializationService:SerializeInstancesAsync(children)` (skip Terrain and Camera; StarterPlayer without StarterPlayerScripts) → `EncodingService:Base64Encode`, kept in `_G`, sent in slices of ≤ 60K characters padded past 64K so the harness saves them to files, decoded locally and verified by length + FNV-1a; services identical to the previous backup are copied. ServerStorage is now 155 KB (four slices), ReplicatedStorage 86 KB (two).
- Every module `--!strict`. Vendor code (`*/Vendor/*`) is out of the zero-warning rule.

## On pass
Set this file to **A2.6**, update `docs/ROADMAP.md`, append the checkpoint record to `docs/HANDOFF_REPORT.md`, add the approval line to `docs/DECISION_LOG.md`.
