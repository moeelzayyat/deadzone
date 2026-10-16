--!strict
-- Telemetry/ErrorReportService (architecture §5.1, §5.2 phase 1): structured error reports.
--   report(kind, message, context?)   one `[Error] <kind>: <message> · k=v ...` warning, which the Roblox error report
--                                     dashboard collects from live servers. The same kind + message within 60 s is
--                                     counted but not printed again. Counts per kind and the last 50 reports are kept
--                                     for admin tools and tests.
-- In Init it becomes the reporter of RemoteConfigService, FeatureFlagService and Server/Gateway (they warn until then);
-- in Start it takes the event bus error handler and counts uncaught server script errors (ScriptContext.Error) under
-- `script` without printing them twice.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")

local EventBus = require(ReplicatedStorage.Shared.Events.EventBus)
local Gateway = require(script.Parent.Parent.Parent.Gateway)
local Lifecycle = require(script.Parent.Parent.Parent.Lifecycle)

export type ContextValue = string | number | boolean
export type Report = { kind: string, message: string, context: { [string]: ContextValue }?, at: number, repeats: number }

export type Options = {
	output: ((line: string) -> ())?, -- default warn
	clock: (() -> number)?, -- default os.clock
	window: number?, -- seconds a repeat stays quiet; default 60
	keep: number?, -- reports kept; default 50
	bind: boolean?, -- default true for the live service: wire Platform, Gateway, bus, ScriptContext
}

export type ErrorReportService = {
	Name: string,
	Init: (self: ErrorReportService) -> (),
	Start: (self: ErrorReportService) -> (),
	report: (self: ErrorReportService, kind: string, message: string, context: { [string]: ContextValue }?) -> boolean,
	counts: (self: ErrorReportService) -> { [string]: number },
	recent: (self: ErrorReportService) -> { Report },
	new: (options: Options?) -> ErrorReportService,
}

type Reporting = { setReporter: (self: any, reporter: (kind: string, message: string) -> ()) -> () }

local MAX_MESSAGE = 500
local MAX_CONTEXT_VALUE = 200

local function clip(s: string, limit: number): string
	if #s > limit then
		return string.sub(s, 1, limit) .. "…"
	end
	return s
end

local function new(options: Options?): ErrorReportService
	local output: (line: string) -> () = if options and options.output then options.output else function(line: string)
		warn(line)
	end
	local clock: () -> number = if options and options.clock then options.clock else os.clock
	local window: number = if options and options.window then options.window else 60
	local keep: number = if options and options.keep then options.keep else 50
	local bind = if options and options.bind ~= nil then options.bind else true

	local counts: { [string]: number } = {}
	local recent: { Report } = {}
	local lastShown: { [string]: Report } = {} -- kind .. "\0" .. message -> the report that was printed

	local service = {} :: ErrorReportService
	service.Name = "ErrorReportService"
	service.new = new

	-- Returns true when the report was printed, false when it was a quiet repeat.
	function service.report(_: ErrorReportService, kind: string, message: string, context: { [string]: ContextValue }?): boolean
		local k = if typeof(kind) == "string" and kind ~= "" then kind else "unknown"
		local m = clip(if typeof(message) == "string" then message else tostring(message), MAX_MESSAGE)
		counts[k] = (counts[k] or 0) + 1
		local now = clock()
		local key = k .. "\0" .. m
		local previous = lastShown[key]
		if previous and now - previous.at < window then
			previous.repeats += 1
			return false
		end
		local entry: Report = { kind = k, message = m, context = context, at = now, repeats = 0 }
		lastShown[key] = entry
		table.insert(recent, entry)
		while #recent > keep do
			local dropped = table.remove(recent, 1) :: Report
			local droppedKey = dropped.kind .. "\0" .. dropped.message
			if lastShown[droppedKey] == dropped then
				lastShown[droppedKey] = nil
			end
		end
		local parts: { string } = {}
		if context then
			local names: { string } = {}
			for name in context do
				table.insert(names, name)
			end
			table.sort(names)
			for _, name in names do
				table.insert(parts, `{name}={clip(tostring(context[name]), MAX_CONTEXT_VALUE)}`)
			end
		end
		output(`[Error] {k}: {m}{if #parts > 0 then " · " .. table.concat(parts, " ") else ""}`)
		return true
	end

	function service.counts(_: ErrorReportService): { [string]: number }
		return table.clone(counts)
	end

	function service.recent(_: ErrorReportService): { Report }
		local out: { Report } = {}
		for i, entry in recent do
			out[i] = table.clone(entry)
		end
		return out
	end

	local function sink(prefix: string): (kind: string, message: string) -> ()
		return function(kind: string, message: string)
			service:report(`{prefix}.{kind}`, message)
		end
	end

	function service.Init(_: ErrorReportService)
		if not bind then
			return
		end
		for _, name in { "RemoteConfigService", "FeatureFlagService" } do
			local target = (Lifecycle.get(name) :: any) :: Reporting
			target:setReporter(sink(if name == "RemoteConfigService" then "config" else "flags"))
		end
		Gateway.server():setReporter(sink("net"))
	end

	function service.Start(_: ErrorReportService)
		if not bind then
			return
		end
		EventBus.server():setErrorHandler(function(kind: EventBus.ErrorKind, message: string)
			service:report(`events.{kind}`, message)
		end)
		ScriptContext.Error:Connect(function()
			counts.script = (counts.script or 0) + 1
		end)
	end

	return service
end

return new()
