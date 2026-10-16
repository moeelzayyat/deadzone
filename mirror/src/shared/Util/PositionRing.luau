--!strict
-- Util/PositionRing (architecture §7.1, §8.2): a fixed-size ring of (time, position) samples, newest last. Every enemy
-- record keeps one (`History`) so the A2.5 lag-compensated hit test can look up where an enemy was inside the 250 ms
-- rewind window. A2.3 fills it on every simulation update; the rewind query arrives with A2.5.
--   local ring = PositionRing.new(capacity)
--   ring:push(time, position)       times must not decrease (a smaller time throws "[Ring] ...")
--   ring:latest() → (time?, position?)
--   ring.Count                      samples held (≤ capacity)

export type Ring = {
	Capacity: number,
	Count: number,
	Head: number, -- slot of the newest sample (1-based), 0 when empty
	Times: { number },
	Positions: { Vector3 },
	push: (self: Ring, time: number, position: Vector3) -> (),
	latest: (self: Ring) -> (number?, Vector3?),
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
	}
end

return table.freeze(PositionRing)
