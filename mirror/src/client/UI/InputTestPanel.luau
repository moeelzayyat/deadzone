--!strict
-- UI/InputTestPanel (A2.1 checkpoint aid; flag InputTestPanel): an overlay that proves every §2.4 action fires on every
-- input scheme. It shows the current scheme, context and effective settings, counts each action per scheme
-- (InputRules.ROWS × KeyboardMouse/Touch/Gamepad; a cell turns green at its first count), and gives buttons for the
-- settings and contexts. In the Cards context it shows three placeholder cards (Click/Tap select; gamepad D-pad + A).
-- Gamepad Y or F2 cycles the context. A * after a setting means the device default. Reads InputController only;
-- sends nothing itself.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputRules = require(ReplicatedStorage.Shared.Util.InputRules)
local Flags = require(ReplicatedStorage.Shared.Config.Flags)
local Controllers = script.Parent.Parent.Controllers
local InputController = require(Controllers.InputController)
local FlagsController = require(Controllers.FlagsController)

type Scheme = InputRules.Scheme
type Context = InputRules.Context

local FLAG = "InputTestPanel"
local FLAG_WAIT_SECONDS = 15
local ROW_HEIGHT = 18
local WIDTH = 300
local SHORT: { [Scheme]: string } = { KeyboardMouse = "PC", Touch = "Touch", Gamepad = "Pad" }
local DIM = Color3.fromRGB(150, 150, 150)
local LIT = Color3.fromRGB(110, 235, 140)
local TEXT = Color3.fromRGB(235, 235, 235)
local PANEL = Color3.fromRGB(16, 18, 22)
local BUTTON = Color3.fromRGB(48, 54, 64)
local ACTIVE = Color3.fromRGB(40, 120, 200)

local player = Players.LocalPlayer
local counts: { [string]: { [string]: number } } = {}
local cells: { [string]: { [string]: TextLabel } } = {}
local gui: ScreenGui? = nil
local started = false

local InputTestPanel = {
	Name = "InputTestPanel",
}

-- Copy of the per-scheme counts (action → scheme → count), for play-test checks.
function InputTestPanel.counts(): { [string]: { [string]: number } }
	local out: { [string]: { [string]: number } } = {}
	for action, row in counts do
		out[action] = table.clone(row)
	end
	return out
end

local function label(parent: Instance, text: string, x: number, y: number, w: number, h: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextSize = 12
	l.TextColor3 = TEXT
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Position = UDim2.fromOffset(x, y)
	l.Size = UDim2.fromOffset(w, h or ROW_HEIGHT)
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, x: number, y: number, w: number, onActivated: (InputObject) -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = text
	b.AutoButtonColor = true
	b.BackgroundColor3 = BUTTON
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = TEXT
	b.Text = text
	b.Position = UDim2.fromOffset(x, y)
	b.Size = UDim2.fromOffset(w, 22)
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = b
	b.Activated:Connect(onActivated)
	return b
end

local function build(): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = "InputTest"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 5
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.25
	panel.BorderSizePixel = 0
	panel.Position = UDim2.fromOffset(8, 8)
	panel.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local function rescale()
		scale.Scale = if workspace.CurrentCamera.ViewportSize.Y < 500 then 0.8 else 1
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	local y = 6
	local header = label(panel, "", 8, y, WIDTH - 16)
	header.Name = "Header"
	header.Font = Enum.Font.GothamBold
	y += ROW_HEIGHT
	local settingsLine = label(panel, "", 8, y, WIDTH - 16)
	settingsLine.Name = "Settings"
	y += ROW_HEIGHT + 2

	local toggles: { [string]: TextButton } = {}
	for i, key in { "AutoAim", "AutoFire", "CameraRotate" } do
		toggles[key] = button(panel, key, 8 + (i - 1) * 96, y, 90, function()
			InputController.setSetting(key, not InputController.effective(key))
		end)
	end
	y += 26
	local contextButtons: { [string]: TextButton } = {}
	for i: number, c: Context in InputRules.CONTEXTS do
		contextButtons[c] = button(panel, c, 8 + (i - 1) * 96, y, 90, function()
			InputController.setContext(c)
		end)
	end
	y += 28

	label(panel, "action", 8, y, 120).TextColor3 = DIM
	for i: number, s: Scheme in InputRules.SCHEMES do
		label(panel, SHORT[s], 130 + (i - 1) * 56, y, 50).TextColor3 = DIM
	end
	y += ROW_HEIGHT
	for _, row in InputRules.ROWS do
		label(panel, row.Label, 8, y, 120)
		cells[row.Action] = {}
		counts[row.Action] = {}
		for i, s in InputRules.SCHEMES do
			local cell = label(panel, "0", 130 + (i - 1) * 56, y, 50)
			cell.TextColor3 = DIM
			cells[row.Action][s] = cell
			counts[row.Action][s] = 0
		end
		y += ROW_HEIGHT
	end
	local last = label(panel, "last: —", 8, y + 2, WIDTH - 16)
	last.Name = "Last"
	last.TextColor3 = DIM
	y += ROW_HEIGHT + 8
	panel.Size = UDim2.fromOffset(WIDTH, y)

	-- Placeholder cards for the Cards context.
	local cards = Instance.new("Frame")
	cards.Name = "Cards"
	cards.BackgroundTransparency = 1
	cards.AnchorPoint = Vector2.new(0.5, 0.5)
	cards.Position = UDim2.fromScale(0.5, 0.45)
	cards.Size = UDim2.fromOffset(3 * 130 + 2 * 16, 170)
	cards.Visible = false
	cards.Parent = screen
	local cardButtons: { TextButton } = {}
	for i = 1, InputRules.CARD_COUNT do
		local card = Instance.new("TextButton")
		card.Name = `Card{i}`
		card.BackgroundColor3 = BUTTON
		card.BorderSizePixel = 0
		card.Font = Enum.Font.GothamBold
		card.TextSize = 18
		card.TextColor3 = TEXT
		card.Text = `Card {i}`
		card.Position = UDim2.fromOffset((i - 1) * 146, 0)
		card.Size = UDim2.fromOffset(130, 170)
		card.Parent = cards
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Thickness = 3
		stroke.Color = ACTIVE
		stroke.Enabled = false
		stroke.Parent = card
		card.Activated:Connect(function(input: InputObject)
			InputController.selectCard(i, InputRules.schemeOf(input.UserInputType))
		end)
		cardButtons[i] = card
	end

	local function refresh()
		header.Text = `INPUT TEST · {InputController.scheme()} · {InputController.context()}`
		local parts: { string } = {}
		for key, b in toggles do
			local on = InputController.effective(key)
			local explicit = InputController.setting(key)
			b.BackgroundColor3 = if on then ACTIVE else BUTTON
			table.insert(parts, `{key} {if on then "on" else "off"}{if explicit == nil then "*" else ""}`)
		end
		table.sort(parts)
		settingsLine.Text = table.concat(parts, " · ")
		for c, b in contextButtons do
			b.BackgroundColor3 = if c == InputController.context() then ACTIVE else BUTTON
		end
		cards.Visible = InputController.context() == "Cards"
		for i, card in cardButtons do
			(card:FindFirstChildOfClass("UIStroke") :: UIStroke).Enabled = i == InputController.focus()
		end
	end

	InputController.Action:Connect(function(action: string, phase: string, scheme: Scheme, arg: any?)
		local row = counts[action]
		if row and phase == "Begin" then
			row[scheme] += 1
			local cell = cells[action][scheme]
			cell.Text = tostring(row[scheme])
			cell.TextColor3 = LIT
		end
		last.Text = `last: {action} {phase} · {SHORT[scheme]}{if arg ~= nil then ` · {tostring(arg)}` else ""}`
		refresh()
	end)
	InputController.SettingChanged:Connect(refresh)
	InputController.ContextChanged:Connect(refresh)
	InputController.SchemeChanged:Connect(refresh)
	refresh()
	return screen
end

local function flagOn(): boolean
	local value = FlagsController.get(FLAG)
	local deadline = os.clock() + FLAG_WAIT_SECONDS
	while value == nil and os.clock() < deadline do
		task.wait(0.2)
		value = FlagsController.get(FLAG)
	end
	if value == nil then
		value = (Flags :: any)[FLAG].Default
	end
	return value == true
end

function InputTestPanel.start()
	if started then
		return
	end
	started = true
	if not flagOn() then
		return
	end
	local screen = build()
	screen.Parent = player:WaitForChild("PlayerGui")
	gui = screen
	InputController.enableTestCycle()
	print("[InputTest] overlay on (flag InputTestPanel)")
	FlagsController.Changed:Connect(function()
		local g = gui
		if g then
			g.Enabled = FlagsController.get(FLAG) ~= false
		end
	end)
end

return table.freeze(InputTestPanel)
