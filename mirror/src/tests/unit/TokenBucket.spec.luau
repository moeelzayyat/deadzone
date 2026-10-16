--!strict
-- Net/TokenBucket (A1.8): a bucket rejects the N+1th request of a burst, refills at its sustained rate, never exceeds its
-- burst and never refills on a clock that steps back. Runs on a clone of Shared.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestRunner = require(script.Parent.Parent.TestRunner)

type BucketModule = typeof(require(ReplicatedStorage.Shared.Net.TokenBucket))

local shared = ReplicatedStorage.Shared:Clone()
local TokenBucket: BucketModule = (require :: any)((shared :: any).Net.TokenBucket)

type Bucket = typeof(TokenBucket.new(1, 1, 0))

-- Takes n requests at the same instant; returns how many were accepted.
local function takeMany(bucket: Bucket, n: number, now: number): number
	local accepted = 0
	for _ = 1, n do
		if bucket:take(now) then
			accepted += 1
		end
	end
	return accepted
end

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("burst", function()
		it("accepts N requests at once and rejects the N+1th (every API_CONTRACTS burst size)", function()
			for _, rate in { { 12, 20 }, { 3, 5 }, { 2, 3 }, { 1, 2 }, { 1, 1 }, { 20, 30 }, { 0.1, 2 } } do
				local bucket = TokenBucket.new(rate[1], rate[2], 100)
				for i = 1, rate[2] do
					expect(bucket:take(100)).toBe(true)
					local _ = i
				end
				expect(bucket:take(100)).toBe(false)
			end
		end)

		it("burst 0 rejects everything (the inbound side of server→client remotes)", function()
			local bucket = TokenBucket.new(0, 0, 0)
			expect(takeMany(bucket, 5, 0)).toBe(0)
			expect(takeMany(bucket, 5, 1e6)).toBe(0)
		end)
	end)

	describe("refill", function()
		it("refills one token every 1/sustained seconds", function()
			local bucket = TokenBucket.new(12, 20, 0)
			expect(takeMany(bucket, 21, 0)).toBe(20)
			expect(bucket:take(1 / 24)).toBe(false) -- half a token
			expect(bucket:take(1 / 12)).toBe(true)
			expect(bucket:take(1 / 12)).toBe(false)
			expect(takeMany(bucket, 13, 1 / 12 + 1)).toBe(12) -- one second later: 12 more
		end)

		it("sustains its rate under steady spam (50× rate for 10 s)", function()
			local bucket = TokenBucket.new(12, 20, 0)
			local accepted = 0
			local step = 1 / 600 -- 600 requests per second
			for i = 0, 5999 do
				if bucket:take(i * step) then
					accepted += 1
				end
			end
			-- 20 burst + 12/s over ~10 s
			expect(accepted >= 139 and accepted <= 140).toBe(true)
		end)

		it("never holds more than its burst after a long idle", function()
			local bucket = TokenBucket.new(12, 20, 0)
			expect(bucket:peek(3600)).toBe(20)
			expect(takeMany(bucket, 25, 3600)).toBe(20)
		end)

		it("adds nothing when the clock steps backwards", function()
			local bucket = TokenBucket.new(10, 2, 50)
			expect(takeMany(bucket, 2, 50)).toBe(2)
			expect(bucket:take(10)).toBe(false)
			expect(bucket:take(50)).toBe(false)
			expect(bucket:take(50.1)).toBe(true)
		end)
	end)

	describe("arguments", function()
		it("rejects negative, NaN and fractional settings and non-finite times", function()
			expect(function()
				TokenBucket.new(-1, 5, 0)
			end).toThrow("sustained")
			expect(function()
				TokenBucket.new(0 / 0, 5, 0)
			end).toThrow("sustained")
			expect(function()
				TokenBucket.new(1, 2.5, 0)
			end).toThrow("burst")
			expect(function()
				TokenBucket.new(1, 2, math.huge)
			end).toThrow("time")
			local bucket = TokenBucket.new(1, 2, 0)
			expect(function()
				bucket:take(0 / 0)
			end).toThrow("time")
		end)
	end)
end
