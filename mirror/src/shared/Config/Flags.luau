--!strict
-- Config/Flags (architecture §4.3, §20): feature flag defaults. FeatureFlagService serves them, overridden by the `Flags`
-- section of the `Config` DataStore; `Client = true` flags are replicated through the FlagsUpdate remote.
-- InputTestPanel (A2.1) shows the input test overlay (Client/UI/InputTestPanel); it goes off before the A3.5 public test.
-- TestArena (A2.2, server) places Arenas/TestArena in slot 0 and spawns players in it; run sessions take over in A3.
-- SampleFlag is a placeholder that exercises the path until A3.9 adds the first real flags (icon and onboarding variants).

local Schema = require(script.Parent.Schema)

return Schema.build("Flags", {
	InputTestPanel = {
		Default = true,
		Client = true,
		Description = "Input test overlay (A2.1): scheme, context, settings and per-scheme action counts; off for A3.5.",
		Since = "A2.1",
	},
	TestArena = {
		Default = true,
		Client = false,
		Description = "Arena test harness (A2.2): TestArena in slot 0, players spawn in it; off once run sessions place arenas (A3).",
		Since = "A2.2",
	},
	SampleFlag = {
		Default = false,
		Client = true,
		Description = "Placeholder flag (A1.8): proves defaults, overrides and client replication; replaced in A3.9.",
		Since = "A1.8",
	},
}, true)
