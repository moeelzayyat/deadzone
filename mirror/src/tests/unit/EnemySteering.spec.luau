--!strict
-- Util/EnemySteering (A2.3, architecture §8.3): wall slide keeps a body out of blocked cells (head-on stops flush, a
-- slanted move slides along the wall, corners push out, 5,000 random moves never end inside a wall), line-of-sight on the
-- grid, the spatial hash, separation and overlap resolution between neighbours, and the yaw convention. Runs on a clone
-- of Shared.

local TestRunner = require(script.Parent.Parent.TestRunner)
local EnemyFixture = require(script.Parent.Parent.fixtures.EnemyFixture)

local shared = EnemyFixture.shared()
local ArenaGrid = (require :: any)((shared :: any).Util.ArenaGrid)
local EnemySteering = (require :: any)((shared :: any).Util.EnemySteering)

-- Mini grid in local studs: x and z run -12..12; the wall ring fills |x| or |z| > 10; the box fills x, z in 2..6.
local function setup(): (any, any)
	local grid = ArenaGrid.new(EnemyFixture.miniData())
	return grid, EnemySteering.walls(grid)
end

-- How far a circle reaches into blocked cells (0 when clear).
local function penetration(grid: any, x: number, z: number, r: number): number
	local worst = 0
	for cz = 1, grid.depth do
		for cx = 1, grid.width do
			if not grid:isOpen(cx, cz) then
				local x0, z0 = -12 + (cx - 1) * 2, -12 + (cz - 1) * 2
				local px, pz = math.clamp(x, x0, x0 + 2), math.clamp(z, z0, z0 + 2)
				local d = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
				worst = math.max(worst, r - d)
			end
		end
	end
	return worst
end

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("walls:slide", function()
		it("moves freely in the open", function()
			local _, walls = setup()
			local x, z = walls:slide(-4, -4, 0.5, -0.25, 1.5)
			expect(x).toBeCloseTo(-3.5, 1e-9)
			expect(z).toBeCloseTo(-4.25, 1e-9)
		end)

		it("stops flush against a wall it runs into head-on", function()
			local _, walls = setup()
			-- the east wall's face is x = 10; a radius-1.5 body stops with its centre at 8.5
			local x, z = walls:slide(8, 0, 1, 0, 1.5)
			expect(x).toBeCloseTo(8.5, 1e-2)
			expect(z).toBeCloseTo(0, 1e-9)
		end)

		it("slides along a wall when the move is slanted into it", function()
			local _, walls = setup()
			local x, z = walls:slide(8.4, -2, 0.6, 0.6, 1.5)
			expect(x).toBeCloseTo(8.5, 1e-2)
			expect(z).toBeCloseTo(-1.4, 1e-9)
		end)

		it("pushes a body out of a box corner", function()
			local grid, walls = setup()
			local x, z = walls:slide(1, 1, 0.5, 0.5, 1.5)
			expect(penetration(grid, x, z, 1.5) <= 0).toBe(true)
		end)

		it("leaves a centre that is inside a blocked cell through the nearest face", function()
			local grid, walls = setup()
			local x, z = walls:slide(2.3, 3, 0, 0, 1)
			expect(x).toBeCloseTo(1 - 1e-3, 1e-6)
			expect(z).toBeCloseTo(3, 1e-9)
			expect(penetration(grid, x, z, 1) <= 0).toBe(true)
		end)

		it("never ends a move shorter than the radius inside a wall (5,000 random moves, radius 1.25 and 1.5)", function()
			local grid, walls = setup()
			local rng = Random.new(23)
			local worst = 0
			for i = 1, 5000 do
				local r = if i % 2 == 0 then 1.5 else 1.25
				local x, z
				repeat
					x, z = rng:NextNumber(-10, 10), rng:NextNumber(-10, 10)
				until penetration(grid, x, z, r) <= 0
				local angle = rng:NextNumber(0, 2 * math.pi)
				local step = rng:NextNumber(0, r * 0.99)
				local nx, nz = walls:slide(x, z, math.cos(angle) * step, math.sin(angle) * step, r)
				worst = math.max(worst, penetration(grid, nx, nz, r))
			end
			expect(worst < 1e-6).toBe(true)
		end)
	end)

	describe("walls:open and walls:clear", function()
		it("open reads the cell under a local position", function()
			local _, walls = setup()
			expect(walls:open(-4, -4)).toBe(true)
			expect(walls:open(4, 4)).toBe(false)
			expect(walls:open(11, 0)).toBe(false)
			expect(walls:open(40, 0)).toBe(false)
		end)

		it("clear is false through the box and true around it", function()
			local _, walls = setup()
			expect(walls:clear(-6, 4, 9, 4)).toBe(false)
			expect(walls:clear(-6, -4, 9, -4)).toBe(true)
			expect(walls:clear(0, 0, 0, 0)).toBe(true)
		end)
	end)

	describe("buckets", function()
		it("gather the items in the 3 × 3 cells around a position", function()
			local buckets = EnemySteering.buckets(4)
			local a = { Pos = Vector3.new(1, 0, 1), Radius = 1 }
			local b = { Pos = Vector3.new(5, 0, 1), Radius = 1 }
			local c = { Pos = Vector3.new(13, 0, 1), Radius = 1 }
			buckets:insert(a)
			buckets:insert(b)
			buckets:insert(c)
			local out = {}
			local n = buckets:gather(Vector3.new(2, 0, 2), out)
			expect(n).toBe(2)
			buckets:clear()
			expect(buckets:gather(Vector3.new(2, 0, 2), out)).toBe(0)
		end)
	end)

	describe("separation and resolve", function()
		it("separation pushes away from overlapping neighbours only", function()
			local me = { Pos = Vector3.new(0, 0, 0), Radius = 1 }
			local near = { Pos = Vector3.new(1, 0, 0), Radius = 1 }
			local far = { Pos = Vector3.new(0, 0, 5), Radius = 1 }
			local push = EnemySteering.separation(me, { me, near, far }, 3, 0.3)
			expect(push.X < 0).toBe(true)
			expect(push.Z).toBeCloseTo(0, 1e-9)
			expect(EnemySteering.separation(me, { me, far }, 2, 0.3).Magnitude).toBe(0)
		end)

		it("separation splits two bodies on the same spot", function()
			local a = { Pos = Vector3.new(0, 0, 0), Radius = 1 }
			local b = { Pos = Vector3.new(0, 0, 0), Radius = 1 }
			local pa = EnemySteering.separation(a, { a, b }, 2, 0)
			local pb = EnemySteering.separation(b, { a, b }, 2, 0)
			expect(pa.Magnitude > 0).toBe(true)
			expect(pa.X).toBeCloseTo(-pb.X, 1e-9)
		end)

		it("resolve returns half of each overlap, pointing away", function()
			local me = { Pos = Vector3.new(0, 0, 0), Radius = 1 }
			local other = { Pos = Vector3.new(1.5, 0, 0), Radius = 1 }
			local out = EnemySteering.resolve(me, { me, other }, 2)
			expect(out.X).toBeCloseTo(-0.25, 1e-9)
			expect(out.Z).toBeCloseTo(0, 1e-9)
			local apart = { Pos = Vector3.new(3, 0, 0), Radius = 1 }
			expect(EnemySteering.resolve(me, { apart }, 1).Magnitude).toBe(0)
		end)
	end)

	describe("yaw", function()
		it("gives the heading whose CFrame.Angles look vector is the direction", function()
			for _, dir in { Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 1).Unit, Vector3.new(0.3, 0, 0.9).Unit } do
				local look = CFrame.Angles(0, EnemySteering.yaw(dir.X, dir.Z), 0).LookVector
				expect((look - dir).Magnitude < 1e-6).toBe(true)
			end
		end)
	end)
end
