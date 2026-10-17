--!strict
-- Stats/ClassStats (architecture §7.3, §7.5; docs/STATS.md "Sources"): the StatPipeline inputs that come from a class
-- and its weapon, so every caller builds a player's StatBlock the same way (CombatService for damage, A2.5; later the run
-- state, Forge previews and the class select screen).
--   ClassStats.bases(class, weapon, level) → Bases       Class.Base Health/Speed/Armor → MaxHealth/MoveSpeed/Armor;
--                                                        weapon Projectiles/Pierce at `level` (1 and 0 when absent)
--   ClassStats.modifiers(class) → { Modifier }           the class DamageMult as a DamagePct Multiplier (D-020)
--   ClassStats.compute(class, weapon, level, extra?) → StatBlock   StatPipeline.compute of the above plus `extra`
-- The ClassDefinition Base of §7.5 carries no CritChance, DodgeDistance or DodgeIFrames, which STATS.md lists as
-- class-based; until A4.1 gives each class its own, every class uses DEFAULT_BASES (D-027, revisable).

local StatPipeline = require(script.Parent.StatPipeline)

type Bases = StatPipeline.Bases
type Modifier = StatPipeline.Modifier
type StatBlock = StatPipeline.StatBlock

export type ClassLike = { Id: string, Base: { Health: number, Speed: number, DamageMult: number, Armor: number } }
export type WeaponLike = { Id: string, Projectiles: { number }?, Pierce: { number }? }

local DEFAULT_BASES = table.freeze({
	CritChance = 0.05,
	DodgeDistance = 10,
	DodgeIFrames = 0.3,
})

local ClassStats = { DEFAULT_BASES = DEFAULT_BASES }

local function atLevel(values: { number }?, level: number, default: number): number
	if values == nil or #values == 0 then
		return default
	end
	return values[math.clamp(level, 1, #values)]
end

function ClassStats.bases(class: ClassLike, weapon: WeaponLike, level: number): Bases
	local bases: Bases = {
		MaxHealth = class.Base.Health,
		MoveSpeed = class.Base.Speed,
		Armor = class.Base.Armor,
		ProjectileCount = atLevel(weapon.Projectiles, level, 1),
		Pierce = atLevel(weapon.Pierce, level, 0),
		CritChance = DEFAULT_BASES.CritChance,
		DodgeDistance = DEFAULT_BASES.DodgeDistance,
		DodgeIFrames = DEFAULT_BASES.DodgeIFrames,
	}
	return bases
end

function ClassStats.modifiers(class: ClassLike): { Modifier }
	return {
		{ Stat = "DamagePct", Layer = "Multiplier", Value = class.Base.DamageMult, Source = `Class:{class.Id}` },
	}
end

function ClassStats.compute(class: ClassLike, weapon: WeaponLike, level: number, extra: { Modifier }?): StatBlock
	local modifiers = ClassStats.modifiers(class)
	if extra then
		table.move(extra, 1, #extra, #modifiers + 1, modifiers)
	end
	return StatPipeline.compute(ClassStats.bases(class, weapon, level), modifiers)
end

return table.freeze(ClassStats)
