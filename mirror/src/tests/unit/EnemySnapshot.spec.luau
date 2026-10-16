--!strict
-- Net/EnemySnapshot (A2.3, architecture §7.2, docs/API_CONTRACTS.md EnemySnapshot): the 7-byte header and 18-byte
-- records, splitting into packets that stay under the unreliable payload limit (90 enemies → 889 + 745 bytes), the
-- contract guard accepts every packet, yaw/hp/def/state encodings, decoding junk never throws, and packing a bad row
-- (a server bug) throws. Runs on a clone of Shared.

local TestRunner = require(script.Parent.Parent.TestRunner)
local EnemyFixture = require(script.Parent.Parent.fixtures.EnemyFixture)

local shared = EnemyFixture.shared()
local EnemySnapshot = (require :: any)((shared :: any).Net.EnemySnapshot)
local Contracts = (require :: any)((shared :: any).Net.Contracts)

local function row(i: number, overrides: { [string]: any }?): any
	local r: { [string]: any } = {
		Id = i,
		DefId = if i % 3 == 0 then "Runner" else "Walker",
		Position = Vector3.new(i * 0.5, 0, 1600 - i),
		Yaw = (i * 0.1) % (2 * math.pi),
		State = "Pursue",
		Health = 20,
		MaxHealth = 20,
	}
	if overrides then
		for k, v in overrides do
			r[k] = v
		end
	end
	return r
end

local function rows(n: number): { any }
	local out = {}
	for i = 1, n do
		table.insert(out, row(i))
	end
	return out
end

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("layout", function()
		it("has a 7-byte header, 18-byte records and 49 records per packet under the 900-byte limit", function()
			expect(EnemySnapshot.HEADER).toBe(7)
			expect(EnemySnapshot.RECORD).toBe(18)
			expect(EnemySnapshot.MAX_PER_PACKET).toBe(49)
			expect(EnemySnapshot.HEADER + EnemySnapshot.MAX_PER_PACKET * EnemySnapshot.RECORD <= EnemySnapshot.MAX_BYTES).toBe(true)
		end)

		it("lists the enemy definitions sorted, Runner and Walker included", function()
			local ids = EnemySnapshot.DEF_IDS
			local sorted = table.clone(ids)
			table.sort(sorted)
			expect(ids).toEqual(sorted)
			expect(table.find(ids, "Runner") ~= nil).toBe(true)
			expect(table.find(ids, "Walker") ~= nil).toBe(true)
			expect(EnemySnapshot.defIndex(ids[1])).toBe(1)
			expect(EnemySnapshot.defIndex("Nobody")).toBeNil()
		end)

		it("indexes the seven §8.2 states from 0", function()
			expect(EnemySnapshot.STATES).toEqual({ "Spawn", "Pursue", "Telegraph", "Attack", "Recover", "Stagger", "Dying" })
			expect(EnemySnapshot.stateIndex("Spawn")).toBe(0)
			expect(EnemySnapshot.stateIndex("Dying")).toBe(6)
		end)
	end)

	describe("pack and unpack", function()
		it("split 90 enemies into 889 + 745 bytes that round-trip", function()
			local packets = EnemySnapshot.pack(7, 12.5, rows(90))
			expect(#packets).toBe(2)
			expect(buffer.len(packets[1])).toBe(889)
			expect(buffer.len(packets[2])).toBe(745)
			local seen = 0
			for _, packet in packets do
				local p = EnemySnapshot.unpack(packet)
				assert(p ~= nil, "decode failed")
				expect(p.Seq).toBe(7)
				expect(p.T).toBeCloseTo(12.5, 1e-6)
				for _, r in p.Records do
					seen += 1
					local src = row(r.Id)
					expect(EnemySnapshot.DEF_IDS[r.Def]).toBe(src.DefId)
					expect((r.Position - src.Position).Magnitude < 1e-3).toBe(true)
					expect(r.State).toBe(1)
					expect(r.HpPct).toBe(100)
					local diff = math.abs((r.Yaw - src.Yaw + math.pi) % (2 * math.pi) - math.pi)
					expect(diff <= math.pi / 256 + 1e-6).toBe(true)
				end
			end
			expect(seen).toBe(90)
		end)

		it("send one header-only packet for no enemies, and exactly 49 per full packet", function()
			local empty = EnemySnapshot.pack(1, 0, {})
			expect(#empty).toBe(1)
			expect(buffer.len(empty[1])).toBe(7)
			local p = EnemySnapshot.unpack(empty[1])
			expect(p and #p.Records).toBe(0)
			local full = EnemySnapshot.pack(1, 0, rows(98))
			expect(#full).toBe(2)
			expect(buffer.len(full[2])).toBe(889)
		end)

		it("pass the EnemySnapshot contract guard", function()
			local guard = Contracts.get("EnemySnapshot").Payload
			for _, n in { 0, 1, 49, 50, 90, 300 } do
				for _, packet in EnemySnapshot.pack(1, 1, rows(n)) do
					local ok, reason = guard(packet)
					assert(ok, reason)
				end
			end
			expect((guard(buffer.create(EnemySnapshot.MAX_BYTES + 1)))).toBe(false)
		end)
	end)

	describe("encodings", function()
		it("yaw wraps into 256 steps", function()
			expect(EnemySnapshot.encodeYaw(0)).toBe(0)
			expect(EnemySnapshot.encodeYaw(math.pi)).toBe(128)
			expect(EnemySnapshot.encodeYaw(-math.pi / 2)).toBe(192)
			expect(EnemySnapshot.encodeYaw(2 * math.pi - 0.001)).toBe(0)
			expect(EnemySnapshot.decodeYaw(64)).toBeCloseTo(math.pi / 2, 1e-9)
		end)

		it("hp rounds up so a living enemy never shows 0", function()
			expect(EnemySnapshot.hpPct(20, 20)).toBe(100)
			expect(EnemySnapshot.hpPct(0.01, 20)).toBe(1)
			expect(EnemySnapshot.hpPct(10, 20)).toBe(50)
			expect(EnemySnapshot.hpPct(0, 20)).toBe(0)
			expect(EnemySnapshot.hpPct(-5, 20)).toBe(0)
			expect(EnemySnapshot.hpPct(30, 20)).toBe(100)
		end)
	end)

	describe("decoding untrusted bytes never throws", function()
		it("rejects non-buffers, short, oversized and mis-sized buffers", function()
			expect((EnemySnapshot.unpack("x"))).toBeNil()
			expect((EnemySnapshot.unpack(buffer.create(3)))).toBeNil()
			expect((EnemySnapshot.unpack(buffer.create(901)))).toBeNil()
			local b = buffer.create(7 + 18)
			buffer.writeu8(b, 6, 2)
			local p, reason = EnemySnapshot.unpack(b)
			expect(p).toBeNil()
			expect(reason).toBe("25 bytes does not hold 2 records")
			local over = buffer.create(7)
			buffer.writeu8(over, 6, 50)
			expect((EnemySnapshot.unpack(over))).toBeNil()
		end)

		it("rejects a bad def, state, hp or position", function()
			local function corrupt(offset: number, write: (b: buffer, at: number) -> ()): string?
				local b = EnemySnapshot.pack(1, 1, { row(1) })[1]
				write(b, 7 + offset)
				local p, reason = EnemySnapshot.unpack(b)
				expect(p).toBeNil()
				return reason
			end
			expect(corrupt(2, function(b, at)
				buffer.writeu8(b, at, 0)
			end)).toBe("record 1: def 0 is not an enemy definition")
			expect(corrupt(16, function(b, at)
				buffer.writeu8(b, at, 7)
			end)).toBe("record 1: state 7 is not a state")
			expect(corrupt(17, function(b, at)
				buffer.writeu8(b, at, 101)
			end)).toBe("record 1: hpPct 101 is above 100")
			expect(corrupt(3, function(b, at)
				buffer.writef32(b, at, 0 / 0)
			end)).toBe("record 1: position is not finite")
		end)

		it("survives 2,000 random buffers", function()
			local rng = Random.new(5)
			for _ = 1, 2000 do
				local n = rng:NextInteger(0, 120)
				local b = buffer.create(n)
				for i = 0, n - 1 do
					buffer.writeu8(b, i, rng:NextInteger(0, 255))
				end
				EnemySnapshot.unpack(b)
			end
			expect(true).toBe(true)
		end)
	end)

	describe("packing a bad row throws (a server bug)", function()
		it("names the problem", function()
			expect(function()
				EnemySnapshot.pack(1, 0, { row(1, { DefId = "Ghost" }) })
			end).toThrow("unknown DefId Ghost")
			expect(function()
				EnemySnapshot.pack(1, 0, { row(1, { State = "Dancing" }) })
			end).toThrow("unknown State Dancing")
			expect(function()
				EnemySnapshot.pack(1, 0, { row(0) })
			end).toThrow("Id must be a whole number 1..65535")
			expect(function()
				EnemySnapshot.pack(1, 0, { row(1, { Position = Vector3.new(0 / 0, 0, 0) }) })
			end).toThrow("Position must be a finite Vector3")
			expect(function()
				EnemySnapshot.pack(70000, 0, {})
			end).toThrow("seq must be a whole number")
		end)
	end)
end
