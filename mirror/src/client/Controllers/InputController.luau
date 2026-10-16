--!strict
-- Controllers/InputController (architecture §2.4, §6.4, §7.1): the one place input is bound. Every binding in
-- Shared/Util/InputRules.BINDINGS goes through ContextActionService for the current context; movement is Roblox's
-- character control, read back from Humanoid.MoveDirection. The controller turns input into intent only:
--   Action        signal (action, phase "Begin"|"End", scheme, arg?) for Move, Aim, Primary, Dodge, Signature,
--                 VoteExtract, VoteHold, CardFocus (arg = focused card), CardSelect (arg = card), AutoFireToggle
--   aim()         flat world aim direction for this frame (InputRules.resolveAim), aimSource()
--   isFiring()    primary held by hand or by auto-fire while moving
--   settings      setting(key) explicit value or nil, effective(key) after device defaults, setSetting(key, value)
--                 (sent to the server through RequestSettings, at most one send per 0.25 s, so never above its 5/s)
--   contexts      setContext("Combat" | "Vote" | "Cards"); the card UI (A3.3) and the vote HUD (A3.6) switch it
-- Combat systems (A2.5 onward) subscribe to Action and read aim(); they send their own requests. No damage, hits or
-- truth leave the client from here.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local InputRules = require(ReplicatedStorage.Shared.Util.InputRules)
local Settings = require(ReplicatedStorage.Shared.Config.Settings)

type Scheme = InputRules.Scheme
type Context = InputRules.Context
type AimSource = InputRules.AimSource
type Binding = InputRules.Binding
export type TargetProvider = (origin: Vector3) -> Vector3?

local REMOTE = "RequestSettings"
local NET_WAIT_SECONDS = 30
local SEND_INTERVAL = 0.25 -- one RequestSettings per 0.25 s at most (4/s, under the 5/s contract rate)
local KEY_PRIORITY = Enum.ContextActionPriority.High.Value + 1 -- above Roblox jump (Space) and mouse lock (Shift)
local TOUCH_AIM_PRIORITY = Enum.ContextActionPriority.Medium.Value -- below the dynamic thumbstick, which passes right-side touches
local TOUCH_AIM_MIN_X = 0.45 -- a touch must start right of this share of the screen to aim
local MOUSE_AIM_ACTIVE = 0.3 -- seconds a mouse movement counts as active aim
local MOVE_THRESHOLD = 0.1
local YAW_MOUSE = 0.008 -- radians per pixel of right-drag
local YAW_STICK = 2.5 -- radians per second at full stick

-- Touch button layout inside Roblox's ContextButtonFrame: center (scale of the frame) and size (share of screen height).
local TOUCH_LAYOUT: { [string]: { x: number, y: number, size: number } } = {
	ATTACK = { x = 0.68, y = 0.62, size = 0.24 },
	DODGE = { x = 0.32, y = 0.84, size = 0.15 },
	ABILITY = { x = 0.26, y = 0.46, size = 0.15 },
	AUTO = { x = 0.9, y = 0.16, size = 0.1 },
	EXTRACT = { x = 0.22, y = 0.1, size = 0.2 },
	HOLD = { x = 0.62, y = 0.1, size = 0.2 },
}

local player = Players.LocalPlayer

local actionEvent = Instance.new("BindableEvent")
local settingEvent = Instance.new("BindableEvent")
local contextEvent = Instance.new("BindableEvent")
local schemeEvent = Instance.new("BindableEvent")

local scheme: Scheme = InputRules.schemeOf(UserInputService:GetLastInputType())
	or (if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "Touch" else "KeyboardMouse")
local context: Context = "Combat"
local explicit: { [string]: boolean } = {}
local pending: { [string]: boolean } = {}
local sends = 0
local remote: RemoteEvent? = nil

local manualPrimary = false
local cameraDrag = false
local dragX: number? = nil -- mouse X at the last drag step
local cameraYawHeld = false
local firing = false
local moving = false
local aimActive = false
local aimDir = Vector3.new(0, 0, -1)
local aimSource: AimSource = "hold"
local aimStick = Vector2.zero
local mouseMovedAt = -math.huge
local touchAim: { input: InputObject, origin: Vector2, dir: Vector3? }? = nil
local focus = 1
local yaw = 0
local targetProvider: TargetProvider? = nil
local started = false

local InputController = {
	Name = "InputController",
	Action = actionEvent.Event, -- (action: string, phase: "Begin" | "End", scheme: Scheme, arg: any?)
	SettingChanged = settingEvent.Event, -- (key: string, effective: boolean)
	ContextChanged = contextEvent.Event, -- (context: Context)
	SchemeChanged = schemeEvent.Event, -- (scheme: Scheme)
}

local function emit(action: string, phase: "Begin" | "End", arg: any?)
	actionEvent:Fire(action, phase, scheme, arg)
end

local function setScheme(s: Scheme?)
	if s and s ~= scheme then
		scheme = s
		schemeEvent:Fire(s)
		for _, key in Settings.KEYS do
			settingEvent:Fire(key, InputRules.effective(key, explicit[key], scheme))
		end
	end
end

function InputController.scheme(): Scheme
	return scheme
end

function InputController.context(): Context
	return context
end

function InputController.setting(key: string): boolean?
	return explicit[key]
end

function InputController.effective(key: string): boolean
	return InputRules.effective(key, explicit[key], scheme)
end

-- Sets a whitelisted setting locally (at once) and queues it for the server.
function InputController.setSetting(key: string, value: boolean)
	if not Settings.isKey(key) then
		error(`[Input] unknown setting {tostring(key)}; add it to Shared/Config/Settings`, 0)
	end
	explicit[key] = value
	pending[key] = value
	settingEvent:Fire(key, InputRules.effective(key, value, scheme))
end

function InputController.sends(): number
	return sends
end

function InputController.aim(): Vector3
	return aimDir
end

function InputController.aimSource(): AimSource
	return aimSource
end

function InputController.isFiring(): boolean
	return firing
end

function InputController.isMoving(): boolean
	return moving
end

function InputController.focus(): number
	return focus
end

-- Radians of camera yaw input since the last call (free rotation only; CameraController consumes it each frame).
function InputController.takeYaw(): number
	local y = yaw
	yaw = 0
	return y
end

-- The auto-aim target source (EnemyService's client view, A2.3/A2.4). nil = no targets.
function InputController.setTargetProvider(provider: TargetProvider?)
	targetProvider = provider
end

-- Card Click/Tap from the card UI, and gamepad A on the focused card.
function InputController.selectCard(index: number, from: Scheme?)
	if context ~= "Cards" or index < 1 or index > InputRules.CARD_COUNT then
		return
	end
	setScheme(from)
	focus = index
	emit("CardSelect", "Begin", index)
end

local function layoutTouchButton(name: string, title: string)
	local spot = TOUCH_LAYOUT[title]
	local button = ContextActionService:GetButton(name)
	if spot == nil or button == nil then
		return
	end
	ContextActionService:SetTitle(name, title)
	local camera = workspace.CurrentCamera
	local side = math.floor(camera.ViewportSize.Y * spot.size)
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Size = UDim2.fromOffset(side, side)
	button.Position = UDim2.fromScale(spot.x, spot.y)
end

local function onAim(state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		setScheme("KeyboardMouse")
		mouseMovedAt = os.clock()
		if cameraDrag and dragX and InputController.effective("CameraRotate") then
			yaw -= (input.Position.X - dragX) * YAW_MOUSE -- right-drag turns the camera (free rotation on)
			dragX = input.Position.X
		end
		return Enum.ContextActionResult.Pass
	end
	if input.KeyCode == Enum.KeyCode.Thumbstick2 then
		setScheme("Gamepad")
		aimStick = if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel
			then Vector2.zero
			else Vector2.new(input.Position.X, input.Position.Y)
		return Enum.ContextActionResult.Sink
	end
	-- Touch: a drag that starts on the right side of the screen is the optional aim stick.
	local current = touchAim
	local position = Vector2.new(input.Position.X, input.Position.Y)
	if state == Enum.UserInputState.Begin then
		if current ~= nil or position.X < workspace.CurrentCamera.ViewportSize.X * TOUCH_AIM_MIN_X then
			return Enum.ContextActionResult.Pass
		end
		setScheme("Touch")
		touchAim = { input = input, origin = position, dir = nil }
		return Enum.ContextActionResult.Sink
	end
	if current == nil or current.input ~= input then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Change then
		local drag = position - current.origin
		current.dir = if drag.Magnitude >= InputRules.TOUCH_STICK_PIXELS
			then InputRules.stickToWorld(drag.Unit.X, -drag.Unit.Y, workspace.CurrentCamera.CFrame.LookVector)
			else nil
	else
		touchAim = nil
	end
	return Enum.ContextActionResult.Sink
end

local function handlerFor(binding: Binding)
	return function(_: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
		if binding.Action == "Aim" then
			return onAim(state, input)
		end
		local began = state == Enum.UserInputState.Begin
		local ended = state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel
		if not began and not ended then
			return Enum.ContextActionResult.Pass
		end
		if binding.Action == "CameraDrag" or binding.Action == "CameraYaw" then
			if not InputController.effective("CameraRotate") and began then
				return Enum.ContextActionResult.Pass
			end
			setScheme(InputRules.schemeOf(input.UserInputType, input.KeyCode))
			if binding.Action == "CameraDrag" then
				cameraDrag = began
				dragX = if began then input.Position.X else nil
			else
				cameraYawHeld = began
			end
			return Enum.ContextActionResult.Sink
		end
		setScheme(InputRules.schemeOf(input.UserInputType, input.KeyCode))
		if binding.Action == "Primary" then
			manualPrimary = began
		elseif not began then
			return Enum.ContextActionResult.Sink
		elseif binding.Action == "AutoFireToggle" then
			InputController.setSetting("AutoFire", not InputController.effective("AutoFire"))
			emit("AutoFireToggle", "Begin", InputController.effective("AutoFire"))
		elseif binding.Action == "CardFocus" then
			focus = InputRules.stepFocus(focus, binding.Arg or 1, InputRules.CARD_COUNT)
			emit("CardFocus", "Begin", focus)
		elseif binding.Action == "CardSelect" then
			InputController.selectCard(focus)
		else
			emit(binding.Action, "Begin")
		end
		return Enum.ContextActionResult.Sink
	end
end

local function bindContext()
	for index, binding in InputRules.BINDINGS do
		local name = InputRules.actionName(index)
		ContextActionService:UnbindAction(name)
		if not InputRules.activeIn(binding, context) then
			continue
		end
		local touchButton = binding.Touch ~= nil and UserInputService.TouchEnabled
		if #binding.Inputs == 0 and not touchButton then
			continue
		end
		if binding.Action == "Aim" then
			-- The touch drag sits below the thumbstick's priority; the stick and mouse ride along with it.
			ContextActionService:BindActionAtPriority(name, handlerFor(binding), false, TOUCH_AIM_PRIORITY, table.unpack(binding.Inputs))
		else
			ContextActionService:BindActionAtPriority(name, handlerFor(binding), touchButton, KEY_PRIORITY, table.unpack(binding.Inputs))
		end
		if touchButton then
			layoutTouchButton(name, binding.Touch :: string)
		end
	end
end

function InputController.setContext(c: Context)
	if table.find(InputRules.CONTEXTS, c) == nil then
		error(`[Input] unknown context {tostring(c)}`, 0)
	end
	if c == context then
		return
	end
	context = c
	manualPrimary = false
	focus = 1
	if started then
		bindContext()
	end
	contextEvent:Fire(c)
end

-- Test overlay only (InputTestPanel flag): gamepad Y and F2 cycle Combat → Vote → Cards, so every context can be reached
-- on every scheme before the card UI (A3.3) and vote HUD (A3.6) exist.
function InputController.enableTestCycle()
	ContextActionService:BindActionAtPriority("DZ_TestContext", function(_: string, state: Enum.UserInputState, input: InputObject)
		if state == Enum.UserInputState.Begin then
			setScheme(InputRules.schemeOf(input.UserInputType, input.KeyCode))
			local i = table.find(InputRules.CONTEXTS, context) :: number
			InputController.setContext(InputRules.CONTEXTS[i % #InputRules.CONTEXTS + 1])
		end
		return Enum.ContextActionResult.Sink
	end, false, KEY_PRIORITY, Enum.KeyCode.ButtonY, Enum.KeyCode.F2)
end

local function character(): (Humanoid?, BasePart?)
	local model = player.Character
	if model == nil then
		return nil, nil
	end
	return model:FindFirstChildOfClass("Humanoid"), model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function step(dt: number)
	local humanoid, root = character()
	local camera = workspace.CurrentCamera

	local nowMoving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > MOVE_THRESHOLD
	if nowMoving ~= moving then
		moving = nowMoving
		emit("Move", if moving then "Begin" else "End")
	end

	local rotating = InputController.effective("CameraRotate")
	if rotating and cameraYawHeld then
		yaw -= aimStick.X * YAW_STICK * dt
	end

	local manual: Vector3? = nil
	if root then
		if scheme == "KeyboardMouse" then
			local mouse = UserInputService:GetMouseLocation()
			local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
			local hit = InputRules.planeHit(ray.Origin, ray.Direction, root.Position.Y)
			if hit then
				manual = InputRules.flat(hit - root.Position)
			end
		elseif scheme == "Gamepad" and not (rotating and cameraYawHeld) then
			local d = InputRules.stickToWorld(aimStick.X, aimStick.Y, camera.CFrame.LookVector)
			manual = if d ~= Vector3.zero then d else nil
		elseif scheme == "Touch" and touchAim then
			manual = touchAim.dir
		end
		local origin = root.Position
		aimDir, aimSource = InputRules.resolveAim({
			scheme = scheme,
			manual = manual,
			autoAim = InputController.effective("AutoAim"),
			target = if targetProvider then targetProvider(origin) else nil,
			origin = origin,
			move = if humanoid then humanoid.MoveDirection else Vector3.zero,
			last = aimDir,
		})
	end

	local nowAiming = if scheme == "KeyboardMouse"
		then os.clock() - mouseMovedAt < MOUSE_AIM_ACTIVE
		else manual ~= nil
	if nowAiming ~= aimActive then
		aimActive = nowAiming
		emit("Aim", if aimActive then "Begin" else "End", aimSource)
	end

	local nowFiring = InputRules.firing(manualPrimary, InputController.effective("AutoFire"), moving, context)
	if nowFiring ~= firing then
		firing = nowFiring
		emit("Primary", if firing then "Begin" else "End", if manualPrimary then "manual" else "auto")
	end
end

-- Sends queued settings, one key per SEND_INTERVAL, once the server's remote exists.
local function sendLoop()
	local net = ReplicatedStorage:WaitForChild("Net", NET_WAIT_SECONDS)
	local found = net and net:WaitForChild(REMOTE, NET_WAIT_SECONDS)
	if found == nil or not found:IsA("RemoteEvent") then
		warn(`[Input] ReplicatedStorage.Net.{REMOTE} did not appear within {NET_WAIT_SECONDS} s; settings stay local`)
		return
	end
	remote = found
	while true do
		local key = next(pending)
		if key ~= nil then
			local value = pending[key]
			pending[key] = nil
			(remote :: RemoteEvent):FireServer({ Key = key, Value = value })
			sends += 1
		end
		task.wait(SEND_INTERVAL)
	end
end

function InputController.start()
	if started then
		return
	end
	started = true
	UserInputService.LastInputTypeChanged:Connect(function(inputType: Enum.UserInputType)
		setScheme(InputRules.schemeOf(inputType))
	end)
	bindContext()
	RunService:BindToRenderStep("DZ_Input", Enum.RenderPriority.Input.Value + 1, step)
	print(`[Input] ready · scheme {scheme} · context {context} · touch {UserInputService.TouchEnabled} · gamepad {UserInputService.GamepadEnabled}`)
	task.spawn(sendLoop)
end

return table.freeze(InputController)
