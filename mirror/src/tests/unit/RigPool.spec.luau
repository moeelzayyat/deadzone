--!strict
-- Render/Lib/RigPool (A2.4, architecture §23 object pooling): a rig is built once and reused; a released rig is parked
-- out of view under the container; prewarm fills the pool; trim destroys only idle rigs beyond `keep`; counts add up.
-- Runs on a folder outside the DataModel's Workspace view (a Folder under ServerStorage), destroyed at the end.

local ServerStorage = game:GetService("ServerStorage")

local TestRunner = require(script.Parent.Parent.TestRunner)
local RenderFixture = require(script.Parent.Parent.fixtures.RenderFixture)

local lib = RenderFixture.lib()
local RigPool = RenderFixture.require(lib, "RigPool")
local EnemyRigs = RenderFixture.require(lib, "EnemyRigs")

local function newPool(): (any, Folder, { number })
	local folder = Instance.new("Folder")
	folder.Name = "RigPoolSpec"
	folder.Parent = ServerStorage
	local builds = { 0 }
	local pool = RigPool.new(folder, function(defId: string): (Model, { BasePart })
		builds[1] += 1
		return EnemyRigs.build(EnemyRigs.spec(defId))
	end)
	return pool, folder, builds
end

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("RigPool", function()
		it("builds a rig once and hands the same rig back after release", function()
			local pool, folder, builds = newPool()
			local a = pool:acquire("Walker")
			expect(builds[1]).toBe(1)
			expect(a.Model.Parent).toBe(folder)
			pool:release(a)
			local b = pool:acquire("Walker")
			expect(b).toBe(a)
			expect(builds[1]).toBe(1)
			local c = pool:acquire("Runner")
			expect(c == a).toBe(false)
			expect(builds[1]).toBe(2)
			local s = pool:stats()
			expect(s.Built).toBe(2)
			expect(s.Reused).toBe(1)
			expect(s.Active).toBe(2)
			expect(s.Parked).toBe(0)
			folder:Destroy()
		end)

		it("parks released rigs far out of view and keeps them parented", function()
			local pool, folder = newPool()
			local rig = pool:acquire("Runner")
			pool:release(rig)
			for _, part in rig.Parts do
				expect((part.Position - RigPool.PARK.Position).Magnitude < 1e-3).toBe(true)
				expect(part.Parent).toBe(rig.Model)
			end
			expect(rig.Model.Parent).toBe(folder)
			expect(pool:parked("Runner")).toBe(1)
			folder:Destroy()
		end)

		it("prewarms to a count and serves acquires from it without building", function()
			local pool, folder, builds = newPool()
			expect(pool:prewarm("Walker", 5)).toBe(5)
			expect(pool:prewarm("Walker", 3)).toBe(0)
			expect(pool:parked("Walker")).toBe(5)
			for _ = 1, 5 do
				pool:acquire("Walker")
			end
			expect(builds[1]).toBe(5)
			expect(pool:parked("Walker")).toBe(0)
			folder:Destroy()
		end)

		it("trims only rigs beyond `keep` that sat idle long enough", function()
			local pool, folder = newPool()
			pool:prewarm("Walker", 6)
			local now = os.clock()
			expect(pool:trim(now, 2, 30)).toBe(0) -- not idle yet
			expect(pool:trim(now + 31, 2, 30)).toBe(4)
			expect(pool:parked("Walker")).toBe(2)
			expect(pool:stats().Destroyed).toBe(4)
			local models = 0
			for _, child in folder:GetChildren() do
				if child:IsA("Model") then
					models += 1
				end
			end
			expect(models).toBe(2)
			folder:Destroy()
		end)
	end)
end
