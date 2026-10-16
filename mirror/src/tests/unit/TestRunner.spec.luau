--!strict
-- Sample specs for the harness itself (A1.2): matchers pass, a failing matcher raises, a yielding test is awaited.

local TestRunner = require(script.Parent.Parent.TestRunner)

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("expect", function()
		it("passes matching values, tables and numbers", function()
			expect(1 + 1).toBe(2)
			expect({ a = { 1, 2 }, b = "x" }).toEqual({ a = { 1, 2 }, b = "x" })
			expect(0.1 + 0.2).toBeCloseTo(0.3)
			expect(5).toBeGreaterThan(4)
			expect(-1).toBeLessThan(0)
			expect(nil).toBeNil()
			expect("ok").toBeTruthy()
		end)

		it("raises with a readable message when a matcher fails", function()
			expect(function()
				expect(1).toBe(2)
			end).toThrow("expected 1 to be 2")
			expect(function()
				expect({ 1 }).toEqual({ 2 })
			end).toThrow("to deep-equal")
		end)
	end)

	describe("async", function()
		it("awaits a test that yields", function()
			local startedAt = os.clock()
			task.wait(0.1)
			expect(os.clock() - startedAt).toBeGreaterThan(0.09)
		end, 2)
	end)
end
