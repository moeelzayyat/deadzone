-- tools/arena_export.luau (A2.2, D-024): writes ReplicatedStorage/Shared/Definitions/Arenas/<ID> from the template
-- ServerStorage/Arenas/<TEMPLATE>. Paste the whole file into execute_luau (datamodel Edit). Re-run after every change to
-- the template: Encounter/ArenaService fails the boot while the stored grid and the template disagree.
-- It refuses to write when the template has problems or the grid breaks a rule of Util/ArenaGrid, and lists them.
-- WRITE = false previews the result (counts and rows) without touching the place.
-- The result is one string: summary, the module's length and FNV-1a (compare with the mirror after the export), rows.

local ID = "TestArena"
local TEMPLATE = "TestArena"
local CELL_SIZE = 2
local WRITE = true

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- A clone, so Studio's per-module require cache cannot serve an older ArenaRaster or ArenaGrid.
local shared = ReplicatedStorage.Shared:Clone()
local ArenaRaster = require(shared.Util.ArenaRaster)
local ArenaGrid = require(shared.Util.ArenaGrid)

local function fnv(s: string): number
	local h = 2166136261
	for i = 1, #s do
		h = bit32.bxor(h, string.byte(s, i))
		h = (bit32.lshift(h, 24) + h * 403) % 2 ^ 32
	end
	return h
end

local arenas = ServerStorage:FindFirstChild("Arenas")
local template = arenas and arenas:FindFirstChild(TEMPLATE)
if template == nil then
	return `no template ServerStorage/Arenas/{TEMPLATE}`
end
local startedAt = os.clock()
local result, problems = ArenaRaster.rasterize(template, CELL_SIZE)
local elapsed = (os.clock() - startedAt) * 1000
if result == nil then
	return "template problems, nothing written:\n" .. table.concat(problems, "\n")
end
local definition = {
	Id = ID,
	ZoneId = result.ZoneId,
	Template = TEMPLATE,
	CellSize = result.CellSize,
	Width = result.Width,
	Depth = result.Depth,
	PlayerSpawn = result.PlayerSpawn,
	SpawnEdges = result.SpawnEdges,
	Rows = result.Rows,
}
local gridProblems = ArenaGrid.problems(definition)
local lines = {}
if #gridProblems > 0 then
	table.insert(lines, "grid problems, nothing written:")
	for _, problem in gridProblems do
		table.insert(lines, problem)
	end
else
	local grid = ArenaGrid.new(definition)
	local edges = {}
	for _, edge in grid.edges do
		table.insert(edges, `{edge.Id} {#grid:edgeCells(edge.Id)}`)
	end
	local source = ArenaRaster.source(ID, TEMPLATE, result)
	local status = "preview only (WRITE = false)"
	if WRITE then
		local definitions = ReplicatedStorage.Shared.Definitions
		local folder = definitions:FindFirstChild("Arenas")
		if folder == nil then
			folder = Instance.new("Folder")
			folder.Name = "Arenas"
			folder.Parent = definitions
		end
		local module = folder:FindFirstChild(ID)
		if module == nil then
			module = Instance.new("ModuleScript")
			module.Name = ID
			module.Parent = folder
		end
		module.Source = source
		status = `written {module:GetFullName()}`
	end
	table.insert(
		lines,
		string.format(
			"%s · %d × %d cells of %d studs · open %d · blockers %d · spawn (%d,%d) · edges %s · rasterized in %.2f ms",
			status,
			grid.width,
			grid.depth,
			CELL_SIZE,
			grid.openCount,
			result.Blockers,
			grid.spawn.X,
			grid.spawn.Z,
			table.concat(edges, ", "),
			elapsed
		)
	)
	table.insert(lines, string.format("source %d bytes fnv %08x", #source, fnv(source)))
end
for _, row in result.Rows do
	table.insert(lines, row)
end
return table.concat(lines, "\n")
