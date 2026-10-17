--!strict
-- Render/Lib/SnapshotInterpolation (architecture §6.4 interpolation buffers, §7.2, §8.1): turns the server's 10–15 Hz
-- EnemySnapshot samples into a smooth per-frame position, heading and state. Pure (no Instances, no clocks of its own),
-- so the server-side TestRunner covers it (A2.4).
-- A Clock maps snapshot time T (the match's SimulationClock seconds) to the client's os.clock(): the offset follows the
-- least-delayed packet at once and drifts toward later ones slowly, and a jump of more than RESYNC seconds (a paused
-- or restarted SimulationClock, a long hitch) re-syncs at once. Rendering runs DELAY_INTERVALS snapshot intervals behind
-- the newest sample (clamped to MIN_DELAY..MAX_DELAY), so a packet may arrive one interval late before anything has to
-- be guessed. The render time itself never jumps with those estimates: it advances with the local clock and slews
-- toward its target at most SLEW (±10 %) faster or slower, and snaps only when it is more than SNAP seconds off. A Track keeps the last KEEP samples of one enemy; sampling between two samples interpolates (yaw on the
-- short arc), past the newest it extrapolates for at most EXTRAPOLATE_MAX seconds and then holds. Two samples more than
-- TELEPORT studs apart are a cut (the server's stuck teleport): the old position is held until the new sample's time,
-- then the new one is drawn, never a slide across the arena.
--   newClock() → Clock · observe(clock, t, arrival) · delay(clock) → s · renderTime(clock, now) → T
--   newTrack() → Track · push(track, t, position, yaw, state) → boolean · sample(track, t, out?) → Result?  (fills `out`)

export type Mode = "Interpolate" | "Extrapolate" | "Hold"

export type Sample = {
	T: number,
	Position: Vector3,
	Yaw: number,
	State: string,
	Since: number, -- T of the first sample in this run of the same state
	Cut: boolean, -- true when this sample is a teleport away from the previous one
}

export type Track = { Samples: { Sample } }

export type Clock = {
	Offset: number,
	Interval: number,
	LastT: number,
	Ready: boolean,
	Render: number?, -- the render time handed out last
	LastNow: number?, -- the local time it was handed out at
}

export type Result = {
	Position: Vector3,
	Yaw: number,
	State: string,
	Since: number,
	Mode: Mode,
}

local KEEP = 6
local DELAY_INTERVALS = 2
local MIN_DELAY = 0.1
local MAX_DELAY = 0.3
local EXTRAPOLATE_MAX = 0.1
local DECAY = 0.05 -- share of the gap closed per observation when packets arrive later than the best one
local RESYNC = 0.5
local INTERVAL_SMOOTHING = 0.1
local DEFAULT_INTERVAL = 1 / 12
local TELEPORT = 12
local SLEW = 0.1
local SNAP = 0.25
local TAU = 2 * math.pi

local SnapshotInterpolation = {
	KEEP = KEEP,
	DELAY_INTERVALS = DELAY_INTERVALS,
	MIN_DELAY = MIN_DELAY,
	MAX_DELAY = MAX_DELAY,
	EXTRAPOLATE_MAX = EXTRAPOLATE_MAX,
	RESYNC = RESYNC,
	TELEPORT = TELEPORT,
	SLEW = SLEW,
	SNAP = SNAP,
}

function SnapshotInterpolation.newClock(): Clock
	return { Offset = 0, Interval = DEFAULT_INTERVAL, LastT = -math.huge, Ready = false, Render = nil, LastNow = nil }
end

-- One packet of snapshot time t arrived at os.clock() `arrival`.
function SnapshotInterpolation.observe(clock: Clock, t: number, arrival: number)
	local offset = t - arrival
	if not clock.Ready or math.abs(offset - clock.Offset) > RESYNC then
		clock.Offset = offset
		clock.Ready = true
		clock.LastT = t
		return
	end
	if offset > clock.Offset then
		clock.Offset = offset
	else
		clock.Offset += (offset - clock.Offset) * DECAY
	end
	if t > clock.LastT then
		local gap = t - clock.LastT
		if gap < 1 then
			clock.Interval += (gap - clock.Interval) * INTERVAL_SMOOTHING
		end
		clock.LastT = t
	end
end

function SnapshotInterpolation.delay(clock: Clock): number
	return math.clamp(clock.Interval * DELAY_INTERVALS, MIN_DELAY, MAX_DELAY)
end

-- The snapshot time to draw at os.clock() `now` (call once per frame; it moves the clock's render time).
function SnapshotInterpolation.renderTime(clock: Clock, now: number): number
	local target = now + clock.Offset - SnapshotInterpolation.delay(clock)
	local render, lastNow = clock.Render, clock.LastNow
	local out = target
	if render and lastNow and now >= lastNow then
		local step = now - lastNow
		local ahead = render + step
		if math.abs(target - ahead) <= SNAP then
			out = ahead + math.clamp(target - ahead, -SLEW * step, SLEW * step)
		end
	end
	clock.Render, clock.LastNow = out, now
	return out
end

function SnapshotInterpolation.newTrack(): Track
	return { Samples = {} }
end

-- Adds a sample; an old or repeated time (a late packet) is ignored and returns false.
function SnapshotInterpolation.push(track: Track, t: number, position: Vector3, yaw: number, state: string): boolean
	local samples = track.Samples
	local count = #samples
	local last = samples[count]
	if last and t <= last.T then
		return false
	end
	local since, cut = t, false
	if last then
		if last.State == state then
			since = last.Since
		end
		cut = (position - last.Position).Magnitude > TELEPORT
	end
	table.insert(samples, { T = t, Position = position, Yaw = yaw, State = state, Since = since, Cut = cut })
	if count + 1 > KEEP then
		table.remove(samples, 1)
	end
	return true
end

local function lerpAngle(a: number, b: number, alpha: number): number
	local d = (b - a + math.pi) % TAU - math.pi
	return (a + d * alpha) % TAU
end

local scratch: Result? = nil

local function result(s: Sample, position: Vector3, yaw: number, mode: Mode): Result
	local out = scratch
	if out == nil then
		return { Position = position, Yaw = yaw, State = s.State, Since = s.Since, Mode = mode }
	end
	out.Position, out.Yaw, out.State, out.Since, out.Mode = position, yaw, s.State, s.Since, mode
	return out
end

-- With `out`, the result is written into it (no garbage per call); without, a new table is returned.
function SnapshotInterpolation.sample(track: Track, t: number, out: Result?): Result?
	scratch = out
	local samples = track.Samples
	local count = #samples
	if count == 0 then
		return nil
	end
	local newest = samples[count]
	if t >= newest.T then
		local prev = samples[count - 1]
		if prev == nil or newest.Cut then
			return result(newest, newest.Position, newest.Yaw, "Hold")
		end
		local ahead = t - newest.T
		local velocity = (newest.Position - prev.Position) / (newest.T - prev.T)
		local mode: Mode = if ahead <= EXTRAPOLATE_MAX then "Extrapolate" else "Hold"
		return result(newest, newest.Position + velocity * math.min(ahead, EXTRAPOLATE_MAX), newest.Yaw, mode)
	end
	local first = samples[1]
	if t <= first.T then
		return result(first, first.Position, first.Yaw, "Hold")
	end
	for i = count - 1, 1, -1 do
		local a = samples[i]
		if a.T <= t then
			local b = samples[i + 1]
			if b.Cut then
				return result(a, a.Position, a.Yaw, "Hold")
			end
			local alpha = (t - a.T) / (b.T - a.T)
			return result(a, a.Position:Lerp(b.Position, alpha), lerpAngle(a.Yaw, b.Yaw, alpha), "Interpolate")
		end
	end
	return result(first, first.Position, first.Yaw, "Hold")
end

return table.freeze(SnapshotInterpolation)
