--!strict
-- Render/Lib/EnemyPose + EnemyRigs (A2.4, architecture §8.1, §22; ART_BIBLE silhouette table): the procedural poses
-- (spawn rise, walk cycle, telegraph rear-back, attack lunge, recover, despawn sink) and the placeholder rigs (Walker
-- hunched with arms forward, Runner leaning 45° with arms trailing; heights; art rules; parts that collide with nothing).

local TestRunner = require(script.Parent.Parent.TestRunner)
local RenderFixture = require(script.Parent.Parent.fixtures.RenderFixture)

local lib = RenderFixture.lib()
local EnemyPose = RenderFixture.require(lib, "EnemyPose")
local EnemyRigs = RenderFixture.require(lib, "EnemyRigs")

local function input(state: string, age: number, overrides: { [string]: any }?): any
	local i: { [string]: any } = { State = state, Age = age, TelegraphTime = 0.4, Phase = 0, Speed = 1, Time = 0 }
	if overrides then
		for k, value in overrides do
			i[k] = value
		end
	end
	return i
end

local function pose(defId: string, state: string, age: number, overrides: { [string]: any }?): any
	return EnemyPose.compute(EnemyRigs.spec(defId).Style, input(state, age, overrides), EnemyPose.newPose())
end

-- Part CFrames of one enemy standing at the origin facing -Z.
local function placed(defId: string, p: any): { [string]: CFrame }
	local spec = EnemyRigs.spec(defId)
	local out: { CFrame } = {}
	EnemyRigs.compose(spec, CFrame.identity, p, out, 1)
	local byName: { [string]: CFrame } = {}
	for i, part in spec.Parts do
		byName[part.Name] = out[i]
	end
	return byName
end

-- World direction a limb points from its joint to its far end (down along the part).
local function limbDown(cf: CFrame): Vector3
	return -cf.UpVector
end

local function height(defId: string, p: any): (number, number)
	local spec = EnemyRigs.spec(defId)
	local frames = placed(defId, p)
	local low, high = math.huge, -math.huge
	for _, part in spec.Parts do
		local cf, half = frames[part.Name], part.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local y = (cf * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z)).Y
					low, high = math.min(low, y), math.max(high, y)
				end
			end
		end
	end
	return low, high
end

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("poses", function()
		it("rise out of the floor during Spawn", function()
			local style = EnemyRigs.spec("Walker").Style
			expect(pose("Walker", "Spawn", 0).Lift).toBeCloseTo(-style.Height * EnemyPose.SPAWN_DEPTH, 1e-6)
			expect(pose("Walker", "Spawn", 0.3).Lift < 0).toBe(true)
			expect(pose("Walker", "Spawn", EnemyPose.SPAWN_TIME).Lift).toBeCloseTo(0, 1e-6)
			local low, high = height("Walker", pose("Walker", "Spawn", 0))
			expect(high <= 0).toBe(true) -- fully hidden on the first frame, raised hands included
			expect(low < -5).toBe(true)
		end)

		it("swing the legs in opposition when walking and stand still at speed 0", function()
			local p = pose("Walker", "Pursue", 1, { Phase = math.pi / 2 })
			local _, _, zL = p.LegL:ToEulerAnglesXYZ()
			local xL = p.LegL:ToEulerAnglesXYZ()
			local xR = p.LegR:ToEulerAnglesXYZ()
			expect(xL > 0.3).toBe(true)
			expect(xR).toBeCloseTo(-xL, 1e-6)
			expect(zL).toBeCloseTo(0, 1e-6)
			local idle = pose("Walker", "Pursue", 1, { Phase = math.pi / 2, Speed = 0 })
			expect((idle.LegL:ToEulerAnglesXYZ())).toBeCloseTo(0, 1e-6)
		end)

		it("rear back with arms up during Telegraph, then lunge forward in Attack", function()
			local walk = pose("Walker", "Pursue", 1)
			local tele = pose("Walker", "Telegraph", 0.4)
			local walkLean = walk.Body:ToEulerAnglesXYZ()
			local teleLean = tele.Body:ToEulerAnglesXYZ()
			expect(teleLean > walkLean).toBe(true) -- positive X tilts the body back
			expect(teleLean > 0).toBe(true)
			expect((tele.ArmR:ToEulerAnglesXYZ()) > math.rad(140)).toBe(true)
			local mid = pose("Walker", "Attack", EnemyPose.ATTACK_TIME / 2)
			expect(mid.Forward > 1).toBe(true)
			expect(pose("Walker", "Attack", EnemyPose.ATTACK_TIME).Forward).toBeCloseTo(0, 1e-6)
			local back = pose("Walker", "Recover", EnemyPose.RECOVER_TIME)
			expect((back.Body:ToEulerAnglesXYZ())).toBeCloseTo(walkLean, 1e-3)
		end)

		it("sink fully below the floor while despawning", function()
			expect(pose("Runner", "Despawn", 0).Lift).toBeCloseTo(0, 1e-6)
			local _, high = height("Runner", pose("Runner", "Despawn", EnemyPose.DESPAWN_TIME))
			expect(high <= 0.01).toBe(true)
		end)

		it("never produce NaN for odd inputs", function()
			for _, state in { "Spawn", "Pursue", "Telegraph", "Attack", "Recover", "Stagger", "Dying", "Despawn", "Unknown" } do
				local p = pose("Runner", state, -1, { Speed = 99, TelegraphTime = 0 })
				for _, cf in { p.Body, p.Head, p.ArmL, p.ArmR, p.LegL, p.LegR } do
					local x, y, z = cf:ToEulerAnglesXYZ()
					expect(x == x and y == y and z == z).toBe(true)
				end
				expect(p.Lift == p.Lift and p.Forward == p.Forward).toBe(true)
			end
		end)
	end)

	describe("rigs", function()
		it("Walker is 6–7 studs, hunched about 25°, with both arms straight forward", function()
			local p = pose("Walker", "Pursue", 1, { Speed = 0 })
			local low, high = height("Walker", p)
			expect(low).toBeCloseTo(0, 0.01)
			expect(high > 6 and high < 7).toBe(true)
			local frames = placed("Walker", p)
			local torsoUp = frames.Torso.UpVector
			expect(math.deg(math.acos(torsoUp.Y))).toBeCloseTo(25, 1)
			expect(torsoUp.Z < 0).toBe(true) -- leaning toward its facing (-Z)
			for _, arm in { frames.ArmL, frames.ArmR } do
				local down = limbDown(arm)
				expect(down.Z < -0.95).toBe(true) -- pointing forward, near horizontal
			end
		end)

		it("Runner is thinner, leans 45° and trails its arms", function()
			local p = pose("Runner", "Pursue", 1, { Speed = 0 })
			local frames = placed("Runner", p)
			local torsoUp = frames.Torso.UpVector
			expect(math.deg(math.acos(torsoUp.Y))).toBeCloseTo(45, 1)
			for _, arm in { frames.ArmL, frames.ArmR } do
				expect(limbDown(arm).Z > 0.5).toBe(true) -- behind the body
			end
			local walker, runner = EnemyRigs.spec("Walker"), EnemyRigs.spec("Runner")
			expect(runner.Parts[1].Size.X < walker.Parts[1].Size.X * 0.75).toBe(true)
			expect(runner.Style.Stride > walker.Style.Stride * 1.5).toBe(true)
			local _, high = height("Runner", p)
			expect(high > 5 and high < 7).toBe(true)
		end)

		it("follow the art rules: SmoothPlastic, Neon only for eyes, nothing under 0.3 studs, ≤ 1,500 tris", function()
			for _, id in { "Walker", "Runner", "Default" } do
				local spec = EnemyRigs.spec(id)
				expect(#spec.Parts).toBe(EnemyRigs.PART_COUNT)
				expect(#spec.Parts * 12 <= 1500).toBe(true) -- a box is 12 triangles
				for _, part in spec.Parts do
					local isEye = string.sub(part.Name, 1, 3) == "Eye"
					expect(part.Material == Enum.Material.Neon).toBe(isEye)
					if not isEye then
						expect(part.Material).toBe(Enum.Material.SmoothPlastic)
					end
					expect(math.min(part.Size.X, part.Size.Y, part.Size.Z) >= 0.3).toBe(true)
				end
			end
			expect(EnemyRigs.spec("Brute").Id).toBe("Default")
			expect(EnemyRigs.has("Walker")).toBe(true)
		end)

		it("build anchored parts that collide with nothing, are never hit by rays and touch nothing", function()
			local model, parts = EnemyRigs.build(EnemyRigs.spec("Walker"))
			expect(model:FindFirstChildOfClass("Humanoid")).toBeNil()
			expect(#parts).toBe(EnemyRigs.PART_COUNT)
			for i, part in parts do
				expect(part.Name).toBe(EnemyRigs.spec("Walker").Parts[i].Name)
				expect(part.Parent).toBe(model)
				expect(part.Anchored).toBe(true)
				expect(part.CanCollide).toBe(false)
				expect(part.CanQuery).toBe(false)
				expect(part.CanTouch).toBe(false)
			end
			model:Destroy()
		end)

		it("compose writes one CFrame per part at the requested index and follows yaw", function()
			local spec = EnemyRigs.spec("Walker")
			local p = pose("Walker", "Pursue", 1, { Speed = 0 })
			local out: { CFrame } = {}
			local nextAt = EnemyRigs.compose(spec, CFrame.new(10, 0, 5), p, out, 4)
			expect(nextAt).toBe(4 + EnemyRigs.PART_COUNT)
			expect(out[3]).toBeNil()
			local turned: { CFrame } = {}
			EnemyRigs.compose(spec, CFrame.Angles(0, math.pi / 2, 0), p, turned, 1)
			-- yaw π/2 faces -X: the arms reach toward -X
			expect((-turned[6].UpVector).X < -0.9).toBe(true)
		end)
	end)
end
