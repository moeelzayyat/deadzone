--!strict
-- Stats/DamageCalculator (A1.7): the §7.3 damage formula with stats from StatPipeline, each damage tag against a
-- resistance table, zero and negative inputs, and armor mitigation with its 75% cap. Runs on a clone of Shared.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestRunner = require(script.Parent.Parent.TestRunner)

type CalculatorModule = typeof(require(ReplicatedStorage.Shared.Stats.DamageCalculator))
type PipelineModule = typeof(require(ReplicatedStorage.Shared.Stats.StatPipeline))

local shared = ReplicatedStorage.Shared:Clone()
local DamageCalculator: CalculatorModule = (require :: any)((shared :: any).Stats.DamageCalculator)
local StatPipeline: PipelineModule = (require :: any)((shared :: any).Stats.StatPipeline)

local BASES: { [string]: number } = {
	MaxHealth = 100,
	Armor = 0,
	MoveSpeed = 16,
	CritChance = 0.05,
	ProjectileCount = 1,
	Pierce = 0,
	DodgeDistance = 10,
	DodgeIFrames = 0.3,
}

local function stats(modifiers: { { [string]: any } }?): any
	return StatPipeline.compute(BASES, (modifiers or {}) :: any)
end

local function hit(fields: { [string]: any }): any
	local value: { [string]: any } = { WeaponDamage = 10, Crit = false, Tag = "Ballistic", DifficultyMult = 1 }
	for key, field in fields do
		value[key] = field
	end
	return value
end

local EPSILON = 1e-9

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("damage formula", function()
		it("with no modifiers, damage is the weapon damage", function()
			expect(DamageCalculator.damage(stats(), hit({}))).toBe(10)
		end)

		it("multiplies every term: 20 × 1.25 × 1.2 × 2.0 (crit) × 0.5 (Fire) × 1.5 = 45", function()
			local attacker = stats({
				{ Stat = "DamagePct", Layer = "Multiplier", Value = 1.25, Source = "Class:Sample" }, -- ClassDamageMult
				{ Stat = "DamagePct", Layer = "AdditivePct", Value = 0.2, Source = "Passive:Adrenaline" },
				{ Stat = "CritMult", Layer = "Flat", Value = 0.5, Source = "Item:trinket" },
			})
			expect(attacker.DamagePct).toBeCloseTo(0.5, EPSILON)
			expect(attacker.CritMult).toBe(2)
			local damage = DamageCalculator.damage(
				attacker,
				hit({ WeaponDamage = 20, Crit = true, Tag = "Fire", Resistances = { Fire = 0.5 }, DifficultyMult = 1.5 })
			)
			expect(damage).toBeCloseTo(45, EPSILON)
		end)

		it("CritMult applies only on a crit", function()
			local attacker = stats({ { Stat = "CritMult", Layer = "Flat", Value = 1, Source = "Test" } })
			expect(DamageCalculator.damage(attacker, hit({ Crit = false }))).toBe(10)
			expect(DamageCalculator.damage(attacker, hit({ Crit = true }))).toBe(25)
		end)

		it("DamagePct at its -90% floor still deals 10%", function()
			local attacker = stats({ { Stat = "DamagePct", Layer = "AdditivePct", Value = -5, Source = "Test" } })
			expect(DamageCalculator.damage(attacker, hit({ WeaponDamage = 100 }))).toBeCloseTo(10, EPSILON)
		end)
	end)

	describe("damage tags and resistances", function()
		local resistances = { Ballistic = 1, Blade = 0.75, Fire = 0.5, Shock = 0.25, Explosive = 0 } -- Toxic missing
		local expected = { Ballistic = 100, Blade = 75, Fire = 50, Shock = 25, Explosive = 0, Toxic = 100 }
		for _, tag in { "Ballistic", "Blade", "Fire", "Shock", "Explosive", "Toxic" } do
			it(`{tag} against the resistance table → {expected[tag]}`, function()
				local damage = DamageCalculator.damage(stats(), hit({ WeaponDamage = 100, Tag = tag, Resistances = resistances }))
				expect(damage).toBeCloseTo(expected[tag], EPSILON)
			end)
		end

		it("a missing table or tag is 1.0, out-of-range resistances clamp to 0–1", function()
			expect(DamageCalculator.resistance(nil, "Fire")).toBe(1)
			expect(DamageCalculator.resistance({}, "Fire")).toBe(1)
			expect(DamageCalculator.resistance({ Fire = 1.5 }, "Fire")).toBe(1)
			expect(DamageCalculator.resistance({ Fire = -0.2 }, "Fire")).toBe(0)
		end)

		it("rejects an unknown damage tag and a NaN resistance", function()
			expect(function()
				DamageCalculator.damage(stats(), hit({ Tag = "Cold" }))
			end).toThrow("unknown damage tag Cold")
			expect(function()
				DamageCalculator.resistance({ Fire = 0 / 0 }, "Fire")
			end).toThrow("not a finite number")
		end)
	end)

	describe("zero and negative inputs", function()
		it("zero or negative weapon damage and difficulty give 0, never negative", function()
			expect(DamageCalculator.damage(stats(), hit({ WeaponDamage = 0 }))).toBe(0)
			expect(DamageCalculator.damage(stats(), hit({ WeaponDamage = -10 }))).toBe(0)
			expect(DamageCalculator.damage(stats(), hit({ DifficultyMult = 0 }))).toBe(0)
			expect(DamageCalculator.damage(stats(), hit({ DifficultyMult = -1 }))).toBe(0)
		end)

		it("rejects NaN and infinite inputs", function()
			expect(function()
				DamageCalculator.damage(stats(), hit({ WeaponDamage = 0 / 0 }))
			end).toThrow("WeaponDamage is not a finite number")
			expect(function()
				DamageCalculator.damage(stats(), hit({ DifficultyMult = math.huge }))
			end).toThrow("DifficultyMult is not a finite number")
			expect(function()
				DamageCalculator.mitigate(math.huge, 0)
			end).toThrow("incoming damage is not a finite number")
		end)
	end)

	describe("armor", function()
		it("reduction = Armor / (Armor + 100)", function()
			expect(DamageCalculator.armorReduction(0)).toBe(0)
			expect(DamageCalculator.armorReduction(100)).toBe(0.5)
			expect(DamageCalculator.armorReduction(300)).toBe(0.75)
			expect(DamageCalculator.mitigate(100, 0)).toBe(100)
			expect(DamageCalculator.mitigate(100, 100)).toBe(50)
			expect(DamageCalculator.mitigate(100, 300)).toBe(25)
		end)

		it("caps the reduction at 75% of incoming", function()
			expect(DamageCalculator.armorReduction(1000)).toBe(0.75)
			expect(DamageCalculator.mitigate(100, 1e6)).toBe(25)
		end)

		it("negative armor counts as 0; negative incoming damage is 0", function()
			expect(DamageCalculator.mitigate(100, -50)).toBe(100)
			expect(DamageCalculator.mitigate(-10, 50)).toBe(0)
		end)

		it("the Armor stat cap (300) is exactly the 75% reduction cap", function()
			local attacker = stats({ { Stat = "Armor", Layer = "Flat", Value = 5000, Source = "Test" } })
			expect(attacker.Armor).toBe(300)
			expect(DamageCalculator.mitigate(80, attacker.Armor)).toBe(20)
		end)
	end)
end
