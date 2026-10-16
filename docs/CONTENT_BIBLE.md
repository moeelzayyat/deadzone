# CONTENT BIBLE — v0 (approved by owner 2026-10-16)

Names and one-line descriptions for everything a player meets in a run. Consistent with `architecture.md` §2.3, §7.5, §8.4, §10, §13, §16 and `docs/ART_BIBLE.md` (approved 2026-10-16). Names already fixed by the architecture are kept; new names are marked **new**. Numbers here (protocol gates, multipliers) are starting values for A3 tuning, not commitments.

Tone: original, readable by a 9-year-old, apocalypse-everyday rather than fantasy. Infected, not gory (ART_BIBLE rule 7).

## 1. Classes (6) — architecture §7.5, art hues from ART_BIBLE

| Class | Role | Starter weapon · dodge · signature | Unlock | One line |
|---|---|---|---|---|
| Sharpshooter | Ranged precision | Tactical Rifle · combat roll · Piercing Round | Free (default) | Teal marksman who drops elites from the back line; Piercing Round punches one charged shot through an entire column. |
| Juggernaut | Tank | Combat Shotgun · shoulder charge · Unbreakable | Free at player level 5 | Steel-blue wall of armor; Unbreakable makes them immune for a moment and pulls the horde onto them. |
| Stalker | Melee mobility | Dual Machetes · blink step · Frenzy | Serum | Crimson duelist who darts in and out of the crowd; Frenzy turns the machetes into a blur. |
| Incinerator | Area denial | Flame Projector · backstep + fire trail · Firestorm | Serum | Orange fire-crew veteran who paints the ground in flame; Firestorm rains fire over a wide circle. |
| Mechanic | Summons | Nail Launcher · grapple hop · Defense Turret | Serum | Yellow builder who fights with what they bolt down; the Defense Turret holds a lane on its own. |
| Combat Medic | Support | Medical Sidearm · slide · Healing Pulse | Serum | White-green field medic who keeps the squad standing; Healing Pulse heals everyone nearby (self-heal solo). |

Mechanic was "Engineer" in the draft; renamed because the reference game has an Engineer class with a similar role (D-011).

## 2. Enemies (8) — architecture §8.4, silhouettes from ART_BIBLE

| Enemy | Tier | Earliest protocol | One line |
|---|---|---|---|
| Walker | Fodder | P1 | Hunched, arms out, slow and endless; the body of every horde. |
| Runner | Fodder | P1 | Thin and leaning, fast and fragile; from P2 they sprint in packs. |
| Exploder | Fodder | P5 | Round and waddling; swells for 0.8 s, then bursts into a cloud of amber spores. Kill it at range. |
| **Burrower** (new) | Fodder | P4 | Low and spine-backed; travels underground as a moving dust mound and erupts under a player after a ground-crack telegraph, so standing still is never safe. |
| Brute | Elite | P2 | Twice as wide with arms to the knees; winds up, then charges in a straight line and knocks players back. Step aside. |
| Spitter | Elite | P3 | Glowing green sac on its back; keeps its distance and lobs acid globs that leave a burning puddle. |
| Armored | Elite | P4 | Gunmetal plates on the front shrug off Ballistic damage; flank it, burn it or blow it up. |
| Screamer | Elite | P6 | Tall, head thrown back; its shriek speeds up every infected nearby. Kill it first. |

Burrower needs a row in the ART_BIBLE silhouette table on approval: low wide body, spine ridge, dirt-crusted gray-green skin, no saturated accent (it is fodder); the telegraph is a ring of cracking ground.

### Bosses (one per zone, §16) — names proposed, built A4.6 / B2.2 / B3.5
| Zone | Boss | One line |
|---|---|---|
| Evacuation Streets | Mutant Alpha | The first infected to mutate; leaps across the street and slams the ground in a ring. |
| Quarantine Hospital | **Ward Keeper** (new) | Hulking former orderly who charges down corridors behind a wheeled barricade. |
| Industrial District | **Furnace Hulk** (new) | Molten-cored giant that vents heat zones and must cool down after each blast. |
| Research Facility | **Specimen Nine** (new) | Escaped test subject that splits into smaller copies when hurt. |
| Fallen Military Base | **Iron Sergeant** (new) | Armored ex-soldier who calls in spore barrages on marked spots. |
| Epicenter | **The Bloom** (new) | A crystal colossus rooted at the source; the arena itself is its body. |

## 3. Zones (6) — architecture §16, palettes from ART_BIBLE

| Zone | One line |
|---|---|
| Evacuation Streets | Downtown blocks abandoned mid-evacuation: jammed traffic, tipped buses, orange barricades at dusk. The first zone and the FTUE arena. |
| Quarantine Hospital | Sealed wards and a triage atrium; tight corridors open into wide halls under flickering fluorescent light. |
| Industrial District | Rail yards and foundries in sodium light and smog; furnace vents flare on a rhythm you learn to dodge. |
| Research Facility | The lab where the strain was studied; glass walls, cold light, containment doors that open as the protocol rises. |
| Fallen Military Base | The army's last stand: sandbag lines, collapsed watchtowers, storm skies and signal-red warning lights. |
| Epicenter | The crater at the outbreak's source; magenta crystals and glowing veins in the ground, the horde at its strongest. |

## 4. Outbreak Protocol levels (7) — architecture §2.3, colors from ART_BIBLE

| Level | Name | Mutation (what changes in the horde) | Loot | Also |
|---|---|---|---|---|
| P1 | **Contact** | Baseline: Walkers and Runners. | ×1.0 | |
| P2 | **Spread** | Runners sprint in packs; the first Brute arrives. | ×1.3 | |
| P3 | **Breach** | Spitters join the horde. | ×1.6 | Extraction window 45 s, first HOLD / EXTRACT vote |
| P4 | **Mutation** | Walkers grow armor plates on the front; Armored and Burrowers appear. | ×1.9 | P4 evolutions unlock |
| P5 | **Surge** | Exploders appear, spawn rate jumps, the zone boss arrives. | ×2.2 | Extraction window 40 s |
| P6 | **Overrun** | Screamers appear; every elite carries a magenta mutation and moves faster. | ×2.6 | P6 evolutions unlock |
| P7 | **Deadzone** | Maximum density; a boss still alive gains an extra phase. | ×3.0 | Final extraction window 35 s |

The top level carries the game's name on purpose: "we held to Deadzone" is the sentence players repeat.

## 5. Weapons (12) — shared in-run auto-weapons, architecture §7.4

These drop into the three-card pool for every class. The six class starter weapons (§1) are separate, also level in-run, and three of them evolve (§7). Damage tags from `STATS.md`.

| Weapon (all new) | Archetype | Tag | Targeting | One line |
|---|---|---|---|---|
| Auto Pistol | Projectile | Ballistic | Nearest | Steady shots at the closest infected; the reliable first pick. |
| Scrap Cannon | Spread | Ballistic | Nearest | Blasts a fan of scrap pellets that shreds whatever is in front. |
| Rebar Gun | Pierce | Ballistic | Nearest | Fires steel rods that skewer a whole line of enemies. |
| Frag Lobber | Explosive | Explosive | Random | Arcs grenades into the crowd. |
| Chem Canister | Zone | Toxic | Random | Drops a canister that leaks a lingering toxic cloud. |
| Hubcap Orbit | Orbit | Blade | — | Spinning hubcaps circle you and slice anything that gets close. |
| Jumper Cables | Chain | Shock | Nearest | A spark leaps from one infected to the next. |
| Stop Sign | Boomerang | Blade | Nearest | A spinning road sign flies out and comes back, cutting both ways. |
| Spike Strip | Deployable | Blade | — | Lays strips that slow and cut everything that runs over them. |
| Bug Zapper | Aura | Shock | — | A crackling field around you that zaps anything inside. |
| Flare Gun | Projectile | Fire | Elite | Homing flares that seek out elites and set them burning. |
| Siren Decoy | Deployable | Explosive | — | A wailing decoy that pulls the horde in, then goes off. |

All ten archetypes are covered; Projectile and Deployable have two each.

## 6. Passives (10) — architecture §10.2, every stat has a row in `STATS.md`

| Passive | Stat | One line |
|---|---|---|
| Voltage Core | `AttackSpeedPct` | A humming battery that makes every weapon cycle faster. |
| Shrapnel | `ProjectileCount` | One more projectile per volley. |
| Accelerant | `AreaSize` | Bigger blasts, wider clouds, longer flames. |
| Adrenaline | `DamagePct` | Everything hits harder. |
| Canned Food | `MaxHealth` | More health; the apocalypse runs on beans. |
| Bandage Roll | `HealthRegen` | Slowly patches you up mid-fight. |
| Riot Plating | `Armor` | Bolted-on plates that blunt every hit. |
| Red Dot Sight | `CritChance` | More critical hits. |
| Scrap Magnet | `PickupRadius` | Pulls XP orbs in from farther away. |
| Running Shoes | `MoveSpeed` | Outrun the horde. |

Voltage Core, Shrapnel and Accelerant are named by the architecture's evolution recipes. Luck, rerolls and banishes stay in the skill tree (Fortune branch), not in run passives.

## 7. Evolutions (4) — architecture §10.3

| Evolution | Recipe | Gate | One line |
|---|---|---|---|
| Storm Rifle | Tactical Rifle Lv 8 + Voltage Core Lv 5 | any protocol | Every shot arcs to three more infected. |
| Hive Launcher | Nail Launcher Lv 8 + Shrapnel Lv 5 | Protocol ≥ 4 | Nails burst into a swarm of smaller homing nails on impact. |
| **Junk Tornado** (new) | Hubcap Orbit Lv 8 + Scrap Magnet Lv 5 | Protocol ≥ 5 | The hubcaps widen into a whirling ring of junk that drags enemies and orbs inward. |
| Inferno Engine | Flame Projector Lv 8 + Accelerant Lv 5 | Protocol ≥ 6 | The flame jet doubles in length and leaves burning ground behind it. |

Junk Tornado is the one evolution every class can reach, since it uses a shared weapon. Juggernaut, Stalker and Combat Medic starter evolutions are future content.

## 8. Pets (6) — architecture §13, bonuses limited to the pet stats in `STATS.md`

| Pet | Bonus | One line |
|---|---|---|
| Medical Drone | `HealingPct` | Hovers at your shoulder and boosts every heal you receive. |
| Recon Drone | `CritChance` | Marks weak spots on the horde ahead of you. |
| Robo Dog | `PickupRadius` | A loyal mechanical dog that fetches XP orbs. |
| Combat Drone | `DamagePct` | A small armed drone that makes your hits count. |
| Shield Drone | `MaxHealth` | Projects a faint barrier that adds to your health. |
| Bio-Scanner | `XPGainPct` | Studies the infected so you learn faster. |

Followers are client cosmetics; bonuses go through `StatPipeline` and are capped by the pet rarity table. Eggs cost gameplay currency only, with published odds and pity (D-006).

## 9. Originality check against the reference game

Checked on 2026-10-16 against the Roblox listing and three fan wikis for *Survive The Swarm [CLASS COMBAT]* (classes Warrior, Rogue, Mage, Ranger, Engineer, Healer, Knight, Archer; weapons Kunai, Thunderbolt, Boomerang, Sword, Bomb, Bow, Hammer, Staff, Javelin, Heaven's Arrow, Linked Sword; evolutions Arrowgeddon, Vesuvius, Pyroclasm, Bladestorm, Solar Lance; passives Blaze, Bolt; enemies Ghosts; boss The Understudy; zone Emerald Glade; modes Campaign, Gauntlet, Infinite Dungeons; currencies Gold, Essence, Mythical Crystals). Nothing in §1–§8 reuses those names except the two flagged below. The reference is fantasy (swords, bows, magic); DEADZONE is modern apocalypse, so designs diverge by theme.

**Owner decisions (answered 2026-10-16, D-011):**
1. **Class "Engineer"** is an exact reference class name with a similar role. Renamed to **Mechanic** (same kit, same yellow hue). Touches architecture §7.5, ART_BIBLE, ROADMAP A4.4.
2. **Currency "Essence"** is the reference currency for the same use (buying classes and eggs). Renamed to **Serum**. This is a schema v1 field (§6.1, §21.1), so it is a schema change; no profiles exist yet, so there is no data risk.

**Noted, no change proposed now:**
- Mode "Gauntlet" (§17) shares the reference mode name. It is post-L3 in the registry; rename when it is designed (suggestion: Boss Rush).
- Both games bank rewards at an extraction. Ours differs in the core: a rising protocol, a team HOLD / EXTRACT vote, and a wipe still pays 40%. The reference loses all gold on death.
- Level-up cards, weapon evolutions, rerolls, rarity tiers and XP orbs are survivor-like genre conventions (§1 lineage), not reference-specific.

## Owner approval
- [x] Content names approved · date: 2026-10-16 ("I do approve, rename approved for both", project chat 13:19 UTC)
- [x] Decision 1 (Engineer → Mechanic) · answer: yes
- [x] Decision 2 (Essence → Serum) · answer: yes
