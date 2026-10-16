# STATS — pipeline and registry

## Pipeline (architecture.md §7.3)
```
Final = clamp( (Base + ΣFlat) × (1 + ΣAdditivePct) × ΠMultipliers , Min, Max )
```
Layers: **Base** (class/weapon definition) → **Flat** (sum) → **AdditivePct** (sum, applied once) → **Multiplier** (product) → **Cap**.

Every stat has exactly one row here. Every source that modifies a stat declares its layer. `StatPipeline` reads this table's canonical IDs; a stat used in code without a row here is a test failure (A1.7 checks 100% coverage).

## Registry

| StatId | Unit | Base source | Allowed layers | Min | Max | Notes |
|---|---|---|---|---|---|---|
| `MaxHealth` | HP | Class | Flat, AdditivePct, Multiplier | 1 | 100000 | |
| `HealthRegen` | HP/s | 0 | Flat, AdditivePct | 0 | 50 | |
| `Armor` | flat reduction | Class | Flat, AdditivePct | 0 | 75% of incoming (applied as reduction cap) | reduction = Armor / (Armor + 100) |
| `MoveSpeed` | studs/s | Class | Flat, AdditivePct | 8 | 32 | server movement sanity uses this |
| `DamagePct` | % | 0 | AdditivePct, Multiplier | -90% | +500% | passives/skills additive; evolutions multiplicative |
| `AttackSpeedPct` | % | 0 | AdditivePct | 0 | +150% | cooldown ÷ (1 + AttackSpeedPct) |
| `CooldownReduction` | % | 0 | AdditivePct | 0 | 60% | signature/dodge cooldowns |
| `CritChance` | % | Class | Flat, AdditivePct | 0 | 100% | |
| `CritMult` | × | 1.5 | Flat | 1.5 | 4.0 | |
| `ProjectileCount` | int | Weapon | Flat | 1 | 12 | per activation |
| `Pierce` | int | Weapon | Flat | 0 | 10 | |
| `AreaSize` | % | 0 | AdditivePct | -50% | +200% | zones, explosions, orbit radius |
| `Range` | % | 0 | AdditivePct | -50% | +100% | |
| `PickupRadius` | studs | 6 | Flat, AdditivePct | 2 | 40 | XP magnet |
| `XPGainPct` | % | 0 | AdditivePct | 0 | +200% | includes squad bonus (+10%/member) |
| `Luck` | % | 0 | AdditivePct | 0 | +100% | shifts rarity weights |
| `GoldFindPct` | % | 0 | AdditivePct | 0 | +200% | |
| `DodgeDistance` | studs | Class | Flat, AdditivePct | 4 | 24 | |
| `DodgeIFrames` | s | Class | Flat | 0 | 0.6 | |
| `SignatureDurationPct` | % | 0 | AdditivePct | 0 | +100% | |
| `HealingPct` | % | 0 | AdditivePct | 0 | +100% | Combat Medic, pets |
| `WeaponSlots` | int | 4 | Flat | 1 | 6 | skill tree |
| `PassiveSlots` | int | 4 | Flat | 1 | 6 | skill tree |
| `Rerolls` | int | 0 | Flat | 0 | 3 | per run, from skills |
| `Banishes` | int | 0 | Flat | 0 | 3 | per run, from skills |

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
- `StatPipeline:Preview(...)` equals `StatPipeline:Compute(...)` for identical inputs (Forge parity).
