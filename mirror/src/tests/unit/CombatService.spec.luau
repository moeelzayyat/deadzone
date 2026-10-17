--!strict
-- Combat/CombatService (A2.5, architecture §7.1–§7.3, §19; API_CONTRACTS RequestAttack, ClientHeartbeat,
-- CombatResult): the authoritative primary attack. Hit validation per TEST_PLAN A2: origin tolerance (a spoofed origin
-- is refused and changes nothing), direction normalization, the rewind picks the historical position (and is clamped to
-- 250 ms and to the measured view lag), cooldown on the match clock, replays, walls; damage from ClassStats →
-- StatPipeline → DamageCalculator; kills through a real EnemyService sim; results packed per tick. Also
-- Combat/Lib/LagCompensation, Net/CombatResult, Net/ClientHeartbeat, Stats/ClassStats, and the inbound pipeline of a real
-- Gateway on the shipped RequestAttack contract (guard and rate limit before the handler). Server and Shared are cloned.

local ServerScriptService = game:GetService("ServerScriptService")

local TestRunner = require(script.Parent.Parent.TestRunner)
local EnemyFixture = require(script.Parent.Parent.fixtures.EnemyFixture)

local server = ServerScriptService.Server:Clone()
local CombatService = (require :: any)((server :: any).Domains.Combat.CombatService)
local LagCompensation = (require :: any)((server :: any).Domains.Combat.Lib.LagCompensation)
local EnemyService = (require :: any)((server :: any).Domains.Encounter.EnemyService)
local SimulationClock = (require :: any)((server :: any).Domains.Encounter.SimulationClock)
local Gateway = (require :: any)((server :: any).Gateway)
local shared = EnemyFixture.shared()
local ArenaGrid = (require :: any)((shared :: any).Util.ArenaGrid)
local PositionRing = (require :: any)((shared :: any).Util.PositionRing)
local CombatResult = (require :: any)((shared :: any).Net.CombatResult)
local ClientHeartbeat = (require :: any)((shared :: any).Net.ClientHeartbeat)
local ClassStats = (require :: any)((shared :: any).Stats.ClassStats)
local Contracts = (require :: any)((shared :: any).Net.Contracts)
local definitions = EnemyFixture.definitions(shared)
local SHARPSHOOTER = (require :: any)((shared :: any).Definitions.Classes.Sharpshooter)
local RIFLE = (require :: any)((shared :: any).Definitions.Weapons.TacticalRifle)

local DT = 1 / 60
local EPSILON = 1e-6

type Rig = {
	combat: any,
	player: any,
	setPosition: (Vector3) -> (),
	setAlive: (boolean) -> (),
	counted: { [string]: number },
	logs: { string },
	fired: { any },
}

local function rig(loadout: any?): Rig
	local position = Vector3.zero
	local alive = true
	local counted: { [string]: number } = {}
	local logs: { string } = {}
	local fired: { any } = {}
	local combat = CombatService.new({
		gateway = {
			fire = function(_self: any, name: string, player: any, payload: any)
				table.insert(fired, { name = name, player = player, payload = payload })
			end,
			handle = function() end,
		},
		character = function(_player: any): (Vector3?, boolean)
			return position, alive
		end,
		loadout = function(): any
			return loadout or { Class = SHARPSHOOTER, Weapon = RIFLE, Level = 1 }
		end,
		count = function(name: string, amount: number)
			counted[name] = (counted[name] or 0) + amount
		end,
		log = function(message: string)
			table.insert(logs, message)
		end,
		seed = 5,
		connect = false,
	})
	return {
		combat = combat,
		player = { UserId = 77, Name = "Shooter" },
		setPosition = function(p: Vector3)
			position = p
		end,
		setAlive = function(a: boolean)
			alive = a
		end,
		counted = counted,
		logs = logs,
		fired = fired,
	}
end

-- A hand-made arena on the mini grid: one Walker-sized body whose History the test writes, a settable clock.
type FakeArena = { arena: any, enemy: any, setNow: (number) -> (), damaged: { any } }
local function fakeArena(grid: any): FakeArena
	local now = 0
	local damaged = {}
	local enemy = {
		Id = 3,
		DefId = "Walker",
		Pos = Vector3.zero,
		Radius = 1.5,
		State = "Pursue",
		History = PositionRing.new(16),
		Def = definitions.Walker,
	}
	local arena = {
		MatchId = "F1",
		Clock = {
			Now = function(_self: any): number
				return now
			end,
		},
		Origin = CFrame.identity,
		Grid = grid,
		Enemies = { enemy },
		damage = function(_self: any, id: number, amount: number, userId: number): (number, boolean)
			table.insert(damaged, { id = id, amount = amount, userId = userId })
			return amount, false
		end,
	}
	return {
		arena = arena,
		enemy = enemy,
		setNow = function(t: number)
			now = t
		end,
		damaged = damaged,
	}
end

local function request(seq: number, t: number, origin: Vector3, dir: Vector3, hint: number?): any
	return { Seq = seq, T = t, Origin = origin, Dir = dir, TargetHint = hint }
end

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect
	local grid = ArenaGrid.new(EnemyFixture.miniData())
	local EAST = Vector3.new(1, 0, 0)

	describe("LagCompensation", function()
		it("rewinds to T but never more than 250 ms back and never ahead of now", function()
			expect((LagCompensation.rewindTime(10, 9.9))).toBeCloseTo(9.9, EPSILON)
			local time, clamped = LagCompensation.rewindTime(10, 9.5)
			expect(time).toBeCloseTo(10 - LagCompensation.MAX_REWIND, EPSILON)
			expect(clamped).toBe(true)
			local ahead, clampedAhead = LagCompensation.rewindTime(10, 10.4)
			expect(ahead).toBe(10)
			expect(clampedAhead).toBe(true)
			local _, untouched = LagCompensation.rewindTime(10, 9.8)
			expect(untouched).toBe(false)
		end)

		it("keeps T within the measured view lag ± SLACK (median of the last heartbeats)", function()
			local tracker = LagCompensation.newTracker()
			expect(LagCompensation.lag(tracker)).toBeNil()
			for _, lag in { 0.05, 0.06, 0.9, 0.05, 0.07 } do
				LagCompensation.observe(tracker, 20, 20 - lag)
			end
			expect(LagCompensation.lag(tracker)).toBeCloseTo(0.06, EPSILON) -- the 0.9 s outlier does not move it
			local time, clamped = LagCompensation.rewindTime(20, 19.75, LagCompensation.lag(tracker))
			expect(time).toBeCloseTo(20 - 0.06 - LagCompensation.SLACK, EPSILON)
			expect(clamped).toBe(true)
			expect((LagCompensation.rewindTime(20, 19.9, LagCompensation.lag(tracker)))).toBeCloseTo(19.9, EPSILON)
			for _ = 1, 20 do
				LagCompensation.observe(tracker, 30, 29.8)
			end
			expect(#tracker.Samples).toBe(LagCompensation.SAMPLES)
			expect(LagCompensation.lag(tracker)).toBeCloseTo(0.2, EPSILON)
		end)
	end)

	describe("Net/CombatResult and Net/ClientHeartbeat", function()
		it("round-trips results with hits, misses, crits and kills", function()
			local results = {
				{ Seq = 4294967295, Hits = { { EnemyId = 65535, Damage = 10, Crit = false, Killed = false } } },
				{ Seq = 2, Hits = {} },
				{ Seq = 3, Hits = { { EnemyId = 1, Damage = 15.5, Crit = true, Killed = true } } },
			}
			local packets = CombatResult.pack(results)
			expect(#packets).toBe(1)
			expect(buffer.len(packets[1])).toBe(1 + 3 * 5 + 2 * 7)
			expect(CombatResult.unpack(packets[1])).toEqual(results)
		end)

		it("splits a big tick across packets of at most 900 bytes without splitting a result", function()
			local results = {}
			for i = 1, 200 do
				table.insert(results, { Seq = i, Hits = { { EnemyId = i, Damage = 1, Crit = false, Killed = false } } })
			end
			local packets = CombatResult.pack(results)
			local seen = 0
			for _, packet in packets do
				expect(buffer.len(packet) <= CombatResult.MAX_BYTES).toBe(true)
				seen += #(CombatResult.unpack(packet) :: any)
			end
			expect(#packets).toBe(3)
			expect(seen).toBe(200)
		end)

		it("rejects junk without throwing; pack throws on a server bug", function()
			expect((CombatResult.unpack("x"))).toBeNil()
			expect((CombatResult.unpack(buffer.create(0)))).toBeNil()
			local b = buffer.create(6)
			buffer.writeu8(b, 0, 1)
			buffer.writeu8(b, 5, 1) -- one hit promised, none present
			expect((CombatResult.unpack(b))).toBeNil()
			expect((CombatResult.unpack(buffer.create(901)))).toBeNil()
			expect(function()
				CombatResult.pack({ { Seq = -1, Hits = {} } })
			end).toThrow("[Result]")
			expect(function()
				CombatResult.pack({ { Seq = 1, Hits = { { EnemyId = 1, Damage = 0 / 0, Crit = false, Killed = false } } } })
			end).toThrow("[Result]")
		end)

		it("ClientHeartbeat packs 12 bytes and refuses other sizes, NaN and negative times", function()
			local seq, time = ClientHeartbeat.unpack(ClientHeartbeat.pack(7, 123.25))
			expect(seq).toBe(7)
			expect(time).toBe(123.25)
			expect((ClientHeartbeat.unpack(buffer.create(11)))).toBeNil()
			local nan = buffer.create(12)
			buffer.writef64(nan, 4, 0 / 0)
			expect((select(2, ClientHeartbeat.unpack(nan)))).toBeNil()
			expect((select(2, ClientHeartbeat.unpack(ClientHeartbeat.pack(1, -5))))).toBeNil()
		end)
	end)

	describe("ClassStats", function()
		it("builds the Sharpshooter's StatBlock through StatPipeline", function()
			local stats = ClassStats.compute(SHARPSHOOTER, RIFLE, 1)
			expect(stats.MaxHealth).toBe(SHARPSHOOTER.Base.Health)
			expect(stats.MoveSpeed).toBe(SHARPSHOOTER.Base.Speed)
			expect(stats.DamagePct).toBeCloseTo(SHARPSHOOTER.Base.DamageMult - 1, EPSILON)
			expect(stats.CritChance).toBe(ClassStats.DEFAULT_BASES.CritChance)
			expect(stats.ProjectileCount).toBe(1)
			local boosted = ClassStats.compute(SHARPSHOOTER, RIFLE, 1, {
				{ Stat = "DamagePct", Layer = "AdditivePct", Value = 0.5, Source = "Passive:Test" },
			})
			expect(boosted.DamagePct).toBeCloseTo(0.5, EPSILON)
		end)
	end)

	describe("attack validation", function()
		local function shooter(): (Rig, FakeArena, Vector3)
			local r = rig()
			local f = fakeArena(grid)
			r.combat:bindArena(f.arena, function()
				return true
			end)
			local from = grid:center(3, 4)
			r.setPosition(from + Vector3.new(0, 3, 0))
			f.enemy.Pos = grid:center(7, 4)
			f.enemy.History:push(0, f.enemy.Pos)
			return r, f, from + Vector3.new(0, 3, 0)
		end

		it("hits the enemy on the line with the weapon's damage and queues one result per request", function()
			local r, f, origin = shooter()
			local result, reason = r.combat:attack(r.player, request(1, 0, origin, EAST))
			expect(reason).toBeNil()
			expect(#result.Hits).toBe(1)
			expect(result.Hits[1].EnemyId).toBe(3)
			expect(result.Hits[1].Damage).toBe(RIFLE.Damage[1])
			expect(#f.damaged).toBe(1)
			expect(f.damaged[1].userId).toBe(77)
			expect(r.counted["Combat.Hits"]).toBe(1)
		end)

		it("refuses a spoofed origin: no damage, an empty result, counted and logged (TEST_PLAN A2 security)", function()
			local r, f, origin = shooter()
			-- the cheater claims to stand right next to the enemy, 7 studs from where the server has the character
			local spoofed = origin + Vector3.new(7, 0, 0)
			local result, reason = r.combat:attack(r.player, request(1, 0, spoofed, EAST))
			expect(reason).toBe("origin")
			expect(#result.Hits).toBe(0)
			expect(#f.damaged).toBe(0)
			expect(r.counted["Combat.Rejected.origin"]).toBe(1)
			expect(#r.logs).toBe(1)
			expect(string.find(r.logs[1], "origin 7.0 studs", 1, true) ~= nil).toBe(true)
			-- far away and vertical offsets count too; within the tolerance is accepted
			f.setNow(1)
			local _, far = r.combat:attack(r.player, request(2, 1, origin + Vector3.new(0, 40, 0), EAST))
			expect(far).toBe("origin")
			f.setNow(2)
			local ok, near = r.combat:attack(r.player, request(3, 2, origin + Vector3.new(0, 0, CombatService.ORIGIN_TOLERANCE - 0.5), EAST))
			expect(near).toBeNil()
			expect(ok ~= nil).toBe(true)
			expect(r.counted["Combat.Rejected.origin"]).toBe(2)
		end)

		it("normalizes the direction server-side and refuses a vertical one", function()
			local r, f, origin = shooter()
			local result = r.combat:attack(r.player, request(1, 0, origin, Vector3.new(0.6, -0.8, 0)))
			expect(#result.Hits).toBe(1) -- (0.6, -0.8, 0) flattens to east
			f.setNow(1)
			local _, reason = r.combat:attack(r.player, request(2, 1, origin, Vector3.new(0, -1, 0)))
			expect(reason).toBe("direction")
		end)

		it("refuses replays, dead players and players in no arena", function()
			local r, f, origin = shooter()
			r.combat:attack(r.player, request(5, 0, origin, EAST))
			f.setNow(1)
			local again, reason = r.combat:attack(r.player, request(5, 1, origin, EAST))
			expect(again).toBeNil()
			expect(reason).toBe("seq")
			local older = select(2, r.combat:attack(r.player, request(4, 1, origin, EAST)))
			expect(older).toBe("seq")
			r.setAlive(false)
			expect((select(2, r.combat:attack(r.player, request(6, 1, origin, EAST))))).toBe("state")
			local lone = rig()
			expect((select(2, lone.combat:attack(lone.player, request(1, 0, origin, EAST))))).toBe("arena")
			expect(#f.damaged).toBe(1)
		end)

		it("holds the weapon cooldown on the match clock, allowing COOLDOWN_SLACK of jitter but never a faster average", function()
			local r, f, origin = shooter()
			local cooldown = RIFLE.Cooldown[1]
			r.combat:attack(r.player, request(1, 0, origin, EAST))
			f.setNow(0.2)
			expect((select(2, r.combat:attack(r.player, request(2, 0.2, origin, EAST))))).toBe("cooldown")
			f.setNow(cooldown - CombatService.COOLDOWN_SLACK + 0.01)
			expect((select(2, r.combat:attack(r.player, request(3, 0, origin, EAST))))).toBeNil()
			-- a client firing as early as the slack allows, every time, still gets at most one shot per cooldown
			local accepted, seq, now = 0, 3, f.arena.Clock:Now()
			for _ = 1, 400 do
				now += DT
				f.setNow(now)
				seq += 1
				if select(2, r.combat:attack(r.player, request(seq, now, origin, EAST))) == nil then
					accepted += 1
				end
			end
			local seconds = 400 * DT
			expect(accepted <= math.floor(seconds / cooldown) + 1).toBe(true)
			expect(accepted >= math.floor(seconds / cooldown) - 1).toBe(true)
		end)

		it("rewinds the enemy to T: a shot at where it was hits, at where it is now misses", function()
			local r, f, origin = shooter()
			-- the enemy walks from row 4 to row 7 between t = 0 and t = 0.2
			f.enemy.History:push(0.1, grid:center(7, 5))
			f.enemy.History:push(0.2, grid:center(7, 7))
			f.enemy.Pos = grid:center(7, 7)
			f.setNow(0.2)
			local seen = r.combat:attack(r.player, request(1, 0, origin, EAST))
			expect(#seen.Hits).toBe(1) -- the client saw it on row 4, 200 ms ago
			f.setNow(0.8)
			local late = r.combat:attack(r.player, request(2, 0.8, origin, EAST))
			expect(#late.Hits).toBe(0) -- now it stands on row 7
		end)

		it("clamps T to 250 ms: an older claim sees the enemy where it was 250 ms ago, not where the client says", function()
			local r, f, origin = shooter()
			f.enemy.History:push(0.5, grid:center(7, 7))
			f.enemy.History:push(1, grid:center(7, 7))
			f.enemy.Pos = grid:center(7, 7)
			f.setNow(1)
			local result = r.combat:attack(r.player, request(1, 0, origin, EAST)) -- claims 1 s of lag
			expect(#result.Hits).toBe(0)
			expect(r.counted["Combat.RewindClamped"]).toBe(1)
		end)

		it("bounds T by the heartbeat view lag", function()
			local r, f, origin = shooter()
			f.enemy.History:push(0.9, grid:center(7, 4))
			f.enemy.History:push(1.0, grid:center(7, 7))
			f.enemy.Pos = grid:center(7, 7)
			f.setNow(1)
			for _ = 1, 5 do
				expect(r.combat:heartbeat(r.player, ClientHeartbeat.pack(1, 1 - 0.02))).toBe(true)
			end
			-- view lag 20 ms: T = 0.9 is 100 ms back, inside lag + SLACK (120 ms), so it stands and sees row 4
			local inside = r.combat:attack(r.player, request(1, 0.9, origin, EAST))
			expect(#inside.Hits).toBe(1)
			expect(r.counted["Combat.RewindClamped"]).toBeNil()
			f.setNow(1.6)
			f.enemy.History:push(1.6, grid:center(7, 7))
			for _ = 1, 9 do
				r.combat:heartbeat(r.player, ClientHeartbeat.pack(2, 1.6 - 0.02))
			end
			local outside = r.combat:attack(r.player, request(2, 1.4, origin, EAST)) -- 200 ms > 20 + 100 ms
			expect(r.counted["Combat.RewindClamped"]).toBe(1)
			expect(#outside.Hits).toBe(0)
			expect(r.combat:heartbeat(r.player, buffer.create(3))).toBe(false)
			expect(r.counted["Combat.Rejected.heartbeat"]).toBe(1)
		end)

		it("stops at arena walls: an enemy behind the box is not hit", function()
			local r, f = shooter()
			local from = grid:center(6, 8) + Vector3.new(0, 3, 0)
			r.setPosition(from)
			f.enemy.Pos = grid:center(11, 8)
			f.enemy.History:push(0, f.enemy.Pos)
			local result = r.combat:attack(r.player, request(1, 0, from, EAST))
			expect(#result.Hits).toBe(0)
			expect(r.counted["Combat.Blocked"]).toBe(1)
		end)

		it("does not hit a Dying enemy", function()
			local r, f, origin = shooter()
			f.enemy.State = "Dying"
			local result = r.combat:attack(r.player, request(1, 0, origin, EAST))
			expect(#result.Hits).toBe(0)
		end)

		it("pushes the tick's results once per flush, packed, to the right player", function()
			local r, f, origin = shooter()
			r.combat:attack(r.player, request(1, 0, origin, EAST))
			f.setNow(1)
			r.combat:attack(r.player, request(2, 1, origin, Vector3.new(-1, 0, 0)))
			expect(#r.fired).toBe(0)
			expect(r.combat:flush()).toBe(1)
			expect(#r.fired).toBe(1)
			expect(r.fired[1].name).toBe("CombatResult")
			expect(r.fired[1].player).toBe(r.player)
			local results = CombatResult.unpack(r.fired[1].payload)
			expect(#results).toBe(2)
			expect(results[1].Seq).toBe(1)
			expect(#results[1].Hits).toBe(1)
			expect(results[2].Seq).toBe(2)
			expect(#results[2].Hits).toBe(0)
			expect(r.combat:flush()).toBe(0)
		end)
	end)

	describe("with a real EnemyService sim", function()
		it("two rifle shots kill a Walker: Stagger, then Dying and EnemyKilled, then the row is gone", function()
			local clock = SimulationClock.new()
			local events = {}
			local sim = EnemyService.newSim({
				matchId = "M1",
				grid = grid,
				clock = clock,
				definitions = definitions,
				seed = 3,
				publish = function(name: string, payload: any)
					table.insert(events, { name = name, payload = payload })
				end,
				log = function() end,
			})
			local walker = sim:spawn("Walker", 7, 4)
			local r = rig()
			r.combat:bindArena(sim, function()
				return true
			end)
			local origin = grid:center(3, 4) + Vector3.new(0, 3, 0)
			r.setPosition(origin)
			sim:setTargets({ { UserId = 77, Position = grid:center(3, 10) } })
			for _ = 1, 45 do
				clock:Tick(DT)
				sim:step()
			end
			expect(walker.State).toBe("Pursue")
			local dir = (Vector3.new(walker.Pos.X, origin.Y, walker.Pos.Z) - origin).Unit
			local first = r.combat:attack(r.player, request(1, clock:Now(), origin, dir))
			expect(#first.Hits).toBe(1)
			expect(first.Hits[1].Killed).toBe(false)
			expect(walker.State).toBe("Stagger")
			for _ = 1, 31 do
				clock:Tick(DT)
				sim:step()
			end
			dir = (Vector3.new(walker.Pos.X, origin.Y, walker.Pos.Z) - origin).Unit
			local second = r.combat:attack(r.player, request(2, clock:Now(), origin, dir))
			expect(#second.Hits).toBe(1)
			expect(second.Hits[1].Killed).toBe(true)
			expect(walker.State).toBe("Dying")
			expect(events[#events].name).toBe("EnemyKilled")
			expect(events[#events].payload.KillerUserId).toBe(77)
			expect(r.counted["Combat.Kills"]).toBe(1)
			for _ = 1, 40 do
				clock:Tick(DT)
				sim:step()
			end
			expect(sim:count()).toBe(0)
		end)
	end)

	describe("inbound pipeline (real Gateway, shipped RequestAttack contract)", function()
		local function gatewayRig(): (any, any, { any })
			local now = 0
			local gateway = Gateway.new({
				contracts = { Contracts.get("RequestAttack"), Contracts.get("ClientHeartbeat"), Contracts.get("CombatResult") },
				parent = Instance.new("Folder") :: Instance,
				clock = function(): number
					return now
				end,
				phase = function(): number?
					return nil
				end,
				strict = true,
			})
			gateway:setCounter(function() end)
			gateway:setReporter(function() end)
			local seen = {}
			local combat = CombatService.new({
				gateway = gateway,
				character = function(): (Vector3?, boolean)
					return Vector3.zero, true
				end,
				loadout = function(): any
					return { Class = SHARPSHOOTER, Weapon = RIFLE, Level = 1 }
				end,
				count = function(name: string)
					table.insert(seen, name)
				end,
				log = function() end,
				connect = false,
			})
			combat:Start()
			return gateway, combat, seen
		end

		it("registers RequestAttack and ClientHeartbeat handlers in Start", function()
			local gateway = gatewayRig()
			local ok = gateway:receive("RequestAttack", 1, { UserId = 1, Name = "A" }, request(1, 0, Vector3.zero, EAST))
			expect(ok).toBe(true)
			expect((gateway:receive("ClientHeartbeat", 1, { UserId = 1, Name = "A" }, ClientHeartbeat.pack(1, 0)))).toBe(true)
		end)

		it("drops payloads that carry damage, hits or a bad direction before the handler runs", function()
			local gateway, _, seen = gatewayRig()
			local player = { UserId = 2, Name = "B" }
			local withDamage = request(1, 0, Vector3.zero, EAST) :: any
			withDamage.Damage = 999
			expect((gateway:receive("RequestAttack", 2, player, withDamage))).toBe(false)
			local withHits = request(2, 0, Vector3.zero, EAST) :: any
			withHits.Hits = { 1 }
			expect((gateway:receive("RequestAttack", 2, player, withHits))).toBe(false)
			expect((gateway:receive("RequestAttack", 2, player, request(3, 0, Vector3.zero, Vector3.new(5, 0, 0))))).toBe(false)
			expect((gateway:receive("RequestAttack", 2, player, request(4, 0 / 0, Vector3.zero, EAST)))).toBe(false)
			expect(#seen).toBe(0) -- the handler never ran
			expect(gateway:counts()["Net.Rejected.payload"]).toBe(4)
		end)

		it("rate-limits spam at the contract's 12/s burst 20", function()
			local gateway = gatewayRig()
			local player = { UserId = 3, Name = "C" }
			local accepted = 0
			for i = 1, 40 do
				if gateway:receive("RequestAttack", 3, player, request(i, 0, Vector3.zero, EAST)) then
					accepted += 1
				end
			end
			expect(accepted).toBe(20)
			expect(gateway:counts()["Net.Rejected.rate"]).toBe(20)
		end)
	end)
end
