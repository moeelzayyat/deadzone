--!strict
-- Config/Settings (architecture §2.4, §6.1 PlayerSettings; API_CONTRACTS RequestSettings): the whitelist of player
-- settings a client may set through RequestSettings. Every value is a boolean for now. A setting the player never set
-- reads nil and the client uses its device default (InputRules.effective): auto-aim on for touch and gamepad, auto-fire
-- while moving on touch, fixed camera yaw everywhere.
-- Settings are held for the session only until A5 persists them in PlayerProfile.Settings (D-020, D-023).

export type Key = "AutoAim" | "AutoFire" | "CameraRotate"

export type Spec = { Description: string, Since: string }

local SPECS: { [Key]: Spec } = {
	AutoAim = {
		Description = "Aim at the nearest target when no aim input is given (touch and gamepad default on; mouse always aims).",
		Since = "A2.1",
	},
	AutoFire = {
		Description = "Hold the primary attack while moving (touch default on).",
		Since = "A2.1",
	},
	CameraRotate = {
		Description = "Free camera yaw: right mouse drag on PC, left trigger + right stick on gamepad (default off).",
		Since = "A2.1",
	},
}

local keys: { string } = {}
for key in SPECS do
	table.insert(keys, key)
end
table.sort(keys)

local Settings = {
	SPECS = table.freeze(SPECS),
	KEYS = table.freeze(keys), -- sorted
}

function Settings.isKey(key: unknown): boolean
	return typeof(key) == "string" and (SPECS :: any)[key] ~= nil
end

return table.freeze(Settings)
