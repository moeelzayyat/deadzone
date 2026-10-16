--!strict
-- Sample class (A1.6). Names from CONTENT_BIBLE §1; numbers, ability ids and the weapon tag are placeholders until A4.1.
return {
	Id = "Sharpshooter",
	DisplayName = "Sharpshooter",
	Role = "Ranged precision",
	Base = { Health = 100, Speed = 16, DamageMult = 1, Armor = 0 },
	StarterWeaponId = "TacticalRifle",
	PrimaryAbilityId = "TacticalRifleShot",
	DodgeAbilityId = "CombatRoll",
	SignatureAbilityId = "PiercingRound",
	Unlock = { Kind = "Free" },
	WeaponTags = { "Rifle" },
	Icon = "",
	Model = "",
}
