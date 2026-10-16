--!strict
-- Events/Catalog (architecture §5.3, docs/EVENTS.md): every bus event, its only publisher and its typed payload.
-- EVENTS.md and this module change together. Each event has a runtime schema (checked by EventBus on publish) and an
-- exported payload type of the same name for consumers: bus:subscribe("EnemyKilled", function(p: Catalog.EnemyKilled) ... end).
-- Field rules: strings are non-empty, numbers are finite, integers are whole; arrays are sequences 1..n; payloads carry
-- IDs, numbers and Vector3 values, never Instances. Every field is required and no other field is allowed.
-- Shapes of events whose "since" substage has not been built yet are provisional; that substage settles them here and in EVENTS.md.

-- Publisher identities: the ten §5.1 domains, plus Bootstrap and the Definitions registry (§5.2 phase 3).
export type PublisherId =
	"Platform"
	| "Telemetry"
	| "Data"
	| "Economy"
	| "Combat"
	| "Encounter"
	| "Progression"
	| "Social"
	| "Facilities"
	| "LiveOps"
	| "Bootstrap"
	| "Definitions"

export type FieldKind = "string" | "number" | "integer" | "boolean" | "Vector3" | "enum" | "array" | "map" | "record" | "oneOf"

export type FieldType = {
	kind: FieldKind,
	values: { string }?, -- enum: the allowed strings
	of: FieldType?, -- array: element type
	key: FieldType?, -- map: key type (string or integer)
	value: FieldType?, -- map: value type
	fields: { [string]: FieldType }?, -- record: field types (all required, no extras)
	options: { FieldType }?, -- oneOf: any one of these scalar types
}

export type Fields = { [string]: FieldType }

export type EventDef = { publisher: PublisherId, since: string, fields: Fields }

export type Catalog = { [string]: EventDef }

-- Payload types (one per event). Integer fields are typed number; the schema below is what enforces "whole".
export type Reward = { Kind: string, Id: string, Amount: number }

export type BootCompleted = { Phases: number, Services: { string } }
export type DefinitionsValidated = { Count: number }
export type PlayerProfileLoaded = { UserId: number, SchemaVersion: number, IsNew: boolean }
export type PlayerProfileReleased = { UserId: number }
export type MatchStarted = { MatchId: string, MissionId: string, DifficultyId: string, Participants: { number } }
export type EnemySpawned = { MatchId: string, EnemyId: number, DefId: string, Elite: boolean }
export type EnemyKilled = {
	MatchId: string,
	KillerUserId: number,
	EnemyId: number,
	DefId: string,
	ProtocolLevel: number,
	Position: Vector3,
}
export type PlayerDamaged = { MatchId: string, UserId: number, Amount: number, SourceDefId: string }
export type PlayerDowned = { MatchId: string, UserId: number }
export type XPCollected = { MatchId: string, UserId: number, Amount: number }
export type PlayerLeveledUp = { MatchId: string, UserId: number, NewLevel: number }
export type UpgradeOffered = { MatchId: string, UserId: number, OfferId: string, CardIds: { string } }
export type UpgradeChosen = { MatchId: string, UserId: number, OfferId: string, CardIndex: number, ResultId: string }
export type WeaponEvolved = { MatchId: string, UserId: number, EvolutionId: string }
export type ProtocolChanged = { MatchId: string, NewLevel: number, MutationIds: { string } }
export type ExtractionWindowOpened = { MatchId: string, WindowIndex: number, ClosesAt: number }
export type ExtractionVoted = { MatchId: string, UserId: number, Choice: "Hold" | "Extract" }
export type ExtractionResolved = { MatchId: string, WindowIndex: number, Result: "Hold" | "Extract" }
export type BossPhaseChanged = { MatchId: string, BossId: string, Phase: number }
export type BossDefeated = { MatchId: string, BossId: string, Participants: { number } }
export type MissionEnded = {
	MatchId: string,
	Outcome: string,
	ProtocolReached: number,
	Multiplier: number,
	Participants: { number },
	DurationSec: number,
}
export type RewardsGranted = { UserId: number, ClaimId: string, Rewards: { Reward } }
export type RewardsPended = { UserId: number, ClaimId: string }
export type CurrencyChanged = { UserId: number, Currency: string, Delta: number, Reason: string }
export type ItemGranted = { UserId: number, InstanceId: string, DefId: string, Source: string }
export type ItemEquipped = { UserId: number, InstanceId: string, Slot: string }
export type ItemEnhanced = { UserId: number, InstanceId: string, NewLevel: number }
export type SkillPurchased = { UserId: number, NodeId: string, Rank: number }
export type ChestOpened = { UserId: number, ChestId: string, Results: { string } }
export type EggHatched = { UserId: number, EggId: string, PetDefId: string, Rarity: string }
export type QuestCompleted = { UserId: number, QuestId: string }
export type CodexDiscovered = { UserId: number, DefId: string }
export type PartyFormed = { PartyId: string, Members: { number } }
export type RaidCompleted = { RaidId: string, Participants: { number }, Contributions: { [number]: number } }
export type PurchaseGranted = { UserId: number, ProductId: number, ReceiptId: string }
export type CodeRedeemed = { UserId: number, Code: string }
export type FeatureFlagChanged = { Flag: string, Value: boolean | number | string }

export type EventName =
	"BootCompleted"
	| "DefinitionsValidated"
	| "PlayerProfileLoaded"
	| "PlayerProfileReleased"
	| "MatchStarted"
	| "EnemySpawned"
	| "EnemyKilled"
	| "PlayerDamaged"
	| "PlayerDowned"
	| "XPCollected"
	| "PlayerLeveledUp"
	| "UpgradeOffered"
	| "UpgradeChosen"
	| "WeaponEvolved"
	| "ProtocolChanged"
	| "ExtractionWindowOpened"
	| "ExtractionVoted"
	| "ExtractionResolved"
	| "BossPhaseChanged"
	| "BossDefeated"
	| "MissionEnded"
	| "RewardsGranted"
	| "RewardsPended"
	| "CurrencyChanged"
	| "ItemGranted"
	| "ItemEquipped"
	| "ItemEnhanced"
	| "SkillPurchased"
	| "ChestOpened"
	| "EggHatched"
	| "QuestCompleted"
	| "CodexDiscovered"
	| "PartyFormed"
	| "RaidCompleted"
	| "PurchaseGranted"
	| "CodeRedeemed"
	| "FeatureFlagChanged"

local PUBLISHERS: { PublisherId } = table.freeze({
	"Platform",
	"Telemetry",
	"Data",
	"Economy",
	"Combat",
	"Encounter",
	"Progression",
	"Social",
	"Facilities",
	"LiveOps",
	"Bootstrap",
	"Definitions",
} :: { PublisherId })

local KINDS: { [string]: boolean } = {}
for _, kind in { "string", "number", "integer", "boolean", "Vector3", "enum", "array", "map", "record", "oneOf" } do
	KINDS[kind] = true
end

local SCALARS: { [string]: boolean } = { string = true, number = true, integer = true, boolean = true, Vector3 = true }

-- Field type constructors.
local function scalar(kind: FieldKind): FieldType
	local ft: FieldType = { kind = kind }
	return table.freeze(ft)
end

local T = {
	string = scalar("string"),
	number = scalar("number"),
	integer = scalar("integer"),
	boolean = scalar("boolean"),
	Vector3 = scalar("Vector3"),
}

local function enum(values: { string }): FieldType
	local ft: FieldType = { kind = "enum", values = table.freeze(values) }
	return table.freeze(ft)
end

local function array(of: FieldType): FieldType
	local ft: FieldType = { kind = "array", of = of }
	return table.freeze(ft)
end

local function map(key: FieldType, value: FieldType): FieldType
	local ft: FieldType = { kind = "map", key = key, value = value }
	return table.freeze(ft)
end

local function record(fields: Fields): FieldType
	local ft: FieldType = { kind = "record", fields = table.freeze(fields) }
	return table.freeze(ft)
end

local function oneOf(options: { FieldType }): FieldType
	local ft: FieldType = { kind = "oneOf", options = table.freeze(options) }
	return table.freeze(ft)
end

local function event(publisher: PublisherId, since: string, fields: Fields): EventDef
	local def: EventDef = { publisher = publisher, since = since, fields = table.freeze(fields) }
	return table.freeze(def)
end

local UserIds = array(T.integer)
local Choice = enum({ "Hold", "Extract" })
local RewardType = record({ Kind = T.string, Id = T.string, Amount = T.integer })

local EVENTS: Catalog = {
	BootCompleted = event("Bootstrap", "A1.5", { Phases = T.integer, Services = array(T.string) }),
	DefinitionsValidated = event("Definitions", "A1.6", { Count = T.integer }),
	PlayerProfileLoaded = event("Data", "A5.5", { UserId = T.integer, SchemaVersion = T.integer, IsNew = T.boolean }),
	PlayerProfileReleased = event("Data", "A5.5", { UserId = T.integer }),
	MatchStarted = event(
		"Encounter",
		"A3.1",
		{ MatchId = T.string, MissionId = T.string, DifficultyId = T.string, Participants = UserIds }
	),
	EnemySpawned = event("Encounter", "A2.3", { MatchId = T.string, EnemyId = T.integer, DefId = T.string, Elite = T.boolean }),
	EnemyKilled = event("Encounter", "A2.5", {
		MatchId = T.string,
		KillerUserId = T.integer,
		EnemyId = T.integer,
		DefId = T.string,
		ProtocolLevel = T.integer,
		Position = T.Vector3,
	}),
	PlayerDamaged = event("Combat", "A2.3", { MatchId = T.string, UserId = T.integer, Amount = T.number, SourceDefId = T.string }),
	PlayerDowned = event("Combat", "A4.7", { MatchId = T.string, UserId = T.integer }),
	XPCollected = event("Encounter", "A3.2", { MatchId = T.string, UserId = T.integer, Amount = T.number }),
	PlayerLeveledUp = event("Encounter", "A3.2", { MatchId = T.string, UserId = T.integer, NewLevel = T.integer }),
	UpgradeOffered = event(
		"Encounter",
		"A3.3",
		{ MatchId = T.string, UserId = T.integer, OfferId = T.string, CardIds = array(T.string) }
	),
	UpgradeChosen = event("Encounter", "A3.3", {
		MatchId = T.string,
		UserId = T.integer,
		OfferId = T.string,
		CardIndex = T.integer,
		ResultId = T.string,
	}),
	WeaponEvolved = event("Encounter", "A3.4", { MatchId = T.string, UserId = T.integer, EvolutionId = T.string }),
	ProtocolChanged = event("Encounter", "A3.5", { MatchId = T.string, NewLevel = T.integer, MutationIds = array(T.string) }),
	ExtractionWindowOpened = event("Encounter", "A3.6", { MatchId = T.string, WindowIndex = T.integer, ClosesAt = T.number }),
	ExtractionVoted = event("Encounter", "A3.6", { MatchId = T.string, UserId = T.integer, Choice = Choice }),
	ExtractionResolved = event("Encounter", "A3.6", { MatchId = T.string, WindowIndex = T.integer, Result = Choice }),
	BossPhaseChanged = event("Encounter", "A4.6", { MatchId = T.string, BossId = T.string, Phase = T.integer }),
	BossDefeated = event("Encounter", "A4.6", { MatchId = T.string, BossId = T.string, Participants = UserIds }),
	MissionEnded = event("Encounter", "A3.6", {
		MatchId = T.string,
		Outcome = T.string,
		ProtocolReached = T.integer,
		Multiplier = T.number,
		Participants = UserIds,
		DurationSec = T.number,
	}),
	RewardsGranted = event("Progression", "A5.6", { UserId = T.integer, ClaimId = T.string, Rewards = array(RewardType) }),
	RewardsPended = event("Progression", "A5.6", { UserId = T.integer, ClaimId = T.string }),
	CurrencyChanged = event(
		"Economy",
		"B1.4",
		{ UserId = T.integer, Currency = T.string, Delta = T.integer, Reason = T.string }
	),
	ItemGranted = event("Economy", "B1.1", { UserId = T.integer, InstanceId = T.string, DefId = T.string, Source = T.string }),
	ItemEquipped = event("Economy", "B1.1", { UserId = T.integer, InstanceId = T.string, Slot = T.string }),
	ItemEnhanced = event("Facilities", "B1.7", { UserId = T.integer, InstanceId = T.string, NewLevel = T.integer }),
	SkillPurchased = event("Progression", "B1.3", { UserId = T.integer, NodeId = T.string, Rank = T.integer }),
	ChestOpened = event("Economy", "B1.5", { UserId = T.integer, ChestId = T.string, Results = array(T.string) }),
	EggHatched = event(
		"Facilities",
		"B3.1",
		{ UserId = T.integer, EggId = T.string, PetDefId = T.string, Rarity = T.string }
	),
	QuestCompleted = event("Progression", "B2.6", { UserId = T.integer, QuestId = T.string }),
	CodexDiscovered = event("Progression", "B1.6", { UserId = T.integer, DefId = T.string }),
	PartyFormed = event("Social", "A5.1", { PartyId = T.string, Members = UserIds }),
	RaidCompleted = event(
		"LiveOps",
		"B3.7",
		{ RaidId = T.string, Participants = UserIds, Contributions = map(T.integer, T.number) }
	),
	PurchaseGranted = event("LiveOps", "L1.3", { UserId = T.integer, ProductId = T.integer, ReceiptId = T.string }),
	CodeRedeemed = event("LiveOps", "L1.4", { UserId = T.integer, Code = T.string }),
	FeatureFlagChanged = event(
		"Platform",
		"A1.8",
		{ Flag = T.string, Value = oneOf({ T.boolean, T.number, T.string }) }
	),
}

local CatalogModule = {
	PUBLISHERS = PUBLISHERS,
	T = table.freeze(T),
	enum = enum,
	array = array,
	map = map,
	record = record,
	oneOf = oneOf,
	event = event,
	EVENTS = table.freeze(EVENTS),
}

local PUBLISHER_SET: { [string]: boolean } = {}
for _, id in PUBLISHERS do
	PUBLISHER_SET[id] = true
end

function CatalogModule.isPublisher(id: string): boolean
	return PUBLISHER_SET[id] == true
end

local function checkType(fieldType: unknown, path: string): string?
	if typeof(fieldType) ~= "table" then
		return `{path}: field type must be a table`
	end
	local ft = fieldType :: FieldType
	local kind = ft.kind
	if typeof(kind) ~= "string" or not KINDS[kind] then
		return `{path}: unknown field kind {tostring(kind)}`
	end
	if kind == "enum" then
		local values = ft.values
		if typeof(values) ~= "table" or #(values :: { string }) == 0 then
			return `{path}: enum needs at least one value`
		end
		for _, v in values :: { string } do
			if typeof(v) ~= "string" or v == "" then
				return `{path}: enum values must be non-empty strings`
			end
		end
	elseif kind == "array" then
		return checkType(ft.of, path .. "[]")
	elseif kind == "map" then
		local key = ft.key
		if typeof(key) ~= "table" or (key.kind ~= "string" and key.kind ~= "integer") then
			return `{path}: map keys must be string or integer`
		end
		return checkType(ft.value, path .. "{}")
	elseif kind == "record" then
		local fields = ft.fields
		if typeof(fields) ~= "table" or next(fields :: Fields) == nil then
			return `{path}: record needs at least one field`
		end
		for name, sub in fields :: Fields do
			local err = checkType(sub, `{path}.{name}`)
			if err then
				return err
			end
		end
	elseif kind == "oneOf" then
		local options = ft.options
		if typeof(options) ~= "table" or #(options :: { FieldType }) < 2 then
			return `{path}: oneOf needs at least two options`
		end
		for _, option in options :: { FieldType } do
			if typeof(option) ~= "table" or not SCALARS[option.kind] then
				return `{path}: oneOf options must be scalar types`
			end
		end
	end
	return nil
end

-- Returns an error message for a malformed catalog, or nil. EventBus.new refuses a catalog that fails this.
function CatalogModule.check(catalog: unknown): string?
	if typeof(catalog) ~= "table" then
		return "catalog must be a table"
	end
	local count = 0
	for name, def in catalog :: { [unknown]: unknown } do
		count += 1
		if typeof(name) ~= "string" or not string.match(name, "^%u%w*$") then
			return `event name {tostring(name)} must be PascalCase letters and digits`
		end
		if typeof(def) ~= "table" then
			return `{name}: definition must be a table`
		end
		local d = def :: EventDef
		if typeof(d.publisher) ~= "string" or not PUBLISHER_SET[d.publisher] then
			return `{name}: unknown publisher {tostring(d.publisher)}`
		end
		if typeof(d.since) ~= "string" or d.since == "" then
			return `{name}: since must name a substage`
		end
		if typeof(d.fields) ~= "table" or next(d.fields) == nil then
			return `{name}: needs at least one field`
		end
		for field, ft in d.fields do
			if typeof(field) ~= "string" or not string.match(field, "^%u%w*$") then
				return `{name}: field name {tostring(field)} must be PascalCase letters and digits`
			end
			local err = checkType(ft, `{name}.{field}`)
			if err then
				return err
			end
		end
	end
	if count == 0 then
		return "catalog has no events"
	end
	return nil
end

-- The shipped catalog must be valid; a bad definition fails at require time (and with it the boot).
local problem = CatalogModule.check(EVENTS)
if problem then
	error("[Events] catalog: " .. problem, 0)
end

return table.freeze(CatalogModule)
