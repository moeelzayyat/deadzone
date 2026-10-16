--!strict
-- Net/Contracts (A1.8, CLAUDE.md rule 6): the shipped registry is valid and matches the docs/API_CONTRACTS.md rows built
-- so far; malformed contracts fail at build time with every problem listed. Runs on a clone of Shared.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestRunner = require(script.Parent.Parent.TestRunner)

type ContractsModule = typeof(require(ReplicatedStorage.Shared.Net.Contracts))
type GuardModule = typeof(require(ReplicatedStorage.Shared.Net.Guard))

local shared = ReplicatedStorage.Shared:Clone()
local Contracts: ContractsModule = (require :: any)((shared :: any).Net.Contracts)
local Guard: GuardModule = (require :: any)((shared :: any).Net.Guard)

local function contract(overrides: { [string]: any }): any
	local c: { [string]: any } = {
		Name = "RequestThing",
		Channel = "R",
		Direction = "C2S",
		Payload = Guard.empty(),
		Rate = { Sustained = 2, Burst = 3 },
		Since = "A1.8",
	}
	for k, v in overrides do
		c[k] = v
	end
	return c
end

local function without(field: string): any
	local c = contract({})
	c[field] = nil
	return c
end

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("shipped registry", function()
		it("EnemySnapshot: server→client, unreliable, since A2.3, buffers up to 889 bytes", function()
			local snapshot = Contracts.get("EnemySnapshot")
			expect(snapshot.Channel).toBe("U")
			expect(snapshot.Direction).toBe("S2C")
			expect(snapshot.Since).toBe("A2.3")
			expect(snapshot.Rate).toBeNil()
			expect((snapshot.Payload(buffer.create(889)))).toBe(true)
			expect((snapshot.Payload(buffer.create(890)))).toBe(false)
			expect((snapshot.Payload("889"))).toBe(false)
		end)

		it("RequestEnemySnapshots: client→server, reliable, since A2.3, 1/s burst 2, empty payload only", function()
			local request = Contracts.get("RequestEnemySnapshots")
			expect(request.Channel).toBe("R")
			expect(request.Direction).toBe("C2S")
			expect(request.Since).toBe("A2.3")
			expect(request.Rate).toEqual({ Sustained = 1, Burst = 2 })
			expect((request.Payload({}))).toBe(true)
			expect((request.Payload({ All = true }))).toBe(false)
			expect((request.Payload(nil))).toBe(false)
		end)

		it("holds four contracts; FlagsUpdate: server→client, reliable, since A1.8, no client rate", function()
			expect(#Contracts.list).toBe(4)
			local flags = Contracts.get("FlagsUpdate")
			expect(flags.Channel).toBe("R")
			expect(flags.Direction).toBe("S2C")
			expect(flags.Since).toBe("A1.8")
			expect(flags.Rate).toBeNil()
			expect(table.isfrozen(flags)).toBe(true)
			expect(table.isfrozen(Contracts.list)).toBe(true)
		end)

		it("FlagsUpdate accepts a flag map and rejects junk", function()
			local check = Contracts.get("FlagsUpdate").Payload
			expect((check({ SampleFlag = true, Variant = "B", Weight = 0.5 }))).toBe(true)
			expect((check({}))).toBe(true)
			expect((check({ SampleFlag = Vector3.zero }))).toBe(false)
			expect((check({ [1] = true }))).toBe(false)
			expect((check({ SampleFlag = 0 / 0 }))).toBe(false)
			local many: { [string]: boolean } = {}
			for i = 1, 65 do
				many["F" .. i] = true
			end
			expect((check(many))).toBe(false)
		end)

		it("get throws for a remote with no contract", function()
			expect(function()
				Contracts.get("RequestAttack")
			end).toThrow("no contract named RequestAttack")
		end)
	end)

	describe("validation", function()
		it("accepts a well-formed client→server contract", function()
			expect(#Contracts.problems({ contract({}) })).toBe(0)
			expect(#Contracts.build({ contract({}) })).toBe(1)
		end)

		it("needs a rate on client→server remotes and none on server→client ones", function()
			expect(Contracts.problems({ without("Rate") })[1]).toBe(
				"RequestThing: a client→server remote needs Rate = { Sustained, Burst }"
			)
			expect(#Contracts.problems({ contract({ Rate = { Sustained = 0, Burst = 3 } }) })).toBe(1)
			expect(#Contracts.problems({ contract({ Rate = { Sustained = 1, Burst = 0.5 } }) })).toBe(1)
			expect(#Contracts.problems({ contract({ Direction = "S2C" }) })).toBe(1)
		end)

		it("rejects a server→client RemoteFunction, bad names, channels, Since and payloads", function()
			local fn = without("Rate")
			fn.Channel = "F"
			fn.Direction = "S2C"
			expect(Contracts.problems({ fn })).toEqual({ "RequestThing: a RemoteFunction is client→server only" })
			local problems = Contracts.problems({
				contract({ Name = "bad name" }),
				contract({ Name = "Two", Channel = "X" }),
				contract({ Name = "Three", Since = "soon" }),
				contract({ Name = "Four", Payload = "guard" }),
				contract({ Name = "Five", Direction = "Both" }),
			})
			expect(#problems).toBe(5)
		end)

		it("rejects duplicate names and lists every problem in one error", function()
			expect(function()
				Contracts.build({ contract({}), contract({}), contract({ Name = "Other", Channel = "Q" }) })
			end).toThrow("[Contracts] 2 problems")
		end)
	end)
end
