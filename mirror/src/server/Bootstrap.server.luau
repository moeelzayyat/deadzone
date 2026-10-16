--!strict
-- Server Bootstrap (architecture §5.2).
-- A1.1: checks the §4.3 layout, walks boot phases 0–8 in order and logs the service list per phase.
-- The Init/Start contract and order assertions arrive in A1.4, _Registry in A1.6, remotes in A1.8.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

type Phase = {
	index: number,
	name: string,
	domains: { string },
}

local PHASES: { Phase } = {
	{ index = 0, name = "Platform", domains = { "Platform" } },
	{ index = 1, name = "Telemetry", domains = { "Telemetry" } },
	{ index = 2, name = "Data", domains = { "Data" } },
	{ index = 3, name = "Definitions", domains = {} },
	{ index = 4, name = "Economy", domains = { "Economy" } },
	{ index = 5, name = "Progression", domains = { "Progression" } },
	{ index = 6, name = "Combat → Encounter", domains = { "Combat", "Encounter" } },
	{ index = 7, name = "Social, Facilities, LiveOps", domains = { "Social", "Facilities", "LiveOps" } },
	{ index = 8, name = "Network", domains = {} },
}

local DOMAIN_COUNT = 10

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

-- A service is a ModuleScript directly inside its domain folder. Subfolders (e.g. Data/Vendor) are not services.
local function servicesIn(domainFolder: Instance): { string }
	local names: { string } = {}
	for _, child in domainFolder:GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(names, child.Name)
		end
	end
	table.sort(names)
	return names
end

local startedAt = os.clock()
local serverRoot = script.Parent :: Instance
local domainsFolder = requireChild(serverRoot, "Domains")
requireChild(serverRoot, "Admin")
local shared = requireChild(ReplicatedStorage, "Shared")
local definitions = requireChild(shared, "Definitions")

local ordered: { string } = {}
local seenDomains: { [string]: boolean } = {}
local domainTotal = 0

for expectedIndex, phase in PHASES do
	assert(phase.index == expectedIndex - 1, "[Boot] phase table out of order")
	local parts: { string } = {}
	for _, domainName in phase.domains do
		assert(not seenDomains[domainName], "[Boot] domain listed twice: " .. domainName)
		seenDomains[domainName] = true
		domainTotal += 1
		local services = servicesIn(requireChild(domainsFolder, domainName))
		for _, serviceName in services do
			table.insert(ordered, domainName .. "/" .. serviceName)
		end
		table.insert(parts, string.format("%s [%s]", domainName, if #services > 0 then table.concat(services, ", ") else "no services"))
	end
	if phase.index == 3 then
		local registry = definitions:FindFirstChild("_Registry")
		table.insert(parts, string.format("%d definition folders, _Registry %s", #definitions:GetChildren(), if registry then "present" else "not yet built"))
	elseif phase.index == 8 then
		table.insert(parts, string.format("%d remotes", countRemotes()))
	end
	print(string.format("[Boot] phase %d %s: %s", phase.index, phase.name, table.concat(parts, "; ")))
end

assert(domainTotal == DOMAIN_COUNT, string.format("[Boot] expected %d domains in the phase table, got %d", DOMAIN_COUNT, domainTotal))
for _, child in domainsFolder:GetChildren() do
	assert(seenDomains[child.Name], "[Boot] domain folder not in any phase: " .. child.Name)
end

print(string.format(
	"[Boot] phases 0–8 complete in %.2f ms · services (%d): %s",
	(os.clock() - startedAt) * 1000,
	#ordered,
	if #ordered > 0 then table.concat(ordered, " → ") else "none yet"
))
