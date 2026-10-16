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
