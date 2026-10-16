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
