--!strict
-- Definitions/_Registry (A1.6, A1.7, A2.2 Arenas): folder layout, schemas, duplicate Ids, references and folder rules.
-- Runs on a clone of Shared, so edits to _Registry or the samples are picked up in Edit mode too (Studio caches require
-- per ModuleScript) and the real folders are never touched. Bad definitions are built by mutating copies of the samples.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestRunner = require(script.Parent.Parent.TestRunner)

-- The installed module only lends its type (a type-level require does not run); every test uses the clone below.
type RegistryModule = typeof(require(ReplicatedStorage.Shared.Definitions._Registry))
type Entry = { kind: string, name: string, value: unknown }

local shared = ReplicatedStorage.Shared:Clone()
local Registry: RegistryModule = (require :: any)((shared :: any).Definitions._Registry)

local function freshDefinitions(): Instance
	return (shared :: any).Definitions:Clone()
end

local function deepCopy(value: unknown): unknown
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, element in value :: { [unknown]: unknown } do
		copy[key] = deepCopy(element)
	end
	return copy
end

-- The shipped samples as plain, mutable entries.
local function sampleEntries(): { Entry }
	local entries, problems = Registry.collect(freshDefinitions())
	assert(#problems == 0, table.concat(problems, "\n"))
	local copies: { Entry } = {}
	for _, entry in entries do
		table.insert(copies, { kind = entry.kind, name = entry.name, value = deepCopy(entry.value) })
	end
	return copies
end

local function find(entries: { Entry }, kind: string, name: string): { [string]: any }
	for _, entry in entries do
		if entry.kind == kind and entry.name == name then
			return entry.value :: { [string]: any }
		end
	end
	error(`no sample {kind}/{name}`)
end

-- Validates the samples after `mutate` changes them; returns a function for expect(...).toThrow.
local function withChange(mutate: (entries: { Entry }) -> ()): () -> ()
	return function()
		local entries = sampleEntries()
		mutate(entries)
		Registry.validate(entries)
	end
end

local function change(kind: string, name: string, edit: (def: { [string]: any }) -> ()): () -> ()
	return withChange(function(entries: { Entry })
		edit(find(entries, kind, name))
	end)
end

local function errorOf(fn: () -> ()): string
	local ok, err = pcall(function()
		fn()
	end)
	assert(not ok, "expected an error")
	return tostring(err)
end

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("folders and schemas", function()
		it("has one schema for each of the 19 definition folders (§4.3 plus Arenas, D-024)", function()
			expect(Registry.KINDS).toEqual({
				"Classes",
				"Weapons",
				"Passives",
				"Evolutions",
				"Enemies",
				"Protocol",
				"Missions",
				"Zones",
				"Arenas",
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
			})
			local count = 0
			for kind in Registry.SCHEMAS do
				count += 1
				expect(table.find(Registry.KINDS, kind :: any) ~= nil).toBe(true)
			end
			expect(count).toBe(19)
		end)

		it("matches the Studio folders one to one", function()
			local names: { string } = {}
			for _, child in ReplicatedStorage.Shared.Definitions:GetChildren() do
				if child:IsA("Folder") then
					table.insert(names, child.Name)
				end
			end
			table.sort(names)
			local kinds: { string } = {}
			for _, kind in Registry.KINDS do
				table.insert(kinds, kind)
			end
			table.sort(kinds)
			expect(names).toEqual(kinds)
		end)
	end)

	describe("shipped definitions", function()
		it("load clean with at least one sample per folder", function()
			local registry = Registry.load(freshDefinitions())
			expect(registry.count).toBe(20)
			for _, kind in Registry.KINDS do
				expect(#registry:all(kind :: any) >= 1).toBe(true)
			end
		end)

		it("are indexed by Id, sorted, and deep-frozen", function()
			local registry = Registry.load(freshDefinitions())
			local rifle = registry:get("Weapons", "TacticalRifle")
			expect(rifle ~= nil).toBe(true)
			expect((rifle :: any).MaxLevel).toBe(8)
			expect(registry:get("Weapons", "NoSuchWeapon")).toBeNil()
			local enemies = registry:all("Enemies")
			expect({ enemies[1].Id, enemies[2].Id }).toEqual({ "MutantAlpha", "Walker" })
			expect(function()
				(rifle :: any).MaxLevel = 99
			end).toThrow()
			expect(function()
				(rifle :: any).Damage[1] = 99
			end).toThrow()
			expect(function()
				registry:get("Gadgets" :: any, "X")
			end).toThrow("unknown definition folder")
		end)

		it("shared() validates Shared/Definitions once and returns the same registry", function()
			local first = Registry.shared()
			expect(Registry.shared()).toBe(first)
			expect(first.count).toBe(20)
		end)
	end)

	describe("folder layout", function()
		it("fails on a missing definition folder", function()
			local defs = freshDefinitions()
			local seasons = defs:FindFirstChild("Seasons") :: Instance
			seasons:Destroy()
			expect(function()
				Registry.load(defs)
			end).toThrow("Seasons: missing folder")
		end)

		it("fails on a duplicated module (two modules with the same Id in one folder)", function()
			local defs = freshDefinitions()
			local walker = (defs:FindFirstChild("Enemies") :: Instance):FindFirstChild("Walker") :: Instance
			walker:Clone().Parent = walker.Parent
			expect(function()
				Registry.load(defs)
			end).toThrow('Enemies/Walker: duplicate Id "Walker": two modules named Walker in Enemies')
		end)

		it("fails on anything that is not a ModuleScript inside a folder, or beside the folders", function()
			local defs = freshDefinitions()
			local stray = Instance.new("Folder")
			stray.Name = "Extra"
			stray.Parent = defs:FindFirstChild("Weapons")
			local loose = Instance.new("StringValue")
			loose.Name = "Notes"
			loose.Parent = defs
			local message = errorOf(function()
				Registry.load(defs)
			end)
			expect(string.find(message, "Weapons/Extra: a Folder is not allowed here", 1, true) ~= nil).toBe(true)
			expect(string.find(message, "Notes: unexpected StringValue", 1, true) ~= nil).toBe(true)
		end)
	end)

	describe("fields", function()
		it("names a missing field with its path and type", function()
			expect(change("Enemies", "Walker", function(def)
				def.Attack.TelegraphTime = nil
			end)).toThrow("Enemies/Walker: missing field Attack.TelegraphTime (number ≥ 0)")
		end)

		it("rejects wrong types, NaN, non-integers and out-of-range numbers", function()
			expect(change("Enemies", "Walker", function(def)
				def.MaxHealth = "20"
			end)).toThrow('MaxHealth: expected number > 0, got string "20"')
			expect(change("Enemies", "Walker", function(def)
				def.MoveSpeed = 0 / 0
			end)).toThrow("MoveSpeed: expected number ≥ 0, got number")
			expect(change("Enemies", "Walker", function(def)
				def.MinProtocol = 1.5
			end)).toThrow("MinProtocol: expected integer 1–7, got number 1.5")
			expect(change("Enemies", "Walker", function(def)
				def.MinProtocol = 8
			end)).toThrow("MinProtocol: expected integer 1–7, got number 8")
		end)

		it("rejects unknown fields (typos)", function()
			expect(change("Enemies", "Walker", function(def)
				def.MaxHealt = 20
			end)).toThrow("Enemies/Walker: unknown field MaxHealt")
		end)

		it("rejects values outside an enum", function()
			expect(change("Enemies", "Walker", function(def)
				def.Tier = "Boss2"
			end)).toThrow('Tier: expected one of Fodder, Elite, Boss, got string "Boss2"')
		end)

		it("checks arrays, maps and asset ids", function()
			expect(change("Enemies", "Walker", function(def)
				def.Abilities = { [2] = "Bite" }
			end)).toThrow("Abilities: expected array of non-empty string")
			expect(change("Enemies", "Walker", function(def)
				def.Resistances = { Fire = 1.5 }
			end)).toThrow("Resistances[Fire]: expected number 0–1, got number 1.5")
			expect(change("Enemies", "Walker", function(def)
				def.Resistances = { Laser = 0.5 }
			end)).toThrow("Resistances[Laser] key: expected one of Ballistic")
			expect(change("Weapons", "TacticalRifle", function(def)
				def.Icon = "my-icon"
			end)).toThrow('Icon: expected asset ("" or "rbxassetid://<number>")')
		end)

		it("requires the Id to equal the module name", function()
			expect(change("Zones", "EvacuationStreets", function(def)
				def.Id = "Downtown"
			end)).toThrow('Zones/EvacuationStreets: Id is "Downtown"; it must equal the module name')
		end)

		it("rejects a module that does not return a table", function()
			expect(withChange(function(entries: { Entry })
				table.insert(entries, { kind = "Items", name = "Broken", value = "oops" })
			end)).toThrow('Items/Broken: the module must return a table, got string "oops"')
		end)
	end)

	describe("Ids and references", function()
		it("rejects the same Id in two folders", function()
			expect(withChange(function(entries: { Entry })
				local copy = deepCopy(find(entries, "Items", "SampleHelmet")) :: { [string]: any }
				copy.Id = "Walker"
				table.insert(entries, { kind = "Items", name = "Walker", value = copy })
			end)).toThrow('Items/Walker: duplicate Id "Walker", already used by Enemies/Walker')
		end)

		it("rejects a reference to a definition that does not exist", function()
			expect(change("Classes", "Sharpshooter", function(def)
				def.StarterWeaponId = "NoSuchGun"
			end)).toThrow('Classes/Sharpshooter: StarterWeaponId: no Weapons definition "NoSuchGun"')
			expect(change("Missions", "EvacStreets_01", function(def)
				def.EnemyPool = { "Walker", "Ghoul" }
			end)).toThrow('EnemyPool[2]: no Enemies definition "Ghoul"')
		end)

		it("reports every problem in one error", function()
			local message = errorOf(withChange(function(entries: { Entry })
				find(entries, "Enemies", "Walker").XP = nil
				find(entries, "Zones", "EvacuationStreets").Order = 0
			end))
			expect(string.find(message, "[Definitions] 2 problems in Shared/Definitions", 1, true) ~= nil).toBe(true)
			expect(string.find(message, "Enemies/Walker: missing field XP", 1, true) ~= nil).toBe(true)
			expect(string.find(message, "Zones/EvacuationStreets: Order: expected integer ≥ 1", 1, true) ~= nil).toBe(true)
		end)
	end)

	describe("folder rules", function()
		it("Weapons: per-level arrays match MaxLevel, and listed evolutions evolve this weapon", function()
			expect(change("Weapons", "TacticalRifle", function(def)
				table.remove(def.Damage)
			end)).toThrow("Damage: has 7 levels, MaxLevel is 8")
			expect(change("Evolutions", "StormRifle", function(def)
				def.WeaponLevel = 9
			end)).toThrow("WeaponLevel 9 is above TacticalRifle.MaxLevel 8")
			expect(change("Weapons", "TacticalRifle", function(def)
				def.EvolutionIds = {}
			end)).toThrow("TacticalRifle.EvolutionIds does not list StormRifle")
		end)

		it("Enemies: a boss telegraphs for at least 0.6 s", function()
			expect(change("Enemies", "MutantAlpha", function(def)
				def.Attack.TelegraphTime = 0.5
			end)).toThrow("a boss telegraphs for at least 0.6 s")
		end)

		it("Missions: BossId is a Boss and the pool has no bosses", function()
			expect(change("Missions", "EvacStreets_01", function(def)
				def.BossId = "Walker"
			end)).toThrow("BossId: Walker is a Fodder enemy, not a Boss")
			expect(change("Missions", "EvacStreets_01", function(def)
				def.EnemyPool = { "MutantAlpha" }
			end)).toThrow("EnemyPool[1]: MutantAlpha is a Boss")
		end)

		it("Loot and Eggs: weights sum to 1", function()
			expect(change("Loot", "Zone1_Normal", function(def)
				def.Entries[1].Weight = 0.9
			end)).toThrow("Entries: weights sum to 0.9; they must sum to 1")
			expect(change("Eggs", "SampleEgg", function(def)
				table.insert(def.Odds, { PetId = "MedicalDrone", Weight = 0.5 })
			end)).toThrow("Odds: weights sum to 1.5")
		end)

		it("Skills: prerequisites are acyclic", function()
			expect(withChange(function(entries: { Entry })
				local a = find(entries, "Skills", "SampleSkill")
				local b = deepCopy(a) :: { [string]: any }
				b.Id = "SampleSkillB"
				b.Prereqs = { "SampleSkill" }
				a.Prereqs = { "SampleSkillB" }
				table.insert(entries, { kind = "Skills", name = "SampleSkillB", value = b })
			end)).toThrow("Prereqs: cycle SampleSkill → SampleSkillB → SampleSkill")
		end)

		it("Protocol and Zones: Level and Order are unique", function()
			expect(withChange(function(entries: { Entry })
				local copy = deepCopy(find(entries, "Protocol", "Contact")) :: { [string]: any }
				copy.Id = "Spread"
				table.insert(entries, { kind = "Protocol", name = "Spread", value = copy })
			end)).toThrow("Protocol/Spread: Level 1 is already used by Contact")
		end)

		it("Classes, Forge, Raids and Shop: field combinations", function()
			expect(change("Classes", "Sharpshooter", function(def)
				def.Unlock = { Kind = "Currency", Value = 500 }
			end)).toThrow("Unlock: Kind Currency needs Value and Currency")
			expect(change("Forge", "SampleRecipe", function(def)
				def.OutputItemId = nil
			end)).toThrow("OutputItemId: a Craft recipe needs an output item")
			expect(change("Raids", "SampleRaid", function(def)
				def.MinPlayers = 13
			end)).toThrow("MinPlayers: expected integer 1–12")
			expect(change("Shop", "SampleCosmetic", function(def)
				def.Price = { Currency = "Robux", Amount = 99 }
			end)).toThrow("ProductId: a Robux price needs the developer product or pass id")
		end)

		it("Passives, Skills and Pets: the stat must take the layer (STATS.md allowed layers)", function()
			expect(change("Passives", "VoltageCore", function(def)
				def.Layer = "Flat"
			end)).toThrow("Layer: AttackSpeedPct does not take layer Flat (allowed: AdditivePct)")
			expect(change("Skills", "SampleSkill", function(def)
				def.Effect = { Stat = "WeaponSlots", Layer = "AdditivePct", PerRank = 0.1 }
			end)).toThrow("Effect.Layer: WeaponSlots does not take layer AdditivePct (allowed: Flat)")
			expect(change("Pets", "MedicalDrone", function(def)
				def.Layer = "Flat"
			end)).toThrow("Layer: HealingPct does not take layer Flat (allowed: AdditivePct)")
		end)

		it("Arenas: the grid rules hold and the zone exists", function()
			expect(change("Arenas", "TestArena", function(def)
				def.Rows[1] = string.rep(".", 76)
			end)).toThrow("Arenas/TestArena: the outer ring must be blocked")
			expect(change("Arenas", "TestArena", function(def)
				def.Rows[40] = string.sub(def.Rows[40], 1, 75)
			end)).toThrow("Arenas/TestArena: Rows[40]: 75 cells, Width is 76")
			expect(change("Arenas", "TestArena", function(def)
				def.PlayerSpawn = { X = 1, Z = 1 }
			end)).toThrow("Arenas/TestArena: PlayerSpawn (1,1) must be an open cell")
			expect(change("Arenas", "TestArena", function(def)
				def.ZoneId = "Atlantis"
			end)).toThrow('Arenas/TestArena: ZoneId: no Zones definition "Atlantis"')
			expect(change("Arenas", "TestArena", function(def)
				def.CellSize = 0
			end)).toThrow("Arenas/TestArena: CellSize: expected number > 0")
		end)

		it("Quests: the event must be in the event catalog", function()
			expect(change("Quests", "SampleDailyQuest", function(def)
				def.Event = "ZombieHugged"
			end)).toThrow('Event: expected one of')
		end)
	end)
end
