--!strict
-- Gateway (architecture §5.2 phase 8, §7.1, §7.2, §19; CLAUDE.md rule 6): the only code that creates remotes and the
-- only door between client traffic and server logic.
--   · Remotes exist only for Net/Contracts entries and are created by expose(), which runs only while
--     Lifecycle.currentPhase() is 8 (Bootstrap's network step). They live in ReplicatedStorage/Net/<Name>.
--   · Services register handlers for client→server remotes with handle() before phase 8; expose() fails the boot if a
--     client→server contract has no handler. Server pushes go through fire()/fireAll() after expose().
--   · Every inbound request runs, in order (§7.1): identity (a Player in this server, one payload argument) → the
--     player's token bucket for that remote → the contract's payload guard → the handler. Handlers do the domain checks
--     (state, cooldown, ownership, resources, transaction uniqueness; §19). A rejection drops the request (a
--     RemoteFunction returns nil) and counts `Net.Rejected.<reason>`; a rate drop also counts `RateLimited` (§7.2).
--   · Session flag (§7.2 "three bursts in a minute"): a burst is one run of rate drops for a player on one remote,
--     ended when the bucket next accepts a request on that remote. The third burst start within 60 s flags the session
--     once: it counts `SessionFlagged` and isFlagged(userId) turns true. Flagging only marks; nothing is kicked.
--   · Outgoing pushes are checked against the contract guard in strict mode (Studio), so a server bug fails loudly.
-- Telemetry hooks in through setCounter (MetricsService) and setReporter (ErrorReportService); until then counts stay
-- local and reports go to warn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Contracts = require(ReplicatedStorage.Shared.Net.Contracts)
local TokenBucket = require(ReplicatedStorage.Shared.Net.TokenBucket)
local Lifecycle = require(script.Parent.Lifecycle)

type Contract = Contracts.Contract
type Bucket = TokenBucket.Bucket

export type Handler = (player: Player, payload: any) -> any
export type Counter = (name: string, amount: number) -> ()
export type Reporter = (kind: string, message: string) -> ()

export type Options = {
	contracts: { Contract }?, -- default Net/Contracts.list
	parent: Instance?, -- where the Net folder goes; default ReplicatedStorage
	clock: (() -> number)?, -- default os.clock
	phase: (() -> number?)?, -- default Lifecycle.currentPhase
	strict: boolean?, -- default RunService:IsStudio()
}

type Track = { bucket: Bucket, dropping: boolean }
type PlayerState = { tracks: { [string]: Track }, burstStarts: { number }, flagged: boolean }

export type Gateway = {
	strict: boolean,
	exposed: boolean,
	folder: Folder?,
	handle: (gateway: Gateway, name: string, handler: Handler) -> (),
	expose: (gateway: Gateway) -> number,
	onExposed: (gateway: Gateway, callback: () -> ()) -> (),
	fire: (gateway: Gateway, name: string, player: Player, payload: any) -> (),
	fireAll: (gateway: Gateway, name: string, payload: any) -> (),
	receive: (gateway: Gateway, name: string, userId: number, player: Player?, payload: unknown, extra: number?) -> (boolean, any),
	isFlagged: (gateway: Gateway, userId: number) -> boolean,
	forget: (gateway: Gateway, userId: number) -> (),
	setCounter: (gateway: Gateway, counter: Counter) -> (),
	setReporter: (gateway: Gateway, reporter: Reporter) -> (),
	counts: (gateway: Gateway) -> { [string]: number },
}

local NET_FOLDER = "Net"
local PHASE_NETWORK = 8
local BURSTS_TO_FLAG = 3
local BURST_WINDOW = 60

local function fail(message: string): never
	error("[Net] " .. message, 0)
end

local Gateway = {
	BURSTS_TO_FLAG = BURSTS_TO_FLAG,
	BURST_WINDOW = BURST_WINDOW,
	NET_FOLDER = NET_FOLDER,
}

function Gateway.new(options: Options?): Gateway
	local contracts: { Contract } = if options and options.contracts then options.contracts else Contracts.list
	local parent: Instance = if options and options.parent then options.parent else ReplicatedStorage
	local clock: () -> number = if options and options.clock then options.clock else os.clock
	local phase: () -> number? = if options and options.phase then options.phase else Lifecycle.currentPhase
	local strict = if options and options.strict ~= nil then options.strict else RunService:IsStudio()

	local byName: { [string]: Contract } = {}
	for _, c in contracts do
		byName[c.Name] = c
	end
	local handlers: { [string]: Handler } = {}
	local remotes: { [string]: Instance } = {}
	local players: { [number]: PlayerState } = {}
	local localCounts: { [string]: number } = {}
	local exposedCallbacks: { () -> () } = {}
	local counter: Counter? = nil
	local reporter: Reporter = function(kind: string, message: string)
		warn(`[Net] {kind}: {message}`)
	end

	local function count(name: string)
		localCounts[name] = (localCounts[name] or 0) + 1
		local sink = counter
		if sink then
			local ok, err = pcall(function()
				sink(name, 1)
			end)
			if not ok then
				warn(`[Net] counter failed for {name}: {tostring(err)}`)
			end
		end
	end

	local function contractOf(name: string): Contract
		local c = byName[name]
		if c == nil then
			fail(`no contract named {tostring(name)} (add its API_CONTRACTS.md row and Net/Contracts entry first)`)
		end
		return c :: Contract
	end

	local function stateOf(userId: number): PlayerState
		local state = players[userId]
		if state == nil then
			state = { tracks = {}, burstStarts = {}, flagged = false }
			players[userId] = state
		end
		return state :: PlayerState
	end

	local function trackOf(state: PlayerState, c: Contract, now: number): Track
		local track = state.tracks[c.Name]
		if track == nil then
			local rate = c.Rate
			local bucket = if rate then TokenBucket.new(rate.Sustained, rate.Burst, now) else TokenBucket.new(0, 0, now)
			track = { bucket = bucket, dropping = false }
			state.tracks[c.Name] = track
		end
		return track :: Track
	end

	local function reject(reason: string): (boolean, any)
		count(`Net.Rejected.{reason}`)
		return false, reason
	end

	local gateway = {} :: Gateway
	gateway.strict = strict
	gateway.exposed = false
	gateway.folder = nil

	function gateway.handle(_: Gateway, name: string, handler: Handler)
		local c = contractOf(name)
		if c.Direction ~= "C2S" then
			fail(`{name} is server→client; only client→server remotes take handlers`)
		end
		if gateway.exposed then
			fail(`handle({name}) after phase 8; register handlers in Init or Start`)
		end
		if handlers[name] ~= nil then
			fail(`{name} already has a handler`)
		end
		if typeof(handler) ~= "function" then
			fail(`handler for {name} must be a function`)
		end
		handlers[name] = handler
	end

	-- The inbound pipeline. userId keys the buckets; extra is the number of arguments after the payload.
	function gateway.receive(_: Gateway, name: string, userId: number, player: Player?, payload: unknown, extra: number?): (boolean, any)
		local c = byName[name]
		if c == nil then
			return reject("unknown")
		end
		if typeof(userId) ~= "number" or userId % 1 ~= 0 then
			return reject("identity")
		end
		if extra ~= nil and extra > 0 then
			return reject("arity")
		end
		local now = clock()
		local state = stateOf(userId)
		local track = trackOf(state, c, now)
		if not track.bucket:take(now) then
			count("RateLimited")
			if not track.dropping then
				track.dropping = true
				-- A new burst: keep the starts inside the window and flag on the third.
				local starts = state.burstStarts
				table.insert(starts, now)
				while #starts > 0 and now - starts[1] > BURST_WINDOW do
					table.remove(starts, 1)
				end
				if #starts >= BURSTS_TO_FLAG and not state.flagged then
					state.flagged = true
					count("SessionFlagged")
				end
			end
			return reject(if c.Direction == "S2C" then "direction" else "rate")
		end
		track.dropping = false
		if not (c.Payload(payload)) then
			return reject("payload")
		end
		local handler = handlers[name]
		if handler == nil then
			return reject("unhandled")
		end
		local handled, result = pcall(handler, player :: Player, payload)
		if not handled then
			count("Net.HandlerError")
			reporter("handler", `{name}: {tostring(result)}`)
			return false, "handler"
		end
		return true, result
	end

	function gateway.expose(_: Gateway): number
		local current = phase()
		if current ~= PHASE_NETWORK then
			fail(`remotes are created in boot phase 8 only (current phase: {if current == nil then "none" else tostring(current)})`)
		end
		if gateway.exposed then
			fail("expose() already ran")
		end
		if parent:FindFirstChild(NET_FOLDER) then
			fail(`{parent:GetFullName()}.{NET_FOLDER} already exists before phase 8`)
		end
		for _, c in contracts do
			if c.Direction == "C2S" and handlers[c.Name] == nil then
				fail(`{c.Name} is client→server but no service registered a handler`)
			end
		end
		local folder = Instance.new("Folder")
		folder.Name = NET_FOLDER
		for _, c in contracts do
			local remote: Instance
			if c.Channel == "F" then
				local fn = Instance.new("RemoteFunction")
				local name = c.Name
				fn.OnServerInvoke = function(player: Player, payload: unknown, ...: unknown): any
					if not player:IsDescendantOf(Players) then
						count("Net.Rejected.identity")
						return nil
					end
					local ok, result = gateway:receive(name, player.UserId, player, payload, select("#", ...))
					return if ok then result else nil
				end
				remote = fn
			else
				local event: RemoteEvent | UnreliableRemoteEvent = if c.Channel == "U"
					then Instance.new("UnreliableRemoteEvent")
					else Instance.new("RemoteEvent")
				local name = c.Name;
				(event :: any).OnServerEvent:Connect(function(player: Player, payload: unknown, ...: unknown)
					if not player:IsDescendantOf(Players) then
						count("Net.Rejected.identity")
						return
					end
					gateway:receive(name, player.UserId, player, payload, select("#", ...))
				end)
				remote = event
			end
			remote.Name = c.Name
			remote.Parent = folder
			remotes[c.Name] = remote
		end
		folder.Parent = parent
		gateway.folder = folder
		gateway.exposed = true
		Players.PlayerRemoving:Connect(function(player: Player)
			players[player.UserId] = nil
		end)
		for _, callback in exposedCallbacks do
			local ok, err = pcall(function()
				callback()
			end)
			if not ok then
				reporter("exposed", tostring(err))
			end
		end
		table.clear(exposedCallbacks)
		return #contracts
	end

	-- Runs callback right after expose() (immediately if it already ran). Use it to push initial state to players.
	function gateway.onExposed(_: Gateway, callback: () -> ())
		if gateway.exposed then
			callback()
		else
			table.insert(exposedCallbacks, callback)
		end
	end

	local function outgoing(name: string, payload: unknown): Instance?
		local c = contractOf(name)
		if c.Direction ~= "S2C" then
			fail(`{name} is client→server; the server cannot fire it`)
		end
		if not gateway.exposed then
			fail(`fire({name}) before phase 8; push from onExposed or later`)
		end
		local ok, reason = c.Payload(payload)
		if not ok then
			if strict then
				fail(`{name}: outgoing payload rejected: {reason}`)
			end
			count("Net.OutgoingRejected")
			reporter("outgoing", `{name}: {reason}`)
			return nil
		end
		return remotes[name]
	end

	function gateway.fire(_: Gateway, name: string, player: Player, payload: any)
		local remote = outgoing(name, payload)
		if remote then
			(remote :: any):FireClient(player, payload)
		end
	end

	function gateway.fireAll(_: Gateway, name: string, payload: any)
		local remote = outgoing(name, payload)
		if remote then
			(remote :: any):FireAllClients(payload)
		end
	end

	function gateway.isFlagged(_: Gateway, userId: number): boolean
		local state = players[userId]
		return state ~= nil and state.flagged
	end

	function gateway.forget(_: Gateway, userId: number)
		players[userId] = nil
	end

	function gateway.setCounter(_: Gateway, fn: Counter)
		counter = fn
	end

	function gateway.setReporter(_: Gateway, fn: Reporter)
		reporter = fn
	end

	function gateway.counts(_: Gateway): { [string]: number }
		return table.clone(localCounts)
	end

	return gateway
end

local shared: Gateway? = nil

-- The one gateway of this server (Bootstrap exposes it in phase 8).
function Gateway.server(): Gateway
	if not RunService:IsServer() then
		fail("Gateway runs on the server only")
	end
	if shared == nil then
		shared = Gateway.new()
	end
	return shared :: Gateway
end

return table.freeze(Gateway)
