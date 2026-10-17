--!strict
-- Net/ClientHeartbeat (architecture §7.1; docs/API_CONTRACTS.md `ClientHeartbeat`): the client's periodic report of the
-- SimulationClock time it is drawing enemies at (its render time), sent over the ClientHeartbeat UnreliableRemoteEvent.
-- The server turns arrival time minus that time into the player's view lag (snapshot delay + render delay + one-way
-- trip) and bounds the rewind of that player's attacks by it (Combat/Lib/LagCompensation). A hint, never truth.
-- Layout, little-endian, exactly SIZE bytes: seq u32 · clientTime f64.
--   ClientHeartbeat.pack(seq, clientTime) → buffer
--   ClientHeartbeat.unpack(b) → (seq?, clientTime?, reason?)   never throws on junk bytes

local SIZE = 12
local MAX_SEQ = 4294967295

local ClientHeartbeat = { SIZE = SIZE, MAX_SEQ = MAX_SEQ }

function ClientHeartbeat.pack(seq: number, clientTime: number): buffer
	local b = buffer.create(SIZE)
	buffer.writeu32(b, 0, seq % (MAX_SEQ + 1))
	buffer.writef64(b, 4, clientTime)
	return b
end

function ClientHeartbeat.unpack(value: unknown): (number?, number?, string?)
	if typeof(value) ~= "buffer" then
		return nil, nil, `expected buffer, got {typeof(value)}`
	end
	local b = value :: buffer
	if buffer.len(b) ~= SIZE then
		return nil, nil, `heartbeat of {buffer.len(b)} bytes, expected {SIZE}`
	end
	local t = buffer.readf64(b, 4)
	if t ~= t or t == math.huge or t == -math.huge or t < 0 then
		return nil, nil, "clientTime is not a finite time ≥ 0"
	end
	return buffer.readu32(b, 0), t, nil
end

return table.freeze(ClientHeartbeat)
