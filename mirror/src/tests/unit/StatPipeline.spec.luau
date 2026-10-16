--!strict
-- Stats/StatPipeline (A1.7): every docs/STATS.md row alone per layer, its Min and Max, all layers combined, zero and
-- negative inputs, input checks and preview parity. Expected values are worked out by hand, not by the formula.
-- Runs on a clone of Shared (Studio caches require per ModuleScript in Edit mode).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestRunner = require(script.Parent.Parent.TestRunner)

type PipelineModule = typeof(require(ReplicatedStorage.Shared.Stats.StatPipeline))
type RegistryModule = typeof(require(ReplicatedStorage.Shared.Stats.StatRegistry))
type Modifier = { Stat: any, Layer: any, Value: number, Source: string }

local shared = ReplicatedStorage.Shared:Clone()
local StatPipeline: PipelineModule = (require :: any)((shared :: any).Stats.StatPipeline)
local StatRegistry: RegistryModule = (require :: any)((shared :: any).Stats.StatRegistry)

-- Bases for the stats whose base comes from a class or weapon definition.
local BASES: { [string]: number } = {
	MaxHealth = 100,
	Armor = 20,
	MoveSpeed = 16,
	CritChance = 0.05,
	ProjectileCount = 1,
	Pierce = 0,
	DodgeDistance = 10,
	DodgeIFrames = 0.3,
}

local function mod(stat: string, layer: string, value: number, source: string?): Modifier
	return { Stat = stat, Layer = layer, Value = value, Source = source or "Test" }
end

local function compute(modifiers: { Modifier }, bases: { [string]: number }?): { [string]: number }
	return StatPipeline.compute(bases or BASES, modifiers :: any) :: any
end

-- One row per stat: with no modifiers, one modifier per allowed layer, and a modifier that drives it past Min and Max.
type Case = { layer: string, value: number, expected: number }
type Row = { none: number, layers: { Case }, low: Case, high: Case }
local EXPECTED: { [string]: Row } = {
	MaxHealth = {
		none = 100,
		layers = {
			{ layer = "Flat", value = 25, expected = 125 },
			{ layer = "AdditivePct", value = 0.2, expected = 120 },
			{ layer = "Multiplier", value = 1.5, expected = 150 },
		},
		low = { layer = "Flat", value = -500, expected = 1 },
		high = { layer = "Flat", value = 200000, expected = 100000 },
	},
	HealthRegen = {
		none = 0,
		layers = {
			{ layer = "Flat", value = 2, expected = 2 },
			{ layer = "AdditivePct", value = 0.5, expected = 0 }, -- scales Base + Flat, which is 0
		},
		low = { layer = "Flat", value = -5, expected = 0 },
		high = { layer = "Flat", value = 80, expected = 50 },
	},
	Armor = {
		none = 20,
		layers = {
			{ layer = "Flat", value = 30, expected = 50 },
			{ layer = "AdditivePct", value = 0.5, expected = 30 },
		},
		low = { layer = "Flat", value = -50, expected = 0 },
		high = { layer = "Flat", value = 1000, expected = 300 },
	},
	MoveSpeed = {
		none = 16,
		layers = {
			{ layer = "Flat", value = 4, expected = 20 },
			{ layer = "AdditivePct", value = 0.25, expected = 20 },
		},
		low = { layer = "AdditivePct", value = -0.9, expected = 8 },
		high = { layer = "Flat", value = 40, expected = 32 },
	},
	DamagePct = {
		none = 0,
		layers = {
			{ layer = "AdditivePct", value = 0.3, expected = 0.3 },
			{ layer = "Multiplier", value = 1.5, expected = 0.5 },
		},
		low = { layer = "AdditivePct", value = -2, expected = -0.9 },
		high = { layer = "Multiplier", value = 10, expected = 5 },
	},
	AttackSpeedPct = {
		none = 0,
		layers = { { layer = "AdditivePct", value = 0.4, expected = 0.4 } },
		low = { layer = "AdditivePct", value = -0.5, expected = 0 },
		high = { layer = "AdditivePct", value = 3, expected = 1.5 },
	},
	CooldownReduction = {
		none = 0,
		layers = { { layer = "AdditivePct", value = 0.25, expected = 0.25 } },
		low = { layer = "AdditivePct", value = -0.1, expected = 0 },
		high = { layer = "AdditivePct", value = 0.9, expected = 0.6 },
	},
	CritChance = {
		none = 0.05,
		layers = {
			{ layer = "Flat", value = 0.05, expected = 0.1 },
			{ layer = "AdditivePct", value = 1, expected = 0.1 },
		},
		low = { layer = "Flat", value = -1, expected = 0 },
		high = { layer = "Flat", value = 2, expected = 1 },
	},
	CritMult = {
		none = 1.5,
		layers = { { layer = "Flat", value = 0.5, expected = 2 } },
		low = { layer = "Flat", value = -1, expected = 1.5 },
		high = { layer = "Flat", value = 5, expected = 4 },
	},
	ProjectileCount = {
		none = 1,
		layers = { { layer = "Flat", value = 2, expected = 3 } },
		low = { layer = "Flat", value = -3, expected = 1 },
		high = { layer = "Flat", value = 20, expected = 12 },
	},
	Pierce = {
		none = 0,
		layers = { { layer = "Flat", value = 2, expected = 2 } },
		low = { layer = "Flat", value = -1, expected = 0 },
		high = { layer = "Flat", value = 15, expected = 10 },
	},
	AreaSize = {
		none = 0,
		layers = { { layer = "AdditivePct", value = 0.3, expected = 0.3 } },
		low = { layer = "AdditivePct", value = -1, expected = -0.5 },
		high = { layer = "AdditivePct", value = 5, expected = 2 },
	},
	Range = {
		none = 0,
		layers = { { layer = "AdditivePct", value = 0.2, expected = 0.2 } },
		low = { layer = "AdditivePct", value = -0.8, expected = -0.5 },
		high = { layer = "AdditivePct", value = 3, expected = 1 },
	},
	PickupRadius = {
		none = 6,
		layers = {
			{ layer = "Flat", value = 4, expected = 10 },
			{ layer = "AdditivePct", value = 0.5, expected = 9 },
		},
		low = { layer = "Flat", value = -10, expected = 2 },
		high = { layer = "Flat", value = 100, expected = 40 },
	},
	XPGainPct = {
		none = 0,
		layers = { { layer = "AdditivePct", value = 0.1, expected = 0.1 } },
		low = { layer = "AdditivePct", value = -0.5, expected = 0 },
		high = { layer = "AdditivePct", value = 5, expected = 2 },
	},
	Luck = {
		none = 0,
		layers = { { layer = "AdditivePct", value = 0.25, expected = 0.25 } },
		low = { layer = "AdditivePct", value = -1, expected = 0 },
		high = { layer = "AdditivePct", value = 2, expected = 1 },
	},
	GoldFindPct = {
		none = 0,
		layers = { { layer = "AdditivePct", value = 0.5, expected = 0.5 } },
		low = { layer = "AdditivePct", value = -1, expected = 0 },
		high = { layer = "AdditivePct", value = 3, expected = 2 },
	},
	DodgeDistance = {
		none = 10,
		layers = {
			{ layer = "Flat", value = 2, expected = 12 },
			{ layer = "AdditivePct", value = 0.5, expected = 15 },
		},
		low = { layer = "Flat", value = -10, expected = 4 },
		high = { layer = "Flat", value = 30, expected = 24 },
	},
	DodgeIFrames = {
		none = 0.3,
		layers = { { layer = "Flat", value = 0.1, expected = 0.4 } },
		low = { layer = "Flat", value = -1, expected = 0 },
		high = { layer = "Flat", value = 1, expected = 0.6 },
	},
	SignatureDurationPct = {
		none = 0,
		layers = { { layer = "AdditivePct", value = 0.5, expected = 0.5 } },
		low = { layer = "AdditivePct", value = -0.2, expected = 0 },
		high = { layer = "AdditivePct", value = 2, expected = 1 },
	},
	HealingPct = {
		none = 0,
		layers = { { layer = "AdditivePct", value = 0.3, expected = 0.3 } },
		low = { layer = "AdditivePct", value = -1, expected = 0 },
		high = { layer = "AdditivePct", value = 4, expected = 1 },
	},
	WeaponSlots = {
		none = 4,
		layers = { { layer = "Flat", value = 1, expected = 5 } },
		low = { layer = "Flat", value = -5, expected = 1 },
		high = { layer = "Flat", value = 5, expected = 6 },
	},
	PassiveSlots = {
		none = 4,
		layers = { { layer = "Flat", value = 1, expected = 5 } },
		low = { layer = "Flat", value = -5, expected = 1 },
		high = { layer = "Flat", value = 5, expected = 6 },
	},
	Rerolls = {
		none = 0,
		layers = { { layer = "Flat", value = 2, expected = 2 } },
		low = { layer = "Flat", value = -1, expected = 0 },
		high = { layer = "Flat", value = 9, expected = 3 },
	},
	Banishes = {
		none = 0,
		layers = { { layer = "Flat", value = 2, expected = 2 } },
		low = { layer = "Flat", value = -1, expected = 0 },
		high = { layer = "Flat", value = 9, expected = 3 },
	},
}

local EPSILON = 1e-9

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("STATS.md coverage", function()
		it("has an expected-value row for every stat, and no row for a stat that does not exist", function()
			local missing, extra = {}, {}
			for _, id in StatRegistry.IDS do
				if EXPECTED[id] == nil then
					table.insert(missing, id)
				end
			end
			for id in EXPECTED do
				if StatRegistry.BY_ID[id] == nil then
					table.insert(extra, id)
				end
			end
			expect(#StatRegistry.IDS).toBe(25)
			expect(table.concat(missing, ",")).toBe("")
			expect(table.concat(extra, ",")).toBe("")
		end)

		it("tests every allowed layer of every stat, and only allowed layers", function()
			for _, statRow in StatRegistry.ROWS do
				local tested = {}
				for _, case in EXPECTED[statRow.Id].layers do
					table.insert(tested, case.layer)
				end
				expect(`{statRow.Id}: {table.concat(tested, ",")}`).toBe(`{statRow.Id}: {table.concat(statRow.Layers, ",")}`)
			end
		end)

		it("computes a block with exactly the 25 stats, frozen", function()
			local block = compute({})
			local count = 0
			for id in block do
				expect(StatRegistry.BY_ID[id] ~= nil).toBe(true)
				count += 1
			end
			expect(count).toBe(25)
			expect(table.isfrozen(block)).toBe(true)
		end)
	end)

	describe("each stat, each layer alone", function()
		for _, statRow in StatRegistry.ROWS do
			local id = statRow.Id
			local row = EXPECTED[id]
			it(`{id}: no modifiers gives the base`, function()
				expect(compute({})[id]).toBeCloseTo(row.none, EPSILON)
			end)
			for _, case in row.layers do
				it(`{id}: {case.layer} {case.value} → {case.expected}`, function()
					expect(compute({ mod(id, case.layer, case.value) })[id]).toBeCloseTo(case.expected, EPSILON)
					local base = if statRow.BaseSource == "Fixed" then nil else BASES[id]
					expect(StatPipeline.stat(id :: any, base, { mod(id, case.layer, case.value) } :: any)).toBeCloseTo(
						case.expected,
						EPSILON
					)
				end)
			end
		end
	end)

	describe("caps", function()
		for _, statRow in StatRegistry.ROWS do
			local id = statRow.Id
			local row = EXPECTED[id]
			it(`{id}: clamps at Min {statRow.Min} and Max {statRow.Max}`, function()
				expect(row.low.expected).toBe(statRow.Min)
				expect(row.high.expected).toBe(statRow.Max)
				expect(compute({ mod(id, row.low.layer, row.low.value) })[id]).toBe(statRow.Min)
				expect(compute({ mod(id, row.high.layer, row.high.value) })[id]).toBe(statRow.Max)
			end)
		end

		it("CritChance caps at 100%, CooldownReduction at 60%, MoveSpeed at 32 (§7.3 examples)", function()
			local block = compute({
				mod("CritChance", "AdditivePct", 50),
				mod("CooldownReduction", "AdditivePct", 0.35),
				mod("CooldownReduction", "AdditivePct", 0.35),
				mod("MoveSpeed", "AdditivePct", 1),
			})
			expect(block.CritChance).toBe(1)
			expect(block.CooldownReduction).toBe(0.6)
			expect(block.MoveSpeed).toBe(32)
		end)
	end)

	describe("all layers combined", function()
		it("MaxHealth: (100 + 20 + 30) × (1 + 0.1 + 0.2) × 1.2 × 1.5 = 351", function()
			local block = compute({
				mod("MaxHealth", "Flat", 20),
				mod("MaxHealth", "Flat", 30),
				mod("MaxHealth", "AdditivePct", 0.1),
				mod("MaxHealth", "AdditivePct", 0.2),
				mod("MaxHealth", "Multiplier", 1.2),
				mod("MaxHealth", "Multiplier", 1.5),
			})
			expect(block.MaxHealth).toBeCloseTo(351, EPSILON)
		end)

		it("DamagePct: (1 + 0.25 + 0.25) × 2 × 1.2 − 1 = 2.6", function()
			local block = compute({
				mod("DamagePct", "AdditivePct", 0.25),
				mod("DamagePct", "AdditivePct", 0.25),
				mod("DamagePct", "Multiplier", 2),
				mod("DamagePct", "Multiplier", 1.2),
			})
			expect(block.DamagePct).toBeCloseTo(2.6, EPSILON)
		end)

		it("AdditivePct is summed and applied once, not compounded", function()
			local block = compute({ mod("MaxHealth", "AdditivePct", 0.5), mod("MaxHealth", "AdditivePct", 0.5) })
			expect(block.MaxHealth).toBeCloseTo(200, EPSILON) -- compounding would give 225
		end)

		it("modifiers of one stat never change another", function()
			local block = compute({ mod("MaxHealth", "Flat", 50), mod("DamagePct", "AdditivePct", 1) })
			expect(block.Armor).toBe(20)
			expect(block.AttackSpeedPct).toBe(0)
			expect(block.MaxHealth).toBe(150)
			expect(block.DamagePct).toBe(1)
		end)

		it("the result does not depend on modifier order", function()
			local list = {
				mod("MaxHealth", "Multiplier", 1.5),
				mod("MaxHealth", "Flat", 10),
				mod("MaxHealth", "AdditivePct", 0.3),
			}
			local reversed = { list[3], list[2], list[1] }
			expect(compute(reversed).MaxHealth).toBeCloseTo(compute(list).MaxHealth, EPSILON)
			expect(compute(list).MaxHealth).toBeCloseTo(110 * 1.3 * 1.5, EPSILON)
		end)
	end)

	describe("zero and negative inputs", function()
		it("zero and negative bases clamp to Min", function()
			local zero = table.clone(BASES)
			zero.MaxHealth, zero.MoveSpeed, zero.ProjectileCount = 0, 0, 0
			local negative = table.clone(BASES)
			negative.MaxHealth, negative.Armor, negative.CritChance = -50, -10, -0.5
			expect(compute({}, zero).MaxHealth).toBe(1)
			expect(compute({}, zero).MoveSpeed).toBe(8)
			expect(compute({}, zero).ProjectileCount).toBe(1)
			expect(compute({}, negative).MaxHealth).toBe(1)
			expect(compute({}, negative).Armor).toBe(0)
			expect(compute({}, negative).CritChance).toBe(0)
		end)

		it("zero and negative multipliers clamp to Min", function()
			expect(compute({ mod("MaxHealth", "Multiplier", 0) }).MaxHealth).toBe(1)
			expect(compute({ mod("MaxHealth", "Multiplier", -2) }).MaxHealth).toBe(1)
			expect(compute({ mod("DamagePct", "Multiplier", 0) }).DamagePct).toBe(-0.9)
		end)

		it("AdditivePct below -100% clamps to Min instead of flipping sign", function()
			expect(compute({ mod("MaxHealth", "AdditivePct", -3) }).MaxHealth).toBe(1)
			expect(compute({ mod("DamagePct", "AdditivePct", -1.5) }).DamagePct).toBe(-0.9)
		end)

		it("zero-valued modifiers change nothing", function()
			local block = compute({ mod("MaxHealth", "Flat", 0), mod("MaxHealth", "AdditivePct", 0), mod("Luck", "AdditivePct", 0) })
			expect(block.MaxHealth).toBe(100)
			expect(block.Luck).toBe(0)
		end)

		it("never returns NaN, even when finite inputs overflow", function()
			local block = compute({
				mod("MaxHealth", "Flat", 1e308),
				mod("MaxHealth", "Flat", 1e308),
				mod("MaxHealth", "Multiplier", 0),
				mod("Armor", "Flat", 1e308),
				mod("Armor", "Flat", 1e308),
			})
			for id, value in block do
				expect(`{id} {value == value}`).toBe(`{id} true`)
			end
			expect(block.MaxHealth).toBe(1) -- inf × 0 → Min
			expect(block.Armor).toBe(300) -- inf → Max
		end)
	end)

	describe("input checks", function()
		it("rejects unknown stats and layers a stat does not take", function()
			expect(function()
				compute({ mod("Strength", "Flat", 1) })
			end).toThrow("unknown stat Strength")
			expect(function()
				compute({ mod("AttackSpeedPct", "Multiplier", 2) })
			end).toThrow("AttackSpeedPct does not take layer Multiplier")
			expect(function()
				compute({ mod("CritMult", "AdditivePct", 0.5) })
			end).toThrow("CritMult does not take layer AdditivePct")
		end)

		it("rejects NaN and infinite values and bases", function()
			expect(function()
				compute({ mod("MaxHealth", "Flat", 0 / 0) })
			end).toThrow("not a finite number")
			expect(function()
				compute({ mod("MaxHealth", "Multiplier", math.huge) })
			end).toThrow("not a finite number")
			local bad = table.clone(BASES)
			bad.MoveSpeed = -math.huge
			expect(function()
				compute({}, bad)
			end).toThrow("base of MoveSpeed is not a finite number")
		end)

		it("rejects fractional values on whole-number stats", function()
			expect(function()
				compute({ mod("ProjectileCount", "Flat", 1.5) })
			end).toThrow("ProjectileCount is a whole number")
			local bad = table.clone(BASES)
			bad.Pierce = 0.5
			expect(function()
				compute({}, bad)
			end).toThrow("Pierce is a whole number")
		end)

		it("needs every Class/Weapon base, and refuses bases for fixed or unknown stats", function()
			local missing: { [string]: number } = {}
			for id, base in BASES do
				if id ~= "MaxHealth" then
					missing[id] = base
				end
			end
			expect(function()
				compute({}, missing)
			end).toThrow("MaxHealth needs its base from the Class definition")
			local fixed = table.clone(BASES)
			fixed.CritMult = 2
			expect(function()
				compute({}, fixed)
			end).toThrow("the base of CritMult is fixed at 1.5")
			local unknown = table.clone(BASES)
			unknown.Strength = 3
			expect(function()
				compute({}, unknown)
			end).toThrow("base given for unknown stat Strength")
		end)

		it("rejects a modifier without a Source", function()
			expect(function()
				compute({ mod("MaxHealth", "Flat", 1, "") })
			end).toThrow("modifier has no Source")
		end)
	end)

	describe("preview (Forge parity)", function()
		local modifiers = {
			mod("MaxHealth", "Flat", 25, "Item:helmet"),
			mod("Armor", "Flat", 10, "Item:helmet"),
			mod("DamagePct", "AdditivePct", 0.2, "Passive:Adrenaline"),
			mod("DamagePct", "Multiplier", 1.25, "Class:Sharpshooter"),
		}

		it("with no change, Before and After both equal compute", function()
			local preview = StatPipeline.preview(BASES, modifiers :: any, {})
			expect(preview.Before).toEqual(StatPipeline.compute(BASES, modifiers :: any))
			expect(preview.After).toEqual(preview.Before)
			expect((next(preview.Delta))).toBeNil()
		end)

		it("After equals compute with the change applied", function()
			local add = { mod("MaxHealth", "Flat", 40, "Item:chest"), mod("CritChance", "Flat", 0.05, "Item:chest") }
			local preview = StatPipeline.preview(BASES, modifiers :: any, { Add = add :: any, RemoveSources = { "Item:helmet" } })
			local expected = { modifiers[3], modifiers[4], add[1], add[2] }
			expect(preview.Before).toEqual(StatPipeline.compute(BASES, modifiers :: any))
			expect(preview.After).toEqual(StatPipeline.compute(BASES, expected :: any))
			expect(preview.After.MaxHealth).toBe(140)
			expect(preview.After.Armor).toBe(20)
		end)

		it("Delta lists only the stats that changed", function()
			local preview = StatPipeline.preview(BASES, modifiers :: any, { RemoveSources = { "Item:helmet" } })
			expect(preview.Delta).toEqual({ MaxHealth = -25, Armor = -10 })
			expect(table.isfrozen(preview.Delta)).toBe(true)
		end)
	end)
end
