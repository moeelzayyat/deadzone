--!strict
-- Config/Flags (architecture §4.3, §20): feature flag defaults. FeatureFlagService serves them, overridden by the `Flags`
-- section of the `Config` DataStore; `Client = true` flags are replicated through the FlagsUpdate remote.
-- SampleFlag is a placeholder that exercises the path until A3.9 adds the first real flags (icon and onboarding variants).

local Schema = require(script.Parent.Schema)

return Schema.build("Flags", {
	SampleFlag = {
		Default = false,
		Client = true,
		Description = "Placeholder flag (A1.8): proves defaults, overrides and client replication; replaced in A3.9.",
		Since = "A1.8",
	},
}, true)
