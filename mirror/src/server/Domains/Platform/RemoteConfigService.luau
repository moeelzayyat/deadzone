--!strict
-- Platform/RemoteConfigService (architecture §5.1, §20): tunables with defaults from Shared/Config/Tunables and the remote
-- config document, read from the `Config` DataStore (key `Current`) at boot and polled every 5 min:
--   { Flags = { [flag]: value }, Tunables = { [key]: value } }   -- both sections optional
-- The Flags section goes to FeatureFlagService:apply(). Tunables follow the same rules: a listed key takes the value,
-- an unlisted key returns to its default, and a value of the wrong type, out of bounds or for an unknown key is
-- reported and ignored. A failed read (DataStore down, no Studio API access) is reported and keeps the current values,
-- so the server always runs on defaults at worst.
--   get(key)     current tunable value; an unknown key throws
--   refresh()    one fetch + apply (Start runs it once, then the poll loop)
-- Init resolves FeatureFlagService; Start does the boot read before any later phase starts, so Start code elsewhere sees
-- remote values. Writing the document is an admin task (LiveOps tools, later); this service only reads.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Schema = require(ReplicatedStorage.Shared.Config.Schema)
local Tunables = require(ReplicatedStorage.Shared.Config.Tunables)
local Lifecycle = require(script.Parent.Parent.Parent.Lifecycle)

type Value = Schema.Value
type Entry = Schema.Entry

export type Reporter = (kind: string, message: string) -> ()
export type Fetch = () -> unknown -- returns the document (nil when absent); may yield; errors are caught

-- The part of FeatureFlagService this service uses (tests pass a fake).
export type FlagSink = { apply: (self: any, overrides: unknown) -> { string } }

export type Options = {
	specs: { [string]: Entry }?, -- default Config/Tunables
	fetch: Fetch?, -- default: Config DataStore, key Current
	flags: FlagSink?, -- default: FeatureFlagService, resolved in Init
	interval: number?, -- poll seconds; default 300
}

export type RefreshResult = { ok: boolean, reason: string?, tunables: { string }, flags: { string } }

export type RemoteConfigService = {
	Name: string,
	Init: (self: RemoteConfigService) -> (),
	Start: (self: RemoteConfigService) -> (),
	get: (self: RemoteConfigService, key: string) -> Value,
	all: (self: RemoteConfigService) -> { [string]: Value },
	refresh: (self: RemoteConfigService) -> RefreshResult,
	setReporter: (self: RemoteConfigService, reporter: Reporter) -> (),
	new: (options: Options?) -> RemoteConfigService,
}

local STORE_NAME = "Config"
local STORE_KEY = "Current"
local POLL_SECONDS = 300

local function readStore(): unknown
	return DataStoreService:GetDataStore(STORE_NAME):GetAsync(STORE_KEY)
end

local function new(options: Options?): RemoteConfigService
	local specs: { [string]: Entry } = if options and options.specs then options.specs else Tunables
	local fetch: Fetch = if options and options.fetch then options.fetch else readStore
	local flags: FlagSink? = options and options.flags
	local interval: number = if options and options.interval then options.interval else POLL_SECONDS

	local values: { [string]: Value } = {}
	for key, entry in specs do
		values[key] = entry.Default
	end
	local reporter: Reporter = function(kind: string, message: string)
		warn(`[Config] {kind}: {message}`)
	end

	local function applyTunables(section: unknown): { string }
		if section ~= nil and typeof(section) ~= "table" then
			reporter("override", `Tunables section must be a table, got {typeof(section)}; keeping current values`)
			return {}
		end
		local wanted: { [string]: Value } = {}
		for key, value in (section or {}) :: { [unknown]: unknown } do
			local entry = if typeof(key) == "string" then specs[key :: string] else nil
			if entry == nil then
				reporter("override", `unknown tunable {tostring(key)} ignored`)
				continue
			end
			local ok, reason = Schema.check(entry :: Entry, value)
			if not ok then
				reporter("override", `{key}: {reason}; keeping the default`)
				continue
			end
			wanted[key :: string] = value :: Value
		end
		local changed: { string } = {}
		for key, entry in specs do
			local target = if wanted[key] ~= nil then wanted[key] else entry.Default
			if values[key] ~= target then
				values[key] = target
				table.insert(changed, key)
			end
		end
		table.sort(changed)
		return changed
	end

	local service = {} :: RemoteConfigService
	service.Name = "RemoteConfigService"
	service.new = new

	function service.Init(_: RemoteConfigService)
		if flags == nil then
			flags = Lifecycle.get("FeatureFlagService") :: any
		end
	end

	function service.refresh(_: RemoteConfigService): RefreshResult
		local ok, document = pcall(fetch)
		if not ok then
			reporter("fetch", `{STORE_NAME}/{STORE_KEY} read failed: {tostring(document)}; keeping current values`)
			return { ok = false, reason = "fetch", tunables = {}, flags = {} }
		end
		if document ~= nil and typeof(document) ~= "table" then
			reporter("document", `{STORE_NAME}/{STORE_KEY} must be a table, got {typeof(document)}; keeping current values`)
			return { ok = false, reason = "document", tunables = {}, flags = {} }
		end
		local doc = (document or {}) :: { [unknown]: unknown }
		for key in doc do
			if key ~= "Flags" and key ~= "Tunables" then
				reporter("document", `unknown section {tostring(key)} ignored`)
			end
		end
		local changedTunables = applyTunables(doc.Tunables)
		local changedFlags = if flags then (flags :: FlagSink):apply(doc.Flags) else {}
		return { ok = true, reason = nil, tunables = changedTunables, flags = changedFlags }
	end

	function service.Start(self: RemoteConfigService)
		self:refresh()
		task.spawn(function()
			while true do
				task.wait(interval)
				self:refresh()
			end
		end)
	end

	function service.get(_: RemoteConfigService, key: string): Value
		local value = values[key]
		if value == nil then
			error(`[Config] unknown tunable {tostring(key)}; declare it in Shared/Config/Tunables`, 0)
		end
		return value
	end

	function service.all(_: RemoteConfigService): { [string]: Value }
		return table.clone(values)
	end

	function service.setReporter(_: RemoteConfigService, fn: Reporter)
		reporter = fn
	end

	return service
end

return new()
