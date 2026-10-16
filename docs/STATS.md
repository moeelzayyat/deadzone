# STATS — pipeline and registry

## Pipeline (architecture.md §7.3)
```
Final = clamp( (Base + ΣFlat) × (1 + ΣAdditivePct) × ΠMultipliers , Min, Max )
```
Layers: **Base** (class/weapon definition) → **Flat** (sum) → **AdditivePct** (sum, applied once) → **Multiplier** (product) → **Cap**.

Every stat has exactly one row here. Every source that modifies a stat declares its layer. `StatPipeline` reads this table's canonical IDs; a stat used in code without a row here is a test failure (A1.7 checks 100% coverage).

**In code (A1.7, D-020):** the rows live once in `ReplicatedStorage/Shared/Stats/StatRegistry`; `StatPipeline.compute(bases, modifiers)` returns a frozen `StatBlock` with every stat, `StatPipeline.preview(...)` gives before/after/delta through the same `compute`, and `DamageCalculator` applies the damage formula. `tools/check_stats.py` checks that this table and `StatRegistry` agree row for row.

**Form.** Percentages are stored as fractions (+150% = 1.5, -90% = -0.9).
- **Value** stats run the formula on the value itself.
- **Bonus** stats are percent bonuses with Base 0. The literal formula would always give 0 for them (`0 × (1 + ΣAdditivePct)`), so they run it on the factor `1 + value` and report `factor − 1`: `Bonus = (1 + ΣAdditivePct) × ΠMultipliers − 1`. With only AdditivePct this is the plain sum; for DamagePct it is exactly the damage formula's `(1 + ΣDamagePct) × ΠDamageMults`. Min/Max bound the bonus.
- On a Value stat, AdditivePct scales `Base + ΣFlat`, so AdditivePct alone on a Base-0 Value stat (HealthRegen) does nothing; regen passives use Flat.
- **Base source:** a number is fixed (a definition cannot override it); `Class` / `Weapon` means the caller passes the base from that definition (missing → error). Whole-number stats (`int`) reject fractional bases and Flat values.
- NaN or infinite inputs, unknown stats and layers a stat does not take are errors. Any finite input, zero and negative included, is clamped and never NaN.

## Registry

| StatId | Unit | Base source | Allowed layers | Form | Min | Max | Notes |
|---|---|---|---|---|---|---|---|
| `MaxHealth` | HP | Class | Flat, AdditivePct, Multiplier | Value | 1 | 100000 | |
| `HealthRegen` | HP/s | 0 | Flat, AdditivePct | Value | 0 | 50 | |
| `Armor` | armor | Class | Flat, AdditivePct | Value | 0 | 300 | reduction = Armor / (Armor + 100), at most 75% of incoming; 300 armor is exactly 75% |
| `MoveSpeed` | studs/s | Class | Flat, AdditivePct | Value | 8 | 32 | server movement sanity uses this |
| `DamagePct` | % | 0 | AdditivePct, Multiplier | Bonus | -90% | +500% | passives/skills additive; evolutions and class role multiplicative |
| `AttackSpeedPct` | % | 0 | AdditivePct | Bonus | 0 | +150% | cooldown ÷ (1 + AttackSpeedPct) |
| `CooldownReduction` | % | 0 | AdditivePct | Bonus | 0 | 60% | signature/dodge cooldowns |
| `CritChance` | % | Class | Flat, AdditivePct | Value | 0 | 100% | |
| `CritMult` | × | 1.5 | Flat | Value | 1.5 | 4.0 | |
| `ProjectileCount` | int | Weapon | Flat | Value | 1 | 12 | per activation |
| `Pierce` | int | Weapon | Flat | Value | 0 | 10 | |
| `AreaSize` | % | 0 | AdditivePct | Bonus | -50% | +200% | zones, explosions, orbit radius |
| `Range` | % | 0 | AdditivePct | Bonus | -50% | +100% | |
| `PickupRadius` | studs | 6 | Flat, AdditivePct | Value | 2 | 40 | XP magnet |
| `XPGainPct` | % | 0 | AdditivePct | Bonus | 0 | +200% | includes squad bonus (+10%/member) |
| `Luck` | % | 0 | AdditivePct | Bonus | 0 | +100% | shifts rarity weights |
| `GoldFindPct` | % | 0 | AdditivePct | Bonus | 0 | +200% | |
| `DodgeDistance` | studs | Class | Flat, AdditivePct | Value | 4 | 24 | |
| `DodgeIFrames` | s | Class | Flat | Value | 0 | 0.6 | |
| `SignatureDurationPct` | % | 0 | AdditivePct | Bonus | 0 | +100% | |
| `HealingPct` | % | 0 | AdditivePct | Bonus | 0 | +100% | Combat Medic, pets |
| `WeaponSlots` | int | 4 | Flat | Value | 1 | 6 | skill tree |
| `PassiveSlots` | int | 4 | Flat | Value | 1 | 6 | skill tree |
| `Rerolls` | int | 0 | Flat | Value | 0 | 3 | per run, from skills |
| `Banishes` | int | 0 | Flat | Value | 0 | 3 | per run, from skills |

## Passive stats (architecture §10.2)
Every passive kind §10.2 names, with its stat, its layer and its cap. Passives are AdditivePct unless this table says Flat; `_Registry` rejects a passive, skill node or pet whose layer its stat does not take.

| §10.2 passive | StatId | Layer | Cap | CONTENT_BIBLE passive |
|---|---|---|---|---|
| Damage % | `DamagePct` | AdditivePct | +500% | Adrenaline |
| Attack speed % | `AttackSpeedPct` | AdditivePct | +150% | Voltage Core |
| Max health | `MaxHealth` | AdditivePct | 100000 | Canned Food |
| Regen | `HealthRegen` | Flat | 50 HP/s | Bandage Roll |
| Crit chance | `CritChance` | Flat | 100% | Red Dot Sight |
| Crit damage | `CritMult` | Flat | 4.0× | — |
| Projectile count | `ProjectileCount` | Flat | 12 | Shrapnel |
| Pickup radius | `PickupRadius` | AdditivePct | 40 studs | Scrap Magnet |
| XP % | `XPGainPct` | AdditivePct | +200% | — |
| Armor | `Armor` | Flat | 300 (75% reduction) | Riot Plating |
| Cooldown reduction | `CooldownReduction` | AdditivePct | 60% | — |
| Luck | `Luck` | AdditivePct | +100% | — (skill tree, CONTENT_BIBLE §6) |
| Move speed | `MoveSpeed` | AdditivePct | 32 studs/s | Running Shoes |

Accelerant (`AreaSize`, AdditivePct, +200%) is a CONTENT_BIBLE passive outside the §10.2 list.

## Damage formula (architecture.md §7.3)
```
Damage = WeaponDamage(level)
       × ClassDamageMult
       × (1 + ΣDamagePct)
       × ΠDamageMults
       × (Crit ? CritMult : 1)
       × EnemyResistance(tag)        -- 0.0–1.0 multiplier per damage tag
       × DifficultyMult
```
Damage tags: `Ballistic`, `Blade`, `Fire`, `Shock`, `Explosive`, `Toxic`. Enemy `Resistances` map tag → multiplier (default 1.0).

`DamageCalculator.damage(attackerStats, hit)` takes the attacker's `StatBlock` from `StatPipeline`. The class `DamageMult` is a DamagePct Multiplier (sources table below), so `ClassDamageMult × (1 + ΣDamagePct) × ΠDamageMults = 1 + DamagePct` and the class term enters once (D-020). Crit is rolled by the server. Damage is never negative; resistances clamp to 0–1. Incoming damage on a player: `DamageCalculator.mitigate(incoming, Armor)`.

## Sources and their layers (seed)
| Source | Stat(s) | Layer |
|---|---|---|
| Class definition `Base` | MaxHealth, MoveSpeed, Armor, CritChance, Dodge* | Base |
| Class `DamageMult` | DamagePct | Multiplier |
| Equipment (armor, trinkets) | MaxHealth, Armor, DamagePct, CritChance | Flat / AdditivePct per affix |
| Skill nodes | any | Flat or AdditivePct per node definition |
| Passives (in-run) | per passive | AdditivePct unless the definition says Flat |
| Pets | MaxHealth, PickupRadius, DamagePct, HealingPct, CritChance, XPGainPct | Flat / AdditivePct, capped by pet rarity table |
| Evolutions | DamagePct, AreaSize, Pierce | Multiplier / Flat |
| Protocol level | enemy-side only (never buffs the player) | — |
| Difficulty | enemy-side + `DifficultyMult` on damage | Multiplier |
| Squad bonus | XPGainPct | AdditivePct |

## Test requirements (A1.7)
- One test per row: single layer applied → expected value.
- All layers combined on `MaxHealth` and `DamagePct` → expected value.
- Every Min/Max reached → clamped.
- Negative and zero inputs → clamped, never NaN.
- `DamageCalculator` with each damage tag against a resistance table.
- `StatPipeline.preview(...)` equals `StatPipeline.compute(...)` for identical inputs (Forge parity).

Covered in A1.7 by `Tests/unit/StatPipeline.spec` (106 tests: every row with no modifiers, alone per allowed layer and at Min and Max, plus a coverage test that fails when a row has no expected values) and `Tests/unit/DamageCalculator.spec` (18 tests).
