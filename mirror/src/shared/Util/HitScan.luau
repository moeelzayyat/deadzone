--!strict
-- Util/HitScan (architecture §7.1): the primary-attack hit test, flat on the floor plane (X/Z; height is ignored, every
-- enemy stands on the floor). One shared rule for the server's authoritative test (Combat/CombatService, on enemy
-- positions rewound to the request time) and the client's predicted spark (Controllers/CombatController, on the
-- positions it drew), so prediction and truth only differ by where the enemies were, never by the maths.
--   HitScan.flat(dir) → Vector3?            the unit direction on the floor plane; nil when dir is (almost) vertical
--   HitScan.cast(origin, dir, range, candidates, options?) → { Hit }
--       candidates  { { Id, Position, Radius } } (any table with those fields)
--       options     { pad?, hintId?, hintPad?, maxTargets? }
--       A ray from origin along the flat dir hits a candidate when it passes within Radius + pad of its centre and the
--       entry point lies within range. The candidate named by hintId (the enemy the client saw it hit) gets hintPad
--       more. Hits come back nearest first, at most maxTargets (default 1). A body the origin stands inside is hit at
--       distance 0.

export type Candidate = { Id: number, Position: Vector3, Radius: number }
export type Hit = { Id: number, Distance: number, Point: Vector3 }
export type Options = { pad: number?, hintId: number?, hintPad: number?, maxTargets: number? }

local PAD = 0.75 -- studs added to every body: bullet width plus the error left after a rewind
local HINT_PAD = 0.75 -- studs more for the hinted enemy (the one the client drew the hit on)
local MIN_FLAT = 0.1 -- a direction whose floor-plane part is shorter than this has no flat heading

local HitScan = {
	PAD = PAD,
	HINT_PAD = HINT_PAD,
}

function HitScan.flat(dir: Vector3): Vector3?
	local x, z = dir.X, dir.Z
	local m = math.sqrt(x * x + z * z)
	if m ~= m or m < MIN_FLAT or m == math.huge then
		return nil
	end
	return Vector3.new(x / m, 0, z / m)
end

function HitScan.cast(origin: Vector3, dir: Vector3, range: number, candidates: { any }, options: Options?): { Hit }
	local hits: { Hit } = {}
	local flat = HitScan.flat(dir)
	if flat == nil or range <= 0 then
		return hits
	end
	local pad = if options and options.pad then options.pad else PAD
	local hintId = options and options.hintId
	local hintPad = if options and options.hintPad then options.hintPad else HINT_PAD
	local maxTargets = if options and options.maxTargets then options.maxTargets else 1
	local dx, dz = flat.X, flat.Z
	local ox, oz = origin.X, origin.Z
	for _, c in candidates do
		local r = c.Radius + pad
		if hintId ~= nil and c.Id == hintId then
			r += hintPad
		end
		local p: Vector3 = c.Position
		local vx, vz = p.X - ox, p.Z - oz
		local along = vx * dx + vz * dz
		if along < -r then
			continue -- behind the shooter
		end
		local d2 = vx * vx + vz * vz
		local perp2 = d2 - along * along
		local r2 = r * r
		if perp2 > r2 then
			continue
		end
		local entry = if d2 <= r2 then 0 else along - math.sqrt(r2 - perp2)
		if entry > range then
			continue
		end
		local hit: Hit = { Id = c.Id, Distance = entry, Point = Vector3.new(ox + dx * entry, p.Y, oz + dz * entry) }
		local index = #hits + 1
		while index > 1 and hits[index - 1].Distance > entry do
			index -= 1
		end
		if index <= maxTargets then
			table.insert(hits, index, hit)
			if #hits > maxTargets then
				hits[#hits] = nil
			end
		end
	end
	return hits
end

return table.freeze(HitScan)
