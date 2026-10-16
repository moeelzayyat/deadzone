--!strict
-- Sample skill node (A1.6). Placeholder: node names, costs and effects are content for B1.3.
return {
	Id = "SampleSkill",
	DisplayName = "Sample Skill",
	Branch = "Survival",
	Prereqs = {},
	MaxRank = 3,
	Cost = { 1, 1, 1 },
	Effect = { Stat = "MaxHealth", Layer = "Flat", PerRank = 10 },
}
