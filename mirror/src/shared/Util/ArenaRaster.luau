--!strict
-- Util/ArenaRaster (architecture §4.4, §8.3): turns an arena template (a Model in ServerStorage/Arenas) into the
-- collision grid data of its Arenas definition. tools/arena_export.luau writes the definition from it; ArenaService
-- re-runs it at boot and fails the boot when the stored grid no longer matches the geometry.
-- Template layout:
--   Floor            BasePart, upright; its top-face centre is the arena origin and the model's pivot (GetPivot, so
--                    leave PrimaryPart unset or give the floor that PivotOffset). The grid
--                    covers the floor: Width = Size.X / CellSize, Depth = Size.Z / CellSize (whole numbers).
--   Markers/PlayerSpawn          BasePart: the cell under its position is the player spawn.
--   Markers/SpawnEdge_<Id>       BaseParts: the cells whose centres lie inside the part's footprint form spawn edge <Id>.
--   anything else    every other BasePart with CanCollide on blocks the cells its footprint overlaps, when it reaches
--                    into the walking band (BAND_LOW..BAND_HIGH studs above the floor). Blocking parts must stand upright
--                    (one axis vertical); a tilted one is a problem. Non-colliding parts (paint, lights) never block.
--   ZoneId attribute on the model: the definition's ZoneId.
-- Pure: reads the template, writes nothing.

local ArenaRaster = {
	BAND_LOW = 0.25, -- studs above the floor; road paint and kerb trims below this never block
	BAND_HIGH = 8, -- above the tallest character (survivor 7, ART_BIBLE); overhead signs never block
	EPSILON = 0.01, -- footprints that only touch a cell edge do not block it
}

export type Cell = { X: number, Z: number }
export type Edge = { Id: string, Min: Cell, Max: Cell }
export type Result = {
	ZoneId: string,
	CellSize: number,
	Width: number,
	Depth: number,
	PlayerSpawn: Cell,
	SpawnEdges: { Edge },
	Rows: { string },
	Blockers: number, -- parts that blocked at least one cell
}

type Footprint = {
	cx: number,
	cz: number,
	ux: number,
	uz: number,
	hu: number,
	vx: number,
	vz: number,
	hv: number,
	low: number,
	high: number,
}

local VERTICAL = 0.999

-- The part's footprint in arena-local space, or nil and a reason when no axis is vertical.
local function footprint(origin: CFrame, part: BasePart): (Footprint?, string?)
	local cf = origin:ToObjectSpace(part.CFrame)
	local axes = { cf.RightVector, cf.UpVector, -cf.LookVector }
	local sizes = { part.Size.X, part.Size.Y, part.Size.Z }
	local vertical: number? = nil
	for index, axis in axes do
		if math.abs(axis.Y) >= VERTICAL then
			vertical = index
		end
	end
	if vertical == nil then
		return nil, "is tilted; blocking parts must stand upright (one axis vertical)"
	end
	local flat: { number } = {}
	for index = 1, 3 do
		if index ~= vertical then
			table.insert(flat, index)
		end
	end
	local u, v = axes[flat[1]], axes[flat[2]]
	local ul = math.sqrt(u.X * u.X + u.Z * u.Z)
	local vl = math.sqrt(v.X * v.X + v.Z * v.Z)
	local half = sizes[vertical :: number] / 2
	return {
		cx = cf.Position.X,
		cz = cf.Position.Z,
		ux = u.X / ul,
		uz = u.Z / ul,
		hu = sizes[flat[1]] / 2,
		vx = v.X / vl,
		vz = v.Z / vl,
		hv = sizes[flat[2]] / 2,
		low = cf.Position.Y - half,
		high = cf.Position.Y + half,
	}, nil
end

-- Separating-axis test between a footprint and an axis-aligned cell square (centre x, z; half size h).
local function overlaps(f: Footprint, x: number, z: number, h: number): boolean
	local eps = ArenaRaster.EPSILON
	local dx, dz = f.cx - x, f.cz - z
	-- cell axes X and Z
	local ex = math.abs(f.ux) * f.hu + math.abs(f.vx) * f.hv
	if math.abs(dx) >= ex + h - eps then
		return false
	end
	local ez = math.abs(f.uz) * f.hu + math.abs(f.vz) * f.hv
	if math.abs(dz) >= ez + h - eps then
		return false
	end
	-- footprint axes u and v
	local du = math.abs(dx * f.ux + dz * f.uz)
	if du >= f.hu + h * (math.abs(f.ux) + math.abs(f.uz)) - eps then
		return false
	end
	local dv = math.abs(dx * f.vx + dz * f.vz)
	if dv >= f.hv + h * (math.abs(f.vx) + math.abs(f.vz)) - eps then
		return false
	end
	return true
end

local function isUnder(part: Instance, ancestor: Instance?): boolean
	return ancestor ~= nil and part:IsDescendantOf(ancestor)
end

-- The arena origin of a template: the centre of the floor's top face.
function ArenaRaster.origin(floor: BasePart): CFrame
	return floor.CFrame * CFrame.new(0, floor.Size.Y / 2, 0)
end

-- Rasterizes a template. Returns the result, or nil and every problem found.
function ArenaRaster.rasterize(template: Instance, cellSize: number): (Result?, { string })
	local problems: { string } = {}
	local floor = template:FindFirstChild("Floor")
	if floor == nil or not floor:IsA("BasePart") then
		return nil, { `{template.Name}: needs a BasePart named Floor` }
	end
	local floorPart = floor :: BasePart
	local origin = ArenaRaster.origin(floorPart)
	if math.abs(origin.UpVector.Y) < VERTICAL then
		table.insert(problems, "Floor must be level (its top face pointing up)")
	end
	if template:IsA("Model") then
		local pivot = (template :: Model):GetPivot()
		if (pivot.Position - origin.Position).Magnitude > 0.01 or pivot.UpVector:Dot(origin.UpVector) < VERTICAL then
			table.insert(problems, "the model's pivot must be the centre of the floor's top face (ArenaService places arenas by pivot)")
		end
	end
	local width = floorPart.Size.X / cellSize
	local depth = floorPart.Size.Z / cellSize
	if width % 1 ~= 0 or depth % 1 ~= 0 then
		table.insert(problems, `Floor size {floorPart.Size.X} × {floorPart.Size.Z} is not a whole number of {cellSize}-stud cells`)
	end
	local zoneId = template:GetAttribute("ZoneId")
	if typeof(zoneId) ~= "string" or zoneId == "" then
		table.insert(problems, "the template needs a ZoneId attribute (string)")
	end
	if #problems > 0 then
		return nil, problems
	end
	local markers = template:FindFirstChild("Markers")
	local half = cellSize / 2
	local minX, minZ = -width * cellSize / 2, -depth * cellSize / 2
	local blocked = buffer.create(width * depth)
	local blockers = 0

	local parts: { BasePart } = {}
	for _, descendant in template:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= floorPart and not isUnder(descendant, markers) and descendant.CanCollide then
			table.insert(parts, descendant)
		end
	end
	for _, part in parts do
		local f, why = footprint(origin, part)
		if f == nil then
			table.insert(problems, `{part:GetFullName()} {why}`)
			continue
		end
		local shape = f :: Footprint
		if shape.high <= ArenaRaster.BAND_LOW or shape.low >= ArenaRaster.BAND_HIGH then
			continue
		end
		local ex = math.abs(shape.ux) * shape.hu + math.abs(shape.vx) * shape.hv
		local ez = math.abs(shape.uz) * shape.hu + math.abs(shape.vz) * shape.hv
		local x0 = math.max(1, math.floor((shape.cx - ex - minX) / cellSize) + 1)
		local x1 = math.min(width, math.floor((shape.cx + ex - minX) / cellSize) + 1)
		local z0 = math.max(1, math.floor((shape.cz - ez - minZ) / cellSize) + 1)
		local z1 = math.min(depth, math.floor((shape.cz + ez - minZ) / cellSize) + 1)
		local any = false
		for z = z0, z1 do
			for x = x0, x1 do
				if overlaps(shape, minX + (x - 0.5) * cellSize, minZ + (z - 0.5) * cellSize, half) then
					buffer.writeu8(blocked, (z - 1) * width + (x - 1), 1)
					any = true
				end
			end
		end
		if any then
			blockers += 1
		end
	end

	local function cellOf(position: Vector3): (number, number)
		local p = origin:PointToObjectSpace(position)
		return math.floor((p.X - minX) / cellSize) + 1, math.floor((p.Z - minZ) / cellSize) + 1
	end

	local spawn: Cell = { X = 0, Z = 0 }
	local edges: { Edge } = {}
	local spawnPart = markers and markers:FindFirstChild("PlayerSpawn")
	if spawnPart == nil or not spawnPart:IsA("BasePart") then
		table.insert(problems, "needs a BasePart Markers/PlayerSpawn")
	else
		local x, z = cellOf((spawnPart :: BasePart).Position)
		spawn = { X = x, Z = z }
	end
	if markers ~= nil then
		for _, marker in markers:GetChildren() do
			local id = string.match(marker.Name, "^SpawnEdge_(%w+)$")
			if id == nil then
				continue
			end
			if not marker:IsA("BasePart") then
				table.insert(problems, `Markers/{marker.Name} must be a BasePart`)
				continue
			end
			local f = footprint(origin, marker :: BasePart)
			if f == nil then
				table.insert(problems, `Markers/{marker.Name} must stand upright`)
				continue
			end
			local shape = f :: Footprint
			local minCell: Cell? = nil
			local maxCell: Cell? = nil
			for z = 1, depth do
				for x = 1, width do
					local px, pz = minX + (x - 0.5) * cellSize - shape.cx, minZ + (z - 0.5) * cellSize - shape.cz
					if math.abs(px * shape.ux + pz * shape.uz) <= shape.hu and math.abs(px * shape.vx + pz * shape.vz) <= shape.hv then
						minCell = { X = math.min(x, if minCell then minCell.X else x), Z = math.min(z, if minCell then minCell.Z else z) }
						maxCell = { X = math.max(x, if maxCell then maxCell.X else x), Z = math.max(z, if maxCell then maxCell.Z else z) }
					end
				end
			end
			if minCell == nil or maxCell == nil then
				table.insert(problems, `Markers/{marker.Name} covers no cell centre`)
				continue
			end
			table.insert(edges, { Id = id :: string, Min = minCell :: Cell, Max = maxCell :: Cell })
		end
	end
	table.sort(edges, function(a: Edge, b: Edge): boolean
		return a.Id < b.Id
	end)
	if #edges == 0 then
		table.insert(problems, "needs at least one Markers/SpawnEdge_<Id> part")
	end
	if #problems > 0 then
		return nil, problems
	end

	local rows: { string } = {}
	local line = buffer.create(width)
	for z = 1, depth do
		for x = 1, width do
			buffer.writeu8(line, x - 1, if buffer.readu8(blocked, (z - 1) * width + (x - 1)) == 1 then 35 else 46) -- '#' / '.'
		end
		table.insert(rows, buffer.tostring(line))
	end
	return {
		ZoneId = zoneId :: string,
		CellSize = cellSize,
		Width = width,
		Depth = depth,
		PlayerSpawn = spawn,
		SpawnEdges = edges,
		Rows = rows,
		Blockers = blockers,
	},
		problems
end

local function sameCell(a: Cell, b: Cell): boolean
	return a.X == b.X and a.Z == b.Z
end

-- Differences between a stored definition and a fresh rasterization (empty when they agree).
function ArenaRaster.diff(definition: { [string]: any }, result: Result): { string }
	local out: { string } = {}
	if definition.ZoneId ~= result.ZoneId then
		table.insert(out, `ZoneId {tostring(definition.ZoneId)} vs template {result.ZoneId}`)
	end
	if definition.Width ~= result.Width or definition.Depth ~= result.Depth then
		table.insert(out, `size {definition.Width} × {definition.Depth} vs template {result.Width} × {result.Depth}`)
		return out
	end
	local cells, first = 0, nil :: string?
	for z = 1, result.Depth do
		local stored: string = definition.Rows[z] or ""
		local fresh = result.Rows[z]
		if stored ~= fresh then
			for x = 1, result.Width do
				if string.sub(stored, x, x) ~= string.sub(fresh, x, x) then
					cells += 1
					first = first or `({x},{z})`
				end
			end
		end
	end
	if cells > 0 then
		table.insert(out, `{cells} cells differ, first at {first}`)
	end
	if not sameCell(definition.PlayerSpawn, result.PlayerSpawn) then
		table.insert(out, "PlayerSpawn moved")
	end
	local edges: { Edge } = definition.SpawnEdges
	if #edges ~= #result.SpawnEdges then
		table.insert(out, `{#edges} spawn edges vs template {#result.SpawnEdges}`)
	else
		for index, edge in result.SpawnEdges do
			local stored = edges[index]
			if stored.Id ~= edge.Id or not sameCell(stored.Min, edge.Min) or not sameCell(stored.Max, edge.Max) then
				table.insert(out, `spawn edge {edge.Id} differs`)
			end
		end
	end
	return out
end

local function cellText(cell: Cell): string
	return `\{ X = {cell.X}, Z = {cell.Z} \}`
end

-- The ModuleScript source of the Arenas definition for a result (tools/arena_export.luau writes it).
function ArenaRaster.source(id: string, template: string, result: Result): string
	local lines = {
		"--!strict",
		`-- Arena {id} (architecture §8.3): collision grid exported from ServerStorage/Arenas/{template} by`,
		"-- tools/arena_export.luau; do not edit by hand, re-export instead (Encounter/ArenaService checks it against the",
		"-- template at boot). '#' blocked, '.' open; row 1 is the north (-Z) edge, column 1 the west (-X) edge.",
		"return {",
		`\tId = "{id}",`,
		`\tZoneId = "{result.ZoneId}",`,
		`\tTemplate = "{template}",`,
		`\tCellSize = {result.CellSize},`,
		`\tWidth = {result.Width},`,
		`\tDepth = {result.Depth},`,
		`\tPlayerSpawn = {cellText(result.PlayerSpawn)},`,
		"\tSpawnEdges = {",
	}
	for _, edge in result.SpawnEdges do
		table.insert(lines, `\t\t\{ Id = "{edge.Id}", Min = {cellText(edge.Min)}, Max = {cellText(edge.Max)} \},`)
	end
	table.insert(lines, "\t},")
	table.insert(lines, "\tRows = {")
	for _, row in result.Rows do
		table.insert(lines, `\t\t"{row}",`)
	end
	table.insert(lines, "\t},")
	table.insert(lines, "}")
	return table.concat(lines, "\n") .. "\n"
end

return table.freeze(ArenaRaster)
