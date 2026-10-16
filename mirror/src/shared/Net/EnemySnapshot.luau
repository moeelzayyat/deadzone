--!strict
-- Net/EnemySnapshot (architecture §7.2, §8.1; docs/API_CONTRACTS.md `EnemySnapshot`): the packed enemy snapshot the
-- server pushes over the EnemySnapshot UnreliableRemoteEvent and the client (A2.4) decodes for its pooled renderers.
-- One snapshot is split into packets of at most MAX_PER_PACKET enemies, so no packet passes the unreliable payload limit
-- (MAX_BYTES); every packet of a snapshot carries the same Seq and T. Layout, little-endian:
--   header  seq u16 · t f32 (SimulationClock seconds of the snapshot) · count u8
--   record  id u16 · def u8 · x f32 · y f32 · z f32 · yaw u8 · state u8 · hpPct u8      (18 bytes)
-- Positions are world studs (feet). `def` is the 1-based index of the enemy's DefId in DEF_IDS order, the sorted Ids of
-- Shared/Definitions/Enemies (both sides load the same registry). `yaw` is the heading in 256 steps (0 = facing -Z,
-- CFrame.Angles(0, yaw, 0)); `state` indexes STATES; `hpPct` is 0..100, rounded up so a living enemy never shows 0.
--   EnemySnapshot.pack(seq, t, rows) → { buffer }      server; throws "[Snapshot] ..." on a bad row (a server bug)
--   EnemySnapshot.unpack(b) → (Packet?, reason?)       client; never throws on junk bytes
--   EnemySnapshot.encodeYaw / decodeYaw / hpPct / defIndex / stateIndex

export type State = "Spawn" | "Pursue" | "Telegraph" | "Attack" | "Recover" | "Stagger" | "Dying"

export type Row = {
	Id: number,
	DefId: string,
	Position: Vector3,
	Yaw: number,
	State: State,
	Health: number,
	MaxHealth: number,
}

export type Record = {
	Id: number,
	Def: number,
	Position: Vector3,
	Yaw: number,
	State: number,
	HpPct: number,
}

export type Packet = { Seq: number, T: number, Records: { Record } }

local HEADER = 7
local RECORD = 18
local MAX_BYTES = 900 -- the UnreliableRemoteEvent payload limit; bigger payloads are dropped by the engine
local MAX_PER_PACKET = (MAX_BYTES - HEADER) // RECORD -- 49
local TAU = 2 * math.pi
local F32_MAX = 3.4028234663852886e38

local STATES: { State } = { "Spawn", "Pursue", "Telegraph", "Attack", "Recover", "Stagger", "Dying" }
local stateIndex: { [string]: number } = {}
for i, s in STATES do
	stateIndex[s] = i - 1
end

local function enemyIds(): { string }
	local ids: { string } = {}
	local folder = script.Parent.Parent:FindFirstChild("Definitions")
	local enemies = folder and folder:FindFirstChild("Enemies")
	if enemies then
		for _, child in enemies:GetChildren() do
			if child:IsA("ModuleScript") then
				table.insert(ids, child.Name)
			end
		end
	end
	table.sort(ids)
	return ids
end

local DEF_IDS = table.freeze(enemyIds())
local defIndexOf: { [string]: number } = {}
for i, id in DEF_IDS do
	defIndexOf[id] = i
end

local function fail(message: string): never
	error("[Snapshot] " .. message, 0)
end

local function finite(x: number): boolean
	return x == x and x ~= math.huge and x ~= -math.huge
end

local EnemySnapshot = {
	HEADER = HEADER,
	RECORD = RECORD,
	MAX_BYTES = MAX_BYTES,
	MAX_PER_PACKET = MAX_PER_PACKET,
	STATES = table.freeze(STATES),
	DEF_IDS = DEF_IDS,
}

function EnemySnapshot.encodeYaw(yaw: number): number
	return math.floor((yaw % TAU) / TAU * 256 + 0.5) % 256
end

function EnemySnapshot.decodeYaw(byte: number): number
	return byte / 256 * TAU
end

function EnemySnapshot.hpPct(health: number, maxHealth: number): number
	if maxHealth <= 0 or health <= 0 then
		return 0
	end
	return math.clamp(math.ceil(health / maxHealth * 100), 1, 100)
end

function EnemySnapshot.defIndex(defId: string): number?
	return defIndexOf[defId]
end

function EnemySnapshot.stateIndex(state: string): number?
	return stateIndex[state]
end

function EnemySnapshot.pack(seq: number, t: number, rows: { Row }): { buffer }
	if typeof(seq) ~= "number" or seq % 1 ~= 0 or seq < 0 or seq > 65535 then
		fail(`seq must be a whole number 0..65535, got {tostring(seq)}`)
	end
	if typeof(t) ~= "number" or not finite(t) or math.abs(t) > F32_MAX then
		fail(`t must be a finite number, got {tostring(t)}`)
	end
	local packets: { buffer } = {}
	local total = #rows
	local first = 1
	repeat
		local count = math.min(MAX_PER_PACKET, total - first + 1)
		local b = buffer.create(HEADER + count * RECORD)
		buffer.writeu16(b, 0, seq)
		buffer.writef32(b, 2, t)
		buffer.writeu8(b, 6, count)
		local at = HEADER
		for i = first, first + count - 1 do
			local row = rows[i]
			local def = defIndexOf[row.DefId]
			local state = stateIndex[row.State]
			local p = row.Position
			if typeof(row.Id) ~= "number" or row.Id % 1 ~= 0 or row.Id < 1 or row.Id > 65535 then
				fail(`row {i}: Id must be a whole number 1..65535, got {tostring(row.Id)}`)
			end
			if def == nil then
				fail(`row {i}: unknown DefId {tostring(row.DefId)}`)
			end
			if state == nil then
				fail(`row {i}: unknown State {tostring(row.State)}`)
			end
			if typeof(p) ~= "Vector3" or not (finite(p.X) and finite(p.Y) and finite(p.Z)) then
				fail(`row {i}: Position must be a finite Vector3`)
			end
			if typeof(row.Yaw) ~= "number" or not finite(row.Yaw) then
				fail(`row {i}: Yaw must be finite`)
			end
			buffer.writeu16(b, at, row.Id)
			buffer.writeu8(b, at + 2, def)
			buffer.writef32(b, at + 3, p.X)
			buffer.writef32(b, at + 7, p.Y)
			buffer.writef32(b, at + 11, p.Z)
			buffer.writeu8(b, at + 15, EnemySnapshot.encodeYaw(row.Yaw))
			buffer.writeu8(b, at + 16, state)
			buffer.writeu8(b, at + 17, EnemySnapshot.hpPct(row.Health, row.MaxHealth))
			at += RECORD
		end
		table.insert(packets, b)
		first += count
	until first > total
	return packets
end

function EnemySnapshot.unpack(b: unknown): (Packet?, string?)
	if typeof(b) ~= "buffer" then
		return nil, `expected a buffer, got {typeof(b)}`
	end
	local data = b :: buffer
	local len = buffer.len(data)
	if len < HEADER then
		return nil, `{len} bytes is shorter than the {HEADER}-byte header`
	end
	if len > MAX_BYTES then
		return nil, `{len} bytes exceeds {MAX_BYTES}`
	end
	local count = buffer.readu8(data, 6)
	if count > MAX_PER_PACKET then
		return nil, `count {count} exceeds {MAX_PER_PACKET}`
	end
	if len ~= HEADER + count * RECORD then
		return nil, `{len} bytes does not hold {count} records`
	end
	local t = buffer.readf32(data, 2)
	if not finite(t) then
		return nil, "t is not finite"
	end
	local records: { Record } = table.create(count)
	local at = HEADER
	for i = 1, count do
		local def = buffer.readu8(data, at + 2)
		local x, y, z = buffer.readf32(data, at + 3), buffer.readf32(data, at + 7), buffer.readf32(data, at + 11)
		local state = buffer.readu8(data, at + 16)
		local hp = buffer.readu8(data, at + 17)
		if def < 1 or def > #DEF_IDS then
			return nil, `record {i}: def {def} is not an enemy definition`
		end
		if not (finite(x) and finite(y) and finite(z)) then
			return nil, `record {i}: position is not finite`
		end
		if state >= #STATES then
			return nil, `record {i}: state {state} is not a state`
		end
		if hp > 100 then
			return nil, `record {i}: hpPct {hp} is above 100`
		end
		records[i] = {
			Id = buffer.readu16(data, at),
			Def = def,
			Position = Vector3.new(x, y, z),
			Yaw = EnemySnapshot.decodeYaw(buffer.readu8(data, at + 15)),
			State = state,
			HpPct = hp,
		}
		at += RECORD
	end
	return { Seq = buffer.readu16(data, 0), T = t, Records = records }, nil
end

return table.freeze(EnemySnapshot)
