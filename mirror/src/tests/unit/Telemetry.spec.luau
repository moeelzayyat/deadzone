--!strict
-- Telemetry wrappers (A1.8, architecture §5.1, D-017): MetricsService checks its arguments and forwards to the
-- AnalyticsService sink, keeps server counters and counts boot events from the bus; ErrorReportService prints one
-- structured line per report, stays quiet on repeats inside its window and keeps a bounded history.
-- Private instances (`.new`) with a fake sink, output and clock; the Server folder is cloned so the modules load fresh.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TestRunner = require(script.Parent.Parent.TestRunner)
local EventBus = require(ReplicatedStorage.Shared.Events.EventBus)

type MetricsModule = typeof(require(ServerScriptService.Server.Domains.Telemetry.MetricsService))
type ErrorsModule = typeof(require(ServerScriptService.Server.Domains.Telemetry.ErrorReportService))

local server = ServerScriptService.Server:Clone()
local MetricsService: MetricsModule = (require :: any)((server :: any).Domains.Telemetry.MetricsService)
local ErrorReportService: ErrorsModule = (require :: any)((server :: any).Domains.Telemetry.ErrorReportService)

local PLAYER: Player = newproxy() :: any -- stands in for a Player; the wrapper passes it through untouched

local function fakeSink(calls: { { any } }): any
	return {
		funnel = function(...: any)
			table.insert(calls, { "funnel", ... })
		end,
		economy = function(...: any)
			table.insert(calls, { "economy", ... })
		end,
		custom = function(...: any)
			table.insert(calls, { "custom", ... })
		end,
	}
end

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("MetricsService", function()
		local function metrics(): (MetricsModule, { { any } })
			local calls: { { any } } = {}
			return MetricsService.new({ sink = fakeSink(calls), bind = false }), calls
		end

		it("counts server counters", function()
			local m = metrics()
			m:increment("RateLimited")
			m:increment("RateLimited")
			m:increment("Net.Rejected.payload", 3)
			expect(m:counter("RateLimited")).toBe(2)
			expect(m:counter("Never")).toBe(0)
			local snapshot = m:counters()
			snapshot.RateLimited = 99
			expect(m:counter("RateLimited")).toBe(2)
			expect(function()
				m:increment("")
			end).toThrow("[Metrics] counter name")
			expect(function()
				m:increment("X", 0 / 0)
			end).toThrow("finite")
		end)

		it("forwards funnel, economy and custom events with their arguments", function()
			local m, calls = metrics()
			m:funnel(PLAYER, "Onboarding", 2, "FirstKill", "session-1")
			m:economy(PLAYER, "Source", "Gold", 50, 150, "Gameplay", "MissionReward")
			m:custom(PLAYER, "RunAgain", 1)
			m:custom(PLAYER, "HubEntered")
			expect(calls).toEqual({
				{ "funnel" :: any, PLAYER, "Onboarding", "session-1", 2, "FirstKill" },
				{ "economy" :: any, PLAYER, "Source", "Gold", 50, 150, "Gameplay", "MissionReward" },
				{ "custom" :: any, PLAYER, "RunAgain", 1 },
				{ "custom" :: any, PLAYER, "HubEntered" },
			})
		end)

		it("rejects bad arguments before they leave the server", function()
			local m, calls = metrics()
			local bad: { () -> () } = {
				function()
					m:funnel(PLAYER, "Onboarding", 0)
				end,
				function()
					m:funnel(PLAYER, "Onboarding", 1.5)
				end,
				function()
					m:funnel(PLAYER, string.rep("x", 51), 1)
				end,
				function()
					m:economy(PLAYER, "Gift" :: any, "Gold", 1, 1, "Gameplay")
				end,
				function()
					m:economy(PLAYER, "Sink", "Robux", 1, 1, "Shop")
				end,
				function()
					m:economy(PLAYER, "Sink", "Serum", 0, 1, "Shop")
				end,
				function()
					m:economy(PLAYER, "Sink", "Serum", 5, -1, "Shop")
				end,
				function()
					m:custom(PLAYER, "")
				end,
				function()
					m:custom(PLAYER, "Vote", math.huge)
				end,
			}
			for _, call in bad do
				expect(call).toThrow("[Metrics]")
			end
			expect(#calls).toBe(0)
		end)

		it("counts BootCompleted and DefinitionsValidated from the bus after Start", function()
			local bus = EventBus.new()
			local m = MetricsService.new({ sink = fakeSink({}), bus = bus })
			m:Start()
			bus:publisher("Bootstrap"):publish("BootCompleted", { Phases = 9, Services = { "Platform/X" } })
			bus:publisher("Definitions"):publish("DefinitionsValidated", { Count = 19 })
			expect(m:counter("BootCompleted")).toBe(1)
			expect(m:counter("DefinitionsValidated")).toBe(19)
		end)
	end)

	describe("ErrorReportService", function()
		type Rig = { errors: ErrorsModule, lines: { string }, setTime: (number) -> () }

		local function rig(keep: number?): Rig
			local lines: { string } = {}
			local now = 0
			local errors = ErrorReportService.new({
				output = function(line: string)
					table.insert(lines, line)
				end,
				clock = function(): number
					return now
				end,
				keep = keep,
				bind = false,
			})
			return {
				errors = errors,
				lines = lines,
				setTime = function(t: number)
					now = t
				end,
			}
		end

		it("prints one structured line with sorted context", function()
			local r = rig()
			local context: { [string]: string | number | boolean } = { userId = 7, remote = "RequestPing" }
			expect(r.errors:report("net.handler", "RequestPing: boom", context)).toBe(true)
			r.errors:report("config.fetch", "read failed")
			expect(r.lines).toEqual({
				"[Error] net.handler: RequestPing: boom · remote=RequestPing userId=7",
				"[Error] config.fetch: read failed",
			})
		end)

		it("stays quiet on the same report inside 60 s, but counts it", function()
			local r = rig()
			r.errors:report("events.handler", "x")
			r.setTime(30)
			expect(r.errors:report("events.handler", "x")).toBe(false)
			expect(r.errors:report("events.handler", "y")).toBe(true)
			r.setTime(61)
			expect(r.errors:report("events.handler", "x")).toBe(true)
			expect(#r.lines).toBe(3)
			expect(r.errors:counts()).toEqual({ ["events.handler"] = 4 })
			expect(r.errors:recent()[1].repeats).toBe(1)
		end)

		it("keeps the last N reports and clips long messages", function()
			local r = rig(3)
			for i = 1, 5 do
				r.errors:report("k", `message {i}`)
			end
			local recent = r.errors:recent()
			expect(#recent).toBe(3)
			expect(recent[1].message).toBe("message 3")
			r.errors:report("k", "message 1") -- dropped from history, so it prints again
			expect(#r.lines).toBe(6)
			r.errors:report("long", string.rep("x", 600))
			expect(#r.errors:recent()[3].message).toBe(500 + #"…")
		end)

		it("survives a bad kind or message", function()
			local r = rig()
			r.errors:report("" :: any, 42 :: any)
			expect(r.lines[1]).toBe("[Error] unknown: 42")
		end)
	end)
end
