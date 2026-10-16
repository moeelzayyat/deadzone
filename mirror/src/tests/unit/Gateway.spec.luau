--!strict
-- Server/Gateway (A1.8, architecture §5.2 phase 8, §7.1, §7.2, §19): remotes exist only after phase 8, one per contract;
-- inbound requests run identity → token bucket → guard → handler; the N+1th request of a burst is dropped and counted;
-- three bursts in a minute flag the session; pushes are checked and only allowed after phase 8.
-- Uses test contracts and a scratch parent folder, never ReplicatedStorage. Lifecycle and Gateway are cloned together so
-- Gateway reads the cloned Lifecycle's phase.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TestRunner = require(script.Parent.Parent.TestRunner)

type GatewayModule = typeof(require(ServerScriptService.Server.Gateway))
type LifecycleModule = typeof(require(ServerScriptService.Server.Lifecycle))
type ContractsModule = typeof(require(ReplicatedStorage.Shared.Net.Contracts))
type GuardModule = typeof(require(ReplicatedStorage.Shared.Net.Guard))

local serverClone = Instance.new("Folder")
ServerScriptService.Server.Lifecycle:Clone().Parent = serverClone
ServerScriptService.Server.Gateway:Clone().Parent = serverClone
local Lifecycle: LifecycleModule = (require :: any)((serverClone :: any).Lifecycle)
local Gateway: GatewayModule = (require :: any)((serverClone :: any).Gateway)

local shared = ReplicatedStorage.Shared:Clone()
local Contracts: ContractsModule = (require :: any)((shared :: any).Net.Contracts)
local Guard: GuardModule = (require :: any)((shared :: any).Net.Guard)

type Gw = typeof(Gateway.new())
type Service = typeof(Lifecycle.get(""))

local ENTRIES: { any } = {
	{
		Name = "RequestPing",
		Channel = "R",
		Direction = "C2S",
		Payload = Guard.record({ Seq = Guard.integer(0, 4294967295) }),
		Rate = { Sustained = 2, Burst = 3 },
		Since = "A1.8",
	},
	{
		Name = "RequestAsk",
		Channel = "F",
		Direction = "C2S",
		Payload = Guard.empty(),
		Rate = { Sustained = 1, Burst = 2 },
		Since = "A1.8",
	},
	{
		Name = "PushState",
		Channel = "R",
		Direction = "S2C",
		Payload = Guard.record({ N = Guard.integer(0, 100) }),
		Since = "A1.8",
	},
	{
		Name = "PushFast",
		Channel = "U",
		Direction = "S2C",
		Payload = Guard.buffer(16),
		Since = "A1.8",
	},
}
local CONTRACTS = Contracts.build(ENTRIES :: any)

type RigOptions = { strict: boolean?, noHandlers: boolean? }

type Rig = {
	gateway: Gw,
	parent: Folder,
	setTime: (number) -> (),
	setPhase: (number?) -> (),
	handled: { any },
	counted: { string },
	reported: { string },
}

-- A gateway on the test contracts with a fake clock and phase, handlers that record their payloads, and hooks.
local function rig(options: RigOptions?): Rig
	local now = 0
	local phase: number? = nil
	local parent = Instance.new("Folder")
	local handled: { any } = {}
	local counted: { string } = {}
	local reported: { string } = {}
	local gateway = Gateway.new({
		contracts = CONTRACTS,
		parent = parent :: Instance,
		clock = function(): number
			return now
		end,
		phase = function(): number?
			return phase
		end,
		strict = if options and options.strict ~= nil then options.strict else true,
	})
	gateway:setCounter(function(name: string)
		table.insert(counted, name)
	end)
	gateway:setReporter(function(kind: string, message: string)
		table.insert(reported, `{kind}: {message}`)
	end)
	if not (options and options.noHandlers) then
		gateway:handle("RequestPing", function(_player: Player, payload: any): any
			table.insert(handled, payload)
			return payload.Seq
		end)
		gateway:handle("RequestAsk", function(): any
			return "answer"
		end)
	end
	return {
		gateway = gateway,
		parent = parent,
		setTime = function(t: number)
			now = t
		end,
		setPhase = function(p: number?)
			phase = p
		end,
		handled = handled,
		counted = counted,
		reported = reported,
	}
end

local function exposed(options: RigOptions?): Rig
	local r = rig(options)
	r.setPhase(8)
	r.gateway:expose()
	r.setPhase(nil)
	return r
end

local function noop(): any
	return nil
end

local function countOf(list: { string }, name: string): number
	local n = 0
	for _, item in list do
		if item == name then
			n += 1
		end
	end
	return n
end

local function remoteCount(root: Instance): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BaseRemoteEvent") or d:IsA("RemoteFunction") then
			n += 1
		end
	end
	return n
end

local function ping(r: Rig, seq: number, userId: number?): (boolean, any)
	return r.gateway:receive("RequestPing", userId or 1, nil, { Seq = seq })
end

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("remotes are created in phase 8 only", function()
		it("a remote does not exist before phase 8 of a real boot, and every contract has one after", function()
			local parent = Instance.new("Folder")
			local gateway = Gateway.new({ contracts = CONTRACTS, parent = parent :: Instance }) -- phase from the cloned Lifecycle
			local seen: { string } = {}
			local function probe(label: string)
				table.insert(seen, `{label}:{remoteCount(parent)}:{if parent:FindFirstChild("Net") then "net" else "-"}`)
			end
			local function service(name: string, phase: number): Service
				return {
					Name = name,
					Init = function(_self: Service)
						probe(`{name}:Init:{Lifecycle.currentPhase()}`)
					end,
					Start = function(_self: Service)
						probe(`{name}:Start:{Lifecycle.currentPhase()}`)
						if phase == 7 then
							gateway:handle("RequestPing", noop)
							gateway:handle("RequestAsk", noop)
						end
					end,
				}
			end
			local plan = {}
			for _, spec in Lifecycle.PHASES do
				table.insert(plan, { index = spec.index, name = spec.name, entries = {} })
			end
			table.insert(plan[1].entries, { domain = "Platform", service = service("FakePlatform", 0) })
			table.insert(plan[5].entries, { domain = "Economy", service = service("FakeEconomy", 4) })
			table.insert(plan[8].entries, { domain = "Social", service = service("FakeSocial", 7) })
			local createdDuring = -1
			Lifecycle.run(plan :: any, {
				network = function(): string
					probe(`network:{Lifecycle.currentPhase()}`)
					createdDuring = gateway:expose()
					return ""
				end,
			})
			expect(seen).toEqual({
				"FakePlatform:Init:0:0:-",
				"FakeEconomy:Init:4:0:-",
				"FakeSocial:Init:7:0:-",
				"FakePlatform:Start:0:0:-",
				"FakeEconomy:Start:4:0:-",
				"FakeSocial:Start:7:0:-",
				"network:8:0:-",
			})
			expect(createdDuring).toBe(4)
			expect(Lifecycle.currentPhase()).toBeNil()
			local net = parent:FindFirstChild("Net") :: Instance
			expect(remoteCount(parent)).toBe(4)
			expect((net:FindFirstChild("RequestPing") :: Instance).ClassName).toBe("RemoteEvent")
			expect((net:FindFirstChild("RequestAsk") :: Instance).ClassName).toBe("RemoteFunction")
			expect((net:FindFirstChild("PushState") :: Instance).ClassName).toBe("RemoteEvent")
			expect((net:FindFirstChild("PushFast") :: Instance).ClassName).toBe("UnreliableRemoteEvent")
		end)

		it("expose refuses outside a boot and in any phase but 8", function()
			local r = rig()
			expect(function()
				r.gateway:expose()
			end).toThrow("phase 8 only (current phase: none)")
			for phase = 0, 7 do
				r.setPhase(phase)
				expect(function()
					r.gateway:expose()
				end).toThrow(`current phase: {phase}`)
			end
			expect(remoteCount(r.parent)).toBe(0)
			expect(r.parent:FindFirstChild("Net")).toBeNil()
		end)

		it("expose from inside an Init is a boot error", function()
			local gateway = Gateway.new({ contracts = CONTRACTS, parent = Instance.new("Folder") :: Instance })
			local plan = {}
			for _, spec in Lifecycle.PHASES do
				table.insert(plan, { index = spec.index, name = spec.name, entries = {} })
			end
			table.insert(plan[1].entries, {
				domain = "Platform",
				service = {
					Name = "EagerService",
					Init = function()
						gateway:expose()
					end,
					Start = function() end,
				},
			})
			expect(function()
				Lifecycle.run(plan :: any)
			end).toThrow("phase 8 only (current phase: 0)")
			expect(Lifecycle.currentPhase()).toBeNil()
		end)

		it("expose fails when a client→server contract has no handler, and creates nothing", function()
			local r = rig({ noHandlers = true })
			r.gateway:handle("RequestPing", noop)
			r.setPhase(8)
			expect(function()
				r.gateway:expose()
			end).toThrow("RequestAsk is client→server but no service registered a handler")
			expect(r.parent:FindFirstChild("Net")).toBeNil()
		end)

		it("expose runs once and refuses an existing Net folder", function()
			local r = exposed()
			r.setPhase(8)
			expect(function()
				r.gateway:expose()
			end).toThrow("already ran")
			local other = rig()
			Instance.new("Folder", other.parent).Name = "Net"
			other.setPhase(8)
			expect(function()
				other.gateway:expose()
			end).toThrow("already exists before phase 8")
		end)

		it("onExposed callbacks run after expose, or at once when it already ran", function()
			local r = rig()
			local calls: { string } = {}
			r.gateway:onExposed(function()
				table.insert(calls, `first:{remoteCount(r.parent)}`)
			end)
			expect(#calls).toBe(0)
			r.setPhase(8)
			r.gateway:expose()
			r.gateway:onExposed(function()
				table.insert(calls, "second")
			end)
			expect(calls).toEqual({ "first:4", "second" })
		end)
	end)

	describe("handlers", function()
		it("only client→server remotes take one handler each, before phase 8", function()
			local r = rig({ noHandlers = true })
			expect(function()
				r.gateway:handle("PushState", noop)
			end).toThrow("only client→server remotes take handlers")
			expect(function()
				r.gateway:handle("RequestNothing", noop)
			end).toThrow("no contract named RequestNothing")
			r.gateway:handle("RequestPing", noop)
			expect(function()
				r.gateway:handle("RequestPing", noop)
			end).toThrow("already has a handler")
			local e = exposed()
			expect(function()
				(e.gateway :: any):handle("RequestPing", noop)
			end).toThrow("after phase 8")
		end)
	end)

	describe("inbound pipeline", function()
		it("passes a valid request to its handler and returns the result", function()
			local r = exposed()
			local ok, result = ping(r, 7)
			expect(ok).toBe(true)
			expect(result).toBe(7)
			expect(r.handled).toEqual({ { Seq = 7 } })
			local okAsk, answer = r.gateway:receive("RequestAsk", 1, nil, {})
			expect(okAsk).toBe(true)
			expect(answer).toBe("answer")
		end)

		it("the bucket rejects the N+1th request of a burst and counts RateLimited", function()
			local r = exposed()
			for seq = 1, 3 do
				expect((ping(r, seq))).toBe(true)
			end
			local ok, reason = ping(r, 4)
			expect(ok).toBe(false)
			expect(reason).toBe("rate")
			expect(#r.handled).toBe(3)
			expect(countOf(r.counted, "RateLimited")).toBe(1)
			expect(countOf(r.counted, "Net.Rejected.rate")).toBe(1)
			r.setTime(0.5) -- Sustained 2/s: one token back
			expect((ping(r, 5))).toBe(true)
			expect((ping(r, 6))).toBe(false)
		end)

		it("buckets are per player and per remote", function()
			local r = exposed()
			for _ = 1, 3 do
				ping(r, 1, 1)
			end
			expect((ping(r, 1, 1))).toBe(false)
			expect((ping(r, 1, 2))).toBe(true)
			expect((r.gateway:receive("RequestAsk", 1, nil, {}))).toBe(true)
		end)

		it("checks the rate before the payload (spam with junk still drains the bucket)", function()
			local r = exposed()
			for _ = 1, 3 do
				local ok, reason = r.gateway:receive("RequestPing", 1, nil, { Seq = "junk" })
				expect(ok).toBe(false)
				expect(reason).toBe("payload")
			end
			local _, reason = r.gateway:receive("RequestPing", 1, nil, { Seq = "junk" })
			expect(reason).toBe("rate")
			expect(#r.handled).toBe(0)
		end)

		it("drops bad payloads, extra arguments, bad identities and unknown remotes before the handler", function()
			local r = exposed()
			local cases: { { any } } = {
				{ "RequestPing", 1, { Seq = 1, Damage = 999 }, 0, "payload" },
				{ "RequestPing", 2, { Seq = 0 / 0 }, 0, "payload" },
				{ "RequestPing", 3, { Seq = 1 }, 1, "arity" },
				{ "RequestPing", 4.5, { Seq = 1 }, 0, "identity" },
				{ "RequestNothing", 5, {}, 0, "unknown" },
			}
			for _, case in cases do
				local ok, reason = r.gateway:receive(case[1], case[2], nil, case[3], case[4])
				expect(ok).toBe(false)
				expect(reason).toBe(case[5])
				expect(countOf(r.counted, `Net.Rejected.{case[5]}`) >= 1).toBe(true)
			end
			expect(#r.handled).toBe(0)
		end)

		it("a handler error is caught, counted and reported; the gateway keeps serving", function()
			local r = rig({ noHandlers = true })
			r.gateway:handle("RequestPing", function()
				error("boom", 0)
			end)
			r.gateway:handle("RequestAsk", noop)
			r.setPhase(8)
			r.gateway:expose()
			local ok, reason = ping(r, 1)
			expect(ok).toBe(false)
			expect(reason).toBe("handler")
			expect(countOf(r.counted, "Net.HandlerError")).toBe(1)
			expect(r.reported).toEqual({ "handler: RequestPing: boom" })
			expect((r.gateway:receive("RequestAsk", 1, nil, {}))).toBe(true)
		end)

		it("client traffic on a server→client remote is dropped and rate-counted (empty bucket)", function()
			local r = exposed()
			local ok, reason = r.gateway:receive("PushState", 1, nil, { N = 1 })
			expect(ok).toBe(false)
			expect(reason).toBe("direction")
			expect(countOf(r.counted, "RateLimited")).toBe(1)
		end)
	end)

	describe("session flag (three bursts in a minute)", function()
		-- One burst = exhaust the bucket at time t, then one more request that is dropped.
		local function burst(r: Rig, at: number, userId: number?)
			r.setTime(at)
			for _ = 1, 4 do
				ping(r, 1, userId)
			end
		end

		it("flags on the third burst inside 60 s, once", function()
			local r = exposed()
			burst(r, 0)
			burst(r, 10)
			expect(r.gateway:isFlagged(1)).toBe(false)
			burst(r, 20)
			expect(r.gateway:isFlagged(1)).toBe(true)
			burst(r, 30)
			expect(countOf(r.counted, "SessionFlagged")).toBe(1)
			expect(r.gateway:isFlagged(2)).toBe(false)
		end)

		it("a continuous run of drops is one burst", function()
			local r = exposed()
			burst(r, 0)
			for _ = 1, 100 do
				ping(r, 1)
			end
			expect(countOf(r.counted, "RateLimited")).toBe(101)
			expect(r.gateway:isFlagged(1)).toBe(false)
		end)

		it("bursts more than 60 s apart do not flag", function()
			local r = exposed()
			burst(r, 0)
			burst(r, 40)
			burst(r, 100.5) -- the burst at 0 has left the window
			expect(r.gateway:isFlagged(1)).toBe(false)
			burst(r, 130) -- the burst at 40 has left the window too
			expect(r.gateway:isFlagged(1)).toBe(false)
			burst(r, 140) -- 100.5, 130, 140
			expect(r.gateway:isFlagged(1)).toBe(true)
		end)

		it("forget clears a player's buckets and flag", function()
			local r = exposed()
			burst(r, 0)
			burst(r, 1)
			burst(r, 2)
			expect(r.gateway:isFlagged(1)).toBe(true)
			r.gateway:forget(1)
			expect(r.gateway:isFlagged(1)).toBe(false)
			expect((ping(r, 1))).toBe(true)
		end)
	end)

	describe("server pushes", function()
		it("refuse before phase 8 and on client→server remotes", function()
			local r = rig()
			expect(function()
				r.gateway:fireAll("PushState", { N = 1 })
			end).toThrow("before phase 8")
			local e = exposed()
			expect(function()
				e.gateway:fireAll("RequestPing", { Seq = 1 })
			end).toThrow("the server cannot fire it")
		end)

		it("check outgoing payloads: strict throws, lenient counts and drops", function()
			local strict = exposed()
			expect(function()
				strict.gateway:fireAll("PushState", { N = 101 })
			end).toThrow("outgoing payload rejected")
			local lenient = exposed({ strict = false })
			lenient.gateway:fireAll("PushState", { N = "x" })
			expect(countOf(lenient.counted, "Net.OutgoingRejected")).toBe(1)
			expect(#lenient.reported).toBe(1)
		end)

		it("fire valid payloads on reliable and unreliable remotes", function()
			local r = exposed()
			r.gateway:fireAll("PushState", { N = 5 })
			r.gateway:fireAll("PushFast", buffer.create(16))
			expect(#r.reported).toBe(0)
		end)
	end)

	describe("shared gateway", function()
		it("Gateway.server() is one object on a server and refuses elsewhere", function()
			if not game:GetService("RunService"):IsServer() then
				expect(function()
					Gateway.server()
				end).toThrow("server only")
				return
			end
			local a = Gateway.server()
			expect(Gateway.server()).toBe(a)
			expect(a.exposed).toBe(false) -- the clone's gateway; the live one belongs to the real module
		end)
	end)
end
