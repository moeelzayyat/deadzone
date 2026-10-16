--!strict
-- Util/FlowField (A2.3, architecture §8.3): distances toward a target cell (2 straight, 3 diagonal, +WALL_COST next to a
-- wall), no corner cutting, blocked cells unreached, next() always descends to the target, direction() points at the
-- next cell, and a full TestArena build stays cheap. Runs on a clone of Shared.

local TestRunner = require(script.Parent.Parent.TestRunner)
local EnemyFixture = require(script.Parent.Parent.fixtures.EnemyFixture)

local shared = EnemyFixture.shared()
local ArenaGrid = (require :: any)((shared :: any).Util.ArenaGrid)
local FlowField = (require :: any)((shared :: any).Util.FlowField)

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	local function mini(): (any, any)
		local grid = ArenaGrid.new(EnemyFixture.miniData())
		local field = FlowField.new(grid)
		expect(field:build(5, 5)).toBe(true)
		return grid, field
	end

	describe("distances", function()
		it("are 0 at the target, 2 per straight step and 3 per diagonal step in the open", function()
			local _, field = mini()
			expect(field:distance(5, 5)).toBe(0)
			expect(field:distance(6, 5)).toBe(2)
			expect(field:distance(7, 5)).toBe(4)
			expect(field:distance(6, 6)).toBe(3)
			expect(field:distance(4, 4)).toBe(3)
		end)

		it("add WALL_COST for each step into a cell that touches a blocked cell", function()
			local _, field = mini()
			-- (3, 5) touches no wall; (2, 5) touches the west wall ring
			expect(field:distance(3, 5)).toBe(4)
			expect(field:distance(2, 5)).toBe(6 + FlowField.WALL_COST)
		end)

		it("leave blocked cells and cells off the grid UNREACHED", function()
			local _, field = mini()
			expect(field:distance(1, 1)).toBe(FlowField.UNREACHED)
			expect(field:distance(8, 8)).toBe(FlowField.UNREACHED)
			expect(field:distance(0, 5)).toBe(FlowField.UNREACHED)
			expect(field:distance(13, 5)).toBe(FlowField.UNREACHED)
			expect(field:distance(2.5, 5)).toBe(FlowField.UNREACHED)
		end)

		it("refuse a blocked target and keep the previous field", function()
			local _, field = mini()
			expect(field:build(8, 8)).toBe(false)
			expect(field.targetX).toBe(5)
			expect(field:distance(5, 5)).toBe(0)
			expect(field.builds).toBe(1)
		end)

		it("rebuild toward a new target", function()
			local _, field = mini()
			expect(field:build(10, 10)).toBe(true)
			expect(field:distance(10, 10)).toBe(0)
			expect(field:distance(5, 5) > 0).toBe(true)
			expect(field.builds).toBe(2)
		end)
	end)

	describe("next and direction", function()
		it("descend from every open cell to the target without cutting a wall corner", function()
			local grid, field = mini()
			for _, target in { { 5, 5 }, { 10, 10 }, { 2, 11 } } do
				field:build(target[1], target[2])
				for z = 1, 12 do
					for x = 1, 12 do
						if not grid:isOpen(x, z) then
							continue
						end
						local cx, cz, steps = x, z, 0
						while cx ~= target[1] or cz ~= target[2] do
							local nx, nz = field:next(cx, cz)
							assert(nx ~= nil and nz ~= nil, `no next cell from ({cx},{cz}) toward ({target[1]},{target[2]})`)
							assert(field:distance(nx, nz) < field:distance(cx, cz), "next does not descend")
							if nx ~= cx and nz ~= cz then
								assert(grid:isOpen(nx, cz) and grid:isOpen(cx, nz), `corner cut at ({cx},{cz})`)
							end
							cx, cz, steps = nx, nz, steps + 1
							assert(steps <= 144, "next loops")
						end
					end
				end
			end
			expect(true).toBe(true)
		end)

		it("is nil at the target, unreached cells and the outer ring", function()
			local _, field = mini()
			expect(field:next(5, 5)).toBeNil()
			expect(field:next(8, 8)).toBeNil()
			expect(field:next(1, 5)).toBeNil()
		end)

		it("direction() points from a position at the centre of the next cell", function()
			local grid, field = mini()
			local from = grid:center(7, 5) -- next is (6, 5), straight west
			local dx, dz = field:direction(from)
			expect(dx).toBeCloseTo(-1, 1e-9)
			expect(dz).toBeCloseTo(0, 1e-9)
			local ax, az = field:direction(grid:center(5, 5))
			expect(ax).toBe(0)
			expect(az).toBe(0)
		end)
	end)

	describe("TestArena", function()
		it("builds a full field toward the spawn and reaches every open cell", function()
			local grid = ArenaGrid.new((require :: any)((shared :: any).Definitions.Arenas.TestArena))
			local field = FlowField.new(grid)
			local best = math.huge
			for _ = 1, 3 do
				local startedAt = os.clock()
				field:build(grid.spawn.X, grid.spawn.Z)
				best = math.min(best, os.clock() - startedAt)
			end
			local reached = 0
			for z = 1, grid.depth do
				for x = 1, grid.width do
					if grid:isOpen(x, z) and field:distance(x, z) ~= FlowField.UNREACHED then
						reached += 1
					end
				end
			end
			expect(reached).toBe(grid.openCount)
			print(string.format("[FlowField.spec] TestArena build %.3f ms (best of 3, %d open cells)", best * 1000, reached))
			expect(best < 0.02).toBe(true)
		end)
	end)
end
