--!strict
-- Util/ArenaGrid (architecture §8.3): the precomputed collision grid of an arena, read by enemy steering (A2.3) and wall
-- slide. Built from an Arenas definition (Shared/Definitions/Arenas, exported from the template by
-- tools/arena_export.luau and checked against the template by Encounter/ArenaService at boot).
-- Arena-local space: the origin is the centre of the floor's top face, +Y up; the grid is centred on it. Cell (1, 1) is
-- the -X/-Z corner (west/north: the default camera looks toward -Z); column X runs along +X, row Z along +Z.
--   local grid = ArenaGrid.new(definition)      -- throws "[Arena] ..." on any problem (problems() lists them)
--   grid:isOpen(x, z)                            -- false outside the grid
--   grid:cellAt(localPosition) → x?, z?          -- nil outside the grid
--   grid:center(x, z) → Vector3                  -- local centre of a cell at floor height
--   grid:edgeCells(edgeId) → { Cell }            -- the open cells of a spawn edge
--   grid:reach(x, z) → (visited buffer, count)   -- 4-neighbour flood fill over open cells
-- Rules (problems()): rows match Width × Depth and use only '.' (open) and '#' (blocked); the outer ring is blocked, so
-- nothing leaves the grid; the player spawn is open; every open cell is reachable from it (no sealed pockets); every
-- open cell lies in a fully open 2 × 2 block (no passage narrower than two cells, where steering would snag); spawn
-- edges have unique Ids, lie inside the grid and hold at least MIN_EDGE_CELLS open cells.

export type Cell = { X: number, Z: number }
export type Edge = { Id: string, Min: Cell, Max: Cell }
export type Data = {
	CellSize: number,
	Width: number,
	Depth: number,
	Rows: { string },
	PlayerSpawn: Cell,
	SpawnEdges: { Edge },
}

export type Grid = {
	cellSize: number,
	width: number,
	depth: number,
	openCount: number,
	spawn: Cell,
	edges: { Edge },
	isOpen: (self: Grid, x: number, z: number) -> boolean,
	cellAt: (self: Grid, position: Vector3) -> (number?, number?),
	openAt: (self: Grid, position: Vector3) -> boolean,
	center: (self: Grid, x: number, z: number) -> Vector3,
	edgeCells: (self: Grid, edgeId: string) -> { Cell },
	reach: (self: Grid, x: number, z: number) -> (buffer, number),
}

local OPEN = string.byte(".")
local MIN_EDGE_CELLS = 8
local MAX_LISTED = 5

local ArenaGrid = {
	MIN_EDGE_CELLS = MIN_EDGE_CELLS,
	OPEN = ".",
	BLOCKED = "#",
}

local function inside(width: number, depth: number, x: number, z: number): boolean
	return x >= 1 and x <= width and z >= 1 and z <= depth and x % 1 == 0 and z % 1 == 0
end

-- One byte per cell, 1 = open. Assumes the rows already have the right shape.
local function cellsOf(data: Data): buffer
	local cells = buffer.create(data.Width * data.Depth)
	for z, row in data.Rows do
		for x = 1, data.Width do
			if string.byte(row, x) == OPEN then
				buffer.writeu8(cells, (z - 1) * data.Width + (x - 1), 1)
			end
		end
	end
	return cells
end

local function flood(cells: buffer, width: number, depth: number, x: number, z: number): (buffer, number)
	local visited = buffer.create(width * depth)
	local start = (z - 1) * width + (x - 1)
	if not inside(width, depth, x, z) or buffer.readu8(cells, start) ~= 1 then
		return visited, 0
	end
	local queue = { start }
	buffer.writeu8(visited, start, 1)
	local head, count = 1, 1
	while head <= #queue do
		local index = queue[head]
		head += 1
		local cx, cz = index % width, index // width
		local function visit(nx: number, nz: number)
			if nx < 0 or nx >= width or nz < 0 or nz >= depth then
				return
			end
			local n = nz * width + nx
			if buffer.readu8(cells, n) == 1 and buffer.readu8(visited, n) == 0 then
				buffer.writeu8(visited, n, 1)
				count += 1
				table.insert(queue, n)
			end
		end
		visit(cx + 1, cz)
		visit(cx - 1, cz)
		visit(cx, cz + 1)
		visit(cx, cz - 1)
	end
	return visited, count
end

local function listed(cells: { string }, total: number): string
	local text = table.concat(cells, " ", 1, math.min(#cells, MAX_LISTED))
	if total > MAX_LISTED then
		text ..= ` … (+{total - MAX_LISTED})`
	end
	return text
end

-- Every rule broken by the data, as readable messages (empty when the grid is usable). Expects the field types the
-- Arenas schema checks (numbers, strings, records).
function ArenaGrid.problems(data: Data): { string }
	local problems: { string } = {}
	local width, depth = data.Width, data.Depth
	if #data.Rows ~= depth then
		table.insert(problems, `Rows: {#data.Rows} rows, Depth is {depth}`)
		return problems
	end
	for z, row in data.Rows do
		if #row ~= width then
			table.insert(problems, `Rows[{z}]: {#row} cells, Width is {width}`)
		elseif string.find(row, "[^%.#]") ~= nil then
			table.insert(problems, `Rows[{z}]: only '.' (open) and '#' (blocked) are allowed`)
		end
	end
	if #problems > 0 then
		return problems
	end
	local cells = cellsOf(data)
	local function open(x: number, z: number): boolean
		return inside(width, depth, x, z) and buffer.readu8(cells, (z - 1) * width + (x - 1)) == 1
	end

	local border: { string } = {}
	for z = 1, depth do
		for x = 1, width do
			if (x == 1 or z == 1 or x == width or z == depth) and open(x, z) then
				table.insert(border, `({x},{z})`)
			end
		end
	end
	if #border > 0 then
		table.insert(problems, `the outer ring must be blocked so nothing leaves the grid; open: {listed(border, #border)}`)
	end

	local spawn = data.PlayerSpawn
	local spawnOk = open(spawn.X, spawn.Z)
	if not spawnOk then
		table.insert(problems, `PlayerSpawn ({spawn.X},{spawn.Z}) must be an open cell inside the grid`)
	end

	local pinched: { string } = {}
	local openCount = 0
	for z = 1, depth do
		for x = 1, width do
			if not open(x, z) then
				continue
			end
			openCount += 1
			local fits = false
			for dz = -1, 0 do
				for dx = -1, 0 do
					if open(x + dx, z + dz) and open(x + dx + 1, z + dz) and open(x + dx, z + dz + 1) and open(x + dx + 1, z + dz + 1) then
						fits = true
					end
				end
			end
			if not fits then
				table.insert(pinched, `({x},{z})`)
			end
		end
	end
	if #pinched > 0 then
		table.insert(problems, `{#pinched} open cells are in a passage narrower than 2 cells: {listed(pinched, #pinched)}`)
	end

	if spawnOk then
		local visited, count = flood(cells, width, depth, spawn.X, spawn.Z)
		if count < openCount then
			local sealed: { string } = {}
			for z = 1, depth do
				for x = 1, width do
					local index = (z - 1) * width + (x - 1)
					if buffer.readu8(cells, index) == 1 and buffer.readu8(visited, index) == 0 then
						table.insert(sealed, `({x},{z})`)
					end
				end
			end
			table.insert(problems, `{#sealed} open cells cannot be reached from PlayerSpawn: {listed(sealed, #sealed)}`)
		end
	end

	local seen: { [string]: boolean } = {}
	for index, edge in data.SpawnEdges do
		local label = `SpawnEdges[{index}] {edge.Id}`
		if seen[edge.Id] then
			table.insert(problems, `{label}: duplicate edge Id`)
		end
		seen[edge.Id] = true
		local min, max = edge.Min, edge.Max
		if not inside(width, depth, min.X, min.Z) or not inside(width, depth, max.X, max.Z) then
			table.insert(problems, `{label}: Min/Max must lie inside the {width} × {depth} grid`)
			continue
		end
		if min.X > max.X or min.Z > max.Z then
			table.insert(problems, `{label}: Min must not exceed Max`)
			continue
		end
		local count = 0
		for z = min.Z, max.Z do
			for x = min.X, max.X do
				if open(x, z) then
					count += 1
				end
			end
		end
		if count < MIN_EDGE_CELLS then
			table.insert(problems, `{label}: {count} open cells, at least {MIN_EDGE_CELLS} needed`)
		end
	end
	return problems
end

function ArenaGrid.new(data: Data): Grid
	local problems = ArenaGrid.problems(data)
	if #problems > 0 then
		error(`[Arena] {#problems} problems: {table.concat(problems, "; ")}`, 2)
	end
	local width, depth, size = data.Width, data.Depth, data.CellSize
	local cells = cellsOf(data)
	local minX, minZ = -width * size / 2, -depth * size / 2
	local openCount = 0
	for index = 0, width * depth - 1 do
		openCount += buffer.readu8(cells, index)
	end
	local edges: { Edge } = {}
	local byId: { [string]: Edge } = {}
	for _, edge in data.SpawnEdges do
		local copy = table.freeze({
			Id = edge.Id,
			Min = table.freeze({ X = edge.Min.X, Z = edge.Min.Z }),
			Max = table.freeze({ X = edge.Max.X, Z = edge.Max.Z }),
		})
		table.insert(edges, copy)
		byId[edge.Id] = copy
	end

	local grid = {} :: Grid
	grid.cellSize = size
	grid.width = width
	grid.depth = depth
	grid.openCount = openCount
	grid.spawn = table.freeze({ X = data.PlayerSpawn.X, Z = data.PlayerSpawn.Z })
	grid.edges = table.freeze(edges)

	function grid.isOpen(_: Grid, x: number, z: number): boolean
		return inside(width, depth, x, z) and buffer.readu8(cells, (z - 1) * width + (x - 1)) == 1
	end

	function grid.cellAt(_: Grid, position: Vector3): (number?, number?)
		local x = math.floor((position.X - minX) / size) + 1
		local z = math.floor((position.Z - minZ) / size) + 1
		if x < 1 or x > width or z < 1 or z > depth then
			return nil, nil
		end
		return x, z
	end

	function grid.openAt(self: Grid, position: Vector3): boolean
		local x, z = self:cellAt(position)
		return x ~= nil and z ~= nil and buffer.readu8(cells, (z - 1) * width + (x - 1)) == 1
	end

	function grid.center(_: Grid, x: number, z: number): Vector3
		return Vector3.new(minX + (x - 0.5) * size, 0, minZ + (z - 0.5) * size)
	end

	function grid.edgeCells(self: Grid, edgeId: string): { Cell }
		local edge = byId[edgeId]
		if edge == nil then
			error(`[Arena] unknown spawn edge {edgeId}`, 2)
		end
		local out: { Cell } = {}
		for z = edge.Min.Z, edge.Max.Z do
			for x = edge.Min.X, edge.Max.X do
				if self:isOpen(x, z) then
					table.insert(out, { X = x, Z = z })
				end
			end
		end
		return out
	end

	function grid.reach(_: Grid, x: number, z: number): (buffer, number)
		return flood(cells, width, depth, x, z)
	end

	return table.freeze(grid)
end

return table.freeze(ArenaGrid)
