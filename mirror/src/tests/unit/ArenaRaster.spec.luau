--!strict
-- Util/ArenaRaster (A2.2, architecture §8.3): template → grid. Walls and boxes block the cells they overlap (touching an
-- edge does not), rotated parts block by their real footprint, the walking band and CanCollide filter what blocks,
-- markers give the spawn and spawn edges, the result does not depend on where the template stands, template problems are
-- reported, diff finds drift, and source() writes the definition. Runs on a clone of Shared with the ArenaFixture template.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestRunner = require(script.Parent.Parent.TestRunner)
local ArenaFixture = require(script.Parent.Parent.fixtures.ArenaFixture)

type RasterModule = typeof(require(ReplicatedStorage.Shared.Util.ArenaRaster))

local shared = ReplicatedStorage.Shared:Clone()
local ArenaRaster: RasterModule = (require :: any)((shared :: any).Util.ArenaRaster)
local ArenaGrid = (require :: any)((shared :: any).Util.ArenaGrid)

local EXPECTED = {
	"############",
	"#..........#",
	"#..........#",
	"#..........#",
	"#..........#",
	"#..........#",
	"#..........#",
	"#......##..#",
	"#......##..#",
	"#..........#",
	"#..........#",
	"############",
}

local function rasterize(model: Model): any
	local result, problems = ArenaRaster.rasterize(model, 2)
	assert(result ~= nil, table.concat(problems, "\n"))
	return result
end

local function problemsOf(model: Model): string
	local result, problems = ArenaRaster.rasterize(model, 2)
	assert(result == nil, "expected problems")
	return table.concat(problems, "\n")
end

local function has(text: string, fragment: string): boolean
	return string.find(text, fragment, 1, true) ~= nil
end

local function addPart(model: Model, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Parent = model
	return p
end

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("rasterize", function()
		it("blocks the wall ring and the box, finds the spawn and both edges", function()
			local result = rasterize(ArenaFixture.template())
			expect(result.Rows).toEqual(EXPECTED)
			expect(result.Width).toBe(12)
			expect(result.Depth).toBe(12)
			expect(result.CellSize).toBe(2)
			expect(result.ZoneId).toBe("EvacuationStreets")
			expect(result.PlayerSpawn).toEqual({ X = 5, Z = 5 })
			expect(result.SpawnEdges).toEqual({
				{ Id = "North", Min = { X = 2, Z = 2 }, Max = { X = 11, Z = 2 } },
				{ Id = "South", Min = { X = 2, Z = 11 }, Max = { X = 11, Z = 11 } },
			})
			expect(result.Blockers).toBe(5)
			expect(ArenaGrid.problems(ArenaFixture.definition(result))).toEqual({})
		end)

		it("does not depend on where the template stands or how it is turned", function()
			local model = ArenaFixture.template()
			local before = rasterize(model)
			model:PivotTo(CFrame.new(512, 40, -300) * CFrame.Angles(0, math.rad(90), 0))
			local after = rasterize(model)
			expect(after.Rows).toEqual(before.Rows)
			expect(after.PlayerSpawn).toEqual(before.PlayerSpawn)
			expect(after.SpawnEdges).toEqual(before.SpawnEdges)
		end)

		it("blocks a 45° part by its diamond footprint, not its bounding box", function()
			local model = ArenaFixture.template()
			-- a 4-stud square turned 45° around (-4, 4): its bounding box covers columns 3..6 × rows 7..10, the diamond
			-- misses the four corner cells of that box
			addPart(model, Vector3.new(4, 4, 4), CFrame.new(-4, 2, 4) * CFrame.Angles(0, math.rad(45), 0))
			local rows = rasterize(model).Rows
			expect(string.sub(rows[7], 3, 6)).toBe(".##.")
			expect(string.sub(rows[8], 3, 6)).toBe("####")
			expect(string.sub(rows[9], 3, 6)).toBe("####")
			expect(string.sub(rows[10], 3, 6)).toBe(".##.")
		end)

		it("does not block cells a part only touches", function()
			local model = ArenaFixture.template()
			addPart(model, Vector3.new(2, 4, 2), CFrame.new(-7, 2, 1)) -- exactly cell (3, 7)
			local rows = rasterize(model).Rows
			expect(string.sub(rows[7], 2, 4)).toBe(".#.")
			expect(string.sub(rows[6], 3, 3)).toBe(".")
			expect(string.sub(rows[8], 3, 3)).toBe(".")
		end)

		it("ignores non-colliding parts and parts outside the walking band", function()
			local model = ArenaFixture.template()
			addPart(model, Vector3.new(4, 0.2, 4), CFrame.new(-6, 0.1, 6)) -- road paint below the band
			addPart(model, Vector3.new(4, 1, 4), CFrame.new(-6, 9, 6)) -- sign above the band
			local ghost = addPart(model, Vector3.new(4, 4, 4), CFrame.new(-6, 2, 6))
			ghost.CanCollide = false
			expect(rasterize(model).Rows).toEqual(EXPECTED)
		end)

		it("reports tilted blockers, odd floor sizes, a missing ZoneId, spawn and edges", function()
			local tilted = ArenaFixture.template()
			addPart(tilted, Vector3.new(2, 4, 2), CFrame.new(0, 2, 0) * CFrame.Angles(math.rad(20), 0, 0)).Name = "Leaning"
			expect(has(problemsOf(tilted), "Leaning is tilted")).toBe(true)

			local odd = ArenaFixture.template()
			local floor = odd:FindFirstChild("Floor") :: BasePart
			floor.Size = Vector3.new(25, 1, 24)
			expect(has(problemsOf(odd), "not a whole number of 2-stud cells")).toBe(true)

			local noZone = ArenaFixture.template()
			noZone:SetAttribute("ZoneId", nil)
			expect(has(problemsOf(noZone), "ZoneId attribute")).toBe(true)

			local moved = ArenaFixture.template()
			moved.WorldPivot = CFrame.new(0, 3, 0)
			expect(has(problemsOf(moved), "the model's pivot must be the centre of the floor's top face")).toBe(true)

			local primary = ArenaFixture.template() -- a PrimaryPart decides the pivot: here the floor's centre, 0.5 too low
			primary.PrimaryPart = primary:FindFirstChild("Floor") :: BasePart
			expect(has(problemsOf(primary), "the model's pivot must be the centre of the floor's top face")).toBe(true)

			local bare = ArenaFixture.template()
			for _, marker in (bare:FindFirstChild("Markers") :: Instance):GetChildren() do
				marker:Destroy()
			end
			local text = problemsOf(bare)
			expect(has(text, "needs a BasePart Markers/PlayerSpawn")).toBe(true)
			expect(has(text, "needs at least one Markers/SpawnEdge_<Id> part")).toBe(true)

			local noFloor = ArenaFixture.template();
			(noFloor:FindFirstChild("Floor") :: Instance):Destroy()
			expect(has(problemsOf(noFloor), "needs a BasePart named Floor")).toBe(true)
		end)
	end)

	describe("diff and source", function()
		it("diff is empty for a fresh export and names drift", function()
			local result = rasterize(ArenaFixture.template())
			local def = ArenaFixture.definition(result)
			expect(ArenaRaster.diff(def, result)).toEqual({})
			def.Rows[6] = "#....#.....#"
			def.PlayerSpawn = { X = 6, Z = 5 }
			def.SpawnEdges = { def.SpawnEdges[1] }
			local text = table.concat(ArenaRaster.diff(def, result), "\n")
			expect(has(text, "1 cells differ, first at (6,6)")).toBe(true)
			expect(has(text, "PlayerSpawn moved")).toBe(true)
			expect(has(text, "1 spawn edges vs template 2")).toBe(true)
			def.Width = 14
			expect(has(table.concat(ArenaRaster.diff(def, result), "\n"), "size 14 × 12 vs template 12 × 12")).toBe(true)
		end)

		it("source writes a strict module with every field and row", function()
			local result = rasterize(ArenaFixture.template())
			local source = ArenaRaster.source("Mini", "Mini", result)
			expect(string.sub(source, 1, 9)).toBe("--!strict")
			for _, fragment in
				{
					'\tId = "Mini",',
					'\tZoneId = "EvacuationStreets",',
					'\tTemplate = "Mini",',
					"\tCellSize = 2,",
					"\tWidth = 12,",
					"\tDepth = 12,",
					"\tPlayerSpawn = { X = 5, Z = 5 },",
					'\t\t{ Id = "North", Min = { X = 2, Z = 2 }, Max = { X = 11, Z = 2 } },',
					'\t\t"#......##..#",',
				}
			do
				expect(has(source, fragment)).toBe(true)
			end
			local _, rows = string.gsub(source, '\t\t"[#.]+",\n', "")
			expect(rows).toBe(12)
		end)
	end)
end
