--!strict
-- Input rules (A2.1, architecture §2.4): every §2.4 action has a way to fire on PC, touch and gamepad; the
-- ContextActionService bindings are the §2.4 keys, unique per context; schemes, device defaults (auto-aim on for touch
-- and gamepad, auto-fire on for touch), stick mapping, mouse plane hits, aim priority (manual > assist > auto > move >
-- hold), auto-fire while moving and card focus; the place settings the bindings rely on (no jump: Space is dodge; no
-- mouse lock: Shift is dodge; keyboard movement, no click-to-move). Pure functions on a clone of Shared.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local TestRunner = require(script.Parent.Parent.TestRunner)

type RulesModule = typeof(require(ReplicatedStorage.Shared.Util.InputRules))

local shared = ReplicatedStorage.Shared:Clone()
local InputRules: RulesModule = (require :: any)((shared :: any).Util.InputRules)

local function near(a: Vector3, b: Vector3): boolean
	return (a - b).Magnitude < 1e-4
end

local function bindingsFor(action: string): { any }
	local out: { any } = {}
	for _, b in InputRules.BINDINGS do
		if b.Action == action then
			table.insert(out, b)
		end
	end
	return out
end

local function hasInput(action: string, input: Enum.KeyCode | Enum.UserInputType): boolean
	for _, b in bindingsFor(action) do
		if table.find(b.Inputs, input) then
			return true
		end
	end
	return false
end

local function aim(overrides: { [string]: any }): (Vector3, string)
	local input: { [string]: any } = {
		scheme = "Touch",
		manual = nil,
		autoAim = true,
		target = nil,
		origin = Vector3.zero,
		move = Vector3.zero,
		last = Vector3.new(1, 0, 0),
	}
	for k, v in overrides do
		input[k] = v
	end
	return InputRules.resolveAim(input :: any)
end

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("§2.4 coverage", function()
		it("lists the seven §2.4 actions (vote split in two) with a way to fire on every scheme", function()
			local actions: { string } = {}
			for _, row in InputRules.ROWS do
				table.insert(actions, row.Action)
				for _, s in InputRules.SCHEMES do
					expect(#((row :: any)[s] :: string) > 0).toBe(true)
				end
			end
			expect(actions).toEqual({ "Move", "Aim", "Primary", "Dodge", "Signature", "VoteExtract", "VoteHold", "CardSelect" })
		end)

		it("binds the §2.4 keys and buttons", function()
			expect(hasInput("Primary", Enum.UserInputType.MouseButton1)).toBe(true)
			expect(hasInput("Primary", Enum.KeyCode.ButtonR2)).toBe(true)
			expect(hasInput("Dodge", Enum.KeyCode.LeftShift)).toBe(true)
			expect(hasInput("Dodge", Enum.KeyCode.Space)).toBe(true)
			expect(hasInput("Dodge", Enum.KeyCode.ButtonB)).toBe(true)
			expect(hasInput("Signature", Enum.KeyCode.Q)).toBe(true)
			expect(hasInput("Signature", Enum.KeyCode.ButtonR1)).toBe(true)
			expect(hasInput("Signature", Enum.KeyCode.ButtonL1)).toBe(true)
			expect(hasInput("VoteExtract", Enum.KeyCode.One)).toBe(true)
			expect(hasInput("VoteHold", Enum.KeyCode.Two)).toBe(true)
			expect(hasInput("VoteExtract", Enum.KeyCode.DPadLeft)).toBe(true)
			expect(hasInput("VoteHold", Enum.KeyCode.DPadRight)).toBe(true)
			expect(hasInput("CardFocus", Enum.KeyCode.DPadLeft)).toBe(true)
			expect(hasInput("CardFocus", Enum.KeyCode.DPadRight)).toBe(true)
			expect(hasInput("CardSelect", Enum.KeyCode.ButtonA)).toBe(true)
			expect(hasInput("Aim", Enum.KeyCode.Thumbstick2)).toBe(true)
			expect(hasInput("Aim", Enum.UserInputType.Touch)).toBe(true)
		end)

		it("gives touch buttons to attack, dodge, ability, both votes and the auto-fire toggle", function()
			local titles: { string } = {}
			for _, b in InputRules.BINDINGS do
				if b.Touch then
					table.insert(titles, `{b.Action}={b.Touch}`)
				end
			end
			table.sort(titles)
			expect(titles).toEqual({
				"AutoFireToggle=AUTO",
				"Dodge=DODGE",
				"Primary=ATTACK",
				"Signature=ABILITY",
				"VoteExtract=EXTRACT",
				"VoteHold=HOLD",
			})
		end)

		it("never binds one input twice in the same context, and action names are unique", function()
			local names: { [string]: boolean } = {}
			for i, b in InputRules.BINDINGS do
				local name = InputRules.actionName(i)
				expect(names[name]).toBeNil()
				names[name] = true
			end
			for _, context in InputRules.CONTEXTS do
				local seen: { [string]: boolean } = {}
				for _, b in InputRules.BINDINGS do
					if InputRules.activeIn(b, context :: any) then
						for _, input in b.Inputs do
							local key = tostring(input)
							expect(seen[key]).toBeNil()
							seen[key] = true
						end
					end
				end
			end
		end)

		it("binds combat in Combat and Vote, votes only in Vote, cards only in Cards", function()
			local primary = bindingsFor("Primary")[1]
			expect(InputRules.activeIn(primary, "Combat")).toBe(true)
			expect(InputRules.activeIn(primary, "Vote")).toBe(true)
			expect(InputRules.activeIn(primary, "Cards")).toBe(false)
			local vote = bindingsFor("VoteExtract")[1]
			expect(InputRules.activeIn(vote, "Combat")).toBe(false)
			expect(InputRules.activeIn(vote, "Vote")).toBe(true)
			local card = bindingsFor("CardSelect")[1]
			expect(InputRules.activeIn(card, "Cards")).toBe(true)
			expect(InputRules.activeIn(card, "Combat")).toBe(false)
		end)
	end)

	describe("schemes and defaults", function()
		it("maps input types to schemes", function()
			expect(InputRules.schemeOf(Enum.UserInputType.Keyboard)).toBe("KeyboardMouse")
			expect(InputRules.schemeOf(Enum.UserInputType.MouseButton1)).toBe("KeyboardMouse")
			expect(InputRules.schemeOf(Enum.UserInputType.MouseMovement)).toBe("KeyboardMouse")
			expect(InputRules.schemeOf(Enum.UserInputType.Touch)).toBe("Touch")
			expect(InputRules.schemeOf(Enum.UserInputType.Gamepad1)).toBe("Gamepad")
			expect(InputRules.schemeOf(Enum.UserInputType.Gamepad4)).toBe("Gamepad")
			expect(InputRules.schemeOf(Enum.UserInputType.Focus)).toBeNil()
			expect(InputRules.schemeOf(Enum.UserInputType.TextInput)).toBeNil()
		end)

		it("treats gamepad key codes as Gamepad whatever the input type", function()
			expect(InputRules.schemeOf(Enum.UserInputType.Keyboard, Enum.KeyCode.ButtonA)).toBe("Gamepad")
			expect(InputRules.schemeOf(Enum.UserInputType.Keyboard, Enum.KeyCode.ButtonR2)).toBe("Gamepad")
			expect(InputRules.schemeOf(Enum.UserInputType.Keyboard, Enum.KeyCode.DPadLeft)).toBe("Gamepad")
			expect(InputRules.schemeOf(Enum.UserInputType.Gamepad1, Enum.KeyCode.Thumbstick2)).toBe("Gamepad")
			expect(InputRules.schemeOf(Enum.UserInputType.Keyboard, Enum.KeyCode.Space)).toBe("KeyboardMouse")
			expect(InputRules.schemeOf(Enum.UserInputType.Keyboard, Enum.KeyCode.Backspace)).toBe("KeyboardMouse")
			expect(InputRules.schemeOf(Enum.UserInputType.MouseButton1, Enum.KeyCode.None)).toBe("KeyboardMouse")
		end)

		it("uses §2.4 device defaults: auto-aim on touch and gamepad, auto-fire on touch, fixed camera", function()
			expect(InputRules.effective("AutoAim", nil, "Touch")).toBe(true)
			expect(InputRules.effective("AutoAim", nil, "Gamepad")).toBe(true)
			expect(InputRules.effective("AutoAim", nil, "KeyboardMouse")).toBe(false)
			expect(InputRules.effective("AutoFire", nil, "Touch")).toBe(true)
			expect(InputRules.effective("AutoFire", nil, "Gamepad")).toBe(false)
			expect(InputRules.effective("AutoFire", nil, "KeyboardMouse")).toBe(false)
			expect(InputRules.effective("CameraRotate", nil, "KeyboardMouse")).toBe(false)
			expect(InputRules.effective("CameraRotate", nil, "Gamepad")).toBe(false)
		end)

		it("an explicit setting beats the device default", function()
			expect(InputRules.effective("AutoFire", false, "Touch")).toBe(false)
			expect(InputRules.effective("AutoFire", true, "KeyboardMouse")).toBe(true)
			expect(InputRules.effective("AutoAim", false, "Gamepad")).toBe(false)
			expect(InputRules.effective("CameraRotate", true, "Gamepad")).toBe(true)
		end)
	end)

	describe("geometry", function()
		it("maps a stick to a flat world direction relative to the camera", function()
			local north = Vector3.new(0, -0.8, -0.6) -- camera looking down toward -Z
			expect(near(InputRules.stickToWorld(0, 1, north), Vector3.new(0, 0, -1))).toBe(true)
			expect(near(InputRules.stickToWorld(1, 0, north), Vector3.new(1, 0, 0))).toBe(true)
			expect(near(InputRules.stickToWorld(-1, 0, north), Vector3.new(-1, 0, 0))).toBe(true)
			expect(near(InputRules.stickToWorld(0, -1, north), Vector3.new(0, 0, 1))).toBe(true)
			local east = Vector3.new(1, -1, 0) -- camera turned to look toward +X
			expect(near(InputRules.stickToWorld(0, 1, east), Vector3.new(1, 0, 0))).toBe(true)
			expect(near(InputRules.stickToWorld(1, 0, east), Vector3.new(0, 0, 1))).toBe(true)
		end)

		it("ignores stick input inside the dead zone and normalizes outside it", function()
			expect(InputRules.stickToWorld(0.1, 0.1, Vector3.new(0, 0, -1))).toBe(Vector3.zero)
			expect(InputRules.stickToWorld(0, 0, Vector3.new(0, 0, -1))).toBe(Vector3.zero)
			local d = InputRules.stickToWorld(0.3, 0.3, Vector3.new(0, 0, -1))
			expect(d.Magnitude).toBeCloseTo(1, 4)
		end)

		it("intersects a mouse ray with the plane at the character's height", function()
			local hit = InputRules.planeHit(Vector3.new(0, 30, 20), Vector3.new(0, -3, -2), 3)
			expect(hit ~= nil and near(hit, Vector3.new(0, 3, 2))).toBe(true)
			expect(InputRules.planeHit(Vector3.new(0, 30, 0), Vector3.new(1, 0, 0), 3)).toBeNil()
			expect(InputRules.planeHit(Vector3.new(0, 30, 0), Vector3.new(0, 1, 0), 3)).toBeNil()
		end)
	end)

	describe("aim", function()
		it("manual aim wins over the auto-aim target outside the assist cone", function()
			local d, source = aim({ manual = Vector3.new(1, 0, 0), target = Vector3.new(0, 0, -10) })
			expect(source).toBe("manual")
			expect(near(d, Vector3.new(1, 0, 0))).toBe(true)
		end)

		it("a stick inside the assist cone snaps to the target (touch and gamepad, not the mouse)", function()
			local target = Vector3.new(10, 0, 1) -- ~5.7° off +X
			local d, source = aim({ scheme = "Gamepad", manual = Vector3.new(1, 0, 0), target = target })
			expect(source).toBe("assist")
			expect(near(d, target.Unit)).toBe(true)
			local d2, source2 = aim({ scheme = "KeyboardMouse", manual = Vector3.new(1, 0, 0), target = target })
			expect(source2).toBe("manual")
			expect(near(d2, Vector3.new(1, 0, 0))).toBe(true)
		end)

		it("no assist when auto-aim is off", function()
			local _, source = aim({ scheme = "Gamepad", autoAim = false, manual = Vector3.new(1, 0, 0), target = Vector3.new(10, 0, 1) })
			expect(source).toBe("manual")
		end)

		it("without manual input, auto-aim faces the target in range", function()
			local d, source = aim({ target = Vector3.new(0, 5, 20) })
			expect(source).toBe("auto")
			expect(near(d, Vector3.new(0, 0, 1))).toBe(true)
		end)

		it("a target beyond auto-aim range is ignored", function()
			local _, source = aim({ target = Vector3.new(0, 0, InputRules.AUTO_AIM_RANGE + 1), move = Vector3.new(0, 0, -1) })
			expect(source).toBe("move")
		end)

		it("falls back to the move direction, then the last aim, then -Z", function()
			local d, source = aim({ move = Vector3.new(0, 0, -2) })
			expect(source).toBe("move")
			expect(near(d, Vector3.new(0, 0, -1))).toBe(true)
			local d2, source2 = aim({})
			expect(source2).toBe("hold")
			expect(near(d2, Vector3.new(1, 0, 0))).toBe(true)
			local d3 = aim({ last = Vector3.zero })
			expect(near(d3, Vector3.new(0, 0, -1))).toBe(true)
		end)

		it("always returns a flat unit vector", function()
			local d = aim({ manual = Vector3.new(0.6, 0, 0.8), target = Vector3.new(3, 9, 4) })
			expect(d.Y).toBe(0)
			expect(d.Magnitude).toBeCloseTo(1, 4)
		end)
	end)

	describe("firing and cards", function()
		it("fires when held by hand, or with auto-fire while moving", function()
			expect(InputRules.firing(true, false, false, "Combat")).toBe(true)
			expect(InputRules.firing(false, true, true, "Combat")).toBe(true)
			expect(InputRules.firing(false, true, false, "Combat")).toBe(false)
			expect(InputRules.firing(false, false, true, "Combat")).toBe(false)
			expect(InputRules.firing(false, true, true, "Vote")).toBe(true)
		end)

		it("never fires in the card context", function()
			expect(InputRules.firing(true, true, true, "Cards")).toBe(false)
		end)

		it("wraps card focus around three cards", function()
			expect(InputRules.stepFocus(1, 1, 3)).toBe(2)
			expect(InputRules.stepFocus(3, 1, 3)).toBe(1)
			expect(InputRules.stepFocus(1, -1, 3)).toBe(3)
			expect(InputRules.stepFocus(2, -1, 3)).toBe(1)
		end)
	end)

	describe("place settings the bindings rely on", function()
		it("no jump (Space is dodge), no mouse lock (Shift is dodge), keyboard movement and dynamic thumbstick", function()
			expect(StarterPlayer.CharacterUseJumpPower).toBe(false)
			expect(StarterPlayer.CharacterJumpHeight).toBe(0)
			expect(StarterPlayer.EnableMouseLockOption).toBe(false)
			expect(StarterPlayer.DevComputerMovementMode).toBe(Enum.DevComputerMovementMode.KeyboardMouse)
			expect(StarterPlayer.DevTouchMovementMode).toBe(Enum.DevTouchMovementMode.DynamicThumbstick)
		end)
	end)
end
