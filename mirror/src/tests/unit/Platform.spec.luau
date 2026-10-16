--!strict
-- Platform wrappers (A1.8, architecture §5.1, §20): Config/Schema, FeatureFlagService and RemoteConfigService.
-- Defaults come from Shared/Config; overrides are validated and applied as a set; bad overrides are reported and ignored;
-- flag changes publish FeatureFlagChanged and push Client flags after phase 8; a failed config read keeps current values.
-- Private instances (`.new`) with fakes for the DataStore read, the gateway and the bus; the Server folder is cloned so
-- the modules load fresh.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TestRunner = require(script.Parent.Parent.TestRunner)
local EventBus = require(ReplicatedStorage.Shared.Events.EventBus)

type FlagsModule = typeof(require(ServerScriptService.Server.Domains.Platform.FeatureFlagService))
type ConfigModule = typeof(require(ServerScriptService.Server.Domains.Platform.RemoteConfigService))
type SchemaModule = typeof(require(ReplicatedStorage.Shared.Config.Schema))

local server = ServerScriptService.Server:Clone()
local FeatureFlagService: FlagsModule = (require :: any)((server :: any).Domains.Platform.FeatureFlagService)
local RemoteConfigService: ConfigModule = (require :: any)((server :: any).Domains.Platform.RemoteConfigService)
local shared = ReplicatedStorage.Shared:Clone()
local Schema: SchemaModule = (require :: any)((shared :: any).Config.Schema)

local FLAG_SPECS: any = {
	Bool = { Default = false, Client = true, Description = "client flag", Since = "A1.8" },
	Num = { Default = 1, Min = 0, Max = 10, Description = "server number", Since = "A1.8" },
	Mode = { Default = "A", Options = { "A", "B" }, Description = "server choice", Since = "A1.8" },
}

local TUNABLE_SPECS: any = {
	Speed = { Default = 1, Min = 0, Max = 5, Description = "tunable", Since = "A1.8" },
	Count = { Default = 3, Min = 1, Max = 9, Integer = true, Description = "tunable", Since = "A1.8" },
}

type Fake = {
	calls: { { any } },
	expose: () -> (),
	onExposed: (self: any, callback: () -> ()) -> (),
	fire: (self: any, name: string, player: Player, payload: any) -> (),
	fireAll: (self: any, name: string, payload: any) -> (),
}

local function fakeGateway(): Fake
	local callbacks: { () -> () } = {}
	local fake: Fake
	fake = {
		calls = {},
		expose = function()
			for _, callback in callbacks do
				callback()
			end
		end,
		onExposed = function(_self: any, callback: () -> ())
			table.insert(callbacks, callback)
		end,
		fire = function(_self: any, name: string, _player: Player, payload: any)
			table.insert(fake.calls, { "fire", name, payload })
		end,
		fireAll = function(_self: any, name: string, payload: any)
			table.insert(fake.calls, { "fireAll", name, payload })
		end,
	}
	return fake
end

type FlagRig = { flags: FlagsModule, gateway: Fake, events: { any }, reports: { string } }

local function flagRig(): FlagRig
	local gateway = fakeGateway()
	local bus = EventBus.new()
	local events: { any } = {}
	bus:subscribe("FeatureFlagChanged", function(payload: any)
		table.insert(events, { payload.Flag, payload.Value })
	end)
	local flags = FeatureFlagService.new({ specs = FLAG_SPECS, gateway = gateway :: any, bus = bus })
	local reports: { string } = {}
	flags:setReporter(function(kind: string, message: string)
		table.insert(reports, `{kind}: {message}`)
	end)
	return { flags = flags, gateway = gateway, events = events, reports = reports }
end

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Config/Schema", function()
		it("the shipped Flags and Tunables are valid and frozen", function()
			local Flags = (require :: any)((shared :: any).Config.Flags)
			local Tunables = (require :: any)((shared :: any).Config.Tunables)
			expect(Flags.SampleFlag.Default).toBe(false)
			expect(Flags.SampleFlag.Client).toBe(true)
			expect(Tunables.SampleTunable.Default).toBe(1)
			expect(table.isfrozen(Flags)).toBe(true)
			expect(table.isfrozen(Tunables.SampleTunable)).toBe(true)
		end)

		it("check enforces type, bounds, integer and options", function()
			local num: any = { Default = 1, Min = 0, Max = 5, Integer = true, Description = "d", Since = "A1.8" }
			expect((Schema.check(num, 5))).toBe(true)
			expect((Schema.check(num, 6))).toBe(false)
			expect((Schema.check(num, 1.5))).toBe(false)
			expect((Schema.check(num, 0 / 0))).toBe(false)
			expect((Schema.check(num, "1"))).toBe(false)
			local choice: any = { Default = "A", Options = { "A", "B" }, Description = "d", Since = "A1.8" }
			expect((Schema.check(choice, "B"))).toBe(true)
			expect((Schema.check(choice, "C"))).toBe(false)
			expect((Schema.check(choice, string.rep("A", 201)))).toBe(false)
		end)

		it("problems lists every malformed entry; build throws them in one error", function()
			local bad: any = {
				lowercase = { Default = 1, Description = "d", Since = "A1.8" },
				OutOfBounds = { Default = 9, Max = 5, Description = "d", Since = "A1.8" },
				ClientTunable = { Default = true, Client = true, Description = "d", Since = "A1.8" },
				OptionsOnNumber = { Default = 1, Options = { "x" }, Description = "d", Since = "A1.8" },
				NoDescription = { Default = 1, Since = "A1.8" },
				BadSince = { Default = 1, Description = "d", Since = "later" },
				Typo = { Default = 1, Description = "d", Since = "A1.8", Maxx = 3 },
				TableDefault = { Default = {}, Description = "d", Since = "A1.8" },
			}
			expect(#Schema.problems(bad, false)).toBe(8)
			expect(#Schema.problems({ Ok = { Default = true, Client = true, Description = "d", Since = "A1.8" } } :: any, true)).toBe(0)
			expect(function()
				Schema.build("Test", bad, false)
			end).toThrow("[Config] 8 problems in Test")
		end)
	end)

	describe("FeatureFlagService", function()
		it("serves Config/Flags defaults", function()
			local flags = FeatureFlagService.new({ gateway = fakeGateway() :: any, bus = EventBus.new() })
			expect(flags:get("SampleFlag")).toBe(false)
			expect(flags:clientFlags()).toEqual({ InputTestPanel = true, SampleFlag = false })
			expect(function()
				flags:get("NoSuchFlag")
			end).toThrow("unknown flag NoSuchFlag")
		end)

		it("applies overrides as a set: listed flags change, unlisted ones return to default", function()
			local r = flagRig()
			expect(r.flags:apply({ Bool = true, Num = 7 })).toEqual({ "Bool", "Num" })
			expect(r.flags:get("Bool")).toBe(true)
			expect(r.flags:get("Num")).toBe(7)
			expect(r.flags:apply({ Num = 7 })).toEqual({ "Bool" })
			expect(r.flags:get("Bool")).toBe(false)
			expect(r.flags:apply(nil)).toEqual({ "Num" })
			expect(r.flags:all()).toEqual({ Bool = false, Num = 1, Mode = "A" })
			expect(#r.reports).toBe(0)
		end)

		it("reports and ignores wrong types, out-of-bounds values and unknown flags", function()
			local r = flagRig()
			local changed = r.flags:apply({ Bool = "yes", Num = 11, Mode = "C", Ghost = true, [1] = true } :: any)
			expect(#changed).toBe(0)
			expect(r.flags:all()).toEqual({ Bool = false, Num = 1, Mode = "A" })
			expect(#r.reports).toBe(5)
			expect(r.flags:apply("everything on")).toEqual({})
			expect(r.reports[6]).toBe("override: Flags section must be a table, got string; keeping current values")
		end)

		it("publishes FeatureFlagChanged for each change", function()
			local r = flagRig()
			r.flags:apply({ Mode = "B", Num = 2 })
			r.flags:apply({ Mode = "B", Num = 2 })
			expect(r.events).toEqual({ { "Mode", "B" }, { "Num", 2 :: any } })
		end)

		it("pushes Client flags only after phase 8: all on exposure, then only the changed ones", function()
			local r = flagRig()
			-- fireAll pushes only; per-player "fire" calls exist only when players are present (play tests).
			local function pushes(): { any }
				local out: { any } = {}
				for _, call in r.gateway.calls do
					if call[1] == "fireAll" then
						table.insert(out, call)
					end
				end
				return out
			end
			r.flags:Start()
			r.flags:apply({ Bool = true })
			expect(#r.gateway.calls).toBe(0) -- not exposed yet
			r.gateway.expose()
			for _, call in r.gateway.calls do
				expect(call[3]).toEqual({ Bool = true }) -- initial push per player: every Client flag
			end
			r.flags:apply({ Num = 3 }) -- Bool returns to default (client), Num changes (server only)
			expect(pushes()).toEqual({ { "fireAll", "FlagsUpdate", { Bool = false } :: any } })
			r.flags:apply({ Bool = false, Num = 4 })
			expect(#pushes()).toBe(1) -- only a server flag changed
		end)
	end)

	describe("RemoteConfigService", function()
		type FlagSink = { applied: { any }, apply: (self: any, overrides: unknown) -> { string } }

		local function rig(fetch: () -> unknown): (ConfigModule, FlagSink, { string })
			local sink: FlagSink
			sink = {
				applied = {},
				apply = function(_self: any, overrides: unknown): { string }
					table.insert(sink.applied, overrides or "nil")
					return {}
				end,
			}
			local config = RemoteConfigService.new({ specs = TUNABLE_SPECS, fetch = fetch, flags = sink :: any, interval = 1e6 })
			local reports: { string } = {}
			config:setReporter(function(kind: string, message: string)
				table.insert(reports, `{kind}: {message}`)
			end)
			return config, sink, reports
		end

		it("serves Config/Tunables defaults", function()
			local config = RemoteConfigService.new({
				fetch = function(): unknown
					return nil
				end,
				flags = { apply = function(): { string }
					return {}
				end },
			})
			expect(config:get("SampleTunable")).toBe(1)
			expect(function()
				config:get("NoSuchKey")
			end).toThrow("unknown tunable NoSuchKey")
		end)

		it("applies the Tunables section and hands the Flags section to FeatureFlagService", function()
			local config, sink, reports = rig(function(): unknown
				return { Tunables = { Speed = 2.5 }, Flags = { Bool = true } }
			end)
			local result = config:refresh()
			expect(result.ok).toBe(true)
			expect(result.tunables).toEqual({ "Speed" })
			expect(config:get("Speed")).toBe(2.5)
			expect(config:get("Count")).toBe(3)
			expect(sink.applied).toEqual({ { Bool = true } })
			expect(#reports).toBe(0)
		end)

		it("an absent document means defaults", function()
			local doc: any = { Tunables = { Count = 9 } }
			local config, sink = rig(function(): unknown
				return doc
			end)
			config:refresh()
			expect(config:get("Count")).toBe(9)
			doc = nil
			expect(config:refresh().tunables).toEqual({ "Count" })
			expect(config:get("Count")).toBe(3)
			expect(sink.applied[2]).toBe("nil")
		end)

		it("a failed read or a malformed document keeps the current values", function()
			local mode = "good"
			local config, sink, reports = rig(function(): unknown
				if mode == "error" then
					error("DataStore request was rejected", 0)
				elseif mode == "string" then
					return "oops"
				end
				return { Tunables = { Speed = 4 } }
			end)
			config:refresh()
			mode = "error"
			local failed = config:refresh()
			expect(failed.ok).toBe(false)
			expect(failed.reason).toBe("fetch")
			mode = "string"
			expect(config:refresh().reason).toBe("document")
			expect(config:get("Speed")).toBe(4)
			expect(#sink.applied).toBe(1)
			expect(reports[1]).toBe("fetch: Config/Current read failed: DataStore request was rejected; keeping current values")
			expect(#reports).toBe(2)
		end)

		it("reports and ignores bad tunables and unknown sections", function()
			local config, _, reports = rig(function(): unknown
				return { Tunables = { Speed = 6, Count = 2.5, Ghost = 1 }, Extra = {} }
			end)
			local result = config:refresh()
			expect(result.ok).toBe(true)
			expect(result.tunables).toEqual({})
			expect(config:all()).toEqual({ Speed = 1, Count = 3 })
			expect(#reports).toBe(4)
		end)

		it("Start reads once at boot before returning", function()
			local reads = 0
			local config = rig(function(): unknown
				reads += 1
				return { Tunables = { Speed = 3 } }
			end)
			config:Start()
			expect(reads).toBe(1)
			expect(config:get("Speed")).toBe(3)
		end)
	end)
end
