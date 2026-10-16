--!strict
-- Telemetry/MetricsService (architecture §5.1, D-017): the wrapper around Roblox AnalyticsService, plus server counters.
--   increment(name, amount?)      server-local counter (RateLimited, SessionFlagged, Net.Rejected.*, BootCompleted, ...);
--                                 counters() returns a copy. Which counters reach the dashboard is decided in A3.9.
--   funnel(player, funnelName, step, stepName?, sessionId?)          → AnalyticsService:LogFunnelStepEvent
--   economy(player, flow, currency, amount, endingBalance, transactionType, itemSku?) → LogEconomyEvent
--   custom(player, eventName, value?)                                → LogCustomEvent
-- Arguments are checked before they leave the server (names 1–50 bytes, finite numbers, a §6.1 currency, flow Source or
-- Sink); a bad call is a bug and throws "[Metrics] ...". The Roblox calls go through a sink that tests replace.
-- In Init it becomes Server/Gateway's counter; in Start it counts BootCompleted and DefinitionsValidated from the bus.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Common = require(ReplicatedStorage.Shared.Types.Common)
local EventBus = require(ReplicatedStorage.Shared.Events.EventBus)
local Gateway = require(script.Parent.Parent.Parent.Gateway)

export type Flow = "Source" | "Sink"

export type Sink = {
	funnel: (player: Player, funnelName: string, sessionId: string?, step: number, stepName: string?) -> (),
	economy: (
		player: Player,
		flow: Flow,
		currency: string,
		amount: number,
		endingBalance: number,
		transactionType: string,
		itemSku: string?
	) -> (),
	custom: (player: Player, eventName: string, value: number?) -> (),
}

export type Options = {
	sink: Sink?, -- default: Roblox AnalyticsService
	bind: boolean?, -- default true for the live service: Gateway counter and bus subscriptions
	bus: EventBus.Bus?, -- default EventBus.server()
}

export type MetricsService = {
	Name: string,
	Init: (self: MetricsService) -> (),
	Start: (self: MetricsService) -> (),
	increment: (self: MetricsService, name: string, amount: number?) -> (),
	counter: (self: MetricsService, name: string) -> number,
	counters: (self: MetricsService) -> { [string]: number },
	funnel: (self: MetricsService, player: Player, funnelName: string, step: number, stepName: string?, sessionId: string?) -> (),
	economy: (
		self: MetricsService,
		player: Player,
		flow: Flow,
		currency: string,
		amount: number,
		endingBalance: number,
		transactionType: string,
		itemSku: string?
	) -> (),
	custom: (self: MetricsService, player: Player, eventName: string, value: number?) -> (),
	new: (options: Options?) -> MetricsService,
}

local MAX_NAME = 50

local function fail(message: string): never
	error("[Metrics] " .. message, 0)
end

local function finite(x: unknown): boolean
	return typeof(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

local function checkName(label: string, s: unknown)
	if typeof(s) ~= "string" or #s == 0 or #s > MAX_NAME then
		fail(`{label} must be a string of 1–{MAX_NAME} bytes, got {tostring(s)}`)
	end
end

local function analyticsSink(): Sink
	local AnalyticsService = game:GetService("AnalyticsService")
	return {
		funnel = function(player: Player, funnelName: string, sessionId: string?, step: number, stepName: string?)
			AnalyticsService:LogFunnelStepEvent(player, funnelName, sessionId, step, stepName)
		end,
		economy = function(
			player: Player,
			flow: Flow,
			currency: string,
			amount: number,
			endingBalance: number,
			transactionType: string,
			itemSku: string?
		)
			local flowType = if flow == "Source"
				then Enum.AnalyticsEconomyFlowType.Source
				else Enum.AnalyticsEconomyFlowType.Sink
			AnalyticsService:LogEconomyEvent(player, flowType, currency, amount, endingBalance, transactionType, itemSku)
		end,
		custom = function(player: Player, eventName: string, value: number?)
			AnalyticsService:LogCustomEvent(player, eventName, value)
		end,
	}
end

local function new(options: Options?): MetricsService
	local sink: Sink = if options and options.sink then options.sink else analyticsSink()
	local bind = if options and options.bind ~= nil then options.bind else true
	local injectedBus: EventBus.Bus? = options and options.bus

	local counts: { [string]: number } = {}

	local service = {} :: MetricsService
	service.Name = "MetricsService"
	service.new = new

	function service.increment(_: MetricsService, name: string, amount: number?)
		if typeof(name) ~= "string" or name == "" then
			fail(`counter name must be a non-empty string, got {tostring(name)}`)
		end
		local by = if amount == nil then 1 else amount
		if not finite(by) then
			fail(`{name}: amount must be finite, got {tostring(amount)}`)
		end
		counts[name] = (counts[name] or 0) + by
	end

	function service.counter(_: MetricsService, name: string): number
		return counts[name] or 0
	end

	function service.counters(_: MetricsService): { [string]: number }
		return table.clone(counts)
	end

	function service.funnel(_: MetricsService, player: Player, funnelName: string, step: number, stepName: string?, sessionId: string?)
		checkName("funnelName", funnelName)
		if not finite(step) or step % 1 ~= 0 or step < 1 then
			fail(`{funnelName}: step must be a whole number ≥ 1, got {tostring(step)}`)
		end
		if stepName ~= nil then
			checkName("stepName", stepName)
		end
		if sessionId ~= nil then
			checkName("sessionId", sessionId)
		end
		sink.funnel(player, funnelName, sessionId, step, stepName)
	end

	function service.economy(
		_: MetricsService,
		player: Player,
		flow: Flow,
		currency: string,
		amount: number,
		endingBalance: number,
		transactionType: string,
		itemSku: string?
	)
		if flow ~= "Source" and flow ~= "Sink" then
			fail(`flow must be Source or Sink, got {tostring(flow)}`)
		end
		if typeof(currency) ~= "string" or table.find(Common.CURRENCIES, currency) == nil then
			fail(`currency must be one of {table.concat(Common.CURRENCIES, ", ")}, got {tostring(currency)}`)
		end
		if not finite(amount) or amount <= 0 then
			fail(`{currency}: amount must be a finite number > 0, got {tostring(amount)}`)
		end
		if not finite(endingBalance) or endingBalance < 0 then
			fail(`{currency}: endingBalance must be a finite number ≥ 0, got {tostring(endingBalance)}`)
		end
		checkName("transactionType", transactionType)
		if itemSku ~= nil then
			checkName("itemSku", itemSku)
		end
		sink.economy(player, flow, currency, amount, endingBalance, transactionType, itemSku)
	end

	function service.custom(_: MetricsService, player: Player, eventName: string, value: number?)
		checkName("eventName", eventName)
		if value ~= nil and not finite(value) then
			fail(`{eventName}: value must be finite, got {tostring(value)}`)
		end
		sink.custom(player, eventName, value)
	end

	function service.Init(_: MetricsService)
		if bind then
			Gateway.server():setCounter(function(name: string, amount: number)
				service:increment(name, amount)
			end)
		end
	end

	function service.Start(_: MetricsService)
		if not bind then
			return
		end
		local bus = injectedBus or EventBus.server()
		bus:subscribe("BootCompleted", function()
			service:increment("BootCompleted")
		end)
		bus:subscribe("DefinitionsValidated", function(payload: { Count: number })
			service:increment("DefinitionsValidated", payload.Count)
		end)
	end

	return service
end

return new()
