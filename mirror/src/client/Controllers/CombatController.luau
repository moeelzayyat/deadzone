--!strict
-- Controllers/CombatController (architecture §7.1, §7.2, §23; docs/API_CONTRACTS.md RequestAttack, ClientHeartbeat,
-- CombatResult): the client half of the primary attack with prediction (A2.5).
--   · Firing: while InputController reports Primary (held, or auto-fire), the class's starter weapon fires at its
--     Cooldown. The first shot of a press goes out in the render step of the frame that handled the input (DZ_Combat runs
--     right after DZ_Input; the Primary action may arrive deferred, so the step fires too).
--   · Prediction, same frame: muzzle flash, tracer and shot sound (Effects/ShotEffects); if the shot passes through an
--     enemy as it is drawn on screen (Render/EnemyRenderer.drawn, Util/HitScan, arena geometry by raycast) an orange
--     predicted spark appears on it. No damage number: that is the server's to say.
--   · Intent to the server: RequestAttack { Seq, T, Origin, Dir, TargetHint } where T is the SimulationClock time of the
--     enemies on screen (EnemyRenderer.renderTime) and TargetHint the enemy the spark is on. Nothing else.
--   · Truth from the server: CombatResult (per tick, unreliable). A result with hits confirms the spark (white, gold on
--     a crit; a hit the client did not predict gets its spark then); a result without hits, or none within RESULT_TIMEOUT,
--     fades it.
--   · ClientHeartbeat at HEARTBEAT_HZ with the render time, so the server can bound the rewind (Combat/Lib/LagCompensation).
-- Measuring (A2.5): `Workspace.ClientFx` carries attributes refreshed every STATS_EVERY s: Shots, Results, Hits, Kills,
-- Lost, Predicted, Confirmed, Refused, round trip Rtt{Avg,P50,P95,P99,Max}Ms over the last RTT_WINDOW results (request
-- sent → its result arrived), FeedbackFrames{Max,Last} and FeedbackMsMax (input event → first frame drawn with the shot,
-- 1 = the frame that handled the input), FeedbackShots. Setting its attribute `Reset` to true restarts the counters and
-- the round-trip window at the next publish. `tools/latency_probe.luau` uses both.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ClientHeartbeat = require(ReplicatedStorage.Shared.Net.ClientHeartbeat)
local CombatResult = require(ReplicatedStorage.Shared.Net.CombatResult)
local HitScan = require(ReplicatedStorage.Shared.Util.HitScan)
local InputController = require(script.Parent.InputController)
local EnemyRenderer = require(script.Parent.Parent.Render.EnemyRenderer)
local ShotEffects = require(script.Parent.Parent.Effects.ShotEffects)

local ATTACK = "RequestAttack"
local RESULT = "CombatResult"
local HEARTBEAT = "ClientHeartbeat"
local DEFAULT_CLASS = "Sharpshooter"
local NET_WAIT_SECONDS = 30
local HEARTBEAT_HZ = 5
local RESULT_TIMEOUT = 1 -- s without a result before a shot counts as lost
local MUZZLE_FORWARD = 1.6 -- studs ahead of the root
local MUZZLE_UP = 0.6
local SPARK_UP = 3 -- studs above the drawn feet
local STATS_EVERY = 0.5
local RTT_WINDOW = 200
local FRAME_SLACK = 1 / 60 -- s a held shot may be late by one frame without shifting the cadence

type Shot = { SentAt: number, Spark: ShotEffects.Spark?, Predicted: number? }

local player = Players.LocalPlayer
local weapon: any = nil
local attackRemote: RemoteEvent? = nil
local heartbeatRemote: UnreliableRemoteEvent? = nil
local seq = 0
local heartbeatSeq = 0
local nextReady = -math.huge
local frame = 0
local inputFrame: number? = nil
local inputAt = 0
local shots: { [number]: Shot } = {}
local rtts: { number } = table.create(RTT_WINDOW, 0)
local rttCount = 0
local counts = {
	Shots = 0,
	Results = 0,
	Hits = 0,
	Kills = 0,
	Lost = 0,
	Predicted = 0,
	Confirmed = 0,
	Refused = 0,
	Unpredicted = 0,
	Malformed = 0,
	FeedbackShots = 0,
	FeedbackFramesMax = 0,
	FeedbackFramesLast = 0,
	FeedbackMsMax = 0,
}
local lastStats = 0
local lastHeartbeat = 0
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local started = false

local CombatController = { Name = "CombatController" }

local function loadWeapon(): any
	local definitions = ReplicatedStorage.Shared.Definitions
	local class = require(definitions.Classes:FindFirstChild(DEFAULT_CLASS) :: ModuleScript) :: any
	return require(definitions.Weapons:FindFirstChild(class.StarterWeaponId) :: ModuleScript) :: any
end

local function percentile(sorted: { number }, p: number): number
	local n = #sorted
	if n == 0 then
		return 0
	end
	return sorted[math.clamp(math.ceil(n * p), 1, n)]
end

function CombatController.stats(): { [string]: number }
	local out: { [string]: number } = table.clone(counts) :: any
	local n = math.min(rttCount, RTT_WINDOW)
	local sorted = table.move(rtts, 1, n, 1, table.create(n))
	table.sort(sorted)
	local total = 0
	for _, v in sorted do
		total += v
	end
	out.RttSamples = n
	out.RttAvgMs = if n > 0 then total / n * 1000 else 0
	out.RttP50Ms = percentile(sorted, 0.5) * 1000
	out.RttP95Ms = percentile(sorted, 0.95) * 1000
	out.RttP99Ms = percentile(sorted, 0.99) * 1000
	out.RttMaxMs = (sorted[n] or 0) * 1000
	return out
end

local function publish()
	local folder = ShotEffects.container()
	if folder == nil then
		return
	end
	if folder:GetAttribute("Reset") == true then
		-- a probe asked for a fresh window: counters and the round-trip window restart
		folder:SetAttribute("Reset", false)
		local c = counts :: any
		for key in c do
			c[key] = 0
		end
		rttCount = 0
	end
	for key, value in CombatController.stats() do
		folder:SetAttribute(key, value)
	end
end

local function root(): BasePart?
	local model = player.Character
	local r = model and model:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function fire(now: number, fromInput: boolean)
	local remote = attackRemote
	local r = root()
	if remote == nil or r == nil or weapon == nil then
		return
	end
	local dir = HitScan.flat(InputController.aim())
	if dir == nil then
		return
	end
	nextReady = math.max(nextReady, now - FRAME_SLACK) + weapon.Cooldown[1]
	local origin = r.Position
	local range: number = weapon.Range

	-- what the player sees: the enemies as drawn this frame, and the arena geometry
	local hits = HitScan.cast(origin, dir, range, EnemyRenderer.drawn(), { maxTargets = weapon.MaxTargets })
	local first: HitScan.Hit? = hits[1]
	local reach = if first then first.Distance else range
	local filter: { Instance } = { r.Parent :: Instance }
	local enemies = workspace:FindFirstChild("ClientEnemies")
	if enemies then
		table.insert(filter, enemies)
	end
	local fx = ShotEffects.container()
	if fx then
		table.insert(filter, fx)
	end
	rayParams.FilterDescendantsInstances = filter
	local wall = workspace:Raycast(origin, dir * math.max(reach, 0.1), rayParams)
	local endPoint = origin + dir * reach
	if wall then
		first = nil
		endPoint = wall.Position
	end

	local muzzle = origin + dir * MUZZLE_FORWARD + Vector3.new(0, MUZZLE_UP, 0)
	ShotEffects.shot(muzzle, Vector3.new(endPoint.X, muzzle.Y, endPoint.Z))
	local spark: ShotEffects.Spark? = nil
	if first then
		spark = ShotEffects.spark(Vector3.new(first.Point.X, first.Point.Y + SPARK_UP, first.Point.Z))
		counts.Predicted += 1
	end
	if fromInput and inputFrame ~= nil then
		local frames = frame - inputFrame
		counts.FeedbackShots += 1
		counts.FeedbackFramesLast = frames
		counts.FeedbackFramesMax = math.max(counts.FeedbackFramesMax, frames)
		counts.FeedbackMsMax = math.max(counts.FeedbackMsMax, (now - inputAt) * 1000)
		inputFrame = nil
	end

	seq = (seq + 1) % (CombatResult.MAX_SEQ + 1)
	shots[seq] = { SentAt = os.clock(), Spark = spark, Predicted = if first then first.Id else nil }
	counts.Shots += 1
	remote:FireServer({
		Seq = seq,
		T = math.max(0, EnemyRenderer.renderTime() or 0),
		Origin = origin,
		Dir = dir,
		TargetHint = if first then first.Id else nil,
	})
end

local function onResult(payload: unknown)
	local results = CombatResult.unpack(payload)
	if results == nil then
		counts.Malformed += 1
		return
	end
	local now = os.clock()
	for _, result in results do
		local shot = shots[result.Seq]
		if shot == nil then
			continue
		end
		shots[result.Seq] = nil
		counts.Results += 1
		rttCount += 1
		rtts[(rttCount - 1) % RTT_WINDOW + 1] = now - shot.SentAt
		local spark = shot.Spark
		if #result.Hits == 0 then
			if spark then
				ShotEffects.fade(spark)
				counts.Refused += 1
			end
			continue
		end
		for _, hit in result.Hits do
			counts.Hits += 1
			if hit.Killed then
				counts.Kills += 1
			end
		end
		local hit = result.Hits[1]
		if spark == nil or shot.Predicted ~= hit.EnemyId then
			if spark then
				ShotEffects.fade(spark)
			end
			-- a hit the client did not predict: show it on the enemy as drawn
			counts.Unpredicted += 1
			spark = nil
			for _, drawn in EnemyRenderer.drawn() do
				if drawn.Id == hit.EnemyId then
					spark = ShotEffects.spark(drawn.Position + Vector3.new(0, SPARK_UP, 0))
					break
				end
			end
		end
		if spark then
			ShotEffects.confirm(spark, hit.Crit)
			counts.Confirmed += 1
		end
	end
end

local function step(_dt: number)
	local now = os.clock()
	if InputController.isFiring() and now >= nextReady then
		fire(now, inputFrame ~= nil)
	end
	inputFrame = nil -- a press is a feedback sample only on the frame it is handled (not after a cooldown wait)
	for id, shot in shots do
		if now - shot.SentAt > RESULT_TIMEOUT then
			shots[id] = nil
			counts.Lost += 1
			if shot.Spark then
				ShotEffects.fade(shot.Spark)
			end
		end
	end
	ShotEffects.step(now)
	local hb = heartbeatRemote
	local renderT = EnemyRenderer.renderTime()
	if hb and renderT and now - lastHeartbeat >= 1 / HEARTBEAT_HZ then
		lastHeartbeat = now
		heartbeatSeq += 1
		hb:FireServer(ClientHeartbeat.pack(heartbeatSeq, math.max(0, renderT)))
	end
	if now - lastStats >= STATS_EVERY then
		lastStats = now
		publish()
	end
end

local function connect()
	local net = ReplicatedStorage:WaitForChild("Net", NET_WAIT_SECONDS)
	local result = net and net:WaitForChild(RESULT, NET_WAIT_SECONDS)
	local attack = net and net:WaitForChild(ATTACK, NET_WAIT_SECONDS)
	local hb = net and net:WaitForChild(HEARTBEAT, NET_WAIT_SECONDS)
	if result == nil or not result:IsA("UnreliableRemoteEvent") or attack == nil or not attack:IsA("RemoteEvent") then
		warn(`[Combat] ReplicatedStorage.Net.{ATTACK}/{RESULT} did not appear within {NET_WAIT_SECONDS} s; attacks stay off`)
		return
	end
	result.OnClientEvent:Connect(onResult)
	attackRemote = attack
	if hb and hb:IsA("UnreliableRemoteEvent") then
		heartbeatRemote = hb
	end
end

function CombatController.start()
	if started then
		return
	end
	started = true
	weapon = loadWeapon()
	ShotEffects.init()
	-- frame counter first in every frame, so an input event (handled before the render steps) sees the previous frame
	RunService:BindToRenderStep("DZ_Frame", Enum.RenderPriority.First.Value, function()
		frame += 1
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 or t == Enum.UserInputType.Touch then
			inputFrame = frame
			inputAt = os.clock()
		end
	end)
	InputController.Action:Connect(function(action: string, phase: string)
		if action == "Primary" and phase == "Begin" then
			local now = os.clock()
			if now >= nextReady then
				fire(now, inputFrame ~= nil)
			end
		end
	end)
	RunService:BindToRenderStep("DZ_Combat", Enum.RenderPriority.Input.Value + 2, step)
	print(`[Combat] CombatController on · {weapon.Id} cooldown {weapon.Cooldown[1]} s range {weapon.Range}`)
	task.spawn(connect)
end

return table.freeze(CombatController)
