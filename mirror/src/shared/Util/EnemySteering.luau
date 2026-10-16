--!strict
-- Util/EnemySteering (architecture §8.3): the movement pieces of fodder steering, all in arena-local space on the arena
-- collision grid (Util/ArenaGrid). Encounter/EnemyService combines them: seek (a FlowField direction, or straight at a
-- target in sight) + separation from neighbours + wall slide.
--   local walls = EnemySteering.walls(grid)
--   walls:open(x, z) → boolean                       is the cell under local (x, z) open
--   walls:slide(x, z, dx, dz, radius) → (x, z)       move a circle by (dx, dz), then push it out of the blocked cells
--                                                    it overlaps, deepest first (closest point, up to 4 passes), so
--                                                    the part of a move into a wall is dropped and the rest slides
--                                                    along it; a move must be shorter than the radius, so the
--                                                    centre never crosses into a blocked cell (callers substep)
--   walls:clear(ax, az, bx, bz) → boolean            every cell on the segment is open (half-cell samples)
--   local buckets = EnemySteering.buckets(cellSize)  a spatial hash of items with a Pos (Vector3)
--   buckets:clear() · buckets:insert(item) · buckets:gather(position, out) → count   (items in the 3 × 3 cells around)
--   EnemySteering.separation(item, neighbours, count, margin) → Vector3   sum of pushes away from overlapping neighbours,
--                                                    each scaled by its overlap fraction (0..1)
--   EnemySteering.resolve(item, neighbours, count) → Vector3   half of each overlap with a neighbour (bodies closer than
--                                                    the sum of their radii), as the offset that pushes item out
--   EnemySteering.yaw(dx, dz) → number               heading for CFrame.Angles(0, yaw, 0) whose look vector is (dx, 0, dz)

local ArenaGrid = require(script.Parent.ArenaGrid)

export type Walls = {
	open: (self: Walls, x: number, z: number) -> boolean,
	slide: (self: Walls, x: number, z: number, dx: number, dz: number, radius: number) -> (number, number),
	clear: (self: Walls, ax: number, az: number, bx: number, bz: number) -> boolean,
}

export type Item = { Pos: Vector3, Radius: number }

export type Buckets = {
	size: number,
	clear: (self: Buckets) -> (),
	insert: (self: Buckets, item: Item) -> (),
	gather: (self: Buckets, position: Vector3, out: { Item }) -> number,
}

local SKIN = 1e-3 -- gap kept between a circle and a wall it stops against

local EnemySteering = {}

function EnemySteering.walls(grid: ArenaGrid.Grid): Walls
	local width, depth, size = grid.width, grid.depth, grid.cellSize
	local minX, minZ = -width * size / 2, -depth * size / 2
	local open = buffer.create(width * depth)
	for z = 1, depth do
		for x = 1, width do
			if grid:isOpen(x, z) then
				buffer.writeu8(open, (z - 1) * width + (x - 1), 1)
			end
		end
	end

	local function cellX(x: number): number
		return math.floor((x - minX) / size)
	end
	local function cellZ(z: number): number
		return math.floor((z - minZ) / size)
	end
	local function openCell(cx: number, cz: number): boolean
		return cx >= 0 and cx < width and cz >= 0 and cz < depth and buffer.readu8(open, cz * width + cx) == 1
	end

	local walls = {} :: Walls

	function walls.open(_: Walls, x: number, z: number): boolean
		return openCell(cellX(x), cellZ(z))
	end

	function walls.slide(_: Walls, x: number, z: number, dx: number, dz: number, radius: number): (number, number)
		local nx, nz = x + dx, z + dz
		for _ = 1, 4 do
			-- push out of the deepest overlap first; a flat wall made of many cells then never pushes from its seams
			local deepest, bx0, bz0 = 0, 0, 0
			for cz = cellZ(nz - radius), cellZ(nz + radius) do
				for cx = cellX(nx - radius), cellX(nx + radius) do
					if openCell(cx, cz) then
						continue
					end
					local x0, z0 = minX + cx * size, minZ + cz * size
					local px, pz = math.clamp(nx, x0, x0 + size), math.clamp(nz, z0, z0 + size)
					local d = math.sqrt((nx - px) ^ 2 + (nz - pz) ^ 2)
					local depth = if d < 1e-6 then radius + size else radius - d
					if depth > deepest then
						deepest, bx0, bz0 = depth, x0, z0
					end
				end
			end
			if deepest <= 0 then
				break
			end
			local x1, z1 = bx0 + size, bz0 + size
			local px, pz = math.clamp(nx, bx0, x1), math.clamp(nz, bz0, z1)
			local ox, oz = nx - px, nz - pz
			local d = math.sqrt(ox * ox + oz * oz)
			if d >= 1e-6 then
				local push = radius - d + SKIN
				nx += ox / d * push
				nz += oz / d * push
			else
				-- the centre is inside the blocked cell: leave through its nearest face
				local west, east, north, south = nx - bx0, x1 - nx, nz - bz0, z1 - nz
				local least = math.min(west, east, north, south)
				if least == west then
					nx = bx0 - radius - SKIN
				elseif least == east then
					nx = x1 + radius + SKIN
				elseif least == north then
					nz = bz0 - radius - SKIN
				else
					nz = z1 + radius + SKIN
				end
			end
		end
		return nx, nz
	end

	function walls.clear(_: Walls, ax: number, az: number, bx: number, bz: number): boolean
		local dx, dz = bx - ax, bz - az
		local steps = math.max(1, math.ceil(math.sqrt(dx * dx + dz * dz) / (size / 2)))
		for i = 0, steps do
			local t = i / steps
			if not openCell(cellX(ax + dx * t), cellZ(az + dz * t)) then
				return false
			end
		end
		return true
	end

	return walls
end

function EnemySteering.buckets(cellSize: number): Buckets
	local cells: { [number]: { Item } } = {}
	local used: { { Item } } = {}
	local buckets = {} :: Buckets
	buckets.size = cellSize

	local function key(bx: number, bz: number): number
		return (bx + 32768) * 65536 + (bz + 32768)
	end

	function buckets.clear(_: Buckets)
		for _, list in used do
			table.clear(list)
		end
		table.clear(used)
	end

	function buckets.insert(_: Buckets, item: Item)
		local p = item.Pos
		local k = key(math.floor(p.X / cellSize), math.floor(p.Z / cellSize))
		local list = cells[k]
		if list == nil then
			list = {}
			cells[k] = list
		end
		if #list == 0 then
			table.insert(used, list)
		end
		table.insert(list, item)
	end

	function buckets.gather(_: Buckets, position: Vector3, out: { Item }): number
		local bx, bz = math.floor(position.X / cellSize), math.floor(position.Z / cellSize)
		local n = 0
		for ox = -1, 1 do
			for oz = -1, 1 do
				local list = cells[key(bx + ox, bz + oz)]
				if list then
					for _, item in list do
						n += 1
						out[n] = item
					end
				end
			end
		end
		return n
	end

	return buckets
end

function EnemySteering.separation(item: Item, neighbours: { Item }, count: number, margin: number): Vector3
	local px, pz = item.Pos.X, item.Pos.Z
	local sx, sz = 0, 0
	for i = 1, count do
		local other = neighbours[i]
		if other == item then
			continue
		end
		local dx, dz = px - other.Pos.X, pz - other.Pos.Z
		local reach = item.Radius + other.Radius + margin
		local d2 = dx * dx + dz * dz
		if d2 >= reach * reach then
			continue
		end
		local d = math.sqrt(d2)
		local push = (reach - d) / reach
		if d < 1e-4 then
			-- exactly on top of each other: split along a direction fixed by the pair, so the two separate
			local a = (tostring(item) < tostring(other)) and 1 or -1
			sx += a * push
		else
			sx += dx / d * push
			sz += dz / d * push
		end
	end
	return Vector3.new(sx, 0, sz)
end

function EnemySteering.resolve(item: Item, neighbours: { Item }, count: number): Vector3
	local px, pz = item.Pos.X, item.Pos.Z
	local ox, oz = 0, 0
	for i = 1, count do
		local other = neighbours[i]
		if other == item then
			continue
		end
		local dx, dz = px - other.Pos.X, pz - other.Pos.Z
		local reach = item.Radius + other.Radius
		local d2 = dx * dx + dz * dz
		if d2 >= reach * reach or d2 < 1e-8 then
			continue
		end
		local d = math.sqrt(d2)
		local depth = (reach - d) / 2
		ox += dx / d * depth
		oz += dz / d * depth
	end
	return Vector3.new(ox, 0, oz)
end

function EnemySteering.yaw(dx: number, dz: number): number
	return math.atan2(-dx, -dz)
end

return table.freeze(EnemySteering)
