--!strict
-- Stats/DamageCalculator (architecture §7.3, docs/STATS.md): outgoing damage and armor mitigation, server-side truth
-- and client prediction alike.
--   Damage = WeaponDamage(level) × ClassDamageMult × (1 + ΣDamagePct) × ΠDamageMults
--            × (Crit ? CritMult : 1) × EnemyResistance(tag) × DifficultyMult
-- The attacker's stats come from StatPipeline. The class DamageMult is a DamagePct Multiplier (STATS.md sources), so
-- ClassDamageMult × (1 + ΣDamagePct) × ΠDamageMults is 1 + the computed DamagePct and the class term enters once (D-020).
-- Crit is rolled by the server (CombatService), never sent by a client.

local Common = require(script.Parent.Parent.Types.Common)
local StatRegistry = require(script.Parent.StatRegistry)

type StatBlock = StatRegistry.StatBlock
export type DamageTag = Common.DamageTag

export type Hit = {
	WeaponDamage: number, -- WeaponDefinition.Damage[level]
	Crit: boolean,
	Tag: DamageTag,
	Resistances: { [string]: number }?, -- EnemyDefinition.Resistances: tag → multiplier 0–1; a missing tag is 1.0
	DifficultyMult: number,
}

local PREFIX = "[Stats] "
local ARMOR_CONSTANT = 100 -- reduction = Armor / (Armor + 100)
local MAX_ARMOR_REDUCTION = 0.75 -- STATS.md Armor cap: at most 75% of incoming

local DamageCalculator = {}

local function finite(value: number, name: string): number
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		error(`{PREFIX}{name} is not a finite number: {tostring(value)}`, 3)
	end
	return value
end

-- EnemyResistance(tag): the multiplier for one damage tag, clamped to 0–1.
function DamageCalculator.resistance(resistances: { [string]: number }?, tag: DamageTag): number
	if table.find(Common.DAMAGE_TAGS, tag) == nil then
		error(`{PREFIX}unknown damage tag {tostring(tag)}`, 2)
	end
	local multiplier = if resistances == nil then nil else resistances[tag]
	if multiplier == nil then
		return 1
	end
	return math.clamp(finite(multiplier, `resistance {tag}`), 0, 1)
end

-- Outgoing damage of one hit, never negative.
function DamageCalculator.damage(attacker: StatBlock, hit: Hit): number
	local weaponDamage = math.max(0, finite(hit.WeaponDamage, "WeaponDamage"))
	local difficulty = math.max(0, finite(hit.DifficultyMult, "DifficultyMult"))
	local damageFactor = 1 + finite(attacker.DamagePct, "DamagePct")
	local critFactor = if hit.Crit then finite(attacker.CritMult, "CritMult") else 1
	local damage = weaponDamage
		* damageFactor
		* critFactor
		* DamageCalculator.resistance(hit.Resistances, hit.Tag)
		* difficulty
	return math.max(0, damage)
end

-- The share of incoming damage that armor removes: Armor / (Armor + 100), at most 75%.
function DamageCalculator.armorReduction(armor: number): number
	local clamped = math.max(0, finite(armor, "Armor"))
	return math.min(clamped / (clamped + ARMOR_CONSTANT), MAX_ARMOR_REDUCTION)
end

-- Damage a player takes after armor, never negative.
function DamageCalculator.mitigate(incoming: number, armor: number): number
	local damage = math.max(0, finite(incoming, "incoming damage"))
	return damage * (1 - DamageCalculator.armorReduction(armor))
end

return table.freeze(DamageCalculator)
