--!strict
-- Fodder enemy (A2.3): CONTENT_BIBLE §2 "thin and leaning, fast and fragile". Slower than a survivor (16 studs/s) so a
-- moving player can still kite; numbers are placeholders until the A3 balance pass.
return {
	Id = "Runner",
	Tier = "Fodder",
	MaxHealth = 12,
	MoveSpeed = 12,
	Radius = 1.25,
	Attack = { Damage = 4, Range = 2.5, Cooldown = 1.2, TelegraphTime = 0.3 },
	XP = 1,
	Abilities = {},
	Resistances = {},
	MinProtocol = 1,
	Render = { Model = "", Anims = {}, Scale = 1 },
}
