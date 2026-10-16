# EVENTS — event bus catalog

Module: `ReplicatedStorage/Shared/Events`. Server-side bus; typed payloads; publisher is the authoritative domain only. Consumers (Quests, Codex, Analytics, BattlePass, Leaderboards) never query gameplay state directly.

Rules:
- Add an event here in the same change that adds it to code.
- Payloads carry IDs and numbers, never Instances.
- `MatchId` is present on every in-run event.
- Events are fire-and-forget; a consumer error must not break the publisher (bus wraps handlers in `pcall` and reports via `ErrorReportService`).

| Event | Payload | Publisher (domain) | Known consumers | Since |
|---|---|---|---|---|
| `BootCompleted` | `{ Phases: number, Services: {string} }` | Bootstrap | Telemetry | A1.4 |
| `DefinitionsValidated` | `{ Count: number }` | Definitions registry | Telemetry | A1.6 |
| `PlayerProfileLoaded` | `{ UserId, SchemaVersion, IsNew: boolean }` | Data | Telemetry, Progression | A5.5 |
| `PlayerProfileReleased` | `{ UserId }` | Data | Telemetry | A5.5 |
| `MatchStarted` | `{ MatchId, MissionId, DifficultyId, Participants: {number} }` | Encounter | Telemetry | A3.1 |
| `EnemySpawned` | `{ MatchId, EnemyId, DefId, Elite: boolean }` | Encounter | Telemetry (sampled) | A2.3 |
| `EnemyKilled` | `{ MatchId, KillerUserId, EnemyId, DefId, ProtocolLevel, Position }` | Encounter | XP, Codex, Quests, Telemetry | A2.5 |
| `PlayerDamaged` | `{ MatchId, UserId, Amount, SourceDefId }` | Combat | Telemetry | A2.3 |
| `PlayerDowned` | `{ MatchId, UserId }` | Combat | Encounter, Telemetry | A4.7 |
| `XPCollected` | `{ MatchId, UserId, Amount }` | Encounter | Telemetry (sampled) | A3.2 |
| `PlayerLeveledUp` | `{ MatchId, UserId, NewLevel }` | Encounter (XP) | Upgrade, Telemetry | A3.2 |
| `UpgradeOffered` | `{ MatchId, UserId, OfferId, CardIds: {string} }` | Encounter (Upgrade) | Telemetry | A3.3 |
| `UpgradeChosen` | `{ MatchId, UserId, OfferId, CardIndex, ResultId }` | Encounter (Upgrade) | Codex, Quests, Telemetry | A3.3 |
| `WeaponEvolved` | `{ MatchId, UserId, EvolutionId }` | Encounter (Evolution) | Codex, Quests, Telemetry | A3.4 |
| `ProtocolChanged` | `{ MatchId, NewLevel, MutationIds: {string} }` | Encounter (Protocol) | Telemetry, Codex | A3.5 |
| `ExtractionWindowOpened` | `{ MatchId, WindowIndex, ClosesAt }` | Encounter (Extraction) | Telemetry | A3.6 |
| `ExtractionVoted` | `{ MatchId, UserId, Choice: "Hold" \| "Extract" }` | Encounter (Extraction) | Telemetry | A3.6 |
| `ExtractionResolved` | `{ MatchId, WindowIndex, Result: "Hold" \| "Extract" }` | Encounter (Extraction) | Telemetry | A3.6 |
| `BossPhaseChanged` | `{ MatchId, BossId, Phase }` | Encounter | Telemetry | A4.6 |
| `BossDefeated` | `{ MatchId, BossId, Participants }` | Encounter | Quests, Codex, Telemetry | A4.6 |
| `MissionEnded` | `{ MatchId, Outcome, ProtocolReached, Multiplier, Participants, DurationSec }` | Encounter | Reward, Campaign, Quests, Leaderboard, Telemetry | A3.6 |
| `RewardsGranted` | `{ UserId, ClaimId, Rewards }` | Progression (Reward) | Telemetry, Quests | A5.6 |
| `RewardsPended` | `{ UserId, ClaimId }` | Progression (Reward) | Telemetry | A5.6 |
| `CurrencyChanged` | `{ UserId, Currency, Delta, Reason }` | Economy | Telemetry | B1.4 |
| `ItemGranted` | `{ UserId, InstanceId, DefId, Source }` | Economy | Codex, Telemetry | B1.1 |
| `ItemEquipped` | `{ UserId, InstanceId, Slot }` | Economy | Telemetry | B1.1 |
| `ItemEnhanced` | `{ UserId, InstanceId, NewLevel }` | Facilities (Forge) | Quests, Telemetry | B1.7 |
| `SkillPurchased` | `{ UserId, NodeId, Rank }` | Progression | Telemetry | B1.3 |
| `ChestOpened` | `{ UserId, ChestId, Results: {string} }` | Economy (Loot) | Telemetry | B1.5 |
| `EggHatched` | `{ UserId, EggId, PetDefId, Rarity }` | Facilities (Egg) | Codex, Telemetry | B3.1 |
| `QuestCompleted` | `{ UserId, QuestId }` | Progression (Quest) | Telemetry | B2.6 |
| `CodexDiscovered` | `{ UserId, DefId }` | Progression (Codex) | Telemetry | B1.6 |
| `PartyFormed` | `{ PartyId, Members: {number} }` | Social | Telemetry | A5.1 |
| `RaidCompleted` | `{ RaidId, Participants, Contributions: {[number]: number} }` | LiveOps (Raid) | Reward, Quests, Telemetry | B3.7 |
| `PurchaseGranted` | `{ UserId, ProductId, ReceiptId }` | LiveOps (Purchase) | Telemetry | L1.3 |
| `CodeRedeemed` | `{ UserId, Code }` | LiveOps | Telemetry | L1.4 |
| `FeatureFlagChanged` | `{ Flag, Value }` | Platform | all | A1.8 |

## Funnel events (Telemetry → Roblox AnalyticsService)
Not bus events; emitted by `AnalyticsService` from bus subscriptions. Names are fixed for dashboard continuity.

`Joined` · `ArenaEntered` · `FirstKill` · `FirstCard` · `ProtocolReached_N` · `ExtractionWindow` · `Vote` · `RunEnded` · `RunAgain` · `HubEntered` · `Left`
