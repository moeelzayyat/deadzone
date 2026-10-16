--!strict
-- Stats/StatPipeline (architecture §7.3, docs/STATS.md): the one place a stat value is computed. In-run stats, Forge
-- previews, pet bonuses and codex displays all call this module; no formula lives anywhere else (CLAUDE.md rule 7).
--   Final = clamp( (Base + ΣFlat) × (1 + ΣAdditivePct) × ΠMultipliers , Min, Max )
-- Value stats run the formula on the value; Bonus stats (percent bonuses, Base 0) run it on the factor 1 + value and
-- report factor − 1, so DamagePct = (1 + ΣDamagePct) × ΠDamageMults − 1 as in the §7.3 damage formula (D-020).
--   local block = StatPipeline.compute(bases, modifiers)      -- frozen StatBlock with every stat
--   local preview = StatPipeline.preview(bases, modifiers, { Add = { ... }, RemoveSources = { "Item:abc" } })
-- Inputs come from validated definitions, so a bad input is a bug: unknown stats, layers a stat does not allow,
-- non-finite numbers, fractional values on whole-number stats and wrong bases throw "[Stats] ...". Any finite input,
-- zero and negative included, gives a clamped result and never NaN.

local StatRegistry = require(script.Parent.StatRegistry)

type StatId = StatRegistry.StatId
type Layer = StatRegistry.Layer
type StatRow = StatRegistry.StatRow
export type StatBlock = StatRegistry.StatBlock

-- One contribution to one stat. Source names who added it ("Class:Sharpshooter", "Item:<InstanceId>", "Passive:...").
export type Modifier = { Stat: StatId, Layer: Layer, Value: number, Source: string }
-- Bases for the stats whose base comes from a definition (BaseSource Class or Weapon), keyed by StatId.
export type Bases = { [string]: number }
-- A change to preview: modifiers added, and every modifier from the listed sources removed.
export type Change = { Add: { Modifier }?, RemoveSources: { string }? }
export type Preview = {
	Before: StatBlock,
	After: StatBlock,
	Delta: { [string]: number }, -- After − Before, only for stats that changed
}

local PREFIX = "[Stats] "

local StatPipeline = {}

local function isFinite(value: unknown): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isWhole(value: number): boolean
	return value % 1 == 0
end

-- Throws when a modifier is not one StatPipeline can apply.
function StatPipeline.check(modifier: Modifier)
	local statRow = StatRegistry.BY_ID[modifier.Stat]
	if statRow == nil then
		error(`{PREFIX}unknown stat {tostring(modifier.Stat)}`, 2)
	end
	if table.find(statRow.Layers, modifier.Layer) == nil then
		error(
			`{PREFIX}{statRow.Id} does not take layer {tostring(modifier.Layer)} (allowed: {table.concat(statRow.Layers, ", ")})`,
			2
		)
	end
	if not isFinite(modifier.Value) then
		error(`{PREFIX}{statRow.Id} {modifier.Layer} value is not a finite number: {tostring(modifier.Value)}`, 2)
	end
	if statRow.Integer and modifier.Layer == "Flat" and not isWhole(modifier.Value) then
		error(`{PREFIX}{statRow.Id} is a whole number; Flat {modifier.Value} is not`, 2)
	end
	if typeof(modifier.Source) ~= "string" or modifier.Source == "" then
		error(`{PREFIX}{statRow.Id} modifier has no Source`, 2)
	end
end

local function baseOf(statRow: StatRow, bases: Bases): number
	local given = bases[statRow.Id]
	if statRow.BaseSource == "Fixed" then
		if given ~= nil then
			error(`{PREFIX}the base of {statRow.Id} is fixed at {statRow.Base}; it does not come from a definition`, 3)
		end
		return statRow.Base :: number
	end
	if given == nil then
		error(`{PREFIX}{statRow.Id} needs its base from the {statRow.BaseSource} definition`, 3)
	end
	if not isFinite(given) then
		error(`{PREFIX}base of {statRow.Id} is not a finite number: {tostring(given)}`, 3)
	end
	if statRow.Integer and not isWhole(given) then
		error(`{PREFIX}{statRow.Id} is a whole number; base {given} is not`, 3)
	end
	return given
end

local function apply(statRow: StatRow, base: number, flat: number, additive: number, multiplier: number): number
	local value
	if statRow.Form == "Bonus" then
		value = (1 + base + flat) * (1 + additive) * multiplier - 1
	else
		value = (base + flat) * (1 + additive) * multiplier
	end
	if value ~= value then
		-- Only reachable when finite inputs overflow (inf × 0); never hand out NaN.
		return statRow.Min
	end
	return math.clamp(value, statRow.Min, statRow.Max)
end

type Sums = { flat: { [string]: number }, additive: { [string]: number }, multiplier: { [string]: number } }

-- Checks the modifiers (all of them, or only those of one stat) and sums them per stat and layer.
local function sum(modifiers: { Modifier }, only: StatId?): Sums
	local sums: Sums = { flat = {}, additive = {}, multiplier = {} }
	for _, modifier in modifiers do
		if only == nil or modifier.Stat == only then
			StatPipeline.check(modifier)
			local id = modifier.Stat
			if modifier.Layer == "Flat" then
				sums.flat[id] = (sums.flat[id] or 0) + modifier.Value
			elseif modifier.Layer == "AdditivePct" then
				sums.additive[id] = (sums.additive[id] or 0) + modifier.Value
			else
				sums.multiplier[id] = (sums.multiplier[id] or 1) * modifier.Value
			end
		end
	end
	return sums
end

local function value(statRow: StatRow, bases: Bases, sums: Sums): number
	local id = statRow.Id
	return apply(statRow, baseOf(statRow, bases), sums.flat[id] or 0, sums.additive[id] or 0, sums.multiplier[id] or 1)
end

function StatPipeline.compute(bases: Bases, modifiers: { Modifier }): StatBlock
	for key in bases do
		if StatRegistry.BY_ID[key] == nil then
			error(`{PREFIX}base given for unknown stat {tostring(key)}`, 2)
		end
	end
	local sums = sum(modifiers)
	local block: { [string]: number } = {}
	for _, statRow in StatRegistry.ROWS do
		block[statRow.Id] = value(statRow, bases, sums)
	end
	return table.freeze(block) :: StatBlock
end

-- One stat's value, same rules as compute; only that stat's modifiers are read. `base` is required for Class/Weapon
-- stats and must be nil for Fixed ones.
function StatPipeline.stat(id: StatId, base: number?, modifiers: { Modifier }): number
	local statRow = StatRegistry.BY_ID[id]
	if statRow == nil then
		error(`{PREFIX}unknown stat {tostring(id)}`, 2)
	end
	local bases: Bases = {}
	if base ~= nil then
		bases[id] = base
	end
	return value(statRow, bases, sum(modifiers, id))
end

-- A StatBlock read by id (codex rows, previews, tests).
function StatPipeline.get(block: StatBlock, id: string): number
	local values: { [string]: number } = block :: { [string]: number }
	return values[id]
end

-- Forge, equip and pet previews: the block before and after a change, through compute, so a preview always equals
-- what compute returns once the change is applied.
function StatPipeline.preview(bases: Bases, modifiers: { Modifier }, change: Change): Preview
	local removed: { [string]: boolean } = {}
	local removeSources: { string } = change.RemoveSources or {}
	local add: { Modifier } = change.Add or {}
	for _, source in removeSources do
		removed[source] = true
	end
	local applied: { Modifier } = {}
	for _, modifier in modifiers do
		if not removed[modifier.Source] then
			table.insert(applied, modifier)
		end
	end
	for _, modifier in add do
		table.insert(applied, modifier)
	end
	local before = StatPipeline.compute(bases, modifiers)
	local after = StatPipeline.compute(bases, applied)
	local delta: { [string]: number } = {}
	for _, id in StatRegistry.IDS do
		local difference = StatPipeline.get(after, id) - StatPipeline.get(before, id)
		if difference ~= 0 then
			delta[id] = difference
		end
	end
	return table.freeze({ Before = before, After = after, Delta = table.freeze(delta) })
end

return table.freeze(StatPipeline)
