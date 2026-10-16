--!strict
-- Encounter/SimulationClock (A1.8, architecture §9.1): a paused clock does not advance, resume continues from where it
-- stopped, ticks accumulate, a hitch is capped at MaxStep, bad dt throws. Runs on a clone of the module.

local ServerScriptService = game:GetService("ServerScriptService")

local TestRunner = require(script.Parent.Parent.TestRunner)

type ClockModule = typeof(require(ServerScriptService.Server.Domains.Encounter.SimulationClock))

local SimulationClock: ClockModule = (require :: any)(ServerScriptService.Server.Domains.Encounter.SimulationClock:Clone())

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("ticking", function()
		it("starts at 0, running", function()
			local clock = SimulationClock.new()
			expect(clock:Now()).toBe(0)
			expect(clock.Paused).toBe(false)
			expect(clock.Ticks).toBe(0)
		end)

		it("accumulates dt tick by tick", function()
			local clock = SimulationClock.new()
			for _ = 1, 60 do
				clock:Tick(1 / 60)
			end
			expect(clock:Now()).toBeCloseTo(1, 1e-9)
			expect(clock.Ticks).toBe(60)
			expect(clock:Tick(0.125)).toBe(0.125)
			expect(clock:Now()).toBeCloseTo(1.125, 1e-9)
		end)

		it("caps a hitch at MaxStep (0.25 s by default)", function()
			local clock = SimulationClock.new()
			expect(clock.MaxStep).toBe(0.25)
			expect(clock:Tick(2)).toBe(0.25)
			expect(clock:Now()).toBe(0.25)
			local custom = SimulationClock.new({ maxStep = 1 })
			expect(custom:Tick(2)).toBe(1)
		end)

		it("dt 0 adds nothing and is not counted", function()
			local clock = SimulationClock.new()
			expect(clock:Tick(0)).toBe(0)
			expect(clock.Ticks).toBe(0)
		end)

		it("clocks are independent (one per match)", function()
			local a, b = SimulationClock.new(), SimulationClock.new()
			a:Tick(0.1)
			b:Pause()
			b:Tick(0.1)
			expect(a:Now()).toBe(0.1)
			expect(b:Now()).toBe(0)
		end)
	end)

	describe("pause and resume", function()
		it("a paused clock does not advance", function()
			local clock = SimulationClock.new({ maxStep = 1 })
			clock:Tick(0.5)
			clock:Pause()
			expect(clock.Paused).toBe(true)
			for _ = 1, 600 do
				expect(clock:Tick(1 / 60)).toBe(0)
			end
			expect(clock:Now()).toBe(0.5)
			expect(clock.Ticks).toBe(1)
		end)

		it("resume continues from the paused time", function()
			local clock = SimulationClock.new({ maxStep = 1 })
			clock:Tick(0.5)
			clock:Pause()
			clock:Tick(0.2)
			clock:Resume()
			expect(clock.Paused).toBe(false)
			clock:Tick(0.25)
			expect(clock:Now()).toBe(0.75)
		end)

		it("pause and resume are idempotent", function()
			local clock = SimulationClock.new()
			clock:Pause()
			clock:Pause()
			clock:Tick(1)
			clock:Resume()
			clock:Resume()
			clock:Tick(0.1)
			expect(clock:Now()).toBe(0.1)
		end)

		it("does not read os.clock: wall time passing while paused changes nothing", function()
			local clock = SimulationClock.new()
			clock:Pause()
			task.wait(0.05)
			clock:Resume()
			expect(clock:Now()).toBe(0)
		end)
	end)

	describe("arguments and service shape", function()
		it("rejects negative, NaN and infinite dt and a bad maxStep", function()
			local clock = SimulationClock.new()
			for _, dt in { -0.01, 0 / 0, math.huge } do
				expect(function()
					clock:Tick(dt)
				end).toThrow("[Clock] dt")
			end
			expect(clock:Now()).toBe(0)
			expect(function()
				SimulationClock.new({ maxStep = 0 })
			end).toThrow("maxStep")
		end)

		it("is the Encounter service named SimulationClock", function()
			expect(SimulationClock.Name).toBe("SimulationClock")
			expect(typeof(SimulationClock.Init)).toBe("function")
			expect(typeof(SimulationClock.Start)).toBe("function")
		end)
	end)
end
