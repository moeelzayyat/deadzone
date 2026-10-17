--!strict
-- Combat/CombatService (architecture §7.1–§7.3, §19; docs/API_CONTRACTS.md RequestAttack, ClientHeartbeat,
-- CombatResult): the server side of the primary attack. The client sends intent only (Seq, T, Origin, Dir, TargetHint);
-- the server decides everything else:
--   Gateway (identity → token bucket 12/20 → payload guard) → handler:
--   seq (strictly increasing per player; a replay gets no result) → arena (the player stands in a bound arena) →
--   state (alive) → origin (within ORIGIN_TOLERANCE studs of the server's character position) → direction (flattened
--   and normalized here) → cooldown (the weapon's Cooldown on the match SimulationClock, COOLDOWN_SLACK early at most,
--   never faster on average) → rewind enemies to T (Lib/LagCompensation: ≤ 250 ms, bounded by the measured view lag) →
--   hit test (Util/HitScan on the rewound positions, MaxTargets, stopped by arena walls) → DamageCalculator with the
--   attacker's StatBlock (Stats/ClassStats → StatPipeline; crit rolled here) → arena:damage → EnemyKilled (Encounter).
-- Every request that passes the seq check gets one CombatResult entry (no hits = miss or refusal); results are packed
-- (Net/CombatResult) and pushed once per server tick, after the step. Refusals count `Combat.Rejected.<reason>`.
-- Arenas come from Encounter, which boots later (§5.2), so Encounter binds its simulations here:
--   CombatService:bindArena(arena, contains) → unbind      arena = an EnemyService sim; contains(player) → boolean
--   CombatService:attack(player, request) → (Result?, reason?)   the handler body (tests call it directly)
--   CombatService:heartbeat(player, payload)               ClientHeartbeat: one view-lag sample
--   CombatService:flush() → packets                        push queued results (Heartbeat does it every tick)
--   CombatService:stats() → counters
-- Loadout until run state exists (A3) and class select (A4.7): every player is the default class (Sharpshooter) with
-- its starter weapon at level 1.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArenaGrid = require(ReplicatedStorage.Shared.Util.ArenaGrid)
local ClassStats = require(ReplicatedStorage.Shared.Stats.ClassStats)
local ClientHeartbeat = require(ReplicatedStorage.Shared.Net.ClientHeartbeat)
local CombatResult = require(ReplicatedStorage.Shared.Net.CombatResult)
local Common = require(ReplicatedStorage.Shared.Types.Common)
local DamageCalculator = require(ReplicatedStorage.Shared.Stats.DamageCalculator)
local EnemySteering = require(ReplicatedStorage.Shared.Util.EnemySteering)
local HitScan = require(ReplicatedStorage.Shared.Util.HitScan)
local PositionRing = require(ReplicatedStorage.Shared.Util.PositionRing)
local Registry = require(ReplicatedStorage.Shared.Definitions._Registry)
local StatPipeline = require(ReplicatedStorage.Shared.Stats.StatPipeline)
local Gateway = require(script.Parent.Parent.Parent.Gateway)
local Lifecycle = require(script.Parent.Parent.Parent.Lifecycle)
local LagCompensation = require(script.Parent.Lib.LagCompensation)

type StatBlock = StatPipeline.StatBlock
export type Result = CombatResult.Result

-- What CombatService reads of an enemy record (Encounter/EnemyService §8.2 rows).
export type Target = {
	Id: number,
	DefId: string,
	Pos: Vector3, -- arena-local
	Radius: number,
	State: string,
	History: PositionRing.Ring,
	Def: { Resistances: { [string]: number }? },
}

-- What CombatService reads of an arena simulation (an EnemyService Sim).
export type Arena = {
	MatchId: string,
	Clock: { Now: (self: any) -> number },
	Origin: CFrame,
	Grid: ArenaGrid.Grid,
	Enemies: { any },
	damage: (self: any, id: number, amount: number, userId: number) -> (number, boolean),
}

export type Request = { Seq: number, T: number, Origin: Vector3, Dir: Vector3, TargetHint: number? }

export type Loadout = { Class: ClassStats.ClassLike, Weapon: any, Level: number }

export type Pusher = {
	fire: (self: any, name: string, player: any, payload: any) -> (),
	handle: (self: any, name: string, handler: (player: Player, payload: any) -> any) -> (),
}

export type Options = {
	gateway: Pusher?,
	character: ((player: any) -> (Vector3?, boolean))?, -- position of the character root and whether it is alive
	loadout: ((player: any) -> Loadout)?,
	count: ((name: string, amount: number) -> ())?, -- default MetricsService:increment
	log: ((message: string) -> ())?, -- default warn
	seed: number?,
	connect: boolean?, -- Heartbeat flush and PlayerRemoving cleanup (default true)
}

export type CombatService = {
	Name: string,
	Init: (self: CombatService) -> (),
	Start: (self: CombatService) -> (),
	new: (options: Options?) -> CombatService,
	bindArena: (self: CombatService, arena: Arena, contains: (player: any) -> boolean) -> () -> (),
	arenaFor: (self: CombatService, player: any) -> Arena?,
	attack: (self: CombatService, player: any, request: Request) -> (Result?, string?),
	heartbeat: (self: CombatService, player: any, payload: unknown) -> boolean,
	flush: (self: CombatService) -> number,
	forget: (self: CombatService, userId: number) -> (),
	stats: (self: CombatService) -> { [string]: number },
	ORIGIN_TOLERANCE: number,
	COOLDOWN_SLACK: number,
}

local ORIGIN_TOLERANCE = 6 -- studs between the request's Origin and the server's character position (API_CONTRACTS)
local COOLDOWN_SLACK = 0.1 -- s a shot may arrive early (network jitter); the average rate never beats the cooldown
local DEFAULT_CLASS = "Sharpshooter"
local LOG_EVERY = 10 -- s between rejection log lines per player and reason
local DEFAULT_TAG: Common.DamageTag = "Ballistic"

type Binding = { arena: Arena, contains: (player: any) -> boolean, walls: EnemySteering.Walls }
type PlayerState = {
	LastSeq: number,
	NextReady: number,
	ReadyMatch: string?,
	Lag: LagCompensation.Tracker,
	LagMatch: string?,
	Stats: StatBlock?,
	Loadout: Loadout?,
}

local function defaultCharacter(player: Player): (Vector3?, boolean)
	local model = player.Character
	if model == nil then
		return nil, false
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") then
		return nil, false
	end
	return root.Position, humanoid ~= nil and humanoid.Health > 0
end

local function defaultLoadout(_player: Player): Loadout
	local registry = Registry.shared()
	local class = registry:get("Classes", DEFAULT_CLASS) :: any
	local weapon = registry:get("Weapons", class.StarterWeaponId) :: any
	return { Class = class, Weapon = weapon, Level = 1 }
end

local function damageTag(weapon: any): Common.DamageTag
	for _, tag in weapon.Tags or {} do
		if table.find(Common.DAMAGE_TAGS, tag) then
			return tag :: Common.DamageTag
		end
	end
	return DEFAULT_TAG
end

local function new(options: Options?): CombatService
	local injectedGateway = options and options.gateway
	local character: (player: any) -> (Vector3?, boolean) = (options and options.character) or defaultCharacter
	local loadoutOf: (player: any) -> Loadout = (options and options.loadout) or defaultLoadout
	local injectedCount = options and options.count
	local log: (message: string) -> () = (options and options.log) or function(message: string)
		warn(message)
	end
	local connect = not (options and options.connect == false)
	local rng = Random.new(options and options.seed or os.time())

	local bindings: { Binding } = {}
	local states: { [number]: PlayerState } = {}
	local pending: { [any]: { Result } } = {}
	local counters: { [string]: number } = {}
	local lastLog: { [string]: number } = {}
	local metrics: any = nil

	local service = {} :: CombatService
	service.Name = "CombatService"
	service.new = new
	service.ORIGIN_TOLERANCE = ORIGIN_TOLERANCE
	service.COOLDOWN_SLACK = COOLDOWN_SLACK

	local function count(name: string, amount: number?)
		local n = amount or 1
		counters[name] = (counters[name] or 0) + n
		if injectedCount then
			injectedCount(name, n)
		elseif metrics then
			metrics:increment(name, n)
		end
	end

	local function gateway(): Pusher
		return injectedGateway or (Gateway.server() :: any)
	end

	local function stateOf(userId: number): PlayerState
		local state = states[userId]
		if state == nil then
			state = {
				LastSeq = -1,
				NextReady = -math.huge,
				ReadyMatch = nil,
				Lag = LagCompensation.newTracker(),
				LagMatch = nil,
				Stats = nil,
				Loadout = nil,
			}
			states[userId] = state
		end
		return state :: PlayerState
	end

	local function reject(player: any, reason: string, detail: string?): (nil, string)
		count(`Combat.Rejected.{reason}`)
		if detail then
			local key = `{player.UserId}:{reason}`
			local now = os.clock()
			if now - (lastLog[key] or -math.huge) >= LOG_EVERY then
				lastLog[key] = now
				log(`[Combat] rejected an attack from {player.Name} ({player.UserId}): {reason}, {detail}`)
			end
		end
		return nil, reason
	end

	local function queue(player: any, result: Result)
		local list = pending[player]
		if list == nil then
			list = {}
			pending[player] = list
		end
		table.insert(list :: { Result }, result)
	end

	function service.bindArena(_: CombatService, arena: Arena, contains: (player: any) -> boolean): () -> ()
		local binding: Binding = { arena = arena, contains = contains, walls = EnemySteering.walls(arena.Grid) }
		table.insert(bindings, binding)
		return function()
			local index = table.find(bindings, binding)
			if index then
				table.remove(bindings, index)
			end
		end
	end

	local function bindingFor(player: any): Binding?
		for _, binding in bindings do
			if binding.contains(player) then
				return binding
			end
		end
		return nil
	end

	function service.arenaFor(_: CombatService, player: any): Arena?
		local binding = bindingFor(player)
		return if binding then binding.arena else nil
	end

	-- The authoritative attack. Returns the queued result, or nil and the reason when no result is sent (a replay).
	function service.attack(_: CombatService, player: any, request: Request): (Result?, string?)
		local state = stateOf(player.UserId)
		if request.Seq <= state.LastSeq then
			return reject(player, "seq")
		end
		state.LastSeq = request.Seq
		local result: Result = { Seq = request.Seq, Hits = {} }
		queue(player, result)

		local binding = bindingFor(player)
		if binding == nil then
			local _, reason = reject(player, "arena")
			return result, reason
		end
		local position, alive = character(player)
		if position == nil or not alive then
			local _, reason = reject(player, "state")
			return result, reason
		end
		local offset = (request.Origin - position).Magnitude
		if offset > ORIGIN_TOLERANCE then
			local _, reason = reject(player, "origin", string.format("origin %.1f studs from the server position", offset))
			return result, reason
		end
		local dir = HitScan.flat(request.Dir)
		if dir == nil then
			local _, reason = reject(player, "direction")
			return result, reason
		end

		local arena = binding.arena
		local now = arena.Clock:Now()
		local loadout = state.Loadout or loadoutOf(player)
		state.Loadout = loadout
		local weapon = loadout.Weapon
		local level = math.clamp(loadout.Level, 1, #weapon.Damage)
		if state.ReadyMatch ~= arena.MatchId then
			state.ReadyMatch = arena.MatchId
			state.NextReady = -math.huge
		end
		if now < state.NextReady - COOLDOWN_SLACK then
			local _, reason = reject(player, "cooldown")
			return result, reason
		end
		state.NextReady = math.max(state.NextReady, now) + weapon.Cooldown[level]

		if state.LagMatch ~= arena.MatchId then
			state.LagMatch = arena.MatchId
			state.Lag = LagCompensation.newTracker()
		end
		local rewindTo, clamped = LagCompensation.rewindTime(now, request.T, LagCompensation.lag(state.Lag))
		if clamped then
			count("Combat.RewindClamped")
		end

		local origin = arena.Origin:PointToObjectSpace(request.Origin)
		local localDir = arena.Origin:VectorToObjectSpace(dir)
		local candidates = table.create(#arena.Enemies)
		local byId: { [number]: Target } = {}
		for _, e in arena.Enemies do
			local target = e :: Target
			if target.State == "Dying" then
				continue
			end
			byId[target.Id] = target
			table.insert(candidates, {
				Id = target.Id,
				Position = target.History:at(rewindTo) or target.Pos,
				Radius = target.Radius,
			})
		end
		local hits = HitScan.cast(origin, localDir, weapon.Range, candidates, {
			hintId = request.TargetHint,
			maxTargets = weapon.MaxTargets,
		})

		local stats = state.Stats or ClassStats.compute(loadout.Class, weapon, level)
		state.Stats = stats
		local tag = damageTag(weapon)
		count("Combat.Attacks")
		for _, hit in hits do
			if not binding.walls:clear(origin.X, origin.Z, hit.Point.X, hit.Point.Z) then
				count("Combat.Blocked")
				break -- a wall stops the shot; anything farther is behind it too
			end
			local target = byId[hit.Id]
			local crit = rng:NextNumber() < StatPipeline.get(stats, "CritChance")
			local spec: DamageCalculator.Hit = {
				WeaponDamage = weapon.Damage[level],
				Crit = crit,
				Tag = tag :: any, -- a Common.DamageTag (damageTag checks it against DAMAGE_TAGS)
				Resistances = target.Def.Resistances,
				DifficultyMult = 1,
			}
			local amount = DamageCalculator.damage(stats, spec)
			local applied, killed = arena:damage(hit.Id, amount, player.UserId)
			if applied > 0 or killed then
				table.insert(result.Hits, { EnemyId = hit.Id, Damage = applied, Crit = crit, Killed = killed })
				count("Combat.Hits")
				if killed then
					count("Combat.Kills")
				end
			end
		end
		return result, nil
	end

	function service.heartbeat(_: CombatService, player: any, payload: unknown): boolean
		local _, clientTime = ClientHeartbeat.unpack(payload)
		if clientTime == nil then
			count("Combat.Rejected.heartbeat")
			return false
		end
		local binding = bindingFor(player)
		if binding == nil then
			return false
		end
		local state = stateOf(player.UserId)
		local arena = binding.arena
		if state.LagMatch ~= arena.MatchId then
			state.LagMatch = arena.MatchId
			state.Lag = LagCompensation.newTracker()
		end
		LagCompensation.observe(state.Lag, arena.Clock:Now(), clientTime :: number)
		return true
	end

	function service.flush(_: CombatService): number
		local sent = 0
		local push: Pusher? = nil
		for player, list in pending do
			pending[player] = nil
			if #list == 0 then
				continue
			end
			push = push or gateway()
			for _, packet in CombatResult.pack(list) do
				(push :: Pusher):fire("CombatResult", player, packet)
				sent += 1
				count("Combat.ResultBytes", buffer.len(packet))
			end
		end
		return sent
	end

	function service.forget(_: CombatService, userId: number)
		states[userId] = nil
		for player in pending do
			if player.UserId == userId then
				pending[player] = nil
			end
		end
	end

	function service.stats(_: CombatService): { [string]: number }
		return table.clone(counters)
	end

	function service.Init(_: CombatService)
		if injectedCount == nil then
			metrics = Lifecycle.get("MetricsService")
		end
	end

	function service.Start(self: CombatService)
		local push = gateway()
		push:handle("RequestAttack", function(player: Player, payload: any)
			self:attack(player, payload :: Request)
			return nil
		end)
		push:handle("ClientHeartbeat", function(player: Player, payload: any)
			self:heartbeat(player, payload)
			return nil
		end)
		if connect then
			RunService.Heartbeat:Connect(function()
				self:flush()
			end)
			Players.PlayerRemoving:Connect(function(player: Player)
				self:forget(player.UserId)
			end)
		end
	end

	return service
end

return new()
