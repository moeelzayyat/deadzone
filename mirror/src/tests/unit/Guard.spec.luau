--!strict
-- Net/Guard (A1.8, architecture §19): each guard accepts its type and rejects wrong types, NaN/inf, out-of-range values,
-- oversized and malformed tables without throwing. Runs on a clone of Shared.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestRunner = require(script.Parent.Parent.TestRunner)

type GuardModule = typeof(require(ReplicatedStorage.Shared.Net.Guard))
type Check = (unknown) -> (boolean, string?)

local shared = ReplicatedStorage.Shared:Clone()
local Guard: GuardModule = (require :: any)((shared :: any).Net.Guard)

local NAN = 0 / 0
local INF = math.huge

-- Values a client could send that are never valid for a non-table guard of another type.
local JUNK: { any } = { NAN, INF, -INF, "", "x", true, {}, Vector3.zero, buffer.create(1), CFrame.identity, workspace }

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	local function accepts(check: Check, value: unknown)
		local ok, reason = check(value)
		if not ok then
			error(`expected {tostring(value)} to pass, got: {reason}`, 0)
		end
	end

	local function rejects(check: Check, value: unknown, fragment: string?)
		local ok, reason = check(value)
		expect(ok).toBe(false)
		expect(typeof(reason)).toBe("string")
		if fragment and not string.find(reason :: string, fragment, 1, true) then
			error(`expected reason containing {fragment}, got {reason}`, 0)
		end
	end

	describe("scalars", function()
		it("number: finite only, bounds, integer", function()
			local anyNumber = Guard.number()
			accepts(anyNumber, 0)
			accepts(anyNumber, -1e300)
			rejects(anyNumber, NAN, "not finite")
			rejects(anyNumber, INF, "not finite")
			rejects(anyNumber, "1", "expected number")
			local u32 = Guard.integer(0, 4294967295)
			accepts(u32, 0)
			accepts(u32, 4294967295)
			rejects(u32, -1, "below")
			rejects(u32, 4294967296, "above")
			rejects(u32, 1.5, "whole")
		end)

		it("boolean, string, literal", function()
			accepts(Guard.boolean(), false)
			rejects(Guard.boolean(), 0)
			local s = Guard.string(4)
			accepts(s, "abcd")
			rejects(s, "abcde", "exceeds 4")
			rejects(s, "", "empty")
			accepts(Guard.string(4, true), "")
			local vote = Guard.literal("Hold", "Extract")
			accepts(vote, "Hold")
			rejects(vote, "hold", "Hold|Extract")
			rejects(vote, 1)
		end)

		it("vector3: finite, unit, max magnitude", function()
			local dir = Guard.vector3({ unit = true })
			accepts(dir, Vector3.new(0, 0, -1))
			accepts(Guard.vector3(), Vector3.new(1e6, 0, 0))
			rejects(dir, Vector3.new(0, 0, -2), "not 1")
			rejects(dir, Vector3.new(NAN, 0, 0), "not finite")
			rejects(dir, Vector3.new(INF, 0, 0), "not finite")
			rejects(Guard.vector3({ maxMagnitude = 6 }), Vector3.new(7, 0, 0), "exceeds 6")
			rejects(dir, { X = 0, Y = 0, Z = -1 }, "expected Vector3")
		end)

		it("buffer: type and size", function()
			local b = Guard.buffer(8)
			accepts(b, buffer.create(8))
			rejects(b, buffer.create(9), "exceeds 8")
			rejects(b, "12345678", "expected buffer")
		end)

		it("rejects nil and every junk value of another type", function()
			local guards: { Check } = { Guard.number(), Guard.boolean(), Guard.string(10), Guard.vector3(), Guard.literal("A", "B") }
			local types = { "number", "boolean", "string", "Vector3", "string" }
			for i, check in guards do
				rejects(check, nil)
				for _, value in JUNK do
					if (check(value)) then
						expect(typeof(value)).toBe(types[i])
					end
				end
			end
		end)
	end)

	describe("tables", function()
		local attack = Guard.record({
			Seq = Guard.integer(0, 4294967295),
			Dir = Guard.vector3({ unit = true }),
			TargetHint = Guard.optional(Guard.integer(0, 65535)),
		})

		it("record: exact fields, optional fields, nested reasons", function()
			accepts(attack, { Seq = 1, Dir = Vector3.xAxis })
			accepts(attack, { Seq = 1, Dir = Vector3.xAxis, TargetHint = 3 })
			rejects(attack, { Seq = 1 }, "Dir: expected Vector3")
			rejects(attack, { Seq = 1, Dir = Vector3.xAxis, Damage = 9999 }, "unknown field Damage")
			rejects(attack, { Seq = -1, Dir = Vector3.xAxis }, "Seq:")
			rejects(attack, { [1] = 1, Seq = 1, Dir = Vector3.xAxis } :: any, "unknown field 1")
			rejects(attack, "x", "expected table")
			rejects(attack, setmetatable({ Seq = 1, Dir = Vector3.xAxis }, {}), "expected table")
		end)

		it("empty: only {}", function()
			accepts(Guard.empty(), {})
			rejects(Guard.empty(), { 1 }, "empty")
			rejects(Guard.empty(), nil, "expected table")
		end)

		it("array: dense, bounded, typed items", function()
			local ids = Guard.array(Guard.string(36), 3)
			accepts(ids, {})
			accepts(ids, { "a", "b", "c" })
			rejects(ids, { "a", "b", "c", "d" }, "exceeds 3")
			rejects(ids, { [1] = "a", [3] = "c" }, "sparse")
			rejects(ids, { a = "x" }, "array key a")
			rejects(ids, { "a" :: any, 2 }, "[2]: expected string")
			rejects(ids, { [1.5] = "a" }, "array key")
		end)

		it("map: bounded, typed keys and values", function()
			local flags = Guard.map(Guard.string(8), Guard.oneOf(Guard.boolean(), Guard.number()), 2)
			accepts(flags, {})
			accepts(flags, { A = true, B = 2 } :: any)
			rejects(flags, { A = true, B = 2, C = 3 } :: any, "exceeds 2")
			rejects(flags, { A = "yes" }, "no option matched")
			rejects(flags, { [5] = true }, "key: expected string")
			rejects(flags, { A = NAN }, "no option matched")
		end)

		it("guards never throw, even on cyclic tables", function()
			local cyclic: { [string]: any } = {}
			cyclic.Seq = cyclic
			local ok = pcall(attack, cyclic)
			expect(ok).toBe(true)
			expect((attack(cyclic))).toBe(false)
		end)
	end)

	describe("builders", function()
		it("reject malformed guard definitions", function()
			expect(function()
				Guard.number({ min = 2, max = 1 })
			end).toThrow("above max")
			expect(function()
				Guard.number({ min = NAN })
			end).toThrow("finite")
			expect(function()
				Guard.string(0)
			end).toThrow("maxLength")
			expect(function()
				Guard.literal()
			end).toThrow("at least one")
			expect(function()
				Guard.oneOf(Guard.boolean())
			end).toThrow("at least two")
			expect(function()
				Guard.record({})
			end).toThrow("Guard.empty")
			expect(function()
				Guard.array(Guard.boolean(), 0)
			end).toThrow("maxLength")
		end)
	end)
end
