--!strict
-- Controllers/EnemyController (architecture §6.4, §7.2, §8.1; API_CONTRACTS EnemySnapshot): the client's latest view of
-- the enemies in its arena, from the server's EnemySnapshot packets (A2.3). Each packet is decoded by Net/EnemySnapshot;
-- a malformed packet is dropped and counted, never trusted. Records are keyed by enemy id and keep the snapshot time T
-- (SimulationClock seconds), so an older packet arriving late never overwrites a newer one; an enemy missing from every
-- snapshot for STALE_SECONDS is forgotten. Presentation only: the one message back is RequestEnemySnapshots, sent once
-- the handler is connected, because the server streams only to subscribed clients (an unreliable event that reaches a
-- client with no handler is discarded with a console error).
--   EnemyController.enemies() → { [id]: View }      the latest record per enemy (read-only)
--   EnemyController.count() → number
--   EnemyController.stats() → { Packets, Dropped, Snapshots }
-- It also feeds InputController's auto-aim (A2.1 target provider): the nearest known enemy within AIM_RANGE of the aim
-- origin. Pooled renderers and interpolation build on this in A2.4.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemySnapshot = require(ReplicatedStorage.Shared.Net.EnemySnapshot)
local InputController = require(script.Parent.InputController)

export type View = {
	Id: number,
	DefId: string,
	Position: Vector3,
	Yaw: number,
	State: EnemySnapshot.State,
	HpPct: number,
	T: number, -- snapshot SimulationClock time
	SeenAt: number, -- os.clock() of the packet that last carried it
}

local REMOTE = "EnemySnapshot"
local SUBSCRIBE = "RequestEnemySnapshots"
local NET_WAIT_SECONDS = 30
local STALE_SECONDS = 1
local AIM_RANGE = 60 -- studs; the auto-aim reach of A2.1 (D-023 point 4)
local WARN_EVERY = 10 -- s between malformed-packet warnings

local views: { [number]: View } = {}
local alive = 0
local packets, dropped, snapshots = 0, 0, 0
local lastSeq = -1
local lastWarn = -math.huge
local lastPrune = 0

local EnemyController = { Name = "EnemyController" }

function EnemyController.enemies(): { [number]: View }
	return views
end

function EnemyController.count(): number
	return alive
end

function EnemyController.stats(): { Packets: number, Dropped: number, Snapshots: number }
	return { Packets = packets, Dropped = dropped, Snapshots = snapshots }
end

local function prune(now: number)
	for id, view in views do
		if now - view.SeenAt > STALE_SECONDS then
			views[id] = nil
			alive -= 1
		end
	end
end

local function nearest(origin: Vector3): Vector3?
	local best: Vector3? = nil
	local bestD2 = AIM_RANGE * AIM_RANGE
	for _, view in views do
		if view.State == "Dying" then
			continue
		end
		local d = view.Position - origin
		local d2 = d.X * d.X + d.Z * d.Z
		if d2 < bestD2 then
			best, bestD2 = view.Position, d2
		end
	end
	return best
end

local function onPacket(payload: unknown)
	local packet, reason = EnemySnapshot.unpack(payload)
	if packet == nil then
		dropped += 1
		local now = os.clock()
		if now - lastWarn >= WARN_EVERY then
			lastWarn = now
			warn(`[Enemy] dropped a malformed {REMOTE} packet ({dropped} so far): {reason}`)
		end
		return
	end
	packets += 1
	if packet.Seq ~= lastSeq then
		lastSeq = packet.Seq
		snapshots += 1
	end
	local now = os.clock()
	for _, record in packet.Records do
		local view = views[record.Id]
		if view and view.T > packet.T then
			continue -- a late packet; the newer state stays
		end
		if view == nil then
			alive += 1
		end
		views[record.Id] = {
			Id = record.Id,
			DefId = EnemySnapshot.DEF_IDS[record.Def],
			Position = record.Position,
			Yaw = record.Yaw,
			State = EnemySnapshot.STATES[record.State + 1],
			HpPct = record.HpPct,
			T = packet.T,
			SeenAt = now,
		}
	end
	if now - lastPrune >= STALE_SECONDS / 2 then
		lastPrune = now
		prune(now)
	end
end

-- Waits for the Net folder (server boot phase 8), listens for snapshots and hands auto-aim its targets.
function EnemyController.start()
	InputController.setTargetProvider(nearest)
	local net = ReplicatedStorage:WaitForChild("Net", NET_WAIT_SECONDS)
	local remote = net and net:WaitForChild(REMOTE, NET_WAIT_SECONDS)
	if remote == nil or not remote:IsA("UnreliableRemoteEvent") then
		warn(`[Enemy] ReplicatedStorage.Net.{REMOTE} did not appear within {NET_WAIT_SECONDS} s; no enemies will show`)
		return
	end
	remote.OnClientEvent:Connect(onPacket)
	local subscribe = (net :: Instance):WaitForChild(SUBSCRIBE, NET_WAIT_SECONDS)
	if subscribe == nil or not subscribe:IsA("RemoteEvent") then
		warn(`[Enemy] ReplicatedStorage.Net.{SUBSCRIBE} did not appear within {NET_WAIT_SECONDS} s; no enemies will show`)
		return
	end
	subscribe:FireServer({})
end

return table.freeze(EnemyController)
