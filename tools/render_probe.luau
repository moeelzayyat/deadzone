--!nocheck
-- tools/render_probe.luau (A2.4): client FPS + enemy render probe. Paste into execute_luau, datamodel Client, during a
-- play test with the EnemyTest horde. Set the four values below. It measures RenderStepped frame times over SECONDS
-- and the differences of the EnemyRenderer attributes on Workspace.ClientEnemies over the same window (MaxSpeedRatio is
-- polled every 0.5 s, the renderer's publish period). WALK walks the character around a 80 × 80 stud square in
-- TestArena slot 0 with Humanoid:MoveTo. CPU_SCALE > 1 turns on the CPU part of the low-end emulation (D-026);
-- QUALITY sets settings().Rendering.QualityLevel for the window (nil leaves it). Both are restored afterwards.
-- Returns one summary line.
local SECONDS, WALK, CPU_SCALE, QUALITY = 60, false, 1, nil

local RunService = game:GetService("RunService")
local folder = workspace:WaitForChild("ClientEnemies", 10)
assert(folder, "Workspace.ClientEnemies missing: is the renderer running?")
local rendering = settings().Rendering
local oldQuality = rendering.QualityLevel
if QUALITY then
	rendering.QualityLevel = QUALITY
end
folder:SetAttribute("EmulateCpuScale", CPU_SCALE)
task.wait(1.5) -- let the renderer pick up the scale and the frame rate settle

local frames = {}
local conn = RunService.RenderStepped:Connect(function(dt)
	table.insert(frames, dt)
end)
local a0 = folder:GetAttributes()
local maxRatio, stop = 0, false
task.spawn(function()
	while not stop do
		task.wait(0.5)
		maxRatio = math.max(maxRatio, folder:GetAttribute("MaxSpeedRatio") or 0)
	end
end)
if WALK then
	task.spawn(function()
		local humanoid = game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		local points = { Vector3.new(-40, 0, 1560), Vector3.new(40, 0, 1560), Vector3.new(40, 0, 1640), Vector3.new(-40, 0, 1640) }
		local i = 1
		while not stop do
			humanoid:MoveTo(points[i])
			humanoid.MoveToFinished:Wait()
			i = i % 4 + 1
		end
	end)
end
task.wait(SECONDS)
stop = true
conn:Disconnect()
local a1 = folder:GetAttributes()
folder:SetAttribute("EmulateCpuScale", 1)
rendering.QualityLevel = oldQuality

table.sort(frames)
local total = 0
for _, dt in frames do
	total += dt
end
local n = #frames
local function at(p)
	return frames[math.clamp(math.ceil(n * p), 1, n)] * 1000
end
local function d(k)
	return (a1[k] or 0) - (a0[k] or 0)
end
return string.format(
	"%s%s cpu×%g quality %s, %d s: %d frames, %.1f FPS avg, frame p50 %.2f / p99 %.2f / max %.2f ms, frames > 33.3 ms: %d · enemies %d, rigs %d, parked %d · render work avg %.3f / p99 %.3f / max %.3f ms (last 600 frames) · drawn interp %d, extrap %d, held %d · snaps %d, jumps %d, max speed ratio %.2f · built %d, reused %d, destroyed %d · delay %.0f ms",
	WALK and "walking" or "standing",
	"",
	CPU_SCALE,
	tostring(QUALITY or oldQuality),
	SECONDS,
	n,
	n / total,
	at(0.5),
	at(0.99),
	frames[n] * 1000,
	(function()
		local c = 0
		for _, dt in frames do
			if dt > 1 / 30 then
				c += 1
			end
		end
		return c
	end)(),
	a1.Enemies,
	a1.Rigs,
	a1.Parked,
	a1.WorkAvgMs,
	a1.WorkP99Ms,
	a1.WorkMaxMs,
	d("Interpolated"),
	d("Extrapolated"),
	d("Held"),
	d("Snaps"),
	d("Jumps"),
	maxRatio,
	d("Built"),
	d("Reused"),
	d("Destroyed"),
	a1.DelayMs
)
