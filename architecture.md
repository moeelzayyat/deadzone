# DEADZONE
## Master Game Architecture & Production Specification

**Document Version:** 2.0 (supersedes v1.0)
**Status:** Approved design baseline — implementation begins at Alpha A1
**Platform:** Roblox (mobile, PC, console)
**Language:** Luau (strict mode where practical)
**Development Environment:** Claude (Roblox Studio MCP) + Roblox Studio + Git mirror
**Architecture:** Server-authoritative, data-driven, event-bus driven, single-place first
**Production Stages:** Alpha → Public Test → Beta → Launch → Live Operations

---

# 0. WHAT CHANGED FROM v1.0 AND WHY

v1.0 was a strong backend blueprint. It did not decide the things that determine whether a Roblox action game is fun and whether anyone finds it. v2.0 keeps every v1.0 principle and adds the missing half:

| Area | v1.0 | v2.0 |
|---|---|---|
| Combat feel | Server-validated only | Client-predicted presentation + server validation + lag compensation (§7) |
| Enemies | Undecided | Non-Humanoid, table-simulated, client-rendered (§8) |
| First session | Hub → menus → teleport → fight | New players spawn **into** a fight; hub unlocks after the first extraction (§3) |
| Signature mechanic | None | **Outbreak Protocol: Hold or Extract** (§2.3) |
| Player contact | Beta B4 | Alpha A3.5 Public Test, within the first 8–10 weeks (§24) |
| Places | Four places via TeleportService | One place through Launch; reserved servers only when CCU demands (§4.4) |
| Services | 32 flat services | 10 bounded domains + typed event bus + explicit init order (§5) |
| Persistence | Hand-rolled session locking | ProfileStore (session-locked) + admin tooling + remote config (§20) |
| Stats | Undefined formulas | Defined stat pipeline with stacking rules (§7.3) |
| Tooling | Optional, Rojo-based | Studio-native via Roblox Studio MCP; Git mirror for backup; in-Studio test runner (§4.2) |
| Art/audio | Not addressed | Defined style, sourcing plan, and asset ownership rules (§22) |
| Growth | Not addressed | Discovery-signal-driven growth architecture (§29) |
| Exit criteria | Opinion-based | Measured, numeric per phase (§24) |
| Monetization | Chests/eggs for currency | Cosmetic-only Robux chests; gear only from play; fairness test (§21) |
| Name collisions | `RunService`, `CollectionService` | Renamed (`MissionSessionService`, `CodexService`) |

Pets, Forge and Raids remain in scope. They are **Launch-exit** requirements, not Beta-exit requirements, so they stop blocking the first real player data.

---

# 1. PROJECT MISSION

DEADZONE is a class-based, cooperative zombie horde survival action RPG for Roblox.

Genre lineage: the "survivor-like" loop (auto-firing weapons, XP orbs, three-card level-ups, weapon evolutions, extraction), proven on and off Roblox. The reference game is *Survive The Swarm [CLASS COMBAT]*. DEADZONE uses only original assets, code, classes, enemies, maps, UI art and names.

## 1.1 The three pillars (unchanged)

1. **Superior combat** — attacks register instantly on the player's screen, dodging matters, classes feel different, bosses reward learning.
2. **Deep progression** — weapons, evolutions, passives, equipment, Forge, pets, skill tree, codex, persistent upgrades.
3. **An evolving apocalypse** — the Outbreak Protocol escalates inside every run; campaign zones, dungeons, raids, seasons escalate across runs.

## 1.2 The viral thesis

A game spreads on Roblox when it scores well on the platform's own per-user signals (playthrough, low first-play bounce, play days, co-play days, qualified sessions) and when players produce clips and invite friends on their own. DEADZONE is engineered for those signals:

- **Click:** a title and icon that show one hero against a horde with upgrade cards in the air.
- **Stay:** first kill within 30 seconds of joining, first upgrade card within 60.
- **Return:** a run is 5–8 minutes; progression, codex and daily objectives (no punishment for missing a day) give a reason for Day 2 and Week 2.
- **Bring friends:** the Hold-or-Extract vote is a shared decision with a shared payoff; squad bonuses, private servers and an invite reward make playing together strictly better.
- **Clip:** the moment the team holds at Protocol 5 with 3 seconds on the extraction timer is the clip.
- **Pay fairly:** cosmetics, battle pass, supporter packs, convenience. No paid power, no paid random gear.

## 1.3 Non-negotiable requirements

- Every gameplay transaction is server-authoritative.
- Every permanent reward is saved through session-locked, versioned profiles.
- Run state never writes to profile state except through `RewardService` at mission end.
- Mobile, PC and console are all first-class; every UI is verified on a phone before a phase exits.
- Multiplayer (4-player co-op) is foundational.
- Non-paying players can reach every gameplay goal. No pay-to-win. No paid random items that affect power.
- No reference-game assets, code or UI artwork. All names and designs are original.
- No anxiety mechanics: no streak wipes, no "you'll lose this" messaging, no countdown pressure aimed at children.
- Development proceeds through gated, measured milestones. No phase exits without its numbers.
- Players touch the game at Alpha A3.5, not at Beta.

---

# 2. GAMEPLAY VISION

## 2.1 Core loop

```text
JOIN
  ↓ (new player: straight into a mission; returning player: hub)
Deploy into outbreak zone
  ↓
Fight the horde — primary attack, dodge, signature, auto-weapons
  ↓
Collect XP → level up → encounter pauses (solo) → choose 1 of 3 cards
  ↓
Outbreak Protocol rises → horde mutates → loot multiplier rises
  ↓
Extraction opens (Protocol 3) → team votes: HOLD or EXTRACT
  ↓
Extract: validated rewards.  Wipe: partial rewards (never zero).
  ↓
Results screen → shareable run card → "Run again" / "Invite"
  ↓
Hub: upgrade gear, skills, codex, pets, Forge → harder content
  ↺
```

Run length target: 5–8 minutes on Normal. A session of three runs fits a 20-minute window.

## 2.2 Four combat capability sources

| Source | Input | Server role |
|---|---|---|
| Primary class attack | Manual | Validates cooldown, origin, direction; computes hits with lag compensation |
| Dodge | Manual | Validates cooldown, distance, i-frame window |
| Signature ability | Manual | Validates cooldown, resource, state |
| Automatic weapons | None (acquired in-run) | Fully server-simulated; client renders |

Every class must feel different in the hands within 10 seconds of play.

## 2.3 Signature mechanic — Outbreak Protocol: Hold or Extract

This is the one element that is only ours. It is built in Alpha A3 and present in the Public Test.

**The meter.** Every mission has an Outbreak Protocol level, 1–7, shown as a large HUD meter with a mutating biohazard icon. It rises on a server clock and jumps on elite kills. Each level does three things at once, all visible:

1. **Mutation** — a new modifier applies to the horde (Runners sprint in packs; Walkers gain armor plates; Spitters spawn; Exploders appear; bosses gain a phase). Modifiers are data-driven (`Definitions/Protocol/`).
2. **Loot multiplier** — mission rewards scale: ×1.0 at P1 up to ×3.0 at P7 (tunable).
3. **Evolution gates** — some evolutions are only offered at P4+, so pushing the protocol unlocks builds you can't get otherwise. The codex shows which.

**The decision.** At Protocol 3 the extraction zone opens for 45 seconds. The team votes on the HUD: **EXTRACT** (bank the current multiplier, mission ends) or **HOLD** (zone closes, protocol keeps rising, zone reopens at P5 and P7). A wipe before extraction pays 40% of what the last open window would have paid, so holding is a real gamble but never a total loss.

Why it works for the signals:
- Playthrough / click: "Hold or Extract" is the icon's second image and the trailer's hook.
- Co-play: the vote is a shared decision; private-server squads argue about it.
- Clips: a P7 extraction with one player alive is inherently clippable.
- Return: P6–P7 evolutions in the codex are the curiosity gate.
- Fair for young players: losing pays partial rewards; nothing is stolen by other players.

`[Assumption — test in A3.5]`: players understand the vote without text; players hold at least once per session.

## 2.4 Camera and controls

Default camera: elevated third-person, slight isometric pitch, fixed yaw by default with optional free rotation on PC/console.

| Action | PC | Mobile | Console |
|---|---|---|---|
| Move | WASD | Left virtual stick | Left stick |
| Aim | Mouse | Auto-aim + optional right stick | Right stick (aim assist) |
| Primary | LMB / hold | Attack button (hold) | RT |
| Dodge | Shift / Space | Dodge button | B / Circle |
| Signature | Q | Ability button | RB / LB |
| Vote | 1 / 2 | Two large HUD buttons | D-pad |
| Card select | Click | Tap | D-pad + A |

Mobile defaults: auto-aim on, auto-fire while moving. The game must be playable one-handed in a pinch. All bindings route through a single `InputController` using `ContextActionService`. Client input is intent; the server decides.

---

# 3. FIRST SESSION DESIGN (FTUE)

Built in Alpha A3. Shipped in A3.5. Measured by first-play bounce.

| Time | What happens | Measured |
|---|---|---|
| 0:00 | Loading screen shows the icon's hero and a single tip ("Kill. Level. Choose."). | Load time |
| 0:05 | New player spawns **directly into a Normal mission** as Sharpshooter, auto-fire on. No hub, no class menu, no party screen. | Time to control |
| 0:10 | A Walker approaches. The first shot lands. Damage number, hit flash, sound. | Time to first kill (target ≤ 30 s) |
| 0:45 | First level-up. Encounter pauses. Three cards slide in. Each card is an icon plus one line, readable without text (weapon silhouette and a +). | Time to first card |
| 2:00 | Second weapon is firing. Protocol hits 2; the horde visibly changes; the meter pulses. | Still playing at 2:00 |
| 3:00 | Protocol 3 — extraction opens. Solo player sees a 2-button prompt. No vote partner yet, so it's a personal choice. | Hold rate |
| 5:00–7:00 | Extract or wipe. Results screen: XP earned, gear found, best card, protocol reached, a one-tap "Run again" and "Invite a friend." | Second run started |
| After run 1 | Hub unlocks with a 10-second guided camera pan: Gear, Skills, Codex, Deploy. | Hub interaction |

Rules:
- Nothing in the first 60 seconds requires reading.
- No tutorial pop-ups that block input. Contextual arrows only.
- The second run is one tap from the results screen.
- Returning players spawn in the hub, with a "Quick Deploy" button that starts a Normal mission in one tap.

---

# 4. TECHNICAL ARCHITECTURE

## 4.1 Core principles

1. Server-authoritative simulation.
2. Client-predicted presentation (feel first, truth second, never truth from the client).
3. Data-driven content with boot-time schema validation.
4. Ten bounded domains, explicit initialization order, typed event bus — no circular imports.
5. Persistent / run / match / client state isolation.
6. Versioned, session-locked profiles.
7. Idempotent economic transactions.
8. Unit and integration tests run in Studio via `TestRunner` before every checkpoint; play tests for Instance behavior.
9. Performance budgets measured, not assumed.
10. Structured telemetry from day one.
11. Backward-compatible progression changes.
12. Milestone-gated development with numeric exit criteria.

## 4.2 Required toolchain (Studio-native)

Roblox Studio is the single source of truth for code and content. Claude works inside it through the Roblox Studio MCP tools: `multi_edit` / `script_read` / `script_grep` for code, `execute_luau` for running tests and admin scripts, `start_stop_play` + `get_console_output` for play tests, `inspect_instance` / `search_game_tree` for the tree, `insert_asset` / `search_asset` for packages and models, `generate_mesh` / `generate_texture` for placeholders, `screen_capture` for UI checks.

| Tool | Purpose | Required from |
|---|---|---|
| Roblox Studio + Studio MCP | Editing, running, testing, publishing | P0 |
| Studio Version History | Restore points; a named restore point is saved at every checkpoint | P0 |
| Git mirror (`/mirror`) | Claude exports every script's source to a Git repo after each checkpoint via `script_read`; backup, diff and review only — never edited by hand and never imported back | A1 |
| `TestRunner` (ModuleScript in `ServerStorage/Tests`) | In-house ~150-line harness: `describe/it/expect`, runs via `execute_luau`, prints a pass/fail table to the console | A1 |
| ProfileStore | Session-locked profiles; inserted from the Creator Store, version recorded in `ART_SOURCES.md` | A1 (insert), A5 (use) |
| Luau `--!strict` | Type checking in Studio's Script Analysis; zero warnings is a checkpoint condition | A1 |
| Studio Script Analysis + Luau linter | Replaces Selene/StyLua; "no warnings" enforced at each checkpoint | A1 |
| Team Create | Enabled so MCP edits and the owner's edits coexist safely | P0 |

Rules:
- No Rojo, Wally, Rokit, Lune or CI in this project. Headless CI is replaced by running the full `TestRunner` suite in Studio before every checkpoint and recording the console output in the handoff report.
- Modules from the Creator Store (ProfileStore, type guard) are inserted once, pinned by version in `ART_SOURCES.md`, and never silently updated.
- No additional frameworks without a `DECISION_LOG.md` entry stating the reason, cost and alternatives.

## 4.3 Project structure

The **Studio place** holds the code and content; the **Git repository** holds documents and a read-only mirror of scripts. The folder layout below is used identically in both: under `ReplicatedStorage/Shared`, `ServerScriptService/Server`, `StarterPlayerScripts/Client` and `ServerStorage/Tests` in Studio, and under `src/` in the mirror.

```text
DEADZONE/   (Git repository)
├── CLAUDE.md                     # operating contract summary for Claude
├── architecture.md               # this document
├── README.md                     # how to open the place, connect MCP, run tests
│
├── mirror/                       # read-only export of Studio scripts, per checkpoint
│   └── src/ (same tree as below)
│
├── docs/
│   ├── ROADMAP.md
│   ├── CURRENT_PHASE.md          # Claude Code reads this before every task
│   ├── SYSTEM_REGISTRY.md
│   ├── DECISION_LOG.md
│   ├── API_CONTRACTS.md          # every remote and every domain API
│   ├── EVENTS.md                 # event bus catalog
│   ├── STATS.md                  # stat pipeline and every stat's stacking rule
│   ├── TEST_PLAN.md
│   ├── PERFORMANCE_BUDGETS.md
│   ├── LIVEOPS_PLAYBOOK.md
│   ├── ART_BIBLE.md
│   └── HANDOFF_REPORT.md
│
├── src/
│   ├── shared/
│   │   ├── Types/                # all exported types
│   │   ├── Definitions/
│   │   │   ├── Classes/  Weapons/  Passives/  Evolutions/  Enemies/
│   │   │   ├── Protocol/  Missions/  Zones/  Loot/  Items/  Skills/
│   │   │   ├── Pets/  Eggs/  Forge/  Quests/  Raids/  Seasons/  Shop/
│   │   │   └── _Registry.luau    # loads, validates, indexes all definitions
│   │   ├── Stats/                # StatPipeline, DamageCalculator
│   │   ├── Net/                  # remote contracts, packet codecs (buffer)
│   │   ├── Events/               # typed event bus
│   │   ├── Config/               # tunables, feature flag defaults
│   │   └── Util/
│   ├── server/
│   │   ├── Bootstrap.server.luau
│   │   ├── Domains/
│   │   │   ├── Platform/   Data/   Economy/   Combat/   Encounter/
│   │   │   ├── Progression/ Social/ Facilities/ LiveOps/ Telemetry/
│   │   └── Admin/                # command console, profile inspector (whitelisted)
│   └── client/
│       ├── Bootstrap.client.luau
│       ├── Controllers/          # Input, Camera, Prediction, Interp
│       ├── UI/                   # Fusion or Roact-style components, one theme file
│       ├── Effects/              # VFX, SFX, damage numbers, screen shake
│       └── Render/               # enemy renderers, projectile renderers, pooling
│
├── tests/                        # ServerStorage/Tests in Studio
│   ├── TestRunner.luau           # describe/it/expect harness, run via execute_luau
│   ├── unit/
│   ├── integration/
│   └── fixtures/profiles/        # v1, v2, ... profile fixtures for migrations
│
└── assets/
    ├── ART_SOURCES.md            # every asset ID, origin, license, owner
    └── icons/ thumbnails/        # source files for store assets
```

## 4.4 Place topology

**One place through Launch.** Hub and mission arenas are in the same place. A mission runs in an isolated arena region of the same server (arenas are instanced per party using CFrame-offset copies from `ServerStorage`, streaming enabled). This removes teleport latency and failure from the first session and from every "Run again."

Server size: 12 players (3 parties of 4). Hub is social; arenas are private to the party.

Reserved-server missions (via `TeleportService:ReserveServer`) are added **only** when hub CCU per server makes arena simulation exceed budget (§23), and only after A3.5 data. Training and Raids may later use separate places; that decision is logged when the need is measured, not before.

---

# 5. DOMAINS, SERVICES AND INITIALIZATION

## 5.1 Ten bounded domains

Each domain owns its state, exposes a documented API, and publishes/subscribes to the event bus. Cross-domain calls go through the API; cross-domain reactions go through events. No domain requires another to boot except in the order below.

| # | Domain | Services inside | Owns |
|---|---|---|---|
| 1 | **Platform** | `RemoteConfigService`, `FeatureFlagService`, `TimeService` | Server time, flags, tunables from DataStore/MemoryStore |
| 2 | **Telemetry** | `MetricsService` (wraps Roblox AnalyticsService), `ErrorReportService` | Funnel, progression, economy events; structured errors |
| 3 | **Data** | `ProfileDataService` (ProfileStore), `MigrationService`, `AdminDataService` | Profile load/save/migrate; admin inspect/repair |
| 4 | **Economy** | `WalletService`, `InventoryService`, `LootService`, `TransactionService` | Currencies, item instances, RNG rolls, idempotent commits |
| 5 | **Combat** | `CombatService`, `WeaponService`, `AbilityService`, `HitValidationService` | Damage, cooldowns, hit checks, lag compensation |
| 6 | **Encounter** | `MissionSessionService`, `EnemyService`, `WaveDirectorService`, `ProtocolService`, `XPService`, `UpgradeService`, `EvolutionService`, `ExtractionService`, `SimulationClock` | Everything inside a run |
| 7 | **Progression** | `ClassService`, `SkillTreeService`, `CodexService`, `QuestService`, `CampaignService`, `RewardService`, `BattlePassService` | Permanent player power and goals |
| 8 | **Social** | `PartyService`, `MatchmakerService`, `SquadBonusService`, `LeaderboardService`, `InviteService` | Parties, matchmaking, leaderboards (OrderedDataStore), invites |
| 9 | **Facilities** | `ForgeService`, `CraftingService`, `PetService`, `EggService`, `ShopService` | Hub facilities |
| 10 | **LiveOps** | `EventService`, `SeasonService`, `CodeRedemptionService`, `PurchaseService`, `RaidService`, `RaidScheduleService`, `DungeonService` | Time-bound content, purchases, endgame modes |

Services are modules inside a domain folder. A domain's `init.luau` exposes the domain API. Services within a domain may call each other directly.

## 5.2 Initialization order

```text
Phase 0  Platform      (flags and config must exist before anything reads them)
Phase 1  Telemetry     (so boot errors are reported)
Phase 2  Data          (profiles; ProfileStore configured)
Phase 3  Definitions   (_Registry validates all content; server refuses to start on failure)
Phase 4  Economy
Phase 5  Progression
Phase 6  Combat → Encounter
Phase 7  Social, Facilities, LiveOps
Phase 8  Network exposure (remotes are created LAST; nothing is callable before all services are ready)
```

Each service implements:

```lua
export type Service = {
    Name: string,
    Init: (self: Service) -> (),   -- resolve dependencies, no side effects
    Start: (self: Service) -> (),  -- connect events, begin work
}
```

Bootstrap asserts that no `Start` runs before every `Init` completes, and logs the full order on boot.

## 5.3 Event bus

`shared/Events` defines typed events. Publishers are the authoritative domain only.

```lua
-- EVENTS.md catalog (excerpt)
EnemyKilled        { MatchId, KillerUserId, EnemyId, ProtocolLevel, Position }
PlayerLeveledUp    { MatchId, UserId, NewLevel }
UpgradeChosen      { MatchId, UserId, OfferId, CardIndex, ResultId }
WeaponEvolved      { MatchId, UserId, EvolutionId }
ProtocolChanged    { MatchId, NewLevel }
ExtractionVoted    { MatchId, UserId, Choice }
MissionEnded       { MatchId, Outcome, ProtocolReached, Multiplier, Participants }
RewardsGranted     { UserId, ClaimId, Rewards }
ItemEnhanced       { UserId, InstanceId, NewLevel }
RaidCompleted      { RaidId, Participants, Contributions }
PurchaseGranted    { UserId, ProductId, ReceiptId }
```

Quests, codex, analytics, battle pass and leaderboards **only** consume events. They never query gameplay state directly. This is what keeps the service graph acyclic.

---

# 6. STATE OWNERSHIP

## 6.1 Persistent profile (schema v1 — all `any` placeholders are forbidden)

```lua
export type PlayerProfile = {
    SchemaVersion: number,
    CreatedAt: number,
    LastSeenAt: number,

    Wallet: {
        Gold: number,
        Serum: number,
        Samples: number,
        Event: {[string]: number},
    },

    Classes: {
        Active: string,
        Unlocked: {[string]: boolean},
        Mastery: {[string]: number},          -- class XP
    },

    Inventory: {
        Items: {[string]: ItemInstance},      -- keyed by InstanceId
        Materials: {[string]: number},
        Consumables: {[string]: number},
    },

    Loadouts: {[string]: Loadout},            -- keyed by ClassId
    Skills: {[string]: number},               -- NodeId -> rank
    Pets: {[string]: PetInstance},
    EquippedPetIds: {string},

    Campaign: {
        HighestZone: number,
        Stages: {[string]: StageRecord},      -- best protocol, best time, clears per difficulty
    },

    Codex: {[string]: boolean},               -- discovered DefinitionIds
    Quests: {[string]: QuestState},
    Raids: {[string]: RaidRecord},
    BattlePass: { SeasonId: string, XP: number, Premium: boolean, Claimed: {[string]: boolean} },
    RedeemedCodes: {[string]: boolean},
    Transactions: {[string]: number},         -- ClaimId -> timestamp (idempotency; pruned after 30 days)

    Stats: { Runs: number, Extractions: number, Kills: number, BestProtocol: number, PlayDays: number },
    Settings: PlayerSettings,
}
```

Never save Instances, functions, enemy references or run state.

## 6.2 Run player state (discarded at mission end)

```lua
export type RunPlayerState = {
    Level: number, XP: number, XPRequired: number,
    Health: number, MaxHealth: number, Downed: boolean,
    Weapons: {[string]: number}, Passives: {[string]: number}, Evolutions: {[string]: boolean},
    WeaponSlots: number, PassiveSlots: number,
    PendingPicks: number, ActiveOfferId: string?, IsSelecting: boolean,
    Kills: number, DamageDealt: number, DamageTaken: number, ElitesKilled: number,
    LastInputSeq: number,
    ComputedStats: StatBlock,   -- recomputed on every change by StatPipeline
}
```

## 6.3 Match state

```lua
export type MatchState = {
    MatchId: string, MissionId: string, DifficultyId: string,
    Participants: {number}, Connected: {[number]: boolean},
    Clock: number,                      -- SimulationClock seconds (pausable)
    Paused: boolean, PauseReason: string?,
    Protocol: number, ProtocolProgress: number,
    Wave: number, Elites: number,
    Extraction: { Open: boolean, ClosesAt: number?, Votes: {[number]: string}, WindowIndex: number },
    Boss: { Active: boolean, Phase: number }?,
    Outcome: "InProgress" | "Extracted" | "Wiped" | "Abandoned",
    RewardMultiplier: number,
}
```

## 6.4 Client presentation state

Open panels, camera, input context, prediction buffers, interpolation buffers, VFX pools, notification queue, card focus. Never authoritative.

---

# 7. COMBAT SYSTEM

## 7.1 Combat pipeline with prediction

```text
CLIENT                                   SERVER
Input (seq N, timestamp T)
  → play animation, muzzle VFX,
    predicted hit spark, SFX         →   RequestAttack {seq, T, origin, dir, targetHint}
    (no damage number yet)               rate limit → state check → cooldown check
                                         → rewind enemies to T (≤ 250 ms) → hit test
                                         → DamageCalculator → apply → EnemyKilled?
  ← CombatResult {seq, hits[], damage[]} (UnreliableRemoteEvent, batched per tick)
  → show damage numbers, kill effects;
    if seq missed: fade predicted spark
```

Rules:
- The client never sends damage, hit lists or enemy health. It sends intent and a timestamp.
- The client renders *predicted* feedback instantly; *authoritative* feedback (damage numbers, kills) arrives from the server. Players perceive the first; they trust the second.
- Server rewinds enemy positions using a 250 ms ring buffer per enemy for hit tests. Clients with higher latency are clamped, not favored.
- Attack origin must be within tolerance of the server's player position; direction is normalized server-side.
- AOE and pierce have hard caps on targets per activation (definition field `MaxTargets`).

## 7.2 Transport

| Traffic | Channel |
|---|---|
| Player requests (attack, dodge, ability, card, vote, equip) | `RemoteEvent` / `RemoteFunction` (reliable) |
| Enemy position snapshots | `UnreliableRemoteEvent`, `buffer`-packed, 10–15 Hz, interest-filtered per arena |
| Combat results, VFX triggers, damage numbers | `UnreliableRemoteEvent`, batched per server tick |
| State changes (HP, level, protocol, votes, offers) | `RemoteEvent` reliable |
| Profile data | Replicated via a single `ProfileReplica` channel on change, diff-based |

Every remote has a per-player token bucket (`API_CONTRACTS.md` lists the rate). Exceeding it drops the request and increments a telemetry counter; three bursts in a minute flag the session.

## 7.3 Stat pipeline (defined now, used everywhere)

Every stat is computed in this order, documented per stat in `STATS.md`:

```text
Final = clamp( (Base + ΣFlat) × (1 + ΣAdditivePct) × ΠMultipliers , Min, Max )
```

| Layer | Sources | Rule |
|---|---|---|
| Base | Class definition, weapon definition | — |
| Flat | Equipment, skill nodes, pets | Sum |
| AdditivePct | Passives, most skill nodes, difficulty, protocol | Sum, then applied once |
| Multipliers | Evolutions, signature buffs, class role modifier | Multiply |
| Caps | Per-stat `Min/Max` in `STATS.md` | Cooldown reduction capped (e.g. 60%); crit chance capped at 100%; move speed capped |

The same `StatPipeline` module computes Forge previews, pet bonuses, codex displays and in-run damage. One source of truth; no formula lives in UI code.

Damage:
```text
Damage = WeaponDamage(level) × ClassDamageMult × (1 + ΣDamagePct) × ΠDamageMults
         × (Crit ? CritMult : 1) × EnemyResistance(tag) × DifficultyMult
```

## 7.4 Automatic weapon archetypes

The `WeaponService` dispatches by `Archetype`:

`Projectile`, `Spread`, `Pierce`, `Explosive`, `Zone` (DoT), `Orbit`, `Chain`, `Boomerang`, `Deployable`, `Aura`.

A1 defines the interface; A2 implements `Projectile`, `Spread`, `Orbit`; A3 adds `Explosive`, `Zone`, `Chain`; the rest follow content needs.

Targeting strategies: `Nearest`, `Random`, `LowestHealth`, `HighestHealth`, `Elite`, `Cursor` (PC/console only).

## 7.5 Classes

| Class | Role | Starter weapon | Dodge | Signature | Unlock |
|---|---|---|---|---|---|
| Sharpshooter | Ranged precision | Tactical Rifle | Combat roll | Piercing Round | Free (default) |
| Juggernaut | Tank | Combat Shotgun | Shoulder charge | Unbreakable (damage immunity + taunt) | Free at player level 5 |
| Stalker | Melee mobility | Dual Machetes | Blink step (short) | Frenzy (attack speed) | Serum |
| Incinerator | Area denial | Flame Projector | Backstep + fire trail | Firestorm | Serum |
| Mechanic | Summons | Nail Launcher | Grapple hop | Defense Turret | Serum |
| Combat Medic | Support | Medical Sidearm | Slide | Healing Pulse | Serum |

Two classes free early so the "which class" decision exists before any currency is earned. Classes are definitions; nothing is hardcoded to a class.

```lua
export type ClassDefinition = {
    Id: string, DisplayName: string, Role: string,
    Base: { Health: number, Speed: number, DamageMult: number, Armor: number },
    StarterWeaponId: string,
    PrimaryAbilityId: string, DodgeAbilityId: string, SignatureAbilityId: string,
    Unlock: { Kind: "Free" | "Level" | "Currency", Value: number?, Currency: string? },
    WeaponTags: {string},          -- which class-weapon tags this class may equip
    Icon: string, Model: string,
}
```

---

# 8. ENEMY SIMULATION

## 8.1 Representation decision (final)

Enemies are **not** Humanoids. Each enemy is a row in a server-side table simulated by `EnemyService` on the `SimulationClock`. Clients receive packed snapshots and render pooled models with interpolation and locally driven animations.

Consequences:
- Hundreds of enemies are feasible; the budget is measured in A2 (§23).
- Pausing an encounter is "stop ticking." The solo level-up pause is trivially correct.
- No physics, no `Humanoid` replication cost, no network ownership headaches.
- Bosses may use richer server-side logic but still are not Humanoids.

## 8.2 Server enemy record

```lua
export type Enemy = {
    Id: number, DefId: string, MatchId: string,
    Pos: Vector3, Vel: Vector3, Yaw: number,
    Health: number, MaxHealth: number,
    State: "Spawn" | "Pursue" | "Telegraph" | "Attack" | "Recover" | "Stagger" | "Dying",
    StateUntil: number, TargetUserId: number?,
    Elite: boolean, Mutations: {string},
    History: PositionRing,     -- for lag compensation
    Tier: number,               -- update frequency tier by distance to nearest player
}
```

## 8.3 Navigation

- Walkers, Runners, Spitters, Screamers, Exploders, Burrowers: **steering** toward target + separation from neighbors + wall slide against a precomputed arena navmesh/collision grid. No per-enemy `PathfindingService`.
- Brutes, Armored, bosses: `PathfindingService` path recomputed at most every 1.5 s, steering between waypoints.
- Arenas are authored so that steering rarely gets stuck; stuck detection teleports an unseen enemy to a valid spawn edge (logged).

## 8.4 Enemy definitions and roster

```lua
export type EnemyDefinition = {
    Id: string, Tier: "Fodder" | "Elite" | "Boss",
    MaxHealth: number, MoveSpeed: number, Radius: number,
    Attack: { Damage: number, Range: number, Cooldown: number, TelegraphTime: number },
    XP: number, Abilities: {string}, Resistances: {[string]: number},
    MinProtocol: number,            -- earliest protocol this enemy may spawn
    Render: { Model: string, Anims: {[string]: string}, Scale: number },
}
```

Roster: Walker, Runner, Brute, Spitter, Screamer, Armored, Exploder, Burrower; bosses Mutant Alpha (A4), then one per zone (names in `docs/CONTENT_BIBLE.md`). Bosses have telegraphed attacks (≥ 0.6 s wind-up), 2–3 phases, and a readable counter. Difficulty never comes from health alone.

---

# 9. ENCOUNTER: WAVES, PROTOCOL, XP, UPGRADES, EXTRACTION

## 9.1 SimulationClock

One pausable clock per match. Everything in a run (enemy ticks, cooldowns, DoT, protocol progress, extraction timers) reads `match.Clock`, never `os.clock()`. Pausing sets `Paused = true`; the clock stops advancing; nothing else needs to know.

## 9.2 WaveDirector

Spawns against a **spawn budget** (`MaxAlive`, `SpawnRate(protocol)`), an enemy pool filtered by `MinProtocol`, and an elite schedule. Mission definition:

```lua
{
    Id = "EvacStreets_01", ZoneId = "EvacuationStreets",
    DurationCap = 480,
    SpawnBudget = { MaxAlive = 90, BaseRate = 1.2, RatePerProtocol = 0.5 },
    EnemyPool = {"Walker", "Runner", "Brute", "Spitter"},
    EliteSchedule = { {Protocol = 2, Id = "Brute"}, {Protocol = 4, Id = "Armored"} },
    BossId = "MutantAlpha", BossAtProtocol = 5,
    ProtocolRate = { SecondsPerLevel = 55, ElitesPerLevel = 3 },
    ExtractionWindows = { {Protocol = 3, Seconds = 45}, {Protocol = 5, Seconds = 40}, {Protocol = 7, Seconds = 35} },
    RewardTable = "Zone1_Normal",
}
```

## 9.3 ProtocolService

Owns the meter. Publishes `ProtocolChanged`. Applies mutation definitions to the WaveDirector and to live enemies. Exposes `GetMultiplier()`. Opens extraction windows via `ExtractionService`.

## 9.4 XP and level-up

XP orbs are server objects with a magnet radius (modified by passives/pets). Thresholds: `XPRequired(level) = floor(base × level^1.35)` (tunable in `Config`). Multiple level-ups queue picks.

## 9.5 Mid-combat upgrade selection

**Solo:** clock pauses. Three cards. Pick applies. Next pending pick or resume.

**Co-op (planned design, test in A5):** the match does not pause. The selecting player gets a **non-blocking card overlay** at the bottom of the screen and keeps moving/dodging but cannot attack; auto-weapons keep firing. A 12-second timer auto-picks the top card. Enemies do not ignore the player. This avoids a frozen teammate in the horde and keeps the match honest. If A5 testing shows this is too punishing, the fallback is a 6-second damage-reduction shield during selection, never full protection.

Offer generation:

```text
XPService → PlayerLeveledUp
UpgradeService builds eligible pool (slots, class tags, protocol gates, maxed items excluded)
RarityRoller picks tiers (luck stat applies)
EvolutionService injects eligible evolution cards (recipe satisfied)
Offer {OfferId, Cards[3]} stored server-side; client receives it
Client → RequestUpgradeChoice {OfferId, Index}
Server validates OfferId is active for that player, applies, publishes UpgradeChosen
```

Card types: new weapon, weapon +1, weapon +2 (rare), new passive, passive +1, evolution, class-specific, reroll token (from skills), banish (from skills).

## 9.6 ExtractionService

Opens a window per the mission definition, broadcasts the vote UI, tallies votes (majority; ties → HOLD; solo → that player's choice), ends the mission on EXTRACT with `RewardMultiplier = GetMultiplier()`. On wipe, `RewardMultiplier = 0.4 × multiplier at last open window` (or 0.25 × P1 multiplier if no window opened). Disconnected players who were present for ≥ 60% of the run receive rewards on next login via a pending-claim record.

---

# 10. WEAPONS, PASSIVES, EVOLUTIONS, CODEX

## 10.1 Weapon definition

```lua
export type WeaponDefinition = {
    Id: string, DisplayName: string, Archetype: Archetype, Rarity: Rarity,
    Damage: {number}, Cooldown: {number}, Range: number, MaxLevel: number,   -- arrays indexed by level
    Projectiles: {number}?, Pierce: {number}?, MaxTargets: number,
    Targeting: Targeting, Tags: {string}, ClassTags: {string}?,
    EvolutionIds: {string}, Render: { Projectile: string?, Fx: string, Sfx: string }, Icon: string,
}
```

## 10.2 Passives

Damage %, attack speed %, max health, regen, crit chance, crit damage, projectile count, pickup radius, XP %, armor, cooldown reduction, luck, move speed. Every passive declares its stat, layer (Flat/AdditivePct/Multiplier) and cap in `STATS.md`.

## 10.3 Evolutions

```text
Tactical Rifle Lv 8 + Voltage Core Lv 5 → Storm Rifle       (any protocol)
Nail Launcher Lv 8 + Shrapnel Lv 5     → Hive Launcher      (Protocol ≥ 4)
Flame Projector Lv 8 + Accelerant Lv 5 → Inferno Engine     (Protocol ≥ 6)
```

Recipes live in `Definitions/Evolutions/`; the server checks eligibility; the codex displays requirements including protocol gates — the protocol gate is the curiosity hook.

## 10.4 Codex (`CodexService`)

Discovered weapons, passives, evolutions, enemies, mutations, pets. Discovery is written from events (`WeaponEvolved`, `EnemyKilled` first time, etc.). Shows protocol requirements. Completion rewards per category.

---

# 11. INVENTORY, EQUIPMENT, ITEMS

```lua
export type ItemInstance = {
    InstanceId: string, DefId: string, Slot: "Weapon" | "Helmet" | "Chest" | "Legs" | "Trinket",
    Level: number, Rarity: Rarity, Xp: number, Locked: boolean, AcquiredAt: number,
    Affixes: {Affix}?,
}
```

Operations (server-only): add, remove, equip, unequip, lock, salvage, enhance, preview. Equip validates class tags and slot. Every mutation runs inside `TransactionService:Run(claimId, fn)` which guarantees single application and never leaves a negative balance.

Gear comes from play: mission rewards, codex rewards, quests, Forge. Robux never buys gear or gear chests (§21).

---

# 12. FORGE AND CRAFTING (Launch-exit)

Enhance (consume materials + gold; preview uses `StatPipeline`), salvage duplicates → materials, craft from recipes, reroll one affix (Samples). Locked items cannot be consumed. All recipes in `Definitions/Forge/`. Flow: UI → `ForgeService` → recipe validation → `TransactionService` → updated item → `ItemEnhanced` event.

---

# 13. PETS AND COMPANIONS (Launch-exit)

Original drones and animals: Medical Drone, Recon Drone, Robo Dog, Combat Drone, Shield Drone, Bio-Scanner. Eggs are bought with **gameplay currencies only**; odds published on the egg; pity counter after N hatches without the top rarity (disclosed). Pet bonuses go through `StatPipeline` (Flat/AdditivePct layers, capped). Companion following is client cosmetic. Pets level with mission XP.

---

# 14. SKILL TREE

Directed graph of `SkillNode { Id, Prereqs, MaxRank, Cost(rank), Effect }`. Branches: Survival, Firepower, Fortune (luck, rerolls, banish), Squad (bonuses that only apply with ≥ 2 players — a co-play incentive). Weapon/passive slot unlocks live here. Respec costs Gold, scaling, never Robux.

---

# 15. LOOT

Server-side RNG; tables normalized at boot (registry rejects tables that don't sum to 1); results committed with the grant in one transaction; client animation plays the confirmed result. Mission reward tables scale by `RewardMultiplier` (protocol) and difficulty. Daily first-extraction bonus (no penalty for missing days).

---

# 16. CAMPAIGN, DIFFICULTY, PARTY, MATCHMAKING

Zones: Evacuation Streets → Quarantine Hospital → Industrial District → Research Facility → Fallen Military Base → Epicenter. Each zone: unique enemy pool, mutations, boss, palette and music. Difficulties: Normal, Hard, Nightmare, Cataclysm — each changes composition, protocol rate, boss phases and modifiers, not only health.

Party: 1–4, leader, ready state, Quick Deploy, public matchmaking by zone/difficulty via `MemoryStoreService` queues within the server first (same-server fill), cross-server only when reserved servers exist. Disconnect handling and pending rewards per §9.6.

**Squad bonuses (co-play incentive):** +10% XP per additional party member, shared extraction multiplier, a Squad skill branch. Invite reward: both players receive a cosmetic after their first shared extraction (one-time, no pressure).

---

# 17. ENDGAME: DUNGEONS, ENDLESS, RAIDS

All modes implement `IEncounterMode` (start, tick, end, rewards) on top of the same Encounter domain. Endless Outbreak (protocol uncapped, leaderboard), Gauntlet (chained bosses), Containment Dungeons (modifiers + loot pools), Raids (scheduled, 8–12 players, phases, contribution tracking, weekly rewards; `RaidService` + `RaidScheduleService`, server time only, idempotent claims, cleanup of abandoned instances). Raid foundation in B3; first full raid is a Launch-exit requirement.

---

# 18. QUESTS, EVENTS, BATTLE PASS, CODES

Quests consume events only. Daily (3) and weekly (3) objectives; missing a day costs nothing. Events: data-driven, time-windowed by server time, own currency, cleanup on expiry. Battle pass: free and premium tracks, premium entitlement validated via `MarketplaceService` receipts, claims idempotent. Codes: single-use per profile, expiry, server-validated.

---

# 19. NETWORK SECURITY

Every request validates: identity, payload types (`t` or hand-written guards), state eligibility, cooldown, rate limit, ownership, resources, transaction uniqueness. Remotes are created only after all services start. Admin commands are a separate whitelisted channel, never ordinary remotes. Movement sanity: max displacement per tick with dodge allowances; violations rubber-band and log. Security test suite in §26.

---

# 20. DATA PERSISTENCE

- **ProfileStore** for session locking, auto-save, `BindToClose`, retry/backoff.
- `MigrationService` runs migrations `v → v+1` in order; every version has a fixture in `ServerStorage/Tests/fixtures/profiles/`; `TestRunner` runs all migrations on all fixtures at every checkpoint.
- `TransactionService:Run(claimId, fn)`: validate → commit; `claimId` recorded in `profile.Transactions`; duplicate → return previous result.
- `AdminDataService`: inspect, diff, grant, revoke, rollback to last snapshot (snapshots kept 7 days in a secondary DataStore). You will need this the first week after launch.
- Leaderboards: `OrderedDataStore` (Best Protocol, Endless depth, weekly extractions), refreshed every 60 s per server.
- Remote config: a `Config` DataStore read at boot and polled every 5 min; feature flags gate events and experiments without a republish.
- Never overwrite newer data with an older session's data (ProfileStore guarantees; migrations preserve acquired rewards).

---

# 21. ECONOMY AND MONETIZATION

## 21.1 Currencies
Gold (general), Serum (classes, respec, advanced), Samples (Forge rerolls, crafting), Event currency (time-boxed). All earned from play. None purchasable directly with Robux.

## 21.2 What Robux buys
- Cosmetics: skins for classes, weapon VFX colors, extraction flares, emotes, name tags.
- Battle pass premium track (cosmetics + bonus currency; nothing exclusive to power).
- Supporter packs (cosmetic bundle + a thank-you badge).
- Convenience that does not gate the loop: extra loadout slots, Quick Deploy skip of hub pan, inventory tabs. No paid sprint, no paid revive, no paid rerolls in-run.
- Private servers (Roblox standard).

## 21.3 What Robux never buys
Gear, gear chests, eggs with stat pets, in-run power, XP boosts that exceed what Squad bonuses give, protocol multipliers.

## 21.4 Fairness test (answered)
1. Non-payers can reach every goal — yes, by design.
2. Can a payer beat a non-payer in direct competition — no PvP; leaderboards count only gameplay stats, and nothing paid affects them.
3. Parent over the shoulder — every prompt is a cosmetic with a price; no chance purchases.
4. Odds clear — all egg/chest odds (gameplay-currency only) displayed before opening.

## 21.5 Compliance
Age-rating questionnaire answered accurately (fantasy violence, no gore). Paid-random-item policies re-checked on the Creator Hub before B1. Receipts processed with `ProcessReceipt`, idempotent, granted only after profile commit.

---

# 22. ART, ANIMATION, AUDIO PIPELINE

Claude Code writes code; it does not produce a zombie walk cycle. This pipeline is a hard dependency named here so it is never "later."

**Style:** low-poly stylized with strong silhouettes and saturated palettes per zone; readable on a 6-inch phone at the default camera distance. Zombies are distinct by silhouette and color before detail. No realistic gore (age rating and parent acceptance).

**Sourcing plan, in order:**
1. Alpha A1–A3: placeholder primitives and Studio-generated meshes/textures; procedural animation (code-driven bob/lunge) so combat can be tested without an animator.
2. A3.5 Public Test: one hero model, three enemy models, one arena, licensed Creator Store audio. Commission or acquire licensed packs; record every asset in `assets/ART_SOURCES.md` with license and owner.
3. Beta: contracted 3D artist and animator for six classes, roster, bosses, zones; UI artist for icons and cards. Budget line in `ROADMAP.md`.

**UI:** one theme module (colors, type scale, rarity colors), component library (Fusion recommended; decision logged), every screen verified at 360×640 and on a controller before phase exit.

**Juice checklist (A2 exit):** hit flash, damage numbers, screen shake (scaled, toggleable), kill pop, XP orb magnet sound, level-up sting, protocol-up stinger, extraction siren.

---

# 23. PERFORMANCE BUDGETS (measured, not assumed)

| Metric | Target | Measured at |
|---|---|---|
| Server heartbeat | ≤ 8 ms avg, ≤ 16 ms p99 at 12 players / 3 arenas | A2, A5, B4 |
| Live enemies per arena | 90 fodder + elites at target heartbeat | A2 (set), A5 (confirm) |
| Snapshot bandwidth | ≤ 25 KB/s per client at 90 enemies | A2 |
| Client FPS | 60 PC; 30 low-end Android (define device) | A2, A3.5 |
| Input → visual feedback | ≤ 1 client frame | A2 |
| Attack round-trip (request → result) | ≤ 150 ms at 80 ms RTT | A2 |
| Memory growth | < 50 MB/hour server over a 2-hour soak | A5, B4 |
| Save failure rate | 0 unresolved; retries logged | A5 onward |
| Join → control (new account) | ≤ 15 s | A3 |
| Time to first kill (new account) | ≤ 30 s median | A3.5 |

Techniques: tiered update rates by distance, interest filtering per arena, object pooling (measured), `buffer` packing, cosmetic effects client-only, bounded particle counts on mobile.

---

# 24. DEVELOPMENT LIFECYCLE

Every phase exits only with: functional tests passing, integration checks, security checks, performance numbers met, architecture review, owner approval, handoff report. **No phase exits on opinion.**

## ALPHA

### A1 — Foundation (target: 1–2 weeks)
Deliverables: Studio layout, TestRunner, Git mirror, domain skeleton with init order, event bus, `_Registry` with validation, shared types (all of §6), `StatPipeline` with tests, `SimulationClock`, network layer (contracts, token buckets, `buffer` codecs), `MetricsService` + `ErrorReportService` wrappers, `RemoteConfig`, docs scaffold.
Exit: TestRunner green with zero Script Analysis warnings; boots in Studio with ordered log and zero errors; a bad definition fails boot; `StatPipeline` tests cover every layer and cap; README setup works on a clean machine.

### A2 — Combat Feel (2–3 weeks)
Deliverables: camera, `InputController` (all three platforms), Sharpshooter primary with prediction + lag compensation, dodge with i-frames, `Projectile`/`Spread`/`Orbit` auto-weapons, non-Humanoid `EnemyService` with Walker + Runner, steering, snapshots + client interpolation, pooled renderers, juice checklist, one test arena.
Exit: all A2 budget rows in §23 met and recorded; 90 enemies alive; attack feels instant on a phone over a 100 ms simulated RTT; server owns every kill.

### A3 — Run Progression, Protocol, FTUE (3 weeks)
Deliverables: `WaveDirector` with spawn budgets, XP orbs, leveling, solo pause, three-card offers, pick queue, 8 weapons / 8 passives, 2 evolutions, `ProtocolService` with 7 levels and 5 mutations, `ExtractionService` with Hold/Extract (solo), results screen with "Run again" and run card, FTUE (§3), minimal run-counter persistence.
Exit: new account reaches first kill ≤ 30 s and first card ≤ 60 s in 5/5 internal tests; pause is exact (no DoT tick, no cooldown drift); 3 queued picks resolve correctly; extraction and wipe pay per §9.6.

### A3.5 — PUBLIC TEST (1 week prep, 2–3 weeks live)
Publish the A3 build as an unlisted-then-listed experience with a provisional icon and title (§29). One class, one arena, Walker/Runner/Brute, Protocol, Hold/Extract. Telemetry funnel live. Two icon variants and two onboarding variants via feature flags.
Exit (go/no-go for A4): median time to first kill ≤ 30 s; ≥ 50% of new players start a second run; ≥ 30% of extraction windows see at least one HOLD; first-play bounce (<60 s) trending down across the three weeks. If the second-run rate is < 30% after two iterations, stop and revisit the loop before A4.

### A4 — Classes and Bosses (4 weeks)
Six classes, signatures, full fodder roster, Mutant Alpha with phases, mission objectives, victory/defeat flows, Juggernaut unlock at level 5.
Exit: every class extracts on Normal in internal play; boss telegraphs read on a phone; no class breaks run progression; A2 budgets still met with all archetypes active.

### A5 — Multiplayer and Persistence (4 weeks)
Parties of 4, same-server arenas, enemy scaling, co-op card overlay (§9.5), vote tallies, ProfileStore profiles with schema v1 and migration harness, `RewardService` with idempotent claims, pending rewards for disconnects, squad bonuses, invite reward, leaderboards.
Exit: four players extract; a player picking a card does not stall the match; duplicate reward claims rejected in tests; profile survives reconnect and server shutdown; 2-hour soak meets memory budget.

## BETA

### B1 — Persistent Progression (4 weeks)
Full inventory, equipment, armor, skill tree, currencies, gameplay chests with published odds, codex, Forge core (enhance, salvage).
Exit: equipment persists and is reflected by `StatPipeline`; no transaction duplicates under spam tests; migration fixtures pass; Forge previews equal in-run values.

### B2 — Hub and Campaign (3 weeks)
Hub with facilities, Quick Deploy, three zones with difficulties, matchmaking, campaign progression, daily/weekly quests.
Exit: full hub → mission → hub loop in one place; solo and party deployment; quest events fire from authoritative sources only.

### B3 — Facilities and Endgame Foundation (5 weeks)
Pets and eggs (gameplay currency), Forge crafting and reroll, training arena, Endless Outbreak, first dungeon, raid foundation with one functional raid boss, remaining zones.
Exit: pets grant bonuses through `StatPipeline`; egg odds match definitions in a 10k-roll test; one raid completes with contribution tracking.

### B4 — Closed Beta (4 weeks)
UI integration pass on phone/controller, onboarding refinements from data, anti-exploit suite, performance soak, analytics dashboards, 50–200 invited testers.
Exit: no release-blocking bugs; testers navigate progression unassisted; Week-1 return rate and co-play rate recorded as the launch baseline.

## LAUNCH

### L1 — Release Candidate (3 weeks)
Economy balance pass from beta data, data audit, purchase validation, battle pass season 1, codes, support/moderation process, rollback plan, final icon/title/thumbnails/trailer, creator outreach list.
Exit: save integrity confirmed; purchases and claims tested end to end; Pets, Forge and at least one Raid are complete and tested (Launch-exit requirements); checklist approved.

### L2 — Public Release
Listed, sponsored diagnostics run (ads give data, not ranking), live dashboards, daily hotfix window, weekly update cadence begins.
Exit: stable matchmaking; no progression exploits; D1 and D7 play days monitored.

### L3 — Season 1 (6–8 weeks after L2)
New zone, seasonal gear (cosmetic-forward), limited event with its currency, raid rotation, new boss, pass season 2.
Exit: seasonal content integrates without profile loss; live updates don't break progression.

---

# 25. SYSTEM COMPLETENESS REGISTRY

Status values: `Planned` / `In Development` / `Implemented` / `Tested` / `Released`. A UI screen is not completion.

**Combat and encounter:** class combat · primary attacks · dodge · signatures · auto-weapons · weapon levels · prediction + lag compensation · enemy simulation · steering/pathing · enemy abilities · wave director · spawn budgets · XP orbs · level-up offers · solo pause · co-op overlay · pick queue · rarity rolls · evolutions · protocol meter · mutations · Hold/Extract vote · extraction windows · bosses · results screen · run card

**Progression:** six classes · class unlocks · inventory · armor · trinkets · skill tree · slots · enhancement · salvage · crafting · affix reroll · codex · leaderboards

**Economy:** Gold · Serum · Samples · event currency · gameplay chests · odds display · pity · transactions · shop (cosmetic)

**Pets:** pet inventory · eggs · odds · hatching · rarity · leveling · equipping · bonuses · companion visuals

**World and social:** hub · Quick Deploy · zones · difficulties · matchmaking · private parties · squad bonuses · invite reward · pending rewards · training arena

**Endgame:** Endless · Gauntlet · dungeons · raid boss · raid schedule · raid matchmaking · contribution · raid rewards · rotation

**Live ops:** daily/weekly quests · achievements · free pass · premium pass · events · event chests (gameplay currency) · codes · analytics · purchase verification · remote config · feature flags · admin tools · profile migration · mobile · controller

New systems may be added; approved systems are never silently dropped.

---

# 26. TESTING STRATEGY

**Unit (`TestRunner` in Studio via `execute_luau`, before every checkpoint):** StatPipeline every layer/cap; DamageCalculator; XP thresholds; offer eligibility; evolution recipes; loot normalization and 10k-roll distributions; skill prerequisites; Forge validation; pet bonuses; protocol multiplier; extraction payout rules; vote tally; codec round-trips; migrations on every fixture.

**Integration (`TestRunner` with mocked services in Studio, plus play-test mode):** kill → XP → offer → pick → stat change; extraction → reward claim once; disconnect → pending reward; egg → valid pet; raid → single reward; mission → campaign record.

**Studio manual (per phase):** camera, controls on phone/controller, snapshot interpolation smoothness, pause exactness, telegraph readability, UI at 360×640.

**Security (automated where possible):** remote spam at 50×rate; invalid OfferIds; forged InstanceIds; negative/overflow amounts; duplicate claims; teleport/speed; attack origin spoofing; admin remote probing.

**Performance:** 90-enemy arena soak, 3-arena server soak, 2-hour memory soak, mobile FPS capture.

---

# 27. CLAUDE CODE OPERATING CONTRACT

Claude Code implements. The project owner decides product. Architecture reviews and phase acceptance follow this document and `docs/CURRENT_PHASE.md`.

1. Read `architecture.md` and `docs/CURRENT_PHASE.md` before any implementation task.
2. Implement only the current phase; account for future dependencies through interfaces, not code.
3. Never replace an architectural decision in §0, §4.4, §5, §7, §8 or §21 without a logged decision and owner approval.
4. Never remove a registry item.
5. Never trust client damage, hits, rewards, item IDs, rarity rolls or timestamps as truth.
6. Every new remote gets a contract entry, a rate limit and a guard before it is created.
7. Every new stat gets a `STATS.md` row (layer, cap).
8. Every new definition type gets registry validation.
9. Write tests for logic; run them; report exactly what ran.
10. Do not claim Studio verification without running a play test and reading the console; do not claim tests green without pasting the TestRunner summary.
11. Update `API_CONTRACTS.md`, `EVENTS.md`, `STATS.md` in the same change that alters them.
12. Small reviewable commits grouped by behavior; no mixed refactors.
13. Stop and ask when a change affects scope, budgets, monetization or data schema.
14. Keep `assets/ART_SOURCES.md` current for every asset ID used.
15. Prefer reusable modules; avoid speculative abstraction.

## 27.1 Handoff format (after every task)

```text
PHASE / TASK:
FILES CREATED / MODIFIED:
IMPLEMENTED BEHAVIOR:
CONTRACT CHANGES (remotes, events, stats, definitions):
TESTS RUN (command + result) / NOT RUN:
STUDIO VERIFICATION / NOT YET VERIFIED:
BUDGET MEASUREMENTS (if applicable):
SECURITY NOTES:
KNOWN ISSUES:
DEVIATIONS FROM ARCHITECTURE (with DECISION_LOG reference):
NEXT RECOMMENDED TASK:
```

---

# 28. INITIAL ASSIGNMENT — ALPHA A1

1. Create the Studio folder layout in §4.3 (`ReplicatedStorage/Shared`, `ServerScriptService/Server`, `StarterPlayerScripts/Client`, `ServerStorage/Tests`); enable Team Create; insert ProfileStore from the Creator Store and record its version.
2. Build `TestRunner` and the Git-mirror export procedure; save the first named restore point.
3. Domain skeleton (§5.1) with `Init`/`Start` lifecycle and asserted init order (§5.2); boot log.
4. Typed event bus with the `EVENTS.md` catalog started.
5. `_Registry` loading all `Definitions/*` with schema validation and duplicate-ID detection; one sample definition per folder.
6. All types in §6 (no `any`).
7. `StatPipeline` + `DamageCalculator` with full unit tests; `STATS.md` seeded with every stat in §10.2.
8. `SimulationClock` with pause/resume tests.
9. Network layer: contract registry, token buckets, `buffer` codec helpers, remotes created in Phase 8 only.
10. `MetricsService`, `ErrorReportService`, `RemoteConfigService`, `FeatureFlagService` wrappers.
11. `docs/CURRENT_PHASE.md` = A1, `README.md` setup, first `HANDOFF_REPORT.md`.

Do not build combat, enemies, upgrades, inventory, pets, Forge, raids or UI beyond a boot HUD in A1.

**A1 is complete when** the full `TestRunner` suite passes in Studio with zero Script Analysis warnings, Studio boots with an ordered log and zero errors, a deliberately broken definition fails boot, and `StatPipeline` tests pass on every layer and cap.

---

# 29. GROWTH ARCHITECTURE (DISCOVERY AND VIRALITY)

Roblox recommends per-user, not by size, so a small game competes on quality signals. Each signal has an owner in this architecture:

| Official signal | What drives it here | Where measured |
|---|---|---|
| Playthrough rate | Icon shows hero vs horde + cards; title states the promise | A3.5 icon A/B via sponsored diagnostics |
| First-play bounce (<60 s, 61–180 s) | Spawn into combat; first kill ≤ 30 s; card ≤ 60 s; no teleport | Funnel events `JoinedArena`, `FirstKill`, `FirstCard`, `Left` |
| Play days D1 / D2–7 / D8–28 | Daily first-extraction bonus (no punishment), codex gates at P4+/P6+, quests, weekly updates | `PlayDays` in profile + Analytics |
| Playtime (capped 60 min/day) | 5–8 minute runs; "Run again" one tap; don't chase longer sessions | Session telemetry |
| Co-play days | Squad bonuses, shared vote, invite reward, private servers, Squad skill branch | Party size per run; invites accepted |
| Qualified sessions | Fast join; arena in the same place | Session length distribution |
| Spend days / Robux per user | Cosmetics people want to show; battle pass; never pressure | Receipts |

**Title and icon (A3.5 variants):**
- Title A: `DEADZONE 🧟 Hold or Extract` — Title B: `DEADZONE: Zombie Horde Survival` — the bracket/emoji tag rotates with updates (`[NEW CLASS]`), standard Roblox practice.
- Icon: one survivor silhouette dead center, horde pressing from the edges, three glowing upgrade cards above the head, the Protocol meter at the bottom. Test two palettes. Show action, never a logo.
- Thumbnails 16:9: the P7 extraction, the card choice, four classes together.

**Clip and creator strategy:** results screen generates a run card (class, protocol reached, best evolution, squad) with one-tap share; "Hold at P7" and "last survivor extraction" moments trigger a short slow-mo on the client. Build a creator list in L1; give creators a code with a cosmetic. Ads are used in A3.5 and L2 for **diagnostics** only; ad-acquired players do not count toward ranking.

**Live-ops cadence (from L2):** weekly update every Friday (one of: new weapon/evolution, new mutation, event, QoL), monthly larger drop, seasonal zone. The data-driven definitions and remote config exist so a weekly update is a content change, not an engine change. If the owner cannot sustain weekly, biweekly is the floor; the cadence is written in `LIVEOPS_PLAYBOOK.md` and kept.

---

# 30. PRODUCT SUCCESS PRINCIPLES

- **Combat:** instant on the player's screen, honest on the server.
- **Decision:** every card matters; every extraction window is a real choice.
- **Progression:** permanent power is earned by play; curiosity gates pull players forward.
- **Social:** better with a squad, never worse alone; nothing taken by other players.
- **Content:** zones, mutations and bosses that look and behave differently.
- **Trust:** saves never lose, odds are what they say, nothing is sold that wins.
- **Player time:** 5–8 minute runs, one-tap replay, no punishment for leaving.

---

# 31. FINAL DIRECTIVE

DEADZONE is one interconnected platform: class combat, temporary survival builds, the Outbreak Protocol, persistent RPG progression, Forge, pets, co-op missions, dungeons and raids, campaign and seasons. Build in dependency order. Measure every exit. Put the game in front of players at A3.5 and let their data decide A4.

**Current approved stage: ALPHA A1.**

**End of Master Architecture Document — v2.0**
