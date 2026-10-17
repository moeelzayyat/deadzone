--!strict
-- Render/EnemyRenderer (architecture §6.4, §8.1, §22, §23): draws the enemies EnemyController knows about. Every frame,
-- after the camera, it feeds new snapshot samples into one SnapshotInterpolation track per enemy, samples every track
-- DELAY behind the newest snapshot, poses each enemy procedurally (EnemyPose) and moves all parts of all rigs with one
-- workspace:BulkMoveTo. Rigs come from a RigPool (placeholder primitives, EnemyRigs); enemies are never Humanoids.
-- Presentation only: nothing here goes back to the server.
-- Despawn policy (A2.4):
--   1. An enemy that is missing from EnemyController's view, or whose last packet is older than STALE_SECONDS, leaves:
--      its rig sinks into the floor over EnemyPose.DESPAWN_TIME at its last pose, then goes back to the pool.
--   2. An id whose definition changes (an id reused by the server) leaves and comes back as a new enemy.
--   3. At most MAX_RIGS rigs are drawn; enemies beyond that wait for a free rig. At most BUILDS_PER_FRAME new rigs are
--      built per frame (pooled rigs are free), so a wave arriving at once never builds 90 rigs in one frame.
--   4. Every TRIM_EVERY seconds the pool destroys parked rigs beyond POOL_KEEP per definition idle for POOL_IDLE seconds.
-- Level of detail: a rig outside the camera view (plus a margin) updates every OFFSCREEN_EVERY frames, a rig farther
-- than FAR studs from the camera every other frame, the rest every frame. Each enemy's walk cycle advances by the
-- distance it moved, so a skipped frame never desyncs feet and ground.
-- Measuring (A2.4): the container `Workspace.ClientEnemies` carries attributes refreshed every STATS_EVERY seconds
-- (counts are cumulative; probes take differences). Setting its attribute `EmulateCpuScale` to k > 1 makes each frame's
-- render work take k times as long (busy wait), the CPU part of the low-end emulation (D-026).
--   EnemyRenderer.stats() → Stats

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EnemyController = require(script.Parent.Parent.Controllers.EnemyController)
local Lib = script.Parent.Lib
local SnapshotInterpolation = require(Lib.SnapshotInterpolation)
local EnemyPose = require(Lib.EnemyPose)
local EnemyRigs = require(Lib.EnemyRigs)
local RigPool = require(Lib.RigPool)

local CONTAINER = "ClientEnemies"
local STALE_SECONDS = 1 -- EnemyController forgets an enemy after the same time
local MAX_RIGS = 160
local BUILDS_PER_FRAME = 6
local PREWARM = 24 -- rigs built ahead per fodder definition at start, BUILDS_PER_FRAME per frame (not refilled)
local TRIM_EVERY = 5
local POOL_KEEP = 24
local POOL_IDLE = 30
local FAR = 110
local OFFSCREEN_EVERY = 6
local SCREEN_MARGIN = 0.15
local STATS_EVERY = 0.5
local WORK_WINDOW = 600 -- frames kept for the work percentiles
local UP = Vector3.new(0, 3, 0)
local TAU = 2 * math.pi
local DEFAULT_MOVE_SPEED = 8
local DEFAULT_TELEGRAPH = 0.4

type Entry = {
	Id: number,
	DefId: string,
	Spec: EnemyRigs.Spec,
	Track: SnapshotInterpolation.Track,
	MoveSpeed: number,
	TelegraphTime: number,
	Seed: number,
	PushedT: number,
	Seen: number,
	Rig: RigPool.Rig?,
	Phase: number,
	Speed: number,
	Last: Vector3?,
	LastAt: number,
	Root: CFrame?,
	GoneAt: number,
}

export type Stats = {
	Frames: number,
	Enemies: number,
	Rigs: number,
	Parked: number,
	Leaving: number,
	Built: number,
	Reused: number,
	Destroyed: number,
	WorkAvgMs: number, -- over the last WORK_WINDOW frames
	WorkP99Ms: number,
	WorkMaxMs: number,
	DelayMs: number,
	Interpolated: number, -- enemy-frames drawn, by sampling mode (cumulative)
	Extrapolated: number,
	Held: number,
	Snaps: number, -- deliberate cuts drawn (server teleports)
	Jumps: number, -- draws that moved faster than twice the definition's speed without being a cut
	MaxSpeedRatio: number, -- largest drawn speed / definition MoveSpeed since the last publish (STATS_EVERY)
	MaxSpeedRatioAll: number, -- the same since start
	CpuScale: number,
}

local entries: { [number]: Entry } = {}
local leaving: { Entry } = {}
local clock = SnapshotInterpolation.newClock()
local pool: RigPool.Pool? = nil
local container: Folder? = nil
local pose = EnemyPose.newPose()
local poseInput: EnemyPose.Input = { State = "Pursue", Age = 0, TelegraphTime = 0.4, Phase = 0, Speed = 0, Time = 0 }
local parts: { BasePart } = {}
local frames: { CFrame } = {}
local defCache: { [string]: { MoveSpeed: number, TelegraphTime: number } } = {}
local prewarmQueue: { string } = {}
local prewarmed: { [string]: number } = {}
local activeRigs = 0
local sampled: SnapshotInterpolation.Result = {
	Position = Vector3.zero,
	Yaw = 0,
	State = "Pursue",
	Since = 0,
	Mode = "Hold",
}
local work: { number } = table.create(WORK_WINDOW, 0)
local workCount = 0
local frame = 0
local nextSeed = 0
local lastT, lastArrival = -math.huge, -math.huge
local lastTrim, lastStats = 0, 0
local cpuScale = 1
local counts = { Interpolated = 0, Extrapolated = 0, Held = 0, Snaps = 0, Jumps = 0, MaxSpeedRatio = 0, MaxSpeedRatioAll = 0 }
local started = false

local EnemyRenderer = { Name = "EnemyRenderer" }

local function definition(defId: string): { MoveSpeed: number, TelegraphTime: number }
	local cached = defCache[defId]
	if cached then
		return cached
	end
	local moveSpeed, telegraph = DEFAULT_MOVE_SPEED, DEFAULT_TELEGRAPH
	local folder = ReplicatedStorage.Shared.Definitions:FindFirstChild("Enemies")
	local module = folder and folder:FindFirstChild(defId)
	if module and module:IsA("ModuleScript") then
		local ok, def = pcall(require, module)
		if ok and typeof(def) == "table" then
			local d = def :: any
			if typeof(d.MoveSpeed) == "number" and d.MoveSpeed > 0 then
				moveSpeed = d.MoveSpeed
			end
			if typeof(d.Attack) == "table" and typeof(d.Attack.TelegraphTime) == "number" then
				telegraph = d.Attack.TelegraphTime
			end
		end
	end
	local fresh = { MoveSpeed = moveSpeed, TelegraphTime = telegraph }
	defCache[defId] = fresh
	return fresh
end

local function newEntry(view: EnemyController.View): Entry
	local def = definition(view.DefId)
	nextSeed += 1
	return {
		Id = view.Id,
		DefId = view.DefId,
		Spec = EnemyRigs.spec(view.DefId),
		Track = SnapshotInterpolation.newTrack(),
		MoveSpeed = def.MoveSpeed,
		TelegraphTime = def.TelegraphTime,
		Seed = nextSeed,
		PushedT = -math.huge,
		Seen = 0,
		Rig = nil,
		Phase = (nextSeed * 2.399) % TAU, -- golden-angle offsets so neighbours never walk in step
		Speed = 0,
		Last = nil,
		LastAt = 0,
		Root = nil,
		GoneAt = 0,
	}
end

local function leave(entry: Entry, now: number)
	entry.GoneAt = now
	table.insert(leaving, entry)
end

local function percentile(sorted: { number }, p: number): number
	local n = #sorted
	if n == 0 then
		return 0
	end
	return sorted[math.clamp(math.ceil(n * p), 1, n)]
end

function EnemyRenderer.stats(): Stats
	local n = math.min(workCount, WORK_WINDOW)
	local sorted = table.move(work, 1, n, 1, table.create(n))
	table.sort(sorted)
	local total = 0
	for _, v in sorted do
		total += v
	end
	local enemies = 0
	for _ in entries do
		enemies += 1
	end
	local poolStats = if pool then pool:stats() else nil
	return {
		Frames = frame,
		Enemies = enemies,
		Rigs = if poolStats then poolStats.Active else 0,
		Parked = if poolStats then poolStats.Parked else 0,
		Leaving = #leaving,
		Built = if poolStats then poolStats.Built else 0,
		Reused = if poolStats then poolStats.Reused else 0,
		Destroyed = if poolStats then poolStats.Destroyed else 0,
		WorkAvgMs = if n > 0 then total / n * 1000 else 0,
		WorkP99Ms = percentile(sorted, 0.99) * 1000,
		WorkMaxMs = (sorted[n] or 0) * 1000,
		DelayMs = SnapshotInterpolation.delay(clock) * 1000,
		Interpolated = counts.Interpolated,
		Extrapolated = counts.Extrapolated,
		Held = counts.Held,
		Snaps = counts.Snaps,
		Jumps = counts.Jumps,
		MaxSpeedRatio = counts.MaxSpeedRatio,
		MaxSpeedRatioAll = counts.MaxSpeedRatioAll,
		CpuScale = cpuScale,
	}
end

local function publish()
	local folder = container
	if folder == nil then
		return
	end
	for key, value in EnemyRenderer.stats() :: any do
		folder:SetAttribute(key, value)
	end
	counts.MaxSpeedRatio = 0
end

-- Poses one enemy at `root` and appends its parts and CFrames; returns the next index.
local function draw(entry: Entry, rig: RigPool.Rig, root: CFrame, at: number): number
	for i, part in rig.Parts do
		parts[at + i - 1] = part
	end
	return EnemyRigs.compose(entry.Spec, root, pose, frames, at)
end

local function ingest(now: number)
	local views = EnemyController.enemies()
	for id, view in views do
		if now - view.SeenAt > STALE_SECONDS then
			continue
		end
		local old: Entry? = entries[id]
		if old and old.DefId ~= view.DefId then
			entries[id] = nil
			leave(old, now)
			old = nil
		end
		local e: Entry = old or newEntry(view)
		entries[id] = e
		if view.T ~= e.PushedT then
			if view.T ~= lastT or view.SeenAt ~= lastArrival then
				lastT, lastArrival = view.T, view.SeenAt
				SnapshotInterpolation.observe(clock, view.T, view.SeenAt)
			end
			SnapshotInterpolation.push(e.Track, view.T, view.Position, view.Yaw, view.State)
			e.PushedT = view.T
		end
		e.Seen = frame
	end
	for id, entry in entries do
		if entry.Seen ~= frame then
			entries[id] = nil
			leave(entry, now)
		end
	end
end

local function step(dt: number)
	local started0 = os.clock()
	local now = started0
	frame += 1
	local p = pool :: RigPool.Pool
	ingest(now)

	local camera = workspace.CurrentCamera
	local camPos = if camera then camera.CFrame.Position else Vector3.zero
	local viewport = if camera then camera.ViewportSize else Vector2.zero
	local mx, my = viewport.X * SCREEN_MARGIN, viewport.Y * SCREEN_MARGIN
	local renderT = SnapshotInterpolation.renderTime(clock, now)
	table.clear(parts)
	table.clear(frames)
	local at = 1
	local builds = 0

	-- build a few rigs ahead per frame until each fodder definition has PREWARM
	while #prewarmQueue > 0 and builds < BUILDS_PER_FRAME do
		local defId = prewarmQueue[#prewarmQueue]
		local done = prewarmed[defId] or 0
		if done >= PREWARM then
			table.remove(prewarmQueue)
		else
			builds += p:prewarm(defId, p:parked(defId) + 1)
			prewarmed[defId] = done + 1
		end
	end

	for _, e in entries do
		if SnapshotInterpolation.sample(e.Track, renderT, sampled) == nil then
			continue
		end
		local rig = e.Rig
		if rig == nil then
			if activeRigs >= MAX_RIGS then
				continue
			end
			if p:parked(e.Spec.Id) == 0 then
				if builds >= BUILDS_PER_FRAME then
					continue
				end
				builds += 1
			end
			rig = p:acquire(e.Spec.Id)
			e.Rig = rig
			activeRigs += 1
		end
		local position = sampled.Position
		local every = 1
		if camera then
			local screen, inFront = camera:WorldToViewportPoint(position + UP)
			if not inFront or screen.X < -mx or screen.X > viewport.X + mx or screen.Y < -my or screen.Y > viewport.Y + my then
				every = OFFSCREEN_EVERY
			elseif (position - camPos).Magnitude > FAR then
				every = 2
			end
		end
		local last = e.Last
		if last and (frame + e.Seed) % every ~= 0 then
			continue
		end
		local elapsed = if last then now - e.LastAt else dt
		local moved = 0
		if last then
			local d = position - last
			moved = math.sqrt(d.X * d.X + d.Z * d.Z)
			if moved > SnapshotInterpolation.TELEPORT then
				counts.Snaps += 1
				moved = 0
			elseif elapsed > 0 and every == 1 then
				local ratio = moved / (e.MoveSpeed * elapsed)
				if ratio > counts.MaxSpeedRatio then
					counts.MaxSpeedRatio = ratio
				end
				if ratio > counts.MaxSpeedRatioAll then
					counts.MaxSpeedRatioAll = ratio
				end
				if ratio > 2 and moved > 0.25 then
					counts.Jumps += 1
				end
			end
		end
		if sampled.Mode == "Interpolate" then
			counts.Interpolated += 1
		elseif sampled.Mode == "Extrapolate" then
			counts.Extrapolated += 1
		else
			counts.Held += 1
		end
		local speed = moved / math.max(elapsed, 1 / 240)
		e.Speed += (speed - e.Speed) * math.min(1, elapsed * 8)
		e.Phase = (e.Phase + TAU * moved / e.Spec.Style.Stride) % TAU
		poseInput.State = sampled.State
		poseInput.Age = renderT - sampled.Since
		poseInput.TelegraphTime = e.TelegraphTime
		poseInput.Phase = e.Phase
		poseInput.Speed = e.Speed / e.MoveSpeed
		poseInput.Time = now + e.Seed * 0.37
		EnemyPose.compute(e.Spec.Style, poseInput, pose)
		local root = CFrame.new(position) * CFrame.Angles(0, sampled.Yaw, 0)
		at = draw(e, rig :: RigPool.Rig, root, at)
		e.Root = root
		e.Last = position
		e.LastAt = now
	end

	for i = #leaving, 1, -1 do
		local e = leaving[i]
		local age = now - e.GoneAt
		local rig, root = e.Rig, e.Root
		if rig == nil or root == nil or age >= EnemyPose.DESPAWN_TIME then
			if rig then
				p:release(rig)
				e.Rig = nil
				activeRigs -= 1
			end
			leaving[i] = leaving[#leaving]
			leaving[#leaving] = nil
			continue
		end
		poseInput.State = "Despawn"
		poseInput.Age = age
		poseInput.Phase = e.Phase
		poseInput.Speed = 0
		poseInput.Time = now
		EnemyPose.compute(e.Spec.Style, poseInput, pose)
		at = draw(e, rig, root, at)
	end

	if at > 1 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end

	if now - lastTrim >= TRIM_EVERY then
		lastTrim = now
		p:trim(now, POOL_KEEP, POOL_IDLE)
	end

	local spent = os.clock() - started0
	workCount += 1
	work[(workCount - 1) % WORK_WINDOW + 1] = spent
	if now - lastStats >= STATS_EVERY then
		lastStats = now
		local scale = if container then container:GetAttribute("EmulateCpuScale") else nil
		cpuScale = if typeof(scale) == "number" and scale >= 1 then scale else 1
		publish()
	end
	if cpuScale > 1 then
		local untilAt = started0 + spent * cpuScale
		while os.clock() < untilAt do
			-- busy wait: emulated slower CPU (D-026)
		end
	end
end

function EnemyRenderer.start()
	if started then
		return
	end
	started = true
	local folder = workspace:FindFirstChild(CONTAINER)
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = CONTAINER
		created.Parent = workspace
		folder = created
	end
	container = folder :: Folder
	pool = RigPool.new(folder :: Folder, function(defId: string): (Model, { BasePart })
		return EnemyRigs.build(EnemyRigs.spec(defId))
	end)
	for _, defId in { "Runner", "Walker" } do
		table.insert(prewarmQueue, defId)
	end
	RunService:BindToRenderStep("DZ_Enemies", Enum.RenderPriority.Camera.Value + 2, step)
	print(`[Render] EnemyRenderer on for {Players.LocalPlayer.Name} (pool prewarm {PREWARM} per fodder rig)`)
end

return table.freeze(EnemyRenderer)
