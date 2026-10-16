--!strict
-- Controllers/FlagsController (architecture §20; API_CONTRACTS FlagsUpdate): the client's copy of the Client feature flags.
-- The server sends every Client flag once after phase 8 (and on join), then only changed flags. Each push is checked
-- with the FlagsUpdate contract guard; a malformed push is dropped with a warning. Unknown flags read as nil until the
-- first push arrives, so UI reads flags through get() with its own default.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contracts = require(ReplicatedStorage.Shared.Net.Contracts)

type Value = boolean | number | string

local REMOTE = "FlagsUpdate"
local NET_WAIT_SECONDS = 30

local values: { [string]: Value } = {}
local changed = Instance.new("BindableEvent")
local updates = 0

local FlagsController = {
	Name = "FlagsController",
	Changed = changed.Event, -- fires (names: { string }) after each accepted push
}

function FlagsController.get(name: string): Value?
	return values[name]
end

function FlagsController.updates(): number
	return updates
end

-- Waits for the Net folder (created in server boot phase 8) and listens for pushes.
function FlagsController.start()
	local net = ReplicatedStorage:WaitForChild("Net", NET_WAIT_SECONDS)
	local remote = net and net:WaitForChild(REMOTE, NET_WAIT_SECONDS)
	if remote == nil or not remote:IsA("RemoteEvent") then
		warn(`[Flags] ReplicatedStorage.Net.{REMOTE} did not appear within {NET_WAIT_SECONDS} s; flags stay unset`)
		return
	end
	local guard = Contracts.get(REMOTE).Payload
	remote.OnClientEvent:Connect(function(payload: unknown)
		local ok, reason = guard(payload)
		if not ok then
			warn(`[Flags] dropped a malformed {REMOTE}: {reason}`)
			return
		end
		local names: { string } = {}
		for name, value in payload :: { [string]: Value } do
			values[name] = value
			table.insert(names, name)
		end
		table.sort(names)
		updates += 1
		local parts: { string } = {}
		for _, name in names do
			table.insert(parts, `{name}={tostring(values[name])}`)
		end
		print(`[Flags] update {updates}: {if #parts > 0 then table.concat(parts, " ") else "none"}`)
		changed:Fire(names)
	end)
end

return table.freeze(FlagsController)
