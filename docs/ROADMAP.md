# DEADZONE — Production Roadmap
## From empty place to live operations, in stages, substages and checkpoints

**Companion to:** `architecture.md` v2.0
**Toolchain:** Roblox Studio + Roblox Studio MCP (Claude edits, runs and tests in Studio directly), Git mirror for backup
**Estimates:** assume the owner directs work ~5 days/week; ranges are calendar weeks. Total to public launch (L2): **~38–44 weeks**. The plan is dependency-ordered; durations are guesses, checkpoints are not.

---

## 0. How to use this document

### Status values
`⬜ Not started` · `🟨 In progress` · `🟦 Checkpoint pending` · `✅ Passed` · `🟥 Blocked`

Update the status column in the stage tables and the master tracker. `docs/CURRENT_PHASE.md` always names the one substage currently in progress.

### What "checkpoint passed" means — every time, no exceptions
1. **Tests:** full `TestRunner` suite run in Studio via `execute_luau`; console summary pasted in the handoff report; zero failures.
2. **Static:** Script Analysis shows zero warnings in `--!strict` modules.
3. **Play test:** the substage's play-test steps run via `start_stop_play`; `get_console_output` shows zero errors; screenshots via `screen_capture` where UI is involved.
4. **Numbers:** any budget or metric named in the checkpoint is measured and written down, not estimated.
5. **Restore point:** a named Studio version-history save (`<ID> passed`).
6. **Mirror:** scripts exported to `mirror/src` and committed to Git with the substage ID as the message.
7. **Handoff report** (format in `architecture.md` §27.1) appended to `docs/HANDOFF_REPORT.md`.
8. **Owner approval** recorded in `docs/DECISION_LOG.md` (one line is enough).

A checkpoint that fails any item stays `🟦` or goes `🟥`. Nothing downstream starts.

### Stage gates
A **stage** exits only when every substage is ✅ and the stage's exit numbers (from `architecture.md` §24) are recorded. Stage gates marked **GO/NO-GO** can stop the project or send it back a stage; that is their purpose.

---

## 1. Master tracker

| Stage | Name | Substages | Est. weeks | Planned start | Gate type | Status |
|---|---|---|---|---|---|---|
| P0 | Pre-production | 6 | 1 | 2026-10-16 (proposed) | Standard | 🟨 |
| A1 | Foundation | 8 | 1.5–2 | 2026-10-19 (proposed) | Standard | ⬜ |
| A2 | Combat Feel | 8 | 2–3 | 2026-11-02 (proposed) | Numeric | ⬜ |
| A3 | Run Progression, Protocol, FTUE | 9 | 3 | 2026-11-23 (proposed) | Numeric | ⬜ |
| A3.5 | **Public Test** | 6 | 3–4 live | 2026-12-14 (proposed) | **GO/NO-GO** | ⬜ |
| A4 | Classes and Bosses | 7 | 4 | 2027-01-11 (proposed) | Standard | ⬜ |
| A5 | Multiplayer and Persistence | 8 | 4 | 2027-02-08 (proposed) | Numeric | ⬜ |
| B1 | Persistent Progression | 7 | 4 | 2027-03-08 (proposed) | Standard | ⬜ |
| B2 | Hub and Campaign | 6 | 3 | 2027-04-05 (proposed) | Standard | ⬜ |
| B3 | Facilities and Endgame Foundation | 8 | 5 | 2027-04-26 (proposed) | Standard | ⬜ |
| B4 | **Closed Beta** | 7 | 4 | 2027-05-31 (proposed) | **GO/NO-GO** | ⬜ |
| L1 | Release Candidate | 8 | 3 | 2027-06-28 (proposed) | Checklist | ⬜ |
| L2 | **Public Launch** | 5 | 1 + 2 monitoring | 2027-07-19 (proposed) | Standard | ⬜ |
| L3 | Season 1 | 6 | 6–8 | 2027-08-09 (proposed) | Standard | ⬜ |
| LO | Live Operations | ongoing | — | 2027-07-30 (proposed) | Cadence | ⬜ |

### 1.1 Schedule, Beta art budget and weekly rhythm (P0.6)

**Status:** proposed by Claude on 2026-10-16, **awaiting the owner's written dates** (P0.6 checkpoint). Every value marked "(proposed)" changes to the owner's value when confirmed.

**How the dates were built:** each stage starts on a Monday; A1 and A2 use the upper estimate (2 and 3 weeks), A3.5 uses 1 prep + 3 live weeks, all other stages use their single estimate. P0 → L2 start = 39.5 weeks (roadmap range 38–44). L3 here is the start of Season 1 production; Season 1 goes live 6–8 weeks after launch (target ~2027-09-06). LO starts with the first Friday update (L2.5).

- A3.5 Public Test (2026-12-14 → 2027-01-08) overlaps the year-end holidays. Holiday traffic helps the diagnostics, but owner availability may not; if the owner prefers, shift A3.5 and everything after it by 2 weeks.
- Slip rule (from §17): a stage running past 150% of its estimate triggers a scope cut (zones, pets) before any checkpoint is cut. Downstream dates are re-planned at the Friday review, never silently.

**Beta art budget line (architecture §22 step 3, used in B4.1):** proposed cap **— (owner to set)**. Scope and rough cost (USD):

| Item | Count | Lean | Standard | Premium |
|---|---|---|---|---|
| Class models, rigged (≤ 6k tris) | 6 | 240 | 900 | 2,400 |
| Fodder enemy models, rigged (≤ 1.5k tris) | 8 | 200 | 640 | 1,600 |
| Boss models, rigged (≤ 20k tris) | 6 | 480 | 1,800 | 4,800 |
| Animations (8 per class, 5 per fodder, 8 per boss) | 136 | 1,360 | 4,080 | 10,200 |
| Zone dressing kits | 6 | 900 | 3,000 | 9,000 |
| Hub dressing kit | 1 | 200 | 600 | 2,000 |
| UI icons (weapons, passives, evolutions, pets, currencies, classes, misc) | ~60 | 300 | 900 | 2,400 |
| Card frames per rarity + class portraits | 11 | 165 | 550 | 1,320 |
| **Subtotal** | | **3,845** | **12,470** | **33,720** |
| **With 15% contingency** | | **~4,400** | **~14,300** | **~38,800** |

- Rates are estimates. The Lean column is anchored on a handful of Roblox freelancer price lists (DevForum, Fiverr, Carrd; mostly undated, checked 2026-10-16); Standard and Premium are assumptions, not quotes. Real quotes replace them at B2.
- Timing: brief and shortlist during B2 (from 2027-04-05), contracts signed at B3 start (2027-04-26), final delivery by B4 week 2 (2027-06-11). No money is committed before the A3.5 GO decision.
- Every contract grants the owner the right to use and modify; every asset gets an `assets/ART_SOURCES.md` row.
- Optional, separate: PT.1 minimum presentation (one hero, Walker/Runner/Brute, one arena, audio) can use generated meshes and licensed Creator Store packs at ~$0–800; owner to decide whether to fund it.

**Weekly working rhythm (proposed):**

| When | Who | What |
|---|---|---|
| Mon–Fri working sessions | Owner | Studio open on the Deadzone place (72812275891657) with the Studio MCP connected; work only runs while Studio is open on the owner's computer |
| During sessions | Claude | One thread per substage, unattended checkpoints (D-010), `progress.md` updated after every step |
| Any time | Claude | Owner-only questions (dates, scope, art, monetization, schema, gates) posted in the substage thread; work continues where it can |
| Friday | Owner + Claude | Weekly review: substages passed, dates vs plan, open decisions answered in one batch, next week's target substages |
| Gates (A3.5, B4) | Owner | Written GO/NO-GO in `DECISION_LOG.md`; nothing after a gate starts without it |
| From L2.5 | Both | Friday live-ops update (§16), biweekly floor announced if weekly can't hold |

---

## 2. Stage P0 — Pre-production (1 week)

Purpose: nothing is built until the place, the tools, the art direction and the legal basics exist.

| ID | Substage | Deliverables | Checkpoint — passes when | Verify via |
|---|---|---|---|---|
| P0.1 | Place and access | New experience created; Team Create on; MCP connected; `list_roblox_studios` shows the place | Claude reads and writes a test script in the place and runs a play test | `get_studio_state`, `multi_edit`, `start_stop_play` |
| P0.2 | Repository | Git repo with `architecture.md`, `ROADMAP.md`, `CLAUDE.md`, empty `docs/` files, `mirror/` | First commit; `README.md` explains open-place / connect-MCP / run-tests | Repo inspection |
| P0.3 | Art bible v0 | `ART_BIBLE.md`: low-poly style, zone palettes, silhouette rules, UI theme tokens (colors, type scale, rarity colors), icon concept sketch | Owner approves one page of direction and two reference mood images (original or licensed) | Owner review |
| P0.4 | Content bible v0 | Names and one-line descriptions for 6 classes, 8 enemies, 6 zones, 7 protocol levels, 12 weapons, 10 passives, 4 evolutions, 6 pets | Document exists; nothing resembles reference-game names or designs | Owner review |
| P0.5 | Compliance basics | Age-rating questionnaire draft; monetization rules (§21) acknowledged; Creator Store licenses noted in `ART_SOURCES.md` template | Draft answers written; `ART_SOURCES.md` has columns and the first row (ProfileStore) | Document |
| P0.6 | Budget and cadence | `ROADMAP.md` dates filled in; contractor budget line for Beta art; weekly working rhythm agreed | Owner writes the planned start date for each stage | Document |

**P0 exit:** all six ✅; `CURRENT_PHASE.md` = A1.1.

---

## 3. Stage A1 — Foundation (1.5–2 weeks)

Purpose: the skeleton every later system plugs into. No gameplay.

| ID | Substage | Deliverables | Checkpoint — passes when | Verify via |
|---|---|---|---|---|
| A1.1 | Studio layout | Folders per §4.3 in ReplicatedStorage/ServerScriptService/StarterPlayerScripts/ServerStorage; Bootstrap scripts; ProfileStore inserted and version pinned | Play test boots; console prints `[Boot] phases 0–8 complete` with the ordered service list and zero errors | `start_stop_play`, `get_console_output` |
| A1.2 | TestRunner | `ServerStorage/Tests/TestRunner` with `describe/it/expect`, async support, summary table; 3 sample tests | `execute_luau` runs the suite and prints `3 passed, 0 failed` | `execute_luau` |
| A1.3 | Git mirror | Export procedure (Claude reads every script and writes `mirror/src/...`); first export committed | Mirror tree matches the Studio tree one-to-one (script count equal) | `script_search` count vs mirror file count |
| A1.4 | Domains and lifecycle | 10 domain folders, `Init`/`Start` contract, bootstrap asserts order, one placeholder service per domain | Deliberately swapping two services' phases triggers the assertion in a test | TestRunner |
| A1.5 | Event bus | Typed `Events` module; `EVENTS.md` with the §5.3 catalog; publish/subscribe tests; misuse (publish from wrong domain) asserts in strict mode | Tests: subscribe → publish → receive; wrong-type payload rejected | TestRunner |
| A1.6 | Definitions registry | `_Registry` loads every `Definitions/*` folder, validates schema, detects duplicate IDs; one sample per folder | A deliberately broken sample (missing field / duplicate ID) makes boot fail with a clear message; fixing it boots clean | Play test ×2 |
| A1.7 | Types and StatPipeline | All §6 types with no `any`; `StatPipeline` + `DamageCalculator`; `STATS.md` seeded with every §10.2 stat, layer and cap | Tests cover: each layer alone, all layers combined, every cap, zero/negative inputs; 100% of `STATS.md` rows have a test | TestRunner |
| A1.8 | Clock, network, platform wrappers | `SimulationClock` (pause/resume/tick tests); contract registry + token buckets + `buffer` codec helpers; remotes created in phase 8 only; `AnalyticsService`, `ErrorReportService`, `RemoteConfigService`, `FeatureFlagService` wrappers | Tests: paused clock does not advance; bucket rejects the N+1th request; codec round-trips all field types; a remote does not exist before phase 8 | TestRunner, `search_game_tree` |

**A1 exit numbers:** 0 boot errors; 0 Script Analysis warnings; TestRunner ≥ 40 tests, 0 failures; broken-definition boot failure demonstrated. → `CURRENT_PHASE.md` = A2.1.

---

## 4. Stage A2 — Combat Feel (2–3 weeks)

Purpose: one class, two enemies, and combat that feels instant on a phone. This stage decides whether pillar 1 is real.

| ID | Substage | Deliverables | Checkpoint — passes when | Verify via |
|---|---|---|---|---|
| A2.1 | Camera and input | Elevated third-person camera; `InputController` with PC/mobile/console bindings; mobile auto-aim + auto-fire toggle | Owner plays on PC and on a phone (Studio device emulator plus one real phone); every action fires on all three input schemes | Play test, `screen_capture` |
| A2.2 | Test arena | Greybox arena with spawn edges and collision grid; placeholder survivor model | Player walks the arena with no stuck spots; arena grid exported for steering | Play test |
| A2.3 | Enemy simulation core | `EnemyService` table sim on `SimulationClock`; Walker + Runner definitions; steering + separation; tiered update rates; snapshot packing | 90 Walkers/Runners alive pursuing one player; server heartbeat ≤ 8 ms avg / ≤ 16 ms p99 (record both) | `execute_luau` profiler script, console |
| A2.4 | Client rendering | Pooled enemy renderers; snapshot interpolation; procedural animation; despawn policy | 90 enemies move smoothly at 60 FPS on PC and ≥ 30 FPS in low-end emulation; no visible teleporting at 12 Hz snapshots | Play test, FPS overlay |
| A2.5 | Primary attack with prediction | Sharpshooter rifle: client predicted VFX/SFX; `RequestAttack` with seq + timestamp; server lag-compensated hit test with 250 ms ring buffer; `CombatResult` batched over `UnreliableRemoteEvent` | With 100 ms simulated RTT (Studio network settings): input→feedback ≤ 1 frame; request→result ≤ 150 ms; server rejects attacks with spoofed origin in tests | Play test, TestRunner |
| A2.6 | Dodge | Combat roll with i-frames; server validates distance/cooldown; rubber-band on violation | Rolling through a Walker attack takes no damage; a scripted 3× speed dodge is rejected and logged | Play test, TestRunner |
| A2.7 | Auto-weapons | `WeaponService` archetype dispatch; `Projectile`, `Spread`, `Orbit`; targeting strategies; `MaxTargets` caps | Three auto-weapons fire simultaneously at correct cooldowns from `SimulationClock`; pausing the clock stops them | Play test, TestRunner |
| A2.8 | Juice | Hit flash, damage numbers, kill pop, screen shake (toggle), SFX set from Creator Store; bandwidth measured | Snapshot + result bandwidth ≤ 25 KB/s per client at 90 enemies; owner rates "feels instant" on a phone | Network stats, owner sign-off |

**A2 exit numbers (all recorded in `PERFORMANCE_BUDGETS.md`):** heartbeat, enemy count, bandwidth, FPS PC/mobile, input→feedback, request→result. → A3.1.

---

## 5. Stage A3 — Run Progression, Protocol, FTUE (3 weeks)

Purpose: a complete solo run with the signature mechanic and a first session that starts fighting in 5 seconds.

| ID | Substage | Deliverables | Checkpoint — passes when | Verify via |
|---|---|---|---|---|
| A3.1 | WaveDirector | Spawn budget, rate per protocol, enemy pool filtered by `MinProtocol`, elite schedule; Brute added | 8-minute run never exceeds `MaxAlive`; elites appear at the scheduled protocol levels | TestRunner (simulated clock), play test |
| A3.2 | XP and leveling | XP orbs with magnet radius; thresholds; pick queue | Killing 20 Walkers at level 1 yields the designed level; 3 level-ups in one second queue 3 picks | TestRunner, play test |
| A3.3 | Solo pause and cards | Clock pause on level-up; offer generation (pool, rarity, slots); 3-card UI readable without text; `RequestUpgradeChoice` validation | During pause: no enemy moves, no cooldown advances, no DoT ticks (asserted by test); invalid OfferId rejected; cards readable at 360×640 | TestRunner, `screen_capture` |
| A3.4 | Content set 1 | 8 weapons (3 archetypes + `Explosive`, `Zone`, `Chain`), 8 passives, 2 evolutions with codex entries | Every definition validates; each weapon reaches max level in a scripted run; both evolutions trigger when recipes are met and not otherwise | TestRunner |
| A3.5 | ProtocolService | 7 levels, meter HUD, 5 mutations (data-driven), multiplier, protocol gates on evolutions | Protocol reaches 7 in a scripted long run; each mutation visibly changes the horde (screenshot per level); a P4-gated evolution is never offered at P3 | Play test, TestRunner |
| A3.6 | ExtractionService (solo) | Windows at P3/P5/P7; two-button prompt; extract/hold; payout rules incl. wipe 40% | Extract at P3 pays ×multiplier; wipe after holding pays 40% of last window; wipe before P3 pays the floor | TestRunner |
| A3.7 | Results and replay | Results screen (XP, protocol, best card), run card, "Run again" and "Invite" buttons; run counter saved | "Run again" starts a new run in ≤ 3 s without a teleport; run counter persists across rejoin | Play test |
| A3.8 | FTUE | New-account flow per §3: spawn into mission as Sharpshooter, auto-fire on, contextual arrows only, hub pan after first extraction | 5/5 fresh test accounts: time to first kill ≤ 30 s median, first card ≤ 60 s; no blocking pop-ups | Play test with alt accounts, console timestamps |
| A3.9 | Telemetry funnel | Events `Joined`, `ArenaEntered`, `FirstKill`, `FirstCard`, `ExtractionWindow`, `Vote`, `RunEnded`, `RunAgain`, `Left`; feature flags for 2 icons × 2 onboarding variants | Each event appears in the Analytics dashboard from a play test; flags switch variants without a republish | Analytics dashboard, `RemoteConfig` change |

**A3 exit numbers:** first kill ≤ 30 s, first card ≤ 60 s (medians over 5 accounts); pause exactness test green; payout tests green. → A3.5 (Public Test).

---

## 6. Stage A3.5 — PUBLIC TEST (1 week prep + 2–3 weeks live) — GO/NO-GO

Purpose: real players decide whether the loop and the signature mechanic work before four more months are spent.

| ID | Substage | Deliverables | Checkpoint — passes when | Verify via |
|---|---|---|---|---|
| PT.1 | Minimum presentation | One hero model, Walker/Runner/Brute models, one dressed arena (placeholders upgraded with generated meshes/textures or licensed packs), audio set, loading screen | Owner judges it "not embarrassing" on a phone; every asset in `ART_SOURCES.md` | Owner, document |
| PT.2 | Store assets | Title variants A/B; icon with hero-vs-horde + cards; 3 thumbnails 16:9; description | Both icons exported; thumbnails readable at small size | Files in `assets/` |
| PT.3 | Publish unlisted | Experience published, friends-only soak for 2 days; crash/error watch | 0 server errors over 48 h of friend sessions; funnel events arriving | Analytics, error reports |
| PT.4 | Publish listed + diagnostics | Listed publicly; small sponsored campaign for diagnostic traffic only (ads don't rank you); flags set for A/B | Playthrough and bounce data visible for both icon variants after 48 h | Creator analytics |
| PT.5 | Iterate weekly | Two improvement passes from data (onboarding, card readability, difficulty, vote clarity) | Each pass ships within a week and its hypothesis and result are logged in `DECISION_LOG.md` | Log |
| PT.6 | Go/no-go review | Written review against the thresholds below | Decision recorded | Owner |

**GO (proceed to A4) when, over the final 7 days:**
- Median time to first kill ≤ 30 s (new accounts)
- ≥ 50% of new players start a second run
- ≥ 30% of extraction windows record at least one HOLD
- First-play bounce (<60 s) lower in week 3 than week 1
- Player feedback mentions the Hold/Extract decision unprompted

**NO-GO (return to A3) when:** second-run rate < 30% after two iteration passes, or testers do not understand the vote after two UI revisions. **Shelve review** if time-to-first-kill cannot be brought under 45 s or the loop produces no "one more" behavior after three passes.

---

## 7. Stage A4 — Classes and Bosses (4 weeks)

| ID | Substage | Deliverables | Checkpoint — passes when | Verify via |
|---|---|---|---|---|
| A4.1 | Ability framework | `AbilityService` with cooldown/resource/state validation; signature slot; class definitions wired | Sharpshooter signature works through the generic path; no class-specific code outside definitions | Code review, TestRunner |
| A4.2 | Juggernaut | Shotgun, shoulder charge, Unbreakable (immunity + taunt); unlock at level 5 | Juggernaut extracts on Normal; taunt redirects 90 enemies in a test | Play test |
| A4.3 | Stalker and Incinerator | Dual Machetes (melee arc), blink; Flame Projector (`Zone`), backstep + fire trail, Firestorm | Both extract on Normal; melee hit arc validated server-side with lag compensation | Play test, TestRunner |
| A4.4 | Mechanic and Combat Medic | Nail Launcher, grapple hop, `Deployable` turret; Medical Sidearm, slide, Healing Pulse (self-heal solo) | Both extract on Normal; turret obeys `MaxTargets`; heal capped by `STATS.md` | Play test, TestRunner |
| A4.5 | Fodder roster complete | Spitter (ranged), Screamer (summons), Armored (resistances), Exploder (death AOE) with telegraphs | Each enemy's behavior is identifiable by a tester who has not read the spec; resistances apply via `DamageCalculator` | Blind test, TestRunner |
| A4.6 | Mutant Alpha boss | Server-side boss logic, 3 phases, telegraphs ≥ 0.6 s, counters; boss at P5 | Boss killable by every class on Normal; each phase transition is readable on a phone; health is not the only difficulty lever | Play test ×6 classes |
| A4.7 | Mission flow | Objectives, victory/defeat screens, class select in hub (unlocks shown), A2 budgets re-measured with all archetypes | Budgets within A2 numbers ±10%; every class has a results screen path | Profiler, play test |

**A4 exit:** 6/6 classes extract; boss readability sign-off; budgets recorded. → A5.1.

---

## 8. Stage A5 — Multiplayer and Persistence (4 weeks)

| ID | Substage | Deliverables | Checkpoint — passes when | Verify via |
|---|---|---|---|---|
| A5.1 | Parties | `PartyService`: create, invite, leader, ready, Quick Deploy; 1–4 players | 4 Studio test clients form a party and deploy together | Studio local server (4 players) |
| A5.2 | Instanced arenas | Per-party arena copies from `ServerStorage`, interest-filtered snapshots, 3 concurrent arenas | 3 parties run simultaneously; a client receives only its arena's snapshots; heartbeat ≤ 16 ms p99 at 12 players | Network stats, profiler |
| A5.3 | Co-op scaling and votes | Enemy count/health scaling by party size; vote tally (majority, tie→HOLD); squad XP bonus | 4-player P7 extraction completes; tally tests cover 1–4 voters and disconnects | TestRunner, play test |
| A5.4 | Co-op card overlay | Non-blocking overlay, 12 s auto-pick, auto-weapons continue, attack disabled during selection | A selecting player survives a normal wave at Normal in ≥ 4/5 trials; match never stalls | Play test |
| A5.5 | Profiles | ProfileStore integration, schema v1, defaults, `MigrationService` with v0→v1 fixture, `BindToClose` | Profile survives rejoin and a Studio server shutdown; migration fixtures pass | TestRunner, play test |
| A5.6 | Rewards | `RewardService` with idempotent `ClaimId`; pending rewards for disconnects (≥ 60% presence) | Replaying the same claim grants once; a disconnected player receives rewards on next login | TestRunner, play test |
| A5.7 | Social hooks | Invite reward (one-time cosmetic), `LeaderboardService` on OrderedDataStore (Best Protocol), hub leaderboard board | Two accounts receive the cosmetic once after a shared extraction; leaderboard updates within 60 s | Play test |
| A5.8 | Soak | 2-hour 12-player soak with bots or alt clients | Memory growth < 50 MB/h; 0 errors; 0 save failures | Profiler, console |

**A5 exit numbers:** heartbeat p99, memory growth, save failures (0), duplicate claims rejected (test), overlay survival rate. → B1.1.

---

## 9. Stage B1 — Persistent Progression (4 weeks)

| ID | Substage | Deliverables | Checkpoint — passes when | Verify via |
|---|---|---|---|---|
| B1.1 | Inventory and items | `ItemInstance`, slots, add/remove/equip/lock, loadouts per class, `TransactionService` | Equip reflects in `StatPipeline`; spamming equip 50× yields one state change | TestRunner |
| B1.2 | Armor and trinkets | Helmet/chest/legs/trinket definitions, rarity, affixes | 30 items validate; previews equal in-run values (test compares both paths) | TestRunner |
| B1.3 | Skill tree | Node graph, prerequisites, ranks, slot unlocks, Squad branch, respec (Gold) | Buying without prerequisites is rejected; respec refunds exactly; slot unlock changes offers | TestRunner, play test |
| B1.4 | Currencies | Gold/Serum/Samples earn and spend paths; class unlocks with Serum | No path produces a negative balance under randomized transaction tests (1000 ops) | TestRunner fuzz |
| B1.5 | Gameplay chests | Reward tables, normalization check at boot, odds UI, batch open, pity | 10,000-roll test matches displayed odds within tolerance; chests cost gameplay currency only | TestRunner |
| B1.6 | Codex | Discovery from events; protocol requirements shown; category rewards | Evolving a weapon unlocks its codex entry once; rewards claim once | TestRunner |
| B1.7 | Forge core | Enhance, salvage, previews via `StatPipeline`, locked-item protection, atomic transaction | Interrupted enhance (simulated failure mid-commit) leaves materials and item unchanged; preview equals result | TestRunner |

**B1 exit:** migration fixtures v1→v2 pass; fuzz test green; odds test green. → B2.1.

---

## 10. Stage B2 — Hub and Campaign (3 weeks)

| ID | Substage | Deliverables | Checkpoint — passes when | Verify via |
|---|---|---|---|---|
| B2.1 | Hub space | Hub build (greybox → dressed), facility stations, Quick Deploy, class select, leaderboard board | Returning player reaches a mission in one tap from the hub; new player still spawns into combat | Play test |
| B2.2 | Zones 1–3 | Evacuation Streets, Quarantine Hospital, Industrial District: arenas, palettes, enemy pools, mutations, bosses (2 new) | Each zone passes the A2 budgets; a blind tester can tell the zones apart from screenshots | Profiler, blind test |
| B2.3 | Difficulties | Normal/Hard/Nightmare/Cataclysm modifiers (composition, protocol rate, boss phases) and unlocks | Difficulty changes more than health (checklist per difficulty); unlocks persist | TestRunner, play test |
| B2.4 | Matchmaking | Same-server fill via MemoryStore queue by zone/difficulty; party + public; disconnect handling | Two solo players in the same server are matched within 20 s; a leaving player's rewards pend correctly | Play test |
| B2.5 | Campaign records | `StageRecord` per stage/difficulty; best protocol/time; zone unlock rules | Records update only from `MissionEnded` events; tampering remote is rejected | TestRunner |
| B2.6 | Quests | Daily (3) / weekly (3) from events; no streak penalties; reward claim idempotent | Quests progress only from authoritative events; missing a day changes nothing | TestRunner |

**B2 exit:** hub→mission→hub loop in one place; zones budgets recorded. → B3.1.

---

## 11. Stage B3 — Facilities and Endgame Foundation (5 weeks)

| ID | Substage | Deliverables | Checkpoint — passes when | Verify via |
|---|---|---|---|---|
| B3.1 | Pets and eggs | `PetService`, `EggService` (gameplay currency), odds display, pity, pet leveling, companion visuals | 10,000-hatch test matches odds; pet bonuses flow through `StatPipeline` and are capped | TestRunner |
| B3.2 | Forge expansion | Crafting recipes, affix reroll (Samples), enhancement history | Recipes validate at boot; reroll consumes exactly once | TestRunner |
| B3.3 | Training arena | Dummies with DPS readout, ability tutorials per class | DPS readout equals `DamageCalculator` output | Play test |
| B3.4 | Endless Outbreak | `IEncounterMode` implementation, uncapped protocol, Endless leaderboard | Protocol > 7 scales mutations procedurally without errors for 20 minutes | Play test |
| B3.5 | Zones 4–6 | Research Facility, Military Base, Epicenter with bosses | Budgets met; blind-test distinguishable | Profiler, blind test |
| B3.6 | First dungeon | Containment Dungeon with modifiers and loot pool on `IEncounterMode` | Completes end to end; rewards claim once | Play test, TestRunner |
| B3.7 | Raid foundation | `RaidService`, `RaidScheduleService` (server time), 8-player raid boss with phases, contribution tracking, lobby | One raid completes with 8 test clients; rewards granted once per participant; abandoned raid cleaned up | Studio local server, TestRunner |
| B3.8 | Content audit | `SYSTEM_REGISTRY.md` statuses updated; all `Planned` items for Launch listed with owners | Registry matches reality (spot-check 10 items) | Review |

**B3 exit:** pets/eggs odds test, one raid completion, registry audit. → B4.1.

---

## 12. Stage B4 — CLOSED BETA (4 weeks) — GO/NO-GO

| ID | Substage | Deliverables | Checkpoint — passes when | Verify via |
|---|---|---|---|---|
| B4.1 | Art pass | Contracted models/animations for classes, roster, bosses, zones; UI icon set; cards; hub dressing | Every placeholder replaced or explicitly accepted; `ART_SOURCES.md` complete | Review |
| B4.2 | UI integration | All §22 screens; phone (360×640) and controller navigation verified; theme tokens only | Every screen screenshot at phone size with no overlap; full controller traversal | `screen_capture`, play test |
| B4.3 | Anti-exploit suite | §26 security tests automated; movement sanity; admin channel isolation | All security tests green; a 50× spam run produces 0 state changes beyond rate | TestRunner |
| B4.4 | Performance soak | 12-player 2-hour soak, all modes, mobile FPS capture on 2 real devices | §23 budgets met; results in `PERFORMANCE_BUDGETS.md` | Profiler, devices |
| B4.5 | Analytics dashboards | Funnel, retention, economy inflow/outflow, co-play size, protocol distribution | Dashboards populated from a beta day | Analytics |
| B4.6 | Beta cohort | 50–200 invited testers (Discord/community), feedback form, bug tracker | ≥ 50 testers active; bugs triaged daily | Tracker |
| B4.7 | Go/no-go review | Written review vs thresholds | Decision logged | Owner |

**GO (to L1) when:** 0 release-blocking bugs open; ≥ 80% of testers reach the hub and equip an item unassisted; Day-1 return rate and co-play share recorded as the launch baseline; economy shows no unbounded inflow. **NO-GO:** blocking bugs, or testers cannot navigate progression unassisted after one UI pass.

---

## 13. Stage L1 — Release Candidate (3 weeks)

| ID | Substage | Deliverables | Checkpoint — passes when | Verify via |
|---|---|---|---|---|
| L1.1 | Economy balance | Tuning pass from beta data; reward tables, costs, protocol multipliers; caps confirmed | Modeled 30-day progression hits design targets; no infinite loops in a 10,000-run simulation | `execute_luau` simulation |
| L1.2 | Data audit | Migration chain v0→vN on all fixtures; `AdminDataService` inspect/grant/rollback tools; snapshot store | Rollback of a corrupted test profile restores yesterday's state | TestRunner, admin test |
| L1.3 | Monetization | Cosmetic shop, supporter packs, convenience items, private servers; `ProcessReceipt` idempotent; battle pass Season 1 (free + premium) | Receipts tested with Studio test purchases; duplicate receipt grants once; §21.4 fairness test re-answered in writing | Test purchases, document |
| L1.4 | Codes and events plumbing | `CodeRedemptionService`; `EventService` with one dry-run event behind a flag | Code redeems once per profile; event toggles via remote config | TestRunner, flag flip |
| L1.5 | Launch-exit systems | Pets, Forge, one Raid: complete and tested (not placeholders) | Each has ≥ 10 tests green and a play-test sign-off | TestRunner, owner |
| L1.6 | Store presence | Final icon (winner from A3.5 + polish), 5 thumbnails, 30-second trailer, description, age rating submitted | Assets uploaded; rating approved | Creator dashboard |
| L1.7 | Creator and community | Creator list (20+), creator codes with cosmetic, Discord/community server, support process, moderation plan | Outreach sent; support doc written | Document |
| L1.8 | Rollback and release checklist | Named restore point `L1 RC`; rollback steps; launch-day checklist; on-call window | Owner signs the checklist | Document |

**L1 exit:** checklist signed; all L1.5 systems ✅. → L2.1.

---

## 14. Stage L2 — PUBLIC LAUNCH (1 week + 2 weeks monitoring)

| ID | Substage | Deliverables | Checkpoint — passes when | Verify via |
|---|---|---|---|---|
| L2.1 | Launch | Listed publicly; creator codes live; sponsored diagnostics campaign | Live with 0 critical errors in the first 6 hours | Dashboards |
| L2.2 | Day-1 hotfix window | Daily patch slot for 7 days; error triage | Each day's top error fixed within 24 h | Error reports |
| L2.3 | Signal review (day 7) | Playthrough, bounce, D1, qualified sessions, co-play, spend days vs beta baseline | Review written; one change shipped from it | Document |
| L2.4 | Signal review (day 14) | D2–7 play days, economy inflow/outflow, protocol distribution, class pick rates | Review written; balance patch shipped if any class < 8% pick rate or > 35% | Document |
| L2.5 | Live-ops cadence start | First Friday update shipped; `LIVEOPS_PLAYBOOK.md` active | Update shipped on schedule | Changelog |

**L2 exit:** two signal reviews done; weekly cadence started. → L3.1.

---

## 15. Stage L3 — Season 1 (6–8 weeks after launch)

| ID | Substage | Deliverables | Checkpoint — passes when | Verify via |
|---|---|---|---|---|
| L3.1 | Season plan | Theme, dates, content list, pass tiers, event currency, raid rotation | Plan approved 4 weeks before start | Document |
| L3.2 | New zone + boss | Seventh zone and boss on existing pipelines | Budgets met; blind-test distinct | Profiler, blind test |
| L3.3 | Event | Limited event (server-time window), currency, event chests (gameplay currency), 2 new mutations | Event starts/ends by flag and clock; cleanup verified on a test server with the clock advanced | Play test |
| L3.4 | Seasonal content | Cosmetic-forward gear set, 2 weapons, 1 evolution, 2 pets | Definitions validate; codex entries | TestRunner |
| L3.5 | Pass Season 2 + raid rotation | Season transition logic, claim protection, rotation schedule | Transition on a test profile preserves claimed rewards; rotation changes on schedule | TestRunner |
| L3.6 | Season review | Retention and economy comparison vs launch baseline | Review written; Season 2 plan adjusted | Document |

**L3 exit:** season shipped without profile loss (0 support tickets about lost items attributable to the update).

---

## 16. Stage LO — Live Operations (ongoing cadence, not a stage)

| Cadence | Content | Checkpoint |
|---|---|---|
| Daily (first 30 days), then as needed | Error triage, hotfixes | Top error < 24 h |
| Weekly (Friday) | One of: weapon/evolution, mutation, QoL, small event, balance | Shipped on day; changelog posted; restore point saved |
| Monthly | Larger drop: boss, dungeon, class skin set, or mode | Signal review attached |
| Seasonal (8–10 weeks) | Zone, pass, event, raid rotation | L3 checklist reused |
| Quarterly | Economy audit, data audit, performance re-baseline, roadmap revision | Documents updated |

Floor: if weekly cannot be sustained, **biweekly** is the minimum and is announced to players. Never skip silently.

---

## 17. Risk register and stop conditions

| Risk | Signal | Response |
|---|---|---|
| Combat doesn't feel instant | A2.5 numbers missed after 2 attempts | Stop. Re-examine prediction design before any A3 work |
| Loop doesn't retain | A3.5 second-run rate < 30% after 2 passes | NO-GO; revise cards/pacing/protocol in A3 |
| Vote not understood | A3.5 HOLD rate < 10% and feedback confused | Redesign vote UI; if still failing, simplify to a single "Hold?" prompt |
| Solo-owner bandwidth | Any stage runs > 150% of estimate | Cut content breadth (zones, pets) before cutting checkpoints |
| Art pipeline stalls | PT.1 or B4.1 blocked > 2 weeks | Ship with generated/licensed placeholders; log the debt |
| Data loss | Any save failure in A5+ | Blocker; nothing ships until root cause is fixed and a test covers it |
| Scope creep | New system proposed mid-stage | Registry entry + `DECISION_LOG.md`; implement only in a later stage |
| Policy change | Roblox updates paid-random-item or rating rules | Re-check Creator Hub at B1, L1 and each season |

---

## 18. Checkpoint record template

Copy into `docs/HANDOFF_REPORT.md` for every substage.

```text
CHECKPOINT: <ID> <Substage name>
DATE:
TESTRUNNER: <N passed / M failed>  (console summary pasted below)
SCRIPT ANALYSIS: <0 warnings | list>
PLAY TEST: <steps run> → <result>, console errors: <0 | list>
NUMBERS: <metric = value> ...
RESTORE POINT: "<ID> passed"
MIRROR COMMIT: <hash>
OWNER APPROVAL: <yes / date>
NOTES / DEBT:
NEXT: <next ID>
```

---

**Current substage:** P0.6
**Last checkpoint passed:** P0.5 (2026-10-16)
