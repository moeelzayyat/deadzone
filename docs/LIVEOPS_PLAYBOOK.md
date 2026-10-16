# LIVE-OPS PLAYBOOK

Active from L2. Applies to every update after public launch.

## Cadence
| Cadence | Content | Day | Checkpoint |
|---|---|---|---|
| Daily (first 30 days), then as needed | Error triage, hotfixes | any | Top error fixed < 24 h; `HANDOFF_REPORT.md` entry |
| Weekly | One of: weapon or evolution, mutation, QoL, small event, balance | Friday | Shipped on day; changelog posted; restore point saved; mirror committed |
| Monthly | Boss, dungeon, class skin set, or mode | last Friday | Signal review attached |
| Seasonal (8–10 weeks) | Zone, pass season, event, raid rotation | planned 4 weeks ahead | L3 checklist |
| Quarterly | Economy audit, data audit, performance re-baseline, roadmap revision | — | Documents updated |

Floor: if weekly cannot be sustained, announce **biweekly** to players. Never skip silently.

## Release procedure (every update)
1. Content change lives in `Definitions/*` and `Config/*` wherever possible; engine changes need a decision-log note.
2. Full `TestRunner` green; Script Analysis zero warnings.
3. Play test on PC and phone; `get_console_output` zero errors.
4. Migration fixture added if the schema changed; migration tests green.
5. Named restore point `release-YYYY-MM-DD`.
6. Mirror export + commit.
7. Publish. Watch error reports and the funnel for 30 minutes.
8. Post changelog (in-game notification + community).
9. If a blocking error appears: revert to the restore point and republish (target < 15 minutes), then fix forward.

## Events
- Defined in `Definitions/Seasons/` and `Definitions/Events/`, windowed by server time, toggled by a feature flag so they can be killed without a republish.
- Event currency expires with a clear in-game end date and a conversion (to Gold) after expiry; nothing is silently lost.
- No streaks, no "log in or lose it" messaging, no countdown pressure in prompts.

## Signal review (weekly, 30 minutes)
| Signal | Where | Action threshold |
|---|---|---|
| Playthrough rate | Creator analytics | icon/thumbnail test if down 2 weeks |
| First-play bounce (<60 s, 61–180 s) | Creator analytics + funnel | FTUE change if up 2 weeks |
| D1 / D2–7 / D8–28 play days | Creator analytics | content/progression review |
| Co-play days | Creator analytics + party-size telemetry | squad incentive review |
| Qualified sessions | Creator analytics | — |
| Class pick rates | telemetry | balance patch if any class < 8% or > 35% |
| Protocol distribution | telemetry | pacing patch if < 20% of runs reach P3 or > 60% reach P7 |
| HOLD rate at P3 | telemetry | vote UI review if < 15% |
| Economy inflow/outflow | telemetry | sink/source adjustment if inflow > outflow by > 20% for 2 weeks |
| Top 5 errors | error reports | fix in the next daily slot |

## Community and support
- Discord/community server with #bugs, #feedback, #codes.
- Support macro: lost-item reports → `AdminDataService.Inspect` → snapshot rollback or grant → log.
- Creator codes: one cosmetic per creator, tracked by `CodeRedemptionService`.
- Moderation: Roblox chat filtering; report flow documented; no custom unfiltered text input.

## Rollback
- Every publish has a named restore point. Rollback = restore + republish.
- Data rollback = `AdminDataService.Rollback(userId, snapshotDate)`; snapshots retained 7 days.
- A rollback is a decision-log entry with cause and prevention.
