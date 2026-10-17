--!strict
-- Combat/Lib/LagCompensation (architecture §7.1): how far back the server looks when it tests a player's attack.
-- The client stamps every RequestAttack with T, the SimulationClock time of the enemies it was drawing (its render
-- time, A2.4: two snapshot intervals behind the newest snapshot). T is a hint: the server rewinds to it only inside
--   · the player's measured view lag ± SLACK, once ClientHeartbeat samples exist (the median of the last SAMPLES
--     differences arrival − clientTime, so a client cannot pick its own rewind freely), and
--   · MAX_REWIND (250 ms) behind now, never ahead of now: higher latency is clamped, not favoured.
-- Pure: no Instances, no clocks of its own; CombatService passes the match clock's Now().
--   LagCompensation.newTracker() → Tracker
--   LagCompensation.observe(tracker, now, clientTime)       one heartbeat
--   LagCompensation.lag(tracker) → number?                  the median view lag (s), nil before the first sample
--   LagCompensation.rewindTime(now, t, lag?) → (time, clamped)

export type Tracker = { Samples: { number }, Head: number }

local MAX_REWIND = 0.25 -- s (§7.1 ring buffer window)
local SLACK = 0.1 -- s a request's T may sit away from the measured view lag (jitter between heartbeats and requests)
local SAMPLES = 9

local LagCompensation = {
	MAX_REWIND = MAX_REWIND,
	SLACK = SLACK,
	SAMPLES = SAMPLES,
}

function LagCompensation.newTracker(): Tracker
	return { Samples = {}, Head = 0 }
end

function LagCompensation.observe(tracker: Tracker, now: number, clientTime: number)
	local lag = now - clientTime
	if lag ~= lag then
		return
	end
	tracker.Head = tracker.Head % SAMPLES + 1
	tracker.Samples[tracker.Head] = math.clamp(lag, 0, 1)
end

function LagCompensation.lag(tracker: Tracker): number?
	local n = #tracker.Samples
	if n == 0 then
		return nil
	end
	local sorted = table.clone(tracker.Samples)
	table.sort(sorted)
	if n % 2 == 1 then
		return sorted[(n + 1) // 2]
	end
	return (sorted[n // 2] + sorted[n // 2 + 1]) / 2
end

-- The time to rewind enemies to for a request stamped t, and whether t had to be moved.
function LagCompensation.rewindTime(now: number, t: number, lag: number?): (number, boolean)
	local target = t
	if lag ~= nil then
		target = math.clamp(target, now - lag - SLACK, now - lag + SLACK)
	end
	target = math.clamp(target, now - MAX_REWIND, now)
	return target, target ~= t
end

return table.freeze(LagCompensation)
