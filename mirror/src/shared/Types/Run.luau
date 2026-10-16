--!strict
-- Types/Run (architecture §6.2): one player's state inside a mission. Discarded at mission end; never persisted.

local StatRegistry = require(script.Parent.Parent.Stats.StatRegistry)

export type StatBlock = StatRegistry.StatBlock

export type RunPlayerState = {
	Level: number,
	XP: number,
	XPRequired: number,
	Health: number,
	MaxHealth: number,
	Downed: boolean,
	Weapons: { [string]: number },
	Passives: { [string]: number },
	Evolutions: { [string]: boolean },
	WeaponSlots: number,
	PassiveSlots: number,
	PendingPicks: number,
	ActiveOfferId: string?,
	IsSelecting: boolean,
	Kills: number,
	DamageDealt: number,
	DamageTaken: number,
	ElitesKilled: number,
	LastInputSeq: number,
	ComputedStats: StatBlock, -- recomputed on every change by StatPipeline
}

-- Types only; nothing to run.
return table.freeze({})
