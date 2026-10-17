--!strict
-- Render/Lib/EnemyPose (architecture §8.1 "locally driven animations", §22 procedural animation for A1–A3): the
-- code-driven body pose of one enemy for one frame, from its state, the time in that state and its walk cycle. Pure
-- math, no Instances, so the server-side TestRunner covers it (A2.4). EnemyRigs turns a pose into part CFrames.
-- Angles in radians. A joint rotation about X that is positive swings a hanging limb forward (toward -Z); `Lean` is a
-- forward tilt of the upper body. States (EnemySnapshot.STATES) plus the renderer's own "Despawn":
--   Spawn      rises out of the floor over SPAWN_TIME, arms up first (the server's Spawn lasts 0.6 s)
--   Pursue     walk cycle: legs swing, body bobs and sways; amplitude follows speed (0 = idle sway)
--   Telegraph  rears back and raises the arms over the definition's TelegraphTime, with a shake
--   Attack     lunges forward and swipes the arms down (ATTACK_TIME, the server's Attack lasts 0.2 s)
--   Recover    eases from the lunge back into the walk over RECOVER_TIME
--   Stagger    knocked back (A2.5 sets this state)
--   Dying      topples backward and sinks (A2.5)
--   Despawn    sinks into the floor over DESPAWN_TIME (an enemy that left the snapshots, see EnemyRenderer)
--   EnemyPose.compute(style, input, out) → out       fills and returns a Pose (reuse `out` to avoid garbage)

export type Style = {
	Lean: number, -- forward tilt of the upper body while walking
	ArmPitch: number, -- arm angle against the upper body while walking (+ forward); the world angle is ArmPitch - Lean
	ArmSwing: number, -- arm swing amplitude in the walk cycle
	Swing: number, -- leg swing amplitude at full speed
	Stride: number, -- studs per full walk cycle
	Bob: number, -- studs of body bob at full speed
	Height: number, -- studs, used to sink fully below the floor
}

export type Input = {
	State: string,
	Age: number, -- seconds in the state (render time - Since)
	TelegraphTime: number,
	Phase: number, -- walk cycle angle
	Speed: number, -- 0..1.2, share of the definition's MoveSpeed
	Time: number, -- free-running seconds for shakes
}

export type Pose = {
	Lift: number, -- studs added to the root's height
	Forward: number, -- studs the root moves along its facing
	Body: CFrame, -- upper body rotation at the hip pivot
	Head: CFrame,
	ArmL: CFrame,
	ArmR: CFrame,
	LegL: CFrame,
	LegR: CFrame,
}

local SPAWN_TIME = 0.6
local SPAWN_DEPTH = 1.4 -- × Height below the floor at the start of Spawn, so raised hands are hidden too
local ATTACK_TIME = 0.2
local RECOVER_TIME = 0.35
local STAGGER_TIME = 0.3
local DYING_TIME = 0.5
local DESPAWN_TIME = 0.35
local ARMS_UP = math.rad(150)

local EnemyPose = {
	SPAWN_TIME = SPAWN_TIME,
	SPAWN_DEPTH = SPAWN_DEPTH,
	ATTACK_TIME = ATTACK_TIME,
	RECOVER_TIME = RECOVER_TIME,
	DESPAWN_TIME = DESPAWN_TIME,
	DYING_TIME = DYING_TIME,
}

local function clamp01(x: number): number
	return if x < 0 then 0 elseif x > 1 then 1 else x
end

local function easeOut(u: number): number
	return 1 - (1 - u) * (1 - u)
end

local function lerp(a: number, b: number, u: number): number
	return a + (b - a) * u
end

function EnemyPose.newPose(): Pose
	local identity = CFrame.identity
	return {
		Lift = 0,
		Forward = 0,
		Body = identity,
		Head = identity,
		ArmL = identity,
		ArmR = identity,
		LegL = identity,
		LegR = identity,
	}
end

function EnemyPose.compute(style: Style, input: Input, out: Pose): Pose
	local state, age = input.State, math.max(input.Age, 0)
	local speed = math.clamp(input.Speed, 0, 1.2)
	local s = math.sin(input.Phase)
	local swing = style.Swing * speed * s
	local lean = style.Lean
	local roll = math.sin(input.Phase) * 0.06 * speed + math.sin(input.Time * 1.7) * 0.03
	local armL = style.ArmPitch - style.ArmSwing * speed * s
	local armR = style.ArmPitch + style.ArmSwing * speed * s
	local headPitch = lean * 0.6 -- the head looks up toward the target while the body leans
	local lift = math.abs(math.cos(input.Phase)) * style.Bob * speed
	local forward = 0
	local legL, legR = swing, -swing

	if state == "Spawn" then
		local u = clamp01(age / SPAWN_TIME)
		lift = -(1 - easeOut(u)) * style.Height * SPAWN_DEPTH
		local flail = math.sin(input.Time * 18) * 0.25 * (1 - u)
		armL, armR = lerp(ARMS_UP, armL, u) + flail, lerp(ARMS_UP, armR, u) - flail
		lean = lerp(-0.2, lean, u)
		legL, legR = 0, 0
	elseif state == "Telegraph" then
		local u = clamp01(age / math.max(input.TelegraphTime, 0.05))
		local shake = math.sin(input.Time * 45) * 0.05 * u
		lean = lerp(lean, -0.25, easeOut(u))
		roll += shake
		armL, armR = lerp(armL, ARMS_UP, easeOut(u)), lerp(armR, ARMS_UP, easeOut(u))
		headPitch = lerp(headPitch, 0.35, u) -- head thrown back: the roar before the swing
		legL, legR = legL * (1 - u), legR * (1 - u)
		lift *= 1 - u
	elseif state == "Attack" then
		local u = clamp01(age / ATTACK_TIME)
		forward = math.sin(u * math.pi) * 1.5
		lean = lerp(-0.25, style.Lean + 0.5, easeOut(u))
		local arm = lerp(ARMS_UP, math.rad(40), easeOut(u))
		armL, armR = arm, arm
		legL, legR = -0.35 * u, 0.25 * u
		lift = 0
	elseif state == "Recover" then
		local u = easeOut(clamp01(age / RECOVER_TIME))
		lean = lerp(style.Lean + 0.5, lean, u)
		armL, armR = lerp(math.rad(40), armL, u), lerp(math.rad(40), armR, u)
		legL, legR = lerp(-0.35, legL, u), lerp(0.25, legR, u)
		lift *= u
	elseif state == "Stagger" then
		local u = clamp01(age / STAGGER_TIME)
		local k = math.sin(u * math.pi)
		lean = lerp(lean, -0.5, k)
		armL, armR = lerp(armL, math.rad(100), k), lerp(armR, math.rad(60), k)
		forward = -0.8 * k
		lift = 0
	elseif state == "Dying" then
		local u = clamp01(age / DYING_TIME)
		lean = lerp(lean, -1.4, easeOut(u))
		lift = -u * u * style.Height * 0.5
		armL, armR = lerp(armL, ARMS_UP, u), lerp(armR, ARMS_UP, u)
		legL, legR = 0, 0
	elseif state == "Despawn" then
		local u = clamp01(age / DESPAWN_TIME)
		lift = -easeOut(u) * style.Height
		legL, legR = 0, 0
	end

	out.Lift = lift
	out.Forward = forward
	out.Body = CFrame.Angles(-lean, 0, roll)
	out.Head = CFrame.Angles(headPitch, 0, 0)
	out.ArmL = CFrame.Angles(armL, 0, 0)
	out.ArmR = CFrame.Angles(armR, 0, 0)
	out.LegL = CFrame.Angles(legL, 0, 0)
	out.LegR = CFrame.Angles(legR, 0, 0)
	return out
end

return table.freeze(EnemyPose)
