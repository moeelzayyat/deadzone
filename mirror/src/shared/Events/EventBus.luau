--!strict
-- Events/EventBus (architecture §5.3, docs/EVENTS.md): the server-side typed event bus.
--   local bus = EventBus.server()                       -- the one shared bus (server only)
--   local publish = bus:publisher("Encounter")          -- one per publishing domain, created in Init or Start
--   publish:publish("EnemyKilled", { ... })             -- validated against Catalog, delivered as a frozen copy
--   local conn = bus:subscribe("EnemyKilled", function(p: Catalog.EnemyKilled) ... end)  -- subscribe in Start
--   conn:Disconnect()
-- Misuse is a publish of an unknown event, of an event from a domain that is not its catalog publisher, or of a payload
-- that fails the schema. Strict mode (Studio and tests) throws "[Events] ..." at the publisher; otherwise the bus reports
-- it to the error handler and drops the event, so a live server never delivers a bad payload.
-- Every handler runs in its own thread: a handler that errors is reported and does not reach the publisher or the other
-- handlers; a handler that yields does not block them. Handlers run in subscription order until their first yield.
-- Setup mistakes (unknown publisher identity, subscribing to an unknown event, a bad catalog) always throw.

local RunService = game:GetService("RunService")

local Catalog = require(script.Parent.Catalog)

export type ErrorKind = "unknown_event" | "domain" | "payload" | "handler"
export type ErrorHandler = (kind: ErrorKind, message: string) -> ()
export type Handler = (payload: any) -> ()

export type Options = {
	strict: boolean?, -- default true for EventBus.new; EventBus.server() uses RunService:IsStudio()
	catalog: Catalog.Catalog?, -- default Catalog.EVENTS
	onError: ErrorHandler?, -- default warn; Telemetry/ErrorReportService takes over with setErrorHandler
}

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Publisher = {
	Domain: Catalog.PublisherId,
	publish: (self: Publisher, name: Catalog.EventName, payload: unknown) -> (),
}

export type Bus = {
	strict: boolean,
	publisher: (self: Bus, domain: Catalog.PublisherId) -> Publisher,
	subscribe: (self: Bus, name: Catalog.EventName, handler: Handler) -> Connection,
	subscriberCount: (self: Bus, name: Catalog.EventName) -> number,
	setErrorHandler: (self: Bus, handler: ErrorHandler) -> (),
}

type Subscription = { handler: Handler, connection: Connection }

local EventBus = {}

local function defaultErrorHandler(kind: ErrorKind, message: string)
	warn(`[Events] {kind}: {message}`)
end

local function describe(value: unknown): string
	local t = typeof(value)
	if t == "string" then
		return `string "{value}"`
	elseif t == "number" or t == "boolean" then
		return `{t} {tostring(value)}`
	end
	return t
end

-- Returns nil when value matches fieldType, otherwise "<path>: expected ..., got ...".
local function check(fieldType: Catalog.FieldType, value: unknown, path: string): string?
	local kind = fieldType.kind
	local t = typeof(value)
	if kind == "string" then
		if t ~= "string" or value == "" then
			return `{path}: expected non-empty string, got {describe(value)}`
		end
	elseif kind == "number" or kind == "integer" then
		if t ~= "number" then
			return `{path}: expected {kind}, got {describe(value)}`
		end
		local n = value :: number
		if n ~= n or n == math.huge or n == -math.huge then
			return `{path}: expected finite {kind}, got {tostring(n)}`
		end
		if kind == "integer" and n ~= math.floor(n) then
			return `{path}: expected integer, got {tostring(n)}`
		end
	elseif kind == "boolean" then
		if t ~= "boolean" then
			return `{path}: expected boolean, got {describe(value)}`
		end
	elseif kind == "Vector3" then
		if t ~= "Vector3" then
			return `{path}: expected Vector3, got {describe(value)}`
		end
	elseif kind == "enum" then
		local values = fieldType.values :: { string }
		if t ~= "string" or table.find(values, value :: string) == nil then
			return `{path}: expected one of {table.concat(values, "|")}, got {describe(value)}`
		end
	elseif kind == "oneOf" then
		local names: { string } = {}
		for _, option in fieldType.options :: { Catalog.FieldType } do
			if check(option, value, path) == nil then
				return nil
			end
			table.insert(names, option.kind)
		end
		return `{path}: expected {table.concat(names, "|")}, got {describe(value)}`
	else
		if t ~= "table" then
			return `{path}: expected {kind}, got {describe(value)}`
		end
		local tbl = value :: { [unknown]: unknown }
		if getmetatable(tbl :: any) ~= nil then
			return `{path}: expected plain {kind}, got a table with a metatable`
		end
		if kind == "array" then
			local n = #tbl
			local count = 0
			for k in tbl do
				count += 1
				if typeof(k) ~= "number" or k < 1 or k > n or k ~= math.floor(k :: number) then
					return `{path}: expected array, got key {describe(k)}`
				end
			end
			if count ~= n then
				return `{path}: expected array, got a table with holes`
			end
			local of = fieldType.of :: Catalog.FieldType
			for i = 1, n do
				local err = check(of, tbl[i], `{path}[{i}]`)
				if err then
					return err
				end
			end
		elseif kind == "map" then
			local key = fieldType.key :: Catalog.FieldType
			local valueType = fieldType.value :: Catalog.FieldType
			for k, v in tbl do
				local err = check(key, k, `{path} key`) or check(valueType, v, `{path}[{tostring(k)}]`)
				if err then
					return err
				end
			end
		elseif kind == "record" then
			local fields = fieldType.fields :: Catalog.Fields
			for name, sub in fields do
				local err = check(sub, tbl[name], `{path}.{name}`)
				if err then
					return err
				end
			end
			for k in tbl do
				if typeof(k) ~= "string" or fields[k :: string] == nil then
					return `{path}: unexpected field {describe(k)}`
				end
			end
		end
	end
	return nil
end

-- Deep copy of a validated payload, frozen at every level so no consumer can change what another one sees.
local function frozenCopy(value: unknown): unknown
	if typeof(value) ~= "table" then
		return value
	end
	local out: { [unknown]: unknown } = {}
	for k, v in value :: { [unknown]: unknown } do
		out[k] = frozenCopy(v)
	end
	return table.freeze(out)
end

function EventBus.new(options: Options?): Bus
	local opts: Options = options or {}
	local strict = if opts.strict == nil then true else opts.strict :: boolean
	local catalog = opts.catalog or Catalog.EVENTS
	local problem = Catalog.check(catalog)
	if problem then
		error("[Events] catalog: " .. problem, 0)
	end
	local onError: ErrorHandler = opts.onError or defaultErrorHandler
	local subscriptions: { [string]: { Subscription } } = {}
	for name in catalog do
		subscriptions[name] = {}
	end

	local function report(kind: ErrorKind, message: string)
		local ok, err = pcall(function(): nil
			onError(kind, message)
			return nil
		end)
		if not ok then
			warn(`[Events] error handler failed ({tostring(err)}) while reporting {kind}: {message}`)
		end
	end

	local function deliver(name: string, handler: Handler, payload: unknown)
		local ok, err = xpcall(function(): nil
			handler(payload)
			return nil
		end, debug.traceback)
		if not ok then
			report("handler", `{name} handler failed: {tostring(err)}`)
		end
	end

	-- Strict: throw at the publisher. Otherwise: report and drop. Returns only in non-strict mode.
	local function misuse(kind: ErrorKind, message: string)
		if strict then
			error("[Events] " .. message, 0)
		end
		report(kind, message .. " (dropped)")
	end

	local bus = {} :: Bus
	bus.strict = strict

	function bus.publisher(_self: Bus, domain: Catalog.PublisherId): Publisher
		if typeof(domain) ~= "string" or not Catalog.isPublisher(domain) then
			error(`[Events] unknown publisher {describe(domain)}; publishers are {table.concat(Catalog.PUBLISHERS, ", ")}`, 0)
		end
		local publisher = {} :: Publisher
		publisher.Domain = domain
		function publisher.publish(_p: Publisher, name: Catalog.EventName, payload: unknown)
			local def = catalog[name]
			if def == nil then
				return misuse("unknown_event", `{domain} published unknown event {describe(name)}`)
			end
			if def.publisher ~= domain then
				return misuse("domain", `{name} is published by {def.publisher} only; {domain} tried to publish it`)
			end
			local err = check({ kind = "record", fields = def.fields }, payload, name)
			if err then
				return misuse("payload", err)
			end
			local frozen = frozenCopy(payload)
			-- Snapshot, so subscribing or disconnecting inside a handler does not change this delivery.
			local snapshot = table.clone(subscriptions[name])
			for _, sub in snapshot do
				if sub.connection.Connected then
					task.spawn(deliver, name, sub.handler, frozen)
				end
			end
			return
		end
		return table.freeze(publisher)
	end

	function bus.subscribe(_self: Bus, name: Catalog.EventName, handler: Handler): Connection
		local list = subscriptions[name]
		if list == nil then
			error(`[Events] cannot subscribe to unknown event {describe(name)}`, 0)
		end
		if typeof(handler) ~= "function" then
			error(`[Events] {name} handler must be a function, got {typeof(handler)}`, 0)
		end
		local connection = { Connected = true } :: Connection
		local sub: Subscription = { handler = handler, connection = connection }
		function connection.Disconnect(self: Connection)
			if not self.Connected then
				return
			end
			self.Connected = false
			local index = table.find(list, sub)
			if index then
				table.remove(list, index)
			end
		end
		table.insert(list, sub)
		return connection
	end

	function bus.subscriberCount(_self: Bus, name: Catalog.EventName): number
		local list = subscriptions[name]
		return if list then #list else 0
	end

	function bus.setErrorHandler(_self: Bus, handler: ErrorHandler)
		if typeof(handler) ~= "function" then
			error("[Events] error handler must be a function", 0)
		end
		onError = handler
	end

	return bus
end

local serverBus: Bus? = nil

-- The one shared server bus. Strict in Studio; on live servers misuse is reported and dropped. Clients have no bus.
function EventBus.server(): Bus
	if not RunService:IsServer() then
		error("[Events] the event bus is server-only", 0)
	end
	if serverBus == nil then
		serverBus = EventBus.new({ strict = RunService:IsStudio() })
	end
	return serverBus :: Bus
end

return table.freeze(EventBus)
