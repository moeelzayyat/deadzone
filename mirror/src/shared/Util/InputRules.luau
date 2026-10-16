--!strict
-- Util/InputRules (architecture §2.4): the bindings table and the pure rules behind Client/Controllers/InputController.
-- The controller binds exactly what BINDINGS lists through ContextActionService; everything here is a plain function so
-- it runs in tests without a player. Client input is intent only: an action name, a phase and an aim direction; the
-- server decides what happens (§7.1).
--   Schemes   KeyboardMouse · Touch · Gamepad (the scheme of the last input; one player can switch mid-run)
--   Contexts  Combat (default) · Vote (Combat + the two vote actions, A3.6) · Cards (only card focus/confirm, A3.3)
--   Move is Roblox's character control (WASD, the dynamic thumbstick, the left stick) and is read from
--   Humanoid.MoveDirection; Aim is computed each frame by resolveAim; card Click/Tap goes through
--   InputController.selectCard from the card UI. Everything else is a ContextActionService binding below (D-023).

export type Scheme = "KeyboardMouse" | "Touch" | "Gamepad"
export type Context = "Combat" | "Vote" | "Cards"
export type Action =
	"Move"
	| "Aim"
	| "Primary"
	| "Dodge"
	| "Signature"
	| "VoteExtract"
	| "VoteHold"
	| "CardFocus"
	| "CardSelect"
	| "AutoFireToggle"
	| "CameraDrag"
	| "CameraYaw"

export type Binding = {
	Action: Action,
	Contexts: { Context }, -- bound while the controller is in one of these
	Inputs: { Enum.KeyCode | Enum.UserInputType }, -- ContextActionService inputs
	Touch: string?, -- title of the ContextActionService touch button (touch devices only)
	Hold: boolean, -- Begin and End matter (otherwise Begin only)
	Arg: number?, -- passed with the action (card focus step)
}

-- What fires each §2.4 action on each scheme (the checkpoint's coverage list; the test panel counts these).
export type Row = { Action: Action, Label: string, KeyboardMouse: string, Touch: string, Gamepad: string }

local DEADZONE = 0.2 -- stick magnitude below this is no input
local TOUCH_STICK_PIXELS = 12 -- right-side drag shorter than this is a tap, not aim
local ASSIST_CONE = math.rad(15) -- gamepad / touch stick snaps to a target within this angle
local AUTO_AIM_RANGE = 60 -- studs

local COMBAT: { Context } = { "Combat", "Vote" }
local VOTE: { Context } = { "Vote" }
local CARDS: { Context } = { "Cards" }
table.freeze(COMBAT) -- shared by several bindings, so frozen once here
table.freeze(VOTE)
table.freeze(CARDS)

local BINDINGS: { Binding } = {
	{
		-- Continuous: the right stick, a right-side touch drag (the optional mobile aim stick) and mouse movement.
		Action = "Aim",
		Contexts = COMBAT,
		Inputs = { Enum.KeyCode.Thumbstick2, Enum.UserInputType.Touch, Enum.UserInputType.MouseMovement },
		Hold = true,
	},
	{
		Action = "Primary",
		Contexts = COMBAT,
		Inputs = { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2 },
		Touch = "ATTACK",
		Hold = true,
	},
	{
		Action = "Dodge",
		Contexts = COMBAT,
		Inputs = { Enum.KeyCode.LeftShift, Enum.KeyCode.Space, Enum.KeyCode.ButtonB },
		Touch = "DODGE",
		Hold = false,
	},
	{
		Action = "Signature",
		Contexts = COMBAT,
		Inputs = { Enum.KeyCode.Q, Enum.KeyCode.ButtonR1, Enum.KeyCode.ButtonL1 },
		Touch = "ABILITY",
		Hold = false,
	},
	{ Action = "VoteExtract", Contexts = VOTE, Inputs = { Enum.KeyCode.One, Enum.KeyCode.DPadLeft }, Touch = "EXTRACT", Hold = false },
	{ Action = "VoteHold", Contexts = VOTE, Inputs = { Enum.KeyCode.Two, Enum.KeyCode.DPadRight }, Touch = "HOLD", Hold = false },
	{ Action = "CardFocus", Contexts = CARDS, Inputs = { Enum.KeyCode.DPadLeft }, Hold = false, Arg = -1 },
	{ Action = "CardFocus", Contexts = CARDS, Inputs = { Enum.KeyCode.DPadRight }, Hold = false, Arg = 1 },
	{ Action = "CardSelect", Contexts = CARDS, Inputs = { Enum.KeyCode.ButtonA }, Hold = false },
	{ Action = "AutoFireToggle", Contexts = COMBAT, Inputs = {}, Touch = "AUTO", Hold = false },
	{ Action = "CameraDrag", Contexts = COMBAT, Inputs = { Enum.UserInputType.MouseButton2 }, Hold = true },
	{ Action = "CameraYaw", Contexts = COMBAT, Inputs = { Enum.KeyCode.ButtonL2 }, Hold = true },
}

local ROWS: { Row } = {
	{ Action = "Move", Label = "Move", KeyboardMouse = "WASD", Touch = "Left virtual stick", Gamepad = "Left stick" },
	{ Action = "Aim", Label = "Aim", KeyboardMouse = "Mouse", Touch = "Auto-aim + right-side drag", Gamepad = "Right stick + assist" },
	{ Action = "Primary", Label = "Primary", KeyboardMouse = "LMB hold", Touch = "ATTACK hold / auto-fire", Gamepad = "RT" },
	{ Action = "Dodge", Label = "Dodge", KeyboardMouse = "Shift / Space", Touch = "DODGE", Gamepad = "B" },
	{ Action = "Signature", Label = "Signature", KeyboardMouse = "Q", Touch = "ABILITY", Gamepad = "RB / LB" },
	{ Action = "VoteExtract", Label = "Vote extract", KeyboardMouse = "1", Touch = "EXTRACT button", Gamepad = "D-pad left" },
	{ Action = "VoteHold", Label = "Vote hold", KeyboardMouse = "2", Touch = "HOLD button", Gamepad = "D-pad right" },
	{ Action = "CardSelect", Label = "Card select", KeyboardMouse = "Click", Touch = "Tap", Gamepad = "D-pad + A" },
}

local CONTEXTS: { Context } = { "Combat", "Vote", "Cards" }
local SCHEMES: { Scheme } = { "KeyboardMouse", "Touch", "Gamepad" }
table.freeze(CONTEXTS)
table.freeze(SCHEMES)

local InputRules = {
	DEADZONE = DEADZONE,
	TOUCH_STICK_PIXELS = TOUCH_STICK_PIXELS,
	ASSIST_CONE = ASSIST_CONE,
	AUTO_AIM_RANGE = AUTO_AIM_RANGE,
	CONTEXTS = CONTEXTS,
	SCHEMES = SCHEMES,
	CARD_COUNT = 3,
}

for _, b in BINDINGS do
	table.freeze(b.Inputs)
	table.freeze(b)
end
for _, r in ROWS do
	table.freeze(r)
end
InputRules.BINDINGS = table.freeze(BINDINGS)
InputRules.ROWS = table.freeze(ROWS)

-- The ContextActionService action name of binding i (unique per binding).
function InputRules.actionName(index: number): string
	local b = BINDINGS[index]
	return if b.Arg then `DZ_{b.Action}_{index}` else `DZ_{b.Action}`
end

-- The scheme an input belongs to; nil for inputs that say nothing (focus, text, accelerometer, ...). A gamepad key code
-- (buttons, D-pad, sticks) counts as Gamepad whatever input type delivered it (injected test input arrives as Keyboard).
function InputRules.schemeOf(inputType: Enum.UserInputType, keyCode: Enum.KeyCode?): Scheme?
	if keyCode then
		local name = keyCode.Name
		if string.sub(name, 1, 6) == "Button" or string.sub(name, 1, 4) == "DPad" or string.sub(name, 1, 10) == "Thumbstick" then
			return "Gamepad"
		end
	end
	if inputType == Enum.UserInputType.Touch then
		return "Touch"
	end
	if
		inputType == Enum.UserInputType.Keyboard
		or inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.MouseButton2
		or inputType == Enum.UserInputType.MouseButton3
		or inputType == Enum.UserInputType.MouseMovement
		or inputType == Enum.UserInputType.MouseWheel
	then
		return "KeyboardMouse"
	end
	if string.sub(inputType.Name, 1, 7) == "Gamepad" then
		return "Gamepad"
	end
	return nil
end

-- A setting's value after device defaults: an explicit choice wins; otherwise auto-aim is on for touch and gamepad,
-- auto-fire is on for touch, camera rotation is off (§2.4 mobile defaults).
function InputRules.effective(key: string, explicit: boolean?, scheme: Scheme): boolean
	if explicit ~= nil then
		return explicit
	end
	if key == "AutoAim" then
		return scheme ~= "KeyboardMouse"
	elseif key == "AutoFire" then
		return scheme == "Touch"
	end
	return false
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-6 then f.Unit else Vector3.zero
end
InputRules.flat = flat

-- A stick (x right, y up = away from the camera) as a flat world direction for a camera looking along `look`.
-- Zero inside the dead zone.
function InputRules.stickToWorld(x: number, y: number, look: Vector3): Vector3
	if Vector2.new(x, y).Magnitude < DEADZONE then
		return Vector3.zero
	end
	local forward = flat(look)
	if forward == Vector3.zero then
		forward = Vector3.new(0, 0, -1)
	end
	local right = Vector3.new(-forward.Z, 0, forward.X)
	return flat(right * x + forward * y)
end

-- Where a ray meets the horizontal plane y = planeY (nil if it never does, going up or parallel).
function InputRules.planeHit(origin: Vector3, direction: Vector3, planeY: number): Vector3?
	if math.abs(direction.Y) < 1e-6 then
		return nil
	end
	local t = (planeY - origin.Y) / direction.Y
	if t <= 0 then
		return nil
	end
	return origin + direction * t
end

export type AimInput = {
	scheme: Scheme,
	manual: Vector3?, -- flat direction from the mouse, a stick or the touch drag; nil when there is none
	autoAim: boolean, -- effective AutoAim
	target: Vector3?, -- nearest target position from the provider (nil before enemies exist, A2.3)
	origin: Vector3,
	move: Vector3, -- Humanoid.MoveDirection
	last: Vector3, -- the previous aim
}

export type AimSource = "manual" | "assist" | "auto" | "move" | "hold"

-- The aim for this frame: manual input wins (a stick snaps to a target inside the assist cone when auto-aim is on;
-- the mouse never does); then the auto-aim target; then the move direction; then the last aim.
function InputRules.resolveAim(input: AimInput): (Vector3, AimSource)
	local toTarget: Vector3? = nil
	if input.autoAim and input.target then
		local d = flat(input.target - input.origin)
		if d ~= Vector3.zero and (input.target - input.origin).Magnitude <= AUTO_AIM_RANGE then
			toTarget = d
		end
	end
	local manual = input.manual
	if manual and manual ~= Vector3.zero then
		if toTarget and input.scheme ~= "KeyboardMouse" then
			local angle = math.acos(math.clamp(manual:Dot(toTarget), -1, 1))
			if angle <= ASSIST_CONE then
				return toTarget, "assist"
			end
		end
		return manual, "manual"
	end
	if toTarget then
		return toTarget, "auto"
	end
	local move = flat(input.move)
	if move ~= Vector3.zero then
		return move, "move"
	end
	local last = flat(input.last)
	return if last ~= Vector3.zero then last else Vector3.new(0, 0, -1), "hold"
end

-- Whether the primary attack is held this frame: held by hand, or auto-fire while moving (never in the card context).
function InputRules.firing(manualHeld: boolean, autoFire: boolean, moving: boolean, context: Context): boolean
	if context == "Cards" then
		return false
	end
	return manualHeld or (autoFire and moving)
end

-- Card focus after a D-pad step, wrapping around `count` cards (1-based).
function InputRules.stepFocus(index: number, delta: number, count: number): number
	return ((index - 1 + delta) % count) + 1
end

-- Whether a binding is active in a context.
function InputRules.activeIn(binding: Binding, context: Context): boolean
	return table.find(binding.Contexts, context) ~= nil
end

return table.freeze(InputRules)
