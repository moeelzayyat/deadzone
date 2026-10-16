--!strict
-- Shared/Types (A1.7): the §6 types and the shared vocabularies. The fixtures below are annotated with the §6 types, so
-- type checking (checkpoint step 2) fails if a type and the architecture drift apart; the tests check the runtime lists.
-- Runs on a clone of Shared.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestRunner = require(script.Parent.Parent.TestRunner)

local Profile = require(ReplicatedStorage.Shared.Types.Profile)
local Run = require(ReplicatedStorage.Shared.Types.Run)
local Match = require(ReplicatedStorage.Shared.Types.Match)
type CommonModule = typeof(require(ReplicatedStorage.Shared.Types.Common))
type PipelineModule = typeof(require(ReplicatedStorage.Shared.Stats.StatPipeline))
type RegistryModule = typeof(require(ReplicatedStorage.Shared.Definitions._Registry))

local shared = ReplicatedStorage.Shared:Clone()
local Common: CommonModule = (require :: any)((shared :: any).Types.Common)
local StatPipeline: PipelineModule = (require :: any)((shared :: any).Stats.StatPipeline)
local Registry: RegistryModule = (require :: any)((shared :: any).Definitions._Registry)

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

local function newProfile(): Profile.PlayerProfile
	local affix: Profile.Affix = { Stat = "Armor", Layer = "Flat", Value = 5 }
	local item: Profile.ItemInstance = {
		InstanceId = "i1",
		DefId = "SampleHelmet",
		Slot = "Helmet",
		Level = 1,
		Rarity = "Common",
		Xp = 0,
		Locked = false,
		AcquiredAt = 0,
		Affixes = { affix },
	}
	return {
		SchemaVersion = 1,
		CreatedAt = 0,
		LastSeenAt = 0,
		Wallet = { Gold = 0, Serum = 0, Samples = 0, Event = {} },
		Classes = { Active = "Sharpshooter", Unlocked = { Sharpshooter = true }, Mastery = {} },
		Inventory = { Items = { i1 = item }, Materials = {}, Consumables = {} },
		Loadouts = { Sharpshooter = { Helmet = "i1" } },
		Skills = {},
		Pets = {
			p1 = {
				InstanceId = "p1",
				DefId = "MedicalDrone",
				Rarity = "Common",
				Level = 1,
				Xp = 0,
				Locked = false,
				AcquiredAt = 0,
			},
		},
		EquippedPetIds = { "p1" },
		Campaign = { HighestZone = 1, Stages = { SampleMission = { BestProtocol = 0, BestTime = 0, Clears = {} } } },
		Codex = {},
		Quests = { SampleQuest = { Progress = 0, Claimed = false, Period = 0 } },
		Raids = { SampleRaid = { Clears = 0, BestTime = 0 } },
		BattlePass = { SeasonId = "SampleSeason", XP = 0, Premium = false, Claimed = {} },
		RedeemedCodes = {},
		Transactions = {},
		Stats = { Runs = 0, Extractions = 0, Kills = 0, BestProtocol = 0, PlayDays = 0 },
		Settings = { MusicVolume = 1, SfxVolume = 1, CameraShake = true, DamageNumbers = true },
	}
end

local function newRunState(): Run.RunPlayerState
	local computed = StatPipeline.compute(BASES, {})
	return {
		Level = 1,
		XP = 0,
		XPRequired = 10,
		Health = computed.MaxHealth,
		MaxHealth = computed.MaxHealth,
		Downed = false,
		Weapons = { TacticalRifle = 1 },
		Passives = {},
		Evolutions = {},
		WeaponSlots = computed.WeaponSlots,
		PassiveSlots = computed.PassiveSlots,
		PendingPicks = 0,
		ActiveOfferId = nil,
		IsSelecting = false,
		Kills = 0,
		DamageDealt = 0,
		DamageTaken = 0,
		ElitesKilled = 0,
		LastInputSeq = 0,
		ComputedStats = computed,
	}
end

local function newMatch(): Match.MatchState
	return {
		MatchId = "m1",
		MissionId = "SampleMission",
		DifficultyId = "Normal",
		Participants = { 1 },
		Connected = { [1] = true },
		Clock = 0,
		Paused = false,
		PauseReason = nil,
		Protocol = 1,
		ProtocolProgress = 0,
		Wave = 0,
		Elites = 0,
		Extraction = { Open = false, ClosesAt = nil, Votes = {}, WindowIndex = 0 },
		Boss = nil,
		Outcome = "InProgress",
		RewardMultiplier = 1,
	}
end

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("§6 types", function()
		it("a schema v1 profile, a run state and a match state build from the types", function()
			local profile = newProfile()
			expect(profile.SchemaVersion).toBe(1)
			expect(profile.Wallet.Serum).toBe(0)
			expect(profile.Loadouts.Sharpshooter.Helmet).toBe("i1")
			local run = newRunState()
			expect(run.MaxHealth).toBe(100)
			expect(run.WeaponSlots).toBe(4)
			expect(run.ComputedStats.CritMult).toBe(1.5)
			expect(newMatch().Outcome).toBe("InProgress")
		end)

		it("type modules hold no runtime values", function()
			for _, name in { "Profile", "Run", "Match" } do
				local module = (require :: any)((shared :: any).Types[name])
				expect(`{name} {next(module) == nil} {table.isfrozen(module)}`).toBe(`{name} true true`)
			end
		end)
	end)

	describe("vocabularies", function()
		it("each list is frozen and has no duplicates", function()
			for name, list in Common :: any do
				local seen = {}
				for _, value in list do
					expect(`{name} {value} {seen[value] == nil}`).toBe(`{name} {value} true`)
					seen[value] = true
				end
				expect(table.isfrozen(list)).toBe(true)
			end
		end)

		it("_Registry uses the same lists, not copies", function()
			local schemas = (Registry :: any).SCHEMAS
			expect(schemas.Weapons.fields.Archetype.values).toBe(Common.ARCHETYPES)
			expect(schemas.Weapons.fields.Rarity.values).toBe(Common.RARITY)
			expect(schemas.Weapons.fields.Targeting.values).toBe(Common.TARGETING)
			expect(schemas.Weapons.fields.Tags.of.values).toBe(Common.DAMAGE_TAGS)
			expect(schemas.Items.fields.Slot.values).toBe(Common.SLOTS)
			expect(schemas.Eggs.fields.Price.fields.Currency.values).toBe(Common.CURRENCIES)
			local StatRegistry = (require :: any)((shared :: any).Stats.StatRegistry)
			expect(schemas.Passives.fields.Stat.values).toBe(StatRegistry.IDS)
			expect(schemas.Pets.fields.Stat.values).toBe(StatRegistry.PET_STATS)
		end)
	end)
end
