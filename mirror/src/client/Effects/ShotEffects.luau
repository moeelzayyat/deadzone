--!strict
-- Effects/ShotEffects (architecture §7.1 "predicted feedback", §22, §23 "cosmetic effects client-only, bounded"): the
-- predicted look and sound of a primary shot, drawn the frame the shot is fired, before the server has answered.
--   ShotEffects.init()                           creates Workspace.ClientFx and the pooled parts (call once)
--   ShotEffects.shot(muzzle, endPoint)           muzzle flash + light, tracer, shot sound
--   ShotEffects.spark(position) → Spark          a predicted hit spark (orange) at the enemy the player saw
--   ShotEffects.confirm(spark, crit)             the server agreed: the spark pops white (gold on a crit), then fades
--   ShotEffects.fade(spark)                      the server disagreed (or never answered): the spark fades out fast
--   ShotEffects.step(now)                        animates everything; called every frame by CombatController
-- Damage numbers, hit flash on the rig and the kill pop are A2.8 (Juice). Parts are anchored, never collide, never take
-- queries or touches, and are pooled (parked out of sight, never re-parented): at most POOL tracers and sparks.
-- Placeholder look: neon primitives (ART_BIBLE rule 7 effects are A2.8). Sound: Audioscape "AS_gun_shot-02"
-- (assets/ART_SOURCES.md).

local SoundService = game:GetService("SoundService")

export type Spark = { Part: BasePart, BornAt: number, Mode: "Predicted" | "Confirmed" | "Fading", ModeAt: number, Crit: boolean }

local CONTAINER = "ClientFx"
local POOL = 8
local PARK = CFrame.new(0, 10000, 0)
local SHOT_SOUND = "rbxassetid://128598607431847"
local SHOT_VOLUME = 0.35
local FLASH_TIME = 0.06 -- s
local TRACER_TIME = 0.09 -- s
local PREDICTED_SIZE = 0.9
local CONFIRM_TIME = 0.16 -- s the white pop lasts
local FADE_TIME = 0.12 -- s a refused spark takes to vanish
local PREDICTED_COLOR = Color3.fromRGB(255, 150, 60)
local CONFIRM_COLOR = Color3.fromRGB(255, 255, 255)
local CRIT_COLOR = Color3.fromRGB(255, 214, 90)
local TRACER_COLOR = Color3.fromRGB(255, 236, 170)
local FLASH_COLOR = Color3.fromRGB(255, 200, 110)

type Tracer = { Part: BasePart, BornAt: number, Live: boolean }

local folder: Folder? = nil
local flash: BasePart? = nil
local flashLight: PointLight? = nil
local flashAt = -math.huge
local tracers: { Tracer } = {}
local sparks: { Spark } = {}
local sparkFree: { BasePart } = {}
local sound: Sound? = nil
local nextTracer = 1

local ShotEffects = {
	POOL = POOL,
	CONFIRM_TIME = CONFIRM_TIME,
	FADE_TIME = FADE_TIME,
}

local function part(name: string, shape: Enum.PartType, color: Color3): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.one
	p.CFrame = PARK
	p.Parent = folder
	return p
end

function ShotEffects.init()
	if folder then
		return
	end
	local f = Instance.new("Folder")
	f.Name = CONTAINER
	f.Parent = workspace
	folder = f
	local fp = part("Flash", Enum.PartType.Ball, FLASH_COLOR)
	fp.Size = Vector3.one * 0.9
	local light = Instance.new("PointLight")
	light.Color = FLASH_COLOR
	light.Range = 10
	light.Brightness = 3
	light.Enabled = false
	light.Parent = fp
	flash, flashLight = fp, light
	for i = 1, POOL do
		table.insert(tracers, { Part = part(`Tracer{i}`, Enum.PartType.Block, TRACER_COLOR), BornAt = 0, Live = false })
		table.insert(sparkFree, part(`Spark{i}`, Enum.PartType.Ball, PREDICTED_COLOR))
	end
	local s = Instance.new("Sound")
	s.Name = "Shot"
	s.SoundId = SHOT_SOUND
	s.Volume = SHOT_VOLUME
	s.Parent = SoundService
	sound = s
end

function ShotEffects.container(): Folder?
	return folder
end

function ShotEffects.shot(muzzle: Vector3, endPoint: Vector3)
	local now = os.clock()
	local fp, light = flash, flashLight
	if fp and light then
		fp.CFrame = CFrame.new(muzzle)
		fp.Transparency = 0
		light.Enabled = true
		flashAt = now
	end
	local tracer = tracers[nextTracer]
	if tracer then
		nextTracer = nextTracer % #tracers + 1
		local length = (endPoint - muzzle).Magnitude
		if length > 0.05 then
			tracer.Part.Size = Vector3.new(0.12, 0.12, length)
			tracer.Part.CFrame = CFrame.lookAt((muzzle + endPoint) / 2, endPoint)
			tracer.Part.Transparency = 0.15
			tracer.BornAt = now
			tracer.Live = true
		end
	end
	local s = sound
	if s then
		SoundService:PlayLocalSound(s)
	end
end

function ShotEffects.spark(position: Vector3): Spark?
	local p = table.remove(sparkFree)
	if p == nil then
		return nil
	end
	p.Color = PREDICTED_COLOR
	p.Size = Vector3.one * PREDICTED_SIZE
	p.Transparency = 0.05
	p.CFrame = CFrame.new(position)
	local now = os.clock()
	local spark: Spark = { Part = p, BornAt = now, Mode = "Predicted", ModeAt = now, Crit = false }
	table.insert(sparks, spark)
	return spark
end

function ShotEffects.confirm(spark: Spark, crit: boolean)
	if spark.Mode ~= "Predicted" then
		return
	end
	spark.Mode = "Confirmed"
	spark.ModeAt = os.clock()
	spark.Crit = crit
	spark.Part.Color = if crit then CRIT_COLOR else CONFIRM_COLOR
end

function ShotEffects.fade(spark: Spark)
	if spark.Mode ~= "Predicted" then
		return
	end
	spark.Mode = "Fading"
	spark.ModeAt = os.clock()
end

function ShotEffects.step(now: number)
	local fp, light = flash, flashLight
	if fp and light and light.Enabled and now - flashAt >= FLASH_TIME then
		fp.CFrame = PARK
		light.Enabled = false
	end
	for _, tracer in tracers do
		if tracer.Live then
			local age = now - tracer.BornAt
			if age >= TRACER_TIME then
				tracer.Live = false
				tracer.Part.CFrame = PARK
			else
				tracer.Part.Transparency = 0.15 + 0.85 * age / TRACER_TIME
			end
		end
	end
	for i = #sparks, 1, -1 do
		local spark = sparks[i]
		local p = spark.Part
		local age = now - spark.ModeAt
		local done = false
		if spark.Mode == "Predicted" then
			p.Size = Vector3.one * PREDICTED_SIZE * (1 + 0.15 * math.sin(age * 40))
		elseif spark.Mode == "Confirmed" then
			local k = math.min(1, age / CONFIRM_TIME)
			p.Size = Vector3.one * PREDICTED_SIZE * (1.8 - 0.6 * k) * (if spark.Crit then 1.3 else 1)
			p.Transparency = k
			done = k >= 1
		else
			local k = math.min(1, age / FADE_TIME)
			p.Size = Vector3.one * PREDICTED_SIZE * (1 - 0.6 * k)
			p.Transparency = 0.05 + 0.95 * k
			done = k >= 1
		end
		if done then
			p.CFrame = PARK
			sparks[i] = sparks[#sparks]
			sparks[#sparks] = nil
			table.insert(sparkFree, p)
		end
	end
end

return table.freeze(ShotEffects)
