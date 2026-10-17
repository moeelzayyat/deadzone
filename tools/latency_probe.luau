--!nocheck
-- tools/latency_probe.luau (A2.5): client attack-latency probe (docs/PERFORMANCE_BUDGETS.md "LatencyProbe"). Paste into
-- execute_luau, datamodel Client, during a play test. Client/Controllers/CombatController publishes its counters on
-- Workspace.ClientFx every 0.5 s; this probe restarts or reads them.
--   MODE = "start"  asks for a fresh window (attribute Reset) and reports the simulated lag in effect
--   MODE = "read"   returns one summary line: shots, results, hits, kills, lost, predicted/confirmed/refused sparks,
--                   request → result round trip (avg, p50, p95, p99, max over the last 200 results; each result is
--                   matched to its request by Seq on the client, from FireServer to the CombatResult handler) and
--                   input → feedback (frames from the input event to the frame that drew the shot; 1 = the frame
--                   that handled the input)
-- Fire between the two calls (user_mouse_input holds or clicks on the play viewport). Simulated network lag is Studio's
-- settings().Network.IncomingReplicationLag (seconds, applied to incoming data on both the client and the server peer
-- of a Studio play session); set it before starting play and put it back to 0 afterwards.
local MODE = "read"

local folder = workspace:WaitForChild("ClientFx", 10)
assert(folder, "Workspace.ClientFx missing: is CombatController running?")
local lag = settings().Network.IncomingReplicationLag
if MODE == "start" then
	folder:SetAttribute("Reset", true)
	task.wait(0.6)
	return string.format("reset · IncomingReplicationLag %.3f s", lag)
end
local a = folder:GetAttributes()
return string.format(
	"lag %.3f s · shots %d results %d hits %d kills %d lost %d · sparks predicted %d confirmed %d refused %d unpredicted %d · "
		.. "request→result avg %.1f p50 %.1f p95 %.1f p99 %.1f max %.1f ms (n %d) · input→feedback max %d frames (%.1f ms) over %d presses",
	lag,
	a.Shots or 0,
	a.Results or 0,
	a.Hits or 0,
	a.Kills or 0,
	a.Lost or 0,
	a.Predicted or 0,
	a.Confirmed or 0,
	a.Refused or 0,
	a.Unpredicted or 0,
	a.RttAvgMs or 0,
	a.RttP50Ms or 0,
	a.RttP95Ms or 0,
	a.RttP99Ms or 0,
	a.RttMaxMs or 0,
	a.RttSamples or 0,
	a.FeedbackFramesMax or 0,
	a.FeedbackMsMax or 0,
	a.FeedbackShots or 0
)
