# API CONTRACTS — remotes and domain APIs

## Rules
- A remote exists only if it has a row here, a type guard, and a token-bucket rate.
- Remotes are created in boot phase 8, under `ReplicatedStorage/Net/<Name>`.
- Channels: `R` = RemoteEvent (reliable), `F` = RemoteFunction, `U` = UnreliableRemoteEvent.
- Direction: `C→S` client request, `S→C` server push.
- Rate = sustained per second / burst. Exceeding drops the request and increments `Telemetry.RateLimited`. Three bursts per minute flag the session.
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
| `RequestSettings` | R | `{ Key, Value }` | whitelist of keys | 5 / 10 | A2.1 |
| `ClientHeartbeat` | U | `buffer` `{ Seq, ClientTime }` | — | 20 / 30 | A2.5 |

## Server → Client
| Remote | Ch | Payload | Notes | Since |
|---|---|---|---|---|
| `EnemySnapshot` | U | `buffer`: `[count][ id u16, x f32, y f32, z f32, yaw u8, state u8, hpPct u8 ]...` | 10–15 Hz, interest-filtered per arena | A2.3 |
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
| `FlagsUpdate` | R | `{ [Flag]: Value }` | on change | A1.8 |

## Domain APIs (server-internal)
Documented per domain in `init.luau` headers; this table lists the cross-domain surface only.

| Domain | Public functions (server) |
|---|---|
| Platform | `Flags.Get(name)`, `Config.Get(key)`, `Time.Now()` |
| Telemetry | `Analytics.Funnel(step, userId)`, `Analytics.Economy(...)`, `Errors.Report(err, ctx)` |
| Data | `Profiles.Get(userId) → Profile?`, `Profiles.OnLoaded`, `Admin.Inspect/Grant/Rollback` |
| Economy | `Wallet.Add/Spend(userId, currency, amt, claimId)`, `Inventory.*`, `Loot.Roll(tableId, luck)`, `Transaction.Run(claimId, fn)` |
| Combat | `Combat.ResolveAttack(req)`, `Weapons.Tick(match, dt)`, `Abilities.Activate(...)`, `Hits.Query(match, shape, atTime)` |
| Encounter | `Missions.Start/End`, `Enemies.Spawn/Damage/Kill`, `Protocol.GetMultiplier(match)`, `Upgrades.Offer/Choose`, `Extraction.OpenWindow/Vote`, `Clock.Pause/Resume` |
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
