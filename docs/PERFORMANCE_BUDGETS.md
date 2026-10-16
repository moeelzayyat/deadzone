# PERFORMANCE BUDGETS

Targets come from `architecture.md` §23. "Measured" columns are filled with real numbers at the named substage; a blank cell means not yet measured. Never write an estimate here.

## Server
| Metric | Target | A2.3 | A2.8 | A4.7 | A5.2 | A5.8 | B4.4 | L1 |
|---|---|---|---|---|---|---|---|---|
| Heartbeat avg (ms) @ 90 enemies, 1 arena | ≤ 8 | | | | | | | |
| Heartbeat p99 (ms) @ 90 enemies, 1 arena | ≤ 16 | | | | | | | |
| Heartbeat p99 (ms) @ 12 players, 3 arenas | ≤ 16 | — | — | — | | | | |
| Live enemies per arena at target heartbeat | 90 fodder + elites | | | | | | | |
| Memory growth (MB/hour, 2-hour soak) | < 50 | — | — | — | — | | | |
| Save failures (unresolved) | 0 | — | — | — | — | | | |
| Rate-limit drops per player-hour (legit play) | < 1 | — | | | | | | |

## Network
| Metric | Target | A2.8 | A5.2 | B4.4 |
|---|---|---|---|---|
| Snapshot + results bandwidth per client @ 90 enemies (KB/s) | ≤ 25 | | | |
| Snapshot rate (Hz) | 10–15 | | | |
| Attack request → result @ 80 ms RTT (ms) | ≤ 150 | | | |

## Client
| Metric | Target | A2.4 | A2.8 | A3.8 | B4.4 (device A) | B4.4 (device B) |
|---|---|---|---|---|---|---|
| FPS PC (90 enemies, 3 auto-weapons) | 60 | | | | | |
| FPS low-end Android (define device: ______) | ≥ 30 | | | | | |
| Input → visual feedback (frames) | ≤ 1 | | | | | |
| Join → control, new account (s) | ≤ 15 | — | — | | | |
| Time to first kill, new account, median (s) | ≤ 30 | — | — | | | |
| Time to first card, new account, median (s) | ≤ 60 | — | — | | | |

## How to measure (scripts live in `ServerStorage/Tests/perf/`)
- `HeartbeatProbe` — samples `RunService.Heartbeat` delta for 60 s, prints avg/p95/p99 and enemy count.
- `BandwidthProbe` — sums `buffer.len` of outgoing snapshots/results per client for 30 s.
- `MemoryProbe` — logs `Stats:GetTotalMemoryUsageMb()` every 60 s; run during soaks.
- `LatencyProbe` — client stamps `RequestAttack.T`; server echoes in `CombatResult`; client prints round-trip percentiles. Use Studio's network simulation (Settings → Network → Incoming Replication Lag) at 100 ms for the RTT target.
- `FunnelProbe` — fresh-account timestamps for `Joined`, `ArenaEntered`, `FirstKill`, `FirstCard` from the console.
- FPS: Studio `Shift+F5` stats overlay; mobile via Roblox app developer stats on the real device.

## Decisions driven by measurements
Record here when a measurement forces a change (link the `DECISION_LOG.md` entry).

| Date | Measurement | Decision |
|---|---|---|
| | | |
