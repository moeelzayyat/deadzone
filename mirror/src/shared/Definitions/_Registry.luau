--!strict
-- Definitions/_Registry (architecture §4.1 principle 3, §4.3, §5.2 phase 3): loads, validates and indexes every definition
-- under Shared/Definitions. CLAUDE.md rule 8: every definition folder has a schema here, and a bad definition fails boot.
--   local Registry = require(ReplicatedStorage.Shared.Definitions._Registry)
--   local registry = Registry.shared()             -- loads and validates once; throws "[Definitions] ..." on any problem
--   registry:get("Weapons", "TacticalRifle")       -- frozen definition, or nil
--   registry:all("Enemies")                        -- frozen definitions sorted by Id
-- Layout: one ModuleScript per definition, directly inside its folder, returning one table whose Id equals the module name.
-- Ids are unique across all folders, because the Codex and profiles key on bare DefinitionIds (§6.1).
-- Checks: the 18 folders exist and nothing else sits beside them; each module requires cleanly and returns a table; every
-- field matches the folder schema (required fields present, no unknown fields, types, ranges, enums, asset ids); references
-- to other definitions resolve; folder rules hold (per-level arrays match MaxLevel, weights sum to 1, skill prerequisites
-- are acyclic, ...). Every problem is collected and reported in one error, so one boot shows them all.
-- Schemas fixed by the architecture (Classes §7.5, Weapons §10.1, Enemies §8.4, Missions §9.2) are copied exactly. The
-- others are provisional: the substage in their `settles` entry settles them here and in the decision log (D-019).

local Catalog = require(script.Parent.Parent.Events.Catalog)

export type Kind =
	"Classes"
	| "Weapons"
	| "Passives"
	| "Evolutions"
	| "Enemies"
	| "Protocol"
	| "Missions"
	| "Zones"
	| "Loot"
	| "Items"
	| "Skills"
	| "Pets"
	| "Eggs"
	| "Forge"
	| "Quests"
	| "Raids"
	| "Seasons"
	| "Shop"

-- A validated definition: a frozen deep copy of the module's table. Consumers cast to the type their substage declares.
export type Definition = { [string]: unknown }

-- One definition as read from a folder: the folder (kind), the module name and the value the module returned.
export type Entry = { kind: string, name: string, value: unknown }

export type Registry = {
	count: number,
	get: (self: Registry, kind: Kind, id: string) -> Definition?,
	all: (self: Registry, kind: Kind) -> { Definition },
}

type FieldType = {
	kind: string, -- id | string | text | asset | number | integer | boolean | enum | array | map | record | ref
	optional: boolean?,
	min: number?, -- number/integer lower bound; array minimum length
	max: number?, -- number/integer upper bound
	above: number?, -- number exclusive lower bound
	values: { string }?, -- enum
	of: FieldType?, -- array element
	key: FieldType?, -- map key
	value: FieldType?, -- map value
	fields: { [string]: FieldType }?, -- record
	target: string?, -- ref: the folder the Id must exist in
}

type Fields = { [string]: FieldType }
type Report = (message: string) -> ()
-- Folder rules run only on definitions whose fields already validated, so they read fields without re-checking types;
-- `any` is limited to these rule functions.
type Lookup = (kind: string, id: string) -> any
type Schema = {
	settles: string, -- "fixed §x.y" or the substage that settles a provisional schema
	fields: Fields,
	check: ((def: any, report: Report, lookup: Lookup) -> ())?,
	checkAll: ((defs: { any }, report: (id: string, message: string) -> ()) -> ())?,
}
type RefUse = { path: string, target: string, id: string }

local PREFIX = "[Definitions] "
local MAX_LISTED = 40

-- Shared vocabularies. STATS and the stat layers mirror docs/STATS.md until A1.7 adds Shared/Stats.
local RARITY = { "Common", "Uncommon", "Rare", "Epic", "Legendary" } -- ART_BIBLE rarity tokens
local DAMAGE_TAGS = { "Ballistic", "Blade", "Fire", "Shock", "Explosive", "Toxic" } -- STATS.md
local ARCHETYPES = { "Projectile", "Spread", "Pierce", "Explosive", "Zone", "Orbit", "Chain", "Boomerang", "Deployable", "Aura" } -- §7.4
local TARGETING = { "Nearest", "Random", "LowestHealth", "HighestHealth", "Elite", "Cursor" } -- §7.4
local WALLET = { "Gold", "Serum", "Samples" } -- §6.1 Wallet: gameplay currencies
local STATS = {
	"MaxHealth",
	"HealthRegen",
	"Armor",
	"MoveSpeed",
	"DamagePct",
	"AttackSpeedPct",
	"CooldownReduction",
	"CritChance",
	"CritMult",
	"ProjectileCount",
	"Pierce",
	"AreaSize",
	"Range",
	"PickupRadius",
	"XPGainPct",
	"Luck",
	"GoldFindPct",
	"DodgeDistance",
	"DodgeIFrames",
	"SignatureDurationPct",
	"HealingPct",
	"WeaponSlots",
	"PassiveSlots",
	"Rerolls",
	"Banishes",
}
local PET_STATS = { "MaxHealth", "PickupRadius", "DamagePct", "HealingPct", "CritChance", "XPGainPct" } -- STATS.md pets row
local MAX_PROTOCOL = 7 -- §2.3
local BOSS_MIN_TELEGRAPH = 0.6 -- §8.4

local EVENT_NAMES: { string } = {}
for name in Catalog.EVENTS do
	table.insert(EVENT_NAMES, name)
end
table.sort(EVENT_NAMES)

-- Field type constructors.
local function ft(spec: FieldType): FieldType
	return table.freeze(spec)
end

local T = {
	id = ft({ kind = "id" }),
	string = ft({ kind = "string" }),
	text = ft({ kind = "text" }),
	asset = ft({ kind = "asset" }),
	boolean = ft({ kind = "boolean" }),
}

local function num(min: number?, max: number?): FieldType
	return ft({ kind = "number", min = min, max = max })
end

local function positive(): FieldType
	return ft({ kind = "number", above = 0 })
end

local function int(min: number?, max: number?): FieldType
	return ft({ kind = "integer", min = min, max = max })
end

local function enum(values: { string }): FieldType
	-- Vocabularies such as RARITY are shared by several schemas, so freeze each list once.
	return ft({ kind = "enum", values = if table.isfrozen(values) then values else table.freeze(values) })
end

local function array(of: FieldType, minLength: number?): FieldType
	return ft({ kind = "array", of = of, min = minLength })
end

local function map(key: FieldType, value: FieldType): FieldType
	return ft({ kind = "map", key = key, value = value })
end

local function record(fields: Fields): FieldType
	return ft({ kind = "record", fields = table.freeze(fields) })
end

local function ref(target: string): FieldType
	return ft({ kind = "ref", target = target })
end

local function optional(t: FieldType): FieldType
	local copy = table.clone(t)
	copy.optional = true
	return table.freeze(copy)
end

local function protocolLevel(): FieldType
	return int(1, MAX_PROTOCOL)
end

local function weightSum(rows: { any }): number
	local total = 0
	for _, row in rows do
		total += row.Weight
	end
	return total
end

local function checkWeights(rows: { any }, field: string, report: Report)
	local total = weightSum(rows)
	if math.abs(total - 1) > 1e-6 then
		report(`{field}: weights sum to {total}; they must sum to 1 (§15)`)
	end
end

local function checkLevels(def: any, fields: { string }, maxField: string, report: Report)
	for _, field in fields do
		local values = def[field]
		if values ~= nil and #values ~= def[maxField] then
			report(`{field}: has {#values} levels, {maxField} is {def[maxField]}`)
		end
	end
end

local function checkUnique(field: string): (defs: { any }, report: (id: string, message: string) -> ()) -> ()
	return function(defs: { any }, report: (id: string, message: string) -> ())
		local seen: { [any]: string } = {}
		for _, def in defs do
			local value = def[field]
			local first = seen[value]
			if first ~= nil then
				report(def.Id, `{field} {tostring(value)} is already used by {first}`)
			else
				seen[value] = def.Id
			end
		end
	end
end

local SCHEMAS: { [string]: Schema } = {
	Classes = {
		settles = "fixed §7.5",
		fields = {
			Id = T.id,
			DisplayName = T.string,
			Role = T.string,
			Base = record({ Health = positive(), Speed = num(0), DamageMult = num(0), Armor = num(0) }),
			StarterWeaponId = ref("Weapons"),
			PrimaryAbilityId = T.string,
			DodgeAbilityId = T.string,
			SignatureAbilityId = T.string,
			Unlock = record({
				Kind = enum({ "Free", "Level", "Currency" }),
				Value = optional(num(0)),
				Currency = optional(enum(WALLET)),
			}),
			WeaponTags = array(T.string),
			Icon = T.asset,
			Model = T.asset,
		},
		check = function(def: any, report: Report)
			local unlock = def.Unlock
			if unlock.Kind == "Free" and (unlock.Value ~= nil or unlock.Currency ~= nil) then
				report("Unlock: Kind Free takes no Value or Currency")
			elseif unlock.Kind == "Level" and (unlock.Value == nil or unlock.Value % 1 ~= 0 or unlock.Currency ~= nil) then
				report("Unlock: Kind Level needs a whole Value (player level) and no Currency")
			elseif unlock.Kind == "Currency" and (unlock.Value == nil or unlock.Currency == nil) then
				report("Unlock: Kind Currency needs Value and Currency")
			end
		end,
	},
	Weapons = {
		settles = "fixed §10.1",
		fields = {
			Id = T.id,
			DisplayName = T.string,
			Archetype = enum(ARCHETYPES),
			Rarity = enum(RARITY),
			Damage = array(num(0), 1),
			Cooldown = array(positive(), 1),
			Range = num(0),
			MaxLevel = int(1),
			Projectiles = optional(array(int(1), 1)),
			Pierce = optional(array(int(0), 1)),
			MaxTargets = int(1),
			Targeting = enum(TARGETING),
			Tags = array(enum(DAMAGE_TAGS), 1),
			ClassTags = optional(array(T.string)),
			EvolutionIds = array(ref("Evolutions")),
			Render = record({ Projectile = optional(T.asset), Fx = T.text, Sfx = T.asset }),
			Icon = T.asset,
		},
		check = function(def: any, report: Report, lookup: Lookup)
			checkLevels(def, { "Damage", "Cooldown", "Projectiles", "Pierce" }, "MaxLevel", report)
			for _, evolutionId in def.EvolutionIds do
				local evolution = lookup("Evolutions", evolutionId)
				if evolution ~= nil and evolution.WeaponId ~= def.Id then
					report(`EvolutionIds: {evolutionId} evolves {evolution.WeaponId}, not {def.Id}`)
				end
			end
		end,
	},
	Passives = {
		settles = "A3.4",
		fields = {
			Id = T.id,
			DisplayName = T.string,
			Stat = enum(STATS),
			Layer = enum({ "Flat", "AdditivePct" }),
			Values = array(num(), 1),
			MaxLevel = int(1),
			Icon = T.asset,
		},
		check = function(def: any, report: Report)
			checkLevels(def, { "Values" }, "MaxLevel", report)
		end,
	},
	Evolutions = {
		settles = "A3.4",
		fields = {
			Id = T.id,
			DisplayName = T.string,
			WeaponId = ref("Weapons"),
			WeaponLevel = int(1),
			PassiveId = ref("Passives"),
			PassiveLevel = int(1),
			MinProtocol = protocolLevel(),
			Icon = T.asset,
		},
		check = function(def: any, report: Report, lookup: Lookup)
			local weapon = lookup("Weapons", def.WeaponId)
			if weapon ~= nil then
				if def.WeaponLevel > weapon.MaxLevel then
					report(`WeaponLevel {def.WeaponLevel} is above {def.WeaponId}.MaxLevel {weapon.MaxLevel}`)
				end
				if table.find(weapon.EvolutionIds, def.Id) == nil then
					report(`{def.WeaponId}.EvolutionIds does not list {def.Id}`)
				end
			end
			local passive = lookup("Passives", def.PassiveId)
			if passive ~= nil and def.PassiveLevel > passive.MaxLevel then
				report(`PassiveLevel {def.PassiveLevel} is above {def.PassiveId}.MaxLevel {passive.MaxLevel}`)
			end
		end,
	},
	Enemies = {
		settles = "fixed §8.4",
		fields = {
			Id = T.id,
			Tier = enum({ "Fodder", "Elite", "Boss" }),
			MaxHealth = positive(),
			MoveSpeed = num(0),
			Radius = positive(),
			Attack = record({ Damage = num(0), Range = num(0), Cooldown = positive(), TelegraphTime = num(0) }),
			XP = num(0),
			Abilities = array(T.string),
			Resistances = map(enum(DAMAGE_TAGS), num(0, 1)),
			MinProtocol = protocolLevel(),
			Render = record({ Model = T.asset, Anims = map(T.string, T.asset), Scale = positive() }),
		},
		check = function(def: any, report: Report)
			if def.Tier == "Boss" and def.Attack.TelegraphTime < BOSS_MIN_TELEGRAPH then
				report(`Attack.TelegraphTime: a boss telegraphs for at least {BOSS_MIN_TELEGRAPH} s (§8.4), got {def.Attack.TelegraphTime}`)
			end
		end,
	},
	Protocol = {
		settles = "A3.5",
		fields = {
			Id = T.id,
			DisplayName = T.string,
			Level = protocolLevel(),
			LootMultiplier = num(1),
		},
		checkAll = checkUnique("Level"),
	},
	Missions = {
		settles = "fixed §9.2",
		fields = {
			Id = T.id,
			ZoneId = ref("Zones"),
			DurationCap = positive(),
			SpawnBudget = record({ MaxAlive = int(1), BaseRate = positive(), RatePerProtocol = num(0) }),
			EnemyPool = array(ref("Enemies"), 1),
			EliteSchedule = array(record({ Protocol = protocolLevel(), Id = ref("Enemies") })),
			BossId = ref("Enemies"),
			BossAtProtocol = protocolLevel(),
			ProtocolRate = record({ SecondsPerLevel = positive(), ElitesPerLevel = int(0) }),
			ExtractionWindows = array(record({ Protocol = protocolLevel(), Seconds = positive() })),
			RewardTable = ref("Loot"),
		},
		check = function(def: any, report: Report, lookup: Lookup)
			local boss = lookup("Enemies", def.BossId)
			if boss ~= nil and boss.Tier ~= "Boss" then
				report(`BossId: {def.BossId} is a {boss.Tier} enemy, not a Boss`)
			end
			for index, enemyId in def.EnemyPool do
				local enemy = lookup("Enemies", enemyId)
				if enemy ~= nil and enemy.Tier == "Boss" then
					report(`EnemyPool[{index}]: {enemyId} is a Boss; bosses come from BossId`)
				end
			end
			local last = 0
			for index, window in def.ExtractionWindows do
				if window.Protocol <= last then
					report(`ExtractionWindows[{index}]: Protocol {window.Protocol} must be above the previous window's {last}`)
				end
				last = window.Protocol
			end
		end,
	},
	Zones = {
		settles = "B2.2",
		fields = {
			Id = T.id,
			DisplayName = T.string,
			Order = int(1),
		},
		checkAll = checkUnique("Order"),
	},
	Loot = {
		settles = "B1.5",
		fields = {
			Id = T.id,
			Entries = array(
				record({
					Weight = positive(),
					Kind = enum({ "Currency", "Material", "Item" }),
					RewardId = T.string,
					Min = int(0),
					Max = int(0),
				}),
				1
			),
		},
		check = function(def: any, report: Report, lookup: Lookup)
			checkWeights(def.Entries, "Entries", report)
			for index, entry in def.Entries do
				local path = `Entries[{index}]`
				if entry.Min > entry.Max then
					report(`{path}: Min {entry.Min} is above Max {entry.Max}`)
				end
				if entry.Kind == "Currency" and table.find(WALLET, entry.RewardId) == nil then
					report(`{path}.RewardId: "{entry.RewardId}" is not a wallet currency ({table.concat(WALLET, ", ")})`)
				elseif entry.Kind == "Item" and lookup("Items", entry.RewardId) == nil then
					report(`{path}.RewardId: no Items definition "{entry.RewardId}"`)
				end
			end
		end,
	},
	Items = {
		settles = "B1.2",
		fields = {
			Id = T.id,
			DisplayName = T.string,
			Slot = enum({ "Weapon", "Helmet", "Chest", "Legs", "Trinket" }),
			Rarity = enum(RARITY),
			ClassTags = optional(array(T.string)),
			Icon = T.asset,
		},
	},
	Skills = {
		settles = "B1.3",
		fields = {
			Id = T.id,
			DisplayName = T.string,
			Branch = enum({ "Survival", "Firepower", "Fortune", "Squad" }),
			Prereqs = array(ref("Skills")),
			MaxRank = int(1),
			Cost = array(int(0), 1),
			Effect = record({ Stat = enum(STATS), Layer = enum({ "Flat", "AdditivePct" }), PerRank = num() }),
		},
		check = function(def: any, report: Report)
			checkLevels(def, { "Cost" }, "MaxRank", report)
		end,
		checkAll = function(defs: { any }, report: (id: string, message: string) -> ())
			-- §14: the skill tree is a directed acyclic graph.
			local byId: { [string]: any } = {}
			for _, def in defs do
				byId[def.Id] = def
			end
			local state: { [string]: number } = {} -- 1 visiting, 2 done
			local stack: { string } = {}
			local reported: { [string]: boolean } = {}
			local function visit(id: string)
				local def = byId[id]
				if def == nil or state[id] == 2 then
					return
				end
				if state[id] == 1 then
					local start = table.find(stack, id) or 1
					local cycle = table.move(stack, start, #stack, 1, {})
					table.insert(cycle, id)
					if not reported[id] then
						reported[id] = true
						report(id, `Prereqs: cycle {table.concat(cycle, " → ")}`)
					end
					return
				end
				state[id] = 1
				table.insert(stack, id)
				for _, prereq in def.Prereqs do
					visit(prereq)
				end
				table.remove(stack)
				state[id] = 2
			end
			for _, def in defs do
				visit(def.Id)
			end
		end,
	},
	Pets = {
		settles = "B3.1",
		fields = {
			Id = T.id,
			DisplayName = T.string,
			Stat = enum(PET_STATS),
			Layer = enum({ "Flat", "AdditivePct" }),
			Icon = T.asset,
			Model = T.asset,
		},
	},
	Eggs = {
		settles = "B3.1",
		fields = {
			Id = T.id,
			DisplayName = T.string,
			Price = record({ Currency = enum(WALLET), Amount = int(1) }), -- §13: gameplay currencies only
			Odds = array(record({ PetId = ref("Pets"), Weight = positive() }), 1),
			PityAfter = int(1),
		},
		check = function(def: any, report: Report)
			checkWeights(def.Odds, "Odds", report)
		end,
	},
	Forge = {
		settles = "B1.7",
		fields = {
			Id = T.id,
			Kind = enum({ "Enhance", "Salvage", "Craft", "Reroll" }),
			Gold = int(0),
			Materials = map(T.string, int(1)),
			OutputItemId = optional(ref("Items")),
		},
		check = function(def: any, report: Report)
			if def.Kind == "Craft" and def.OutputItemId == nil then
				report("OutputItemId: a Craft recipe needs an output item")
			elseif def.Kind ~= "Craft" and def.OutputItemId ~= nil then
				report(`OutputItemId: only Craft recipes have an output item (Kind is {def.Kind})`)
			end
		end,
	},
	Quests = {
		settles = "B2.6",
		fields = {
			Id = T.id,
			DisplayName = T.string,
			Cadence = enum({ "Daily", "Weekly" }),
			Event = enum(EVENT_NAMES), -- §18: quests progress from bus events only
			Target = int(1),
		},
	},
	Raids = {
		settles = "B3.7",
		fields = {
			Id = T.id,
			DisplayName = T.string,
			MinPlayers = int(1, 12),
			MaxPlayers = int(1, 12), -- §4.4: 12 players per server
		},
		check = function(def: any, report: Report)
			if def.MinPlayers > def.MaxPlayers then
				report(`MinPlayers {def.MinPlayers} is above MaxPlayers {def.MaxPlayers}`)
			end
		end,
	},
	Seasons = {
		settles = "L1.3",
		fields = {
			Id = T.id,
			DisplayName = T.string,
			Tiers = int(1),
		},
	},
	Shop = {
		settles = "L1.3",
		fields = {
			Id = T.id,
			DisplayName = T.string,
			Kind = enum({ "Cosmetic", "Pass", "SupporterPack", "Convenience" }), -- §21.2; Robux never buys power (§21.3)
			Price = record({ Currency = enum({ "Robux", "Gold", "Serum", "Samples" }), Amount = int(1) }),
			ProductId = optional(int(1)),
		},
		check = function(def: any, report: Report)
			if def.Price.Currency == "Robux" and def.ProductId == nil then
				report("ProductId: a Robux price needs the developer product or pass id")
			elseif def.Price.Currency ~= "Robux" and def.ProductId ~= nil then
				report(`ProductId: only Robux prices have a product id (Currency is {def.Price.Currency})`)
			end
		end,
	},
}

-- §4.3 folder order.
local KINDS: { Kind } = {
	"Classes",
	"Weapons",
	"Passives",
	"Evolutions",
	"Enemies",
	"Protocol",
	"Missions",
	"Zones",
	"Loot",
	"Items",
	"Skills",
	"Pets",
	"Eggs",
	"Forge",
	"Quests",
	"Raids",
	"Seasons",
	"Shop",
}

local Registry = {
	KINDS = table.freeze(KINDS),
	SCHEMAS = table.freeze(SCHEMAS),
}

local function describeType(t: FieldType): string
	local kind = t.kind
	if kind == "id" then
		return "Id (a letter, then letters, digits or _)"
	elseif kind == "string" then
		return "non-empty string"
	elseif kind == "text" then
		return "string"
	elseif kind == "asset" then
		return `asset ("" or "rbxassetid://<number>")`
	elseif kind == "number" or kind == "integer" then
		if t.min ~= nil and t.max ~= nil then
			return `{kind} {t.min}–{t.max}`
		elseif t.min ~= nil then
			return `{kind} ≥ {t.min}`
		elseif t.max ~= nil then
			return `{kind} ≤ {t.max}`
		elseif t.above ~= nil then
			return `{kind} > {t.above}`
		end
		return kind
	elseif kind == "enum" then
		return `one of {table.concat(t.values :: { string }, ", ")}`
	elseif kind == "array" then
		local of = describeType(t.of :: FieldType)
		return if t.min ~= nil then `array of {of} (at least {t.min})` else `array of {of}`
	elseif kind == "map" then
		return `map of {describeType(t.key :: FieldType)} to {describeType(t.value :: FieldType)}`
	elseif kind == "record" then
		return "table"
	elseif kind == "ref" then
		return `{t.target} Id`
	end
	return kind
end

local function describeValue(value: unknown): string
	local t = typeof(value)
	if t == "string" then
		return `string "{value}"`
	elseif t == "number" or t == "boolean" then
		return `{t} {tostring(value)}`
	end
	return t
end

local function isSequence(value: { [unknown]: unknown }): boolean
	local count = 0
	for key in value do
		if typeof(key) ~= "number" then
			return false
		end
		count += 1
	end
	for index = 1, count do
		if value[index] == nil then
			return false
		end
	end
	return true
end

local function sortedKeys(fields: Fields): { string }
	local names: { string } = {}
	for name in fields do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

local checkFields: (fields: Fields, value: { [unknown]: unknown }, prefix: string, report: Report, refs: { RefUse }) -> ()

local function checkValue(t: FieldType, value: unknown, path: string, report: Report, refs: { RefUse })
	local kind = t.kind
	local function bad()
		report(`{path}: expected {describeType(t)}, got {describeValue(value)}`)
	end
	if kind == "id" then
		if typeof(value) ~= "string" or string.match(value, "^%a[%w_]*$") == nil then
			bad()
		end
	elseif kind == "string" then
		if typeof(value) ~= "string" or value == "" then
			bad()
		end
	elseif kind == "text" then
		if typeof(value) ~= "string" then
			bad()
		end
	elseif kind == "asset" then
		if typeof(value) ~= "string" or (value ~= "" and string.match(value, "^rbxassetid://%d+$") == nil) then
			bad()
		end
	elseif kind == "boolean" then
		if typeof(value) ~= "boolean" then
			bad()
		end
	elseif kind == "number" or kind == "integer" then
		if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
			bad()
		elseif kind == "integer" and value % 1 ~= 0 then
			bad()
		elseif (t.min ~= nil and value < t.min) or (t.max ~= nil and value > t.max) or (t.above ~= nil and value <= t.above) then
			bad()
		end
	elseif kind == "enum" then
		if typeof(value) ~= "string" or table.find(t.values :: { string }, value) == nil then
			bad()
		end
	elseif kind == "ref" then
		if typeof(value) ~= "string" or value == "" then
			bad()
		else
			table.insert(refs, { path = path, target = t.target :: string, id = value })
		end
	elseif kind == "array" then
		if typeof(value) ~= "table" or not isSequence(value :: { [unknown]: unknown }) then
			bad()
			return
		end
		local list = value :: { unknown }
		if t.min ~= nil and #list < t.min then
			report(`{path}: needs at least {t.min} entries, has {#list}`)
		end
		for index, element in list do
			checkValue(t.of :: FieldType, element, `{path}[{index}]`, report, refs)
		end
	elseif kind == "map" then
		if typeof(value) ~= "table" then
			bad()
			return
		end
		for key, element in value :: { [unknown]: unknown } do
			local keyPath = `{path}[{tostring(key)}]`
			checkValue(t.key :: FieldType, key, `{keyPath} key`, report, refs)
			checkValue(t.value :: FieldType, element, keyPath, report, refs)
		end
	elseif kind == "record" then
		if typeof(value) ~= "table" then
			bad()
			return
		end
		checkFields(t.fields :: Fields, value :: { [unknown]: unknown }, path .. ".", report, refs)
	else
		report(`{path}: schema has unknown field kind {kind}`)
	end
end

function checkFields(fields: Fields, value: { [unknown]: unknown }, prefix: string, report: Report, refs: { RefUse })
	for _, name in sortedKeys(fields) do
		local fieldType = fields[name]
		local fieldValue = value[name]
		if fieldValue == nil then
			if not fieldType.optional then
				report(`missing field {prefix}{name} ({describeType(fieldType)})`)
			end
		else
			checkValue(fieldType, fieldValue, prefix .. name, report, refs)
		end
	end
	local extras: { string } = {}
	for key in value do
		if typeof(key) ~= "string" then
			report(`{prefix}[{tostring(key)}]: unexpected {typeof(key)} key`)
		elseif fields[key] == nil then
			table.insert(extras, key)
		end
	end
	table.sort(extras)
	for _, key in extras do
		report(`unknown field {prefix}{key}`)
	end
end

local function deepFreeze(value: unknown): unknown
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, element in value :: { [unknown]: unknown } do
		copy[key] = deepFreeze(element)
	end
	return table.freeze(copy)
end

local function fail(problems: { string }): never
	local lines: { string } = {}
	for index = 1, math.min(#problems, MAX_LISTED) do
		table.insert(lines, "  - " .. problems[index])
	end
	if #problems > MAX_LISTED then
		table.insert(lines, `  ... and {#problems - MAX_LISTED} more`)
	end
	local noun = if #problems == 1 then "problem" else "problems"
	error(`{PREFIX}{#problems} {noun} in Shared/Definitions; the boot stops until they are fixed:\n{table.concat(lines, "\n")}`, 0)
end

-- Reads a Definitions folder: the 18 kind folders (anything else beside them is a problem) and every ModuleScript inside
-- them, required in name order. Returns the entries and the problems found so far; does not validate fields.
function Registry.collect(folder: Instance): ({ Entry }, { string })
	local entries: { Entry } = {}
	local problems: { string } = {}
	local found: { [string]: Instance } = {}
	local children = folder:GetChildren()
	table.sort(children, function(a: Instance, b: Instance): boolean
		return a.Name < b.Name
	end)
	for _, child in children do
		if child.Name == "_Registry" and child:IsA("ModuleScript") then
			continue
		end
		if child:IsA("Folder") and SCHEMAS[child.Name] ~= nil then
			if found[child.Name] then
				table.insert(problems, `{child.Name}: two folders named {child.Name}`)
			else
				found[child.Name] = child
			end
		else
			table.insert(problems, `{child.Name}: unexpected {child.ClassName} beside the definition folders`)
		end
	end
	for _, kind in KINDS do
		local kindFolder: Instance? = found[kind]
		if kindFolder == nil then
			table.insert(problems, `{kind}: missing folder (architecture §4.3)`)
			continue
		end
		local modules = (kindFolder :: Instance):GetChildren()
		table.sort(modules, function(a: Instance, b: Instance): boolean
			return a.Name < b.Name
		end)
		for _, module in modules do
			local label = `{kind}/{module.Name}`
			if not module:IsA("ModuleScript") then
				table.insert(problems, `{label}: a {module.ClassName} is not allowed here; each definition is one ModuleScript`)
				continue
			end
			local ok, result = pcall(require, module)
			if not ok then
				table.insert(problems, `{label}: require failed: {tostring(result)}`)
				continue
			end
			table.insert(entries, { kind = kind, name = module.Name, value = result })
		end
	end
	return entries, problems
end

-- Validates entries against the schemas and returns the frozen index. Any problem (including `earlier` ones from
-- collect) throws one "[Definitions] ..." error listing all of them.
function Registry.validate(entries: { Entry }, earlier: { string }?): Registry
	local problems: { string } = if earlier then table.clone(earlier) else {}
	local byKind: { [string]: { [string]: any } } = {}
	for _, kind in KINDS do
		byKind[kind] = {}
	end
	local exists: { [string]: { [string]: boolean } } = {} -- every module with a schema, valid or not: refs resolve
	-- against these, so one broken definition does not also fail everything that points at it
	for _, kind in KINDS do
		exists[kind] = {}
	end
	local firstUse: { [string]: string } = {}
	type Valid = { kind: string, value: any, label: string, refs: { RefUse } }
	local valid: { Valid } = {}

	-- Pass 1: shape, fields and duplicate Ids.
	for _, entry in entries do
		local label = `{entry.kind}/{entry.name}`
		local function report(message: string)
			table.insert(problems, `{label}: {message}`)
		end
		local schema = SCHEMAS[entry.kind]
		if schema == nil then
			report("no schema for this folder")
			continue
		end
		local before = #problems
		exists[entry.kind][entry.name] = true
		local previous = firstUse[entry.name]
		if previous == label then
			report(`duplicate Id "{entry.name}": two modules named {entry.name} in {entry.kind}`)
		elseif previous ~= nil then
			report(`duplicate Id "{entry.name}", already used by {previous}; Ids are unique across all definition folders`)
		else
			firstUse[entry.name] = label
		end
		local value = entry.value
		if typeof(value) ~= "table" then
			report(`the module must return a table, got {describeValue(value)}`)
			continue
		end
		local refs: { RefUse } = {}
		checkFields(schema.fields, value :: { [unknown]: unknown }, "", report, refs)
		local id = (value :: { [unknown]: unknown }).Id
		if typeof(id) == "string" and id ~= entry.name then
			report(`Id is "{id}"; it must equal the module name`)
		end
		if #problems == before then
			byKind[entry.kind][entry.name] = value
			table.insert(valid, { kind = entry.kind, value = value, label = label, refs = refs })
		end
	end

	-- Pass 2: references, then folder rules on definitions whose fields validated (lookup only returns those).
	local function lookup(kind: string, id: string): any
		local defs = byKind[kind]
		return if defs ~= nil then defs[id] else nil
	end
	for _, item in valid do
		local function report(message: string)
			table.insert(problems, `{item.label}: {message}`)
		end
		for _, use in item.refs do
			if not exists[use.target][use.id] then
				report(`{use.path}: no {use.target} definition "{use.id}"`)
			end
		end
		local check = SCHEMAS[item.kind].check
		if check ~= nil then
			local ok, err = pcall(function()
				check(item.value, report, lookup)
			end)
			if not ok then
				report(`rule check failed: {tostring(err)}`)
			end
		end
	end
	for _, kind in KINDS do
		local checkAll = SCHEMAS[kind].checkAll
		if checkAll == nil then
			continue
		end
		local defs: { any } = {}
		for _, item in valid do
			if item.kind == kind then
				table.insert(defs, item.value)
			end
		end
		local ok, err = pcall(function()
			checkAll(defs, function(id: string, message: string)
				table.insert(problems, `{kind}/{id}: {message}`)
			end)
		end)
		if not ok then
			table.insert(problems, `{kind}: rule check failed: {tostring(err)}`)
		end
	end

	if #problems > 0 then
		fail(problems)
	end

	-- Build the frozen index.
	local index: { [string]: { [string]: Definition } } = {}
	local sorted: { [string]: { Definition } } = {}
	local count = 0
	for _, kind in KINDS do
		local defs: { [string]: Definition } = {}
		local list: { Definition } = {}
		for id, value in byKind[kind] do
			local frozen = deepFreeze(value) :: Definition
			defs[id] = frozen
			table.insert(list, frozen)
			count += 1
		end
		table.sort(list, function(a: Definition, b: Definition): boolean
			return (a.Id :: string) < (b.Id :: string)
		end)
		index[kind] = table.freeze(defs)
		sorted[kind] = table.freeze(list)
	end

	local registry: Registry = {
		count = count,
		get = function(_self: Registry, kind: Kind, id: string): Definition?
			local defs = index[kind]
			if defs == nil then
				error(`{PREFIX}unknown definition folder "{kind}"`, 2)
			end
			return defs[id]
		end,
		all = function(_self: Registry, kind: Kind): { Definition }
			local list = sorted[kind]
			if list == nil then
				error(`{PREFIX}unknown definition folder "{kind}"`, 2)
			end
			return list
		end,
	}
	return table.freeze(registry)
end

-- Collects and validates a Definitions folder.
function Registry.load(folder: Instance): Registry
	local entries, problems = Registry.collect(folder)
	return Registry.validate(entries, problems)
end

local shared: Registry? = nil

-- The registry for Shared/Definitions, loaded on first use (Bootstrap phase 3 on the server). A failed load is not cached.
function Registry.shared(): Registry
	if shared == nil then
		shared = Registry.load(script.Parent :: Instance)
	end
	return shared :: Registry
end

return table.freeze(Registry)
