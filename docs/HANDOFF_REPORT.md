# HANDOFF REPORT

Append-only. One record per checkpoint (template: `ROADMAP.md` §18) and one per implementation task (template: `architecture.md` §27.1). Newest at the bottom.

---

## Project initialized — 2026-10-16
Repository scaffold created: `architecture.md` v2.0, `CLAUDE.md`, `README.md`, `docs/*` seeded, `assets/ART_SOURCES.md`, `mirror/`.
Current substage: **P0.1 — Place and access**.
Nothing has been built in Studio yet. No tests exist yet. No numbers have been measured.

---

## P0.1 — Place and access — 2026-10-16

```text
CHECKPOINT: P0.1 Place and access
DATE: 2026-10-16
TESTRUNNER: n/a — TestRunner is an A1 deliverable; no tests exist yet.
SCRIPT ANALYSIS: 0 user scripts in the place after cleanup, so nothing to analyse. The throwaway
  script was 3 lines with --!strict. (Script Analysis panel is not readable through MCP.)
PLAY TEST: start_stop_play(start) → server reported 1 player with character spawned →
  get_console_output → start_stop_play(stop).
  Console: "[P0.1] studio link ok" printed. Console errors: 0.
  Warnings: 5 × "[UIBlox - Warning] FoundationProvider not found" from Roblox CorePackages
  (engine UI, not project code).
NUMBERS: none named by this checkpoint. Recorded IDs:
  place 72812275891657 · universe 10771233280 · creator user 11752219158 · place created 2026-10-16T11:35:33Z
  ProfileStore asset 109379033046155 (loleris), asset updated 2025-03-25T15:59:32Z
RESTORE POINT: "P0.1 passed" — pending owner (Studio version-history naming is not reachable through MCP)
MIRROR COMMIT: n/a — no scripts remain to export; the local folder is not yet a Git repo (P0.2 deliverable).
OWNER APPROVAL: pending
NOTES / DEBT:
  - Studio MCP: list_roblox_studios shows "Deadzone (placeId: 72812275891657)".
  - Studio API access: DataStoreService:GetDataStore("P01_probe"):GetAsync succeeded in Edit.
  - Team Create: on (NetworkClient + DraftsService present in the Edit DataModel, collaborator
    Player object present).
  - StreamingEnabled = true.
  - Root folders created: ReplicatedStorage/Shared, ServerScriptService/Server,
    StarterPlayer/StarterPlayerScripts/Client, ServerStorage/Tests.
  - Throwaway ServerScriptService/Server/P01_LinkCheck written with multi_edit, read back with
    script_read, play-tested, then deleted.
  - The probe DataStore "P01_probe" was only read, never written.
NEXT: P0.2
```

### P0.1 addendum — 2026-10-16 (checkpoint closed)
```text
RESTORE POINT: backups/P0.1_passed_20261016-1152/ — 6 × .rbxm via SerializationService (rule: D-010)
  Workspace 2 inst / 7831 B · Lighting 5 / 3445 B · ReplicatedStorage 1 / 577 B ·
  ServerScriptService 1 / 577 B · ServerStorage 1 / 576 B · StarterPlayerScripts 1 / 577 B.
  Byte counts match Studio's export; every file starts with the <roblox! binary header.
OWNER APPROVAL: yes, 2026-10-16 ("Yes, approved" in the project chat; "go ahead" in the P0.1 thread)
RESULT: P0.1 ✅ Passed. NEXT: P0.2
```

---

---

## P0.2 — Repository — 2026-10-16

```text
CHECKPOINT: P0.2 Repository
DATE: 2026-10-16
TESTRUNNER: n/a — TestRunner is an A1 deliverable (D-002); no tests exist yet.
SCRIPT ANALYSIS: 0 scripts in the place (search_game_tree, LuaSourceContainer → none), so nothing to analyse.
PLAY TEST: start_stop_play(start) → execute_luau(Server): players=1 character=true, printed
  "[P0.2] play test ok" → get_console_output → start_stop_play(stop).
  Console errors: 0. Warnings: 5 × "[UIBlox - Warning] FoundationProvider not found" from Roblox
  CorePackages (engine UI, not project code; same as P0.1).
NUMBERS: tracked files in first commit = 21 · working tree excluding .git and backups = 191 KB ·
  README.md = 64 lines · remote refs/heads/main = a6b0546f0853d586c65cd343c3cb406feb7415a5
  (git ls-remote, matches local HEAD).
RESTORE POINT: backups/P0.2_passed_20261016-1209/ — 6 × .rbxm (rule: D-010)
  Fresh SerializationService export of the six services: Workspace 7831 B · Lighting 3445 B ·
  ReplicatedStorage 577 B · ServerScriptService 577 B · ServerStorage 576 B · StarterPlayerScripts 577 B.
  Size and FNV-1a of every fresh export equal the P0.1 files byte for byte (place unchanged since P0.1),
  so the folder was written from those verified-identical bytes. Every file starts with <roblox!.
MIRROR COMMIT: a6b0546 "P0.2: initial repository" (mirror/src empty: 0 scripts to export)
OWNER APPROVAL: Auto-approved under standing owner approval of 2026-10-16 (D-010)
NOTES / DEBT:
  - Repo: https://github.com/moeelzayyat/deadzone, branch main, first push 2026-10-16.
  - Commit identity is repo-local: moeelzayyat <262207486+moeelzayyat@users.noreply.github.com>
    (no global git identity was set on this machine).
  - .gitignore now also ignores backups/ and .claude/settings.local.json (check-ignore verified);
    .gitattributes added (text=auto eol=lf, .rbxm/.rbxl/.png/.jpg binary).
  - README rewritten around: open the place (IDs, Team Create, API access), connect the Studio
    MCP (list_roblox_studios check), run tests (TestRunner from A1, play tests), backups per D-010.
  - architecture.md §4.2 still says Studio Version History named restore points; D-010 supersedes
    that for checkpoints. Left unedited (doc owner's call), README follows D-010.
NEXT: P0.3
```

---

## P0.3 — Art bible v0 — 2026-10-16

```text
CHECKPOINT: P0.3 Art bible v0
DATE: 2026-10-16
TESTRUNNER: n/a — TestRunner is an A1 deliverable (D-002); no tests exist yet.
SCRIPT ANALYSIS: 0 scripts in the place (execute_luau scan of LuaSourceContainer in project services → 0), nothing to analyse.
PLAY TEST: start_stop_play(start) → execute_luau(Server): players=1 character=true
  ArtReferenceInServerStorage=true, printed "[P0.3] play test ok" → get_console_output → start_stop_play(stop).
  Console errors: 0. Warnings: 5 × "[UIBlox - Warning] FoundationProvider not found" (Roblox CorePackages, same as P0.1/P0.2).
NUMBERS: docs/ART_BIBLE.md = 1,384 words · mood A 214,556 B, mood B 217,146 B (1920×895 Studio captures) ·
  icon sketch PNG 1064×652 · ServerStorage/ArtReference = 1,349 BaseParts (mood A 188 env + characters,
  mood B 119 env + characters) · 50 zombies in scene A, 87 + 3 Brutes in scene B · third-party asset IDs used: 0.
RESTORE POINT: backups/P0.3_passed_20261016-1303/ — 6 × .rbxm via SerializationService (rule: D-010)
  Workspace 7831 B · Lighting 3445 B · ReplicatedStorage 577 B · ServerScriptService 577 B ·
  ServerStorage 48583 B (new: ArtReference) · StarterPlayerScripts 577 B.
  Transfer: base64 from execute_luau, decoded locally; every file's length and FNV-1a match the hash computed
  in Studio (Lighting 866e3754, ServerStorage e36937fc). Every file starts with <roblox!.
MIRROR COMMIT: 877f58b "P0.3: art bible v0, mood references, icon sketch; advance to P0.4" (mirror/src empty: 0 scripts to export)
OWNER APPROVAL: yes, 2026-10-16 ("Yes Approved" in the P0.3 thread, 13:01 UTC)
NOTES / DEBT:
  - Mood references are original Studio captures of primitive scenes, kept in ServerStorage/ArtReference
    (reshoot by dragging into Workspace; lighting presets are in ART_BIBLE.md).
  - Lighting was changed for the captures and restored; the first restore rounded Atmosphere Color/Decay
    (~1e-6), caught by the byte diff against P0.2 and fixed with exact RGB values. Lighting now hashes
    identical to P0.2 (866e3754).
  - New art rule from the shoot: players always get their own light + white outline (Highlight, players only).
  - Lighting technology (Future vs ShadowMap) left to A1 against the mobile FPS budget; not readable via MCP
    (RobloxScript capability).
  - An earlier "Yes, approved" (project chat, 11:46 UTC) predated the review and was not counted.
NEXT: P0.4
```

```text
CHECKPOINT: P0.4 Content bible v0
DATE: 2026-10-16
TESTRUNNER: n/a — TestRunner is an A1 deliverable (D-002); no tests exist yet.
SCRIPT ANALYSIS: 0 scripts in the place (execute_luau scan of LuaSourceContainer in 8 services → scripts=0), nothing to analyse.
PLAY TEST: start_stop_play(start) → execute_luau(Server): players=1 character=true ArtReference=true,
  printed "[P0.4] play test ok" → get_console_output → start_stop_play(stop).
  Console errors: 0. Warnings: 5 × "[UIBlox - Warning] FoundationProvider not found" (Roblox CorePackages, same as P0.1–P0.3).
NUMBERS: docs/CONTENT_BIBLE.md = 2184 words · 6 classes · 8 enemies (1 new: Burrower) + 6 zone bosses (5 new names) ·
  6 zones · 7 protocol levels · 12 shared auto-weapons covering 10/10 archetypes · 10 passives (10/10 map to STATS.md rows) ·
  4 evolutions (1 new: Junk Tornado) · 6 pets (6/6 use STATS.md pet stats) · reference-name collisions found 3
  (Engineer, Essence → renamed; Gauntlet → deferred) · collisions remaining in the bible 0.
RESTORE POINT: backups/P0.4_passed_20261016-1321/ — 6 × .rbxm (rule: D-010). Place unchanged since P0.3 (docs-only
  substage): a fresh SerializationService export of each service matched the P0.3 files on length, FNV-1a and two
  extra hashes (Adler-32, reverse FNV-1a), so the verified P0.3 bytes were copied and re-checked locally (all 6 OK).
  Lighting 3445 B 866e3754 · ServerStorage 48583 B e36937fc · Workspace 7831 B 68417a0c · RS/SSS/SPS 577 B each.
MIRROR COMMIT: d4d4a46 "P0.4: content bible v0, D-011 renames (Engineer→Mechanic, Essence→Serum); advance to P0.5" (mirror/src empty: 0 scripts to export)
OWNER APPROVAL: yes, 2026-10-16 ("I do approve, rename approved for both", project chat 13:19 UTC)
NOTES / DEBT:
  - D-011: Engineer → Mechanic, Essence → Serum (schema v1 field renamed before any profile exists; no migration).
    Applied in architecture.md (§6.1, §7.5, §21.1, §25), ART_BIBLE, ROADMAP (A4.4, B1.4), SYSTEM_REGISTRY (renamed, not removed).
  - Burrower added to architecture §8.3/§8.4 and the ART_BIBLE silhouette table.
  - Mode "Gauntlet" (§17, post-L3) shares the reference mode name; rename when designed.
  - Protocol multipliers (×1.0–×3.0) and enemy earliest-protocol values are starting points for A3 tuning.
NEXT: P0.5
```

```text
CHECKPOINT: P0.5 Compliance basics
DATE: 2026-10-16
TESTRUNNER: n/a — TestRunner is an A1 deliverable (D-002); no tests exist yet.
SCRIPT ANALYSIS: 0 scripts in the place (execute_luau scan of LuaSourceContainer in 8 services → scripts=0), nothing to analyse.
PLAY TEST: start_stop_play(start) → execute_luau(Server): printed "[P0.5] play test ok players=1 character=true ArtReference=true"
  → get_console_output → start_stop_play(stop).
  Console errors: 0. Warnings: 5 × "[UIBlox - Warning] FoundationProvider not found" (Roblox CorePackages, same as P0.1–P0.4).
NUMBERS: docs/COMPLIANCE.md = 1915 words · questionnaire sections answered 15/15 (Violence, Blood, Fear, Crude humor,
  Unplayable gambling, Strong language, Romance/private/adult, Alcohol, Social hangout, Free-form creation, Sensitive issues,
  Paid random items, Paid item trading, Media, AI) · expected label Mild (Violence Mild/Repeated, Fear Mild/Repeated, Blood none) ·
  guardrail rows 8 · open owner decisions 2 (D-012: O-1 Robux cosmetic chests, O-2 premium bonus currency) ·
  ART_SOURCES.md: 9 columns, first row ProfileStore (asset 109379033046155, Apache-2.0, GitHub wally.toml 1.0.3).
RESTORE POINT: backups/P0.5_passed_20261016-1330/ — 6 × .rbxm (rule: D-010). Place unchanged since P0.4 (docs-only substage):
  a fresh SerializationService export of each service matched P0.4 on length and FNV-1a, so the P0.4 bytes were copied
  and re-checked locally (all 6 OK). Lighting 3445 B 866e3754 · ServerStorage 48583 B e36937fc · Workspace 7831 B 68417a0c ·
  ReplicatedStorage 577 B 866a0dbe · ServerScriptService 577 B f1d87fa0 · StarterPlayerScripts 577 B 29f33cc4.
MIRROR COMMIT: fa73fd4 "P0.5: compliance basics ...; D-012 proposed; advance to P0.6" (mirror/src empty: 0 scripts to export)
OWNER APPROVAL: Auto-approved under standing owner approval of 2026-10-16 (D-010). D-012 is open and waits for the owner.
NOTES / DEBT:
  - Sources: Creator Hub "Content maturity and compliance" and "Paid random items policy guidelines" (read 2026-10-16).
    en.help.roblox.com returned 403, so the Help Center age-restricted policy, the Community Standards and the Kids and Select
    requirements are still to read, at PT.3 before submitting.
  - ART_SOURCES previously said ProfileStore was "MIT-style"; corrected to Apache-2.0 with obligations (keep header, mark
    modifications, keep a LICENSE copy beside the module). Compare the store asset (updated 2025-03-25) against GitHub
    (last commit 2025-07-31) at the A1 insert.
  - The questionnaire is submitted at PT.3. An unrated experience is restricted for all players.
NEXT: P0.6
```

```text
CHECKPOINT: P0.6 Budget and cadence
DATE: 2026-10-16
TESTRUNNER: n/a — TestRunner is an A1 deliverable (D-002); no tests exist yet.
SCRIPT ANALYSIS: 0 scripts in the place (execute_luau scan of LuaSourceContainer in 8 services → scripts=0), nothing to analyse.
PLAY TEST: start_stop_play(start) → execute_luau(Server): printed "[P0.6] play test ok players=1 character=true ArtReference=true"
  → get_console_output → start_stop_play(stop).
  Console errors: 0. Warnings: 5 × "[UIBlox - Warning] FoundationProvider not found" (Roblox CorePackages, same as P0.1–P0.5).
NUMBERS: stages with an owner-written planned start 14/14 + LO (ROADMAP §1 master tracker) · P0 → L2 start = 39.5 weeks
  (2026-10-16 → 2027-07-19; roadmap range 38–44) · Beta art cap USD 14,300 (Standard; Lean ~4,400 / Premium ~38,800, incl. 15%
  contingency) · art scope: 6 classes, 8 fodder, 6 bosses, 136 animations, 6 zone kits, 1 hub kit, ~60 icons, 11 cards/portraits ·
  weekly rhythm rows 6.
RESTORE POINT: backups/P0.6_passed_20261016-1346/ — 6 × .rbxm (rule: D-010). Place unchanged since P0.5 (docs-only substage):
  a fresh SerializationService export of each service matched P0.5 on length and FNV-1a, so the P0.5 bytes were copied and
  re-checked locally (all 6 OK). Lighting 3445 B 866e3754 · ServerStorage 48583 B e36937fc · Workspace 7831 B 68417a0c ·
  ReplicatedStorage 577 B 866a0dbe · ServerScriptService 577 B f1d87fa0 · StarterPlayerScripts 577 B 29f33cc4.
MIRROR COMMIT: 5dedf15 "P0.6: budget and cadence approved ...; P0 exit; advance to A1.1" (mirror/src empty: 0 scripts to export)
OWNER APPROVAL: yes, 2026-10-16 ("all ok and approved, go ahead", P0.6 thread 13:46 UTC), recorded as D-013.
NOTES / DEBT:
  - Art rates: Lean is anchored on a few Roblox freelancer price lists (DevForum, Fiverr, Carrd; mostly undated); Standard
    and Premium are estimates. Replace with real quotes at B2.
  - A3.5 Public Test runs 2026-12-14 → 2027-01-08 over the year-end holidays (owner kept it; no shift).
  - A1 work may start before its planned 2026-10-19 start under unattended mode; being ahead of plan is not a deviation.
  - D-012 (paid random items) is still open for the owner; must be decided before B1.
NEXT: A1.1
```

---

## A1.1 — Studio layout — 2026-10-16

```text
CHECKPOINT: A1.1 Studio layout
DATE: 2026-10-16
TESTRUNNER: n/a — TestRunner is the A1.2 deliverable; no tests exist yet.
SCRIPT ANALYSIS: 0 diagnostics in the 2 project scripts (both --!strict), via luau-lsp 1.70.1 (D-014):
  `tools/analyze.sh` → "files: 2 / diagnostics: 0". Roblox definitions globalTypes.None.d.luau (luau-lsp main 8e8a4e7,
  2026-10-15, sha256 ad8c25d5…), sourcemap mirror/sourcemap.json built from the Studio tree. Negative control (a scratch file
  with a type error, a bad member and unused locals) reported all 5 issues, so the checker is live.
  Vendor ProfileStore (nonstrict, unmodified, out of scope per ROADMAP §0 step 2): 2 TypeErrors (Signal:Fire on an inferred
  table, lines 2160/2169) + 3 lints (LocalUnused ×2, LocalShadow). Not fixed: changing it breaks "unmodified" (Apache-2.0).
PLAY TEST: start_stop_play(start) → execute_luau(Server): require ProfileStore, wait for DataStoreState → get_console_output
  → start_stop_play(stop). Console:
    [Boot] phase 0 Platform: Platform [no services]
    [Boot] phase 1 Telemetry: Telemetry [no services]
    [Boot] phase 2 Data: Data [no services]
    [Boot] phase 3 Definitions: 18 definition folders, _Registry not yet built
    [Boot] phase 4 Economy: Economy [no services]
    [Boot] phase 5 Progression: Progression [no services]
    [Boot] phase 6 Combat → Encounter: Combat [no services]; Encounter [no services]
    [Boot] phase 7 Social, Facilities, LiveOps: Social [no services]; Facilities [no services]; LiveOps [no services]
    [Boot] phase 8 Network: 0 remotes
    [Boot] phases 0–8 complete in 0.40 ms · services (0): none yet
    [Boot][Client] ready for Lighthouse8282 in 0.01 ms · controllers (0): none yet
    [ProfileStore]: Roblox API services available - data will be saved
    [A1.1] ProfileStore require ok, DataStoreState=Access after 0.64s, players=1
  Console errors: 0. Warnings: 5 × "[UIBlox - Warning] FoundationProvider not found" (Roblox CorePackages, same as P0.1–P0.6).
NUMBERS: server boot 0.40 ms (phases 0–8) · client boot 0.01 ms · layout folders 50 (4 roots + 45 created + Data/Vendor)
  · definition folders 18 · domain folders 10 (each in exactly one phase, asserted) · scripts 3 (2 project + 1 vendor)
  · services 0 · remotes 0 · ProfileStore DataStoreState=Access in 0.64 s · analysis diagnostics 0 (project).
RESTORE POINT: backups/A1.1_passed_20261016-1357/ — 6 × .rbxm (rule: D-010), each verified by length + FNV-1a against Studio.
  Lighting 3445 B 866e3754 · Workspace 7831 B 68417a0c (both unchanged since P0.6, copied) · ReplicatedStorage 872 B 24e5e75c
  · ServerScriptService 36523 B 4b51c889 · ServerStorage 48656 B 56e82a5e · StarterPlayerScripts 1961 B ec786e61.
  The place was not changed after the backup (analysis ran on the mirror).
MIRROR COMMIT: f1b0599 "A1.1: Studio layout (§4.3 folders), Server/Client Bootstrap, ProfileStore inserted and pinned; mirror
  export ..." — mirror/src/server/Bootstrap.server.luau (3860 B 0df2e9a3), mirror/src/client/Bootstrap.client.luau
  (976 B 4186be90), mirror/src/server/Domains/Data/Vendor/ProfileStore.luau (64517 B 1e3a6f3f) + ProfileStore_LICENSE.txt
  (11357 B dc4aedc0); hashes equal the Studio sources. Sourcemap and tools/analyze.sh are in the pass commit.
OWNER APPROVAL: Auto-approved under standing owner approval of 2026-10-16 (D-010). luau-lsp download approved by the owner
  ("ok download luau-lsp and install it", A1.1 thread 14:40 UTC), recorded as D-014.
NOTES / DEBT:
  - ProfileStore: store asset 109379033046155 = GitHub ProfileStore.luau @ 9580f7c (2025-03-25; unchanged at HEAD 45c9847)
    except whitespace-only lines. Used as inserted. insert_asset set Sandboxed = true (capabilities include DataStore,
    Network, ServerCommunication); left on. Re-check at A5 when PlayerDataService uses it.
  - Domain folders and Definitions subfolders exist now because they are part of the §4.3 layout. A1.4 adds the Init/Start
    contract, order assertions and placeholder services; Bootstrap only lists ModuleScripts directly inside domain folders
    (Vendor/ subfolders are not services).
  - Mirror path mapping used here: Shared→src/shared, Server→src/server, Client→src/client, Tests→src/tests (§4.3).
    A1.3 formalises the export procedure and the script-count check.
  - luau-lsp is not Studio's own Script Analysis; it runs the same Luau type checker and linter. If they ever disagree,
    Studio's window wins (the owner can open View → Script Analysis).
NEXT: A1.2
```
