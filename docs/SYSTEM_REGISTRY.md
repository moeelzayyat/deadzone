# SYSTEM REGISTRY

Every approved system. Status: `Planned` · `In Development` · `Implemented` · `Tested` · `Released`. A UI screen is not completion. Items are never removed; new items need a `DECISION_LOG.md` entry. "Target" is the substage where the item is first Implemented.

## Combat and encounter
| System | Target | Status | Notes |
|---|---|---|---|
| Class combat framework | A2.5 | Planned | |
| Primary attacks (6) | A2.5 / A4 | Planned | |
| Dodge abilities (6) | A2.6 / A4 | Planned | |
| Signature abilities (6) | A4.1–A4.4 | Planned | |
| Auto-weapons framework | A2.7 | Planned | archetypes: Projectile, Spread, Orbit (A2); Explosive, Zone, Chain (A3); Pierce, Boomerang, Deployable, Aura (A4+) |
| Weapon levels | A3.4 | Planned | |
| Client prediction + lag compensation | A2.5 | Planned | |
| Enemy simulation (non-Humanoid) | A2.3 | Tested | `Encounter/EnemyService` (`newSim` per arena: table rows on SimulationClock, Spawn → Pursue → Telegraph → Attack → Recover, tiers 1/2/4 steps by distance, stuck teleport to a hidden spawn edge, EnemySpawned); Walker + Runner definitions; 22 tests in `EnemyService.spec`; 90 enemies in play at 0.64 ms avg / 0.84 ms p99 server step work (D-025) |
| Steering / pathing | A2.3 / A4.5 | In Development | A2.3 fodder steering: `Shared/Util/FlowField` (one field per target on the arena grid) + `Shared/Util/EnemySteering` (separation, overlap resolution, wall slide); 9 + 13 tests (D-025). PathfindingService for Brutes/Armored/bosses in A4.5. Grid since A2.2 (D-024) |
| Test arena + collision grid (added A2.2, D-024) | A2.2 | Tested | template `ServerStorage/Arenas/TestArena` (greybox, 152 × 152 studs); grid in `Shared/Definitions/Arenas/TestArena` (76 × 76 cells of 2 studs, 4 spawn edges) exported by `tools/arena_export.luau` from `Shared/Util/ArenaRaster`; `Encounter/ArenaService` checks grid vs template at boot and places copies by slot; 32 tests in `ArenaGrid.spec`, `ArenaRaster.spec`, `ArenaService.spec`; walk test 0 stuck spots |
| Placeholder survivor (added A2.2, D-024) | A2.2 → B4.1 art | Tested | `StarterPlayer/StarterCharacter`: primitives welded to an R15 root, 7 studs, white outline + key light (ART_BIBLE rule 3); 6 tests in `Survivor.spec`; replaced by the A3.5 hero model |
| Enemy snapshot stream (added A2.3, D-025) | A2.3 | Tested | `Shared/Net/EnemySnapshot` (header + 18-byte records, ≤ 49 per packet), `EnemySnapshot` U remote at 12 Hz to subscribed players in the arena (`RequestEnemySnapshots`), `Client/Controllers/EnemyController`; 12 tests in `EnemySnapshot.spec`; 19.1 KB/s payload per client at 90 enemies |
| Client enemy rendering (added A2.4, D-026) | A2.4 | Tested | `Client/Render/EnemyRenderer` + `Render/Lib/{SnapshotInterpolation,EnemyPose,EnemyRigs,RigPool}`: interpolation 2 snapshot intervals behind with a ±10 % render-clock slew, procedural poses per state, pooled primitive rigs (never Humanoids), despawn sink, LOD; `UI/PerfOverlay` (flag PerfOverlay); 27 tests; 90 enemies at 60.0 FPS on PC and under low-end emulation (Level01 + CPU ×6), 0 visible jumps |
| Enemy abilities | A4.5 | Planned | |
| Wave director + spawn budgets | A3.1 | Planned | |
| XP orbs | A3.2 | Planned | |
| Level-up offers (3 cards) | A3.3 | Planned | |
| Solo pause (SimulationClock) | A3.3 | Planned | |
| Co-op card overlay | A5.4 | Planned | |
| Pick queue | A3.2 | Planned | |
| Rarity rolls (luck) | A3.3 | Planned | |
| Evolutions | A3.4 | Planned | |
| Protocol meter + mutations | A3.5 | Planned | |
| Hold/Extract vote + windows | A3.6 / A5.3 | Planned | |
| Bosses (Mutant Alpha + per zone) | A4.6, B2.2, B3.5 | Planned | |
| Results screen + run card | A3.7 | Planned | |

## Progression
| System | Target | Status | Notes |
|---|---|---|---|
| Six classes | A4 | Planned | Sharpshooter A2 |
| Class unlocks (free/level/Serum) | A4.7 / B1.4 | Planned | |
| Inventory + ItemInstance | B1.1 | Planned | |
| Armor + trinkets + affixes | B1.2 | Planned | |
| Skill tree (incl. Squad branch) | B1.3 | Planned | |
| Weapon/passive slot unlocks | B1.3 | Planned | |
| Enhancement + salvage | B1.7 | Planned | |
| Crafting + affix reroll | B3.2 | Planned | |
| Codex | B1.6 | Planned | |
| Leaderboards (OrderedDataStore) | A5.7 | Planned | |

## Economy
| System | Target | Status | Notes |
|---|---|---|---|
| Gold / Serum / Samples | B1.4 | Planned | |
| Event currency | L3.3 | Planned | |
| Gameplay chests + odds + pity | B1.5 | Planned | gameplay currency only |
| TransactionService (idempotent) | B1.1 | Planned | interface in A1 |
| Cosmetic shop | L1.3 | Planned | |

## Pets
| System | Target | Status | Notes |
|---|---|---|---|
| Pet inventory, eggs, odds, hatching, rarity, leveling, equipping, bonuses, companion visuals | B3.1 | Planned | Launch-exit (D-007) |

## World and social
| System | Target | Status | Notes |
|---|---|---|---|
| Hub + Quick Deploy | B2.1 | Planned | |
| Zones 1–3 / 4–6 | B2.2 / B3.5 | Planned | |
| Difficulties | B2.3 | Planned | |
| Parties | A5.1 | Planned | |
| Instanced arenas (same place) | A5.2 | In Development | A2.2: `Encounter/ArenaService:place(arenaId, slot)` clones a template to slot origin (0, 0, 1600) + slot × 400 studs along X, `release` frees it (D-024); per-party assignment and streaming checks in A5.2 |
| Matchmaking (same-server) | B2.4 | Planned | |
| Squad bonuses | A5.3 | Planned | |
| Invite reward | A5.7 | Planned | |
| Pending rewards (disconnect) | A5.6 | Planned | |
| Training arena | B3.3 | Planned | |

## Endgame
| System | Target | Status | Notes |
|---|---|---|---|
| Endless Outbreak | B3.4 | Planned | |
| Gauntlet | post-L3 | Planned | |
| Containment Dungeon | B3.6 | Planned | |
| Raid boss, schedule, matchmaking, contribution, rewards, rotation | B3.7 / L1.5 / L3.5 | Planned | Launch-exit (D-007) |

## Live ops and platform
| System | Target | Status | Notes |
|---|---|---|---|
| Daily / weekly quests | B2.6 | Planned | |
| Achievements | B4 | Planned | |
| Free / premium battle pass | L1.3 | Planned | |
| Events + event chests | L1.4 / L3.3 | Planned | |
| Redeemable codes | L1.4 | Planned | |
| Analytics funnel | A1.8 / A3.9 | In Development | A1.8: `Telemetry/MetricsService` wrapper (funnel/economy/custom → AnalyticsService, server counters), 4 tests in `Telemetry.spec`; funnel events in A3.9 (D-021) |
| Purchase verification (`ProcessReceipt`) | L1.3 | Planned | |
| Remote config + feature flags | A1.8 | Tested | `Platform/RemoteConfigService` (`Config` DataStore, key `Current`, read at boot + every 300 s) and `Platform/FeatureFlagService` (+ `FlagsUpdate` remote, `Client/Controllers/FlagsController`); defaults in `Shared/Config/{Flags,Tunables}`; 14 tests in `Platform.spec` (D-021) |
| Admin tools (inspect/grant/rollback) | L1.2 | Planned | interface in A5.5 |
| Profile migration | A5.5 | Planned | |
| Mobile support | A2.1 onward | In Development | verified every checkpoint. A2.1: touch bindings (dynamic thumbstick, ATTACK/DODGE/ABILITY/AUTO, EXTRACT/HOLD, right-side aim drag), auto-aim + auto-fire defaults (D-023); owner played on a phone and approved A2.1 (2026-10-16) |
| Controller support | A2.1 onward | In Development | verified every checkpoint. A2.1: RT/B/RB/LB, D-pad votes and card focus + A, right-stick aim with 15° assist, LT + right stick camera turn (D-023) |
| Camera + input controller (added A2.1, D-023) | A2.1 | Tested | `Client/Controllers/{InputController,CameraController,AimController}` + `Shared/Util/InputRules` (§2.4 table); 23 tests in `InputRules.spec`; test overlay `Client/UI/InputTestPanel` (flag `InputTestPanel`) |
| Player settings, session (added A2.1, D-023) | A2.1 / A5 | Tested | `Data/SettingsService` + `RequestSettings`; whitelist `Shared/Config/Settings`; 11 tests in `Settings.spec`; persisted in A5 |

## Foundation (A1)
| System | Target | Status | Notes |
|---|---|---|---|
| Domain lifecycle + init order | A1.4 | Tested | `Server/Lifecycle` + one placeholder service per domain; 14 tests in `Tests/unit/Lifecycle.spec` (D-016) |
| Event bus | A1.5 | Tested | `Shared/Events/EventBus` + `Catalog` (37 events typed); 24 tests in `Tests/unit/EventBus.spec`; Bootstrap publishes `BootCompleted` (D-018) |
| Definitions registry + validation | A1.6 | Tested | `Shared/Definitions/_Registry`, 18 folder schemas (4 fixed, 14 provisional), 19 samples; 26 tests in `Tests/unit/Registry.spec`; a bad definition stops the boot in phase 3 (D-019) |
| StatPipeline + DamageCalculator | A1.7 | Tested | `Shared/Stats/{StatRegistry,StatPipeline,DamageCalculator}`; §6 types in `Shared/Types/{Common,Profile,Run,Match}`; 106 + 18 + 4 tests (StatPipeline, DamageCalculator, Types specs); D-020 |
| SimulationClock | A1.8 | Tested | `Server/Domains/Encounter/SimulationClock` (`new()` per match, Pause/Resume/Tick, MaxStep 0.25 s); 11 tests in `SimulationClock.spec` (D-021) |
| Net layer (contracts, buckets, codecs) | A1.8 | Tested | `Shared/Net/{Contracts,Guard,TokenBucket,Codec}` + `Server/Gateway` (remotes in phase 8 only, identity → bucket → guard → handler, session flag); first remote `FlagsUpdate`; 7 + 11 + 7 + 21 + 22 tests; `tools/check_contracts.py` (D-021) |
| Structured error reports (ErrorReportService) | A1.8 | Tested | `Telemetry/ErrorReportService`: `[Error] kind: message` lines, 60 s repeat window, last 50 kept; reporter for Platform, Gateway and the event bus; 4 tests in `Telemetry.spec`. Added by D-021 (an A1.8 deliverable with no registry row) |
| TestRunner | A1.2 | Planned | |
| Git mirror procedure | A1.3 | Planned | |
