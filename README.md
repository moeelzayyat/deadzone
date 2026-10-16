# DEADZONE

Co-op zombie horde survival action RPG for Roblox. Survivor-like loop (auto-weapons, XP, three-card level-ups, evolutions) with one signature mechanic: **Outbreak Protocol — Hold or Extract**.

## Documents
| File | Purpose |
|---|---|
| `architecture.md` | Master architecture and production spec (v2.0). The authority. |
| `CLAUDE.md` | Operating contract for Claude Code. Read first every session. |
| `docs/ROADMAP.md` | Stages → substages → checkpoints, P0 through live ops. |
| `docs/CURRENT_PHASE.md` | The one substage in progress right now. |
| `docs/SYSTEM_REGISTRY.md` | Every approved system and its status. Nothing is removed. |
| `docs/DECISION_LOG.md` | Architectural decisions and owner approvals. |
| `docs/API_CONTRACTS.md` | Every remote: payload, guard, rate limit. |
| `docs/EVENTS.md` | Event bus catalog. |
| `docs/STATS.md` | Every stat: layer, cap, sources. |
| `docs/TEST_PLAN.md` | What is tested where. |
| `docs/PERFORMANCE_BUDGETS.md` | Targets and measured values. |
| `docs/LIVEOPS_PLAYBOOK.md` | Update cadence and release procedure. |
| `docs/ART_BIBLE.md` | Visual direction and UI theme tokens. |
| `docs/HANDOFF_REPORT.md` | Append-only checkpoint records. |
| `docs/MIRROR.md` | How scripts are exported from Studio into `mirror/src/`. |
| `assets/ART_SOURCES.md` | Every asset ID, origin, license, owner. |
| `mirror/src/` | Read-only export of Studio scripts, per checkpoint. |

## Toolchain
Roblox Studio is the source of truth. Claude Code edits and runs the game through the Roblox Studio MCP server. No Rojo, no CI; tests run inside Studio. This Git repository holds the documents and a read-only mirror of the scripts; it is never imported back into Studio.

| | |
|---|---|
| Experience | DEADZONE — universe `10771233280`, place `72812275891657` (one place through Launch, D-004) |
| Repository | https://github.com/moeelzayyat/deadzone |
| Local folder | open Claude Code in this folder (the repo root) |

### 1. Open the place
1. Open Roblox Studio and sign in with the account that owns the experience.
2. **Home → My Experiences → DEADZONE** (or open place `72812275891657` from the Creator Dashboard with *Edit in Studio*). Team Create is on, so Studio opens the cloud copy; there is no local `.rbxl` to open.
3. First time only, check **Game Settings → Security → Enable Studio Access to API Services** is on (DataStores in Studio) and **Game Settings → Collaboration** shows Team Create enabled.
4. Keep the place open in Studio for the whole working session. Claude can only see a running Studio.

### 2. Connect the Studio MCP server
1. Install the Roblox Studio MCP server and its Studio plugin per their own instructions, and register it with Claude Code (`claude mcp add ...` or the desktop app's connector settings).
2. With the place open, start Claude Code in this folder. The MCP tools appear as `mcp__Roblox_Studio__*`.
3. Check the link: `list_roblox_studios` must list **Deadzone (placeId: 72812275891657)**, and `get_studio_state` must report Edit mode.
4. Start every session with: *"Read CLAUDE.md and docs/CURRENT_PHASE.md, then begin the current substage."*

### 3. Run tests
`ServerStorage/Tests/TestRunner` is built in A1 (decision D-002). From then on, in Studio (Claude runs this through `execute_luau`):
```lua
require(game.ServerStorage.Tests.TestRunner).run()
```
The runner prints a pass/fail table to the Output window. Every checkpoint pastes that summary into `docs/HANDOFF_REPORT.md`.

Play tests run through `start_stop_play` and are read back with `get_console_output`; a checkpoint needs zero console errors from project code.

### Backups
- **Restore points (D-010):** at every checkpoint Claude exports each service to `backups/<ID>_passed_<YYYYMMDD-HHMM>/` as one `.rbxm` per service (`SerializationService`). Terrain, Camera and service-level properties are not captured. `backups/` is git-ignored and stays on this machine.
- **Studio version history:** a named `<ID> passed` version is optional; the MCP cannot create one.
- **Git mirror:** after each checkpoint Claude exports every script into `mirror/src/` (same tree as Studio) and commits with the substage ID. Procedure: `docs/MIRROR.md` (`tools/mirror_export.luau` in Studio, then `python tools/mirror_write.py <result files>`).

### What is not committed
`backups/`, every `.rbxl/.rbxlx/.rbxm/.rbxmx` outside `assets/`, and `.claude/settings.local.json` (per-machine permissions). See `.gitignore`.

## Current status
See `docs/CURRENT_PHASE.md`.
