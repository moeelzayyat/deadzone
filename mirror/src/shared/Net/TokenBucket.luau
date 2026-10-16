--!strict
-- Net/TokenBucket (architecture §7.2): the per-player, per-remote rate limit. A bucket holds up to `burst` tokens, starts
-- full and refills at `sustained` tokens per second; each request takes one token or is rejected. Time is passed in
-- (seconds, any monotonic clock), so the bucket is deterministic under test. A bucket with burst 0 rejects everything
-- (the inbound side of server→client remotes).

export type Bucket = {
	sustained: number,
	burst: number,
	tokens: number,
	updatedAt: number,
	take: (self: Bucket, now: number) -> boolean,
	peek: (self: Bucket, now: number) -> number,
}

local EPSILON = 1e-9 -- refill arithmetic in doubles: 12 × (1/12 s) must give a whole token

local function fail(message: string): never
	error("[TokenBucket] " .. message, 0)
end

local function finite(x: number): boolean
	return x == x and x ~= math.huge and x ~= -math.huge
end

local function refill(self: Bucket, now: number)
	if typeof(now) ~= "number" or not finite(now) then
		fail(`time must be a finite number, got {tostring(now)}`)
	end
	-- A clock that steps backwards refills nothing (never adds tokens).
	local elapsed = now - self.updatedAt
	if elapsed > 0 then
		self.tokens = math.min(self.burst, self.tokens + elapsed * self.sustained)
	end
	self.updatedAt = math.max(self.updatedAt, now)
end

local TokenBucket = {}

function TokenBucket.new(sustained: number, burst: number, now: number): Bucket
	if typeof(sustained) ~= "number" or not finite(sustained) or sustained < 0 then
		fail(`sustained must be a finite number ≥ 0, got {tostring(sustained)}`)
	end
	if typeof(burst) ~= "number" or not finite(burst) or burst < 0 or burst % 1 ~= 0 then
		fail(`burst must be a whole number ≥ 0, got {tostring(burst)}`)
	end
	if typeof(now) ~= "number" or not finite(now) then
		fail(`time must be a finite number, got {tostring(now)}`)
	end
	local bucket: Bucket = {
		sustained = sustained,
		burst = burst,
		tokens = burst,
		updatedAt = now,
		take = function(self: Bucket, at: number): boolean
			refill(self, at)
			if self.tokens >= 1 - EPSILON then
				self.tokens = math.max(0, self.tokens - 1)
				return true
			end
			return false
		end,
		peek = function(self: Bucket, at: number): number
			refill(self, at)
			return self.tokens
		end,
	}
	return bucket
end

return table.freeze(TokenBucket)
