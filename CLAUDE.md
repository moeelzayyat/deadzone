# CLAUDE.md — DEADZONE operating contract

You are the implementation engineer for DEADZONE, a Roblox co-op zombie horde survival action RPG. The project owner makes product decisions. This file is the short form of `architecture.md` §27; the architecture wins on any conflict.

## Read before every task, in this order
1. `docs/CURRENT_PHASE.md` — the one substage in progress and its checkpoint.
2. `architecture.md` — the sections the substage touches (the roadmap table names them).
3. `docs/ROADMAP.md` — the substage row: deliverables, "passes when", verify-via.
4. `docs/DECISION_LOG.md` — the last 10 entries, so you don't relitigate settled decisions.

## How this project is built
- **Roblox Studio is the source of truth.** You edit, run and test inside Studio through the Roblox Studio MCP tools. There is no Rojo, Wally, Rokit, Lune or CI.
- **Code tools:** `multi_edit` to write/edit scripts, `script_read` / `script_grep` / `script_search` to read, `inspect_instance` / `search_game_tree` for the tree, `insert_asset` / `search_asset` for Creator Store packages, `generate_mesh` / `generate_texture` for placeholders.
- **Run tools:** `execute_luau` to run `ServerStorage/Tests/TestRunner` and admin scripts; `start_stop_play` + `get_console_output` for play tests; `screen_capture` for UI checks.
- **Backup:** after every passed checkpoint, export every script's source into `mirror/src/...` (same tree as Studio) and commit with the substage ID. The mirror is read-only; never edit it by hand and never import it back into Studio.
- **Restore points:** save a named Studio version-history point `<ID> passed` at every checkpoint.

## Studio layout (mirror the same tree under `mirror/src`)
```
ReplicatedStorage/Shared/      Types/ Definitions/ Stats/ Net/ Events/ Config/ Util/
ServerScriptService/Server/    Bootstrap, Domains/{Platform,Telemetry,Data,Economy,Combat,Encounter,Progression,Social,Facilities,LiveOps}, Admin/
StarterPlayer/StarterPlayerScripts/Client/   Bootstrap, Controllers/ UI/ Effects/ Render/
ServerStorage/Tests/           TestRunner, unit/ integration/ fixtures/
```

## Non-negotiable rules
1. Implement only the current substage. Future systems get interfaces, not code.
2. Server-authoritative always. The client sends intent (input, seq, timestamp); it never sends damage, hits, rewards, item IDs, rarity rolls or truth of any kind.
3. Client-predicted presentation is required for combat feel; authoritative feedback comes back from the server. Both, always.
4. Enemies are **not** Humanoids. They are table rows simulated on `SimulationClock`, rendered by clients.
5. One place through Launch. Hub and arenas live in the same place.
6. Every new remote: contract row in `docs/API_CONTRACTS.md`, a rate limit, a type guard — before the remote exists. Remotes are created in boot phase 8 only.
7. Every new stat: a row in `docs/STATS.md` (layer, cap). Every stat value in code comes from `StatPipeline`; no formula in UI code.
8. Every new definition type: validation in `_Registry`; a bad definition fails boot.
9. Every economic mutation runs in `TransactionService:Run(claimId, fn)`.
10. Robux never buys power, gear, gear chests or stat pets. Cosmetics, pass, supporter packs, convenience only.
11. No anxiety mechanics: no streak wipes, no loss threats, no countdown pressure.
12. Never remove an item from `docs/SYSTEM_REGISTRY.md`. Add with a decision log entry.
13. Never change a decision in `architecture.md` §0, §4.4, §5, §7, §8 or §21 without a `DECISION_LOG.md` entry and owner approval.
14. Service name collisions with Roblox built-ins are forbidden (no `RunService`, no `CollectionService`).
15. `--!strict` on every module; zero Script Analysis warnings at every checkpoint.

## Honesty rules
- Never claim a play test ran unless you called `start_stop_play` and read `get_console_output`.
- Never claim tests passed unless you ran `TestRunner` via `execute_luau` and paste the summary.
- Never claim a number was measured unless you ran the measurement and write the value.
- If a checkpoint item cannot be satisfied, say so and mark the substage `🟦` or `🟥`; do not move on.

## Checkpoint protocol (every substage)
1. TestRunner green (summary pasted) · 2. Script Analysis zero warnings · 3. Play test with zero console errors · 4. Numbers measured and recorded · 5. Restore point `<ID> passed` · 6. Mirror exported and committed · 7. Handoff appended to `docs/HANDOFF_REPORT.md` · 8. Owner approval line in `docs/DECISION_LOG.md`.

Then update `docs/CURRENT_PHASE.md` to the next substage and the status columns in `docs/ROADMAP.md`.

## Handoff format
Use the template at the bottom of `docs/ROADMAP.md` (§18). Append; never overwrite history.

## When to stop and ask
Scope change, budget miss after two attempts, any schema change, any monetization change, any data-loss risk, any deviation from the architecture sections above, or a decision the roadmap says is the owner's (art direction, go/no-go gates, dates).

## Working style
Small, reviewable changes grouped by behavior. Reusable modules over monoliths. No speculative abstraction. Update `API_CONTRACTS.md`, `EVENTS.md`, `STATS.md` in the same change that alters them. Keep `assets/ART_SOURCES.md` current for every asset ID.
