# PERFORMANCE BUDGETS

Targets come from `architecture.md` §23. "Measured" columns are filled with real numbers at the named substage; a blank cell means not yet measured. Never write an estimate here.

## Server
| Metric | Target | A2.3 | A2.8 | A4.7 | A5.2 | A5.8 | B4.4 | L1 |
|---|---|---|---|---|---|---|---|---|
| Heartbeat avg (ms) @ 90 enemies, 1 arena | ≤ 8 | 0.64 standing · 0.74 walking | | | | | | |
| Heartbeat p99 (ms) @ 90 enemies, 1 arena | ≤ 16 | 0.84 standing · 2.50 walking | | | | | | |
| Heartbeat p99 (ms) @ 12 players, 3 arenas | ≤ 16 | — | — | — | | | | |
| Live enemies per arena at target heartbeat | 90 fodder + elites | 90 fodder (60 Walkers, 30 Runners) | | | | | | |
| Memory growth (MB/hour, 2-hour soak) | < 50 | — | — | — | — | | | |
| Save failures (unresolved) | 0 | — | — | — | — | | | |
| Rate-limit drops per player-hour (legit play) | < 1 | — | | | | | | |

A2.3 measurement (Studio play on PC, 1 player, TestArena, `Tests/perf/HeartbeatProbe`, D-025 point 10): "heartbeat" = the server step's work, PreSimulation until every Heartbeat handler has run; the Heartbeat frame interval is pinned at 16.67 ms by 60 Hz (p99 18.7 ms). Standing 60 s: work 0.639 avg / 0.838 p99, EnemyService step 0.568 / 0.751, Stats.HeartbeatTimeMs 0.110 / 0.319. Walking 978 studs in 55 s: work 0.735 / 2.501, EnemyService step 0.634 / 2.386 (273 flow-field builds of ~1.5 ms). Snapshot payload 19.1 KB/s per client at 12 Hz (2 packets, 889 + 745 B); A2.8 measures it on the wire.

## Network
| Metric | Target | A2.8 | A5.2 | B4.4 |
|---|---|---|---|---|
| Snapshot + results bandwidth per client @ 90 enemies (KB/s) | ≤ 25 | | | |
| Snapshot rate (Hz) | 10–15 | | | |
| Attack request → result @ 80 ms RTT (ms) | ≤ 150 | | | |

## Client
| Metric | Target | A2.4 | A2.8 | A3.8 | B4.4 (device A) | B4.4 (device B) |
|---|---|---|---|---|---|---|
| FPS PC (90 enemies, 3 auto-weapons) | 60 | 60.0 standing · 60.0 walking (90 enemies, no weapons yet; p99 18.2 ms) | | | | |
| FPS low-end Android (define device: ______) | ≥ 30 | emulation (D-026: Level01 + CPU ×6): 60.0 standing · 60.0 walking; stress ×12: 39.6 | | | | |
| Input → visual feedback (frames) | ≤ 1 | | | | | |
| Join → control, new account (s) | ≤ 15 | — | — | | | |
| Time to first kill, new account, median (s) | ≤ 30 | — | — | | | |
| Time to first card, new account, median (s) | ≤ 60 | — | — | | | |

A2.4 measurement (Studio play on PC with the window in front, 1 player, TestArena, EnemyTest horde of 90; `tools/render_probe.luau`, D-026): PC standing 60 s 60.0 FPS, frame p50 16.63 / p99 18.18 / max 19.81 ms; walking 514 studs 60.0 FPS, p99 18.11 ms; enemy render work 1.68 ms avg / 2.54 p99 standing. Low-end emulation (QualityLevel Level01 + renderer CPU ×6) standing 60.0 FPS, p99 18.58 ms; walking 60.0 FPS, p99 18.26 ms; stress ×12 39.6 FPS, p99 34.67 ms. Pooled rig reuse 2.8 µs vs 110.5 µs build + destroy. No real device captured yet.

## How to measure (scripts live in `ServerStorage/Tests/perf/`)
- `HeartbeatProbe` — samples `RunService.Heartbeat` delta for 60 s, prints avg/p95/p99 and enemy count.
- `BandwidthProbe` — sums `buffer.len` of outgoing snapshots/results per client for 30 s.
- `MemoryProbe` — logs `Stats:GetTotalMemoryUsageMb()` every 60 s; run during soaks.
- `LatencyProbe` — client stamps `RequestAttack.T`; server echoes in `CombatResult`; client prints round-trip percentiles. Use Studio's network simulation (Settings → Network → Incoming Replication Lag) at 100 ms for the RTT target.
- `FunnelProbe` — fresh-account timestamps for `Joined`, `ArenaEntered`, `FirstKill`, `FirstCard` from the console.
- FPS: the `PerfOverlay` flag (A2.4) or Studio `Shift+F5`; `tools/render_probe.luau` for recorded windows (Studio must be in front: a background window renders at 15 FPS); mobile via Roblox app developer stats on the real device.

## Decisions driven by measurements
Record here when a measurement forces a change (link the `DECISION_LOG.md` entry).

| Date | Measurement | Decision |
|---|---|---|
| | | |
