--!strict
-- UI/PerfOverlay (A2.4 checkpoint aid, architecture §23; flag PerfOverlay): a one-line FPS overlay in the top right
-- corner. Every REFRESH seconds it shows the frame rate and the 99th-percentile frame time over the last WINDOW frames,
-- the enemies drawn (rigs in use, rigs parked in the pool), the renderer's own work per frame, the interpolation delay
-- and the emulated CPU scale when the low-end emulation is on (D-026). Reads EnemyRenderer only; sends nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Flags = require(ReplicatedStorage.Shared.Config.Flags)
local FlagsController = require(script.Parent.Parent.Controllers.FlagsController)
local EnemyRenderer = require(script.Parent.Parent.Render.EnemyRenderer)

local FLAG = "PerfOverlay"
local FLAG_WAIT_SECONDS = 15
local WINDOW = 300
local REFRESH = 0.5

local player = Players.LocalPlayer
local frameTimes: { number } = table.create(WINDOW, 0)
local frameCount = 0
local started = false

local PerfOverlay = { Name = "PerfOverlay" }

-- Average FPS and p99 frame time (ms) over the last WINDOW frames.
function PerfOverlay.frameStats(): (number, number)
	local n = math.min(frameCount, WINDOW)
	if n == 0 then
		return 0, 0
	end
	local sorted = table.move(frameTimes, 1, n, 1, table.create(n))
	table.sort(sorted)
	local total = 0
	for _, dt in sorted do
		total += dt
	end
	return n / total, sorted[math.clamp(math.ceil(n * 0.99), 1, n)] * 1000
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

local function build(): (ScreenGui, TextLabel)
	local screen = Instance.new("ScreenGui")
	screen.Name = "PerfOverlay"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 100
	screen.IgnoreGuiInset = true
	local text = Instance.new("TextLabel")
	text.Name = "Line"
	text.AnchorPoint = Vector2.new(1, 0)
	text.Position = UDim2.new(1, -8, 0, 8)
	text.Size = UDim2.fromOffset(0, 22)
	text.AutomaticSize = Enum.AutomaticSize.X
	text.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
	text.BackgroundTransparency = 0.25
	text.BorderSizePixel = 0
	text.Font = Enum.Font.Code
	text.TextSize = 13
	text.TextColor3 = Color3.fromRGB(235, 235, 235)
	text.TextXAlignment = Enum.TextXAlignment.Right
	text.Text = "FPS —"
	text.Parent = screen
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = text
	return screen, text
end

function PerfOverlay.start()
	if started then
		return
	end
	started = true
	RunService.RenderStepped:Connect(function(dt: number)
		frameCount += 1
		frameTimes[(frameCount - 1) % WINDOW + 1] = dt
	end)
	if not flagOn() then
		return
	end
	local screen, line = build()
	screen.Parent = player:WaitForChild("PlayerGui")
	print("[Perf] overlay on (flag PerfOverlay)")
	FlagsController.Changed:Connect(function()
		screen.Enabled = FlagsController.get(FLAG) ~= false
	end)
	while true do
		task.wait(REFRESH)
		local fps, p99 = PerfOverlay.frameStats()
		local s = EnemyRenderer.stats()
		line.Text = string.format(
			"FPS %.0f · p99 %.1f ms · enemies %d (rigs %d, pool %d) · render %.2f ms · delay %.0f ms%s",
			fps,
			p99,
			s.Enemies,
			s.Rigs,
			s.Parked,
			s.WorkAvgMs,
			s.DelayMs,
			if s.CpuScale > 1 then string.format(" · CPU ×%.0f", s.CpuScale) else ""
		)
	end
end

return table.freeze(PerfOverlay)
