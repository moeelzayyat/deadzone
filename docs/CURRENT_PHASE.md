# CURRENT PHASE

**Stage:** A1 — Foundation
**Substage:** A1.1 — Studio layout
**Status:** ⬜ Not started
**Last checkpoint passed:** P0.6 (2026-10-16) — P0 exit: all six ✅
**Started:** —
**Planned stage start:** A1 2026-10-19 (D-013)

## Deliverables (from ROADMAP.md)
- Folders per architecture §4.3 in ReplicatedStorage / ServerScriptService / StarterPlayerScripts / ServerStorage; Bootstrap scripts; ProfileStore inserted and version pinned.

## Checkpoint — passes when
Play test boots; console prints `[Boot] phases 0–8 complete` with the ordered service list and zero errors.

## Verify via
`start_stop_play`, `get_console_output`.

## Notes for this substage
- First substage with scripts: every module `--!strict`, Script Analysis 0 warnings, mirror export to `mirror/src` is real from here on.
- ProfileStore is Apache-2.0 (P0.5): keep the license header, mark modifications, keep a LICENSE copy beside the module; compare the store asset (109379033046155) against GitHub (wally.toml 1.0.3, last commit 2025-07-31) when inserting, and pin the version in `assets/ART_SOURCES.md`.
- Service names must not collide with Roblox built-ins (D-008). UI library is decided at A2.1 (D-009), not here.
- Open owner item: D-012 (paid random items). Doesn't block A1; must be decided before B1.
- Starting before the planned 2026-10-19 date is fine (unattended mode); log it in `progress.md`.
- `backups/` and `.claude/settings.local.json` stay out of git.

## On pass
Set this file to **A1.2**, update `docs/ROADMAP.md`, append the checkpoint record to `docs/HANDOFF_REPORT.md`, add the approval line to `docs/DECISION_LOG.md`.
