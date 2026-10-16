--!strict
-- Stats/StatRegistry (architecture §7.3, docs/STATS.md): one row per stat, the only copy in code. StatPipeline,
-- DamageCalculator and Definitions/_Registry read stat ids, layers and caps from here; docs/STATS.md is the human copy
-- and must match it row for row (tools/check_stats.py).
-- Percentages are fractions: +150% is 1.5, -90% is -0.9.
-- Form (D-020): a Value stat runs the §7.3 formula on its value. A Bonus stat is a percent bonus with Base 0; it runs the
-- formula on its factor 1 + value and reports factor − 1, so Min/Max bound the bonus itself.

export type StatId =
	"MaxHealth"
	| "HealthRegen"
	| "Armor"
	| "MoveSpeed"
	| "DamagePct"
	| "AttackSpeedPct"
	| "CooldownReduction"
	| "CritChance"
	| "CritMult"
	| "ProjectileCount"
	| "Pierce"
	| "AreaSize"
	| "Range"
	| "PickupRadius"
	| "XPGainPct"
	| "Luck"
	| "GoldFindPct"
	| "DodgeDistance"
	| "DodgeIFrames"
	| "SignatureDurationPct"
	| "HealingPct"
	| "WeaponSlots"
	| "PassiveSlots"
	| "Rerolls"
	| "Banishes"

export type Layer = "Flat" | "AdditivePct" | "Multiplier"
export type Form = "Value" | "Bonus"
-- Fixed: the row's Base is the base. Class / Weapon: the caller passes the base from that definition.
export type BaseSource = "Fixed" | "Class" | "Weapon"

export type StatRow = {
	Id: StatId,
	Unit: string,
	BaseSource: BaseSource,
	Base: number?, -- set only when BaseSource is Fixed
	Layers: { Layer },
	Min: number,
	Max: number,
	Form: Form,
	Integer: boolean, -- base and Flat values must be whole numbers
}

-- Every stat, computed. RunPlayerState.ComputedStats (§6.2) holds one.
export type StatBlock = {
	MaxHealth: number,
	HealthRegen: number,
	Armor: number,
	MoveSpeed: number,
	DamagePct: number,
	AttackSpeedPct: number,
	CooldownReduction: number,
	CritChance: number,
	CritMult: number,
	ProjectileCount: number,
	Pierce: number,
	AreaSize: number,
	Range: number,
	PickupRadius: number,
	XPGainPct: number,
	Luck: number,
	GoldFindPct: number,
	DodgeDistance: number,
	DodgeIFrames: number,
	SignatureDurationPct: number,
	HealingPct: number,
	WeaponSlots: number,
	PassiveSlots: number,
	Rerolls: number,
	Banishes: number,
}

local F: Layer, A: Layer, M: Layer = "Flat", "AdditivePct", "Multiplier"

local function row(
	id: StatId,
	unit: string,
	base: BaseSource | number,
	layers: { Layer },
	min: number,
	max: number,
	form: Form,
	integer: boolean?
): StatRow
	local fixed = typeof(base) == "number"
	local source: BaseSource = if fixed then "Fixed" else base :: BaseSource
	return table.freeze({
		Id = id,
		Unit = unit,
		BaseSource = source,
		Base = if fixed then base :: number else nil,
		Layers = table.freeze(layers),
		Min = min,
		Max = max,
		Form = form,
		Integer = integer == true,
	})
end

-- Same order as docs/STATS.md.
local ROWS: { StatRow } = {
	row("MaxHealth", "HP", "Class", { F, A, M }, 1, 100000, "Value"),
	row("HealthRegen", "HP/s", 0, { F, A }, 0, 50, "Value"),
	row("Armor", "armor", "Class", { F, A }, 0, 300, "Value"), -- 300 armor = 75% reduction, the STATS.md cap
	row("MoveSpeed", "studs/s", "Class", { F, A }, 8, 32, "Value"),
	row("DamagePct", "%", 0, { A, M }, -0.9, 5, "Bonus"),
	row("AttackSpeedPct", "%", 0, { A }, 0, 1.5, "Bonus"),
	row("CooldownReduction", "%", 0, { A }, 0, 0.6, "Bonus"),
	row("CritChance", "%", "Class", { F, A }, 0, 1, "Value"),
	row("CritMult", "×", 1.5, { F }, 1.5, 4, "Value"),
	row("ProjectileCount", "int", "Weapon", { F }, 1, 12, "Value", true),
	row("Pierce", "int", "Weapon", { F }, 0, 10, "Value", true),
	row("AreaSize", "%", 0, { A }, -0.5, 2, "Bonus"),
	row("Range", "%", 0, { A }, -0.5, 1, "Bonus"),
	row("PickupRadius", "studs", 6, { F, A }, 2, 40, "Value"),
	row("XPGainPct", "%", 0, { A }, 0, 2, "Bonus"),
	row("Luck", "%", 0, { A }, 0, 1, "Bonus"),
	row("GoldFindPct", "%", 0, { A }, 0, 2, "Bonus"),
	row("DodgeDistance", "studs", "Class", { F, A }, 4, 24, "Value"),
	row("DodgeIFrames", "s", "Class", { F }, 0, 0.6, "Value"),
	row("SignatureDurationPct", "%", 0, { A }, 0, 1, "Bonus"),
	row("HealingPct", "%", 0, { A }, 0, 1, "Bonus"),
	row("WeaponSlots", "int", 4, { F }, 1, 6, "Value", true),
	row("PassiveSlots", "int", 4, { F }, 1, 6, "Value", true),
	row("Rerolls", "int", 0, { F }, 0, 3, "Value", true),
	row("Banishes", "int", 0, { F }, 0, 3, "Value", true),
}

local IDS: { string } = {} -- StatIds in row order, as { string } for consumers that take string lists
local BY_ID: { [string]: StatRow } = {}
for _, statRow in ROWS do
	assert(BY_ID[statRow.Id] == nil, `[Stats] duplicate stat row {statRow.Id}`)
	assert(statRow.Min <= statRow.Max, `[Stats] {statRow.Id}: Min above Max`)
	table.insert(IDS, statRow.Id)
	BY_ID[statRow.Id] = statRow
end

local LAYERS: { Layer } = { F, A, M }
-- STATS.md "Sources and their layers": the stats a pet bonus may change.
local function stats(...: StatId): { string }
	return { ... }
end
local PET_STATS = stats("MaxHealth", "PickupRadius", "DamagePct", "HealingPct", "CritChance", "XPGainPct")
for _, id in PET_STATS do
	assert(BY_ID[id] ~= nil, `[Stats] PET_STATS lists unknown stat {id}`)
end

return table.freeze({
	ROWS = table.freeze(ROWS),
	IDS = table.freeze(IDS),
	BY_ID = table.freeze(BY_ID),
	LAYERS = table.freeze(LAYERS),
	PET_STATS = table.freeze(PET_STATS),
})
