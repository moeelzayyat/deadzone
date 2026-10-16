--!strict
-- Types/Profile (architecture §6.1, schema v1): the persistent player profile. PlayerProfile's fields are copied from §6.1
-- exactly (Serum per D-011); changing one is a schema change (STOP AND ASK). Never save Instances, functions, enemy
-- references or run state.
-- §6.1 names sub-types it does not define. ItemInstance is §11. The others are provisional lean shapes built from the
-- architecture text; each is settled by the substage named beside it, with a decision log entry (D-020). Nothing is
-- persisted before A5, so settling them loses no data.

local Common = require(script.Parent.Common)
local StatRegistry = require(script.Parent.Parent.Stats.StatRegistry)

export type Rarity = Common.Rarity
export type Slot = Common.Slot

-- Provisional (B1.1): one equipment roll. STATS.md: equipment is Flat or AdditivePct per affix.
export type Affix = { Stat: StatRegistry.StatId, Layer: "Flat" | "AdditivePct", Value: number }

-- §11.
export type ItemInstance = {
	InstanceId: string,
	DefId: string,
	Slot: Slot,
	Level: number,
	Rarity: Rarity,
	Xp: number,
	Locked: boolean,
	AcquiredAt: number,
	Affixes: { Affix }?,
}

-- Provisional (B1.1): the equipped item InstanceIds of one class, per slot.
export type Loadout = {
	Weapon: string?,
	Helmet: string?,
	Chest: string?,
	Legs: string?,
	Trinket: string?,
}

-- Provisional (B3.1): §13 pets have a rarity (it caps the bonus) and level with mission XP.
export type PetInstance = {
	InstanceId: string,
	DefId: string,
	Rarity: Rarity,
	Level: number,
	Xp: number,
	Locked: boolean,
	AcquiredAt: number,
}

-- Provisional (B2.5): §6.1 "best protocol, best time, clears per difficulty".
export type StageRecord = {
	BestProtocol: number,
	BestTime: number, -- seconds; 0 until the first clear
	Clears: { [string]: number }, -- DifficultyId -> clears
}

-- Provisional (B2.6): progress of one quest in its current daily/weekly period (§18).
export type QuestState = {
	Progress: number,
	Claimed: boolean,
	Period: number, -- the period index the progress belongs to; a new period starts fresh
}

-- Provisional (B3.7).
export type RaidRecord = {
	Clears: number,
	BestTime: number, -- seconds; 0 until the first clear
}

-- Provisional (A5): per-player options; the settings UI settles the list.
export type PlayerSettings = {
	MusicVolume: number, -- 0–1
	SfxVolume: number, -- 0–1
	CameraShake: boolean,
	DamageNumbers: boolean,
}

-- §6.1, schema v1.
export type PlayerProfile = {
	SchemaVersion: number,
	CreatedAt: number,
	LastSeenAt: number,

	Wallet: {
		Gold: number,
		Serum: number,
		Samples: number,
		Event: { [string]: number },
	},

	Classes: {
		Active: string,
		Unlocked: { [string]: boolean },
		Mastery: { [string]: number }, -- class XP
	},

	Inventory: {
		Items: { [string]: ItemInstance }, -- keyed by InstanceId
		Materials: { [string]: number },
		Consumables: { [string]: number },
	},

	Loadouts: { [string]: Loadout }, -- keyed by ClassId
	Skills: { [string]: number }, -- NodeId -> rank
	Pets: { [string]: PetInstance },
	EquippedPetIds: { string },

	Campaign: {
		HighestZone: number,
		Stages: { [string]: StageRecord }, -- best protocol, best time, clears per difficulty
	},

	Codex: { [string]: boolean }, -- discovered DefinitionIds
	Quests: { [string]: QuestState },
	Raids: { [string]: RaidRecord },
	BattlePass: { SeasonId: string, XP: number, Premium: boolean, Claimed: { [string]: boolean } },
	RedeemedCodes: { [string]: boolean },
	Transactions: { [string]: number }, -- ClaimId -> timestamp (idempotency; pruned after 30 days)

	Stats: { Runs: number, Extractions: number, Kills: number, BestProtocol: number, PlayDays: number },
	Settings: PlayerSettings,
}

-- Types only; nothing to run.
return table.freeze({})
