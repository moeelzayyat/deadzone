--!strict
-- Encounter/ArenaService (A2.2, architecture §4.4, §8.3): boot check of every arena against its template (a drifted grid
-- or a missing template stops the boot), slots and placement by pivot, release, local/world mapping, the spawn pose, the
-- TestArena flag, and the shipped TestArena against ServerStorage/Arenas. Runs on a clone of Server; copies go to a
-- scratch folder, never Workspace.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TestRunner = require(script.Parent.Parent.TestRunner)
local ArenaFixture = require(script.Parent.Parent.fixtures.ArenaFixture)

type ServiceModule = typeof(require(ServerScriptService.Server.Domains.Encounter.ArenaService))

local server = ServerScriptService.Server:Clone()
local ArenaService: ServiceModule = (require :: any)((server :: any).Domains.Encounter.ArenaService)
local shared = ReplicatedStorage.Shared:Clone()
local ArenaRaster = (require :: any)((shared :: any).Util.ArenaRaster)

local function flags(on: boolean): any
	return {
		get = function(_self: any, name: string): any
			assert(name == "TestArena", `unexpected flag {name}`)
			return on
		end,
	}
end

-- A templates folder holding the fixture, its definition, and a scratch folder for placed copies.
local function setup(edit: ((def: { [string]: any }) -> ())?): (Instance, { [string]: any }, Instance)
	local templates: Instance = Instance.new("Folder")
	local model = ArenaFixture.template()
	model.Parent = templates
	local result, problems = ArenaRaster.rasterize(model, 2)
	assert(result ~= nil, table.concat(problems, "\n"))
	local def = ArenaFixture.definition(result)
	if edit then
		edit(def)
	end
	return templates, def, Instance.new("Folder")
end

local function make(edit: ((def: { [string]: any }) -> ())?): (any, Instance)
	local templates, def, parent = setup(edit)
	local service = ArenaService.new({
		templates = templates,
		definitions = { def },
		flags = flags(false),
		parent = parent,
		players = false,
	})
	return service, parent
end

local function errorOf(fn: () -> ()): string
	local ok, err = pcall(function()
		fn()
	end)
	assert(not ok, "expected an error")
	return tostring(err)
end

local function has(text: string, fragment: string): boolean
	return string.find(text, fragment, 1, true) ~= nil
end

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("boot check", function()
		it("accepts a definition that matches its template and builds its grid", function()
			local service = make()
			expect(service:verify()).toEqual({})
			local grid = service:grid("Mini")
			expect(grid.width).toBe(12)
			expect(grid:isOpen(8, 8)).toBe(false)
			expect(grid:isOpen(5, 5)).toBe(true)
		end)

		it("stops the boot when the stored grid drifted from the template", function()
			local service = make(function(def)
				def.Rows[5] = "#...#......#"
			end)
			local message = errorOf(function()
				service:Init()
			end)
			expect(has(message, "[Arena] 1 problems; the boot stops")).toBe(true)
			expect(has(message, "Mini: the stored grid no longer matches the template (1 cells differ, first at (5,5)")).toBe(true)
			expect(has(message, "re-run tools/arena_export.luau")).toBe(true)
		end)

		it("stops the boot when the template is missing or broken", function()
			local service = make(function(def)
				def.Template = "Gone"
			end)
			expect(has(errorOf(function()
				service:Init()
			end), "Mini: no template Model ServerStorage/Arenas/Gone")).toBe(true)

			local templates, def, parent = setup()
			local floor = (templates:FindFirstChild("Mini") :: Model):FindFirstChild("Floor") :: BasePart
			floor.Size = Vector3.new(25, 1, 24)
			local broken = ArenaService.new({ templates = templates, definitions = { def }, flags = flags(false), parent = parent, players = false })
			expect(has(table.concat(broken:verify(), "\n"), "Mini: template Floor size 25 × 24")).toBe(true)
		end)

		it("unknown arenas throw", function()
			local service = make()
			service:Init()
			expect(function()
				service:grid("Nowhere")
			end).toThrow("[Arena] unknown arena Nowhere")
			expect(function()
				service:place("Nowhere", 0)
			end).toThrow("[Arena] unknown arena Nowhere")
		end)
	end)

	describe("placement", function()
		it("copies the template to its slot by pivot", function()
			local service, parent = make()
			service:Init()
			local placed = service:place("Mini", 2)
			expect(placed.Model.Parent).toBe(parent)
			expect(placed.Model.Name).toBe("Mini_2")
			expect(placed.Origin).toEqual(service:slotOrigin(2))
			expect(placed.Origin.Position).toEqual(service:slotOrigin(0).Position + Vector3.new(800, 0, 0))
			expect((placed.Model:GetPivot().Position - placed.Origin.Position).Magnitude < 1e-3).toBe(true)
			local box = placed.Model:FindFirstChild("Box") :: BasePart
			expect((service:toLocal(placed, box.Position) - Vector3.new(4, 2.5, 4)).Magnitude < 1e-3).toBe(true)
			expect(placed.Grid).toBe(service:grid("Mini"))
			expect(table.isfrozen(placed :: any)).toBe(true)
		end)

		it("refuses a taken or bad slot and frees it on release", function()
			local service, parent = make()
			service:Init()
			local placed = service:place("Mini", 0)
			expect(function()
				service:place("Mini", 0)
			end).toThrow("[Arena] slot 0 already holds Mini")
			expect(function()
				service:place("Mini", -1)
			end).toThrow("slot must be a whole number")
			expect(function()
				service:place("Mini", 1.5)
			end).toThrow("slot must be a whole number")
			service:release(placed)
			expect(#parent:GetChildren()).toBe(0)
			local again = service:place("Mini", 0)
			expect(again.Model.Parent).toBe(parent)
		end)

		it("maps local and world positions both ways", function()
			local service = make()
			service:Init()
			local placed = service:place("Mini", 3)
			local here = Vector3.new(-3.5, 1, 7.25)
			local world = service:toWorld(placed, here)
			expect((service:toLocal(placed, world) - here).Magnitude < 1e-4).toBe(true)
			expect((world - (placed.Origin.Position + here)).Magnitude < 1e-4).toBe(true)
		end)

		it("stands a character on the spawn cell, facing north", function()
			local service = make()
			service:Init()
			local placed = service:place("Mini", 1)
			local character = Instance.new("Model")
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Size = Vector3.new(2, 2, 1)
			root.Parent = character
			local humanoid = Instance.new("Humanoid")
			humanoid.HipHeight = 3
			humanoid.Parent = character
			local pose = service:spawnCFrame(placed, character) :: CFrame
			local spawn = placed.Grid:center(5, 5)
			expect((pose.Position - service:toWorld(placed, spawn + Vector3.new(0, 4.1, 0))).Magnitude < 1e-4).toBe(true)
			expect((pose.LookVector - Vector3.new(0, 0, -1)).Magnitude < 1e-4).toBe(true)
			expect(service:spawnCFrame(placed, Instance.new("Model"))).toBeNil()
		end)
	end)

	describe("shipped arenas", function()
		it("TestArena matches ServerStorage/Arenas/TestArena", function()
			local service = ArenaService.new({ flags = flags(false), parent = Instance.new("Folder") :: Instance, players = false })
			expect(service:verify()).toEqual({})
			expect(service:grid("TestArena").width).toBe(76)
		end)

		it("the TestArena flag places TestArena in slot 0, and nothing when off", function()
			local on: Instance = Instance.new("Folder")
			local service = ArenaService.new({ flags = flags(true), parent = on, players = false })
			service:Init()
			service:Start()
			expect(#on:GetChildren()).toBe(1)
			expect(on:GetChildren()[1].Name).toBe("TestArena_0")
			on:ClearAllChildren()

			local off: Instance = Instance.new("Folder")
			local idle = ArenaService.new({ flags = flags(false), parent = off, players = false })
			idle:Init()
			idle:Start()
			expect(#off:GetChildren()).toBe(0)
		end)
	end)
end
