--!strict
-- Net/CombatResult (architecture §7.1, §7.2; docs/API_CONTRACTS.md `CombatResult`): the authoritative outcome of a
-- player's attack requests, batched per server tick and pushed over the CombatResult UnreliableRemoteEvent. Every
-- accepted or refused RequestAttack gets one result with its Seq; a result with no hits is a miss (or a refusal), and
-- the client fades its predicted spark. Packed like EnemySnapshot so the A2.8 bandwidth probe can sum buffer.len.
-- Layout, little-endian:
--   header  count u8 (results in this packet)
--   result  seq u32 · hits u8, then `hits` × hit
--   hit     enemyId u16 · damage f32 · flags u8 (1 = crit, 2 = killed)
-- A tick's results are split into packets of at most MAX_BYTES; a result never spans two packets.
--   CombatResult.pack(results) → { buffer }      server; throws "[Result] ..." on a bad result (a server bug)
--   CombatResult.unpack(b) → ({ Result }?, reason?)   client; never throws on junk bytes

export type Hit = { EnemyId: number, Damage: number, Crit: boolean, Killed: boolean }
export type Result = { Seq: number, Hits: { Hit } }

local HEADER = 1
local RESULT = 5
local HIT = 7
local MAX_BYTES = 900 -- the UnreliableRemoteEvent payload limit (EnemySnapshot.MAX_BYTES)
local MAX_HITS = 16 -- hits in one result (MaxTargets caps are far lower; this bounds a packet)
local MAX_RESULTS = 255 -- results in one packet (count is u8)
local MAX_SEQ = 4294967295
local F32_MAX = 3.4028234663852886e38
local CRIT, KILLED = 1, 2

local CombatResult = {
	HEADER = HEADER,
	RESULT = RESULT,
	HIT = HIT,
	MAX_BYTES = MAX_BYTES,
	MAX_HITS = MAX_HITS,
	MAX_SEQ = MAX_SEQ,
}

local function fail(message: string): never
	error(`[Result] {message}`, 3)
end

local function check(result: Result)
	local seq = result.Seq
	if typeof(seq) ~= "number" or seq % 1 ~= 0 or seq < 0 or seq > MAX_SEQ then
		fail(`Seq {tostring(seq)} is not a u32`)
	end
	if #result.Hits > MAX_HITS then
		fail(`result {seq} has {#result.Hits} hits (max {MAX_HITS})`)
	end
	for _, hit in result.Hits do
		if typeof(hit.EnemyId) ~= "number" or hit.EnemyId % 1 ~= 0 or hit.EnemyId < 1 or hit.EnemyId > 65535 then
			fail(`EnemyId {tostring(hit.EnemyId)} is not a u16 id`)
		end
		local d = hit.Damage
		if typeof(d) ~= "number" or d ~= d or d < 0 or d > F32_MAX then
			fail(`Damage {tostring(d)} is not a finite number ≥ 0`)
		end
	end
end

function CombatResult.pack(results: { Result }): { buffer }
	local packets: { buffer } = {}
	local i = 1
	while i <= #results do
		local size, count = HEADER, 0
		local j = i
		while j <= #results and count < MAX_RESULTS do
			check(results[j])
			local add = RESULT + #results[j].Hits * HIT
			if size + add > MAX_BYTES then
				break
			end
			size += add
			count += 1
			j += 1
		end
		local b = buffer.create(size)
		buffer.writeu8(b, 0, count)
		local at = HEADER
		for k = i, j - 1 do
			local r = results[k]
			buffer.writeu32(b, at, r.Seq)
			buffer.writeu8(b, at + 4, #r.Hits)
			at += RESULT
			for _, hit in r.Hits do
				buffer.writeu16(b, at, hit.EnemyId)
				buffer.writef32(b, at + 2, hit.Damage)
				buffer.writeu8(b, at + 6, (if hit.Crit then CRIT else 0) + (if hit.Killed then KILLED else 0))
				at += HIT
			end
		end
		table.insert(packets, b)
		i = j
	end
	return packets
end

function CombatResult.unpack(value: unknown): ({ Result }?, string?)
	if typeof(value) ~= "buffer" then
		return nil, `expected buffer, got {typeof(value)}`
	end
	local b = value :: buffer
	local len = buffer.len(b)
	if len < HEADER or len > MAX_BYTES then
		return nil, `packet of {len} bytes`
	end
	local count = buffer.readu8(b, 0)
	local at = HEADER
	local results: { Result } = table.create(count)
	for _ = 1, count do
		if at + RESULT > len then
			return nil, "truncated result"
		end
		local seq = buffer.readu32(b, at)
		local hitCount = buffer.readu8(b, at + 4)
		at += RESULT
		if hitCount > MAX_HITS or at + hitCount * HIT > len then
			return nil, "truncated hits"
		end
		local hits: { Hit } = table.create(hitCount)
		for h = 1, hitCount do
			local damage = buffer.readf32(b, at + 2)
			local flags = buffer.readu8(b, at + 6)
			if damage ~= damage or damage < 0 or damage == math.huge then
				return nil, "damage is not finite"
			end
			hits[h] = {
				EnemyId = buffer.readu16(b, at),
				Damage = damage,
				Crit = bit32.btest(flags, CRIT),
				Killed = bit32.btest(flags, KILLED),
			}
			at += HIT
		end
		table.insert(results, { Seq = seq, Hits = hits })
	end
	if at ~= len then
		return nil, `{len - at} trailing bytes`
	end
	return results, nil
end

return table.freeze(CombatResult)
