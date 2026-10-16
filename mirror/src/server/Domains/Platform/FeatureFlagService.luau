--!strict
-- Platform/FeatureFlagService (architecture §5.1, §20): feature flags with defaults from Shared/Config/Flags and overrides
-- from the `Flags` section of the `Config` DataStore, which RemoteConfigService fetches at boot and every 5 min and
-- hands over with apply().
--   get(name)       current value; an unknown flag throws (flags are declared in Config/Flags first)
--   apply(map)      sets the override set: listed flags take the value, unlisted ones return to their default. A value of
--                   the wrong type or out of bounds, or an unknown flag, is reported and ignored. Each change publishes
--                   FeatureFlagChanged (Platform) and, for Client flags, pushes FlagsUpdate to every client.
--   clientFlags()   the flags clients see; sent to each player after phase 8 and on join.
-- Read flags from Start on: Init runs before the boot fetch, so it sees defaults.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Schema = require(ReplicatedStorage.Shared.Config.Schema)
local Flags = require(ReplicatedStorage.Shared.Config.Flags)
local EventBus = require(ReplicatedStorage.Shared.Events.EventBus)
local Gateway = require(script.Parent.Parent.Parent.Gateway)

type Value = Schema.Value
type Entry = Schema.Entry

export type Reporter = (kind: string, message: string) -> ()

-- The part of Server/Gateway this service uses (tests pass a fake).
export type Pusher = {
	onExposed: (self: any, callback: () -> ()) -> (),
	fire: (self: any, name: string, player: Player, payload: any) -> (),
	fireAll: (self: any, name: string, payload: any) -> (),
}

export type Options = {
	specs: { [string]: Entry }?, -- default Config/Flags
	gateway: Pusher?, -- default Gateway.server()
	bus: EventBus.Bus?, -- default EventBus.server()
}

export type FeatureFlagService = {
	Name: string,
	Init: (self: FeatureFlagService) -> (),
	Start: (self: FeatureFlagService) -> (),
	get: (self: FeatureFlagService, name: string) -> Value,
	all: (self: FeatureFlagService) -> { [string]: Value },
	clientFlags: (self: FeatureFlagService) -> { [string]: Value },
	apply: (self: FeatureFlagService, overrides: unknown) -> { string },
	setReporter: (self: FeatureFlagService, reporter: Reporter) -> (),
	new: (options: Options?) -> FeatureFlagService,
}

local CLIENT_REMOTE = "FlagsUpdate"

local function new(options: Options?): FeatureFlagService
	local specs: { [string]: Entry } = if options and options.specs then options.specs else Flags
	local injectedGateway: Pusher? = options and options.gateway
	local injectedBus: EventBus.Bus? = options and options.bus

	local values: { [string]: Value } = {}
	for name, entry in specs do
		values[name] = entry.Default
	end
	local exposed = false
	local reporter: Reporter = function(kind: string, message: string)
		warn(`[Flags] {kind}: {message}`)
	end

	local function gateway(): Pusher
		return injectedGateway or Gateway.server()
	end

	local function clientFlags(): { [string]: Value }
		local out: { [string]: Value } = {}
		for name, entry in specs do
			if entry.Client then
				out[name] = values[name]
			end
		end
		return out
	end

	local service = {} :: FeatureFlagService
	service.Name = "FeatureFlagService"
	service.new = new

	function service.Init(_: FeatureFlagService) end

	function service.Start(_: FeatureFlagService)
		gateway():onExposed(function()
			exposed = true
			local initial = clientFlags()
			for _, player in Players:GetPlayers() do
				gateway():fire(CLIENT_REMOTE, player, initial)
			end
			Players.PlayerAdded:Connect(function(player: Player)
				gateway():fire(CLIENT_REMOTE, player, clientFlags())
			end)
		end)
	end

	function service.get(_: FeatureFlagService, name: string): Value
		local value = values[name]
		if value == nil then
			error(`[Flags] unknown flag {tostring(name)}; declare it in Shared/Config/Flags`, 0)
		end
		return value
	end

	function service.all(_: FeatureFlagService): { [string]: Value }
		return table.clone(values)
	end

	function service.clientFlags(_: FeatureFlagService): { [string]: Value }
		return clientFlags()
	end

	function service.apply(_: FeatureFlagService, overrides: unknown): { string }
		local wanted: { [string]: Value } = {}
		if overrides ~= nil and typeof(overrides) ~= "table" then
			reporter("override", `Flags section must be a table, got {typeof(overrides)}; keeping current values`)
			return {}
		end
		for name, value in (overrides or {}) :: { [unknown]: unknown } do
			local entry = if typeof(name) == "string" then specs[name :: string] else nil
			if entry == nil then
				reporter("override", `unknown flag {tostring(name)} ignored`)
				continue
			end
			local ok, reason = Schema.check(entry :: Entry, value)
			if not ok then
				reporter("override", `{name}: {reason}; keeping the default`)
				continue
			end
			wanted[name :: string] = value :: Value
		end
		local changed: { string } = {}
		for name, entry in specs do
			local target = if wanted[name] ~= nil then wanted[name] else entry.Default
			if values[name] ~= target then
				values[name] = target
				table.insert(changed, name)
			end
		end
		table.sort(changed)
		if #changed == 0 then
			return changed
		end
		local publisher = (injectedBus or EventBus.server()):publisher("Platform")
		local pushed: { [string]: Value } = {}
		local anyClient = false
		for _, name in changed do
			publisher:publish("FeatureFlagChanged", { Flag = name, Value = values[name] })
			if specs[name].Client then
				pushed[name] = values[name]
				anyClient = true
			end
		end
		if anyClient and exposed then
			gateway():fireAll(CLIENT_REMOTE, pushed)
		end
		return changed
	end

	function service.setReporter(_: FeatureFlagService, fn: Reporter)
		reporter = fn
	end

	return service
end

return new()
