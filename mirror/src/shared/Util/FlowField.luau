--!strict
-- Util/FlowField (architecture §8.3): a distance field over an arena collision grid toward one target cell, shared by
-- every fodder enemy chasing that target. One field per target player replaces per-enemy PathfindingService: each enemy
-- steers toward the neighbouring cell that is closest to the target and slides along walls (Util/EnemySteering).
-- Distances use 2 per straight step and 3 per diagonal step (an octile approximation of studs), plus WALL_COST for
-- entering a cell that touches a blocked cell, so paths keep off walls where there is room (a body is wider than half a
-- cell); a diagonal step needs both cells beside it open, so a field never cuts a wall corner. Built with a bucket queue
-- (Dial's algorithm), O(cells).
-- Cells use ArenaGrid indexing: (1, 1) is the -X/-Z corner, positions are arena-local.
--   local field = FlowField.new(grid)
--   field:build(x, z) → boolean          recompute toward cell (x, z); false (field unchanged) if it is not open
--   field:distance(x, z) → number        path cost to the target; UNREACHED for blocked or unreached cells
--   field:next(x, z) → (nx?, nz?)        the neighbour one step closer to the target; nil at the target or unreached
--   field:direction(position) → (dx, dz) unit direction from a position toward the centre of its cell's next cell;
--                                         (0, 0) at the target cell or off the field

local ArenaGrid = require(script.Parent.ArenaGrid)

export type Field = {
	grid: ArenaGrid.Grid,
	targetX: number, -- 0 until the first build
	targetZ: number,
	builds: number,
	build: (self: Field, x: number, z: number) -> boolean,
	distance: (self: Field, x: number, z: number) -> number,
	next: (self: Field, x: number, z: number) -> (number?, number?),
	direction: (self: Field, position: Vector3) -> (number, number),
}

local UNREACHED = 65535
local STRAIGHT = 2
local DIAGONAL = 3
local WALL_COST = 2

local FlowField = { UNREACHED = UNREACHED, STRAIGHT = STRAIGHT, DIAGONAL = DIAGONAL, WALL_COST = WALL_COST }

function FlowField.new(grid: ArenaGrid.Grid): Field
	local width, depth, size = grid.width, grid.depth, grid.cellSize
	local cells = width * depth
	local minX, minZ = -width * size / 2, -depth * size / 2
	-- Open cells as bytes (1 = open), 0-based index z * width + x. The outer ring is blocked (ArenaGrid rule), so every
	-- neighbour of an open cell lies inside the grid and needs no bounds check.
	local open = buffer.create(cells)
	for z = 1, depth do
		for x = 1, width do
			if grid:isOpen(x, z) then
				buffer.writeu8(open, (z - 1) * width + (x - 1), 1)
			end
		end
	end
	-- Extra cost of entering each open cell: WALL_COST when any of its 8 neighbours is blocked.
	local extra = buffer.create(cells)
	for z = 2, depth - 1 do
		for x = 2, width - 1 do
			local i = (z - 1) * width + (x - 1)
			if buffer.readu8(open, i) == 1 then
				for oz = -1, 1 do
					for ox = -1, 1 do
						if buffer.readu8(open, i + oz * width + ox) == 0 then
							buffer.writeu8(extra, i, WALL_COST)
						end
					end
				end
			end
		end
	end
	local dist = buffer.create(cells * 2)
	buffer.fill(dist, 0, 255)
	local buckets: { { number } } = {}

	local field = {} :: Field
	field.grid = grid
	field.targetX = 0
	field.targetZ = 0
	field.builds = 0

	local function isOpen(i: number): boolean
		return buffer.readu8(open, i) == 1
	end

	function field.build(self: Field, x: number, z: number): boolean
		if not grid:isOpen(x, z) then
			return false
		end
		buffer.fill(dist, 0, 255)
		local start = (z - 1) * width + (x - 1)
		buffer.writeu16(dist, start * 2, 0)
		local first = buckets[1]
		if first == nil then
			first = {}
			buckets[1] = first
		end
		table.insert(first, start)
		local top = 0
		local d = 0
		local function relax(n: number, cost: number)
			local nd = cost + buffer.readu8(extra, n)
			if nd < buffer.readu16(dist, n * 2) then
				buffer.writeu16(dist, n * 2, nd)
				local bucket = buckets[nd + 1]
				if bucket == nil then
					bucket = {}
					buckets[nd + 1] = bucket
				end
				table.insert(bucket, n)
				if nd > top then
					top = nd
				end
			end
		end
		while d <= top do
			local bucket = buckets[d + 1]
			if bucket ~= nil and #bucket > 0 then
				for _, i in bucket do
					if buffer.readu16(dist, i * 2) ~= d then
						continue -- a stale entry; the cell was reached cheaper
					end
					local e, w, s, n = i + 1, i - 1, i + width, i - width
					local eOpen, wOpen, sOpen, nOpen = isOpen(e), isOpen(w), isOpen(s), isOpen(n)
					local straight = d + STRAIGHT
					local diagonal = d + DIAGONAL
					if eOpen then
						relax(e, straight)
					end
					if wOpen then
						relax(w, straight)
					end
					if sOpen then
						relax(s, straight)
					end
					if nOpen then
						relax(n, straight)
					end
					if eOpen and sOpen and isOpen(s + 1) then
						relax(s + 1, diagonal)
					end
					if wOpen and sOpen and isOpen(s - 1) then
						relax(s - 1, diagonal)
					end
					if eOpen and nOpen and isOpen(n + 1) then
						relax(n + 1, diagonal)
					end
					if wOpen and nOpen and isOpen(n - 1) then
						relax(n - 1, diagonal)
					end
				end
				table.clear(bucket)
			end
			d += 1
		end
		self.targetX = x
		self.targetZ = z
		self.builds += 1
		return true
	end

	function field.distance(_: Field, x: number, z: number): number
		if x < 1 or x > width or z < 1 or z > depth or x % 1 ~= 0 or z % 1 ~= 0 then
			return UNREACHED
		end
		return buffer.readu16(dist, ((z - 1) * width + (x - 1)) * 2)
	end

	function field.next(_: Field, x: number, z: number): (number?, number?)
		if x < 2 or x >= width or z < 2 or z >= depth or x % 1 ~= 0 or z % 1 ~= 0 then
			return nil, nil
		end
		local i = (z - 1) * width + (x - 1)
		local best = buffer.readu16(dist, i * 2)
		if best == 0 or best == UNREACHED then
			return nil, nil
		end
		local bx, bz = 0, 0
		local function try(n: number, dx: number, dz: number)
			local v = buffer.readu16(dist, n * 2)
			if v < best then
				best, bx, bz = v, dx, dz
			end
		end
		local eOpen, wOpen, sOpen, nOpen = isOpen(i + 1), isOpen(i - 1), isOpen(i + width), isOpen(i - width)
		if eOpen then
			try(i + 1, 1, 0)
		end
		if wOpen then
			try(i - 1, -1, 0)
		end
		if sOpen then
			try(i + width, 0, 1)
		end
		if nOpen then
			try(i - width, 0, -1)
		end
		if eOpen and sOpen then
			try(i + width + 1, 1, 1)
		end
		if wOpen and sOpen then
			try(i + width - 1, -1, 1)
		end
		if eOpen and nOpen then
			try(i - width + 1, 1, -1)
		end
		if wOpen and nOpen then
			try(i - width - 1, -1, -1)
		end
		if bx == 0 and bz == 0 then
			return nil, nil
		end
		return x + bx, z + bz
	end

	function field.direction(self: Field, position: Vector3): (number, number)
		local x = math.floor((position.X - minX) / size) + 1
		local z = math.floor((position.Z - minZ) / size) + 1
		local nx, nz = self:next(x, z)
		if nx == nil or nz == nil then
			return 0, 0
		end
		local dx = minX + (nx - 0.5) * size - position.X
		local dz = minZ + (nz - 0.5) * size - position.Z
		local m = math.sqrt(dx * dx + dz * dz)
		if m < 1e-6 then
			return 0, 0
		end
		return dx / m, dz / m
	end

	return field
end

return table.freeze(FlowField)
