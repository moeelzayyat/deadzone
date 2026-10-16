# TEST PLAN

## Where tests run
| Kind | Runner | When |
|---|---|---|
| Unit | `ServerStorage/Tests/TestRunner` via `execute_luau` | before every checkpoint |
| Integration (mocked services) | TestRunner | before every checkpoint |
| Play test | `start_stop_play` + `get_console_output` (+ `screen_capture`) | every substage with gameplay or UI |
| Security | TestRunner (`tests/security/`) + scripted spam via `execute_luau` | A2.5, A3.3, A5.6, B1.*, B4.3, L1.* |
| Performance | profiler scripts via `execute_luau`; Studio microprofiler; FPS overlay | A2.3/A2.4/A2.8, A4.7, A5.2/A5.8, B2.2, B3.5, B4.4 |
| Migration | TestRunner on `tests/fixtures/profiles/v*.json`-style tables | A5.5 onward, every schema bump |

## TestRunner contract
```lua
local T = require(game.ServerStorage.Tests.TestRunner)
T.describe("StatPipeline", function()
    T.it("sums flat before pct", function()
        T.expect(StatPipeline.Compute(...)).toBe(120)
    end)
end)
T.run() -- prints: suites, passed, failed, duration; lists failures with file:line
```
Supports `beforeEach`, `afterEach`, async `it` via `task.wait`, `toBe`, `toEqual` (deep), `toBeCloseTo(n, eps)`, `toThrow`, `toBeNil`, `toBeTruthy`, `toBeFalsy`, `toBeGreaterThan/LessThan`. Mocks: `T.mock.service(name, impl)` swaps a domain API for the test's duration.

## Coverage by stage (what must exist before the checkpoint)

### A1
- Lifecycle: init-order assertion fires on misordered phases.
- Event bus: subscribe/publish/receive; wrong payload type rejected in strict mode; a throwing handler does not break the publisher.
- Registry: valid set loads; missing required field fails; duplicate ID fails; loot table not summing to 1 fails.
- StatPipeline: one test per `STATS.md` row; all layers combined; every cap; zero/negative; Preview == Compute.
- DamageCalculator: each damage tag vs resistance table; crit path; difficulty mult.
- SimulationClock: tick advances; pause does not advance; resume continues from paused value; scheduled callbacks don't fire while paused.
- Net: token bucket allows N, rejects N+1, refills; codec round-trips every field type including edge values; no remote exists before phase 8.

### A2
- Hit validation: origin tolerance; direction normalization; rewind picks the correct historical position; attack with spoofed origin rejected.
- Dodge: cooldown; distance clamp; i-frame window; 3× speed rejected.
- Weapons: each archetype fires on `SimulationClock` cadence; `MaxTargets` honored; pause stops firing.
- Enemy sim: steering never exceeds MoveSpeed; separation keeps minimum distance; stuck detection relocates.
- Perf: 90-enemy heartbeat script records avg/p99; bandwidth script records bytes/s per client.

### A3
- WaveDirector: never exceeds `MaxAlive`; elite schedule by protocol; pool filtered by `MinProtocol`.
- XP: thresholds; multi-level in one tick queues picks.
- Upgrades: eligible pool respects slots/class tags/protocol gates/maxed; invalid OfferId rejected; stale OfferId rejected; choosing applies exactly once.
- Evolutions: recipe satisfied → offered; not satisfied → never offered; protocol gate respected.
- Protocol: level progression by time and elite kills; multiplier table; mutation application to live enemies.
- Extraction: window open/close; solo choice; payout rules (extract at P3/P5/P7; wipe after hold = 40% of last window; wipe before any window = floor).
- Pause exactness: during pause no enemy position changes, no cooldown decrements, no DoT ticks, no protocol progress (asserted over a simulated 10 s).

### A4
- Abilities: generic activation path for all six signatures; cooldown/resource validation.
- Melee arc hit test with rewind; turret `MaxTargets`; heal cap.
- Boss: phase transitions at thresholds; telegraph durations ≥ 0.6 s; resistances.
- Perf re-measure with all archetypes active.

### A5
- Vote tally: 1–4 voters, ties → Hold, disconnected voters ignored.
- Co-op overlay: auto-pick at deadline; attack disabled during selection; auto-weapons continue.
- Profiles: load defaults; v0→v1 migration fixture; `BindToClose` save; rejoin restores.
- Rewards: same ClaimId twice grants once; pending reward created for disconnect with ≥ 60% presence and granted on next login once.
- Leaderboard submit/read; invite reward once per pair.
- Soak: 2-hour memory growth script.

### B1–B3
- Transactions: fuzz 1000 random ops → no negative balance, no duplicate grants.
- Inventory: equip/unequip idempotent under 50× spam; class tag and slot validation; locked items cannot be salvaged.
- Loot/eggs: 10,000-roll distribution within tolerance of displayed odds; pity triggers at N.
- Skills: prerequisites; respec exact refund; slot unlock affects offers.
- Forge: interrupted commit leaves state unchanged; preview == result.
- Codex/quests: discover/complete exactly once from events; no progress from non-authoritative sources.
- Campaign records only from `MissionEnded`.
- Raid: contribution tracking; single reward per participant; abandoned instance cleanup.

### B4 / L1
- Security suite: remote spam at 50× rate → zero state changes beyond rate; invalid IDs; negative/overflow; duplicate claims; movement teleport/speed; admin remote probing from a non-whitelisted user.
- Receipts: duplicate receipt grants once; failed profile commit → `NotProcessedYet`.
- Codes: once per profile; expiry.
- Migration chain v0→vN on all fixtures; admin rollback restores snapshot.
- Economy simulation: 10,000 runs, 30-day model → no unbounded inflow.

## Play-test scripts (manual, per substage)
Each substage's "Verify via" column in `ROADMAP.md` names the steps. Record: steps run, device(s), console error count, screenshots taken, numbers measured.
