# DECISION LOG

Append-only. One entry per architectural decision, scope change, or owner approval. Format:

```
## D-### — <title>
Date · Stage/substage · Status: Accepted | Superseded by D-###
Context: why a decision was needed
Decision: what was decided
Alternatives: what was rejected and why
Consequences: what this commits us to
Approved by: owner (date)
```

Owner checkpoint approvals are one line: `## CP — <ID> passed · <date> · approved by owner`.

---

## D-001 — Studio-native toolchain, no Rojo
2026-10-16 · P0 · Accepted
Context: v1.0 assumed Rojo + Git source tree. Owner will develop through Claude Code with the Roblox Studio MCP server.
Decision: Roblox Studio is the single source of truth. Claude edits scripts in place via MCP, runs tests via `execute_luau`, play-tests via `start_stop_play`. Git holds docs plus a read-only mirror of scripts exported after each checkpoint.
Alternatives: Rojo two-way sync (rejected: adds a toolchain the owner won't run); no backup at all (rejected: Studio history alone has no diffs or review).
Consequences: no headless CI; TestRunner must be run in Studio before every checkpoint; mirror export is a checkpoint step.
Approved by: owner (2026-10-16)

## D-002 — In-house TestRunner instead of TestEZ / Jest-Lua
2026-10-16 · P0 · Accepted
Context: Without Wally, pulling a test framework means inserting and pinning a package by hand. TestEZ is unmaintained.
Decision: Write a ~150-line `describe/it/expect` runner in `ServerStorage/Tests/TestRunner`, with async support and a console summary table.
Alternatives: Jest-Lua rbxm insert (acceptable fallback if the in-house runner becomes limiting; log a new decision).
Consequences: we own the runner; keep it small.
Approved by: owner (2026-10-16)

## D-003 — Enemies are non-Humanoid table simulations
2026-10-16 · A1 design · Accepted
Context: Horde scale and an exact solo pause.
Decision: `EnemyService` simulates enemies as table rows on `SimulationClock`; clients render pooled models with interpolation. Steering for fodder; PathfindingService only for Brutes/Armored/bosses at ≤ 1 recompute per 1.5 s.
Alternatives: Humanoid NPCs (rejected: replication and physics cost, cannot pause cleanly).
Consequences: custom snapshot replication, custom hit testing with lag compensation, procedural/local animation on the client.
Approved by: owner (2026-10-16)

## D-004 — One place through Launch
2026-10-16 · A1 design · Accepted
Context: First-session bounce; teleports add 10–30 s and a failure mode before the first fight.
Decision: Hub and per-party instanced arenas in a single place; 12-player servers. Reserved servers only when measured CCU demands, after A3.5 data.
Alternatives: Four places via TeleportService (rejected for Alpha/Launch).
Consequences: interest filtering per arena is required in A5; arena instancing from ServerStorage.
Approved by: owner (2026-10-16)

## D-005 — Signature mechanic: Outbreak Protocol, Hold or Extract
2026-10-16 · Design · Accepted
Context: v1.0 had no element that was only ours.
Decision: 7-level protocol meter that mutates the horde, scales loot and gates evolutions; extraction windows at P3/P5/P7 with a team vote; wipe pays 40% of the last open window.
Alternatives: pure wave-count missions (rejected: identical to reference). Separate "extraction gamble" and "mutation meter" systems (rejected: one decision, one system).
Consequences: built in A3, tested publicly in A3.5; GO/NO-GO thresholds depend on it.
Approved by: owner (2026-10-16)

## D-006 — Monetization: cosmetics, pass, supporter packs, convenience only
2026-10-16 · Design · Accepted
Context: Reference-style Robux chests/eggs with stat items fail the parent-over-the-shoulder test.
Decision: Robux never buys gear, gear chests, stat pets, in-run power or protocol multipliers. Eggs and gameplay chests use gameplay currency with published odds and pity.
Consequences: revenue depends on cosmetics people want to show; cosmetic pipeline is a Launch requirement.
Approved by: owner (2026-10-16)

## D-007 — Pets, Forge, Raids are Launch-exit, not Beta-exit
2026-10-16 · Planning · Accepted
Context: Blocking the first player data on three large systems delays learning by months.
Decision: All three stay in the registry and are complete at L1; A3.5 Public Test ships without them.
Approved by: owner (2026-10-16)

## D-008 — Service renames to avoid Roblox built-in collisions
2026-10-16 · A1 design · Accepted
Decision: `RunService` → `MissionSessionService`; `CollectionService` → `CodexService`. No service may share a name with a `game:GetService` name.
Approved by: owner (2026-10-16)

## D-009 — UI library
2026-10-16 · Deferred to A2.1
Context: `architecture.md` §22 recommends Fusion. Decision deferred until A2.1 when the first HUD is built; whichever is chosen is inserted from the Creator Store, pinned in `ART_SOURCES.md`, and logged here.

## D-010 — Unattended checkpoint mode
2026-10-16 · P0.1 · Accepted
Context: Every checkpoint stalled on two owner-only steps: the approval line (step 8) and a named Studio restore point (step 5), which the Studio MCP cannot create.
Decision: Step 5 becomes a timestamped place backup at `backups/<ID>_passed_<YYYYMMDD-HHMM>/` in the project folder: one `.rbxm` per service, exported with `SerializationService:SerializeInstancesAsync` (MCP cannot write a full `.rbxl`; Terrain, Camera and service-level properties are not captured; backups are git-ignored). Step 8: when steps 1–7 pass with real results, Claude writes the approval line itself as "Auto-approved under standing owner approval of 2026-10-16". This never covers the GO/NO-GO gates (A3.5, B4) or anything under STOP AND ASK (scope, schema, monetization, data-loss risk, budget miss after two attempts, deviations from §0/§4.4/§5/§7/§8/§21).
Alternatives: owner approves each checkpoint by hand (rejected: blocks unattended progress).
Consequences: checkpoints advance without the owner present; gates and owner decisions still wait.
Approved by: owner (2026-10-16, "Yes, approved" in the project chat)

## CP — P0.1 passed · 2026-10-16 · approved by owner

## CP — P0.2 passed · 2026-10-16 · Auto-approved under standing owner approval of 2026-10-16

## CP — P0.3 passed · 2026-10-16 · approved by owner ("Yes Approved" in the P0.3 thread, art direction + two mood references)

## D-011 — Content bible v0; rename Engineer → Mechanic and Essence → Serum
2026-10-16 · P0.4 · Accepted
Context: The P0.4 originality check against the reference game (*Survive The Swarm [CLASS COMBAT]*: Roblox listing + fan wikis) found two exact collisions: its "Engineer" class (similar deployables role) and its "Essence" currency (same use: buying classes and eggs).
Decision: Adopt `docs/CONTENT_BIBLE.md` v0 (classes, 8 enemies incl. new Burrower, zone boss names, zones, protocol level names Contact → Deadzone, 12 shared auto-weapons, 10 passives, 4 evolutions incl. new Junk Tornado, 6 pets). Rename class Engineer → **Mechanic** (architecture §7.5, ART_BIBLE, ROADMAP A4.4) and currency Essence → **Serum** (schema v1 field `Serum`, §6.1; §21.1; §25; ROADMAP B1.4; SYSTEM_REGISTRY rows renamed, not removed). Burrower added to the §8.3/§8.4 roster and the ART_BIBLE silhouette table.
Alternatives: keep both names (rejected: violates §1.3 "all names original"). Gauntlet mode also collides; deferred to its design (post-L3).
Consequences: schema change before any profile exists, so there is no migration and no data risk. Every later doc and definition uses Mechanic / Serum.
Approved by: owner (2026-10-16, "I do approve, rename approved for both", project chat 13:19 UTC)

## CP — P0.4 passed · 2026-10-16 · approved by owner ("I do approve, rename approved for both", project chat 13:19 UTC; content bible + D-011)

## D-012 — Paid random items: Robux cosmetic chests (O-1) and premium-track bonus currency (O-2)
2026-10-16 · P0.5 · **Proposed, awaiting owner**
Context: Roblox's paid random items policy covers random items bought directly or indirectly with Robux, including with paid in-game currency, and counts pity systems as probability modifiers. Two lines in the docs would make DEADZONE have paid random items: the §0 table says "Cosmetic-only Robux chests" (this contradicts §21.2 and §21.4 answer 3, "no chance purchases"), and §21.2 gives the premium battle pass "bonus currency". If that currency is Gold, Serum or Samples, eggs, gameplay chests and Forge rerolls become indirect paid random items.
Proposal (see `docs/COMPLIANCE.md` §3): O-1, sell cosmetics at fixed prices and correct the §0 row. O-2, premium-track bonus currency only buys fixed-price items (e.g. the season's event currency), never Gold, Serum or Samples.
Alternatives: keep both and treat eggs, chests and rerolls as paid random items (percent odds summing to 100% before spend, `ArePaidRandomItemsRestricted` handling per player).
Consequences: monetization and §0/§21 wording are owner decisions, so nothing has changed. The questionnaire answer 12 stays "No, pending O-1/O-2". This blocks nothing before B1 (the §21.5 re-check point).
Approved by: — (pending)

## CP — P0.5 passed · 2026-10-16 · Auto-approved under standing owner approval of 2026-10-16 (D-012 remains open for the owner; not covered by this approval)

## D-013 — Stage schedule, Beta art budget and weekly rhythm
2026-10-16 · P0.6 · Accepted
Context: P0.6 needs the owner's planned start date for each stage, a contractor budget line for the Beta art pass (architecture §22 step 3) and an agreed weekly rhythm.
Decision: Planned starts (Mondays, upper estimates): A1 2026-10-19, A2 2026-11-02, A3 2026-11-23, A3.5 2026-12-14, A4 2027-01-11, A5 2027-02-08, B1 2027-03-08, B2 2027-04-05, B3 2027-04-26, B4 2027-05-31, L1 2027-06-28, L2 2027-07-19, L3 2027-08-09 (Season 1 live ~2027-09-06), LO from the first Friday update ~2027-07-30. A3.5 stays over the year-end holidays (no 2-week shift). Beta art cap USD 14,300 (Standard tier incl. 15% contingency); no spend before the A3.5 GO; contracts at B3 start, delivery by 2027-06-11. Weekly rhythm per `ROADMAP.md` §1.1 (Mon–Fri Studio sessions with MCP connected, Friday review with batched owner decisions, gates in writing).
Alternatives: Lean (~USD 4,400) or Premium (~USD 38,800) art tier; shifting A3.5 and later stages by 2 weeks.
Consequences: dates are plans, not checkpoints. A stage past 150% of its estimate triggers the §17 scope response, and re-planned dates are logged here. Art rates are estimates until real quotes at B2.
Approved by: owner (2026-10-16, "all ok and approved, go ahead", P0.6 thread 13:46 UTC)

## CP — P0.6 passed · 2026-10-16 · approved by owner ("all ok and approved, go ahead", P0.6 thread 13:46 UTC; dates, budget and rhythm per D-013). P0 exit: all six ✅.

## D-014 — luau-lsp for checkpoint step 2 (Script Analysis)
2026-10-16 · A1.1 · Accepted
Context: Checkpoint step 2 needs "Script Analysis 0 warnings", but the Studio MCP cannot read Studio's Script Analysis window (no Luau API; `screen_capture` shows only the 3D viewport). Without a checker every checkpoint would wait on the owner.
Decision: Use luau-lsp 1.70.1 (github.com/JohnnyMorganz/luau-lsp, win64 release, sha256 64225b97…) installed outside the repo at `%USERPROFILE%/tools/luau-lsp/1.70.1`, with the Roblox `globalTypes.None.d.luau` definitions and `mirror/sourcemap.json` built from the Studio tree. `tools/analyze.sh` runs it over every mirrored `.luau` except `*/Vendor/*` (nonstrict third-party code, ROADMAP §0 step 2). Step 2 passes at "diagnostics: 0". Version and definitions are pinned; updating them is a new entry here.
Alternatives: owner reads Studio's Script Analysis window at every checkpoint (rejected: blocks unattended mode); syntax-only `loadstring` check (rejected: no type checking).
Consequences: analysis runs on the mirror, so the mirror export happens before step 2 from now on. luau-lsp can differ slightly from Studio; if they disagree, Studio wins.
Approved by: owner (2026-10-16, "ok download luau-lsp and install it", A1.1 thread 14:40 UTC)

## CP — A1.1 passed · 2026-10-16 · Auto-approved under standing owner approval of 2026-10-16

## CP — A1.2 passed · 2026-10-16 · Auto-approved under standing owner approval of 2026-10-16

## D-015 — Mirror export through one execute_luau bundle
2026-10-16 · A1.3 · Accepted
Context: architecture §4.2 describes the Git mirror as Claude exporting every script "via `script_read`". `script_read` returns numbered lines one script at a time, so byte-exact copies need reassembly and give no way to prove the copy equals Studio or that no script was missed.
Decision: The export runs `tools/mirror_export.luau` through `execute_luau` (read-only). It returns a manifest of every script and StringValue under the four roots (byte length + FNV-1a), the tree, a DataModel-wide script count and the sources in chunks under 100K characters. `tools/mirror_write.py` writes the files, checks every hash, deletes stale files, regenerates `mirror/sourcemap.json` and checks the counts. Scripts outside the four roots, nested scripts, case-insensitive duplicate names and names that can't be file names stop the export. Procedure in `docs/MIRROR.md`. `script_read` stays for reading single scripts and `script_search` for the count cross-check.
Alternatives: `script_read` per script (rejected: no byte-exact proof, one call per script); Rojo-style sync (rejected: §4.2 rules out Rojo).
Consequences: same purpose and output as §4.2 (backup, diff and review; never imported back); only the read method differs, so §4.2 is not edited. Vendor code is hash-checked in place and re-sent only with `INCLUDE_VENDOR = true`.
Approved by: implementation detail within §4.2, recorded under the standing owner approval of 2026-10-16 (D-010)

## CP — A1.3 passed · 2026-10-16 · Auto-approved under standing owner approval of 2026-10-16

## D-016 — Boot lifecycle details (Init/Start contract)
2026-10-16 · A1.4 · Accepted
Context: architecture §5.2 fixes the phase order, the `Service` type (`Name`, `Init`, `Start`) and "no Start before every Init", but not how a service resolves a dependency or what "bootstrap asserts order" checks.
Decision: `Server/Lifecycle` holds the §5.2 phase table and boots the plan built from the domain folders (every ModuleScript directly inside a domain folder is a service, booted in name order inside its domain). It fails the boot when: a phase is out of place; a service is listed outside its domain's phase or before a domain §5.2 boots earlier; a module's shape is wrong or its `Name` differs from the module name; two services share a name; a name is a Roblox built-in service name (`game:FindService` succeeds; CLAUDE.md rule 14); an `Init` errors or yields; a `Start` errors. Dependencies are resolved in `Init` with `Lifecycle.get(name)`, which only returns services that already initialized, so a dependency booting later fails with an order error. The §5.2 `Service` type is unchanged.
Alternatives: services declaring their own phase or dependency list (rejected: adds fields to the §5.2 type); letting `Init` yield (rejected: §5.2 says Init has no side effects, and a non-yielding Init keeps the order assertions deterministic).
Consequences: Init stays synchronous; waiting work (DataStore reads, MemoryStore) goes in `Start`. The domain API module (§5.1 "init") is not built yet; it arrives with the first domain that needs one. Three §5.1 names fail the built-in check (D-017).
Approved by: implementation detail within §5.2, recorded under the standing owner approval of 2026-10-16 (D-010)

## D-017 — §5.1 service names that are Roblox built-ins
2026-10-16 · A1.4 · Accepted
Context: `game:FindService` checked all 49 service names in architecture §5.1. Three are Roblox built-in service names, which CLAUDE.md rule 14 forbids and the A1.4 boot now rejects: `AnalyticsService` (Telemetry, A1.8), `PlayerDataService` (Data, A5), `MatchmakingService` (Social, A5). Renaming them changes §5.1 (STOP AND ASK).
Decision: `AnalyticsService` → `MetricsService`, `PlayerDataService` → `ProfileDataService`, `MatchmakingService` → `MatchmakerService` (all three checked free in Studio). A1.4 placeholders avoid the three names, so A1.4 was not blocked. Renamed in architecture §5.1 and the A1 deliverables list, ROADMAP A1.8 and EVENTS.md; the Roblox service itself is still called AnalyticsService where the docs mean it.
Approved by: owner (2026-10-16, "Approved", A1.4 thread 15:46 UTC)

## CP — A1.4 passed · 2026-10-16 · Auto-approved under standing owner approval of 2026-10-16

## D-018 — Event bus details (publisher identity, strict mode, payload rules)
2026-10-16 · A1.5 · Accepted
Context: architecture §5.3 fixes a typed bus in `shared/Events` with the authoritative domain as the only publisher, and A1.5 asks that a publish from the wrong domain asserts "in strict mode". It does not say how the bus knows the caller's domain, what strict mode is, or what "typed" means at runtime.
Decision: `Events/Catalog` lists every EVENTS.md event with its publisher identity (the ten §5.1 domains plus `Bootstrap` and `Definitions`), its "since" substage and a field schema (string non-empty, finite number, whole integer, boolean, Vector3, enum, array, map, record, oneOf; all fields required, no extras), and exports one Luau payload type per event. A service publishes through `bus:publisher("<Domain>")`; a publish is rejected when the event is unknown, the publisher is not the catalog publisher, or the payload fails its schema. Strict mode (Studio, tests) throws at the publisher; live servers report to the error handler and drop the event. Handlers get a deep-frozen copy, each in its own thread, so a handler error or yield never reaches the publisher. `EventBus.server()` is the one shared bus; Bootstrap publishes `BootCompleted` after phase 8.
Alternatives: deriving the domain from the calling script (`debug.info`; rejected: Luau inlining makes frames unreliable, as A1.2 found with `error` levels); throwing on live servers too (rejected: a consumer-facing bug would take down the publishing system mid-run); synchronous `pcall` delivery (rejected: a yielding handler would block the publisher).
Consequences: the publisher identity is declared, not proven; it guards against mistakes, not hostile server code (there is none; clients never reach the bus). Payload shapes for events whose substage is not built yet are provisional and are settled by that substage in Catalog and EVENTS.md. Publish costs 1.4 µs with no subscriber and 2.8 µs with one (EnemyKilled, Edit).
Approved by: implementation detail within §5.3, recorded under the standing owner approval of 2026-10-16 (D-010)

## CP — A1.5 passed · 2026-10-16 · Auto-approved under standing owner approval of 2026-10-16

## D-019 — Definitions registry details (layout, Ids, schemas, failure)
2026-10-16 · A1.6 · Accepted
Context: architecture §4.3 and §5.2 put `_Registry` in `Shared/Definitions` and make phase 3 validate all content ("server refuses to start on failure"); ROADMAP A1.6 asks for schema validation and duplicate-Id detection with one sample per folder. The architecture fixes schemas only for Classes (§7.5), Weapons (§10.1), Enemies (§8.4) and the §9.2 mission example. It does not say how a definition is laid out in Studio, whether Ids are unique per folder or across folders, or what the other 14 folders hold.
Decision: One ModuleScript per definition, directly inside its folder, returning one table whose `Id` equals the module name. Ids are unique across all folders, because the Codex and profiles key on bare DefinitionIds (§6.1). `_Registry` holds one schema per folder with these field types: Id, non-empty string, string, asset (`""` or `rbxassetid://<n>`), number or integer with bounds, boolean, enum, array, map, record, and a reference to another folder's Id. Fields are required unless marked optional, and unknown fields are rejected so typos fail. The Classes, Weapons, Enemies and Missions schemas copy the architecture. The other 14 are provisional and lean, built from the architecture text, and each names the substage that settles it: Passives and Evolutions A3.4, Protocol A3.5, Zones B2.2, Loot B1.5, Items B1.2, Skills B1.3, Pets and Eggs B3.1, Forge B1.7, Quests B2.6, Raids B3.7, Seasons and Shop L1.3. Folder rules: per-level arrays match `MaxLevel`/`MaxRank`; a weapon's `EvolutionIds` and each evolution's `WeaponId` agree, and recipe levels stay within the weapon's and passive's `MaxLevel`; a boss telegraphs for at least 0.6 s (§8.4); a mission's `BossId` is a Boss, its pool holds no boss and its extraction windows rise; loot and egg weights sum to 1 (§15); skill prerequisites are acyclic (§14); protocol `Level` and zone `Order` are unique; class unlock fields match their `Kind`; only Craft recipes have an output item; raids hold 1–12 players with min ≤ max (§4.4); a quest's `Event` is in the event catalog (§18); egg prices are gameplay currencies (§13); shop kinds are the §21.2 kinds, and a Robux price needs a product id. Every problem is collected into one `[Definitions] N problems in Shared/Definitions; the boot stops until they are fixed:` error. Bootstrap phase 3 calls `_Registry.shared()`, so any problem stops the boot before Economy initializes and before any `Start`. The registry hands out frozen deep copies. `DefinitionsValidated { Count }` is published under the `Definitions` identity after the Start pass, next to `BootCompleted`, because subscribers connect in `Start`. The vocabularies (stat ids, damage tags, rarity, archetypes, targeting, wallet currencies) are copied from STATS.md, ART_BIBLE, §7.4 and §6.1 until A1.7 adds `Shared/Stats`; A1.7 then points the registry at it. There are 19 samples: Enemies has Walker and MutantAlpha because the §9.2 mission names a boss. Names come from CONTENT_BIBLE, with `Sample*` names where it has none, and every number is a placeholder.
Alternatives: Ids unique per folder only (rejected: Codex keys would collide); one module holding many definitions (rejected: a copy-pasted entry hides inside one table and Studio diffs get noisy); stopping at the first problem (rejected: one fix per boot); publishing `DefinitionsValidated` inside phase 3 (rejected: nobody is subscribed yet); making the mission `BossId` optional (rejected: §9.2 has it, so a boss sample was added instead).
Consequences: each content substage settles its folder's schema in `_Registry`, with a decision entry when it changes a provisional shape. Luau types for definitions are declared by the substage that consumes them; the registry returns `{ [string]: unknown }`. The shop schema has no random-item kind, so D-012 (open, owner) is not decided here; if the owner picks O-1, L1.3 adds that kind. Measured: validation 0.94 ms at boot for 19 definitions; `Registry.load` 0.19 ms warm.
Approved by: implementation detail within §4.1, §4.3 and §5.2, recorded under the standing owner approval of 2026-10-16 (D-010)

## CP — A1.6 passed · 2026-10-16 · Auto-approved under standing owner approval of 2026-10-16

## D-020 — Stat pipeline and §6 types details (Bonus form, class multiplier, Armor cap, provisional sub-types)
2026-10-16 · A1.7 · Accepted
Context: A1.7 implements §7.3 and the §6 types. Read literally, the §7.3 formula `(Base + ΣFlat) × (1 + ΣAdditivePct) × ΠMultipliers` gives 0 for every percent stat whose Base is 0 (DamagePct, AttackSpeedPct, CooldownReduction, AreaSize, Range, XPGainPct, Luck, GoldFindPct, SignatureDurationPct, HealingPct), while the §7.3 damage formula uses `(1 + ΣDamagePct) × ΠDamageMults`. The class `DamageMult` appears both as a DamagePct Multiplier source (STATS.md, §7.3 layer table "class role modifier") and as the formula's own `ClassDamageMult` term. STATS.md gives Armor no numeric Max ("75% of incoming"). §6.1 names seven sub-types it never defines (ItemInstance is §11; Affix, Loadout, PetInstance, StageRecord, QuestState, RaidRecord and PlayerSettings are defined nowhere).
Decision: (1) Each stat has a Form. Value stats run the §7.3 formula on the value. Bonus stats (percent bonuses, Base 0) run the same formula on the factor `1 + value` and report `factor − 1`, so with AdditivePct only a Bonus is the plain sum, and DamagePct is exactly the damage formula's `(1 + ΣDamagePct) × ΠDamageMults − 1`. (2) The class DamageMult is fed to StatPipeline as a DamagePct Multiplier; DamageCalculator takes the attacker's StatBlock and uses `1 + DamagePct`, so the class term enters once and the -90%..+500% cap covers it. (3) Armor Max is 300, which is exactly the 75% reduction cap (300 / (300 + 100)); DamageCalculator.mitigate also caps the reduction at 75%. (4) Percentages are fractions in code. Fixed bases cannot be overridden; Class/Weapon bases must be passed; whole-number stats reject fractions; NaN/inf, unknown stats and disallowed layers throw; any finite input is clamped and never NaN. (5) The STATS.md rows live once in `Shared/Stats/StatRegistry`; `tools/check_stats.py` checks STATS.md against it. The vocabularies (rarity, archetypes, targeting, damage tags, currencies, slots) live once in `Shared/Types/Common`; `_Registry` uses those lists and now rejects a passive, skill node or pet whose layer its stat does not take. (6) PlayerProfile, RunPlayerState and MatchState copy §6.1–§6.3 field for field (schema v1 unchanged). The undefined sub-types get provisional lean shapes taken from the architecture text, each settled by the substage that builds it: Affix and Loadout B1.1, PetInstance B3.1, StageRecord B2.5, QuestState B2.6, RaidRecord B3.7, PlayerSettings A5.
Alternatives: literal formula for percent stats (rejected: every percent stat would be 0); a separate ClassDamageMult input to DamageCalculator (rejected: the class multiplier would be counted twice or the STATS.md source row would have to change); Armor uncapped with only the reduction capped (rejected: "every cap tested" needs a numeric Max, and 300 gives identical results); leaving the sub-types as `unknown` (rejected: §6.1 forbids placeholders and they would carry no checking).
Consequences: nothing is persisted before A5, so settling a provisional sub-type loses no data; changing a PlayerProfile field is still a schema change (STOP AND ASK). STATS.md has a Form column and a §10.2 passive table. Measured: compute 4.2 µs (0 modifiers) and 7.0 µs (20 modifiers), damage 0.37 µs, preview 16.8 µs (Server, best of 3 × 10,000).
Approved by: implementation detail within §6 and §7.3, recorded under the standing owner approval of 2026-10-16 (D-010); the readings above are listed for the owner to overrule
Owner response: 2026-10-16 17:28 UTC, project chat, "You decide" (owner delegated); the coordinator kept all four readings (Bonus form, class multiplier once, Armor Max 300, provisional sub-types). Accepted under owner delegation of 2026-10-16 (revisable).

## CP — A1.7 passed · 2026-10-16 · Auto-approved under standing owner approval of 2026-10-16

## D-021 — Network layer, SimulationClock and platform wrappers (A1.8 details)
2026-10-16 · A1.8 · Accepted
Context: A1.8 builds §9.1 (SimulationClock), §7.2 transport (contract registry, per-player token buckets, `buffer` codecs, remotes in phase 8 only) and the §5.1 Platform/Telemetry wrappers. The architecture does not say where the remote host lives, how phase 8 is enforced, what a "burst" is for the session flag, what limits server→client remotes get, where remote config is stored, or how a hitch moves the clock.
Decision: (1) `Shared/Net/{Contracts,Guard,TokenBucket,Codec}`; `Server/Gateway` (a server module next to `Lifecycle`, like it outside the domain folders) is the only code that creates remotes, in `ReplicatedStorage/Net/<Name>`, and `expose()` refuses unless `Lifecycle.currentPhase()` is 8 (the new `Lifecycle.currentPhase()` reports the phase during Init, Start and the network step, nil otherwise). Every client→server contract needs a handler before phase 8 or the boot fails. (2) Inbound order follows §7.1: identity (Player in this server, one payload argument) → token bucket → payload guard → handler; the handler does the other §19 checks. (3) Server→client remotes have no client rate; their inbound bucket is empty (burst 0), so every client fire is dropped and counted, which keeps §7.2's "every remote has a per-player token bucket". (4) Session flag: a burst is one run of rate drops for a player on one remote, ended when that remote's bucket next accepts a request; the third burst start inside 60 s flags the session once (`SessionFlagged` counter, `Gateway:isFlagged`). Flagging only marks; nothing is kicked. Steady spam above the rate produces a new burst after every refill, so 50× spam flags within the first second (measured). Decided by Claude under owner delegation of 2026-10-16 (revisable): the owner was asked in the A1.8 thread and answered with the delegation (D-022). (5) Outgoing pushes are checked by the same guard: Studio throws, live servers report, count and drop. (6) Codec types u8 u16 u32 i8 i16 i32 f32 f64 bool vector3 string (u16 length, ≤ 255 B by default); encoding bad values throws, decoding never throws. (7) `Encounter/SimulationClock` is both the §5.1 service (empty Init/Start) and the per-match factory; `Tick(dt)` adds `min(dt, MaxStep)`, MaxStep 0.25 s (the §7.1 rewind window), so a hitch slows the run instead of jumping it. (8) Remote config is the §20 `Config` DataStore, key `Current`, document `{ Flags?, Tunables? }`, read by RemoteConfigService in its Start (phase 0, before any later Start) and every 300 s; a section sets the override set (unlisted entries return to their defaults); bad values are reported and ignored; a failed read keeps current values. FeatureFlagService gets the Flags section through `apply`, publishes `FeatureFlagChanged` per change and pushes Client flags through the first remote, `FlagsUpdate` (API_CONTRACTS row since A1.8). Defaults live in `Shared/Config/{Flags,Tunables}` with one placeholder each (`SampleFlag`, `SampleTunable`) until A3.9/A3.2 add real ones. (9) Telemetry: `MetricsService` (D-017 name) validates and forwards funnel/economy/custom events to AnalyticsService and keeps server counters (Gateway counts go there); which counters reach the dashboard is A3.9's call. `ErrorReportService` prints one `[Error] kind: message` line per report with a 60 s repeat window and becomes the reporter of the Platform services, the Gateway and the event bus. A registry row for it was added (it is an A1.8 deliverable with no row). (10) Client controllers are `{ Name, start }` modules started by the client Bootstrap in their own threads. (11) `tools/check_contracts.py` checks Contracts against this file.
Alternatives: a Gateway service inside Platform (rejected: Platform boots in phase 0 and a service there would look callable before phase 8); payload guard before the rate limit as §19 lists it (rejected: §7.1 puts the rate limit first, and junk spam must cost the server as little as possible: 0.52 µs per dropped request vs 1.88 µs per guard rejection); every dropped request counting as a burst (rejected by the owner's delegation to the recommended option: three bunched packets after lag would flag); no MaxStep (rejected: one 2 s hitch would move every enemy 2 s at once); MemoryStore for config (rejected: §20 names a DataStore; MemoryStore stays an option for live-ops pushes later).
Consequences: the boot now waits for one DataStore read in phase 0 Start (157 ms warm, 905 ms cold in Studio). Each substage that adds a remote adds its Contracts entry, handler and spec in the same change; check_contracts.py fails while a row at or before the current substage has no contract. Measured (Server play test, best of 3): Gateway accepted 1.77 µs, rate-dropped 0.52 µs, payload-rejected 1.88 µs; TokenBucket take 0.12 µs; Clock Tick 0.07 µs; 90-enemy snapshot 1,532 B (22.4 KB/s at 15 Hz, under the 25 KB/s budget before remote overhead), encode 84 µs, decode 76 µs.
Approved by: implementation detail within §5.2, §7.1, §7.2, §9.1 and §20, recorded under the standing owner approval of 2026-10-16 (D-010); point (4) decided by Claude under owner delegation of 2026-10-16 (revisable)

## D-022 — Owner widens unattended mode to forks and owner decisions
2026-10-16 · A1.8 · Accepted
Context: D-010 auto-approved checkpoints but kept owner decisions and deviations from §0/§4.4/§5/§7/§8/§21 as STOP AND ASK. During A1.8 the owner was asked about the §7.2 burst definition and, separately, about D-020.
Decision: The owner's words (project chat, 2026-10-16 17:30 UTC): "I want a fully unattended experience so you do the recommended decision and later we can change". From now on Claude takes the recommended option at a fork instead of stopping, records it here as "Decided by Claude under owner delegation of 2026-10-16 (revisable)" with the alternatives, logs it in progress.md, mentions it in one line in the thread, and keeps going. Still waiting for the owner: real-money spend, publishing to the live game or to real players, and any risk of losing player data. GO/NO-GO gates (A3.5, B4) remain the owner's written decision.
Alternatives: keep asking at every fork (rejected by the owner).
Consequences: D-020 (owner said "You decide" at 17:28 UTC) and D-021 point (4) are settled under this delegation. D-012 (paid random items) touches monetization and the live game; it stays open for the owner.
Approved by: owner (2026-10-16, project chat 17:30 UTC, relayed by the coordinator)

## CP — A1.8 passed · 2026-10-16 · Auto-approved under standing owner approval of 2026-10-16
