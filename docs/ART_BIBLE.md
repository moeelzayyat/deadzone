# ART BIBLE — v0 (P0.3 draft, owner approval pending)

## Direction in one sentence
Low-poly stylized apocalypse: bold silhouettes, saturated zone palettes, readable on a 6-inch phone from the default camera, with fantasy violence and no realistic gore.

## Rules
1. **Silhouette first.** Every enemy and class is identifiable as a dark shape at 1/4 screen height.
2. **Color = role.** Fodder desaturated; elites carry one saturated accent; bosses two. Player classes each own a hue; protocol mutations add emissive detail, never recolor the base.
3. **Readable at distance.** No detail smaller than 0.3 studs on characters; no text in the world.
4. **Juice over fidelity.** Hit flash, kill pop, screen shake and sound carry the feel; models can be simple.
5. **No gore.** Zombies are infected, not butchered: pallid skin, glowing infection veins, torn clothes. Death = dissolve into particles, no dismemberment.
6. **Mobile budget.** ≤ 1,500 tris per fodder enemy, ≤ 6,000 per class, ≤ 20,000 per boss; one 512 texture per fodder; particles capped per `Config.Mobile`.

## Zone palettes (seed)
| Zone | Base | Accent | Sky | Mood |
|---|---|---|---|---|
| Evacuation Streets | asphalt gray, warm concrete | emergency orange | dusk amber | abandoned in a hurry |
| Quarantine Hospital | bone white, mint tile | biohazard yellow | fluorescent green-white | sterile, wrong |
| Industrial District | rust, oil black | sodium orange | smog | heavy, mechanical |
| Research Facility | steel blue, glass | lab cyan | cold white | precise, broken |
| Fallen Military Base | olive, sandbag tan | signal red | storm gray | last stand |
| Epicenter | ash, charcoal | infection magenta | violet | the source |

## Protocol meter visual language
P1 green → P3 yellow → P5 orange → P7 magenta. Biohazard icon gains spikes per level; HUD edge glow matches at P5+. Extraction window: pulsing white ring on the ground plus a siren.

## Class hues
Sharpshooter teal · Juggernaut steel blue · Stalker crimson · Incinerator orange · Engineer yellow · Combat Medic white-green.

## UI theme tokens (`Shared/Config/Theme`)
| Token | Value | Use |
|---|---|---|
| `bg.0` / `bg.1` / `bg.2` | #0D0F12 / #15181D / #1E232A | panels, cards |
| `text.primary` / `text.muted` | #F2F4F7 / #9AA3AF | |
| `accent` | #FF6A2B | buttons, highlights |
| `danger` | #E5484D | wipe, errors |
| `success` | #46C36A | extract, confirmations |
| `rarity.common/uncommon/rare/epic/legendary` | #B8BEC7 / #4CC26A / #3B82F6 / #A855F7 / #F59E0B | borders, glows |
| `font.display` / `font.body` | GothamBold / Gotham (Roblox built-in) | |
| `type.xl/lg/md/sm` | 32 / 24 / 18 / 14 (scaled by `UIScale` for phones) | |
| `radius.card` / `radius.button` | 12 / 8 | |
| `touch.min` | 48 px | every tappable control |

## Icon concept (A3.5 variants)
One survivor silhouette dead center, horde pressing from all edges, three glowing cards above the head, protocol meter along the bottom. Variant A: orange/teal palette. Variant B: magenta/green. No logo-only icon.

## Thumbnails (16:9)
1. P7 extraction, siren light, one survivor left. 2. The three-card choice over a frozen horde. 3. Four classes back-to-back. 4. (L1) Boss telegraph. 5. (L1) Squad vote: HOLD vs EXTRACT.

## Sourcing plan
| Stage | Source |
|---|---|
| A1–A3 | Primitives, Studio-generated meshes/textures, procedural animation |
| A3.5 | One hero, three enemies, one arena from licensed Creator Store packs or commission; licensed audio |
| Beta | Contracted 3D artist + animator for 6 classes, roster, bosses, zones; UI artist for icons/cards |

Every asset ID goes in `assets/ART_SOURCES.md` with license and owner before it ships.

## Owner approval
- [ ] Direction approved · date: ____
- [ ] Two mood references attached (original or licensed) · date: ____
