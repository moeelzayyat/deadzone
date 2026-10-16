--!strict
-- Fodder enemy (A1.6, simulated since A2.3): CONTENT_BIBLE §2 "slow and endless". Numbers are placeholders until the A3
-- balance pass.
return {
	Id = "Walker",
	Tier = "Fodder",
	MaxHealth = 20,
	MoveSpeed = 6,
	Radius = 1.5,
	Attack = { Damage = 5, Range = 3, Cooldown = 1.5, TelegraphTime = 0.4 },
	XP = 1,
	Abilities = {},
	Resistances = {},
	MinProtocol = 1,
	Render = { Model = "", Anims = {}, Scale = 1 },
}
