--!strict
-- Config/Tunables (architecture §4.3, §20): tunable defaults. RemoteConfigService serves them, overridden by the
-- `Tunables` section of the `Config` DataStore. Server-side only (no client replication).
-- SampleTunable is a placeholder that exercises the path until a gameplay substage adds real tunables (XP curve, A3.2).

local Schema = require(script.Parent.Schema)

return Schema.build("Tunables", {
	SampleTunable = {
		Default = 1,
		Min = 0,
		Max = 10,
		Description = "Placeholder tunable (A1.8): proves defaults, bounds and overrides; replaced from A3.2.",
		Since = "A1.8",
	},
}, false)
