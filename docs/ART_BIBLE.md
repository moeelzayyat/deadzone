# ART BIBLE — v0 (approved by owner 2026-10-16)

## Direction in one sentence
Low-poly stylized apocalypse: bold silhouettes, saturated zone palettes, readable on a 6-inch phone from the default camera, with fantasy violence and no realistic gore.

## Mood references (original, captured in Studio for P0.3)
| | Image | What it fixes |
|---|---|---|
| A | `assets/mood/mood_A_evacuation_streets_P3.jpg` | Evacuation Streets at dusk, P3 extraction window open: warm amber haze, orange beacons, one teal survivor with a white rim inside the white extraction ring, horde pressing from the far end. |
| B | `assets/mood/mood_B_epicenter_P7.jpg` | Epicenter at P7: violet night, magenta infection crystals and ground veins, four classes back to back, horde bodies unchanged but carrying magenta mutation detail. |

Both scenes are built from primitives only (no assets, no IDs) and are kept in `ServerStorage/ArtReference` so they can be reshot. They show palette, light and silhouette intent, not final model quality.

## Rules
1. **Silhouette first.** Every enemy and class is identifiable as a flat dark shape at 1/4 screen height. Test: screenshot, desaturate, threshold to black; if two archetypes look the same, one changes.
2. **Color = role.** The horde is desaturated (gray-green skin, dull cloth). Elites carry one saturated accent, bosses two. Player classes each own one hue. Protocol mutations add emissive detail and never recolor the base body.
3. **Players are always lit.** Every player character gets a neutral key light and a thin white outline (Highlight, players only, at most 12 per server). Found in mood B: a strong violet ambient turns teal into blue unless the squad has its own light.
4. **Neon means meaning.** `Enum.Material.Neon` is reserved for gameplay signals: infection eyes, elite and boss accents, mutation detail, hazards, pickups, the extraction ring, muzzle flash. Never on decoration.
5. **Readable at distance.** No detail smaller than 0.3 studs on characters; no text in the world.
6. **Juice over fidelity.** Hit flash, kill pop, screen shake and sound carry the feel; models can be simple.
7. **No gore.** Zombies are infected, not butchered: pallid skin, glowing infection eyes and veins, torn clothes. Death = dissolve into particles, no dismemberment, no blood pools.
8. **Mobile budget.** ≤ 1,500 tris per fodder enemy, ≤ 6,000 per class, ≤ 20,000 per boss; one 512 texture per fodder; particles capped per `Config.Mobile`.

## Low-poly style spec
- Faceted, flat-shaded forms; `SmoothPlastic` base, no PBR noise textures on characters. Environment may use one tiling texture per surface type.
- Proportions: chunky. Heads ~1/4 of body height on survivors, slightly larger on zombies; hands and weapons oversized ×1.3 so the action reads from the camera.
- Character height ≈ 7 studs survivor, 6–7 Walker, 9 Brute. Default camera: elevated third-person, 55° pitch, 44 studs out, FOV 50 (set in A2.1, D-023; kept in A2.2, D-024, and checked by eye with a 90-enemy horde in A2.4, D-026, revisable; v0 said ~35° / ~40 studs, architecture §2.4).
- Edges: bevels only where they catch light (roof caps, car cabins, crystal facets).
- Lighting: technology is picked in A1 against the mobile FPS budget (Future if it holds 30 FPS on the low-end device, else ShadowMap); one strong colored sun/sky per zone plus warm or cold local lights; Atmosphere haze carries the zone mood.

## Silhouette rules (roster, architecture §8.4; Burrower added by the content bible, D-011)
| Archetype | Tier | Silhouette cue | Color cue |
|---|---|---|---|
| Walker | Fodder | hunched, both arms straight forward | gray-green skin, dull cloth, green eyes |
| Runner | Fodder | thin, leaning 45°, long stride, arms trailing | same skin, less cloth |
| Brute | Elite | twice as wide, tiny head, arms to the knees | one saturated band (signal red `#FF4D2E`) |
| Spitter | Elite | swollen glowing sac on the back | acid green sac `#5CFF3A` |
| Screamer | Elite | tall, thin, head thrown back, jaw open | pale skin, one cyan throat glow |
| Armored | Elite | squared plates on shoulders and chest | gunmetal plates `#6B6F75` |
| Exploder | Fodder | round body, short legs | amber pustules `#FFB020` |
| Burrower | Fodder | low wide body, spine ridge on the back | dirt-crusted gray-green skin, no accent; telegraph = ring of cracking ground |
| Bosses | Boss | unique outline, 2× elite scale, readable telegraph pose ≥ 0.6 s | two accents + zone accent |

| Class | Hue | Silhouette cue |
|---|---|---|
| Sharpshooter | teal `#1FB5A8` | cap, long rifle forward |
| Juggernaut | steel blue `#4A7FB5` | ×1.35 bulk, shoulder plates, shotgun |
| Stalker | crimson `#D0263A` | two blades, coat tail |
| Incinerator | orange `#F07A1A` | fuel tank on back, flame jet |
| Mechanic | yellow `#E8C21A` | tool pack with antenna, nail launcher |
| Combat Medic | white-green `#7FD8A0` on white | cross-shaped backpack, sidearm |

## Zone palettes and lighting presets
| Zone | Base | Accent | Sky / Atmosphere | Mood |
|---|---|---|---|---|
| Evacuation Streets | asphalt `#5A5E66`, concrete `#8C8273`, brick `#7D6B5D` | emergency orange `#FF7A1A` | dusk amber, Atmosphere `#E8A06A`, ClockTime 17.9 | abandoned in a hurry |
| Quarantine Hospital | bone `#E6E1D6`, mint tile `#A8D5C2` | biohazard yellow `#F5D90A` | fluorescent green-white `#E8F5E8` | sterile, wrong |
| Industrial District | rust `#8A4B2E`, oil black `#1E1C1A` | sodium orange `#FF9A2E` | smog `#8A7E6A` | heavy, mechanical |
| Research Facility | steel blue `#4A6278`, glass `#9CC4D6` | lab cyan `#2EE6F0` | cold white `#E8F0F8` | precise, broken |
| Fallen Military Base | olive `#5B6438`, sandbag tan `#B8A37A` | signal red `#E5302E` | storm gray `#5E646C` | last stand |
| Epicenter | ash `#45404A`, charcoal `#24212A` | infection magenta `#FF2BD6` | violet night, Atmosphere `#7A3A9A`, ClockTime 20.6 | the source |

Preset values used for the two mood shots (Lighting / Atmosphere): Streets — Brightness 2.8, Ambient `#6A5450`, OutdoorAmbient `#A88070`, ColorShift_Top `#FF9A4A`, Density 0.38, Haze 1.6, Glare 0.4. Epicenter — Brightness 1.8, Ambient `#3A3448`, OutdoorAmbient `#5A4E6A`, ColorShift_Top `#C86AE0`, Density 0.42, Haze 2.2, Glare 0.3.

## Protocol meter visual language
P1 green `#46C36A` → P2 `#9BD34A` → P3 yellow `#E5D23A` → P4 `#F5A524` → P5 orange `#FF6A2B` → P6 `#E0309A` → P7 magenta `#FF2BD6`. The biohazard icon gains spikes per level; HUD edge glow matches at P5+. Mutations show on the horde as emissive detail in the protocol color. Extraction window: pulsing white ring on the ground plus a siren.

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

Rarity is never shown by color alone: each tier also has a border pattern (common plain, uncommon one notch, rare two, epic corner gems, legendary animated edge) for color-blind players.

## Icon concept (A3.5 variants)
Sketch: `assets/icons/icon_concept_sketch.svg` (preview `icon_concept_sketch.png`). One survivor silhouette dead center with a white rim, horde pressing from all edges with eyes in the zone accent, three glowing cards above the head (rare / legendary / epic borders), protocol meter along the bottom. Variant A: orange/teal, meter lit to P5. Variant B: magenta/green, meter full at P7. No logo, no text in the icon.

## Thumbnails (16:9)
1. P7 extraction, siren light, one survivor left. 2. The three-card choice over a frozen horde. 3. Four classes back-to-back (mood B is the composition). 4. (L1) Boss telegraph. 5. (L1) Squad vote: HOLD vs EXTRACT.

## Sourcing plan
| Stage | Source |
|---|---|
| A1–A3 | Primitives, Studio-generated meshes/textures, procedural animation |
| A3.5 | One hero, three enemies, one arena from licensed Creator Store packs or commission; licensed audio |
| Beta | Contracted 3D artist + animator for 6 classes, roster, bosses, zones; UI artist for icons/cards |

Every asset ID goes in `assets/ART_SOURCES.md` with license and owner before it ships.

## Owner approval
- [x] Direction approved · date: 2026-10-16 ("Yes Approved", P0.3 thread)
- [x] Two mood references attached (original, captured in Studio) · date: 2026-10-16
