--!strict
-- Util/ArenaGrid (A2.2, architecture §8.3): grid rules (shape, closed ring, open spawn, no sealed pockets, no passage
-- narrower than two cells, spawn edges), cell queries, flood fill, and the shipped TestArena grid. Runs on a clone of
-- Shared.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestRunner = require(script.Parent.Parent.TestRunner)

type GridModule = typeof(require(ReplicatedStorage.Shared.Util.ArenaGrid))

local shared = ReplicatedStorage.Shared:Clone()
local ArenaGrid: GridModule = (require :: any)((shared :: any).Util.ArenaGrid)

local MAP = {
	"##########",
	"#........#",
	"#........#",
	"#..##....#",
	"#..##....#",
	"#........#",
	"#........#",
	"#........#",
	"#........#",
	"##########",
}

local function data(rows: { string }?, edit: ((d: any) -> ())?): any
	local d: any = {
		CellSize = 2,
		Width = 10,
		Depth = 10,
		Rows = table.clone(rows or MAP),
		PlayerSpawn = { X = 6, Z = 6 },
		SpawnEdges = {
			{ Id = "North", Min = { X = 2, Z = 2 }, Max = { X = 9, Z = 2 } },
			{ Id = "South", Min = { X = 2, Z = 9 }, Max = { X = 9, Z = 9 } },
		},
	}
	if edit then
		edit(d)
	end
	return d
end

local function withRow(z: number, row: string): { string }
	local rows = table.clone(MAP)
	rows[z] = row
	return rows
end

local function problemText(d: any): string
	return table.concat(ArenaGrid.problems(d), "\n")
end

local function has(text: string, fragment: string): boolean
	return string.find(text, fragment, 1, true) ~= nil
end

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("rules", function()
		it("accept a closed map with wide passages", function()
			expect(ArenaGrid.problems(data())).toEqual({})
		end)

		it("reject rows that do not match Width × Depth or use other characters", function()
			expect(has(problemText(data(nil, function(d)
				table.remove(d.Rows)
			end)), "Rows: 9 rows, Depth is 10")).toBe(true)
			expect(has(problemText(data(withRow(3, "#.......#"))), "Rows[3]: 9 cells, Width is 10")).toBe(true)
			expect(has(problemText(data(withRow(3, "#...x....#"))), "Rows[3]: only '.' (open) and '#' (blocked)")).toBe(true)
		end)

		it("reject an open outer ring", function()
			expect(has(problemText(data(withRow(5, "...##....#"))), "the outer ring must be blocked")).toBe(true)
		end)

		it("reject a player spawn on a blocked cell or outside", function()
			expect(has(problemText(data(nil, function(d)
				d.PlayerSpawn = { X = 4, Z = 4 }
			end)), "PlayerSpawn (4,4) must be an open cell")).toBe(true)
			expect(has(problemText(data(nil, function(d)
				d.PlayerSpawn = { X = 11, Z = 4 }
			end)), "PlayerSpawn (11,4)")).toBe(true)
		end)

		it("reject a passage narrower than two cells", function()
			local text = problemText(data(withRow(5, "#####.####")))
			expect(has(text, "1 open cells are in a passage narrower than 2 cells: (6,5)")).toBe(true)
			expect(has(text, "cannot be reached")).toBe(false)
		end)

		it("reject open cells that cannot be reached from the spawn", function()
			local rows = table.clone(MAP)
			rows[6] = "##########" -- splits the map into a north and a south half
			local text = problemText(data(rows, function(d)
				d.PlayerSpawn = { X = 6, Z = 8 }
			end))
			expect(has(text, "28 open cells cannot be reached from PlayerSpawn: (2,2) (3,2) (4,2) (5,2) (6,2) …")).toBe(true)
		end)

		it("reject bad spawn edges", function()
			expect(has(problemText(data(nil, function(d)
				d.SpawnEdges[2].Id = "North"
			end)), "SpawnEdges[2] North: duplicate edge Id")).toBe(true)
			expect(has(problemText(data(nil, function(d)
				d.SpawnEdges[1].Max = { X = 11, Z = 2 }
			end)), "Min/Max must lie inside the 10 × 10 grid")).toBe(true)
			expect(has(problemText(data(nil, function(d)
				d.SpawnEdges[1].Min = { X = 9, Z = 2 }
				d.SpawnEdges[1].Max = { X = 2, Z = 2 }
			end)), "Min must not exceed Max")).toBe(true)
			expect(has(problemText(data(nil, function(d)
				d.SpawnEdges[1].Max = { X = 8, Z = 2 }
			end)), "SpawnEdges[1] North: 7 open cells, at least 8 needed")).toBe(true)
		end)

		it("new throws every problem in one [Arena] error", function()
			expect(function()
				ArenaGrid.new(data(withRow(5, "...##....#"), function(d)
					d.PlayerSpawn = { X = 4, Z = 4 }
				end))
			end).toThrow("[Arena] 3 problems")
		end)
	end)

	describe("queries", function()
		it("isOpen follows the rows and is false outside", function()
			local grid = ArenaGrid.new(data())
			expect(grid:isOpen(2, 2)).toBe(true)
			expect(grid:isOpen(4, 4)).toBe(false)
			expect(grid:isOpen(1, 5)).toBe(false)
			expect(grid:isOpen(0, 5)).toBe(false)
			expect(grid:isOpen(11, 5)).toBe(false)
			expect(grid:isOpen(2.5, 2)).toBe(false)
			expect(grid.openCount).toBe(60)
		end)

		it("cellAt and center map arena-local space, centred on the origin", function()
			local grid = ArenaGrid.new(data())
			local x, z = grid:cellAt(Vector3.new(-10, 0, -10))
			expect(x).toBe(1)
			expect(z).toBe(1)
			x, z = grid:cellAt(Vector3.new(9.99, 3, 0))
			expect(x).toBe(10)
			expect(z).toBe(6)
			expect((grid:cellAt(Vector3.new(10, 0, 0)))).toBeNil()
			expect((grid:cellAt(Vector3.new(0, 0, -10.01)))).toBeNil()
			expect(grid:center(1, 1)).toEqual(Vector3.new(-9, 0, -9))
			expect(grid:center(6, 6)).toEqual(Vector3.new(1, 0, 1))
			for _, cell in { { 2, 2 }, { 7, 3 }, { 9, 9 } } do
				local cx, cz = grid:cellAt(grid:center(cell[1], cell[2]))
				expect(cx).toBe(cell[1])
				expect(cz).toBe(cell[2])
			end
			expect(grid:openAt(grid:center(4, 4))).toBe(false)
			expect(grid:openAt(grid:center(6, 6))).toBe(true)
			expect(grid:openAt(Vector3.new(50, 0, 0))).toBe(false)
		end)

		it("edgeCells lists only the open cells of an edge", function()
			local rows = withRow(2, "#....#...#")
			local grid = ArenaGrid.new(data(rows, function(d)
				d.SpawnEdges[1].Max = { X = 9, Z = 3 }
			end))
			local cells = grid:edgeCells("North")
			expect(#cells).toBe(15)
			for _, cell in cells do
				expect(grid:isOpen(cell.X, cell.Z)).toBe(true)
			end
			expect(function()
				grid:edgeCells("Nowhere")
			end).toThrow("unknown spawn edge Nowhere")
		end)

		it("reach floods every open cell from the spawn", function()
			local grid = ArenaGrid.new(data())
			local visited, count = grid:reach(6, 6)
			expect(count).toBe(grid.openCount)
			expect(buffer.readu8(visited, 0)).toBe(0)
			expect(buffer.readu8(visited, 1 * 10 + 1)).toBe(1)
			local _, none = grid:reach(4, 4)
			expect(none).toBe(0)
		end)

		it("is frozen", function()
			local grid = ArenaGrid.new(data())
			expect(table.isfrozen(grid :: any)).toBe(true)
			expect(table.isfrozen(grid.edges :: any)).toBe(true)
		end)
	end)

	describe("shipped TestArena", function()
		it("is a valid 76 × 76 grid with four spawn edges, spawn in the middle, all open cells reachable", function()
			local def = require((shared :: any).Definitions.Arenas.TestArena) :: any
			expect(ArenaGrid.problems(def)).toEqual({})
			local grid = ArenaGrid.new(def)
			expect(grid.width).toBe(76)
			expect(grid.depth).toBe(76)
			expect(grid.cellSize).toBe(2)
			expect(grid.spawn).toEqual({ X = 38, Z = 38 })
			local ids: { string } = {}
			for _, edge in grid.edges do
				table.insert(ids, edge.Id)
				expect(#grid:edgeCells(edge.Id) >= 40).toBe(true)
			end
			expect(ids).toEqual({ "East", "North", "South", "West" })
			local _, count = grid:reach(38, 38)
			expect(count).toBe(grid.openCount)
			expect(grid.openCount > 4000).toBe(true)
		end)
	end)
end
