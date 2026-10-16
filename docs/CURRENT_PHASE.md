# CURRENT PHASE

**Stage:** A2 — Combat Feel
**Substage:** A2.1 — Camera and input
**Status:** ⬜ Not started
**Last checkpoint passed:** A1.8 (2026-10-16, auto-approved); A1 Foundation complete
**Started:** —
**Planned stage start:** A2 2026-11-02 (D-013)

## Deliverables (from ROADMAP.md)
- Elevated third-person camera; `InputController` with PC/mobile/console bindings; mobile auto-aim + auto-fire toggle.

## Checkpoint — passes when
Owner plays on PC and on a phone (Studio device emulator plus one real phone); every action fires on all three input schemes.

## Verify via
Play test, `screen_capture`.

## Notes for this substage
- Architecture: §2.4 (camera, bindings table, mobile defaults: auto-aim on, auto-fire while moving; all bindings through one `InputController` using `ContextActionService`; client input is intent, the server decides), §4.3 (`Client/Controllers`), §7.1/§7.2 (intent only, never truth), §23 (input → visual feedback ≤ 1 client frame is measured in A2.5, not here).
- The pass condition needs the owner to play on PC and on a real phone. That step waits for the owner; everything else (emulator runs, screenshots, tests) can be done unattended.
- Remote: `RequestSettings` (R, C2S, `{ Key, Value }`, whitelist of keys, 5 / 10, since A2.1) is the only API_CONTRACTS row for A2.1. If the auto-fire toggle is saved server-side it goes through it: add the `Shared/Net/Contracts` entry, a Gateway handler registered before phase 8, a spec, and keep `python tools/check_contracts.py` at MATCH (it now requires every row through the current substage). Settings are not persisted before A5 (PlayerSettings is a provisional §6.1 sub-type, D-020).
- Client controllers are ModuleScripts in `Client/Controllers` returning `{ Name = <module name>, start = function }`; the client Bootstrap starts each in its own thread (A1.8). `FlagsController` holds the Client feature flags.
- Network (D-021): remotes only through `Server/Gateway` (phase 8); inbound order identity → token bucket → guard → handler; three bursts of rate drops in 60 s flag the session, so clients must not exceed a remote's rate.
- Unattended mode is wider since D-022: take the recommended option at a fork, record it as "Decided by Claude under owner delegation of 2026-10-16 (revisable)" with alternatives, log it, mention it in one line, keep going. Real-money spend, publishing to the live game or real players, and player-data-loss risks still wait for the owner; GO/NO-GO gates stay the owner's.
- Mirror export: `docs/MIRROR.md` (D-015). The A1.8 export took five calls (`START = 29`, `46`, `59`, `66`); the place has 71 scripts. Then `bash tools/analyze.sh` → `diagnostics: 0` (D-014).
- `multi_edit` splits dotted script names; create `*.spec` modules with `execute_luau`. Long sources go in execute_luau calls of ≤ 40 KB inside `[==[ ... ]==]`, hash-checked against the local draft; overwrite an existing script only after its Studio source matches the mirror.
- Tests: run on a clone of `ServerStorage.Tests` in Edit mode. Specs require clones (`Shared:Clone()`, `Server:Clone()`) because of the Edit-mode require cache. In a play session, execute_luau has its own require cache: it cannot see live service state (use boot-log lines or Instances).
- Backups (D-010): `SerializationService:SerializeInstancesAsync(service:GetChildren())` → `EncodingService:Base64Encode`, base64 chunks of ≤ 90,000 characters per call (padded past 66K), decoded locally and verified by length + FNV-1a. ServerStorage is now 104 KB (139K base64, two calls). Copy unchanged services from the previous backup after a hash match.
- Every module `--!strict`. Vendor code (`*/Vendor/*`) is out of the zero-warning rule.
- Open owner item: D-012 (paid random items; before B1).

## On pass
Set this file to **A2.2**, update `docs/ROADMAP.md`, append the checkpoint record to `docs/HANDOFF_REPORT.md`, add the approval line to `docs/DECISION_LOG.md`.
