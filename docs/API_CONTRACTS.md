# API CONTRACTS — remotes and domain APIs

## Rules
- A remote exists only if it has a row here, a type guard, and a token-bucket rate, and an entry in `Shared/Net/Contracts` (`python tools/check_contracts.py` compares the two → `MATCH`).
- Remotes are created in boot phase 8, under `ReplicatedStorage/Net/<Name>`, by `Server/Gateway` only; it refuses outside phase 8 (`Lifecycle.currentPhase() == 8`). Before phase 8 `ReplicatedStorage/Net` does not exist (A1.8, D-021).
- Channels: `R` = RemoteEvent (reliable), `F` = RemoteFunction, `U` = UnreliableRemoteEvent.
- Direction: `C→S` client request, `S→C` server push.
- Rate = sustained per second / burst. Exceeding drops the request and increments `Telemetry.RateLimited`. Three bursts per minute flag the session: a burst is one run of drops on one remote, ended when that remote's bucket next accepts a request; the third burst start inside 60 s marks the session (`SessionFlagged`, `Gateway:isFlagged`). Flagging only marks (D-021).
- Server→client rows have no client rate: their inbound bucket is empty, so every client fire on them is dropped and counted as `RateLimited` (reason `direction`).
- Inbound order (§7.1, §19): identity (a Player in this server, exactly one payload argument) → token bucket → payload guard → handler. The handler does the domain checks (state, cooldown, ownership, resources, transaction uniqueness). A rejected `F` request returns nil. Rejections count `Net.Rejected.<reason>` (`unknown`, `identity`, `arity`, `rate`, `direction`, `payload`, `unhandled`); a handler error counts `Net.HandlerError` and is reported.
- Outgoing pushes are checked against the same guard: in Studio a bad push throws; live it is reported, counted (`Net.OutgoingRejected`) and dropped.
- Payloads are plain tables (or `buffer` where noted). The guard rejects wrong types, NaN, inf, out-of-range and oversized payloads before any logic runs.
- The server never trusts: damage, hit lists, enemy health, item IDs chosen by the client, rarity rolls, rewards, timestamps as truth (they are hints for lag compensation, clamped to ≤ 250 ms).

## Client → Server
| Remote | Ch | Payload | Guard summary | Rate (sus/burst) | Since |
|---|---|---|---|---|---|
| `RequestAttack` | R | `{ Seq: u32, T: number, Origin: Vector3, Dir: Vector3, TargetHint: u32? }` | in-run, alive, not selecting; Origin within 6 studs of server pos; Dir normalized | 12 / 20 | A2.5 |
| `RequestDodge` | R | `{ Seq: u32, T: number, Dir: Vector3 }` | cooldown; Dir normalized | 3 / 5 | A2.6 |
| `RequestSignature` | R | `{ Seq: u32, T: number, Dir: Vector3?, Target: Vector3? }` | cooldown, resource | 2 / 3 | A4.1 |
| `RequestUpgradeChoice` | F | `{ OfferId: string, Index: 1\|2\|3 }` | OfferId is the active offer for this player | 3 / 5 | A3.3 |
| `RequestReroll` | F | `{ OfferId: string }` | Rerolls > 0 | 2 / 3 | B1.3 |
| `RequestBanish` | F | `{ OfferId: string, Index }` | Banishes > 0 | 2 / 3 | B1.3 |
| `RequestVote` | R | `{ MatchId, Choice: "Hold"\|"Extract" }` | window open, participant | 4 / 6 | A3.6 |
| `RequestRunAgain` | F | `{}` | in results state | 1 / 2 | A3.7 |
| `RequestQuickDeploy` | F | `{ MissionId?, DifficultyId? }` | in hub, unlocked | 1 / 2 | B2.1 |
| `RequestClassSelect` | F | `{ ClassId }` | unlocked, in hub | 2 / 3 | A4.7 |
| `RequestEquip` | F | `{ InstanceId, Slot }` | owned, slot valid, class tags | 4 / 8 | B1.1 |
| `RequestUnequip` | F | `{ Slot }` | — | 4 / 8 | B1.1 |
| `RequestLockItem` | F | `{ InstanceId, Locked: boolean }` | owned | 4 / 8 | B1.1 |
| `RequestSalvage` | F | `{ InstanceIds: {string} }` | owned, unlocked, ≤ 50 | 2 / 3 | B1.7 |
| `RequestEnhance` | F | `{ InstanceId, ClaimId }` | owned, materials, gold; ClaimId unique | 2 / 3 | B1.7 |
| `RequestCraft` | F | `{ RecipeId, ClaimId }` | recipe valid, materials | 2 / 3 | B3.2 |
| `RequestReroll Affix` | F | `{ InstanceId, AffixIndex, ClaimId }` | samples | 2 / 3 | B3.2 |
| `RequestSkillPurchase` | F | `{ NodeId, ClaimId }` | prereqs, funds | 3 / 5 | B1.3 |
| `RequestRespec` | F | `{ ClaimId }` | gold | 1 / 1 | B1.3 |
| `RequestOpenChest` | F | `{ ChestId, Count: 1\|10, ClaimId }` | currency, inventory room | 2 / 3 | B1.5 |
| `RequestHatchEgg` | F | `{ EggId, Count: 1\|3, ClaimId }` | currency | 2 / 3 | B3.1 |
| `RequestEquipPet` | F | `{ PetInstanceId?, SlotIndex }` | owned | 3 / 5 | B3.1 |
| `RequestPartyCreate` / `Invite` / `Accept` / `Leave` / `Ready` | F | `{ TargetUserId? }` | same server; party ≤ 4 | 2 / 4 | A5.1 |
| `RequestMatchmake` | F | `{ ZoneId, DifficultyId }` | unlocked | 1 / 2 | B2.4 |
| `RequestClaimQuest` | F | `{ QuestId, ClaimId }` | complete, unclaimed | 3 / 5 | B2.6 |
| `RequestClaimPassTier` | F | `{ Tier, Track, ClaimId }` | XP ≥ tier, premium if track | 3 / 5 | L1.3 |
| `RequestRedeemCode` | F | `{ Code: string ≤ 32 }` | — | 1 / 2 (per 10 s) | L1.4 |
| `RequestRaidJoin` | F | `{ RaidId }` | window open, eligible | 1 / 2 | B3.7 |
| `RequestSettings` | R | `{ Key, Value: boolean }`, Key one of AutoAim, AutoFire, CameraRotate (whitelist `Shared/Config/Settings`) | whitelist of keys; boolean value; no other fields. Handler: `Data/SettingsService` stores it for the session (A5 persists, D-023). The client sends at most one per 0.25 s | 5 / 10 | A2.1 |
| `RequestEnemySnapshots` | R | `{}` (an empty table) | empty table only. Handler: `Encounter/EnemyService` marks the player subscribed; EnemySnapshot goes only to subscribed players standing in that arena (an UnreliableRemoteEvent that reaches a client with no handler is discarded with a console error). `Client/EnemyController` sends it once, after connecting its EnemySnapshot handler (D-025) | 1 / 2 | A2.3 |
| `ClientHeartbeat` | U | `buffer` `{ Seq, ClientTime }` | — | 20 / 30 | A2.5 |

## Server → Client
| Remote | Ch | Payload | Notes | Since |
|---|---|---|---|---|
| `EnemySnapshot` | U | `buffer` (`Shared/Net/EnemySnapshot`): header `[seq u16, t f32, count u8]`, then `count` × `[id u16, def u8, x f32, y f32, z f32, yaw u8, state u8, hpPct u8]` (7 + 18 B per enemy). `t` = SimulationClock seconds of the snapshot; `def` = 1-based index into the sorted Enemies Ids; x/y/z = world studs (feet); `yaw` in 256 steps; `state` indexes Spawn, Pursue, Telegraph, Attack, Recover, Stagger, Dying; hpPct 0..100 rounded up. At most 49 enemies (889 B) per packet, under the ~900 B unreliable limit; every packet of one snapshot shares `seq` and `t` (90 enemies = 889 + 745 B) | 10–15 Hz (Tunable `EnemySnapshotHz`, default 12), interest-filtered per arena: only players standing in the arena who sent `RequestEnemySnapshots` (D-025) | A2.3 |
| `CombatResult` | U | `{ Seq, Hits: { {EnemyId, Damage, Crit} } }` | batched per server tick | A2.5 |
| `FxBurst` | U | `buffer`: `[kind u8, x f32, y f32, z f32, arg u8]` | kill pop, explosion, orb pickup | A2.8 |
| `RunState` | R | `RunPlayerState` diff | on change | A3.2 |
| `MatchState` | R | `MatchState` diff | on change | A3.1 |
| `UpgradeOffer` | R | `{ OfferId, Cards: {CardView ×3}, Deadline? }` | | A3.3 |
| `ProtocolUpdate` | R | `{ Level, Progress01, MutationIds }` | | A3.5 |
| `ExtractionWindow` | R | `{ Open, ClosesAt, WindowIndex, Votes }` | | A3.6 |
| `MissionResult` | R | `{ Outcome, ProtocolReached, Multiplier, Rewards, RunCard }` | | A3.7 |
| `ProfileReplica` | R | profile diff | sensitive fields never replicated (`Transactions`) | A5.5 |
| `Notification` | R | `{ Kind, Text, Icon? }` | | A3.7 |
| `LeaderboardUpdate` | R | `{ BoardId, Rows }` | every 60 s | A5.7 |
| `FlagsUpdate` | R | `{ [Flag]: boolean \| number \| string }` (≤ 64 flags, names ≤ 64 B, strings ≤ 200 B) | every Client flag after phase 8 and on join, then only changed Client flags | A1.8 |

## Domain APIs (server-internal)
Documented per domain in `init.luau` headers; this table lists the cross-domain surface only.

| Domain | Public functions (server) |
|---|---|
| Platform | `FeatureFlagService:get(name)`, `RemoteConfigService:get(key)` (A1.8); `Time.Now()` (TimeService, later) |
| Telemetry | `MetricsService:funnel/economy/custom(player, ...)`, `MetricsService:increment(name, amount?)`, `ErrorReportService:report(kind, message, context?)` (A1.8) |
| Data | `Profiles.Get(userId) → Profile?`, `Profiles.OnLoaded`, `Admin.Inspect/Grant/Rollback` |
| Economy | `Wallet.Add/Spend(userId, currency, amt, claimId)`, `Inventory.*`, `Loot.Roll(tableId, luck)`, `Transaction.Run(claimId, fn)` |
| Combat | `Combat.ResolveAttack(req)`, `Weapons.Tick(match, dt)`, `Abilities.Activate(...)`, `Hits.Query(match, shape, atTime)` |
| Encounter | `Missions.Start/End`, `EnemyService.newSim(...)` → `sim:spawn/spawnAtEdge/setTargets/step/snapshot`, `EnemyService:broadcast(sim, players)` (A2.3), `Enemies.Damage/Kill` (A2.5), `ArenaService:grid/place/release` (A2.2), `Protocol.GetMultiplier(match)`, `Upgrades.Offer/Choose`, `Extraction.OpenWindow/Vote`, `SimulationClock.new()` → `match.Clock:Pause/Resume/Tick/Now` (A1.8) |
| Progression | `Rewards.Grant(userId, claimId, rewards)`, `Skills.*`, `Codex.Discover`, `Quests.*`, `Campaign.Record` |
| Social | `Parties.*`, `Matchmaking.*`, `Leaderboards.Submit/Read` |
| Facilities | `Forge.*`, `Pets.*`, `Eggs.Hatch`, `Shop.*` |
| LiveOps | `Events.Active()`, `Seasons.Current()`, `Codes.Redeem`, `Purchases.Process`, `Raids.*` |

### Boot lifecycle (`ServerScriptService/Server/Lifecycle`, A1.4, D-016)
A service is a ModuleScript directly inside its domain folder returning `{ Name = <module name>, Init, Start }` (architecture §5.2 `Service` type, exported as `Lifecycle.Service`).

| Function | Who calls it | Contract |
|---|---|---|
| `Lifecycle.get(name) → Service` | a service, inside its `Init` only | Returns a service whose `Init` already ran (earlier phase, or earlier in name order in the same domain). Anything else is a boot error. Keep the reference for `Start`. |
| `Lifecycle.boot(domainsFolder, hooks?) → Report` | `Server/Bootstrap` only | Plans the domain folders, validates against §5.2, runs every `Init` (phase 3 hook inside), then every `Start`, then the phase 8 hook. |
| `Lifecycle.plan` / `validate` / `run` | Bootstrap and tests | The three steps of `boot`, exposed so tests can build or mutate a plan. |

### Event bus (`ReplicatedStorage/Shared/Events/EventBus`, A1.5, D-018)
Server only. Catalog and payload rules in `docs/EVENTS.md`; `Events/Catalog` holds the schemas and exports one payload type per event.

| Function | Who calls it | Contract |
|---|---|---|
| `EventBus.server() → Bus` | any server module | The one shared bus. Strict in Studio, lenient on live servers. Errors on a client. |
| `bus:publisher(domain) → Publisher` | the publishing service, in `Init` or `Start` | `domain` is one of the ten §5.1 domains, `Bootstrap` or `Definitions`; anything else throws. |
| `publisher:publish(name, payload)` | that service | Publishes only events whose catalog publisher is `domain`. Unknown event, wrong domain or a payload that fails its schema: throws in strict mode, reported and dropped otherwise. Valid payloads go to every subscriber as a deep-frozen copy, each handler in its own thread. |
| `bus:subscribe(name, handler) → Connection` | consumers, in `Start` | Unknown event or non-function handler throws in any mode. `Connection:Disconnect()` is idempotent and takes effect for later publishes and later handlers of the current one. |
| `bus:subscriberCount(name)` | Bootstrap, tests | Number of live subscriptions. |
| `bus:setErrorHandler(fn)` | Telemetry/ErrorReportService (when built) | Receives `(kind, message)` for `unknown_event`, `domain`, `payload` (non-strict) and `handler` errors. Default: `warn`. A failing handler falls back to `warn`. |
| `EventBus.new(options?) → Bus` | tests | A private bus: `strict` (default true), `catalog` (checked; a malformed one throws), `onError`. |

### Definitions registry (`ReplicatedStorage/Shared/Definitions/_Registry`, A1.6, D-019)
Server and client. One ModuleScript per definition, directly inside its folder, returning a table whose `Id` equals the module name; Ids are unique across all 18 folders. Schemas and folder rules live in `_Registry` (CLAUDE.md rule 8).

| Function | Who calls it | Contract |
|---|---|---|
| `Registry.shared() → Registry` | Bootstrap (phase 3), then any module | Loads and validates `Shared/Definitions` once and caches the result. Any problem throws one `[Definitions] N problems ...` error listing all of them; a failed load is not cached. On the server phase 3 runs it, so every later service gets the cached registry. |
| `registry:get(kind, id) → Definition?` | consumers | The frozen definition, or nil for an unknown Id. An unknown folder name throws. |
| `registry:all(kind) → { Definition }` | consumers | Frozen array of the folder's definitions, sorted by Id. |
| `registry.count` | Bootstrap | Number of definitions; published as `DefinitionsValidated { Count }` after the Start pass. |
| `Registry.load(folder)` / `collect(folder)` / `validate(entries, earlier?)` | tests | `load` = `collect` (folder layout, requires) + `validate` (fields, Ids, references, folder rules). Tests run them on clones. |
| `Registry.KINDS` / `Registry.SCHEMAS` | tests | The 18 folder names in §4.3 order and their frozen schemas. |

### Stat pipeline (`ReplicatedStorage/Shared/Stats`, A1.7, D-020)
Server and client (prediction uses the same code). Rows in `StatRegistry` mirror `docs/STATS.md` (`tools/check_stats.py`). Modifiers are `{ Stat, Layer, Value, Source }`; percentages are fractions.

| Call | Caller | Contract |
|---|---|---|
| `StatPipeline.compute(bases, modifiers) → StatBlock` | Combat, Progression, Forge/pet/codex previews | Frozen block with all 25 stats. `bases` holds exactly the Class/Weapon-sourced stats; fixed bases cannot be passed. Throws `[Stats] ...` on unknown stats, disallowed layers, NaN/inf, fractional whole-number values. Never returns NaN. |
| `StatPipeline.stat(id, base?, modifiers) → number` | consumers needing one stat | Same rules, reads only that stat's modifiers. |
| `StatPipeline.preview(bases, modifiers, { Add?, RemoveSources? }) → { Before, After, Delta }` | Forge, equip and pet UI (server-computed or predicted) | Both blocks through `compute`; `Delta` lists only changed stats. |
| `StatPipeline.check(modifier)` / `StatPipeline.get(block, id)` | definitions, tests | Validate one modifier; read a block by id. |
| `DamageCalculator.damage(attackerStats, { WeaponDamage, Crit, Tag, Resistances?, DifficultyMult }) → number` | CombatService (truth), client prediction | §7.3 damage formula; `Crit` is rolled by the server; never negative. Unknown tag throws. |
| `DamageCalculator.mitigate(incoming, armor)` / `armorReduction(armor)` / `resistance(map?, tag)` | Combat | Armor reduction `Armor / (Armor + 100)`, at most 75%; resistance clamps to 0–1, missing = 1. |

### Network layer (`ReplicatedStorage/Shared/Net`, `ServerScriptService/Server/Gateway`, A1.8, D-021)
| Call | Caller | Contract |
|---|---|---|
| `Contracts.list` / `Contracts.get(name)` | Gateway, client controllers | Frozen registry, one entry per existing remote: `{ Name, Channel, Direction, Payload, Rate?, Since }`; a malformed entry fails at require. `get` throws for an unknown name. |
| `Guard.number/integer/boolean/string/literal/vector3/buffer/optional/oneOf/record/empty/array/map` | contracts | Guards `(value) -> (ok, reason?)`; never throw; reject wrong types, NaN/inf, out-of-range, oversized, unknown record fields, sparse arrays, tables with metatables. |
| `TokenBucket.new(sustained, burst, now)` → `bucket:take(now)` | Gateway | Starts full; refills at `sustained`/s up to `burst`; a clock stepping back adds nothing; burst 0 rejects all. |
| `Codec.struct(fields, { maxString? })` / `Codec.list(struct, countType?, maxCount?)` → `encode` / `decode` | high-rate remotes (A2.3 snapshots, A2.5 heartbeat, A2.8 FX) | Types `u8 u16 u32 i8 i16 i32 f32 f64 bool vector3 string`. Encoding a bad value throws `[Codec]`; decoding untrusted bytes never throws and returns nil + reason. |
| `Gateway.server()` | services, Bootstrap | The server's one gateway. `:handle(name, fn)` (client→server, before phase 8, one per remote), `:expose()` (Bootstrap phase 8 only), `:onExposed(fn)`, `:fire(name, player, payload)` / `:fireAll(name, payload)` (server→client, after phase 8), `:isFlagged(userId)`, `:setCounter` (MetricsService), `:setReporter` (ErrorReportService). `Gateway.new(options)` makes private gateways for tests. |

### Input and player settings (A2.1, D-023)
| Call | Caller | Contract |
|---|---|---|
| `InputRules.BINDINGS` / `ROWS` · `schemeOf(inputType, keyCode?)` · `effective(key, explicit, scheme)` · `stickToWorld` · `planeHit` · `resolveAim` · `firing` · `stepFocus` · `activeIn` (`Shared/Util/InputRules`) | InputController, tests | The §2.4 bindings table (ContextActionService inputs and touch buttons per action and context) and pure rules. Device defaults: auto-aim on for touch and gamepad, auto-fire while moving on touch, camera yaw fixed. Aim priority: manual (stick snaps to a target inside 15° when auto-aim is on; the mouse never does) → auto-aim target within 60 studs → move direction → last aim. |
| `InputController.Action` (signal `(action, phase, scheme, arg?)`, phase Begin or End) · `aim()` · `aimSource()` · `isFiring()` · `isMoving()` · `scheme()` · `context()` / `setContext(context)` (Combat, Vote or Cards) · `focus()` / `selectCard(i, scheme?)` · `setting(key)` / `effective(key)` / `setSetting(key, value)` · `setTargetProvider(fn)` · `takeYaw()` (`Client/Controllers/InputController`) | combat (A2.5+), card UI (A3.3), vote HUD (A3.6), CameraController, AimController | The only place input is bound (ContextActionService). Intent only: actions Move, Aim, Primary, Dodge, Signature, VoteExtract, VoteHold, CardFocus, CardSelect, AutoFireToggle. `setSetting` applies locally at once and queues `RequestSettings` (one send per 0.25 s). `setTargetProvider` is the auto-aim hook for the enemy view (A2.3/A2.4). |
| `CameraController.pose(focus, yaw)` · `yaw()` | tests, presentation | Scriptable elevated camera: pitch 55°, distance 44 studs, FOV 50, follow rate 14/s, fixed yaw unless CameraRotate is on. |
| `SettingsService:get(userId, key)` / `:all(userId)` (`Server/Domains/Data/SettingsService`) | any server code | The player's session settings from `RequestSettings`; nil = device default; cleared on leave. Never affects power. |

### Arenas and collision grid (A2.2, D-024)
| Call | Caller | Contract |
|---|---|---|
| `ArenaService:grid(arenaId)` → `ArenaGrid.Grid` (`Server/Domains/Encounter/ArenaService`) | EnemyService steering (A2.3), spawning | The arena's collision grid, built from `Shared/Definitions/Arenas/<Id>` and checked against `ServerStorage/Arenas/<Template>` at boot (a drift stops the boot). Unknown id throws `[Arena]`. |
| `ArenaService:place(arenaId, slot)` → `Placed { Id, Slot, Model, Origin, Grid }` · `:release(placed)` · `:slotOrigin(slot)` · `:toLocal(placed, world)` · `:toWorld(placed, local)` · `:spawnCFrame(placed, character)` | run sessions (A3, A5.2), TestArena harness | Clones the template under `Workspace/Arenas/<Id>_<slot>`, pivot at (0, 0, 1600) + slot × 400 studs along X; a taken or fractional slot throws. Enemies live in arena-local space (origin = floor top centre). |
| `grid:isOpen(x, z)` · `:cellAt(localPos)` → `x?, z?` · `:openAt(localPos)` · `:center(x, z)` → local Vector3 · `:edgeCells(edgeId)` · `:reach(x, z)` → `(visited buffer, count)`; fields `cellSize`, `width`, `depth`, `openCount`, `spawn`, `edges` (`Shared/Util/ArenaGrid`) | steering, stuck recovery, tests | Cells are 1-based, (1, 1) = west/north corner; outside the grid is never open. Grid rules (closed ring, open spawn, all open cells reachable, passages ≥ 2 cells, edges ≥ 8 open cells) hold for every shipped arena (`_Registry`). |
| `ArenaRaster.rasterize(template, cellSize)` · `.diff(def, result)` · `.source(id, template, result)` (`Shared/Util/ArenaRaster`) | `tools/arena_export.luau`, ArenaService boot check | Template → grid: colliding upright parts within 0.25–8 studs above the floor block the cells their footprint overlaps (touching edges excluded). Pure; never writes. |

### Enemy simulation (A2.3, D-025)
| Call | Caller | Contract |
|---|---|---|
| `EnemyService.newSim({ matchId, grid, clock, origin?, definitions?, seed?, publish?, log?, onAttack? })` → `Sim` (`Server/Domains/Encounter/EnemyService`) | run sessions (A3), the EnemyTest harness, tests | One simulation per arena copy, in arena-local space on the arena grid. Enemies are plain table rows (the §8.2 record plus bookkeeping), never Instances. `publish` receives `EnemySpawned`; `onAttack(enemy, targetUserId?)` fires when an attack lands (player damage: A2.6). |
| `sim:spawn(defId, x, z)` · `sim:spawnAtEdge(defId, edgeId?)` → `Enemy` · `sim:remove(id)` · `sim:count()` · fields `Enemies`, `ById`, `Stats` | wave director (A3.1), tests | Unknown definition, blocked cell or unknown edge throws `[Enemy]`. Ids are u16, reused only after release. |
| `sim:setTargets({ { UserId, Position } })` | the match loop | The players in the arena, arena-local. One FlowField per target, rebuilt when its cell changes (at most every 0.2 s). |
| `sim:step() → updated` | the match loop, once per server step after `clock:Tick(dt)` | Reads `clock:Now()`; returns 0 and moves nothing when the clock did not advance (paused). Tiers: ≤ 40 studs every step, ≤ 80 every 2nd, else every 4th. Stuck rule: < 2 studs moved in 4 s while no target within 60 studs → teleport to a hidden spawn-edge cell, logged. |
| `sim:snapshot() → { buffer }` · `EnemyService:broadcast(sim, players) → (packets, bytes)` · `:isSubscribed(userId)` | the match loop | Packs every enemy with world positions (`Net/EnemySnapshot.pack`) and fires each packet to each given player through the Gateway. |
| `EnemySnapshot.pack(seq, t, rows)` / `.unpack(buffer) → (Packet?, reason?)` · `encodeYaw` / `decodeYaw` / `hpPct` / `defIndex` / `stateIndex` · `DEF_IDS`, `STATES` (`Shared/Net/EnemySnapshot`) | server (pack), client (unpack) | Packing a bad row throws `[Snapshot]`; unpacking untrusted bytes never throws. |
| `FlowField.new(grid)` → `:build(x, z)` · `:distance(x, z)` · `:next(x, z)` · `:direction(localPos)` (`Shared/Util/FlowField`) | EnemyService | Dial's algorithm over 8 neighbours: 2 straight, 3 diagonal, +2 into a cell touching a wall, no corner cutting. |
| `EnemySteering.walls(grid)` → `:open` · `:slide(x, z, dx, dz, r)` · `:clear(ax, az, bx, bz)`; `.buckets(size)`; `.separation`; `.resolve`; `.yaw` (`Shared/Util/EnemySteering`) | EnemyService | `slide` pushes a circle out of the deepest blocked cell first (up to 4 passes); a move must be shorter than the radius (EnemyService substeps at 0.5 studs). |
| `PositionRing.new(capacity)` → `:push(t, pos)` · `:latest()` (`Shared/Util/PositionRing`) | EnemyService (`History`), A2.5 rewind | 16 samples per enemy; times never decrease. |
| `EnemyController.enemies()` · `.count()` · `.stats()` (`Client/Controllers/EnemyController`) | A2.4 renderers, auto-aim | The latest record per enemy from EnemySnapshot (late packets ignored by `t`, forgotten after 1 s unseen); feeds `InputController.setTargetProvider` with the nearest enemy within 60 studs. |

### Clock and platform wrappers (A1.8, D-021)
| Call | Caller | Contract |
|---|---|---|
| `SimulationClock.new({ maxStep? })` → `clock:Tick(dt) / Now() / Pause() / Resume()`, field `Paused` | Encounter match loop (A2/A3) | One clock per match; run code reads `match.Clock`, never `os.clock()`. `Tick` adds `min(dt, MaxStep)` (0.25 s) unless paused; bad dt throws `[Clock]`. |
| `FeatureFlagService:get(name)` / `:all()` / `:clientFlags()` / `:apply(map)` | any server code (from Start on); RemoteConfigService | Defaults in `Shared/Config/Flags`; `apply` sets the override set (unlisted flags return to default; bad values reported and ignored); each change publishes `FeatureFlagChanged` and pushes changed Client flags through `FlagsUpdate`. |
| `RemoteConfigService:get(key)` / `:all()` / `:refresh()` | any server code (from Start on) | Defaults in `Shared/Config/Tunables`; the `Config` DataStore key `Current` = `{ Flags?, Tunables? }` is read in Start (phase 0) and every 300 s; a failed read keeps the current values and is reported. Read-only. |
| `MetricsService:increment/counter/counters` · `:funnel/economy/custom` | Gateway (counters), Telemetry consumers (A3.9) | Server counters; the three calls validate and forward to Roblox AnalyticsService (`LogFunnelStepEvent`, `LogEconomyEvent`, `LogCustomEvent`). |
| `ErrorReportService:report(kind, message, context?)` · `:counts()` · `:recent()` | Platform services, Gateway, event bus (error handler) | One `[Error] kind: message · k=v` warning; the same report within 60 s is counted, not reprinted; last 50 kept; counts uncaught script errors (`script`). |
| `FlagsController.get(name)` / `.Changed` | client UI (A2+) | Client copy of Client flags from `FlagsUpdate`, checked with the contract guard. |
