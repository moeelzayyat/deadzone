# EVENTS — event bus catalog

Code: `ReplicatedStorage/Shared/Events` — `Catalog` (this table as typed schemas plus one exported payload type per event) and `EventBus` (publish/subscribe). Server-side bus; the publisher is the authoritative domain only (architecture §5.3). Consumers (Quests, Codex, Analytics, BattlePass, Leaderboards) never query gameplay state directly. Built in A1.5; details in D-018.

Rules:
- Add or change an event here in the same change that changes `Catalog`. The catalog is checked at require time; a malformed entry fails the boot.
- Payloads carry IDs, numbers and `Vector3` values, never Instances. Types: `string` is non-empty, `number` is finite, `integer` is a whole finite number, `{T}` is an array 1..n, `{[K]: V}` a map, `A | B` one of. Every field is required and no other field is accepted.
- `MatchId` is present on every in-run event (Combat and Encounter publishers; a test enforces it).
- Publisher identities: the ten §5.1 domains plus `Bootstrap` and `Definitions` (the `_Registry`, phase 3). Bootstrap publishes `DefinitionsValidated` under the `Definitions` identity after the Start pass, so subscribers that connect in `Start` receive it (D-019). A service publishes through `EventBus.server():publisher("<Domain>")`; the name in parentheses below is the service inside that domain.
- Misuse — an unknown event, a publish from any domain other than the one listed, or a payload that fails its type — throws `[Events] ...` at the publisher in strict mode (Studio and tests). On live servers the bus reports it to the error handler and drops the event; a bad payload is never delivered.
- Events are fire-and-forget. Each handler runs in its own thread with a frozen copy of the payload: a handler error is reported (warn until `ErrorReportService` takes the error handler) and never reaches the publisher or other handlers; a yielding handler blocks no one. Subscribe in `Start`.
- "Since" is the substage that first publishes the event. Payload shapes for events whose substage is not built yet are provisional; that substage confirms or changes them here and in `Catalog`.

| Event | Payload | Publisher (domain) | Known consumers | Since |
|---|---|---|---|---|
| `BootCompleted` | `{ Phases: integer, Services: {string} }` | Bootstrap | Telemetry | A1.5 |
| `DefinitionsValidated` | `{ Count: integer }` | Definitions registry | Telemetry | A1.6 |
| `PlayerProfileLoaded` | `{ UserId: integer, SchemaVersion: integer, IsNew: boolean }` | Data | Telemetry, Progression | A5.5 |
| `PlayerProfileReleased` | `{ UserId: integer }` | Data | Telemetry | A5.5 |
| `MatchStarted` | `{ MatchId: string, MissionId: string, DifficultyId: string, Participants: {integer} }` | Encounter | Telemetry | A3.1 |
| `EnemySpawned` | `{ MatchId: string, EnemyId: integer, DefId: string, Elite: boolean }` | Encounter | Telemetry (sampled) | A2.3 |
| `EnemyKilled` | `{ MatchId: string, KillerUserId: integer, EnemyId: integer, DefId: string, ProtocolLevel: integer, Position: Vector3 }` | Encounter | XP, Codex, Quests, Telemetry | A2.5 |
| `PlayerDamaged` | `{ MatchId: string, UserId: integer, Amount: number, SourceDefId: string }` | Combat | Telemetry | A2.3 |
| `PlayerDowned` | `{ MatchId: string, UserId: integer }` | Combat | Encounter, Telemetry | A4.7 |
| `XPCollected` | `{ MatchId: string, UserId: integer, Amount: number }` | Encounter | Telemetry (sampled) | A3.2 |
| `PlayerLeveledUp` | `{ MatchId: string, UserId: integer, NewLevel: integer }` | Encounter (XP) | Upgrade, Telemetry | A3.2 |
| `UpgradeOffered` | `{ MatchId: string, UserId: integer, OfferId: string, CardIds: {string} }` | Encounter (Upgrade) | Telemetry | A3.3 |
| `UpgradeChosen` | `{ MatchId: string, UserId: integer, OfferId: string, CardIndex: integer, ResultId: string }` | Encounter (Upgrade) | Codex, Quests, Telemetry | A3.3 |
| `WeaponEvolved` | `{ MatchId: string, UserId: integer, EvolutionId: string }` | Encounter (Evolution) | Codex, Quests, Telemetry | A3.4 |
| `ProtocolChanged` | `{ MatchId: string, NewLevel: integer, MutationIds: {string} }` | Encounter (Protocol) | Telemetry, Codex | A3.5 |
| `ExtractionWindowOpened` | `{ MatchId: string, WindowIndex: integer, ClosesAt: number }` | Encounter (Extraction) | Telemetry | A3.6 |
| `ExtractionVoted` | `{ MatchId: string, UserId: integer, Choice: "Hold" \| "Extract" }` | Encounter (Extraction) | Telemetry | A3.6 |
| `ExtractionResolved` | `{ MatchId: string, WindowIndex: integer, Result: "Hold" \| "Extract" }` | Encounter (Extraction) | Telemetry | A3.6 |
| `BossPhaseChanged` | `{ MatchId: string, BossId: string, Phase: integer }` | Encounter | Telemetry | A4.6 |
| `BossDefeated` | `{ MatchId: string, BossId: string, Participants: {integer} }` | Encounter | Quests, Codex, Telemetry | A4.6 |
| `MissionEnded` | `{ MatchId: string, Outcome: string, ProtocolReached: integer, Multiplier: number, Participants: {integer}, DurationSec: number }` | Encounter | Reward, Campaign, Quests, Leaderboard, Telemetry | A3.6 |
| `RewardsGranted` | `{ UserId: integer, ClaimId: string, Rewards: {Reward} }` | Progression (Reward) | Telemetry, Quests | A5.6 |
| `RewardsPended` | `{ UserId: integer, ClaimId: string }` | Progression (Reward) | Telemetry | A5.6 |
| `CurrencyChanged` | `{ UserId: integer, Currency: string, Delta: integer, Reason: string }` | Economy | Telemetry | B1.4 |
| `ItemGranted` | `{ UserId: integer, InstanceId: string, DefId: string, Source: string }` | Economy | Codex, Telemetry | B1.1 |
| `ItemEquipped` | `{ UserId: integer, InstanceId: string, Slot: string }` | Economy | Telemetry | B1.1 |
| `ItemEnhanced` | `{ UserId: integer, InstanceId: string, NewLevel: integer }` | Facilities (Forge) | Quests, Telemetry | B1.7 |
| `SkillPurchased` | `{ UserId: integer, NodeId: string, Rank: integer }` | Progression | Telemetry | B1.3 |
| `ChestOpened` | `{ UserId: integer, ChestId: string, Results: {string} }` | Economy (Loot) | Telemetry | B1.5 |
| `EggHatched` | `{ UserId: integer, EggId: string, PetDefId: string, Rarity: string }` | Facilities (Egg) | Codex, Telemetry | B3.1 |
| `QuestCompleted` | `{ UserId: integer, QuestId: string }` | Progression (Quest) | Telemetry | B2.6 |
| `CodexDiscovered` | `{ UserId: integer, DefId: string }` | Progression (Codex) | Telemetry | B1.6 |
| `PartyFormed` | `{ PartyId: string, Members: {integer} }` | Social | Telemetry | A5.1 |
| `RaidCompleted` | `{ RaidId: string, Participants: {integer}, Contributions: {[integer]: number} }` | LiveOps (Raid) | Reward, Quests, Telemetry | B3.7 |
| `PurchaseGranted` | `{ UserId: integer, ProductId: integer, ReceiptId: string }` | LiveOps (Purchase) | Telemetry | L1.3 |
| `CodeRedeemed` | `{ UserId: integer, Code: string }` | LiveOps | Telemetry | L1.4 |
| `FeatureFlagChanged` | `{ Flag: string, Value: boolean \| number \| string }` | Platform | all | A1.8 |

`Reward` = `{ Kind: string, Id: string, Amount: integer }` (provisional until A5.6).

## Funnel events (Telemetry → Roblox AnalyticsService)
Not bus events; emitted by `MetricsService` from bus subscriptions. Names are fixed for dashboard continuity.

`Joined` · `ArenaEntered` · `FirstKill` · `FirstCard` · `ProtocolReached_N` · `ExtractionWindow` · `Vote` · `RunEnded` · `RunAgain` · `HubEntered` · `Left`
