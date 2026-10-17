--!strict
-- Render/Lib/EnemyRigs (architecture §8.1, §22; ART_BIBLE silhouette table): placeholder enemy models built from
-- primitives (A1–A3 sourcing plan), one spec per enemy definition, and the pose → part CFrame math. Enemies are never
-- Humanoids: a rig is a Model of anchored parts that collide with nothing, cast no ray hits and touch nothing; the
-- renderer moves every part each frame with one workspace:BulkMoveTo call.
--   Walker  6–7 studs, hunched 25°, both arms straight forward; gray-green skin, dull cloth, green eyes
--   Runner  thin, leaning 45°, long stride, arms trailing; same skin, less cloth
--   Default any other enemy until it gets its own spec (a gray box figure)
-- A spec's parts hang off six joints: Body (the hip pivot, upper body), Head (neck on the body), ArmL/ArmR (shoulders on
-- the body), LegL/LegR (hips on the root). The root is the enemy's feet on the floor, facing -Z after its yaw.
--   EnemyRigs.spec(defId) → Spec                     (Default when the definition has no spec)
--   EnemyRigs.build(spec) → Model, { BasePart }      parts in spec.Parts order
--   EnemyRigs.compose(spec, root, pose, out, at) → next index   writes one CFrame per part into out[at..]

local EnemyPose = require(script.Parent.EnemyPose)

export type Joint = "Body" | "Head" | "ArmL" | "ArmR" | "LegL" | "LegR"

export type PartSpec = {
	Name: string,
	Joint: Joint,
	Size: Vector3,
	Offset: CFrame, -- from the joint to the part's center
	Color: Color3,
	Material: Enum.Material,
	Shadow: boolean,
}

export type Spec = {
	Id: string,
	HipHeight: number, -- feet to the hip pivot
	HipSpread: number, -- hip pivot to each leg, sideways
	Neck: Vector3, -- body pivot to the neck
	Shoulder: Vector3, -- body pivot to the right shoulder (the left one is mirrored)
	Style: EnemyPose.Style,
	Parts: { PartSpec },
}

local SKIN = Color3.fromRGB(122, 140, 108)
local SKIN_DARK = Color3.fromRGB(104, 121, 92)
local CLOTH = Color3.fromRGB(88, 84, 74)
local CLOTH_DARK = Color3.fromRGB(62, 64, 70)
local EYES = Color3.fromRGB(140, 255, 80)
local PLAIN = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon

local function part(
	name: string,
	joint: Joint,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?,
	shadow: boolean?
): PartSpec
	return {
		Name = name,
		Joint = joint,
		Size = size,
		Offset = offset,
		Color = color,
		Material = material or PLAIN,
		Shadow = shadow == true,
	}
end

-- Torso, head, two eyes, two arms, two legs: the same eight parts in the same order for every spec.
local function figure(o: {
	Id: string,
	Leg: Vector3,
	HipSpread: number,
	Torso: Vector3,
	Head: Vector3,
	Arm: Vector3,
	TorsoColor: Color3,
	LegColor: Color3,
	Style: EnemyPose.Style,
}): Spec
	local legH, torsoH, headH = o.Leg.Y, o.Torso.Y, o.Head.Y
	local shoulder = Vector3.new(o.Torso.X / 2 + o.Arm.X / 2, torsoH - o.Arm.X / 2, 0)
	local eyeX, eyeY, eyeZ = o.Head.X * 0.22, headH * 0.6, -(o.Head.Z / 2 + 0.1)
	local eye = Vector3.new(0.35, 0.3, 0.3)
	return {
		Id = o.Id,
		HipHeight = legH,
		HipSpread = o.HipSpread,
		Neck = Vector3.new(0, torsoH, 0),
		Shoulder = shoulder,
		Style = o.Style,
		Parts = {
			part("Torso", "Body", o.Torso, CFrame.new(0, torsoH / 2, 0), o.TorsoColor, nil, true),
			part("Head", "Head", o.Head, CFrame.new(0, headH / 2, 0), SKIN, nil, true),
			part("EyeL", "Head", eye, CFrame.new(-eyeX, eyeY, eyeZ), EYES, NEON),
			part("EyeR", "Head", eye, CFrame.new(eyeX, eyeY, eyeZ), EYES, NEON),
			part("ArmL", "ArmL", o.Arm, CFrame.new(0, -o.Arm.Y / 2 + o.Arm.X / 2, 0), SKIN),
			part("ArmR", "ArmR", o.Arm, CFrame.new(0, -o.Arm.Y / 2 + o.Arm.X / 2, 0), SKIN),
			part("LegL", "LegL", o.Leg, CFrame.new(0, -legH / 2, 0), o.LegColor),
			part("LegR", "LegR", o.Leg, CFrame.new(0, -legH / 2, 0), o.LegColor),
		},
	}
end

local SPECS: { [string]: Spec } = {
	Walker = figure({
		Id = "Walker",
		Leg = Vector3.new(0.9, 2.8, 0.9),
		HipSpread = 0.55,
		Torso = Vector3.new(2.2, 2.4, 1.2),
		Head = Vector3.new(1.5, 1.4, 1.4),
		Arm = Vector3.new(0.8, 2.6, 0.8),
		TorsoColor = CLOTH,
		LegColor = CLOTH_DARK,
		Style = {
			Lean = math.rad(25),
			ArmPitch = math.rad(115), -- straight forward in the world: 115° against a body leaning 25°
			ArmSwing = 0.12,
			Swing = 0.45,
			Stride = 3.5,
			Bob = 0.2,
			Height = 6.6,
		},
	}),
	Runner = figure({
		Id = "Runner",
		Leg = Vector3.new(0.7, 3.2, 0.7),
		HipSpread = 0.42,
		Torso = Vector3.new(1.5, 2.3, 0.9),
		Head = Vector3.new(1.2, 1.2, 1.2),
		Arm = Vector3.new(0.6, 2.6, 0.6),
		TorsoColor = SKIN_DARK,
		LegColor = CLOTH,
		Style = {
			Lean = math.rad(45),
			ArmPitch = math.rad(-25), -- trailing: 70° behind the vertical with the body leaning 45°
			ArmSwing = 0.5,
			Swing = 0.9,
			Stride = 7,
			Bob = 0.35,
			Height = 6.7,
		},
	}),
	Default = figure({
		Id = "Default",
		Leg = Vector3.new(1, 2.8, 1),
		HipSpread = 0.6,
		Torso = Vector3.new(2.2, 2.4, 1.2),
		Head = Vector3.new(1.4, 1.4, 1.4),
		Arm = Vector3.new(0.8, 2.4, 0.8),
		TorsoColor = Color3.fromRGB(110, 110, 110),
		LegColor = Color3.fromRGB(80, 80, 80),
		Style = {
			Lean = math.rad(10),
			ArmPitch = math.rad(30),
			ArmSwing = 0.3,
			Swing = 0.5,
			Stride = 4,
			Bob = 0.2,
			Height = 6.6,
		},
	}),
}
for _, spec in SPECS do
	table.freeze(spec.Parts)
	table.freeze(spec.Style)
	table.freeze(spec)
end

local EnemyRigs = { PART_COUNT = 8 }
local joints: { [string]: CFrame } = {} -- reused by compose (one frame's joints at a time)

function EnemyRigs.spec(defId: string): Spec
	return SPECS[defId] or SPECS.Default
end

function EnemyRigs.has(defId: string): boolean
	return SPECS[defId] ~= nil
end

function EnemyRigs.build(spec: Spec): (Model, { BasePart })
	local model = Instance.new("Model")
	model.Name = spec.Id
	local parts: { BasePart } = table.create(#spec.Parts)
	for i, p in spec.Parts do
		local instance = Instance.new("Part")
		instance.Name = p.Name
		instance.Size = p.Size
		instance.Color = p.Color
		instance.Material = p.Material
		instance.TopSurface = Enum.SurfaceType.Smooth
		instance.BottomSurface = Enum.SurfaceType.Smooth
		instance.Anchored = true
		instance.CanCollide = false
		instance.CanQuery = false
		instance.CanTouch = false
		instance.CastShadow = p.Shadow
		instance.Locked = true
		instance.Parent = model
		parts[i] = instance
	end
	return model, parts
end

-- Writes the part CFrames of one enemy whose feet are at `root` (position + yaw) into out[at..]; returns the next index.
function EnemyRigs.compose(spec: Spec, root: CFrame, pose: EnemyPose.Pose, out: { CFrame }, at: number): number
	local base = root * CFrame.new(0, pose.Lift, -pose.Forward)
	local hip = spec.HipHeight
	local body = base * CFrame.new(0, hip, 0) * pose.Body
	local shoulder = spec.Shoulder
	joints.Body = body
	joints.Head = body * CFrame.new(spec.Neck) * pose.Head
	joints.ArmL = body * CFrame.new(-shoulder.X, shoulder.Y, shoulder.Z) * pose.ArmL
	joints.ArmR = body * CFrame.new(shoulder.X, shoulder.Y, shoulder.Z) * pose.ArmR
	joints.LegL = base * CFrame.new(-spec.HipSpread, hip, 0) * pose.LegL
	joints.LegR = base * CFrame.new(spec.HipSpread, hip, 0) * pose.LegR
	for _, p in spec.Parts do
		out[at] = joints[p.Joint] * p.Offset
		at += 1
	end
	return at
end

return table.freeze(EnemyRigs)
