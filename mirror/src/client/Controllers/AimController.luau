--!strict
-- Controllers/AimController (architecture §2.4, §6.4): shows the aim. The character turns to face InputController's aim
-- direction (Humanoid.AutoRotate off, so it can run one way and shoot another) and a flat marker on the ground points
-- along it, brighter while the primary attack is held. Presentation only; the server decides every hit (§7.1).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local InputController = require(script.Parent.InputController)

local MARKER_LENGTH = 7
local MARKER_GAP = 2.2 -- studs from the root to the marker's near end
local MARKER_COLOR = Color3.fromRGB(235, 245, 255)
local MARKER_IDLE = 0.55 -- transparency while not firing
local MARKER_FIRING = 0.1

local player = Players.LocalPlayer
local marker: Part? = nil
local started = false

local AimController = {
	Name = "AimController",
}

local function makeMarker(): Part
	local part = Instance.new("Part")
	part.Name = "AimMarker"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = MARKER_COLOR
	part.Size = Vector3.new(0.35, 0.05, MARKER_LENGTH)
	part.Transparency = MARKER_IDLE
	part.Parent = workspace.CurrentCamera -- client-only, never replicated
	return part
end

local function step()
	local model = player.Character
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local m = marker
	if humanoid == nil or root == nil or humanoid.Health <= 0 or m == nil then
		if m then
			m.Transparency = 1
		end
		return
	end
	local aim = InputController.aim()
	if humanoid.AutoRotate then
		humanoid.AutoRotate = false
	end
	local position = root.Position
	root.CFrame = CFrame.lookAlong(position, aim)
	local floor = position.Y - humanoid.HipHeight - root.Size.Y / 2 + 0.06
	local center = Vector3.new(position.X, floor, position.Z) + aim * (MARKER_GAP + MARKER_LENGTH / 2)
	m.CFrame = CFrame.lookAlong(center, aim)
	m.Transparency = if InputController.isFiring() then MARKER_FIRING else MARKER_IDLE
end

function AimController.start()
	if started then
		return
	end
	started = true
	marker = makeMarker()
	RunService:BindToRenderStep("DZ_Aim", Enum.RenderPriority.Character.Value, step)
end

return table.freeze(AimController)
