--!strict
-- Player settings (A2.1, architecture §2.4; API_CONTRACTS RequestSettings): the whitelist, the RequestSettings contract
-- (reliable, client→server, 5/s burst 10, `{ Key, Value }` with a whitelisted Key and a boolean Value, nothing else) and
-- Data/SettingsService behind a real Gateway on the shipped contracts: accepted values are stored per player, bad
-- payloads and spam never reach it, leaving clears it. Server and Shared are cloned so the modules load fresh.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TestRunner = require(script.Parent.Parent.TestRunner)

type ContractsModule = typeof(require(ReplicatedStorage.Shared.Net.Contracts))
type SettingsModule = typeof(require(ReplicatedStorage.Shared.Config.Settings))
type GatewayModule = typeof(require(ServerScriptService.Server.Gateway))
type ServiceModule = typeof(require(ServerScriptService.Server.Domains.Data.SettingsService))

local shared = ReplicatedStorage.Shared:Clone()
local Contracts: ContractsModule = (require :: any)((shared :: any).Net.Contracts)
local Settings: SettingsModule = (require :: any)((shared :: any).Config.Settings)
local server = ServerScriptService.Server:Clone()
local Gateway: GatewayModule = (require :: any)((server :: any).Gateway)
local SettingsService: ServiceModule = (require :: any)((server :: any).Domains.Data.SettingsService)

type Gw = typeof(Gateway.new())
type Service = typeof(SettingsService.new())

local PLAYER_A: any = { UserId = 101, Name = "A" }
local PLAYER_B: any = { UserId = 202, Name = "B" }

type Rig = { gateway: Gw, service: Service, setTime: (number) -> (), counted: { string } }

-- A gateway on the shipped contracts (fake clock, phase 8 for expose) with a SettingsService registered on it. Other
-- client→server contracts are left out: their services are not part of this rig, and expose() needs a handler for each.
local function rig(): Rig
	local now = 0
	local phase: number? = nil
	local counted: { string } = {}
	local contracts = {}
	for _, c in Contracts.list do
		if c.Direction == "S2C" or c.Name == "RequestSettings" then
			table.insert(contracts, c)
		end
	end
	local gateway = Gateway.new({
		contracts = contracts,
		parent = Instance.new("Folder") :: Instance,
		clock = function(): number
			return now
		end,
		phase = function(): number?
			return phase
		end,
		strict = true,
	})
	gateway:setCounter(function(name: string)
		table.insert(counted, name)
	end)
	gateway:setReporter(function() end)
	local service = SettingsService.new({ gateway = gateway :: any, players = false })
	service:Init()
	service:Start()
	phase = 8
	gateway:expose()
	phase = nil
	return {
		gateway = gateway,
		service = service,
		setTime = function(t: number)
			now = t
		end,
		counted = counted,
	}
end

local function send(r: Rig, player: any, payload: any): boolean
	return (r.gateway:receive("RequestSettings", player.UserId, player, payload))
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

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("whitelist", function()
		it("lists AutoAim, AutoFire and CameraRotate, sorted, each since A2.1", function()
			expect(Settings.KEYS).toEqual({ "AutoAim", "AutoFire", "CameraRotate" })
			for _, key in Settings.KEYS do
				expect((Settings.SPECS :: any)[key].Since).toBe("A2.1")
			end
			expect(Settings.isKey("AutoFire")).toBe(true)
			expect(Settings.isKey("MusicVolume")).toBe(false)
			expect(Settings.isKey(5)).toBe(false)
			expect(table.isfrozen(Settings.KEYS)).toBe(true)
		end)
	end)

	describe("RequestSettings contract", function()
		it("is reliable, client→server, 5/s burst 10, since A2.1", function()
			local c = Contracts.get("RequestSettings")
			expect(c.Channel).toBe("R")
			expect(c.Direction).toBe("C2S")
			expect(c.Since).toBe("A2.1")
			expect(c.Rate).toEqual({ Sustained = 5, Burst = 10 })
		end)

		it("accepts a whitelisted key with a boolean value", function()
			local check = Contracts.get("RequestSettings").Payload
			for _, key in Settings.KEYS do
				expect((check({ Key = key, Value = true }))).toBe(true)
				expect((check({ Key = key, Value = false }))).toBe(true)
			end
		end)

		it("rejects unknown keys, wrong value types, missing or extra fields and non-tables", function()
			local check = Contracts.get("RequestSettings").Payload
			expect((check({ Key = "MusicVolume", Value = true }))).toBe(false)
			expect((check({ Key = "autofire", Value = true }))).toBe(false)
			expect((check({ Key = "AutoFire", Value = 1 }))).toBe(false)
			expect((check({ Key = "AutoFire", Value = "true" }))).toBe(false)
			expect((check({ Key = "AutoFire" }))).toBe(false)
			expect((check({ Value = true }))).toBe(false)
			expect((check({ Key = "AutoFire", Value = true, Extra = 1 }))).toBe(false)
			expect((check({ "AutoFire", true } :: { any }))).toBe(false)
			expect((check("AutoFire"))).toBe(false)
			expect((check(nil))).toBe(false)
		end)
	end)

	describe("SettingsService through the Gateway", function()
		it("registers the RequestSettings handler, so phase 8 exposes it", function()
			local r = rig()
			expect(r.gateway.exposed).toBe(true)
			expect(r.gateway.folder and r.gateway.folder:FindFirstChild("RequestSettings") ~= nil).toBe(true)
		end)

		it("stores accepted values per player; unset keys read nil", function()
			local r = rig()
			expect(send(r, PLAYER_A, { Key = "AutoFire", Value = false })).toBe(true)
			expect(send(r, PLAYER_A, { Key = "CameraRotate", Value = true })).toBe(true)
			expect(send(r, PLAYER_B, { Key = "AutoFire", Value = true })).toBe(true)
			expect(r.service:get(101, "AutoFire")).toBe(false)
			expect(r.service:get(101, "CameraRotate")).toBe(true)
			expect(r.service:get(101, "AutoAim")).toBeNil()
			expect(r.service:get(202, "AutoFire")).toBe(true)
			expect(r.service:all(101)).toEqual({ AutoFire = false, CameraRotate = true })
			expect(r.service:all(999)).toEqual({})
		end)

		it("the last value wins", function()
			local r = rig()
			send(r, PLAYER_A, { Key = "AutoAim", Value = false })
			r.setTime(1)
			send(r, PLAYER_A, { Key = "AutoAim", Value = true })
			expect(r.service:get(101, "AutoAim")).toBe(true)
		end)

		it("never stores a rejected payload", function()
			local r = rig()
			expect(send(r, PLAYER_A, { Key = "MusicVolume", Value = true })).toBe(false)
			expect(send(r, PLAYER_A, { Key = "AutoFire", Value = 0 })).toBe(false)
			expect(r.service:all(101)).toEqual({})
			expect(countOf(r.counted, "Net.Rejected.payload")).toBe(2)
		end)

		it("drops the 11th request of a burst and accepts again after a refill", function()
			local r = rig()
			for i = 1, 10 do
				expect(send(r, PLAYER_A, { Key = "AutoFire", Value = i % 2 == 0 })).toBe(true)
			end
			expect(send(r, PLAYER_A, { Key = "AutoFire", Value = true })).toBe(false)
			expect(r.service:get(101, "AutoFire")).toBe(true) -- the 10th (even) value
			expect(countOf(r.counted, "RateLimited")).toBe(1)
			r.setTime(0.2) -- 5/s refills one token per 0.2 s
			expect(send(r, PLAYER_A, { Key = "AutoFire", Value = false })).toBe(true)
			expect(r.service:get(101, "AutoFire")).toBe(false)
		end)

		it("a client sending one setting per 0.25 s (InputController's pace) is never dropped", function()
			local r = rig()
			local accepted = 0
			for i = 0, 199 do -- 50 s at 4/s
				r.setTime(i * 0.25)
				if send(r, PLAYER_A, { Key = Settings.KEYS[i % 3 + 1], Value = i % 2 == 0 }) then
					accepted += 1
				end
			end
			expect(accepted).toBe(200)
			expect(countOf(r.counted, "RateLimited")).toBe(0)
			expect(r.gateway:isFlagged(101)).toBe(false)
		end)

		it("forget clears a player's values", function()
			local r = rig()
			send(r, PLAYER_A, { Key = "AutoFire", Value = true })
			r.service:forget(101)
			expect(r.service:get(101, "AutoFire")).toBeNil()
			expect(r.service:all(101)).toEqual({})
		end)
	end)
end
