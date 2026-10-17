--!strict
-- Util/HitScan (A2.5, architecture §7.1): the flat ray-versus-body test shared by the server's authoritative hit and the
-- client's predicted spark: direction flattening and normalization, nearest first, MaxTargets, range, bodies behind the
-- shooter, the pad and the hinted enemy's extra pad, a shooter standing inside a body. Runs on a clone of Shared.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestRunner = require(script.Parent.Parent.TestRunner)

local shared = ReplicatedStorage.Shared:Clone()
local HitScan = (require :: any)((shared :: any).Util.HitScan)

local EPSILON = 1e-6

local function body(id: number, x: number, z: number, radius: number?): any
	return { Id = id, Position = Vector3.new(x, 0, z), Radius = radius or 1.5 }
end

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("HitScan.flat", function()
		it("drops height and normalizes; nil for an (almost) vertical or broken direction", function()
			local d = HitScan.flat(Vector3.new(3, 5, 4))
			expect(d.X).toBeCloseTo(0.6, EPSILON)
			expect(d.Y).toBe(0)
			expect(d.Z).toBeCloseTo(0.8, EPSILON)
			expect(HitScan.flat(Vector3.new(0, 1, 0))).toBeNil()
			expect(HitScan.flat(Vector3.new(0.05, 1, 0))).toBeNil()
			expect(HitScan.flat(Vector3.new(0 / 0, 0, 1))).toBeNil()
			expect(HitScan.flat(Vector3.new(math.huge, 0, 1))).toBeNil()
		end)
	end)

	describe("HitScan.cast", function()
		it("hits the nearest body on the line, at its entry point, and only MaxTargets of them", function()
			local bodies = { body(1, 20, 0), body(2, 10, 0), body(3, 30, 0) }
			local hits = HitScan.cast(Vector3.zero, Vector3.new(1, 0, 0), 60, bodies)
			expect(#hits).toBe(1)
			expect(hits[1].Id).toBe(2)
			expect(hits[1].Distance).toBeCloseTo(10 - (1.5 + HitScan.PAD), EPSILON)
			local three = HitScan.cast(Vector3.zero, Vector3.new(1, 0, 0), 60, bodies, { maxTargets = 3 })
			expect(#three).toBe(3)
			expect(three[1].Id).toBe(2)
			expect(three[2].Id).toBe(1)
			expect(three[3].Id).toBe(3)
		end)

		it("ignores height: a shot at chest height hits a body standing on the floor", function()
			local hits = HitScan.cast(Vector3.new(0, 3.5, 0), Vector3.new(0, 0, -1), 60, { body(4, 0, -12) })
			expect(#hits).toBe(1)
			expect(hits[1].Point.Y).toBe(0)
		end)

		it("misses bodies beyond range, behind the shooter, or off the line by more than radius + pad", function()
			local r = 1.5 + HitScan.PAD
			expect(#HitScan.cast(Vector3.zero, Vector3.new(1, 0, 0), 60, { body(1, 63, 0) })).toBe(0)
			expect(#HitScan.cast(Vector3.zero, Vector3.new(1, 0, 0), 60, { body(1, -10, 0) })).toBe(0)
			expect(#HitScan.cast(Vector3.zero, Vector3.new(1, 0, 0), 60, { body(1, 20, r + 0.01) })).toBe(0)
			expect(#HitScan.cast(Vector3.zero, Vector3.new(1, 0, 0), 60, { body(1, 20, r - 0.01) })).toBe(1)
			-- reach counts to the body's edge: centre at range + radius is still hit
			expect(#HitScan.cast(Vector3.zero, Vector3.new(1, 0, 0), 60, { body(1, 60 + r - 0.01, 0) })).toBe(1)
		end)

		it("gives the hinted body hintPad more, and only that body", function()
			local off = 1.5 + HitScan.PAD + HitScan.HINT_PAD / 2
			local bodies = { body(1, 20, off), body(2, 25, -off) }
			expect(#HitScan.cast(Vector3.zero, Vector3.new(1, 0, 0), 60, bodies)).toBe(0)
			local hits = HitScan.cast(Vector3.zero, Vector3.new(1, 0, 0), 60, bodies, { hintId = 2 })
			expect(#hits).toBe(1)
			expect(hits[1].Id).toBe(2)
		end)

		it("hits a body the shooter stands inside at distance 0; nothing for a vertical shot or zero range", function()
			local hits = HitScan.cast(Vector3.new(0.5, 0, 0), Vector3.new(0, 0, 1), 60, { body(9, 0, 0) })
			expect(#hits).toBe(1)
			expect(hits[1].Distance).toBe(0)
			expect(#HitScan.cast(Vector3.zero, Vector3.new(0, 1, 0), 60, { body(9, 0, 5) })).toBe(0)
			expect(#HitScan.cast(Vector3.zero, Vector3.new(0, 0, 1), 0, { body(9, 0, 5) })).toBe(0)
		end)
	end)
end
