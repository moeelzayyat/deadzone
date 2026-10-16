# DEADZONE — progress log

Owner rule (2026-10-16): log project progress here so context survives session compression. Read this after `CLAUDE.md` and `docs/CURRENT_PHASE.md`. The log below is append-only; only "Current state" is rewritten.

## Current state
- **Substage:** P0.4 — Content bible v0 (⬜ not started). Needs the owner's written review; auto-approval does not cover it.
- **Last passed:** P0.3 Art bible v0 (owner-approved 2026-10-16 13:01 UTC).
- **Repo:** https://github.com/moeelzayyat/deadzone, branch `main`.
- **Studio:** place 72812275891657 / universe 10771233280. The Studio MCP lists several open places; always target "Deadzone (placeId: 72812275891657)".
- **Place contents:** 0 scripts. Root folders exist (`ReplicatedStorage/Shared`, `ServerScriptService/Server`, `StarterPlayerScripts/Client`, `ServerStorage/Tests`) plus `ServerStorage/ArtReference` (P0.3 mood scenes).
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
