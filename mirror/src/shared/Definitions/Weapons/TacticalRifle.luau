--!strict
-- Sample weapon (A1.6): the Sharpshooter starter weapon (CONTENT_BIBLE §1, §7). Numbers are placeholders until A2.5/A2.7.
return {
	Id = "TacticalRifle",
	DisplayName = "Tactical Rifle",
	Archetype = "Projectile",
	Rarity = "Common",
	Damage = { 10, 12, 14, 16, 18, 20, 22, 25 },
	Cooldown = { 0.5, 0.5, 0.45, 0.45, 0.4, 0.4, 0.35, 0.35 },
	Range = 60,
	MaxLevel = 8,
	MaxTargets = 1,
	Targeting = "Nearest",
	Tags = { "Ballistic" },
	ClassTags = { "Rifle" },
	EvolutionIds = { "StormRifle" },
	Render = { Fx = "", Sfx = "" },
	Icon = "",
}
