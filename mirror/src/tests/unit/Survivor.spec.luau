--!strict
-- Placeholder survivor (A2.2, ART_BIBLE): StarterPlayer/StarterCharacter is a primitive survivor about 7 studs tall that
-- stands on its hip height, moves as one body welded to its root, carries its own key light and a white outline
-- (ART_BIBLE rule 3), runs no default Animate script, and keeps the art rules for characters (no Neon, nothing thinner
-- than 0.3 studs).

local StarterPlayer = game:GetService("StarterPlayer")

local TestRunner = require(script.Parent.Parent.TestRunner)

local function survivor(): Model
	local model = StarterPlayer:FindFirstChild("StarterCharacter")
	assert(model ~= nil and model:IsA("Model"), "StarterPlayer/StarterCharacter is missing")
	return model
end

local function visibleParts(model: Model): { BasePart }
	local out: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			table.insert(out, d)
		end
	end
	return out
end

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("StarterCharacter", function()
		it("is a Model with a Humanoid and a HumanoidRootPart as primary part", function()
			local model = survivor()
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
			expect(model.PrimaryPart).toBe(root)
			local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
			expect(humanoid.RigType).toBe(Enum.HumanoidRigType.R15)
			expect(root.Transparency).toBe(1)
			expect(root.CanCollide).toBe(true)
			expect(root.Anchored).toBe(false)
			expect(model:FindFirstChild("Head") ~= nil).toBe(true)
		end)

		it("is about 7 studs tall and stands on its hip height", function()
			local model = survivor()
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
			local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
			local low, high = math.huge, -math.huge
			for _, part in visibleParts(model) do
				local half = part.Size.Y / 2
				low = math.min(low, part.Position.Y - half)
				high = math.max(high, part.Position.Y + half)
			end
			expect(high - low).toBeCloseTo(7, 0.3)
			local ground = root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight
			expect(ground).toBeCloseTo(low, 0.05)
		end)

		it("moves as one body: every other part is welded to the root, massless and non-colliding", function()
			local model = survivor()
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
			local welded: { [Instance]: boolean } = {}
			for _, d in model:GetDescendants() do
				local other = if d:IsA("WeldConstraint") and d.Part0 == root then d.Part1 else nil
				if other then
					welded[other] = true
				end
			end
			local count = 0
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d ~= root then
					count += 1
					expect(welded[d] == true).toBe(true)
					expect(d.Massless).toBe(true)
					expect(d.CanCollide).toBe(false)
					expect(d.Anchored).toBe(false)
				end
			end
			expect(count >= 6).toBe(true)
		end)

		it("has its own key light and a white outline (ART_BIBLE rule 3)", function()
			local model = survivor()
			local highlights: { Highlight } = {}
			for _, d in model:GetDescendants() do
				if d:IsA("Highlight") then
					table.insert(highlights, d)
				end
			end
			expect(#highlights).toBe(1)
			local outline = highlights[1]
			expect(outline.FillTransparency).toBe(1)
			expect(outline.OutlineTransparency).toBe(0)
			expect(outline.OutlineColor).toEqual(Color3.new(1, 1, 1))
			local light = (model:FindFirstChild("HumanoidRootPart") :: Instance):FindFirstChildOfClass("PointLight")
			expect(light ~= nil).toBe(true)
			expect((light :: PointLight).Shadows).toBe(false)
			expect((light :: PointLight).Range >= 8 and (light :: PointLight).Range <= 20).toBe(true)
		end)

		it("keeps Roblox's default Animate script out: the rig is welded, A2.4 adds procedural animation", function()
			-- a non-script child named Animate in StarterCharacterScripts stops Roblox inserting its R15 Animate script,
			-- which on this rig loads tracks until the 64-track limit and floods the client log
			local placeholder = StarterPlayer.StarterCharacterScripts:FindFirstChild("Animate")
			expect(placeholder ~= nil).toBe(true)
			expect((placeholder :: Instance):IsA("LuaSourceContainer")).toBe(false)
		end)

		it("keeps the character art rules: no Neon, nothing thinner than 0.3 studs", function()
			for _, part in visibleParts(survivor()) do
				expect(part.Material ~= Enum.Material.Neon).toBe(true)
				expect(math.min(part.Size.X, part.Size.Y, part.Size.Z) >= 0.3).toBe(true)
			end
		end)
	end)
end
