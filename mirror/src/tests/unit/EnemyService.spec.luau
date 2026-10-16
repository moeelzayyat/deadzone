--!strict
-- Encounter/EnemyService (A2.3, architecture §8.1–§8.4, §9.1, §7.2, §23): enemy records match §8.2 and are plain tables
-- (no Instances), spawning and EnemySpawned, Spawn → Pursue → Telegraph → Attack → Recover, a paused clock freezes the
-- simulation, tiered update rates, stuck enemies teleport to a spawn edge and are logged, 90 Walkers/Runners close in on
-- a target in TestArena without leaving the floor or overlapping, snapshots carry world positions and go only to the
-- players given (interest filtering), and the harness stays off unless both flags are on. Also PositionRing (§8.2
-- History). Runs on clones of Server and Shared.

local ServerScriptService = game:GetService("ServerScriptService")

local TestRunner = require(script.Parent.Parent.TestRunner)
local EnemyFixture = require(script.Parent.Parent.fixtures.EnemyFixture)

local server = ServerScriptService.Server:Clone()
local EnemyService = (require :: any)((server :: any).Domains.Encounter.EnemyService)
local SimulationClock = (require :: any)((server :: any).Domains.Encounter.SimulationClock)
local shared = EnemyFixture.shared()
local ArenaGrid = (require :: any)((shared :: any).Util.ArenaGrid)
local EnemySnapshot = (require :: any)((shared :: any).Net.EnemySnapshot)
local PositionRing = (require :: any)((shared :: any).Util.PositionRing)
local definitions = EnemyFixture.definitions(shared)
local testArena = ArenaGrid.new((require :: any)((shared :: any).Definitions.Arenas.TestArena))

local DT = 1 / 60

type Setup = { sim: any, clock: any, grid: any, events: { any }, logs: { string }, attacks: { any } }

local function setup(grid: any?, origin: CFrame?): Setup
	local events, logs, attacks = {}, {}, {}
	local clock = SimulationClock.new()
	local g = grid or ArenaGrid.new(EnemyFixture.miniData())
	local sim = EnemyService.newSim({
		matchId = "M1",
		grid = g,
		clock = clock,
		origin = origin,
		definitions = definitions,
		seed = 11,
		publish = function(name: string, payload: any)
			table.insert(events, { name = name, payload = payload })
		end,
		log = function(message: string)
			table.insert(logs, message)
		end,
		onAttack = function(enemy: any, userId: number?)
			table.insert(attacks, { id = enemy.Id, userId = userId, at = clock:Now() })
		end,
	})
	return { sim = sim, clock = clock, grid = g, events = events, logs = logs, attacks = attacks }
end

local function run(s: Setup, seconds: number)
	for _ = 1, math.round(seconds / DT) do
		s.clock:Tick(DT)
		s.sim:step()
	end
end

-- An open TestArena cell whose centre lies minD..maxD studs from the spawn cell's centre.
local function openCellAt(minD: number, maxD: number): (number, number)
	local spawn = testArena:center(testArena.spawn.X, testArena.spawn.Z)
	for z = 1, testArena.depth do
		for x = 1, testArena.width do
			local d = (testArena:center(x, z) - spawn).Magnitude
			if testArena:isOpen(x, z) and d >= minD and d <= maxD then
				return x, z
			end
		end
	end
	error(`no open cell {minD}..{maxD} studs from the spawn`)
end

local function flags(values: { [string]: any }): any
	return {
		get = function(_self: any, name: string): any
			return values[name]
		end,
	}
end

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("records", function()
		it("hold the §8.2 fields as plain data, never Instances", function()
			local s = setup()
			local e = s.sim:spawn("Walker", 5, 3)
			for _, field in
				{
					"Id",
					"DefId",
					"MatchId",
					"Pos",
					"Vel",
					"Yaw",
					"Health",
					"MaxHealth",
					"State",
					"StateUntil",
					"Elite",
					"Mutations",
					"History",
					"Tier",
				}
			do
				expect(e[field] ~= nil).toBe(true)
			end
			expect(e.DefId).toBe("Walker")
			expect(e.MatchId).toBe("M1")
			expect(e.Health).toBe(definitions.Walker.MaxHealth)
			expect(e.State).toBe("Spawn")
			expect(e.Elite).toBe(false)
			expect(e.History.Count).toBe(1)
			for _, value in e do
				expect(typeof(value) ~= "Instance").toBe(true)
			end
			local x, z = s.grid:cellAt(e.Pos)
			expect({ x, z }).toEqual({ 5, 3 })
		end)

		it("get unique ids and are indexed by id", function()
			local s = setup()
			local a = s.sim:spawn("Walker", 5, 3)
			local b = s.sim:spawn("Runner", 6, 3)
			expect(a.Id ~= b.Id).toBe(true)
			expect(s.sim.ById[b.Id]).toBe(b)
			expect(s.sim:count()).toBe(2)
			expect(s.sim:remove(a.Id)).toBe(true)
			expect(s.sim:remove(a.Id)).toBe(false)
			expect(s.sim:count()).toBe(1)
			expect(s.sim.Enemies[1]).toBe(b)
		end)

		it("publish EnemySpawned with the catalog payload", function()
			local s = setup()
			local e = s.sim:spawn("Runner", 5, 3)
			expect(#s.events).toBe(1)
			expect(s.events[1].name).toBe("EnemySpawned")
			expect(s.events[1].payload).toEqual({ MatchId = "M1", EnemyId = e.Id, DefId = "Runner", Elite = false })
		end)

		it("refuse unknown definitions, blocked cells and unknown edges", function()
			local s = setup()
			expect(function()
				s.sim:spawn("Ghost", 5, 3)
			end).toThrow("unknown enemy definition Ghost")
			expect(function()
				s.sim:spawn("Walker", 8, 8)
			end).toThrow("cell (8,8) is not open")
			expect(function()
				s.sim:spawnAtEdge("Walker", "East")
			end).toThrow("unknown spawn edge East")
		end)

		it("spawn at edges inside the edge's cells", function()
			local s = setup()
			for _ = 1, 20 do
				local e = s.sim:spawnAtEdge("Walker", "South")
				local _, z = s.grid:cellAt(e.Pos)
				expect(z).toBe(11)
			end
			for _ = 1, 20 do
				local e = s.sim:spawnAtEdge("Walker")
				local _, z = s.grid:cellAt(e.Pos)
				expect(z == 2 or z == 11).toBe(true)
			end
		end)
	end)

	describe("states", function()
		it("leave Spawn for Pursue after SPAWN_TIME and move toward the target", function()
			local s = setup()
			local e = s.sim:spawn("Walker", 3, 11)
			local target = s.grid:center(10, 3)
			s.sim:setTargets({ { UserId = 7, Position = target } })
			run(s, EnemyService.SPAWN_TIME - 0.1)
			expect(e.State).toBe("Spawn")
			local before = (e.Pos - target).Magnitude
			run(s, 1)
			expect(e.State).toBe("Pursue")
			expect(e.TargetUserId).toBe(7)
			expect((e.Pos - target).Magnitude < before - 3).toBe(true)
		end)

		it("telegraph, attack once per cooldown and recover when in reach", function()
			local s = setup()
			local e = s.sim:spawn("Walker", 5, 3)
			s.sim:setTargets({ { UserId = 7, Position = e.Pos + Vector3.new(3, 0, 0) } })
			local seen: { [string]: boolean } = {}
			for _ = 1, math.round(4 / DT) do
				s.clock:Tick(DT)
				s.sim:step()
				seen[e.State] = true
			end
			expect(seen.Telegraph and seen.Attack and seen.Recover).toBe(true)
			local attack = definitions.Walker.Attack
			-- first attack lands after spawn + telegraph; then one per cooldown
			expect(#s.attacks >= 2).toBe(true)
			expect(s.attacks[1].userId).toBe(7)
			expect(s.attacks[1].at).toBeCloseTo(EnemyService.SPAWN_TIME + attack.TelegraphTime, 2 * DT)
			expect(s.attacks[2].at - s.attacks[1].at).toBeCloseTo(attack.Cooldown, 2 * DT)
			expect(s.sim.Stats.Attacks).toBe(#s.attacks)
		end)

		it("stand still with no target", function()
			local s = setup()
			local e = s.sim:spawn("Walker", 5, 5)
			local start = e.Pos
			run(s, 2)
			expect(e.Pos).toBe(start)
			expect(e.TargetUserId).toBeNil()
			expect(e.Tier).toBe(3)
		end)
	end)

	describe("SimulationClock", function()
		it("a paused clock freezes every enemy; resuming continues", function()
			local s = setup()
			local e = s.sim:spawn("Runner", 3, 11)
			s.sim:setTargets({ { UserId = 1, Position = s.grid:center(10, 3) } })
			run(s, 1.5)
			s.clock:Pause()
			local frozen, state = e.Pos, e.State
			for _ = 1, 120 do
				s.clock:Tick(DT)
				expect(s.sim:step()).toBe(0)
			end
			expect(e.Pos).toBe(frozen)
			expect(e.State).toBe(state)
			s.clock:Resume()
			run(s, 0.5)
			expect(e.Pos ~= frozen).toBe(true)
		end)

		it("a step without a tick does nothing", function()
			local s = setup()
			s.sim:spawn("Walker", 5, 5)
			s.clock:Tick(DT)
			s.sim:step()
			local steps = s.sim.Stats.Steps
			expect(s.sim:step()).toBe(0)
			expect(s.sim.Stats.Steps).toBe(steps)
		end)
	end)

	describe("tiered update rates", function()
		it("update near enemies every step, mid every 2nd, far every 4th", function()
			local s = setup(testArena)
			local spawn = testArena:center(testArena.spawn.X, testArena.spawn.Z)
			local near = s.sim:spawn("Walker", openCellAt(8, 14))
			local mid = s.sim:spawn("Walker", openCellAt(55, 65))
			local far = s.sim:spawn("Walker", openCellAt(86, 93))
			for _, e in { near, mid, far } do
				e.Speed = 0 -- hold the distances, so the tiers hold
			end
			s.sim:setTargets({ { UserId = 1, Position = spawn } })
			run(s, 0.1) -- every enemy updates once to learn its tier
			expect({ near.Tier, mid.Tier, far.Tier }).toEqual({ 1, 2, 3 })
			local counts = { [near.Id] = 0, [mid.Id] = 0, [far.Id] = 0 }
			for _ = 1, 120 do
				s.clock:Tick(DT)
				s.sim:step()
				for _, e in { near, mid, far } do
					if e.LastStep == s.clock:Now() then
						counts[e.Id] += 1
					end
				end
			end
			expect(counts[near.Id]).toBe(120)
			expect(counts[mid.Id]).toBe(60)
			expect(counts[far.Id]).toBe(30)
			expect({ EnemyService.TIER_NEAR, EnemyService.TIER_MID }).toEqual({ 40, 80 })
		end)
	end)

	describe("stuck enemies (§8.3)", function()
		it("teleport to a spawn edge after STUCK_WINDOW without moving while unseen, and are logged", function()
			local s = setup(testArena)
			local e = s.sim:spawn("Walker", openCellAt(75, 93))
			e.Speed = 0 -- pinned: it cannot make progress
			s.sim:setTargets({ { UserId = 1, Position = testArena:center(testArena.spawn.X, testArena.spawn.Z) } })
			run(s, EnemyService.SPAWN_TIME + EnemyService.STUCK_WINDOW * 2 + 0.5)
			expect(s.sim.Stats.Teleports >= 1).toBe(true)
			expect(#s.logs >= 1).toBe(true)
			expect(string.find(s.logs[1], "moved less than 2 studs in 4 s", 1, true) ~= nil).toBe(true)
			expect(string.find(s.logs[1], "teleported to edge", 1, true) ~= nil).toBe(true)
			local x, z = testArena:cellAt(e.Pos)
			local onEdge = false
			for _, edge in testArena.edges do
				for _, cell in testArena:edgeCells(edge.Id) do
					if cell.X == x and cell.Z == z then
						onEdge = true
					end
				end
			end
			expect(onEdge).toBe(true)
		end)

		it("are not teleported for falling behind a target that runs away faster than they walk", function()
			local s = setup(testArena)
			local spawn = testArena:center(testArena.spawn.X, testArena.spawn.Z)
			local e = s.sim:spawn("Walker", testArena.spawn.X, testArena.spawn.Z)
			local away = (spawn - testArena:center(openCellAt(86, 93))).Unit
			-- the target starts 61 studs off and backs away at 16 studs/s, so the distance only grows
			local target = spawn + away * 61
			for _ = 1, math.round(12 / DT) do
				target = Vector3.new(math.clamp(target.X + away.X * 16 * DT, -70, 70), 0, math.clamp(target.Z + away.Z * 16 * DT, -70, 70))
				s.sim:setTargets({ { UserId = 1, Position = target } })
				s.clock:Tick(DT)
				s.sim:step()
			end
			expect((e.Pos - spawn).Magnitude > 10).toBe(true)
			expect(s.sim.Stats.Teleports).toBe(0)
		end)

		it("do not teleport while a target is close enough to see them", function()
			local s = setup(testArena)
			local e = s.sim:spawn("Walker", openCellAt(20, 28))
			e.Speed = 0
			s.sim:setTargets({ { UserId = 1, Position = testArena:center(testArena.spawn.X, testArena.spawn.Z) } })
			run(s, 10)
			expect(s.sim.Stats.Teleports).toBe(0)
		end)

		it("are pushed back onto the floor when shoved into a wall", function()
			local s = setup()
			local e = s.sim:spawn("Walker", 5, 5)
			s.sim:setTargets({ { UserId = 1, Position = s.grid:center(10, 3) } })
			run(s, EnemyService.SPAWN_TIME + 0.1)
			e.Pos = Vector3.new(4.5, 0, 4.5) -- the middle of the box
			e.Speed = 0
			run(s, 0.1)
			local walls = (require :: any)((shared :: any).Util.EnemySteering).walls(s.grid)
			expect(walls:open(e.Pos.X, e.Pos.Z)).toBe(true)
			expect(s.sim.Stats.Teleports).toBe(0)
		end)
	end)

	describe("a 90-enemy horde in TestArena", function()
		it("closes in on one target without leaving the floor or overlapping", function()
			local s = setup(testArena)
			for i = 1, 90 do
				s.sim:spawnAtEdge(if i % 3 == 0 then "Runner" else "Walker", testArena.edges[(i - 1) % #testArena.edges + 1].Id)
			end
			local target = testArena:center(testArena.spawn.X, testArena.spawn.Z)
			s.sim:setTargets({ { UserId = 1, Position = target } })
			local walls = (require :: any)((shared :: any).Util.EnemySteering).walls(testArena)
			local worstStep, offFloor = 0, 0
			for step = 1, math.round(30 / DT) do
				s.clock:Tick(DT)
				local startedAt = os.clock()
				s.sim:step()
				worstStep = math.max(worstStep, os.clock() - startedAt)
				for _, e in s.sim.Enemies do
					if not walls:open(e.Pos.X, e.Pos.Z) then
						offFloor += 1
					end
				end
				if step % 300 == 0 then
					task.wait()
				end
			end
			local close, worstOverlap = 0, 0
			for i, a in s.sim.Enemies do
				if (a.Pos - target).Magnitude < 20 then
					close += 1
				end
				for j = i + 1, #s.sim.Enemies do
					local b = s.sim.Enemies[j]
					worstOverlap = math.max(worstOverlap, a.Radius + b.Radius - (a.Pos - b.Pos).Magnitude)
				end
			end
			print(
				string.format(
					"[EnemyService.spec] 90 enemies, 30 s: %d within 20 studs, worst overlap %.2f studs, worst step %.2f ms, %d teleports",
					close,
					worstOverlap,
					worstStep * 1000,
					s.sim.Stats.Teleports
				)
			)
			expect(s.sim:count()).toBe(90)
			expect(close >= 80).toBe(true)
			expect(offFloor).toBe(0)
			expect(worstOverlap < 0.25).toBe(true)
		end, 60)
	end)

	describe("snapshots and interest filtering", function()
		it("carry world positions (arena origin applied) and the live states", function()
			local origin = CFrame.new(0, 0, 1600)
			local s = setup(nil, origin)
			local e = s.sim:spawn("Walker", 5, 5)
			local packets = s.sim:snapshot()
			expect(#packets).toBe(1)
			local p = EnemySnapshot.unpack(packets[1])
			assert(p ~= nil, "decode failed")
			expect(p.Seq).toBe(1)
			local r = p.Records[1]
			expect(r.Id).toBe(e.Id)
			expect(((r.Position :: Vector3) - (e.Pos + Vector3.new(0, 0, 1600))).Magnitude < 1e-3).toBe(true)
			expect(EnemySnapshot.STATES[r.State + 1]).toBe("Spawn")
			expect(EnemySnapshot.unpack(s.sim:snapshot()[1]).Seq).toBe(2)
		end)

		it("go only to the players given, one fire per packet per player", function()
			local fired = {}
			local gateway = {
				fire = function(_self: any, name: string, player: any, payload: any)
					table.insert(fired, { name = name, player = player, bytes = buffer.len(payload) })
				end,
				onExposed = function(_self: any, _callback: () -> ()) end,
			}
			local service = EnemyService.new({ gateway = gateway, harness = false })
			local s = setup(testArena)
			for _ = 1, 90 do
				s.sim:spawnAtEdge("Walker")
			end
			local inArena = { { Name = "A" }, { Name = "B" } }
			local packets, bytes = service:broadcast(s.sim, inArena)
			expect(packets).toBe(2)
			expect(bytes).toBe((889 + 745) * 2)
			expect(#fired).toBe(4)
			for _, f in fired do
				expect(f.name).toBe("EnemySnapshot")
				expect(f.player == inArena[1] or f.player == inArena[2]).toBe(true)
			end
			table.clear(fired)
			expect(service:broadcast(s.sim, {})).toBe(0)
			expect(#fired).toBe(0)
		end)
	end)

	describe("service", function()
		it("runs no harness unless EnemyTest and TestArena are both on", function()
			for _, values in { { EnemyTest = false, TestArena = true }, { EnemyTest = true, TestArena = false } } do
				local service = EnemyService.new({
					flags = flags(values),
					config = flags({ EnemyTestCount = 90, EnemySnapshotHz = 12 }),
					arenas = {
						grid = function()
							error("the harness should not start")
						end,
						slotOrigin = function()
							return CFrame.identity
						end,
					},
					gateway = { fire = function() end, onExposed = function() end, handle = function() end },
					players = false,
				})
				service:Init()
				service:Start()
				expect(service:testSim()).toBeNil()
			end
		end)

		it("registers the RequestEnemySnapshots handler in Start whatever the flags, and tracks subscriptions", function()
			local handlers: { [string]: (player: any, payload: any) -> any } = {}
			local service = EnemyService.new({
				flags = flags({ EnemyTest = false, TestArena = false }),
				config = flags({}),
				arenas = { grid = function() end, slotOrigin = function() end },
				gateway = {
					fire = function() end,
					onExposed = function() end,
					handle = function(_self: any, name: string, handler: any)
						handlers[name] = handler
					end,
				},
				players = false,
			})
			service:Init()
			service:Start()
			assert(handlers.RequestEnemySnapshots ~= nil, "no handler")
			expect(service:isSubscribed(42)).toBe(false)
			expect(handlers.RequestEnemySnapshots({ UserId = 42 }, {})).toBeNil()
			expect(service:isSubscribed(42)).toBe(true)
			service:forget(42)
			expect(service:isSubscribed(42)).toBe(false)
		end)

		it("is named EnemyService and has the Init/Start contract", function()
			expect(EnemyService.Name).toBe("EnemyService")
			expect(typeof(EnemyService.Init)).toBe("function")
			expect(typeof(EnemyService.Start)).toBe("function")
		end)
	end)

	describe("PositionRing", function()
		it("keeps the newest samples up to its capacity", function()
			local ring = PositionRing.new(3)
			expect(ring:latest()).toBeNil()
			for i = 1, 5 do
				ring:push(i, Vector3.new(i, 0, 0))
			end
			expect(ring.Count).toBe(3)
			local time, position = ring:latest()
			expect(time).toBe(5)
			expect(position).toBe(Vector3.new(5, 0, 0))
		end)

		it("refuses a time before the newest sample and a bad capacity", function()
			local ring = PositionRing.new(2)
			ring:push(2, Vector3.zero)
			expect(function()
				ring:push(1, Vector3.zero)
			end).toThrow("[Ring] time 1 is before the newest sample 2")
			expect(function()
				PositionRing.new(0)
			end).toThrow("capacity must be a whole number")
		end)
	end)
end
