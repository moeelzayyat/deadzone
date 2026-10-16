--!strict
-- Server Bootstrap (architecture §5.2).
-- Checks the §4.3 layout, then boots every domain service through Lifecycle (A1.4: Init/Start contract and order
-- assertions; any violation stops the boot). Phase 3 loads and validates every definition through _Registry (A1.6); a bad
-- definition stops the boot with a "[Definitions] ..." error listing every problem. After the Start pass it publishes
-- DefinitionsValidated and BootCompleted on the event bus (A1.5), so subscribers connected in Start receive both.
-- Remotes arrive in A1.8 (phase 8).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventBus = require(ReplicatedStorage.Shared.Events.EventBus)
local Lifecycle = require(script.Parent.Lifecycle)

local function requireChild(parent: Instance, name: string): Instance
	local child = parent:FindFirstChild(name)
	if child then
		return child
	end
	error(string.format("[Boot] missing %s.%s", parent:GetFullName(), name), 0)
end

-- Remotes are created in phase 8 only (A1.8); until then this must be 0.
local function countRemotes(): number
	local count = 0
	for _, d in ReplicatedStorage:GetDescendants() do
		if d:IsA("BaseRemoteEvent") or d:IsA("RemoteFunction") then
			count += 1
		end
	end
	return count
end

local serverRoot = script.Parent :: Instance
local domainsFolder = requireChild(serverRoot, "Domains")
requireChild(serverRoot, "Admin")
local shared = requireChild(ReplicatedStorage, "Shared")
local definitions = requireChild(shared, "Definitions")
requireChild(definitions, "_Registry")
local Registry = require(ReplicatedStorage.Shared.Definitions._Registry)

local definitionCount = 0

local report = Lifecycle.boot(domainsFolder, {
	definitions = function(): string
		local startedAt = os.clock()
		local registry = Registry.shared()
		definitionCount = registry.count
		return string.format(
			"%d definitions in %d folders validated in %.2f ms",
			registry.count,
			#Registry.KINDS,
			(os.clock() - startedAt) * 1000
		)
	end,
	network = function(): string
		return string.format("%d remotes", countRemotes())
	end,
})

for _, line in report.phaseLines do
	print("[Boot] " .. line)
end
print(string.format(
	"[Boot] phases 0–8 complete in %.2f ms (Init %.2f ms, Start %.2f ms) · services (%d): %s",
	report.totalMs,
	report.initMs,
	report.startMs,
	#report.order,
	if #report.order > 0 then table.concat(report.order, " → ") else "none yet"
))

-- Subscribers (Telemetry, A1.8+) connect in Start, so they are in place before these publishes.
local bus = EventBus.server()
bus:publisher("Definitions"):publish("DefinitionsValidated", { Count = definitionCount })
bus:publisher("Bootstrap"):publish("BootCompleted", { Phases = #Lifecycle.PHASES, Services = report.order })
print(string.format(
	"[Boot] DefinitionsValidated (%d) and BootCompleted published · %d and %d subscribers · bus %s",
	definitionCount,
	bus:subscriberCount("DefinitionsValidated"),
	bus:subscriberCount("BootCompleted"),
	if bus.strict then "strict" else "lenient"
))
