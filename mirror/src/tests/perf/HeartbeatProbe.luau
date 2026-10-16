--!strict
-- perf/HeartbeatProbe (docs/PERFORMANCE_BUDGETS.md, architecture §23): server heartbeat over a window, during a play test.
-- Run in the Server datamodel through execute_luau:
--   return require(game:GetService("ServerStorage").Tests.perf.HeartbeatProbe).run(60)
-- Per Heartbeat it samples the frame interval (dt), the engine's Stats.HeartbeatTimeMs and the server step's work: the
-- time from the start of the step (PreSimulation) until every Heartbeat handler has run (a thread deferred from the
-- probe's own Heartbeat handler runs after the others); from ServerStorage/EnemyTestProbe (EnemyService harness,
-- A2.3) it reads the enemy simulation's own step time over the same window, the live enemy count and states, and the
-- snapshots sent. Returns one summary line per metric (avg, p95, p99, max) as a string.

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Stats = game:GetService("Stats")

local HeartbeatProbe = {}

local function describe(name: string, samples: { number }): string
	local sorted = table.clone(samples)
	table.sort(sorted)
	local n = #sorted
	if n == 0 then
		return `{name}: no samples`
	end
	local total = 0
	for _, v in sorted do
		total += v
	end
	local function at(p: number): number
		return sorted[math.clamp(math.ceil(n * p), 1, n)]
	end
	return string.format("%s: avg %.3f ms, p95 %.3f, p99 %.3f, max %.3f (%d samples)", name, total / n, at(0.95), at(0.99), sorted[n], n)
end

function HeartbeatProbe.run(seconds: number): string
	assert(RunService:IsServer() and RunService:IsRunning(), "run HeartbeatProbe on the server during a play test")
	local probe = ServerStorage:FindFirstChild("EnemyTestProbe")
	if probe and probe:IsA("BindableFunction") then
		probe:Invoke("reset")
	end
	local frame: { number } = {}
	local engine: { number } = {}
	local work: { number } = {}
	local stepStart = os.clock()
	local pre = RunService.PreSimulation:Connect(function()
		stepStart = os.clock()
	end)
	local post = RunService.Heartbeat:Connect(function(dt: number)
		table.insert(frame, dt * 1000)
		table.insert(engine, Stats.HeartbeatTimeMs)
		local started = stepStart
		task.defer(function()
			table.insert(work, (os.clock() - started) * 1000)
		end)
	end)
	task.wait(seconds)
	pre:Disconnect()
	post:Disconnect()
	local lines = {
		string.format("HeartbeatProbe %d s", seconds),
		describe("frame interval (Heartbeat dt)", frame),
		describe("Stats.HeartbeatTimeMs", engine),
		describe("server step work (PreSimulation → all Heartbeat handlers)", work),
	}
	if probe and probe:IsA("BindableFunction") then
		local r = probe:Invoke("read")
		local states: { string } = {}
		for state, count in r.States do
			table.insert(states, `{state} {count}`)
		end
		table.sort(states)
		table.insert(
			lines,
			string.format(
				"EnemyService step: avg %.3f ms, p99 %.3f, max %.3f (%d steps); %d enemies (%s); snapshots %d, packets %d, %d bytes (%.1f KB/s); field builds %d, teleports %d, attacks %d",
				r.StepAvgMs,
				r.StepP99Ms,
				r.StepMaxMs,
				r.Samples,
				r.Count,
				table.concat(states, ", "),
				r.Snapshots,
				r.Packets,
				r.Bytes,
				r.Bytes / seconds / 1024,
				r.Stats.FieldBuilds,
				r.Stats.Teleports,
				r.Stats.Attacks
			)
		)
	else
		table.insert(lines, "EnemyTestProbe not found (flags EnemyTest / TestArena off?)")
	end
	return table.concat(lines, "\n")
end

return HeartbeatProbe
