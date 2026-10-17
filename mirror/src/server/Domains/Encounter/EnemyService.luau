--!strict
-- Encounter/EnemyService (architecture §8.1–§8.4, §9.1, §7.2, §23): enemies are rows in a server table, simulated on a
-- match's SimulationClock and sent to clients as packed snapshots; they are never Humanoids and never physics parts.
-- The service is the §5.1 Encounter service and the factory of per-match simulations (one Sim per arena copy):
--   local sim = EnemyService.newSim({ matchId, grid, clock, origin })   -- arena-local space on the arena grid
--   sim:spawn(defId, x, z) / sim:spawnAtEdge(defId, edgeId?) → Enemy    -- publishes EnemySpawned
--   sim:setTargets({ { UserId, Position } })                            -- the players in this arena, arena-local
--   sim:step() → updated                                                -- once per server step, after clock:Tick(dt)
--   sim:damage(id, amount, userId) → (applied, killed)                  -- Combat's hits (A2.5); publishes EnemyKilled
--   sim:snapshot() → { buffer }                                         -- Net/EnemySnapshot packets, world positions
--   EnemyService:broadcast(sim, players) → (packets, bytes)             -- EnemySnapshot to those players only
--   EnemyService:isSubscribed(userId) → boolean                         -- the client asked for snapshots
-- Each step reads clock:Now(); a paused clock does not advance, so nothing moves (§9.1). Fodder steering (§8.3): seek
-- along a FlowField toward the nearest target (one field per target, rebuilt when the target changes cell, at most every
-- FIELD_INTERVAL s), or straight at a target in sight within DIRECT_RANGE; plus separation from neighbours (spatial hash)
-- and wall slide on the collision grid. No PathfindingService. Tiered update rates (§23): an enemy within TIER_NEAR studs
-- of its nearest target updates every step, within TIER_MID every 2nd, else every 4th (staggered by Id). An enemy that
-- moves less than STUCK_MOVE studs in STUCK_WINDOW s while pursuing and no target is within UNSEEN_DISTANCE, or that
-- ends up in a blocked cell, is teleported to a spawn-edge cell no target can see, and logged (§8.3). Progress is the
-- enemy's own movement, not its distance to the target: a target running away faster than a Walker is not a stuck
-- Walker.
-- States (§8.2): Spawn (SPAWN_TIME) → Pursue → Telegraph (TelegraphTime) → Attack (ATTACK_TIME) → Recover → Pursue.
-- Attacks call the sim's onAttack hook; resolving damage on players arrives with A2.6.
-- Damage (A2.5, from Combat/CombatService): a hit takes health (never below 0). A hit on a Pursuing, Recovering or
-- Staggered enemy staggers it for STAGGER_TIME (it stands still, then pursues); Telegraph and Attack are not
-- interrupted, so a shooting player still has to dodge. At 0 health the enemy is Dying for DYING_TIME (it cannot be hit
-- and does not move), EnemyKilled goes out, and then the row is removed.
-- Snapshots go only to clients that subscribed: Client/EnemyController sends RequestEnemySnapshots once its handler is
-- connected, because an UnreliableRemoteEvent that reaches a client with no handler is discarded with a console error.
-- Start registers that handler whatever the flags (every client→server contract needs one before phase 8).
-- Test harness (flags EnemyTest + TestArena, A2.3): Start fills TestArena slot 0 with EnemyTestCount enemies (two Walkers
-- per Runner) and keeps it full (killed enemies come back from a spawn edge, at most REFILL_PER_STEP per step; A2.5),
-- binds the arena to Combat/CombatService for the players standing in it (A2.5), chases those players, pushes
-- snapshots at EnemySnapshotHz to the subscribed ones, prints a profile line every PROFILE_EVERY s and serves
-- ServerStorage/EnemyTestProbe (BindableFunction, "reset" | "read") for the Tests/perf/HeartbeatProbe measurement. Run
-- sessions (A3) take this over; the flag goes off then.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ArenaGrid = require(ReplicatedStorage.Shared.Util.ArenaGrid)
local EnemySnapshot = require(ReplicatedStorage.Shared.Net.EnemySnapshot)
local EnemySteering = require(ReplicatedStorage.Shared.Util.EnemySteering)
local EventBus = require(ReplicatedStorage.Shared.Events.EventBus)
local FlowField = require(ReplicatedStorage.Shared.Util.FlowField)
local PositionRing = require(ReplicatedStorage.Shared.Util.PositionRing)
local Registry = require(ReplicatedStorage.Shared.Definitions._Registry)
local Gateway = require(script.Parent.Parent.Parent.Gateway)
local Lifecycle = require(script.Parent.Parent.Parent.Lifecycle)
local SimulationClock = require(script.Parent.SimulationClock)

export type State = EnemySnapshot.State

export type EnemyDef = {
	Id: string,
	Tier: string,
	MaxHealth: number,
	MoveSpeed: number,
	Radius: number,
	Attack: { Damage: number, Range: number, Cooldown: number, TelegraphTime: number },
}

export type Enemy = {
	-- the §8.2 record
	Id: number,
	DefId: string,
	MatchId: string,
	Pos: Vector3, -- arena-local, feet on the floor (Y 0)
	Vel: Vector3,
	Yaw: number,
	Health: number,
	MaxHealth: number,
	State: State,
	StateUntil: number,
	TargetUserId: number?,
	Elite: boolean,
	Mutations: { string },
	History: PositionRing.Ring,
	Tier: number, -- 1 near, 2 mid, 3 far
	-- simulation bookkeeping
	Def: EnemyDef,
	Radius: number,
	Speed: number,
	LastStep: number,
	AttackReadyAt: number,
	CheckAt: number,
	CheckPos: Vector3,
}

export type Target = { UserId: number, Position: Vector3 }

export type SimStats = {
	Steps: number,
	Updates: number,
	FieldBuilds: number,
	Teleports: number,
	Spawned: number,
	Attacks: number,
	Damage: number,
	Kills: number,
	Removed: number,
}

export type SimOptions = {
	matchId: string,
	grid: ArenaGrid.Grid,
	clock: SimulationClock.Clock,
	origin: CFrame?, -- arena origin in the world (ArenaService:slotOrigin); default identity
	definitions: { [string]: EnemyDef }?, -- default the Enemies folder of the shared registry
	seed: number?,
	publish: ((name: string, payload: any) -> ())?, -- EnemySpawned; default nothing
	log: ((message: string) -> ())?, -- default print
	onAttack: ((enemy: Enemy, targetUserId: number?) -> ())?,
}

export type Sim = {
	MatchId: string,
	Grid: ArenaGrid.Grid,
	Clock: SimulationClock.Clock,
	Origin: CFrame,
	Enemies: { Enemy },
	ById: { [number]: Enemy },
	Targets: { Target },
	Stats: SimStats,
	spawn: (self: Sim, defId: string, x: number, z: number) -> Enemy,
	spawnAtEdge: (self: Sim, defId: string, edgeId: string?) -> Enemy,
	remove: (self: Sim, id: number) -> boolean,
	count: (self: Sim) -> number,
	setTargets: (self: Sim, targets: { Target }) -> (),
	step: (self: Sim) -> number,
	snapshot: (self: Sim) -> { buffer },
	damage: (self: Sim, id: number, amount: number, userId: number) -> (number, boolean),
}

local SPAWN_TIME = 0.6 -- s in Spawn before pursuing (the client plays a rise, A2.4)
local ATTACK_TIME = 0.2 -- s in Attack (the hit frame; player damage resolves in A2.6)
local MIN_RECOVER = 0.2 -- s
local STAGGER_TIME = 0.2 -- s a hit stops a pursuing enemy (A2.5)
local DYING_TIME = 0.6 -- s between the killing hit and the row's removal (the client plays the death)
local PLAYER_RADIUS = 1 -- studs; an enemy stops this far plus its own radius from a target's centre
local TIER_NEAR = 40 -- studs to the nearest target
local TIER_MID = 80
local TIER_STRIDE = { 1, 2, 4 }
local SEPARATION_MARGIN = 0.3 -- studs of extra spacing between neighbours
local SEPARATION_WEIGHT = 1.6
local MAX_SPEED_SCALE = 1.25 -- separation may push up to this × MoveSpeed
local TURN_RATE = 10 -- per second; velocity blends toward the desired velocity
local DIRECT_RANGE = 30 -- studs; a target in sight within this range is chased in a straight line
local FIELD_INTERVAL = 0.2 -- s between rebuilds of one target's field
local STUCK_WINDOW = 4 -- s
local STUCK_MOVE = 2 -- studs an enemy must move per window to count as unstuck
local UNSEEN_DISTANCE = 60 -- studs; no target this close means no player can see the enemy
local HISTORY = 16 -- PositionRing samples (≥ the 250 ms rewind window at 60 Hz)
local BUCKET_SIZE = 4 -- studs per spatial-hash cell
local MAX_SLIDE = 0.5 -- studs per wall-slide call (and at most 0.9 × the enemy's radius, the slide contract)
local MAX_ALIVE = 1000
local MAX_ID = 65535 -- ids are u16 in snapshots

local TEST_MATCH = "TestArena_0"
local TEST_ARENA = "TestArena"
local PROBE_NAME = "EnemyTestProbe"
local SUBSCRIBE_REMOTE = "RequestEnemySnapshots"
local PROFILE_EVERY = 30 -- s between harness profile lines
local PROFILE_SAMPLES = 36000 -- step durations kept for the probe (10 min at 60 Hz)
local REFILL_PER_STEP = 2 -- harness: enemies brought back per step after kills

local function definitionsFromRegistry(): { [string]: EnemyDef }
	local out: { [string]: EnemyDef } = {}
	for _, def in Registry.shared():all("Enemies") do
		out[def.Id :: string] = def :: any
	end
	return out
end

local function newSim(options: SimOptions): Sim
	local grid = options.grid
	local clock = options.clock
	local origin = options.origin or CFrame.identity
	local definitions = options.definitions or definitionsFromRegistry()
	local rng = Random.new(options.seed or 1)
	local publish = options.publish
	local log: (message: string) -> () = options.log or function(message: string)
		print(message)
	end
	local onAttack = options.onAttack
	local matchId = options.matchId

	local walls = EnemySteering.walls(grid)
	local buckets = EnemySteering.buckets(BUCKET_SIZE)
	local nearby: { EnemySteering.Item } = {}
	local edgeCells: { [string]: { ArenaGrid.Cell } } = {}
	local allEdgeCells: { { edge: string, cell: ArenaGrid.Cell } } = {}
	for _, edge in grid.edges do
		local cells = grid:edgeCells(edge.Id)
		edgeCells[edge.Id] = cells
		for _, cell in cells do
			table.insert(allEdgeCells, { edge = edge.Id, cell = cell })
		end
	end
	type FieldEntry = { field: FlowField.Field, builtAt: number }
	local fields: { [number]: FieldEntry } = {}
	local nextId = 0
	local lastNow = -1
	local frame = 0
	local seq = 0
	local dead: { number } = {}

	local sim = {} :: Sim
	sim.MatchId = matchId
	sim.Grid = grid
	sim.Clock = clock
	sim.Origin = origin
	sim.Enemies = {}
	sim.ById = {}
	sim.Targets = {}
	sim.Stats = {
		Steps = 0,
		Updates = 0,
		FieldBuilds = 0,
		Teleports = 0,
		Spawned = 0,
		Attacks = 0,
		Damage = 0,
		Kills = 0,
		Removed = 0,
	}

	local function allocateId(): number
		for _ = 1, MAX_ID do
			nextId = nextId % MAX_ID + 1
			if sim.ById[nextId] == nil then
				return nextId
			end
		end
		error("[Enemy] no free enemy id", 0)
	end

	local function cellCentre(x: number, z: number): Vector3
		local c = grid:center(x, z)
		local jitter = grid.cellSize * 0.4
		return Vector3.new(c.X + rng:NextNumber(-jitter, jitter), 0, c.Z + rng:NextNumber(-jitter, jitter))
	end

	local function nearest(position: Vector3): (Target?, number)
		local best: Target? = nil
		local bestD2 = math.huge
		for _, target in sim.Targets do
			local dx, dz = target.Position.X - position.X, target.Position.Z - position.Z
			local d2 = dx * dx + dz * dz
			if d2 < bestD2 then
				best, bestD2 = target, d2
			end
		end
		return best, math.sqrt(bestD2)
	end

	-- A spawn-edge cell no target can see (falls back to any edge cell).
	local function hiddenEdgeCell(): (string, ArenaGrid.Cell)
		local pick = allEdgeCells[rng:NextInteger(1, #allEdgeCells)]
		for _ = 1, 8 do
			local _, d = nearest(grid:center(pick.cell.X, pick.cell.Z))
			if d > UNSEEN_DISTANCE then
				break
			end
			pick = allEdgeCells[rng:NextInteger(1, #allEdgeCells)]
		end
		return pick.edge, pick.cell
	end

	local function teleport(e: Enemy, now: number, reason: string)
		local fromX, fromZ = grid:cellAt(e.Pos)
		local edge, cell = hiddenEdgeCell()
		e.Pos = cellCentre(cell.X, cell.Z)
		e.Vel = Vector3.zero
		e.CheckAt = now + STUCK_WINDOW
		e.CheckPos = e.Pos
		sim.Stats.Teleports += 1
		log(
			`[Enemy] {matchId} #{e.Id} {e.DefId} {reason} at cell ({fromX or "?"},{fromZ or "?"}); teleported to edge {edge} ({cell.X},{cell.Z})`
		)
	end

	-- Timed states chain from the previous deadline, not from the step that noticed it, so the cycle keeps its length
	-- (an attack every Cooldown s) whatever the update tier.
	local function setState(e: Enemy, state: State, duration: number, from: number)
		e.State = state
		e.StateUntil = from + duration
	end

	local function move(e: Enemy, target: Target?, distance: number, dt: number)
		local seekX, seekZ = 0, 0
		local stop = e.Radius + PLAYER_RADIUS
		if target and distance > stop then
			local tx, tz = target.Position.X - e.Pos.X, target.Position.Z - e.Pos.Z
			if distance <= DIRECT_RANGE and walls:clear(e.Pos.X, e.Pos.Z, target.Position.X, target.Position.Z) then
				seekX, seekZ = tx / distance, tz / distance
			else
				local entry = fields[target.UserId]
				if entry then
					seekX, seekZ = entry.field:direction(e.Pos)
				end
				if seekX == 0 and seekZ == 0 then
					seekX, seekZ = tx / distance, tz / distance
				end
			end
		end
		local count = buckets:gather(e.Pos, nearby)
		local push = EnemySteering.separation(e, nearby, count, SEPARATION_MARGIN)
		local speed = e.Speed
		local vx = seekX * speed + push.X * speed * SEPARATION_WEIGHT
		local vz = seekZ * speed + push.Z * speed * SEPARATION_WEIGHT
		local m = math.sqrt(vx * vx + vz * vz)
		local cap = speed * MAX_SPEED_SCALE
		if m > cap then
			vx, vz = vx / m * cap, vz / m * cap
		end
		if target and seekX ~= 0 and distance - stop < speed * dt then
			-- arrive: do not overshoot the stop ring around the target
			local scale = math.max(0, distance - stop) / (speed * dt)
			vx, vz = vx * scale, vz * scale
		end
		local v = e.Vel:Lerp(Vector3.new(vx, 0, vz), math.min(1, dt * TURN_RATE))
		local x, z = e.Pos.X, e.Pos.Z
		local mx, mz = v.X * dt, v.Z * dt
		-- substep long moves (far tiers, clock hitches) so no slide is longer than MAX_SLIDE
		local piece = math.min(MAX_SLIDE, e.Radius * 0.9)
		local pieces = math.max(1, math.ceil(math.sqrt(mx * mx + mz * mz) / piece))
		local nx, nz = x, z
		for _ = 1, pieces do
			nx, nz = walls:slide(nx, nz, mx / pieces, mz / pieces, e.Radius)
		end
		e.Pos = Vector3.new(nx, e.Pos.Y, nz)
		-- bodies never sink into each other: push out of any overlap left after moving (walls still win)
		local out = EnemySteering.resolve(e, nearby, count)
		if out.X ~= 0 or out.Z ~= 0 then
			nx, nz = walls:slide(nx, nz, out.X, out.Z, e.Radius)
			e.Pos = Vector3.new(nx, e.Pos.Y, nz)
		end
		e.Vel = if dt > 0 then Vector3.new((nx - x) / dt, 0, (nz - z) / dt) else Vector3.zero
		if target and distance <= stop + e.Def.Attack.Range * 2 then
			e.Yaw = EnemySteering.yaw(target.Position.X - e.Pos.X, target.Position.Z - e.Pos.Z)
		elseif e.Vel.Magnitude > 0.5 then
			e.Yaw = EnemySteering.yaw(e.Vel.X, e.Vel.Z)
		end
	end

	local function update(e: Enemy, now: number, dt: number)
		e.LastStep = now
		local target, distance = nearest(e.Pos)
		e.TargetUserId = if target then target.UserId else nil
		e.Tier = if target == nil then 3 elseif distance <= TIER_NEAR then 1 elseif distance <= TIER_MID then 2 else 3

		local state = e.State
		if state == "Spawn" then
			if now >= e.StateUntil then
				setState(e, "Pursue", 0, now)
				e.CheckAt = now + STUCK_WINDOW
				e.CheckPos = e.Pos
			end
		elseif state == "Telegraph" then
			if target then
				e.Yaw = EnemySteering.yaw(target.Position.X - e.Pos.X, target.Position.Z - e.Pos.Z)
			end
			if now >= e.StateUntil then
				setState(e, "Attack", ATTACK_TIME, e.StateUntil)
				sim.Stats.Attacks += 1
				if onAttack then
					onAttack(e, e.TargetUserId)
				end
			end
		elseif state == "Attack" then
			if now >= e.StateUntil then
				local attack = e.Def.Attack
				setState(e, "Recover", math.max(MIN_RECOVER, attack.Cooldown - attack.TelegraphTime - ATTACK_TIME), e.StateUntil)
			end
		elseif state == "Recover" or state == "Stagger" then
			if now >= e.StateUntil then
				setState(e, "Pursue", 0, e.StateUntil)
			end
		elseif state == "Dying" then
			if now >= e.StateUntil then
				table.insert(dead, e.Id)
			end
		end

		if e.State == "Pursue" then
			local reach = e.Radius + PLAYER_RADIUS + e.Def.Attack.Range
			if target and distance <= reach and now >= e.AttackReadyAt then
				setState(e, "Telegraph", e.Def.Attack.TelegraphTime, now)
				e.AttackReadyAt = now + e.Def.Attack.Cooldown
				e.Vel = Vector3.zero
				e.Yaw = EnemySteering.yaw(target.Position.X - e.Pos.X, target.Position.Z - e.Pos.Z)
			else
				move(e, target, distance, dt)
				if not walls:open(e.Pos.X, e.Pos.Z) then
					teleport(e, now, "left the open floor")
				elseif now >= e.CheckAt then
					if target and distance > UNSEEN_DISTANCE and (e.Pos - e.CheckPos).Magnitude < STUCK_MOVE then
						teleport(e, now, `moved less than {STUCK_MOVE} studs in {STUCK_WINDOW} s`)
					else
						e.CheckAt = now + STUCK_WINDOW
						e.CheckPos = e.Pos
					end
				end
			end
		elseif e.State ~= "Spawn" then
			e.Vel = Vector3.zero
		end
		e.History:push(now, e.Pos)
	end

	function sim.spawn(self: Sim, defId: string, x: number, z: number): Enemy
		local def = definitions[defId]
		if def == nil then
			error(`[Enemy] unknown enemy definition {tostring(defId)}`, 2)
		end
		if not grid:isOpen(x, z) then
			error(`[Enemy] cell ({x},{z}) is not open`, 2)
		end
		if #self.Enemies >= MAX_ALIVE then
			error(`[Enemy] {matchId} already has {MAX_ALIVE} enemies`, 2)
		end
		local now = clock:Now()
		local id = allocateId()
		local pos = cellCentre(x, z)
		local enemy: Enemy = {
			Id = id,
			DefId = defId,
			MatchId = matchId,
			Pos = pos,
			Vel = Vector3.zero,
			Yaw = rng:NextNumber(0, 2 * math.pi),
			Health = def.MaxHealth,
			MaxHealth = def.MaxHealth,
			State = "Spawn",
			StateUntil = now + SPAWN_TIME,
			TargetUserId = nil,
			Elite = false,
			Mutations = {},
			History = PositionRing.new(HISTORY),
			Tier = 3,
			Def = def,
			Radius = def.Radius,
			Speed = def.MoveSpeed,
			LastStep = now,
			AttackReadyAt = now,
			CheckAt = now + SPAWN_TIME + STUCK_WINDOW,
			CheckPos = pos,
		}
		enemy.History:push(now, pos)
		table.insert(self.Enemies, enemy)
		self.ById[id] = enemy
		self.Stats.Spawned += 1
		if publish then
			publish("EnemySpawned", { MatchId = matchId, EnemyId = id, DefId = defId, Elite = false })
		end
		return enemy
	end

	function sim.spawnAtEdge(self: Sim, defId: string, edgeId: string?): Enemy
		local cells: { ArenaGrid.Cell }
		if edgeId then
			cells = edgeCells[edgeId]
			if cells == nil then
				error(`[Enemy] unknown spawn edge {edgeId}`, 2)
			end
		else
			cells = edgeCells[grid.edges[rng:NextInteger(1, #grid.edges)].Id]
		end
		local cell = cells[rng:NextInteger(1, #cells)]
		return self:spawn(defId, cell.X, cell.Z)
	end

	function sim.remove(self: Sim, id: number): boolean
		local enemy = self.ById[id]
		if enemy == nil then
			return false
		end
		self.ById[id] = nil
		local list = self.Enemies
		local index = table.find(list, enemy) :: number
		list[index] = list[#list]
		list[#list] = nil
		return true
	end

	function sim.count(self: Sim): number
		return #self.Enemies
	end

	function sim.setTargets(self: Sim, targets: { Target })
		self.Targets = targets
		local keep: { [number]: boolean } = {}
		for _, target in targets do
			keep[target.UserId] = true
		end
		for userId in fields do
			if not keep[userId] then
				fields[userId] = nil
			end
		end
	end

	function sim.step(self: Sim): number
		local now = clock:Now()
		if now <= lastNow then
			return 0 -- paused, or no tick since the last step
		end
		lastNow = now
		frame += 1
		self.Stats.Steps += 1

		for _, target in self.Targets do
			local x, z = grid:cellAt(target.Position)
			if x == nil or z == nil or not grid:isOpen(x, z) then
				continue
			end
			local entry = fields[target.UserId]
			if entry == nil then
				entry = { field = FlowField.new(grid), builtAt = -math.huge }
				fields[target.UserId] = entry
			end
			local e = entry :: FieldEntry
			if (e.field.targetX ~= x or e.field.targetZ ~= z) and now - e.builtAt >= FIELD_INTERVAL then
				e.field:build(x, z)
				e.builtAt = now
				self.Stats.FieldBuilds += 1
			end
		end

		buckets:clear()
		for _, enemy in self.Enemies do
			buckets:insert(enemy)
		end
		local updated = 0
		for _, enemy in self.Enemies do
			if (frame + enemy.Id) % TIER_STRIDE[enemy.Tier] == 0 then
				update(enemy, now, now - enemy.LastStep)
				updated += 1
			end
		end
		self.Stats.Updates += updated
		if #dead > 0 then
			for _, id in dead do
				self:remove(id)
				self.Stats.Removed += 1
			end
			table.clear(dead)
		end
		return updated
	end

	function sim.damage(self: Sim, id: number, amount: number, userId: number): (number, boolean)
		local e = self.ById[id]
		if e == nil or e.State == "Dying" or not (amount > 0) then
			return 0, false
		end
		local now = clock:Now()
		local applied = math.min(amount, e.Health)
		e.Health -= applied
		self.Stats.Damage += applied
		if e.Health <= 0 then
			e.Health = 0
			setState(e, "Dying", DYING_TIME, now)
			e.Vel = Vector3.zero
			self.Stats.Kills += 1
			if publish then
				publish("EnemyKilled", {
					MatchId = matchId,
					KillerUserId = userId,
					EnemyId = id,
					DefId = e.DefId,
					ProtocolLevel = 0, -- no Outbreak Protocol before A3.5
					Position = origin:PointToWorldSpace(e.Pos),
				})
			end
			return applied, true
		end
		if e.State == "Pursue" or e.State == "Recover" or e.State == "Stagger" then
			setState(e, "Stagger", STAGGER_TIME, now)
			e.Vel = Vector3.zero
		end
		return applied, false
	end

	function sim.snapshot(self: Sim): { buffer }
		seq = (seq + 1) % 65536
		local rows: { EnemySnapshot.Row } = table.create(#self.Enemies)
		for i, e in self.Enemies do
			rows[i] = {
				Id = e.Id,
				DefId = e.DefId,
				Position = origin:PointToWorldSpace(e.Pos),
				Yaw = e.Yaw,
				State = e.State,
				Health = e.Health,
				MaxHealth = e.MaxHealth,
			}
		end
		return EnemySnapshot.pack(seq, clock:Now(), rows)
	end

	return sim
end

-- The parts of other services this one uses (tests pass fakes).
export type FlagReader = { get: (self: any, name: string) -> any }
export type ConfigReader = { get: (self: any, key: string) -> any }
export type Pusher = {
	fire: (self: any, name: string, player: any, payload: any) -> (),
	onExposed: (self: any, callback: () -> ()) -> (),
	handle: (self: any, name: string, handler: (player: Player, payload: any) -> any) -> (),
}
export type CombatBinder = {
	bindArena: (self: any, arena: any, contains: (player: any) -> boolean) -> () -> (),
}
export type ArenaReader = {
	grid: (self: any, arenaId: string) -> ArenaGrid.Grid,
	slotOrigin: (self: any, slot: number) -> CFrame,
}

export type Options = {
	flags: FlagReader?,
	config: ConfigReader?,
	arenas: ArenaReader?,
	gateway: Pusher?,
	combat: CombatBinder?,
	harness: boolean?, -- run the test horde when the flags are on (default true)
	players: boolean?, -- connect Players.PlayerRemoving to forget subscriptions (default true)
}

export type EnemyService = {
	Name: string,
	Init: (self: EnemyService) -> (),
	Start: (self: EnemyService) -> (),
	newSim: (options: SimOptions) -> Sim,
	broadcast: (self: EnemyService, sim: Sim, players: { any }) -> (number, number),
	subscribe: (self: EnemyService, userId: number) -> (),
	forget: (self: EnemyService, userId: number) -> (),
	isSubscribed: (self: EnemyService, userId: number) -> boolean,
	testSim: (self: EnemyService) -> Sim?,
	new: (options: Options?) -> EnemyService,
	SPAWN_TIME: number,
	TIER_NEAR: number,
	TIER_MID: number,
	TIER_STRIDE: { number },
	STUCK_WINDOW: number,
	UNSEEN_DISTANCE: number,
	DIRECT_RANGE: number,
	STAGGER_TIME: number,
	DYING_TIME: number,
}

local function percentile(sorted: { number }, p: number): number
	if #sorted == 0 then
		return 0
	end
	return sorted[math.clamp(math.ceil(#sorted * p), 1, #sorted)]
end

local function summary(samples: { number }, count: number): (number, number, number)
	local list = table.create(count)
	local total = 0
	for i = 1, count do
		list[i] = samples[i]
		total += samples[i]
	end
	table.sort(list)
	return if count > 0 then total / count else 0, percentile(list, 0.99), list[count] or 0
end

local function new(options: Options?): EnemyService
	local injectedFlags = options and options.flags
	local injectedConfig = options and options.config
	local injectedArenas = options and options.arenas
	local injectedGateway = options and options.gateway
	local injectedCombat = options and options.combat
	local harness = not (options and options.harness == false)
	local connectPlayers = not (options and options.players == false)
	local subscribed: { [number]: boolean } = {}

	local flags: FlagReader? = nil
	local config: ConfigReader? = nil
	local arenas: ArenaReader? = nil
	local combat: CombatBinder? = nil
	local testSim: Sim? = nil

	local service = {} :: EnemyService
	service.Name = "EnemyService"
	service.new = new
	service.newSim = newSim
	service.SPAWN_TIME = SPAWN_TIME
	service.TIER_NEAR = TIER_NEAR
	service.TIER_MID = TIER_MID
	service.TIER_STRIDE = TIER_STRIDE
	service.STUCK_WINDOW = STUCK_WINDOW
	service.UNSEEN_DISTANCE = UNSEEN_DISTANCE
	service.DIRECT_RANGE = DIRECT_RANGE
	service.STAGGER_TIME = STAGGER_TIME
	service.DYING_TIME = DYING_TIME

	local function gateway(): Pusher
		return injectedGateway or (Gateway.server() :: any)
	end

	-- Interest filtering (§7.2): only the given players (the ones in the sim's arena) receive its snapshot.
	function service.broadcast(_: EnemyService, sim: Sim, players: { any }): (number, number)
		if #players == 0 then
			return 0, 0
		end
		local packets = sim:snapshot()
		local bytes = 0
		local push = gateway()
		for _, packet in packets do
			bytes += buffer.len(packet)
			for _, player in players do
				push:fire("EnemySnapshot", player, packet)
			end
		end
		return #packets, bytes * #players
	end

	function service.subscribe(_: EnemyService, userId: number)
		subscribed[userId] = true
	end

	function service.forget(_: EnemyService, userId: number)
		subscribed[userId] = nil
	end

	function service.isSubscribed(_: EnemyService, userId: number): boolean
		return subscribed[userId] == true
	end

	function service.testSim(_: EnemyService): Sim?
		return testSim
	end

	function service.Init(_: EnemyService)
		flags = injectedFlags or (Lifecycle.get("FeatureFlagService") :: any)
		config = injectedConfig or (Lifecycle.get("RemoteConfigService") :: any)
		arenas = injectedArenas or (Lifecycle.get("ArenaService") :: any)
		combat = injectedCombat or (Lifecycle.get("CombatService") :: any)
	end

	local function startHarness(self: EnemyService, arenaReader: ArenaReader, configReader: ConfigReader)
		local grid = arenaReader:grid(TEST_ARENA)
		local origin = arenaReader:slotOrigin(0)
		local clock = SimulationClock.new()
		local events = EventBus.server():publisher("Encounter")
		local sim = newSim({
			matchId = TEST_MATCH,
			grid = grid,
			clock = clock,
			origin = origin,
			seed = 2303,
			publish = function(name: string, payload: any)
				events:publish(name :: any, payload)
			end,
		})
		testSim = sim
		local count: number = configReader:get("EnemyTestCount")
		local hz: number = configReader:get("EnemySnapshotHz")
		local runners = 0
		for i = 1, count do
			local defId = if i % 3 == 0 then "Runner" else "Walker"
			if defId == "Runner" then
				runners += 1
			end
			sim:spawnAtEdge(defId, grid.edges[(i - 1) % #grid.edges + 1].Id)
		end
		local wantRunners = runners
		local present: { [number]: boolean } = {}
		if combat then
			combat:bindArena(sim, function(player: any): boolean
				return present[player.UserId] == true
			end)
		end
		-- Brings killed enemies back (two Walkers per Runner), a few per step.
		local function refill()
			local missing = count - sim:count()
			if missing <= 0 then
				return
			end
			local runnersNow = 0
			for _, e in sim.Enemies do
				if e.DefId == "Runner" then
					runnersNow += 1
				end
			end
			for _ = 1, math.min(missing, REFILL_PER_STEP) do
				local defId = if runnersNow < wantRunners then "Runner" else "Walker"
				if defId == "Runner" then
					runnersNow += 1
				end
				sim:spawnAtEdge(defId)
			end
		end
		print(
			`[Enemy] test horde: {count} enemies ({count - runners} Walkers, {runners} Runners) in {TEST_ARENA} slot 0, snapshots at {hz} Hz`
		)

		local exposed = false
		gateway():onExposed(function()
			exposed = true
		end)

		local samples: { number } = table.create(PROFILE_SAMPLES, 0)
		local sampleCount, sampleHead = 0, 0
		local window: { number } = {}
		local sent = { Snapshots = 0, Packets = 0, Bytes = 0 }
		local function resetProbe()
			sampleCount, sampleHead = 0, 0
			sent.Snapshots, sent.Packets, sent.Bytes = 0, 0, 0
		end

		local probe = Instance.new("BindableFunction")
		probe.Name = PROBE_NAME
		probe.OnInvoke = function(command: string): any
			if command == "reset" then
				resetProbe()
				return true
			end
			local avg, p99, max = summary(samples, sampleCount)
			local states: { [string]: number } = {}
			for _, e in sim.Enemies do
				states[e.State] = (states[e.State] or 0) + 1
			end
			return {
				Count = sim:count(),
				States = states,
				Samples = sampleCount,
				StepAvgMs = avg,
				StepP99Ms = p99,
				StepMaxMs = max,
				Snapshots = sent.Snapshots,
				Packets = sent.Packets,
				Bytes = sent.Bytes,
				Stats = table.clone(sim.Stats),
				ClockTime = clock:Now(),
			}
		end
		probe.Parent = ServerStorage

		local interval = 1 / hz
		local accumulator = 0
		local nextProfile = os.clock() + PROFILE_EVERY
		RunService.Heartbeat:Connect(function(dt: number)
			local startedAt = os.clock()
			clock:Tick(dt)
			local targets: { Target } = {}
			local inArena: { Player } = {}
			table.clear(present)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					local position = origin:PointToObjectSpace(root.Position)
					if math.abs(position.Y) < 50 and grid:cellAt(position) ~= nil then
						table.insert(targets, { UserId = player.UserId, Position = Vector3.new(position.X, 0, position.Z) })
						present[player.UserId] = true
						if subscribed[player.UserId] then
							table.insert(inArena, player)
						end
					end
				end
			end
			sim:setTargets(targets)
			sim:step()
			refill()
			accumulator += dt
			if exposed and accumulator >= interval then
				accumulator = math.min(accumulator - interval, interval)
				local packets, bytes = self:broadcast(sim, inArena)
				if packets > 0 then
					sent.Snapshots += 1
					sent.Packets += packets * #inArena
					sent.Bytes += bytes
				end
			end
			local ms = (os.clock() - startedAt) * 1000
			sampleHead = sampleHead % PROFILE_SAMPLES + 1
			samples[sampleHead] = ms
			sampleCount = math.min(sampleCount + 1, PROFILE_SAMPLES)
			table.insert(window, ms)
			if startedAt >= nextProfile then
				nextProfile = startedAt + PROFILE_EVERY
				local steps = #window
				local avg, p99, max = summary(window, steps)
				table.clear(window)
				print(
					string.format(
						"[Enemy] profile %s: %d enemies, %d targets, step avg %.3f ms, p99 %.3f ms, max %.3f ms over %d steps; %d teleports",
						TEST_MATCH,
						sim:count(),
						#targets,
						avg,
						p99,
						max,
						steps,
						sim.Stats.Teleports
					)
				)
			end
		end)
	end

	function service.Start(self: EnemyService)
		gateway():handle(SUBSCRIBE_REMOTE, function(player: Player, _payload: any)
			self:subscribe(player.UserId)
			return nil
		end)
		if connectPlayers then
			Players.PlayerRemoving:Connect(function(player: Player)
				self:forget(player.UserId)
			end)
		end
		local reader, configReader, arenaReader = flags, config, arenas
		if not harness or reader == nil or configReader == nil or arenaReader == nil then
			return
		end
		if reader:get("EnemyTest") ~= true or reader:get("TestArena") ~= true then
			return
		end
		startHarness(self, arenaReader, configReader)
	end

	return service
end

return new()
