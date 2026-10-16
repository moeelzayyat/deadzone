# DEADZONE — progress log

Owner rule (2026-10-16): log project progress here so context survives session compression. Read this after `CLAUDE.md` and `docs/CURRENT_PHASE.md`. The log below is append-only; only "Current state" is rewritten.

## Current state
- **Substage:** A1.1 — Studio layout (🟦 checkpoint pending, started 2026-10-16 13:50 UTC). Steps 1, 3–6 done; step 2 (Script Analysis) can't be read through MCP, asked the owner how to verify it. Handoff record and approval wait on that. P0 is complete (all six ✅).
- **Waiting on the owner:** A1.1 Script Analysis check (owner reads the Script Analysis window, or allows downloading luau-lsp for an unattended check). D-012 (paid random items, O-1 Robux cosmetic chests / O-2 premium bonus currency). Must be decided before B1.
- **Last passed:** P0.6 Budget and cadence (owner-approved 2026-10-16, D-013: stage dates, Beta art cap USD 14,300, weekly rhythm in ROADMAP §1.1). Before that, P0.5 Compliance basics (auto-approved).
- **Repo:** https://github.com/moeelzayyat/deadzone, branch `main`.
- **Studio:** place 72812275891657 / universe 10771233280. The Studio MCP lists several open places; always target "Deadzone (placeId: 72812275891657)".
- **Place contents:** §4.3 layout (50 folders under the 4 roots), `Server/Bootstrap` (Script), `Client/Bootstrap` (LocalScript), ProfileStore in `Server/Domains/Data/Vendor` with `ProfileStore_LICENSE`. Plus `ServerStorage/ArtReference` (P0.3 mood scenes).
- **Restore points (D-010):** `backups/<ID>_passed_<YYYYMMDD-HHMM UTC>/`, one `.rbxm` per service via `SerializationService`, git-ignored.
- **Working notes:**
  - Backup transfer: `execute_luau` returns base64 JSON. Outputs over ~64K characters are saved by the harness to a tool-results file, which is decoded locally. Outputs over 100K are truncated, so keep each call under that. Verify every file by length and FNV-1a against a hash computed in Studio. In Luau, multiply as `(bit32.lshift(h,24) + h*403) % 2^32`, because a plain `h*16777619` loses float precision.
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
