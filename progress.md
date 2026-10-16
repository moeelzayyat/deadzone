# DEADZONE — progress log

Owner rule (2026-10-16): log project progress here so context survives session compression. Read this after `CLAUDE.md` and `docs/CURRENT_PHASE.md`. The log below is append-only; only "Current state" is rewritten.

## Current state
- **Substage:** A1.5 — Event bus (⬜ not started). A1.4 Domains and lifecycle ✅ passed 2026-10-16 (auto-approved). P0 complete.
- **Waiting on the owner:** D-012 (paid random items, O-1 Robux cosmetic chests / O-2 premium bonus currency), before B1. (D-017 service renames accepted 15:46 UTC.)
- **Last passed:** A1.4 Domains and lifecycle (auto-approved, D-010; contract D-016). Before that A1.3, A1.2, A1.1.
- **Lifecycle (D-016):** `Server/Lifecycle` boots the domain folders in §5.2 order. Init resolves dependencies with `Lifecycle.get` and must not yield; Start may yield. Built-in service names fail the boot.
- **Mirror (D-015):** `docs/MIRROR.md`. Paste `tools/mirror_export.luau` into execute_luau (Edit), then `python tools/mirror_write.py <result files>` → `ALL OK` + `MATCH`. Chunks at 95K (`START = next`); vendor re-sent only with `INCLUDE_VENDOR = true`. 17 scripts now (past script_search's cap of 10).
- **Repo:** https://github.com/moeelzayyat/deadzone, branch `main`.
- **Studio:** place 72812275891657 / universe 10771233280. The Studio MCP lists several open places; always target "Deadzone (placeId: 72812275891657)".
- **Place contents:** §4.3 layout (50 folders under the 4 roots), `Server/Bootstrap` (Script), `Server/Lifecycle` + one placeholder service per domain (A1.4), `Client/Bootstrap` (LocalScript), ProfileStore in `Server/Domains/Data/Vendor` with `ProfileStore_LICENSE`. `ServerStorage/Tests/TestRunner` + `Tests/unit/TestRunner.spec` (A1.2), `Tests/unit/Lifecycle.spec` (A1.4). Plus `ServerStorage/ArtReference` (P0.3 mood scenes).
- **Restore points (D-010):** `backups/<ID>_passed_<YYYYMMDD-HHMM UTC>/`, one `.rbxm` per service via `SerializationService`, git-ignored.
- **Script Analysis (D-014):** `bash tools/analyze.sh` after the mirror export (luau-lsp 1.70.1 at `~/tools/luau-lsp/1.70.1`, Roblox None-security definitions, `mirror/sourcemap.json` regenerated from the Studio tree). Pass = `diagnostics: 0`. Vendor excluded.
- **Working notes:**
  - Backup transfer: `execute_luau` returns base64 JSON. Outputs over ~64K characters are saved by the harness to a tool-results file, which is decoded locally; pad smaller outputs past 64K so they land in a file too. Outputs over 100K are truncated, so keep each call under that. Verify every file by length and FNV-1a against a hash computed in Studio. In Luau, multiply as `(bit32.lshift(h,24) + h*403) % 2^32`, because a plain `h*16777619` loses float precision.
  - `execute_luau` shows only the first return value; return one string.
  - Tests in Edit mode: `local tests = ServerStorage.Tests:Clone(); require(tests.TestRunner).run({tests.unit, tests.integration})`. Studio caches `require` per ModuleScript across execute_luau calls, so a plain require serves stale code after edits.
  - Studio can drop the place mid-session (updates, reopen). Re-run `list_roblox_studios`; the studio_id changes each time.
  - `insert_asset` sets `Sandboxed = true` on inserted scripts.
  - Long Python heredocs in the Bash tool can fail to parse; write the script to the scratchpad and run it.
  - HttpService is disabled in experience settings. Don't enable it to move files; that's an owner setting.
  - Lighting.Technology can't be read through MCP (RobloxScript capability).
  - Restoring Color3 values through `tostring` rounds them. Restore exact RGB values and diff against the previous backup.

## Log

### 2026-10-16 · P0.1 — Place and access · ✅ passed (owner-approved)
- Place created, Team Create on, MCP connected, Studio API access confirmed by a read-only DataStore probe, root folders created, throwaway link-check script written, play-tested and deleted.
- Unattended checkpoint mode approved by the owner (D-010, "Yes, approved" in the project chat 11:46 UTC). Step 5 became the per-service `.rbxm` backup, and step 8 is auto-approved except at gates and STOP-AND-ASK items.
- `.claude/settings.local.json` allows `mcp__Roblox_Studio__execute_luau` (git-ignored, per machine).
- Relayed by the coordinator: a permission check blocked batch shell edits during P0.1, so edits are made one file at a time.

### 2026-10-16 · P0.2 — Repository · ✅ passed (auto-approved, D-010)
- First commit `a6b0546` pushed to `main`, then `62bcd4b` added the checkpoint record.
- Git identity is repo-local: `moeelzayyat <262207486+moeelzayyat@users.noreply.github.com>`. There is no global identity on this machine.
- `.gitignore` covers `backups/` and `.claude/settings.local.json`. `.gitattributes` sets LF and marks binaries.

### 2026-10-16 · P0.3 — Art bible v0 · ✅ passed (owner-approved)
- Built two original mood scenes from primitives in Studio and captured them: `assets/mood/mood_A_evacuation_streets_P3.jpg` and `mood_B_epicenter_P7.jpg`. The scenes moved to `ServerStorage/ArtReference`, and lighting was restored.
- Drew the icon concept sketch (`assets/icons/icon_concept_sketch.svg` + `.png`, palettes A orange/teal and B magenta/green). It was rendered with headless Edge.
- Wrote `docs/ART_BIBLE.md` v0 covering the style spec, the silhouette table for the roster and classes, zone palettes with lighting presets, protocol colors, UI tokens and the icon concept. New rule from the shoot: players always get their own light and a white outline.
- An earlier "Yes, approved" (11:46 UTC) predated the review and was not counted. The owner then approved in the P0.3 thread ("Yes Approved", 13:01 UTC).
- Checkpoint: TestRunner n/a (A1), 0 scripts, play test with 0 errors (5 known UIBlox warnings). Backup `backups/P0.3_passed_20261016-1303` verified by hash. Commits `877f58b` and `410fd7e`. Phase advanced to P0.4.
- Owner added the PROGRESS LOG rule (13:04 UTC), and this file was created.

### 2026-10-16 · P0.4 — Content bible v0 · 🟨 in progress
- 13:10 UTC: started. Read CLAUDE.md, progress.md, CURRENT_PHASE, ROADMAP P0.4 row, architecture §2.3/§7.5/§8.4/§10/§13/§16/§21, last DECISION_LOG entries.
- Checked the reference game (Roblox listing + 3 fan wikis; one wiki looks partly AI-written and was discounted). Collisions: class "Engineer" (exact name, similar role), currency "Essence" (same use: classes and eggs), mode "Gauntlet" (post-L3, noted only).
- Wrote `docs/CONTENT_BIBLE.md` v0: 6 classes, 8 enemies (new: Burrower) + 6 zone bosses (5 new names), 6 zones, 7 protocol levels (Contact, Spread, Breach, Mutation, Surge, Overrun, Deadzone), 12 shared auto-weapons covering all 10 archetypes, 10 passives mapped to STATS.md, 4 evolutions (new: Junk Tornado), 6 pets mapped to the STATS.md pet stats.
- Waiting on the owner: approval of the names, plus decision 1 (Engineer → Mechanic, touches §7.5) and decision 2 (Essence → Serum, schema v1 field). Both are STOP-AND-ASK items and were not changed.
- 13:19 UTC: owner approved in the project chat: "I do approve, rename approved for both". Recorded as D-011.
- Renames applied: Engineer → Mechanic, Essence → Serum in architecture.md (§6.1 schema field, §7.5, §21.1, §25), ART_BIBLE, ROADMAP A4.4/B1.4, SYSTEM_REGISTRY (rows renamed, not removed), CONTENT_BIBLE. Burrower added to architecture §8.3/§8.4 and the ART_BIBLE silhouette table.
- Checkpoint: TestRunner n/a (A1), 0 scripts, play test 0 errors (5 known UIBlox warnings). Backup `backups/P0.4_passed_20261016-1321`: the place is unchanged since P0.3, so a fresh export matched the P0.3 files on length, FNV-1a, Adler-32 and reverse FNV. The P0.3 bytes were copied and re-verified (all 6 OK).
- Gotcha: inline execute_luau base64 output (under 64K) is not saved to a file, so writing it to disk means re-emitting it. When the place hasn't changed, comparing hashes against the previous backup is cheaper.

### 2026-10-16 · P0.4 — Content bible v0 · ✅ passed (owner-approved)
- Handoff record appended, CP line in DECISION_LOG, CURRENT_PHASE advanced to P0.5.
- Commit `d4d4a46`.

### 2026-10-16 · P0.5 — Compliance basics · 🟨 in progress
- 13:25 UTC: started. Read CLAUDE.md, progress.md, CURRENT_PHASE, ROADMAP P0.5 row, architecture §0/§4.2/§21/§22, DECISION_LOG D-005…D-011 + CP lines.
- Read Roblox Creator Hub "Content maturity and compliance" (questionnaire: violence, blood, fear, crude humor, gambling, language, romance, alcohol, social hangout, free-form creation, sensitive issues, paid random items, paid trading, media, AI) and "Paid random items policy guidelines". en.help.roblox.com returned 403, so the Help Center articles were not read.
- ProfileStore license checked on GitHub (MadStudioRoblox/ProfileStore): Apache-2.0, no NOTICE file, wally.toml 1.0.3, last commit 2025-07-31. The docs and README link asset 109379033046155 as the official library model. ART_SOURCES previously said "MIT-style"; that was wrong and is being corrected.
- 13:28 UTC: wrote `docs/COMPLIANCE.md` v0. It answers all 15 questionnaire sections (expected label Mild: violence and fear Mild/Repeated, no blood), sets 8 guardrails that force a resubmission, acknowledges §21 unchanged, and lists the review points (PT.3 submit, B1, L1.3, each season).
- Finding for the owner (D-012, proposed): the §0 "Cosmetic-only Robux chests" row and the premium-track "bonus currency" (§21.2) would make eggs, chests and rerolls paid random items under Roblox policy. Recommended: fixed-price cosmetics, and premium bonus currency limited to fixed-price sinks. Nothing was changed; answer 12 is "No, pending".
- `assets/ART_SOURCES.md`: ProfileStore row corrected to Apache-2.0 with its obligations and the GitHub version. Added a section on how to fill the License column.
- Checkpoint: TestRunner n/a (A1), 0 scripts, play test 0 errors (5 known UIBlox warnings). Fresh service exports matched P0.4 exactly, so the P0.4 bytes were copied to `backups/P0.5_passed_20261016-1330` (all 6 verified).

### 2026-10-16 · P0.5 — Compliance basics · ✅ passed (auto-approved, D-010)
- Handoff record appended, CP line in DECISION_LOG (D-012 left open for the owner), CURRENT_PHASE advanced to P0.6.
- Commit `fa73fd4`.

### 2026-10-16 · P0.6 — Budget and cadence · 🟨 in progress
- 13:39 UTC: started. Read CLAUDE.md, progress.md, CURRENT_PHASE, ROADMAP (P0.6 row, master tracker, §16 LO cadence, §17 risks), architecture §22 (sourcing plan step 3) and §24, DECISION_LOG D-005…D-012 + CP lines.
- Plan: draft a suggested start date per stage (Mondays, upper/mid estimates), a Beta art budget line (§22 step 3) and a weekly rhythm, mark them "proposed" in ROADMAP, and ask the owner in the P0.6 thread. Dates, budget and rhythm are owner decisions; P0.6 cannot pass until the owner writes the dates. D-012 is not touched here.
- 13:47 UTC: wrote `docs/ROADMAP.md` §1.1 and a "Planned start" column in the master tracker, every date marked "(proposed)". Schedule: Monday starts, A1/A2 upper estimates, A3.5 = 1 prep + 3 live; P0 → L2 = 39.5 weeks (L2 2027-07-19). A3.5 overlaps year-end holidays; offered a 2-week shift.
- Beta art budget line (§22 step 3): scope 6 classes, 8 fodder, 6 bosses, 136 animations, 6 zone kits, hub, ~60 icons, 11 cards/portraits. Lean ~$4.4k / Standard ~$14.3k / Premium ~$38.8k with 15% contingency. Lean anchored on a few Roblox freelancer price lists (DevForum, Fiverr, Carrd, mostly undated); Standard/Premium are assumptions. Cap left blank for the owner. Proposed: no spend before A3.5 GO; contracts at B3 start.
- Weekly rhythm drafted: Mon–Fri Studio sessions with MCP connected, unattended checkpoints, Friday review with batched owner decisions, gates in writing.
- CURRENT_PHASE set to 🟦 checkpoint pending. Asking the owner in the P0.6 thread for: stage start dates (accept or edit), budget cap, rhythm.
- 13:46 UTC: owner replied in the P0.6 thread: "all ok and approved, go ahead". Read as: proposed dates accepted (no holiday shift), Standard art tier (recommended), rhythm agreed. Recorded as D-013; "(proposed)" markers removed from ROADMAP.
- Checkpoint: TestRunner n/a (A1), 0 scripts, play test 0 errors (5 known UIBlox warnings). Fresh service exports matched P0.5 exactly, so the P0.5 bytes were copied to `backups/P0.6_passed_20261016-1346` (all 6 verified).

### 2026-10-16 · P0.6 — Budget and cadence · ✅ passed (owner-approved, D-013)
- Handoff record appended, CP line in DECISION_LOG, ROADMAP master tracker P0 → ✅, CURRENT_PHASE advanced to A1.1. P0 exit met.
- Commit `5dedf15`.

### 2026-10-16 · A1.1 — Studio layout · 🟨 in progress
- 13:50 UTC: started (ahead of the planned 2026-10-19 A1 start; allowed under unattended mode). Read CLAUDE.md, progress.md, CURRENT_PHASE, ROADMAP A1 table and §0/§18, architecture §4.1–§5.3 and §28, DECISION_LOG D-004…D-013 + CP lines, ART_SOURCES.
- Plan: create the §4.3 folder tree in Studio (Shared subfolders + Definitions/*, Server Domains/* + Admin, Client Controllers/UI/Effects/Render, Tests unit/integration/fixtures/profiles); `Server/Bootstrap` and `Client/Bootstrap` that walk phases 0–8 and print `[Boot] phases 0–8 complete` with the ordered service list (empty until A1.4 adds placeholder services); insert ProfileStore into `Domains/Data`, diff against GitHub, add a LICENSE StringValue, pin in ART_SOURCES. No domain `Init`/`Start` contract or assertions yet (A1.4).
- 13:52 UTC: created 45 folders (Shared: Types, Definitions + 18 subfolders, Stats, Net, Events, Config, Util; Server: Domains + 10 domains, Admin; Client: Controllers, UI, Effects, Render; Tests: unit, integration, fixtures/profiles).
- 13:53 UTC: inserted ProfileStore (asset 109379033046155) into `Server/Domains/Data/Vendor` (a subfolder, so Bootstrap does not count it as a service). Compared with GitHub: `ProfileStore.luau` last changed in 9580f7c (2025-03-25), the same day as the store asset; the store copy equals it except whitespace-only lines (identical after blanking them, FNV-1a a797d1a7 on both sides). Kept unmodified (FNV-1a 1e3a6f3f, 64,517 B). Added `ProfileStore_LICENSE` StringValue, byte-identical to the repo LICENSE (dc4aedc0). ART_SOURCES row updated.
- Gotcha: `insert_asset` sets `Sandboxed = true` on inserted scripts with a capability list (DataStore, Network, ServerCommunication included). Left as is; a play-test require reached DataStoreState = Access in 0.64 s.
- Gotcha: ProfileStore has no `--!strict` header (nonstrict). ROADMAP §0 step 2 scopes the zero-warning rule to `--!strict` modules, and editing the vendor file would break "unmodified", so it is not changed.
- 13:55 UTC: wrote `Server/Bootstrap` and `Client/Bootstrap` (`--!strict`). Server checks the layout, walks phases 0–8 in §5.2 order, lists ModuleScripts directly inside each domain folder as services (none yet), counts remotes under ReplicatedStorage (0), asserts all 10 domains appear exactly once.
- Play test: `[Boot] phases 0–8 complete in 0.40 ms · services (0): none yet`, client `ready ... in 0.01 ms`, 0 errors, 5 known UIBlox warnings.
- Script Analysis: no MCP/Luau API exposes it (probed ScriptEditorService and other service names; screen_capture shows only the 3D viewport). No local analyzer on this machine (only rojo under aftman). Asked the owner.
- 13:57 UTC: backup `backups/A1.1_passed_20261016-1357`: 6 files verified by length + FNV-1a (Lighting and Workspace unchanged since P0.6, copied). Trick: pad the execute_luau JSON past 64K so the harness saves it to a file instead of inlining.
- Mirror: `mirror/src/server/Bootstrap.server.luau`, `mirror/src/client/Bootstrap.client.luau`, `mirror/src/server/Domains/Data/Vendor/ProfileStore.luau` + `ProfileStore_LICENSE.txt` (Studio `Server`→`server`, `Client`→`client`, `Shared`→`shared`, `Tests`→`tests`, per §4.3). Hashes match Studio.
- 14:40 UTC: owner: "ok download luau-lsp and install it". Downloaded luau-lsp 1.70.1 win64 (sha256 matched the release digest 64225b97…) into `~/tools/luau-lsp/1.70.1`, plus `globalTypes.None.d.luau` from luau-lsp main 8e8a4e7 (2026-10-15). Built `mirror/sourcemap.json` from the Studio tree, added `tools/analyze.sh`.
- Analysis: project scripts 2 → 0 diagnostics. Negative control (scratch file) reported all 5 planted issues. Vendor ProfileStore: 2 TypeErrors + 3 lints, out of scope (nonstrict, unmodified). Recorded as D-014.
- Place unchanged since the 13:57 backup, so that backup stands.

### 2026-10-16 · A1.1 — Studio layout · ✅ passed (auto-approved, D-010)
- Handoff record appended, D-014 + CP line in DECISION_LOG, CURRENT_PHASE advanced to A1.2, ROADMAP footer updated (A1 stays 🟨 in the master tracker).
- Commits `f1b0599` (build + mirror) and `2bd5cfd` (analysis + pass).

### 2026-10-16 · A1.2 — TestRunner · 🟨 in progress
- 14:47 UTC: started. Read CLAUDE.md, progress.md, CURRENT_PHASE, ROADMAP A1.2 row and §0, architecture §4.3/§20 (TestRunner row, ~150-line harness)/§26, DECISION_LOG D-012…D-014 + CP lines, A1.1 handoff.
- Blocker: `list_roblox_studios` returns no Studio (twice). Only `RobloxStudioInstaller` is running (Studio likely updating). Asked the owner to reopen the Deadzone place. Drafting TestRunner + 3 sample tests locally meanwhile, checked with luau-lsp before they go into Studio.
- 14:58 UTC: Studio back (Deadzone 72812275891657). Created `ServerStorage/Tests/TestRunner` (ModuleScript, `--!strict`) and `Tests/unit/TestRunner.spec` (3 tests: matchers, failing-matcher message, async yield). Edit-mode run: `3 passed, 0 failed (1 file, 131.67 ms)`.
- Gotcha: execute_luau (Edit) caches `require` per ModuleScript across calls, so edits to a module are not seen until a clone is required. Checkpoint runs use `Tests:Clone()` (usage comment in TestRunner). Play-test (Server) requires are fresh. Modules under test in later substages hit the same cache.
- Gotcha: `error(msg, level)` positions are unreliable in Studio (Luau inlining shifts frames). Matchers throw with level 0 and the runner appends "(line N)" from the first traceback frame inside the spec.
- Negative control (3 throwaway specs outside the DataModel): `1 passed, 7 failed`: matcher fail (line 4), runtime error, timeout 0.20 s, fail after yield (line 10), toThrow on non-throwing fn (line 12), spec returning a non-function, spec erroring at load. All line numbers correct.
- Play test: Server datamodel `3 passed, 0 failed (1 file, 132.98 ms)`; boot log unchanged (0.37 ms); 0 errors, 5 known UIBlox warnings.
- 15:05 UTC: MCP lost Studio right after the play test stopped; Studio is running again but on its start page ("Place is not open"). Asked the owner to reopen Deadzone. Remaining: mirror export + sourcemap, luau-lsp, backup, handoff, approval, phase advance.
- 15:17 UTC: owner reopened Deadzone (new studio_id). Scripts persisted; suite re-run on a clone: `3 passed, 0 failed (1 file, 131.84 ms)`.
- Mirror: `mirror/src/tests/TestRunner.luau` (8894 B b61ebc85), `mirror/src/tests/unit/TestRunner.spec.luau` (1088 B a07a2957); 4 existing files re-verified; sourcemap regenerated. `tools/analyze.sh`: files 4, diagnostics 0.
- Backup `backups/A1.2_passed_20261016-1518`: 6 fresh exports, all verified by length + FNV-1a. Workspace grew 7831 → 12147 B with unchanged children after the Studio update; SSS and StarterPlayerScripts same length, new hash (child order). Noted, not investigated.

### 2026-10-16 · A1.2 — TestRunner · ✅ passed (auto-approved, D-010)
- Handoff record appended, CP line in DECISION_LOG, CURRENT_PHASE advanced to A1.3, ROADMAP footer updated (A1 stays 🟨).
- Commit `4905af7` (build, mirror, pass), then a commit recording the hash.

### 2026-10-16 · A1.3 — Git mirror · 🟨 in progress
- 15:22 UTC: started. Read CLAUDE.md, progress.md, CURRENT_PHASE, ROADMAP A1.3 row, architecture §4.2/§4.3, DECISION_LOG D-012…D-014 + CP lines, A1.2 handoff.
- Studio connected (Deadzone 72812275891657). Whole-DataModel scan: 5 LuaSourceContainers, all under the 4 roots (Server/Bootstrap, Client/Bootstrap, Data/Vendor/ProfileStore, Tests/TestRunner, Tests/unit/TestRunner.spec).
- Plan: put the A1.2 one-off procedure in the repo as `tools/mirror_export.luau` (run through execute_luau, returns manifest + tree + sources, chunked under 100K) and `tools/mirror_write.py` (writes files, verifies length + FNV-1a, deletes stale mirror files, regenerates the sourcemap, prints the script count check), documented in `docs/MIRROR.md`.
- 15:30 UTC: wrote `tools/mirror_export.luau` (Studio side, read-only; manifest + tree + chunked sources, padded to 66K, errors for scripts outside the roots / nested scripts / case-insensitive duplicate names / non-file-safe names) and `tools/mirror_write.py` (writes, verifies length + FNV-1a, deletes stale files, regenerates sourcemap, count check). luau-lsp on the export script: 0 diagnostics.
- Export run: 1 call (66K padded, saved by the harness) → `ALL OK`, written 4, `scripts: DataModel 5 · under roots 5 · mirror 5 · StringValues 1/1 · MATCH`. Sourcemap now sorted by name; equivalent to the A1.2 one ignoring child order.
- Full rebuild test: deleted mirror/src/{client,server,tests}, exported with INCLUDE_VENDOR = true → 2 chunks (91,850 chars, next = 5; then 66K) → written 6, all OK, `git status` shows no source changes. One chunk alone → `INCOMPLETE: run the export again with START = 5`.
- Negative controls: local — stale file deleted (DEL), hand-edited vendor file BAD, hand-edited non-vendor file overwritten, injected error → "nothing written", parts with different manifests → MISMATCH. Studio — 6 temporary instances (script in ServerStorage root, Dup/dup, nested module, `bad:name`) → all 4 error kinds reported (DataModel 11 / under roots 10); then destroyed, back to 5 scripts.
- `script_search` ("Bootstrap, TestRunner, ProfileStore, spec") lists 5 scripts = 5 `.luau` mirror files. It caps at 10 results, so past 10 scripts the export's DataModel count is the reference (documented in `docs/MIRROR.md`).
- Checkpoint so far: TestRunner (Edit clone) `3 passed, 0 failed (1 file, 132.96 ms)`; analyze.sh files 4 / diagnostics 0; play test Server `3 passed, 0 failed (132.82 ms)`, boot 0.35 ms, 0 errors, 5 known UIBlox warnings.
- Timestamp correction: the "15:30 UTC" line above was ~15:26 UTC (backup clock read 15:27).
- 15:27 UTC: backup `backups/A1.3_passed_20261016-1527`: 5 services equal A1.2 (copied), Workspace exported fresh (7831 B eaa94454); all 6 verified against Studio.
- Docs: `docs/MIRROR.md` (procedure), D-015 (export method), README pointer, handoff record, CP line, CURRENT_PHASE → A1.4, ROADMAP footer.

### 2026-10-16 · A1.3 — Git mirror · ✅ passed (auto-approved, D-010)
- Steps 1–7 met with real results (TestRunner 3/0, analysis 0, play test 0 errors, counts MATCH 5 = 5, backup verified, mirror committed, handoff appended). CP line written, CURRENT_PHASE advanced to A1.4.
- Commit `09202d7` (build, docs, pass), then a commit recording the hash.

### 2026-10-16 · A1.4 — Domains and lifecycle · 🟨 in progress
- 15:33 UTC: started. Read CLAUDE.md, progress.md, CURRENT_PHASE, ROADMAP A1.4 row, architecture §4.1–§5.3, DECISION_LOG D-012…D-015 + CP lines, A1.3 handoff.
- Finding: `game:FindService` succeeds for any Roblox service class name. Of the 49 service names in architecture §5.1, three are Roblox built-ins: `AnalyticsService` (A1.8), `PlayerDataService` (A5), `MatchmakingService` (A5). CLAUDE.md rule 14 forbids them; renaming touches §5.1 (STOP AND ASK). Placeholders avoid them; asked the owner for names (not blocking A1.4).
- Studio dropped once (~15:35 UTC) and came back on its own (new studio_id). Drafts were written locally and checked with luau-lsp meanwhile.
- 15:39 UTC: added `Server/Lifecycle` (ModuleScript: §5.2 phase table, `plan`/`validate`/`run`/`boot`/`get`), 10 placeholder services (Platform/RemoteConfigService, Telemetry/ErrorReportService, Data/MigrationService, Economy/TransactionService, Progression/ClassService, Combat/CombatService, Encounter/MissionSessionService, Social/PartyService, Facilities/ShopService, LiveOps/SeasonService), `Server/Bootstrap` now boots through Lifecycle, `Tests/unit/Lifecycle.spec` (14 tests).
- Edit run (Tests clone): `17 passed, 0 failed (2 files, 131.73 ms)`; Lifecycle.spec 14/0 in 3.56 ms.
- Mutation control: Lifecycle copy with the phase-membership check off still throws on the swap (domain-rank check); with both checks off the swapped plan boots (Economy first), so the swap test depends on the assertion.
- 15:41 UTC: play test: boot `phases 0–8 complete in 0.13 ms (Init 0.10 ms, Start 0.00 ms) · services (10)` in §5.2 order; Server suite `17 passed, 0 failed (2 files, 132.29 ms)`; 0 errors, 5 known UIBlox warnings.
- Mirror export: 1 call (69 KB, saved by the harness) → `ALL OK`, written 16, `scripts: DataModel 17 · under roots 17 · mirror 17 · StringValues 1/1 · MATCH`; local drafts equal the export (`diff -r` clean). `tools/analyze.sh`: files 16, diagnostics 0.
- 15:42 UTC: backup `backups/A1.4_passed_20261016-1542`: SSS 41821 B f7c13864 and ServerStorage 57616 B 2b661855 exported (base64 via `EncodingService:Base64Encode`); Lighting, ReplicatedStorage, StarterPlayerScripts, Workspace equal A1.3 (copied). All 6 verified.
- Docs: D-016 (lifecycle details), D-017 (proposed renames, owner), SYSTEM_REGISTRY row → Tested, API_CONTRACTS boot lifecycle table, handoff record, CP line, CURRENT_PHASE → A1.5, ROADMAP footer.

### 2026-10-16 · A1.4 — Domains and lifecycle · ✅ passed (auto-approved, D-010)
- Commit `c708c1e` (build, mirror, docs, pass), then a commit recording the hash.
- Steps 1–7 met with real results (TestRunner 17/0, analysis 0, play test 0 errors, numbers recorded, backup verified, mirror committed, handoff appended). CP line written, CURRENT_PHASE advanced to A1.5. D-017 waits on the owner (not blocking A1.5).
- 15:46 UTC: owner approved D-017 in the A1.4 thread ("Approved"): `AnalyticsService` → `MetricsService`, `PlayerDataService` → `ProfileDataService`, `MatchmakingService` → `MatchmakerService`. Applied to architecture §5.1 + A1 deliverables list, ROADMAP A1.8, EVENTS.md. An earlier re-delivered message ("rename approved for both", 13:19 UTC) was the P0.4 approval (D-011) and was not counted. No Studio change (no service uses these names yet).
