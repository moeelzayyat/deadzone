--!strict
-- Lifecycle (A1.4): §5.2 phase order, the Init/Start contract and the order assertions.
-- Real-domain cases only plan and validate (no Init/Start runs on real services); contract cases use fake services.

local ServerScriptService = game:GetService("ServerScriptService")

local TestRunner = require(script.Parent.Parent.TestRunner)
local Lifecycle = require(ServerScriptService.Server.Lifecycle)

type Service = Lifecycle.Service
type Plan = Lifecycle.Plan

local Domains = ServerScriptService.Server.Domains

-- A fake service that appends "<Name>:Init" / "<Name>:Start" to log; init runs inside Init.
local function fake(name: string, log: { string }, init: (() -> ())?): Service
	return {
		Name = name,
		Init = function(_self: Service)
			table.insert(log, name .. ":Init")
			if init then
				init()
			end
		end,
		Start = function(_self: Service)
			table.insert(log, name .. ":Start")
		end,
	}
end

-- The nine §5.2 phases with no services, for hand-built cases.
local function emptyPlan(): Plan
	local plan: Plan = {}
	for _, spec in Lifecycle.PHASES do
		table.insert(plan, { index = spec.index, name = spec.name, entries = {} })
	end
	return plan
end

local function add(plan: Plan, phaseIndex: number, domain: string, service: Service)
	table.insert(plan[phaseIndex + 1].entries, { domain = domain, service = service })
end

local function ids(plan: Plan): { string }
	local out: { string } = {}
	for _, phase in plan do
		for _, entry in phase.entries do
			table.insert(out, `{entry.domain}/{entry.service.Name}`)
		end
	end
	return out
end

local function hasStart(log: { string }): boolean
	for _, line in log do
		if string.find(line, ":Start", 1, true) then
			return true
		end
	end
	return false
end

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("phase table", function()
		it("matches architecture §5.2", function()
			local rows: { string } = {}
			for _, spec in Lifecycle.PHASES do
				table.insert(rows, `{spec.index} {table.concat(spec.domains, ",")}`)
			end
			expect(rows).toEqual({
				"0 Platform",
				"1 Telemetry",
				"2 Data",
				"3 ",
				"4 Economy",
				"5 Progression",
				"6 Combat,Encounter",
				"7 Social,Facilities,LiveOps",
				"8 ",
			})
			expect(#Lifecycle.DOMAIN_ORDER).toBe(Lifecycle.DOMAIN_COUNT)
		end)
	end)

	describe("real domains", function()
		it("plans one placeholder service per domain in §5.2 order", function()
			local plan = Lifecycle.plan(Domains)
			expect(ids(plan)).toEqual({
				"Platform/RemoteConfigService",
				"Telemetry/ErrorReportService",
				"Data/MigrationService",
				"Economy/TransactionService",
				"Progression/ClassService",
				"Combat/CombatService",
				"Encounter/MissionSessionService",
				"Social/PartyService",
				"Facilities/ShopService",
				"LiveOps/SeasonService",
			})
			Lifecycle.validate(plan)
		end)

		it("asserts when two services' phases are swapped", function()
			local plan = Lifecycle.plan(Domains)
			local platform, economy = plan[1].entries[1], plan[5].entries[1]
			expect(platform.domain).toBe("Platform")
			expect(economy.domain).toBe("Economy")
			plan[1].entries[1], plan[5].entries[1] = economy, platform
			expect(function()
				Lifecycle.run(plan)
			end).toThrow("[Boot] order: Economy/TransactionService belongs to phase 4 (Economy) but is listed in phase 0")
		end)

		it("asserts when Combat and Encounter swap inside phase 6", function()
			local plan = Lifecycle.plan(Domains)
			local entries = plan[7].entries
			entries[1], entries[2] = entries[2], entries[1]
			expect(function()
				Lifecycle.validate(plan)
			end).toThrow("[Boot] order: Combat/CombatService boots after Encounter")
		end)

		it("asserts when two phases swap places", function()
			local plan = Lifecycle.plan(Domains)
			plan[1], plan[3] = plan[3], plan[1]
			expect(function()
				Lifecycle.validate(plan)
			end).toThrow("[Boot] order: plan position 1 is phase 2, expected phase 0")
		end)
	end)

	describe("Init/Start contract", function()
		it("runs every Init in phase order before any Start, and the network step last", function()
			local log: { string } = {}
			local plan = emptyPlan()
			add(plan, 0, "Platform", fake("FakeA", log))
			add(plan, 4, "Economy", fake("FakeB", log))
			add(plan, 7, "LiveOps", fake("FakeC", log))
			local report = Lifecycle.run(plan, {
				definitions = function(): string
					table.insert(log, "definitions")
					return "defs"
				end,
				network = function(): string
					table.insert(log, "network")
					return "net"
				end,
			})
			expect(log).toEqual({ "FakeA:Init", "definitions", "FakeB:Init", "FakeC:Init", "FakeA:Start", "FakeB:Start", "FakeC:Start", "network" })
			expect(report.order).toEqual({ "Platform/FakeA", "Economy/FakeB", "LiveOps/FakeC" })
			expect(report.phaseLines[4]).toBe("phase 3 Definitions: defs")
			expect(report.phaseLines[9]).toBe("phase 8 Network: net")
		end)

		it("resolves a dependency that booted in an earlier phase", function()
			local log: { string } = {}
			local plan = emptyPlan()
			local a = fake("FakeA", log)
			local resolved: Service? = nil
			add(plan, 0, "Platform", a)
			add(plan, 4, "Economy", fake("FakeB", log, function()
				resolved = Lifecycle.get("FakeA")
			end))
			Lifecycle.run(plan)
			expect(resolved).toBe(a)
		end)

		it("asserts when a dependency's phase is swapped behind its user, before any Start", function()
			local log: { string } = {}
			local plan = emptyPlan()
			add(plan, 0, "Platform", fake("FakeB", log, function()
				Lifecycle.get("FakeA")
			end))
			add(plan, 4, "Economy", fake("FakeA", log))
			expect(function()
				Lifecycle.run(plan)
			end).toThrow("[Boot] order: Platform/FakeB resolved Economy/FakeA during Init, but Economy/FakeA has not initialized")
			expect(log).toEqual({ "FakeB:Init" })
		end)

		it("stops the boot when an Init fails, before any Start", function()
			local log: { string } = {}
			local plan = emptyPlan()
			add(plan, 0, "Platform", fake("FakeA", log))
			add(plan, 7, "LiveOps", fake("FakeC", log, function()
				error("boom", 0)
			end))
			expect(function()
				Lifecycle.run(plan)
			end).toThrow("[Boot] LiveOps/FakeC:Init failed: boom")
			expect(hasStart(log)).toBe(false)
		end)

		it("rejects an Init that yields", function()
			local plan = emptyPlan()
			add(plan, 0, "Platform", fake("FakeA", {}, function()
				coroutine.yield()
			end))
			expect(function()
				Lifecycle.run(plan)
			end).toThrow("[Boot] Platform/FakeA:Init yielded")
		end)

		it("reports a failing Start with the service id", function()
			local plan = emptyPlan()
			local broken = fake("FakeA", {})
			broken.Start = function(_self: Service)
				error("no start", 0)
			end
			add(plan, 0, "Platform", broken)
			expect(function()
				Lifecycle.run(plan)
			end).toThrow("[Boot] Platform/FakeA:Start failed: no start")
		end)

		it("allows Lifecycle.get only during Init, and only for known services", function()
			expect(function()
				Lifecycle.get("FakeA")
			end).toThrow("called outside Init")
			local plan = emptyPlan()
			add(plan, 0, "Platform", fake("FakeA", {}, function()
				Lifecycle.get("Nope")
			end))
			expect(function()
				Lifecycle.run(plan)
			end).toThrow('resolved unknown service "Nope"')
		end)
	end)

	describe("service shape", function()
		it("rejects a missing Start, a duplicate name and a Roblox built-in name", function()
			local plan = emptyPlan()
			add(plan, 0, "Platform", ({ Name = "FakeA", Init = function() end } :: any) :: Service)
			expect(function()
				Lifecycle.validate(plan)
			end).toThrow("[Boot] Platform/FakeA.Start must be a function")

			plan = emptyPlan()
			add(plan, 0, "Platform", fake("FakeA", {}))
			add(plan, 1, "Telemetry", fake("FakeA", {}))
			expect(function()
				Lifecycle.validate(plan)
			end).toThrow('duplicate service name "FakeA" (Platform/FakeA and Telemetry/FakeA)')

			plan = emptyPlan()
			add(plan, 1, "Telemetry", fake("AnalyticsService", {}))
			expect(function()
				Lifecycle.validate(plan)
			end).toThrow('"AnalyticsService" is a Roblox built-in service name')
		end)

		it("rejects an unknown domain", function()
			local plan = emptyPlan()
			add(plan, 0, "Lobby", fake("FakeA", {}))
			expect(function()
				Lifecycle.validate(plan)
			end).toThrow('[Boot] unknown domain "Lobby"')
		end)
	end)
end
