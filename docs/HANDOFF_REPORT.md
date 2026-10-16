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
  (11357 B dc4aedc0); hashes equal the Studio sources. Pass commit 2bd5cfd adds mirror/sourcemap.json and tools/analyze.sh.
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

## A1.2 — TestRunner — 2026-10-16

```text
CHECKPOINT: A1.2 TestRunner
DATE: 2026-10-16
TESTRUNNER: execute_luau (Edit), run on a clone of ServerStorage.Tests so edits are picked up:
    local tests = game:GetService("ServerStorage").Tests:Clone()
    return require(tests.TestRunner).run({ tests.unit, tests.integration }).summary
  →
    file                                     passed failed        ms
    unit.TestRunner.spec                          3      0    131.82
    3 passed, 0 failed (1 file, 131.84 ms)
  Same suite in the play-test Server datamodel (require(ServerStorage.Tests.TestRunner).run()): 3 passed, 0 failed (1 file, 132.98 ms).
  Negative control (3 throwaway specs outside the DataModel, run({ folder })): 1 passed, 7 failed. Reported: matcher fail
  'expected "a" to be "b" (line 4)', runtime error with spec position, timeout 'timed out after 0.20 s', fail after a yield
  (line 10), toThrow on a non-throwing function (line 12), spec returning a non-function, spec erroring at load. Line numbers
  checked against the spec source.
SCRIPT ANALYSIS: `bash tools/analyze.sh` → "files: 4 / diagnostics: 0" (luau-lsp 1.70.1, D-014; sourcemap regenerated from
  the Studio tree). The first local draft reported 2 TypeErrors (pcall on a () -> () function), fixed before insertion, so the
  checker covered the new files. Vendor excluded as before.
PLAY TEST: start_stop_play(start) → execute_luau(Server) runs the suite → get_console_output → start_stop_play(stop). Console:
    [Boot] phases 0–8 complete in 0.37 ms · services (0): none yet   (phase lines 0–8 as in A1.1)
    [Boot][Client] ready for Lighthouse8282 in 0.01 ms · controllers (0): none yet
    [TestRunner] PASS unit.TestRunner.spec › expect › passes matching values, tables and numbers (0.01 ms)
    [TestRunner] PASS unit.TestRunner.spec › expect › raises with a readable message when a matcher fails (0.03 ms)
    [TestRunner] PASS unit.TestRunner.spec › async › awaits a test that yields (132.51 ms)
    [TestRunner] 3 passed, 0 failed (1 file, 132.98 ms)
  Console errors: 0. Warnings: 5 × "[UIBlox - Warning] FoundationProvider not found" (Roblox CorePackages, known since P0.1).
NUMBERS: suite 3 tests / 1 file / 131.84 ms (Edit) and 132.98 ms (Server); sync tests 0.01–0.03 ms each; async test 132.51 ms
  for a 0.1 s task.wait (frame-polled); negative control 7/7 planted failures reported; TestRunner 8894 B (~250 lines incl.
  types); server boot 0.37 ms; scripts 5 (4 project + 1 vendor); analysis diagnostics 0.
RESTORE POINT: backups/A1.2_passed_20261016-1518/ — 6 × .rbxm (D-010), each verified by length + FNV-1a against Studio, all
  exported fresh: Lighting 3445 B 866e3754 · ReplicatedStorage 872 B 24e5e75c (both equal A1.1) · ServerScriptService 36523 B
  314d124c · StarterPlayerScripts 1961 B 1fc169ff (same lengths as A1.1, different hashes: child order changed after Studio
  reopened) · ServerStorage 54253 B 658e5fb2 (TestRunner + spec added) · Workspace 12147 B 5ac584ad (A1.1: 7831 B; children
  unchanged — Terrain, SpawnLocation, Baseplate, Camera — after a Studio update and reopen; not investigated further).
MIRROR COMMIT: 4905af7 "A1.2: TestRunner ..." — mirror/src/tests/TestRunner.luau (8894 B b61ebc85),
  mirror/src/tests/unit/TestRunner.spec.luau (1088 B a07a2957); the 4 existing mirror files re-verified unchanged; sourcemap
  regenerated (adds Tests nodes; Bootstrap entries reordered to the current GetChildren order).
OWNER APPROVAL: Auto-approved under standing owner approval of 2026-10-16 (D-010).
NOTES / DEBT:
  - Spec format: ModuleScript named "*.spec" under Tests/unit or Tests/integration returning function(t: TestRunner.Spec);
    t.describe / t.it(name, body, timeoutSeconds?) / t.expect(v).toBe|toEqual|toBeNil|toBeTruthy|toBeCloseTo|
    toBeGreaterThan|toBeLessThan|toThrow. Default timeout 5 s. run() returns a Report; .summary is the table.
  - Require cache: in Edit mode Studio keeps require() results per ModuleScript across execute_luau calls, so an edited module
    is stale until a clone is required. Modules under test in later substages (A1.4+) hit the same cache: run the suite in a
    play test (fresh requires) or clone the roots under test.
  - error(msg, level) positions are unreliable in Studio (inlining shifts frames); matchers throw at level 0 and the runner
    appends "(line N)" from the spec's traceback frame.
  - A spec that errors at load reports Roblox's generic "Requested module experienced an error while loading"; the original
    error is printed separately in the Output window.
  - Studio closed and reopened twice during this substage (installer update, then a dropped place). Scripts persisted.
NEXT: A1.3
```

## A1.3 — Git mirror — 2026-10-16

```text
CHECKPOINT: A1.3 Git mirror
DATE: 2026-10-16
TESTRUNNER: execute_luau (Edit), on a clone of ServerStorage.Tests:
    local tests = game:GetService("ServerStorage").Tests:Clone()
    return require(tests.TestRunner).run({ tests.unit, tests.integration }).summary
  →
    file                                     passed failed        ms
    unit.TestRunner.spec                          3      0    132.95
    3 passed, 0 failed (1 file, 132.96 ms)
  A1.3 adds no code to the place (the export tools live in the repo), so the suite is unchanged. The procedure was tested by
  the runs and negative controls under NUMBERS.
SCRIPT ANALYSIS: `bash tools/analyze.sh` → "files: 4 / diagnostics: 0" (luau-lsp 1.70.1, D-014; sourcemap regenerated by
  tools/mirror_write.py). luau-lsp on tools/mirror_export.luau (--!strict): 0 diagnostics. tools/mirror_write.py compiles.
PLAY TEST: start_stop_play(start) → execute_luau(Server) runs the suite → get_console_output → start_stop_play(stop). Console:
    [Boot] phases 0–8 complete in 0.35 ms · services (0): none yet   (phase lines 0–8 as in A1.1)
    [Boot][Client] ready for Lighthouse8282 in 0.01 ms · controllers (0): none yet
    [TestRunner] 3 passed, 0 failed (1 file, 132.82 ms)
  Console errors: 0. Warnings: 5 × "[UIBlox - Warning] FoundationProvider not found" (Roblox CorePackages, known since P0.1).
NUMBERS:
  - Passes-when: Studio 5 scripts (DataModel-wide scan 5, under the 4 roots 5) + 1 StringValue; mirror 5 .luau + 1 .txt.
    mirror_write.py: "scripts: DataModel 5 · under roots 5 · mirror 5 · StringValues: studio 1 · mirror 1 · MATCH", ALL OK.
    script_search ("Bootstrap, TestRunner, ProfileStore, spec") lists the same 5 scripts (Client/Bootstrap, Server/Bootstrap,
    Vendor/ProfileStore, Tests/TestRunner, Tests/unit/TestRunner.spec) = 5 mirror .luau files.
  - Normal export: 1 execute_luau call, 66.5 KB result (padded), 4 sources sent, vendor hash-checked in place; all 6 files OK.
  - Full rebuild: mirror/src/{client,server,tests} deleted, exported with INCLUDE_VENDOR = true → 2 chunks (91,850 chars,
    next = 5; then 66.1 KB) → 6 files written, all OK, git shows no source change. One chunk alone → refused (INCOMPLETE).
  - Negative controls, local: stale file → DEL; hand-edited vendor file → BAD (64530 B fa261018 vs studio 64517 B 1e3a6f3f);
    hand-edited non-vendor file → overwritten from Studio; injected export error → "nothing written"; chunks with different
    manifests → MISMATCH. Studio: 6 temporary instances (Script in ServerStorage root, Dup + dup, module nested in a module,
    "bad:name") → 4/4 error kinds reported (DataModel 11, under roots 10); all destroyed afterwards, count back to 5.
  - Sizes: tools/mirror_export.luau 6077 B, LIMIT 95,000 chars per call, PAD_TO 66,000.
RESTORE POINT: backups/A1.3_passed_20261016-1527/ — 6 × .rbxm (D-010), children of each service minus Terrain/Camera, each
  verified by length + FNV-1a against a fresh Studio serialization: Lighting 3445 B 866e3754 · ReplicatedStorage 872 B 24e5e75c ·
  ServerScriptService 36523 B 314d124c · ServerStorage 54253 B 658e5fb2 · StarterPlayerScripts 1961 B 1fc169ff (these 5 equal
  A1.2, bytes copied) · Workspace 7831 B eaa94454 (exported fresh; children SpawnLocation, Baseplate; A1.2 had 12147 B and
  A1.1 7831 B 68417a0c: same length as A1.1, different hash; not investigated).
MIRROR COMMIT: 09202d7 "A1.3: Git mirror export procedure ..." — tools/mirror_export.luau, tools/mirror_write.py, docs/MIRROR.md, mirror/sourcemap.json
  (now sorted by name; equivalent to A1.2's ignoring child order). No mirror source changed (Studio code unchanged since A1.2).
OWNER APPROVAL: Auto-approved under standing owner approval of 2026-10-16 (D-010). Method recorded as D-015.
NOTES / DEBT:
  - script_search caps at 10 results and matches names fuzzily; once the place has more than 10 scripts the export's
    DataModel-wide count is the reference (docs/MIRROR.md step 3).
  - Nested scripts (a module with child modules) are refused by the export for now; if a later substage needs them, extend the
    mapping (e.g. Name/init.luau) in the same change and document it in docs/MIRROR.md.
  - The harness inlines execute_luau results under ~64K and truncates over ~100K; the export pads to 66K and chunks at 95K.
  - Temporary negative-control instances were made and destroyed in the live Team Create place; nothing else was changed.
NEXT: A1.4
```

## A1.4 — Domains and lifecycle — 2026-10-16

```text
CHECKPOINT: A1.4 Domains and lifecycle
DATE: 2026-10-16 (started 15:33 UTC, passed 15:44 UTC)
DELIVERED:
  - ServerScriptService/Server/Lifecycle (ModuleScript, --!strict): §5.2 phase table, Lifecycle.plan / validate / run / boot,
    Lifecycle.get (dependency resolution during Init only). Contract details in D-016.
  - One placeholder service per domain (Init/Start no-ops): Platform/RemoteConfigService, Telemetry/ErrorReportService,
    Data/MigrationService, Economy/TransactionService, Progression/ClassService, Combat/CombatService,
    Encounter/MissionSessionService, Social/PartyService, Facilities/ShopService, LiveOps/SeasonService.
  - Server/Bootstrap now checks the layout and boots through Lifecycle.boot; phase 3 and phase 8 lines come from hooks.
  - ServerStorage/Tests/unit/Lifecycle.spec: 14 tests.
TESTRUNNER: 17 passed / 0 failed. Edit mode, on a clone of ServerStorage.Tests:
    local tests = game:GetService("ServerStorage").Tests:Clone()
    return require(tests.TestRunner).run({ tests.unit, tests.integration }).summary
  →
    file                                     passed failed        ms
    unit.Lifecycle.spec                          14      0      3.56
    unit.TestRunner.spec                          3      0    128.15
    17 passed, 0 failed (2 files, 131.73 ms)
  Passes-when test: "real domains › asserts when two services' phases are swapped" plans the real domain folders, swaps
  Platform/RemoteConfigService (phase 0) with Economy/TransactionService (phase 4) and expects
  "[Boot] order: Economy/TransactionService belongs to phase 4 (Economy) but is listed in phase 0". Also covered: Combat ⇄
  Encounter swapped inside phase 6, two phases swapped, a dependency swapped behind its user (Lifecycle.get order error,
  no Start ran), Init failure stops the boot before any Start, Init yield rejected, Start failure named, get outside Init,
  unknown dependency, missing Start, duplicate name, built-in name ("AnalyticsService"), unknown domain.
SCRIPT ANALYSIS: `bash tools/analyze.sh` → "files: 16 / diagnostics: 0" (luau-lsp 1.70.1, D-014). One TypeError found on the
  local draft (pcall over a method) was fixed before the code went into Studio.
PLAY TEST: start_stop_play(start) → execute_luau(Server) runs the suite → get_console_output → start_stop_play(stop). Console:
    [Boot] phase 0 Platform: Platform [RemoteConfigService]
    [Boot] phase 1 Telemetry: Telemetry [ErrorReportService]
    [Boot] phase 2 Data: Data [MigrationService]
    [Boot] phase 3 Definitions: 18 definition folders, _Registry not yet built
    [Boot] phase 4 Economy: Economy [TransactionService]
    [Boot] phase 5 Progression: Progression [ClassService]
    [Boot] phase 6 Combat → Encounter: Combat [CombatService]; Encounter [MissionSessionService]
    [Boot] phase 7 Social, Facilities, LiveOps: Social [PartyService]; Facilities [ShopService]; LiveOps [SeasonService]
    [Boot] phase 8 Network: 0 remotes
    [Boot] phases 0–8 complete in 0.13 ms (Init 0.10 ms, Start 0.00 ms) · services (10): Platform/RemoteConfigService →
      Telemetry/ErrorReportService → Data/MigrationService → Economy/TransactionService → Progression/ClassService →
      Combat/CombatService → Encounter/MissionSessionService → Social/PartyService → Facilities/ShopService → LiveOps/SeasonService
    [Boot][Client] ready for Lighthouse8282 in 0.02 ms · controllers (0): none yet
    [TestRunner] 17 passed, 0 failed (2 files, 132.29 ms)
  Console errors: 0. Warnings: 5 × "[UIBlox - Warning] FoundationProvider not found" (Roblox CorePackages, known since P0.1).
NUMBERS:
  - Boot (play test): 0.13 ms total, Init pass 0.10 ms (includes plan validation), Start pass 0.00 ms, 10 services, 0 remotes.
  - Lifecycle.spec: 14 tests in 3.56 ms (Edit) / 3.65 ms (play test). Full suite 131.73 ms / 132.29 ms.
  - Mutation control (Edit, on clones of Lifecycle): with the phase-membership check disabled the swap still throws (domain-rank
    check: "Telemetry/ErrorReportService boots after Economy"); with both checks disabled the swapped plan boots with Economy
    first. The swap test depends on the assertion.
  - Service names: 49 names in architecture §5.1 checked with game:FindService; 3 are Roblox built-ins (D-017).
  - Scripts: DataModel 17 · under roots 17 · mirror 17 · StringValues 1/1 · MATCH (mirror_write.py, ALL OK). script_search caps
    at 10, so the DataModel-wide count is the reference (docs/MIRROR.md step 3). Local drafts == Studio export (diff -r clean).
  - Sizes: Lifecycle 11,381 B, Lifecycle.spec 8,334 B, Bootstrap 1,869 B, placeholders 369–434 B.
RESTORE POINT: backups/A1.4_passed_20261016-1542/ — 6 × .rbxm (D-010), each verified by length + FNV-1a against a fresh Studio
  serialization: ServerScriptService 41821 B f7c13864 · ServerStorage 57616 B 2b661855 (exported, base64 via EncodingService) ·
  Lighting 3445 B 866e3754 · ReplicatedStorage 872 B 24e5e75c · StarterPlayerScripts 1961 B 1fc169ff · Workspace 7831 B eaa94454
  (these 4 equal A1.3, bytes copied).
MIRROR COMMIT: c708c1e "A1.4: domain lifecycle ..." — mirror/src (Lifecycle, 10 placeholders, Bootstrap, Lifecycle.spec), mirror/sourcemap.json, docs.
OWNER APPROVAL: Auto-approved under standing owner approval of 2026-10-16 (D-010). Contract details D-016.
NOTES / DEBT:
  - D-017 (proposed, owner): AnalyticsService, PlayerDataService and MatchmakingService in §5.1 are Roblox built-in names; the
    boot rejects them. A1.8 needs the rename answer before AnalyticsService is built.
  - Init must not yield (asserted). Services that wait on DataStore/MemoryStore do it in Start.
  - Services in one domain boot in name order. If a domain needs another intra-domain order, add it with that domain's API module.
  - Lifecycle lives in ServerScriptService, outside Tests: in Edit mode its require is cached across execute_luau calls, so after
    editing it run the suite in a play test or require a clone (as the mutation control did).
  - The placeholder TransactionService has no Run yet (B1.1); nothing calls it.
NEXT: A1.5
```

## A1.5 — Event bus — 2026-10-16

```text
CHECKPOINT: A1.5 Event bus
DATE: 2026-10-16 (started 15:50 UTC, passed 16:02 UTC)
DELIVERED:
  - ReplicatedStorage/Shared/Events/Catalog (ModuleScript, --!strict): all 37 EVENTS.md events with publisher identity, "since"
    substage and field schema; one exported payload type per event (Catalog.EnemyKilled, ...); EventName / PublisherId unions;
    Catalog.check (malformed catalog fails at require time, so it fails the boot).
  - ReplicatedStorage/Shared/Events/EventBus (ModuleScript, --!strict): EventBus.server() (shared, strict in Studio),
    EventBus.new(options), bus:publisher(domain):publish(name, payload), bus:subscribe(name, handler) → Connection:Disconnect(),
    subscriberCount, setErrorHandler. Contract in API_CONTRACTS.md, details in D-018.
  - Server/Bootstrap publishes BootCompleted { Phases = 9, Services = boot order } after phase 8.
  - ServerStorage/Tests/unit/EventBus.spec: 24 tests.
  - docs/EVENTS.md: typed payload column generated from Catalog (37 rows; names, publishers, since and fields match the code),
    payload and misuse rules, Reward shape. BootCompleted "since" A1.4 → A1.5 (it was listed but never published before now).
TESTRUNNER: 41 passed / 0 failed. Edit mode, on a clone of ServerStorage.Tests:
    local tests = game:GetService("ServerStorage").Tests:Clone()
    return require(tests.TestRunner).run({ tests.unit, tests.integration }).summary
  →
    file                                     passed failed        ms
    unit.EventBus.spec                           24      0    182.43
    unit.Lifecycle.spec                          14      0      2.96
    unit.TestRunner.spec                          3      0    130.38
    41 passed, 0 failed (3 files, 315.80 ms)
  Passes-when tests: "subscribe → publish → receive › delivers the payload to a subscriber" (plus order, per-event routing,
  Disconnect, disconnect during a publish, deep-frozen copy, all 37 events published from their own publisher);
  "wrong-type payload › is rejected in strict mode and never delivered" (string for integer, 7.5 for integer, number for
  Vector3, missing field, empty string, NaN, extra field, Instance, non-table) plus nested array/enum/map/record/oneOf cases and
  the non-strict report-and-drop case. Misuse: "publish from the wrong domain › asserts in strict mode" and the same for all
  37 events × 11 other identities (407 checks); non-strict reports "domain" and drops; unknown publisher identity throws.
SCRIPT ANALYSIS: `bash tools/analyze.sh` → "files: 19 / diagnostics: 0" (luau-lsp 1.70.1, D-014). The local drafts were checked
  first with a temporary sourcemap: 28 diagnostics (casts of frozen literals to FieldType, pcall over a no-return function,
  test-only literal types), all fixed before the code went into Studio.
PLAY TEST: start_stop_play(start) → execute_luau(Server) suite + shared-bus probe → get_console_output → start_stop_play(stop):
    [Boot] phases 0–8 complete in 0.11 ms (Init 0.09 ms, Start 0.00 ms) · services (10): Platform/RemoteConfigService → ...
    [Boot] BootCompleted published · 0 subscribers · bus strict
    [Boot][Client] ready for Lighthouse8282 in 0.01 ms · controllers (0): none yet
    [TestRunner] 41 passed, 0 failed (3 files, 314.87 ms)
  Probe: EventBus.server() strict = true, same instance on a second call; Encounter publishing BootCompleted threw
  "[Events] BootCompleted is published by Bootstrap only; Encounter tried to publish it" and nothing was delivered.
  Console errors: 0. Warnings: 5 × "[UIBlox - Warning] FoundationProvider not found" (Roblox CorePackages, known since P0.1) and
  1 × "[Events] error handler failed (... reporter down) ..." written on purpose by the "survives a failing error handler" test.
NUMBERS:
  - Publish cost (Edit, best of 3 × 10,000): EnemyKilled 0 subscribers 1.44 µs · 1 subscriber 2.78 µs · 4 subscribers 6.48 µs;
    MissionEnded (array field) 4 subscribers 7.30 µs.
  - EventBus.spec 24 tests in 182.43 ms (Edit) / 182.73 ms (play test); 175 ms of that is the yielding-handler test's waits.
  - Mutation controls (EventBus copy, spec pointed at it): domain check off → 3 failed (the 3 wrong-domain tests); payload check
    off → 3 failed (the 3 wrong-type tests); handlers called inline instead of task.spawn → 3 failed (the 3 isolation tests).
  - Boot (play test): 0.11 ms, 10 services, 0 remotes. BootCompleted subscribers: 0 (Telemetry is still a placeholder).
  - Scripts: DataModel 20 · under roots 20 · mirror 20 · StringValues 1/1 · MATCH (mirror_write.py, ALL OK, one export call of
    94,519 characters, just under the 95K chunk limit; the next export will take two calls). Local drafts == Studio export.
  - Sizes: Catalog 15,948 B, EventBus 10,265 B, EventBus.spec 16,290 B, Bootstrap 2,397 B.
RESTORE POINT: backups/A1.5_passed_20261016-1559/ — 6 × .rbxm (D-010), each verified by length + FNV-1a against a fresh Studio
  serialization: ReplicatedStorage 12640 B 9b94ec0b · ServerScriptService 42144 B e20dbab0 · ServerStorage 63880 B fa603de8 ·
  Workspace 12147 B 5ac584ad (exported) · Lighting 3445 B 866e3754 · StarterPlayerScripts 1961 B 1fc169ff (equal A1.4, copied).
  Workspace serializes to 12147 B again (7831 B at A1.3/A1.4, 12147 B at A1.2) with no Workspace edits; same behaviour seen in A1.2.
MIRROR COMMIT: 3a20f73 "A1.5: typed event bus ..." — mirror/src (Events/Catalog, Events/EventBus, EventBus.spec, Bootstrap), mirror/sourcemap.json, docs.
OWNER APPROVAL: Auto-approved under standing owner approval of 2026-10-16 (D-010). Details D-018.
NOTES / DEBT:
  - multi_edit treats dots in a path as separators: creating "Tests.unit.EventBus.spec" made Folder EventBus + Module "spec".
    Fixed by renaming/moving in execute_luau. Create dotted names that way (or rename after) from now on.
  - Event payload shapes after A1.5 are provisional (EVENTS.md rule); each "since" substage confirms them.
  - The publisher identity is declared by the caller (D-018); it catches mistakes, not hostile code.
  - EventBus is in ReplicatedStorage but server-only (EventBus.server errors on a client); clients get server events through
    remotes from A1.8 on, never through the bus.
  - Shared/Events modules hit the Edit-mode require cache like Lifecycle: after editing them, run the suite in a play test or point
    a spec clone at a module clone (as the mutation controls did).
NEXT: A1.6
```

## A1.6 — Definitions registry — 2026-10-16

```text
CHECKPOINT: A1.6 Definitions registry
DATE: 2026-10-16 (started 16:12 UTC, passed 16:30 UTC)
DELIVERED:
  - ReplicatedStorage/Shared/Definitions/_Registry (ModuleScript, --!strict): one schema per §4.3 folder (18), field types with
    bounds, references between folders, folder rules; Registry.collect(folder) / validate(entries) / load(folder) / shared();
    get(kind, id) and all(kind) return frozen deep copies. All problems are collected into one "[Definitions] ..." error.
    Contract in API_CONTRACTS.md, details in D-019.
  - 19 sample definitions, one per folder (Enemies has two): Classes/Sharpshooter, Weapons/TacticalRifle, Passives/VoltageCore,
    Evolutions/StormRifle, Enemies/Walker + MutantAlpha, Protocol/Contact, Missions/EvacStreets_01 (the §9.2 example cut to the
    sample enemies), Zones/EvacuationStreets, Loot/Zone1_Normal, Items/SampleHelmet, Skills/SampleSkill, Pets/MedicalDrone,
    Eggs/SampleEgg, Forge/SampleRecipe, Quests/SampleDailyQuest, Raids/SampleRaid, Seasons/SampleSeason, Shop/SampleCosmetic.
    Names from CONTENT_BIBLE (Sample* where it has none); every number is a placeholder.
  - Server/Bootstrap: phase 3 runs _Registry.shared() (a bad definition stops the boot); after the Start pass it publishes
    DefinitionsValidated { Count } and then BootCompleted.
  - ServerStorage/Tests/unit/Registry.spec: 26 tests, run on a clone of Shared.
TESTRUNNER: 67 passed / 0 failed. Edit mode, on a clone of ServerStorage.Tests:
    local tests = game:GetService("ServerStorage").Tests:Clone()
    return require(tests.TestRunner).run({ tests.unit, tests.integration }).summary
  →
    file                                     passed failed        ms
    unit.EventBus.spec                           24      0    182.92
    unit.Lifecycle.spec                          14      0      2.25
    unit.Registry.spec                           26      0     26.71
    unit.TestRunner.spec                          3      0    119.53
    67 passed, 0 failed (4 files, 331.44 ms)
  Passes-when tests: "folder layout › fails on a duplicated module", "fields › names a missing field with its path and type",
  "Ids and references › rejects the same Id in two folders", "shipped definitions › load clean with at least one sample per
  folder". Also: missing folder, stray instances, wrong types, NaN, non-integers, ranges, unknown fields, enums, arrays, maps,
  asset ids, Id = module name, non-table modules, unresolved references, every problem in one error, and the folder rules.
SCRIPT ANALYSIS: `bash tools/analyze.sh` → "files: 40 / diagnostics: 0" (luau-lsp 1.70.1, D-014). The drafts were checked first
  with a temporary sourcemap (12 diagnostics fixed before Studio). A planted type error in Registry.spec was reported, so the
  typeof(require(...)) type alias is really type-checked.
PLAY TEST ×2:
  1 (broken: Walker without Attack.TelegraphTime, SampleHelmet duplicated) → server console:
    [Definitions] 2 problems in Shared/Definitions; the boot stops until they are fixed:
      - Enemies/Walker: missing field Attack.TelegraphTime (number ≥ 0)
      - Items/SampleHelmet: duplicate Id "SampleHelmet": two modules named SampleHelmet in Items
    Stack: Lifecycle.run → Lifecycle.boot → Bootstrap line 43. No phase lines printed, no Start ran, nothing published.
  Fix: Walker restored and the clone destroyed (both hashes equal the originals again).
  2 (fixed) →
    [Boot] phase 3 Definitions: 19 definitions in 18 folders validated in 0.94 ms
    [Boot] phases 0–8 complete in 1.05 ms (Init 1.02 ms, Start 0.00 ms) · services (10): Platform/RemoteConfigService → ...
    [Boot] DefinitionsValidated (19) and BootCompleted published · 0 and 0 subscribers · bus strict
    [TestRunner] 67 passed, 0 failed (4 files, 348.41 ms)
  Console errors: 0. Warnings: 5 × "[UIBlox - Warning] FoundationProvider not found" (Roblox CorePackages, known since P0.1) and
  1 × "[Events] error handler failed (... reporter down) ..." written on purpose by an EventBus.spec test.
NUMBERS:
  - Registry validation at boot: 0.94 ms for 19 definitions in 18 folders (first require of every module included).
    Registry.load on the real folder, warm: 0.193 ms average over 20 runs (play test).
  - Boot total 1.05 ms (A1.5: 0.11 ms); the difference is phase 3.
  - Registry.spec 26 tests in 26.71 ms (Edit) / 30.80 ms (play test).
  - Mutation controls (patched _Registry in a temporary Shared clone, removed afterwards): duplicate check off → 1 failed (the
    duplicate test); unknown-field check off → 1 failed (typo test); reference check off → 1 failed (missing reference test);
    per-definition rules off → 5 failed (the 5 rule tests that use them).
  - Scripts: DataModel 41 · under roots 41 · mirror 41 · StringValues 1/1 · MATCH (mirror_write.py ALL OK, two export calls of
    92,236 + 76,566 characters). The 22 new or changed files equal the local drafts.
  - Sizes: _Registry 31,969 B, Registry.spec 13,601 B, Bootstrap 3,020 B, samples 156–601 B.
RESTORE POINT: backups/A1.6_passed_20261016-1627/ — 6 × .rbxm (D-010), each verified by length + FNV-1a against a fresh Studio
  serialization: ReplicatedStorage 29930 B 2c9357c9 · ServerScriptService 42408 B 0287e81a · ServerStorage 69313 B 33be9d88
  (exported; ServerStorage base64 in two calls) · Lighting 3445 B 866e3754 · StarterPlayerScripts 1961 B 1fc169ff ·
  Workspace 12147 B 5ac584ad (equal A1.5, copied).
MIRROR COMMIT: 0b7f4e3 "A1.6: definitions registry ..." — mirror/src (Definitions/_Registry + 19 samples, Registry.spec, Bootstrap),
  mirror/sourcemap.json, docs.
OWNER APPROVAL: Auto-approved under standing owner approval of 2026-10-16 (D-010). Details D-019.
NOTES / DEBT:
  - 14 of the 18 schemas are provisional (D-019 lists the settling substage for each). Changing one is a registry edit plus a
    decision entry, in the substage that builds that content.
  - The stat, damage-tag, rarity, archetype, targeting and currency lists are copies until A1.7 adds Shared/Stats; A1.7 should
    point _Registry at it so the lists exist once.
  - First run caught a real bug: enum(RARITY) froze the shared list twice (table.freeze on a frozen table errors). Fixed.
  - A spec that requires a real Shared module at runtime keeps the Edit-mode require cache, and a load error stays cached.
    Registry.spec takes the module type with typeof(require(...)) in a type alias (never executed) and runs on Shared:Clone().
  - Sample numbers and ability ids (TacticalRifleShot, CombatRoll, Leap, GroundSlam) are placeholders for A2–A4.
  - D-012 is still open for the owner; the shop schema has no random-item kind, so nothing here decides it.
NEXT: A1.7
```

## A1.7 — Types and StatPipeline — 2026-10-16

```text
CHECKPOINT: A1.7 Types and StatPipeline
DATE: 2026-10-16 (started 16:35 UTC, passed 16:56 UTC)
DELIVERED:
  - ReplicatedStorage/Shared/Types (ModuleScripts, --!strict, no `any`): Common (Rarity, Archetype, Targeting, DamageTag,
    Currency, Slot + their lists, the only copies), Profile (§6.1 PlayerProfile field for field, §11 ItemInstance, provisional
    Affix/Loadout/PetInstance/StageRecord/QuestState/RaidRecord/PlayerSettings, each tagged with its settling substage),
    Run (§6.2 RunPlayerState, ComputedStats: StatBlock), Match (§6.3 MatchState).
  - ReplicatedStorage/Shared/Stats: StatRegistry (the 25 STATS.md rows: unit, base source, layers, Form, Min, Max, whole-number
    flag; StatId, Layer and StatBlock types), StatPipeline (compute / stat / preview / check / get), DamageCalculator (damage,
    resistance, armorReduction, mitigate). Contracts in API_CONTRACTS.md, details in D-020.
  - Shared/Definitions/_Registry: vocabularies now come from Types/Common and Stats/StatRegistry (same tables, not copies);
    new folder rule: a passive, skill node or pet must use a layer its stat takes.
  - docs/STATS.md: Form column, Armor Max 300 (= 75% reduction), §10.2 passive table (stat, layer, cap), code pointers.
    tools/check_stats.py: STATS.md vs StatRegistry row for row → "rows: STATS.md 25 · StatRegistry 25 · MATCH".
  - ServerStorage/Tests/unit: StatPipeline.spec (106), DamageCalculator.spec (18), Types.spec (4); Registry.spec +1 (27).
TESTRUNNER: 196 passed / 0 failed. Edit mode, on a clone of ServerStorage.Tests:
    local tests = game:GetService("ServerStorage").Tests:Clone()
    return require(tests.TestRunner).run({ tests.unit, tests.integration }).summary
  →
    file                                     passed failed        ms
    unit.DamageCalculator.spec                   18      0      3.16
    unit.EventBus.spec                           24      0    179.58
    unit.Lifecycle.spec                          14      0      2.31
    unit.Registry.spec                           27      0     27.86
    unit.StatPipeline.spec                      106      0     10.08
    unit.TestRunner.spec                          3      0    126.57
    unit.Types.spec                               4      0      6.80
    196 passed, 0 failed (7 files, 356.43 ms)
  Passes-when coverage: each layer alone ("each stat, each layer alone", every allowed layer of all 25 rows, through compute and
  stat); all layers combined (MaxHealth 351, DamagePct 2.6, additive applied once, order-independent); every cap ("caps", Min
  and Max of all 25 rows + the §7.3 examples); zero/negative inputs (bases, multipliers, AdditivePct below -100%, zero
  modifiers, overflow never NaN; damage, difficulty, armor, incoming damage); 100% of STATS.md rows ("STATS.md coverage": an
  expected-value row per stat, failing when one is missing or extra, and every allowed layer tested). Also: input checks,
  preview = compute parity, each damage tag against a resistance table, armor 75% cap.
SCRIPT ANALYSIS: `bash tools/analyze.sh` → "files: 50 / diagnostics: 0" (luau-lsp 1.70.1, D-014). Drafts were checked first with
  a temporary sourcemap (array invariance and literal-inference errors fixed before Studio). `grep any` over Shared/Types and
  Shared/Stats: no `any` (one hit is the word "anywhere" in a comment).
PLAY TEST:
    [Boot] phase 3 Definitions: 19 definitions in 18 folders validated in 1.01 ms
    [Boot] phases 0–8 complete in 1.15 ms (Init 1.10 ms, Start 0.00 ms) · services (10): Platform/RemoteConfigService → ...
    [Boot] DefinitionsValidated (19) and BootCompleted published · 0 and 0 subscribers · bus strict
    [TestRunner] 196 passed, 0 failed (7 files, 356.62 ms)
  Sample through the real registry: Sharpshooter → MaxHealth 100, MoveSpeed 16, DamagePct 0; TacticalRifle L1 vs Walker = 10.
  Client datamodel requires StatPipeline and DamageCalculator (DamagePct 0.5 → crit Fire hit 22.5).
  Console errors: 0 (Server LogService: 0 errors, 1 warning; Client: 0 errors, 5 warnings). Warnings: 5 × "[UIBlox - Warning]
  FoundationProvider not found" (Roblox CorePackages, known since P0.1) and 1 × "[Events] error handler failed (... reporter
  down) ..." written on purpose by an EventBus.spec test.
NUMBERS:
  - StatPipeline.compute: 4.20 µs with 0 modifiers, 7.01 µs with 20; preview (20 modifiers) 16.80 µs; DamageCalculator.damage
    0.37 µs (Server play test, best of 3 × 10,000).
  - Boot 1.15 ms (A1.6: 1.05 ms); phase 3 1.01 ms (A1.6: 0.94 ms, now also loads Types/Common and Stats/StatRegistry).
  - Mutation controls (patched Stats modules in a temporary Shared clone, removed afterwards; StatPipeline + DamageCalculator
    specs): AdditivePct compounded → 3 failed · Bonus form off → 28 · clamp removed → 32 · NaN guard off → 1 · layer check off
    → 1 · armor 75% cap off → 1 · crit always on → 8 · resistance ignored → 5 · Armor Max 300→299 → 3.
  - check_stats.py control: CritMult Max changed to 5.0 in STATS.md → "row 9 CritMult: Max ... DIFFER" (exit 1); restored → MATCH.
  - Scripts: DataModel 51 · under roots 51 · mirror 51 · StringValues 1/1 · MATCH (mirror_write.py ALL OK, three export calls of
    94,129 + 94,434 + 65,972 characters). The export equals the local drafts (diff -r clean).
  - Sizes: StatPipeline 7,611 B, StatRegistry 5,233 B, DamageCalculator 3,205 B, Profile 3,749 B, Common 2,455 B,
    _Registry 32,172 B, StatPipeline.spec 18,185 B.
RESTORE POINT: backups/A1.7_passed_20261016-1652/ — 6 × .rbxm (D-010), each verified by length + FNV-1a against a fresh Studio
  serialization: ReplicatedStorage 40913 B 7c82d76a · ServerStorage 79784 B 4c487073 (exported; ServerStorage base64 in three
  calls) · Lighting 3445 B 866e3754 · ServerScriptService 42408 B 0287e81a · StarterPlayerScripts 1961 B 1fc169ff ·
  Workspace 12147 B 5ac584ad (equal A1.6, copied).
MIRROR COMMIT: 1c2f410 "A1.7: §6 types ... and stat pipeline ..." — mirror/src (Types, Stats, _Registry, 4 specs), mirror/sourcemap.json, docs, tools/check_stats.py.
OWNER APPROVAL: Auto-approved under standing owner approval of 2026-10-16 (D-010). Details D-020.
NOTES / DEBT:
  - D-020 readings for the owner to overrule if wanted: Bonus form for percent stats, class DamageMult as a DamagePct
    Multiplier (entering once), Armor Max 300, provisional §6.1 sub-types. PlayerProfile's §6.1 fields are unchanged.
  - Class definitions have no CritChance, DodgeDistance or DodgeIFrames field, although STATS.md sources them from the class;
    StatPipeline requires the caller to pass them. A4.1 (classes) settles where they come from.
  - ProjectileCount and Pierce are weapon-sourced; a player-level block needs the weapon's base. A2.7 (weapons framework)
    decides whether weapons get their own block.
  - Luau arrays are invariant: vocabularies are built through typed varargs and handed out as frozen { string }.
  - D-012 is still open for the owner; nothing here touches monetization.
NEXT: A1.8
```

## A1.8 — Clock, network, platform wrappers — 2026-10-16

```text
CHECKPOINT: A1.8 Clock, network, platform wrappers
DATE: 2026-10-16 (started 17:05 UTC, passed 17:40 UTC)
DELIVERED:
  - ReplicatedStorage/Shared/Net: Contracts (registry; first entry FlagsUpdate R S2C since A1.8; malformed entries fail at
    require), Guard (13 guard builders, never throw), TokenBucket (per-player per-remote bucket), Codec (struct/list buffer
    packing, 11 field types; decode never throws).
  - ServerScriptService/Server/Gateway: the only remote creator; expose() only while Lifecycle.currentPhase() == 8; inbound
    identity → bucket → guard → handler; S2C remotes have an empty inbound bucket; session flag on 3 bursts in 60 s; outgoing
    payloads checked. Lifecycle.currentPhase() added. Bootstrap phase 8 exposes the gateway and logs the remote counts, then
    prints the live config.
  - Domains: Platform/FeatureFlagService (new), Platform/RemoteConfigService (was a placeholder; Config DataStore key Current,
    boot read + 300 s poll), Telemetry/MetricsService (new; AnalyticsService wrapper + counters), Telemetry/ErrorReportService
    (was a placeholder; structured reports, reporter for Platform, Gateway and the bus), Encounter/SimulationClock (new).
  - Shared/Config: Schema, Flags (SampleFlag, Client), Tunables (SampleTunable). Client/Controllers/FlagsController; client
    Bootstrap starts controllers.
  - Tests/unit: Codec.spec (21), Guard.spec (11), TokenBucket.spec (7), Contracts.spec (7), Gateway.spec (22),
    SimulationClock.spec (11), Platform.spec (14), Telemetry.spec (8); Lifecycle.spec list updated (14).
  - Docs: API_CONTRACTS (rules, FlagsUpdate row, network/clock/wrapper tables), EVENTS (consumers), SYSTEM_REGISTRY (4 rows
    updated, ErrorReportService row added), D-021, D-022, D-020 owner response. tools/check_contracts.py.
TESTRUNNER: 297 passed / 0 failed. Edit mode, on a clone of ServerStorage.Tests:
    local tests = game:GetService("ServerStorage").Tests:Clone()
    return require(tests.TestRunner).run({ tests.unit, tests.integration }).summary
  →
    file                                     passed failed        ms
    unit.Codec.spec                              21      0    234.91
    unit.Contracts.spec                           7      0      2.23
    unit.DamageCalculator.spec                   18      0      3.44
    unit.EventBus.spec                           24      0    174.55
    unit.Gateway.spec                            22      0      6.70
    unit.Guard.spec                              11      0      2.43
    unit.Lifecycle.spec                          14      0      2.68
    unit.Platform.spec                           14      0      4.19
    unit.Registry.spec                           27      0     30.67
    unit.SimulationClock.spec                    11      0     69.53
    unit.StatPipeline.spec                      106      0      8.29
    unit.Telemetry.spec                           8      0      3.80
    unit.TestRunner.spec                          3      0    120.29
    unit.TokenBucket.spec                         7      0      2.11
    unit.Types.spec                               4      0      6.60
    297 passed, 0 failed (15 files, 672.55 ms)
  Play test (Server): 297 passed, 0 failed (15 files, 640.78 ms).
  The first Edit run was 293/4; all four were test bugs (Tick(0.5) hit the 0.25 s MaxStep cap in two tests; Contracts gave a
  Direction "Both" contract a second problem, now only S2C gets the "no Rate" message; Gateway.server() refuses in Edit, where
  RunService:IsServer() is false).
  Passes-when coverage: paused clock does not advance ("a paused clock does not advance": 600 ticks while paused add 0);
  bucket rejects the N+1th request ("accepts N requests at once and rejects the N+1th" for all 7 API_CONTRACTS burst sizes,
  and Gateway "the bucket rejects the N+1th request of a burst"); codec round-trips all field types (all 11 types at their
  edges, one struct with every type, lists of 0/1/90 records and of string records); a remote does not exist before phase 8
  (Gateway "a remote does not exist before phase 8 of a real boot": fake services in phases 0/4/7 see 0 remotes and no Net
  folder in Init and Start, the network step sees 0, after it all 4 test remotes exist; expose refuses in phases 0–7 and from
  inside an Init). Verified in the place with search_game_tree: Edit has no ReplicatedStorage.Net and no project remotes; the
  play session (Server and Client) has ReplicatedStorage.Net.FlagsUpdate (RemoteEvent) and nothing else.
  Mutation controls (real module source patched, the one spec run on a Tests clone, source restored and hash-checked in the same
  call): bucket accepts at 0 tokens → TokenBucket 6 failed · pause ignored → SimulationClock 4 · trailing bytes accepted → Codec
  1 · bool byte unchecked → Codec 1 · phase-8 check off → Gateway 2 · rate checked after payload → Gateway 2 · record allows
  extra fields → Guard 1 · bad flag override accepted → Platform 1.
SCRIPT ANALYSIS: `bash tools/analyze.sh` → "files: 70 / diagnostics: 0" (luau-lsp 1.70.1, D-014). Drafts checked first with a
  temporary sourcemap (70 files, 0 diagnostics).
PLAY TEST:
    [Boot] phase 0 Platform: Platform [FeatureFlagService, RemoteConfigService]
    [Boot] phase 1 Telemetry: Telemetry [ErrorReportService, MetricsService]
    [Boot] phase 3 Definitions: 19 definitions in 18 folders validated in 1.04 ms
    [Boot] phase 6 Combat → Encounter: Combat [CombatService]; Encounter [MissionSessionService, SimulationClock]
    [Boot] phase 8 Network: 0 remotes before, 1 created in ReplicatedStorage.Net in 0.22 ms, 1 now
    [Boot] phases 0–8 complete in 157.12 ms (Init 1.17 ms, Start 155.57 ms) · services (13): Platform/FeatureFlagService → ...
    [Boot] DefinitionsValidated (19) and BootCompleted published · 1 and 1 subscribers · bus strict
    [Boot] config: flags SampleFlag=false · tunables SampleTunable=1
    [Boot][Client] ready for Lighthouse8282 in 1.22 ms · controllers (1): FlagsController
    [Flags] update 1: SampleFlag=false
  The 1 and 1 subscribers are MetricsService's (Telemetry Start). The client received FlagsUpdate after phase 8. From the
  Client datamodel 51 events were fired at the server→client remote (50 with extra arguments, 1 NaN): dropped silently, no
  console output. Console errors: 0. Warnings: 5 × "[UIBlox - Warning] FoundationProvider not found" (Roblox CorePackages,
  known since P0.1). The first play session booted in 906 ms (cold DataStore read in RemoteConfigService Start).
NUMBERS (Server play test, best of 3):
  - Gateway.receive: accepted (RequestAttack-shaped payload) 1.77 µs; rate-dropped 0.52 µs; payload-rejected 1.88 µs.
  - Spam at 600 req/s (50× RequestAttack's 12/s) for 10 s: 139 accepted (20 burst + 12/s), session flagged.
  - TokenBucket take 0.118 µs; SimulationClock Tick 0.068 µs; FlagsUpdate guard (3 flags) 0.99 µs.
  - Snapshot codec, 90 enemies (API_CONTRACTS EnemySnapshot layout): 1,532 B, encode 83.8 µs, decode 76.1 µs; 22.4 KB/s per
    client at 15 Hz before remote overhead (§23 budget 25 KB/s; 15.0 KB/s at 10 Hz). Input for A2.3.
  - Boot 157 ms warm / 906 ms cold; the Config DataStore read is ~155 ms of the warm boot; config refresh 116–124 ms (3 reads).
    Phase 8: 0.22 ms. Phase 3: 1.04 ms.
  - Scripts: DataModel 71 · under roots 71 · mirror 71 · StringValues 1/1 · MATCH (mirror_write.py ALL OK, five export calls of
    94,789 + 85,488 + 93,571 + 94,797 + 76,341 characters). The export equals the local drafts (diff -r clean).
  - check_contracts.py → "FlagsUpdate: S2C R since A1.8 rate None | row OK" / MATCH; control `--through A2.5` → 5 rows without
    contracts, DIFFER (exit 1).
  - A1 exit: boot 0 errors; analysis 0; TestRunner 297 tests / 0 failures (≥ 40); broken-definition boot failure shown in A1.6.
RESTORE POINT: backups/A1.8_passed_20261016-1734/ — 6 × .rbxm (D-010), each verified by length + FNV-1a against a fresh Studio
  serialization: ReplicatedStorage 55049 B 1e8fdd07 · ServerScriptService 60100 B 664d08cc · ServerStorage 104066 B f46a7030 ·
  StarterPlayerScripts 4330 B b8b9a0a3 (exported, base64 calls of ≤ 90,000 characters) · Lighting 3445 B 866e3754 ·
  Workspace 12147 B 5ac584ad (equal A1.7, copied).
MIRROR COMMIT: 210424c "A1.8: SimulationClock ..., network layer ..., platform wrappers ..." — mirror/src (Net, Config, Gateway, Lifecycle, 5 services, FlagsController, 9 specs), mirror/sourcemap.json, docs, tools/check_contracts.py.
OWNER APPROVAL: Auto-approved under standing owner approval of 2026-10-16 (D-010). Details D-021; the burst definition was
  decided under owner delegation (D-022).
NOTES / DEBT:
  - execute_luau in a play session has its own require cache, so it cannot read live service state. The boot log prints the
    live config and the client prints each flag update instead.
  - Steady spam just above a remote's rate flags the session within seconds (each refill ends a burst). Clients must respect
    the rates; A2.5's RequestAttack client sends at most 12/s.
  - SampleFlag and SampleTunable are placeholders; A3.9 (flags) and A3.2 (XP curve tunable) replace them.
  - Nothing writes the Config DataStore yet; admin tools (L1.2) or a manual Studio write set it.
  - TimeService (§5.1 Platform) is not built; nothing needs server time yet.
  - D-012 is still open for the owner; nothing here touches monetization.
NEXT: A2.1
```

```text
CHECKPOINT: A2.1 Camera and input  ·  ✅ passed (owner-approved 19:33 UTC)
DATE: 2026-10-16
BUILT: Shared/Util/InputRules (§2.4 bindings table + pure rules), Shared/Config/Settings (AutoAim, AutoFire, CameraRotate),
  Client/Controllers/{InputController, CameraController, AimController}, Client/UI/InputTestPanel (flag InputTestPanel),
  Server/Domains/Data/SettingsService + RequestSettings contract (R, C2S, 5/10); client Bootstrap starts UI modules too;
  StarterPlayer: CharacterJumpHeight 0, EnableMouseLockOption false, DevComputerMovementMode KeyboardMouse,
  DevTouchMovementMode DynamicThumbstick. Details and delegated choices: D-023.
TESTRUNNER: 331 passed / 0 failed (Edit, Tests clone):
    unit.Codec.spec                              21      0    227.10
    unit.Contracts.spec                           7      0      2.48
    unit.DamageCalculator.spec                   18      0      3.42
    unit.EventBus.spec                           24      0    178.73
    unit.Gateway.spec                            22      0      6.68
    unit.Guard.spec                              11      0      1.91
    unit.InputRules.spec                         23      0      3.60
    unit.Lifecycle.spec                          14      0      2.49
    unit.Platform.spec                           14      0      4.43
    unit.Registry.spec                           27      0     34.21
    unit.Settings.spec                           11      0     16.12
    unit.SimulationClock.spec                    11      0    130.32
    unit.StatPipeline.spec                      106      0     10.14
    unit.Telemetry.spec                           8      0      4.17
    unit.TestRunner.spec                          3      0    118.71
    unit.TokenBucket.spec                         7      0      1.98
    unit.Types.spec                               4      0      6.23
    331 passed, 0 failed (17 files, 752.85 ms)
  Server suite in a play session: 331 passed, 0 failed (17 files, 706.31 ms).
  Mutation controls (source patched, one spec run, restored + hash-checked): auto-fire default on gamepad → 1 failed; mouse
  aim assist → 1; firing in the card context → 1; auto-aim range ignored → 1; stick dead zone off → 1; Space unbound from
  dodge → 1; setting value of any type → 2; setting rate 50/100 → 2; extra whitelist key → 3; service ignores the value → 2;
  forget keeps values → 1; no handler registered → 7. Control before the StarterPlayer change: the place-settings test failed
  (JumpHeight 7.2).
SCRIPT ANALYSIS: 0 (bash tools/analyze.sh → files 79, diagnostics 0).
PLAY TEST (Studio, PC, 3 sessions, injected keyboard/mouse/gamepad key codes):
    [Camera] elevated · pitch 55° · distance 44 · fov 50
    [Input] ready · scheme KeyboardMouse · context Combat · touch false · gamepad false
    [Boot][Client] ready for Lighthouse8282 in 4.88 ms · modules (5): AimController, CameraController, FlagsController, InputController, InputTestPanel
    [Boot] phase 2 Data: Data [MigrationService, SettingsService]
    [Boot] phase 8 Network: 0 remotes before, 2 created in ReplicatedStorage.Net in 0.08 ms, 2 now
    [Boot] config: flags InputTestPanel=true SampleFlag=false · tunables SampleTunable=1
    [InputTest] overlay on (flag InputTestPanel)
  Test-panel counts: PC Move, Aim, Primary, Dodge (Shift and Space), Signature (Q), Vote extract (1), Vote hold (2), Card select
  (click) all ≥ 1; Pad Primary (RT), Dodge (B), Signature (RB, LB), Vote extract / hold (D-pad), Card select (D-pad + A) ≥ 1.
  Contexts cycled with F2 and gamepad Y. Settings panel: AutoFire and CameraRotate toggled → server
  "[Settings] … CameraRotate=true", "AutoFire=true"; 180 px right-drag → camera yaw −82.5°; W with auto-fire →
  "Primary Begin/End · auto". Screenshots taken (vote context, all schemes, rotated camera with auto-fire). RequestSettings
  fired from the client: unknown key and wrong type dropped by the guard; 30 in one frame → 8 accepted, 22 rate-dropped.
  Console: Server 0 errors, 0 warnings; Client 0 errors, 5 × known "[UIBlox - Warning] FoundationProvider not found".
  Not covered here (the injector cannot move analog sticks or touch): gamepad Move/Aim and every touch action → owner check.
NUMBERS: Client 60.0 FPS (301 frames in 5 s, avg 16.67 ms, p99 18.06 ms) with camera + input + aim marker + panel; resolveAim
  0.180 µs, stickToWorld 0.199 µs, planeHit 0.050 µs (best of 3 × 10,000); camera height above root 37.5 studs; client boot
  4.88 ms for 5 modules; RequestSettings client pace ≤ 4/s (contract 5/s, burst 10). Scripts: DataModel 80 · under roots 80 ·
  mirror 80 · StringValues 1/1 · MATCH. check_contracts.py → MATCH (registry 2, rows through A2.1 2); control --through A2.5
  → DIFFER.
RESTORE POINT: backups/A2.1_passed_20261016-1925/ — ReplicatedStorage 61336 B 31532cd9 · ServerScriptService 61369 B d287ca8a ·
  ServerStorage 111274 B 3acdb04f · StarterPlayerScripts 18156 B 058c2cac · Workspace 7831 B eaa94454 (exported) · Lighting
  3445 B 866e3754 (equal A1.8, copied); all verified by length + FNV-1a. The StarterPlayer properties are not in a per-service
  .rbxm; they are listed above, in D-023, and checked by InputRules.spec.
MIRROR COMMIT: 57d1433 "A2.1: camera and input ..." — mirror/src (InputRules, Settings, Contracts, Flags, SettingsService, 3 controllers, InputTestPanel, Bootstrap, 5 specs), mirror/sourcemap.json, docs.
OWNER APPROVAL: yes, 2026-10-16 19:33 UTC — "A2.1 OK" in the A2.1 thread after the owner's play on PC and on a phone
  (the pass condition); CP line in DECISION_LOG.
NOTES / DEBT:
  - The touch button layout is a first guess inside Roblox's ContextButtonFrame; the phone check may move buttons.
  - Edit-mode require cache: changed Shared modules were replaced with identical clones so Edit tests load the new source.
  - SettingsService prints "[Settings] <player> <Key>=<Value>" in Studio only (play-test evidence; execute_luau cannot read the
    live service).
  - InputTestPanel is on by default; turn the flag off before the A3.5 public test.
NEXT: A2.2
```

```text
CHECKPOINT: A2.2 Test arena  ·  ✅ passed (auto-approved, D-022)
DATE: 2026-10-16 (started 19:40 UTC, passed 20:25 UTC)
BUILT: ServerStorage/Arenas/TestArena (greybox, 72 parts, 152 × 152 studs, Evacuation Streets palette, markers PlayerSpawn
  + SpawnEdge_{North,South,East,West}); Shared/Util/ArenaGrid (grid rules + queries); Shared/Util/ArenaRaster (template → grid,
  diff, module source); Shared/Definitions/Arenas/TestArena (generated by tools/arena_export.luau: 76 × 76 cells of 2 studs,
  4,608 open, spawn (38,38), edges East 168 / North 156 / South 156 / West 168 open cells); _Registry: Arenas folder + schema
  (19 folders); Encounter/ArenaService (boot check grid vs template, place/release by slot, toLocal/toWorld, spawnCFrame,
  TestArena harness); Config/Flags TestArena (server, default on); StarterPlayer/StarterCharacter placeholder survivor (7.0
  studs, welded primitives, white outline + key light) and a Folder "Animate" in StarterCharacterScripts; tests: ArenaGrid.spec
  14, ArenaRaster.spec 8, ArenaService.spec 10, Survivor.spec 6, fixtures/ArenaFixture; Registry.spec and Lifecycle.spec
  updated. Decisions in D-024.
TESTRUNNER: 370 passed / 0 failed
    Edit:  370 passed, 0 failed (21 files, 1008.28 ms)
    Play (server, after the Animate fix):  370 passed, 0 failed (21 files, 974.60 ms)
    unit.ArenaGrid.spec 14 0 · unit.ArenaRaster.spec 8 0 · unit.ArenaService.spec 10 0 · unit.Registry.spec 28 0 ·
    unit.Survivor.spec 6 0 · unit.Lifecycle.spec 14 0 (every other file as in A2.1)
  First runs found 4 failures, all fixed: a test map with a one-cell pinch, a Model whose PrimaryPart moved GetPivot() off the
  floor top (rasterizer now checks GetPivot; templates leave PrimaryPart unset; +1 test), and two counts (19 → 20 definitions).
SCRIPT ANALYSIS: 0 (bash tools/analyze.sh → files 88, diagnostics 0). check_contracts.py → MATCH (registry 2, rows through
  A2.2 2); check_stats.py → MATCH.
PLAY TEST (Studio, PC, 3 sessions):
    [Arena] TestArena 76 × 76 cells, 4608 open, 4 spawn edges, checked against the template in 7.28 ms
    [Arena] placed TestArena in slot 0 at (0, 0, 1600) in 1.20 ms
    [Arena] Lighthouse8282 spawned in TestArena slot 0 at cell (38,38)
    [Boot] phase 3 Definitions: 20 definitions in 19 folders validated in 6.35 ms
    [Boot] phase 6 Combat → Encounter: Combat [CombatService]; Encounter [ArenaService, MissionSessionService, SimulationClock]
    [Boot] phases 0–8 complete in 1157.85 ms (Init 13.90 ms, Start 1143.71 ms) · services (15)
    [Boot] config: flags InputTestPanel=true SampleFlag=false TestArena=true · tunables SampleTunable=1
  Walk test (client Humanoid:MoveTo along grid BFS paths through every 4th open cell): targets 289 · moves 631 · walked 2159
  studs in 178.1 s · root Y 3.99..4.00 · stuck 0. Push test (walk 1 s into an obstacle, then back out) at 64 of 510
  obstacle-adjacent cells: snagged 0.
  Console, final session: Server 0 errors, 1 warning (written by EventBus.spec's own reporter-failure test during the suite run);
  Client 0 errors, 5 × known UIBlox "FoundationProvider not found". Session 1 also showed "Failed to play animation …
  AnimationTrack limit of 64" from Roblox's default Animate script on the welded survivor; fixed with the Animate Folder
  (session 2: 0 animation warnings, 0 tracks) and covered by Survivor.spec.
  Not covered: keyboard WASD and screenshots. Studio's viewport did not render during this session (RenderStepped fired 0
  times in 5 s, screen_capture timed out in play and Edit), so injected keys did not move the character and the camera check
  was done by calculation (D-024 point 8).
NUMBERS: Grid queries (Edit, best of 3 × 10,000): isOpen 0.070 µs, cellAt 0.051 µs, openAt 0.085 µs, center 0.047 µs; full
  flood fill 0.94 ms; ArenaGrid.new 5.02 ms; problems 5.12 ms; rasterize 1.49 ms (28 blockers of 72 parts); clone + pivot +
  destroy 0.60 ms; boot check 7.28 ms; place at boot 1.20 ms. Client heartbeat in the arena: 299 frames in 5 s, avg 16.67 ms,
  p99 18.18 ms (render FPS not measurable, viewport not rendering). TestArena definition 7,037 B. Camera (computed, FOV 50,
  16:9): 55° / 44 studs shows ~18 studs behind and ~47 ahead, survivor ~12% of screen height; 35° / 40 shows ~16 behind and
  ~129 ahead, ~17%. Scripts: DataModel 89 · under roots 89 · mirror 89 · StringValues 1/1 · MATCH.
RESTORE POINT: backups/A2.2_passed_20261016-2018/ — ReplicatedStorage 73770 B 5724cdb0 · ServerScriptService 65903 B 57222802 ·
  ServerStorage 125982 B 07a44239 · StarterPlayer 8456 B 2475d2fe (new file: StarterCharacter + StarterCharacterScripts)
  exported; Lighting 3445 B 866e3754, StarterPlayerScripts 18156 B 058c2cac, Workspace 7831 B eaa94454 equal A2.1 (copied);
  all 7 verified by length + FNV-1a.
MIRROR COMMIT: <hash> "A2.2: test arena ..."
OWNER APPROVAL: auto-approved under standing owner approval of 2026-10-16 (D-022); CP line in DECISION_LOG.
NOTES / DEBT:
  - Re-run tools/arena_export.luau after any template change; the boot names the first differing cell.
  - The TestArena flag places the arena and moves players; turn it off when run sessions place arenas (A3).
  - Camera stays 55° / 44 / FOV 50; the owner may want to look at it in the arena (D-024 point 8 is revisable).
  - The survivor has no animation (A2.4 procedural) and is replaced by the A3.5 hero model.
  - The walk/push test scripts ran through execute_luau (Client) and are not in the place; method and thresholds are in progress.md.
NEXT: A2.3
```
