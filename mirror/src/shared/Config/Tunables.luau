--!strict
-- Config/Tunables (architecture §4.3, §20): tunable defaults. RemoteConfigService serves them, overridden by the
-- `Tunables` section of the `Config` DataStore. Server-side only (no client replication).
-- EnemyTestCount and EnemySnapshotHz (A2.3) size the enemy test horde and set the EnemySnapshot rate (§7.2: 10–15 Hz).
-- SampleTunable is a placeholder that exercises the path until a gameplay substage adds real tunables (XP curve, A3.2).

local Schema = require(script.Parent.Schema)

return Schema.build("Tunables", {
	EnemyTestCount = {
		Default = 90,
		Min = 0,
		Max = 300,
		Integer = true,
		Description = "Enemies in the A2.3 test horde (flag EnemyTest); the A2 budget is 90 per arena (§23).",
		Since = "A2.3",
	},
	EnemySnapshotHz = {
		Default = 12,
		Min = 10,
		Max = 15,
		Integer = true,
		Description = "EnemySnapshot pushes per second per arena (§7.2: 10–15 Hz).",
		Since = "A2.3",
	},
	SampleTunable = {
		Default = 1,
		Min = 0,
		Max = 10,
		Description = "Placeholder tunable (A1.8): proves defaults, bounds and overrides; replaced from A3.2.",
		Since = "A1.8",
	},
}, false)
