--!strict
-- Util/PositionRing (architecture §7.1, §8.2): a fixed-size ring of (time, position) samples, newest last. Every enemy
-- record keeps one (`History`) so the A2.5 lag-compensated hit test can look up where an enemy was inside the 250 ms
-- rewind window. A2.3 fills it on every simulation update; A2.5 adds the rewind query.
--   local ring = PositionRing.new(capacity)
--   ring:push(time, position)       times must not decrease (a smaller time throws "[Ring] ...")
--   ring:latest() → (time?, position?)
--   ring:at(time) → Vector3?        the position at `time`: linear between the two samples around it, the oldest sample
--                                   before the ring's reach, the newest after it; nil when empty
--   ring.Count                      samples held (≤ capacity)

export type Ring = {
	Capacity: number,
	Count: number,
	Head: number, -- slot of the newest sample (1-based), 0 when empty
	Times: { number },
	Positions: { Vector3 },
	push: (self: Ring, time: number, position: Vector3) -> (),
	latest: (self: Ring) -> (number?, Vector3?),
	at: (self: Ring, time: number) -> Vector3?,
}

local PositionRing = {}

local function push(self: Ring, time: number, position: Vector3)
	if self.Count > 0 and time < self.Times[self.Head] then
		error(`[Ring] time {time} is before the newest sample {self.Times[self.Head]}`, 2)
	end
	local slot = self.Head % self.Capacity + 1
	self.Times[slot] = time
	self.Positions[slot] = position
	self.Head = slot
	if self.Count < self.Capacity then
		self.Count += 1
	end
end

local function latest(self: Ring): (number?, Vector3?)
	if self.Count == 0 then
		return nil, nil
	end
	return self.Times[self.Head], self.Positions[self.Head]
end

local function at(self: Ring, time: number): Vector3?
	local count = self.Count
	if count == 0 then
		return nil
	end
	local capacity = self.Capacity
	local slot = self.Head
	local newerT, newerP = self.Times[slot], self.Positions[slot]
	if time >= newerT then
		return newerP
	end
	for _ = 2, count do
		slot = (slot - 2) % capacity + 1
		local t, p = self.Times[slot], self.Positions[slot]
		if time >= t then
			local span = newerT - t
			if span <= 0 then
				return newerP
			end
			return p:Lerp(newerP, (time - t) / span)
		end
		newerT, newerP = t, p
	end
	return newerP -- before the oldest sample
end

function PositionRing.new(capacity: number): Ring
	if typeof(capacity) ~= "number" or capacity % 1 ~= 0 or capacity < 1 then
		error(`[Ring] capacity must be a whole number ≥ 1, got {tostring(capacity)}`, 2)
	end
	return {
		Capacity = capacity,
		Count = 0,
		Head = 0,
		Times = table.create(capacity, 0),
		Positions = table.create(capacity, Vector3.zero),
		push = push,
		latest = latest,
		at = at,
	}
end

return table.freeze(PositionRing)
