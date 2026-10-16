--!strict
-- Sample boss (A1.6): the Evacuation Streets boss the sample mission needs (architecture §9.2, CONTENT_BIBLE §2).
-- Numbers and ability ids are placeholders until A4.6.
return {
	Id = "MutantAlpha",
	Tier = "Boss",
	MaxHealth = 3000,
	MoveSpeed = 10,
	Radius = 4,
	Attack = { Damage = 25, Range = 12, Cooldown = 4, TelegraphTime = 0.8 },
	XP = 100,
	Abilities = { "Leap", "GroundSlam" },
	Resistances = {},
	MinProtocol = 5,
	Render = { Model = "", Anims = {}, Scale = 2.5 },
}
