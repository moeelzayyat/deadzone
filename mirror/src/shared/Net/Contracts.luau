--!strict
-- Net/Contracts (architecture §7.2, §19; CLAUDE.md rule 6): the contract registry. One entry per remote that exists; each
-- mirrors its docs/API_CONTRACTS.md row (tools/check_contracts.py compares them). A remote is created in boot phase 8
-- (Server/Gateway) only if it is listed here, with a payload guard and, for client→server remotes, a token-bucket rate.
-- Rows in API_CONTRACTS.md whose substage is not built yet are added here by that substage.
--   Channel   R = RemoteEvent, F = RemoteFunction, U = UnreliableRemoteEvent
--   Direction C2S = client request, S2C = server push. F is C2S only (the server never invokes a client).
--   Rate      C2S only: Sustained per second / Burst. S2C remotes take no client traffic: their inbound bucket is empty, so
--             every client fire on them is dropped and counted (§7.2 "every remote has a per-player token bucket").
--   Payload   Net/Guard check run before any logic (inbound), and on outgoing pushes in strict mode.

local ClientHeartbeat = require(script.Parent.ClientHeartbeat)
local CombatResult = require(script.Parent.CombatResult)
local EnemySnapshot = require(script.Parent.EnemySnapshot)
local Guard = require(script.Parent.Guard)
local Settings = require(script.Parent.Parent.Config.Settings)

export type Channel = "R" | "F" | "U"
export type Direction = "C2S" | "S2C"
export type Rate = { Sustained: number, Burst: number }

export type Contract = {
	Name: string,
	Channel: Channel,
	Direction: Direction,
	Payload: Guard.Check,
	Rate: Rate?,
	Since: string,
}

local MAX_FLAGS = 64
local MAX_FLAG_NAME = 64
local MAX_FLAG_STRING = 200
local MAX_SEQ = 4294967295 -- request sequence numbers are u32
local MAX_TIME = 1e7 -- s; a SimulationClock time hint (T) beyond this is junk
local MAX_POSITION = 1e6 -- studs from the world origin
local MAX_ENEMY_ID = 65535 -- enemy ids are u16 (EnemySnapshot)

local function finite(x: number): boolean
	return x == x and x ~= math.huge and x ~= -math.huge
end

local Contracts = {}

-- Returns every problem in a contract list (empty when valid).
function Contracts.problems(list: { Contract }): { string }
	local problems: { string } = {}
	local seen: { [string]: boolean } = {}
	for i, c in list do
		local id = if typeof(c) == "table" and typeof(c.Name) == "string" then c.Name else `#{i}`
		if typeof(c) ~= "table" then
			table.insert(problems, `{id}: not a table`)
			continue
		end
		if typeof(c.Name) ~= "string" or not string.match(c.Name, "^%u%w*$") then
			table.insert(problems, `{id}: Name must be PascalCase letters and digits`)
		elseif seen[c.Name] then
			table.insert(problems, `{id}: duplicate Name`)
		else
			seen[c.Name] = true
		end
		if c.Channel ~= "R" and c.Channel ~= "F" and c.Channel ~= "U" then
			table.insert(problems, `{id}: Channel must be R, F or U`)
		end
		if c.Direction ~= "C2S" and c.Direction ~= "S2C" then
			table.insert(problems, `{id}: Direction must be C2S or S2C`)
		end
		if c.Channel == "F" and c.Direction ~= "C2S" then
			table.insert(problems, `{id}: a RemoteFunction is client→server only`)
		end
		if typeof(c.Payload) ~= "function" then
			table.insert(problems, `{id}: Payload must be a Net/Guard check`)
		end
		if typeof(c.Since) ~= "string" or not string.match(c.Since, "^%u%d+%.%d+$") then
			table.insert(problems, `{id}: Since must be a substage id such as A1.8`)
		end
		local rate = c.Rate
		if c.Direction == "C2S" then
			if typeof(rate) ~= "table" then
				table.insert(problems, `{id}: a client→server remote needs Rate = \{ Sustained, Burst }`)
			else
				local r = rate :: Rate
				if typeof(r.Sustained) ~= "number" or not finite(r.Sustained) or r.Sustained <= 0 then
					table.insert(problems, `{id}: Rate.Sustained must be a finite number > 0`)
				end
				if typeof(r.Burst) ~= "number" or r.Burst % 1 ~= 0 or r.Burst < 1 then
					table.insert(problems, `{id}: Rate.Burst must be a whole number ≥ 1`)
				end
			end
		elseif c.Direction == "S2C" and rate ~= nil then
			table.insert(problems, `{id}: a server→client remote takes no Rate (its inbound bucket is empty)`)
		end
	end
	return problems
end

-- Checks a list and returns it frozen and sorted by Name; throws one "[Contracts] ..." error listing every problem.
function Contracts.build(list: { Contract }): { Contract }
	local problems = Contracts.problems(list)
	if #problems > 0 then
		error(`[Contracts] {#problems} problems:\n- {table.concat(problems, "\n- ")}`, 0)
	end
	local sorted: { Contract } = table.clone(list)
	table.sort(sorted, function(a: Contract, b: Contract): boolean
		return a.Name < b.Name
	end)
	for _, c in sorted do
		if c.Rate then
			table.freeze(c.Rate)
		end
		table.freeze(c)
	end
	return table.freeze(sorted)
end

local flagValue = Guard.oneOf(Guard.boolean(), Guard.number(), Guard.string(MAX_FLAG_STRING, true))

Contracts.list = Contracts.build({
	{
		Name = "ClientHeartbeat",
		Channel = "U",
		Direction = "C2S",
		Payload = Guard.buffer(ClientHeartbeat.SIZE),
		Rate = { Sustained = 20, Burst = 30 },
		Since = "A2.5",
	},
	{
		Name = "CombatResult",
		Channel = "U",
		Direction = "S2C",
		Payload = Guard.buffer(CombatResult.MAX_BYTES),
		Since = "A2.5",
	},
	{
		Name = "EnemySnapshot",
		Channel = "U",
		Direction = "S2C",
		Payload = Guard.buffer(EnemySnapshot.HEADER + EnemySnapshot.MAX_PER_PACKET * EnemySnapshot.RECORD),
		Since = "A2.3",
	},
	{
		Name = "FlagsUpdate",
		Channel = "R",
		Direction = "S2C",
		Payload = Guard.map(Guard.string(MAX_FLAG_NAME), flagValue, MAX_FLAGS),
		Since = "A1.8",
	},
	{
		Name = "RequestSettings",
		Channel = "R",
		Direction = "C2S",
		Payload = Guard.record({ Key = Guard.literal(table.unpack(Settings.KEYS)), Value = Guard.boolean() }),
		Rate = { Sustained = 5, Burst = 10 },
		Since = "A2.1",
	},
	{
		Name = "RequestAttack",
		Channel = "R",
		Direction = "C2S",
		Payload = Guard.record({
			Seq = Guard.integer(0, MAX_SEQ),
			T = Guard.number({ min = 0, max = MAX_TIME }),
			Origin = Guard.vector3({ maxMagnitude = MAX_POSITION }),
			Dir = Guard.vector3({ unit = true }),
			TargetHint = Guard.optional(Guard.integer(1, MAX_ENEMY_ID)),
		}),
		Rate = { Sustained = 12, Burst = 20 },
		Since = "A2.5",
	},
	{
		Name = "RequestEnemySnapshots",
		Channel = "R",
		Direction = "C2S",
		Payload = Guard.empty(),
		Rate = { Sustained = 1, Burst = 2 },
		Since = "A2.3",
	},
})

local byName: { [string]: Contract } = {}
for _, c in Contracts.list do
	byName[c.Name] = c
end

-- The contract for a remote; throws for a name with no contract.
function Contracts.get(name: string): Contract
	local c = byName[name]
	if c == nil then
		error(`[Contracts] no contract named {tostring(name)}`, 0)
	end
	return c
end

return table.freeze(Contracts)
