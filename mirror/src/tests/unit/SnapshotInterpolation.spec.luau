--!strict
-- Render/Lib/SnapshotInterpolation (A2.4, architecture §6.4, §8.1): the snapshot clock (offset, interval, delay,
-- re-sync), the per-enemy track (late packets, state runs, cuts, bounded length) and sampling (interpolation, yaw on
-- the short arc, capped extrapolation, hold). The last test replays a 12 Hz stream with arrival jitter and lost packets
-- at 60 frames per second and checks that the drawn motion has no visible jumps.

local TestRunner = require(script.Parent.Parent.TestRunner)
local RenderFixture = require(script.Parent.Parent.fixtures.RenderFixture)

local SI = RenderFixture.require(RenderFixture.lib(), "SnapshotInterpolation")

local HZ = 1 / 12
local RATE = 0.1 -- the render clock may run at most 10 % fast or slow (a fixed bound, not the module's own constant)

local function v(x: number, z: number?): Vector3
	return Vector3.new(x, 0, z or 0)
end

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("clock", function()
		it("maps snapshot time to local time on the first packet and renders two intervals behind", function()
			local clock = SI.newClock()
			SI.observe(clock, 50, 1000)
			expect(clock.Offset).toBeCloseTo(-950, 1e-9)
			expect(SI.delay(clock)).toBeCloseTo(2 * HZ, 1e-9)
			expect(SI.renderTime(clock, 1000)).toBeCloseTo(50 - 2 * HZ, 1e-9)
		end)

		it("follows an earlier packet at once and a later one slowly", function()
			local clock = SI.newClock()
			SI.observe(clock, 10, 100)
			SI.observe(clock, 10 + HZ, 100 + HZ - 0.02) -- 20 ms earlier than the first: less delay
			expect(clock.Offset).toBeCloseTo(-90 + 0.02, 1e-9)
			SI.observe(clock, 10 + 2 * HZ, 100 + 2 * HZ + 0.03) -- 30 ms late
			expect(clock.Offset < -90 + 0.02).toBe(true)
			expect(clock.Offset > -90 + 0.02 - 0.01).toBe(true)
		end)

		it("re-syncs at once after a pause of the simulation clock", function()
			local clock = SI.newClock()
			SI.observe(clock, 10, 100)
			SI.observe(clock, 10 + HZ, 100 + HZ)
			SI.observe(clock, 10 + 2 * HZ, 103) -- the clock stood still for ~3 s
			expect(clock.Offset).toBeCloseTo(10 + 2 * HZ - 103, 1e-9)
		end)

		it("learns the snapshot interval and keeps the delay within its bounds", function()
			local clock = SI.newClock()
			for i = 0, 200 do
				SI.observe(clock, i / 15, 100 + i / 15)
			end
			expect(clock.Interval).toBeCloseTo(1 / 15, 1e-3)
			expect(SI.delay(clock)).toBeCloseTo(2 / 15, 1e-3)
			local slow = SI.newClock()
			for i = 0, 200 do
				SI.observe(slow, i * 0.5, 100 + i * 0.5)
			end
			expect(SI.delay(slow)).toBe(SI.MAX_DELAY)
		end)
	end)

	describe("render time", function()
		it("slews toward a new estimate at most SLEW faster or slower, never backward", function()
			local clock = SI.newClock()
			SI.observe(clock, 10, 100)
			local dt = 1 / 60
			local last = SI.renderTime(clock, 100)
			SI.observe(clock, 10 + HZ, 100 + HZ - 0.05) -- the estimate jumps 50 ms ahead
			for f = 1, 60 do
				local r = SI.renderTime(clock, 100 + f * dt)
				expect(r - last <= dt * (1 + RATE) + 1e-9).toBe(true)
				expect(r - last >= dt * (1 - RATE) - 1e-9).toBe(true)
				last = r
			end
			-- after a second it has caught up: 50 ms closed at up to 10 % of each frame
			expect(math.abs(last - (100 + 1 + clock.Offset - SI.delay(clock)))).toBeCloseTo(0, 1e-6)
		end)

		it("snaps when the estimate moves by more than SNAP", function()
			local clock = SI.newClock()
			SI.observe(clock, 10, 100)
			SI.renderTime(clock, 100)
			SI.observe(clock, 12, 100.1) -- 1.9 s jump: a re-sync
			expect(SI.renderTime(clock, 100.1)).toBeCloseTo(12 - SI.delay(clock), 1e-9)
		end)
	end)

	describe("track", function()
		it("ignores a late or repeated sample and keeps at most KEEP samples", function()
			local track = SI.newTrack()
			expect(SI.push(track, 1, v(0), 0, "Pursue")).toBe(true)
			expect(SI.push(track, 1, v(5), 0, "Pursue")).toBe(false)
			expect(SI.push(track, 0.9, v(5), 0, "Pursue")).toBe(false)
			for i = 2, 20 do
				SI.push(track, i, v(i), 0, "Pursue")
			end
			expect(#track.Samples).toBe(SI.KEEP)
			expect(track.Samples[1].T).toBe(20 - SI.KEEP + 1)
		end)

		it("remembers when the current state began", function()
			local track = SI.newTrack()
			SI.push(track, 1, v(0), 0, "Pursue")
			SI.push(track, 2, v(1), 0, "Telegraph")
			SI.push(track, 3, v(1), 0, "Telegraph")
			SI.push(track, 4, v(1), 0, "Attack")
			expect(track.Samples[3].Since).toBe(2)
			expect(track.Samples[4].Since).toBe(4)
			local r = SI.sample(track, 3.5)
			expect(r.State).toBe("Telegraph")
			expect(r.Since).toBe(2)
		end)
	end)

	describe("sample", function()
		it("interpolates position and takes yaw along the short arc", function()
			local track = SI.newTrack()
			SI.push(track, 1, v(0), math.rad(350), "Pursue")
			SI.push(track, 2, v(10), math.rad(10), "Pursue")
			local r = SI.sample(track, 1.5)
			expect(r.Mode).toBe("Interpolate")
			expect(r.Position.X).toBeCloseTo(5, 1e-6)
			local yaw = math.deg(r.Yaw) % 360
			expect(math.min(yaw, 360 - yaw)).toBeCloseTo(0, 1e-6)
			local out: any = { Position = Vector3.zero, Yaw = 0, State = "", Since = 0, Mode = "Hold" }
			local filled = SI.sample(track, 1.25, out)
			expect(filled).toBe(out) -- reused, no new table
			expect(out.Position.X).toBeCloseTo(2.5, 1e-6)
			expect(SI.sample(track, 1.5) == out).toBe(false)
		end)

		it("extrapolates at most EXTRAPOLATE_MAX past the newest sample, then holds there", function()
			local track = SI.newTrack()
			SI.push(track, 1, v(0), 0, "Pursue")
			SI.push(track, 2, v(6), 0, "Pursue") -- 6 studs/s
			local r = SI.sample(track, 2.05)
			expect(r.Mode).toBe("Extrapolate")
			expect(r.Position.X).toBeCloseTo(6.3, 1e-6)
			local held = SI.sample(track, 3)
			expect(held.Mode).toBe("Hold")
			expect(held.Position.X).toBeCloseTo(6 + 6 * SI.EXTRAPOLATE_MAX, 1e-6)
		end)

		it("holds before the first sample and with a single sample", function()
			local track = SI.newTrack()
			expect(SI.sample(track, 1)).toBeNil()
			SI.push(track, 5, v(3), 0, "Spawn")
			expect(SI.sample(track, 4).Mode).toBe("Hold")
			expect(SI.sample(track, 6).Position.X).toBe(3)
		end)

		it("draws a teleport as a cut, never a slide across the arena", function()
			local track = SI.newTrack()
			SI.push(track, 1, v(0), 0, "Pursue")
			SI.push(track, 2, v(1), 0, "Pursue")
			SI.push(track, 3, v(60, 40), 0, "Pursue")
			expect(track.Samples[3].Cut).toBe(true)
			expect(SI.sample(track, 2.5).Position.X).toBe(1)
			expect(SI.sample(track, 2.99).Position.X).toBe(1)
			expect(SI.sample(track, 3).Position.X).toBe(60)
			expect(SI.sample(track, 3.05).Position.X).toBe(60) -- no extrapolation from a cut
		end)
	end)

	describe("12 Hz stream drawn at 60 FPS", function()
		it("moves smoothly with jitter and lost packets: no visible jumps, no holds, ≤ 2 guessed frames per loss", function()
			local rng = Random.new(42)
			local clock = SI.newClock()
			local track = SI.newTrack()
			local speed = 12 -- studs/s, a Runner
			local arrivals: { { T: number, At: number } } = {}
			local lost = 0
			for i = 0, 12 * 20 do -- 20 s of snapshots
				if i % 25 == 7 then -- every 25th packet is lost
					lost += 1
				else
					local tSim = i * HZ
					table.insert(arrivals, { T = tSim, At = 500 + tSim + 0.04 + rng:NextNumber(0, 0.03) })
				end
			end
			table.sort(arrivals, function(a, b)
				return a.At < b.At
			end)
			local nextArrival = 1
			local last: Vector3? = nil
			local worst, holds, extrapolated, drawn = 0, 0, 0, 0
			local dt = 1 / 60
			for f = 0, 60 * 19 do
				local now = 500 + f * dt
				while nextArrival <= #arrivals and arrivals[nextArrival].At <= now do
					local a = arrivals[nextArrival]
					SI.observe(clock, a.T, a.At)
					SI.push(track, a.T, v(a.T * speed), 0, "Pursue")
					nextArrival += 1
				end
				local r = SI.sample(track, SI.renderTime(clock, now))
				if r and f > 60 then
					drawn += 1
					if r.Mode == "Hold" then
						holds += 1
					elseif r.Mode == "Extrapolate" then
						extrapolated += 1
					end
					if last then
						local ratio = (r.Position - last).Magnitude / (speed * dt)
						worst = math.max(worst, ratio)
					end
				end
				last = if r then r.Position else nil
			end
			expect(drawn > 1000).toBe(true)
			expect(holds).toBe(0)
			-- a loss plus a late next packet outruns the two-interval buffer by at most the jitter (30 ms = 2 frames)
			expect(extrapolated <= 2 * lost).toBe(true)
			expect(worst <= 1 + RATE + 0.01).toBe(true) -- at most 1.1× the true distance per frame (+ float32 Vector3 error)
		end)
	end)
end
