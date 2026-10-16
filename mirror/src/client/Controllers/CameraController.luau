--!strict
-- Controllers/CameraController (architecture §2.4, §6.4): the elevated third-person camera. A scriptable camera follows
-- the character's root from above and behind at a fixed pitch (slight isometric look) and a fixed yaw; with the
-- CameraRotate setting on, InputController's yaw input (right-drag on PC, LT + right stick on gamepad) turns it.
-- Presentation only: the camera never decides anything.
--   pose(focus, yaw) → CFrame   the camera CFrame for a focus point (pure; used by tests)
--   yaw()                        current yaw in radians (0 = looking toward -Z)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local InputController = require(script.Parent.InputController)

local PITCH = math.rad(55) -- down from the horizon
local DISTANCE = 44 -- studs from the focus point
local FIELD_OF_VIEW = 50
local FOLLOW_RATE = 14 -- 1/s; higher follows tighter
local FOCUS_HEIGHT = 1.5 -- above the root, so the body sits in the middle of the screen

local player = Players.LocalPlayer
local currentYaw = 0
local focus: Vector3? = nil
local started = false

local CameraController = {
	Name = "CameraController",
	PITCH = PITCH,
	DISTANCE = DISTANCE,
	FIELD_OF_VIEW = FIELD_OF_VIEW,
}

function CameraController.pose(at: Vector3, yaw: number): CFrame
	local back = Vector3.new(math.sin(yaw), 0, math.cos(yaw)) -- from the focus toward the camera, flat
	local offset = back * (DISTANCE * math.cos(PITCH)) + Vector3.new(0, DISTANCE * math.sin(PITCH), 0)
	return CFrame.lookAt(at + offset, at)
end

function CameraController.yaw(): number
	return currentYaw
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	if InputController.effective("CameraRotate") then
		currentYaw += InputController.takeYaw()
	else
		InputController.takeYaw()
		currentYaw = 0
	end
	local model = player.Character
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local target = root.Position + Vector3.new(0, FOCUS_HEIGHT, 0)
		local current = focus
		focus = if current then current:Lerp(target, 1 - math.exp(-FOLLOW_RATE * dt)) else target
	end
	if focus then
		camera.CFrame = CameraController.pose(focus :: Vector3, currentYaw)
	end
end

function CameraController.start()
	if started then
		return
	end
	started = true
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = FIELD_OF_VIEW
	player.CharacterAdded:Connect(function()
		focus = nil -- snap to the new character instead of gliding across the map
	end)
	RunService:BindToRenderStep("DZ_Camera", Enum.RenderPriority.Camera.Value + 1, step)
	print(`[Camera] elevated · pitch {math.deg(PITCH)}° · distance {DISTANCE} · fov {FIELD_OF_VIEW}`)
end

return table.freeze(CameraController)
