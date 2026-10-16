--!strict
-- Types/Common (architecture §4.3, §6, §7.4, §10.1, §11): vocabularies shared by the §6 types, the definitions and the
-- stat modules. Each list exists once, here; `_Registry`, `StatPipeline` and `DamageCalculator` read it from here.

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" -- ART_BIBLE rarity tokens
export type Archetype =
	"Projectile"
	| "Spread"
	| "Pierce"
	| "Explosive"
	| "Zone"
	| "Orbit"
	| "Chain"
	| "Boomerang"
	| "Deployable"
	| "Aura" -- §7.4
export type Targeting = "Nearest" | "Random" | "LowestHealth" | "HighestHealth" | "Elite" | "Cursor" -- §7.4
export type DamageTag = "Ballistic" | "Blade" | "Fire" | "Shock" | "Explosive" | "Toxic" -- STATS.md damage formula
export type Currency = "Gold" | "Serum" | "Samples" -- §6.1 Wallet: the gameplay currencies (Event currencies are keyed)
export type Slot = "Weapon" | "Helmet" | "Chest" | "Legs" | "Trinket" -- §11 ItemInstance.Slot

-- Each list is built through a function typed with its union, so a misspelled entry fails type checking, and is handed
-- out as a frozen { string } (Luau arrays are invariant, so a { Rarity } would not pass where { string } is expected).
local function rarities(...: Rarity): { string }
	local list: { string } = { ... }
	return table.freeze(list)
end
local function archetypes(...: Archetype): { string }
	local list: { string } = { ... }
	return table.freeze(list)
end
local function targetings(...: Targeting): { string }
	local list: { string } = { ... }
	return table.freeze(list)
end
local function damageTags(...: DamageTag): { string }
	local list: { string } = { ... }
	return table.freeze(list)
end
local function currencies(...: Currency): { string }
	local list: { string } = { ... }
	return table.freeze(list)
end
local function slots(...: Slot): { string }
	local list: { string } = { ... }
	return table.freeze(list)
end

return table.freeze({
	RARITY = rarities("Common", "Uncommon", "Rare", "Epic", "Legendary"),
	ARCHETYPES = archetypes(
		"Projectile",
		"Spread",
		"Pierce",
		"Explosive",
		"Zone",
		"Orbit",
		"Chain",
		"Boomerang",
		"Deployable",
		"Aura"
	),
	TARGETING = targetings("Nearest", "Random", "LowestHealth", "HighestHealth", "Elite", "Cursor"),
	DAMAGE_TAGS = damageTags("Ballistic", "Blade", "Fire", "Shock", "Explosive", "Toxic"),
	CURRENCIES = currencies("Gold", "Serum", "Samples"),
	SLOTS = slots("Weapon", "Helmet", "Chest", "Legs", "Trinket"),
})
