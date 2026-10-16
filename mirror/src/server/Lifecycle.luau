--!strict
-- Lifecycle (architecture §5.2): the Init/Start contract, the canonical boot order and the assertions that guard it.
-- Bootstrap calls Lifecycle.boot(Domains); tests build plans by hand and call Lifecycle.run(plan).
-- Every violation raises "[Boot] ..." and stops the boot, so the server never starts half-built:
--   · the plan has phases 0–8 in order; each domain boots in its §5.2 phase and in §5.2 domain order;
--   · a service module returns { Name = <module name>, Init, Start }; names are unique and never a Roblox built-in service name;
--   · Init only resolves dependencies (Lifecycle.get) and must not yield; every Init completes before any Start;
--   · Lifecycle.get(name) only returns a service whose Init already ran, so a dependency booting later is an order error;
--   · the network step (phase 8) runs after every Start; Lifecycle.currentPhase() is 8 only while it runs, which is
--     how Server/Gateway refuses to create remotes anywhere else (A1.8).
-- Services inside a domain boot in name order. The domain API module (§5.1 "init") arrives with the first domain that needs one.

export type Service = {
	Name: string,
	Init: (self: Service) -> (),
	Start: (self: Service) -> (),
}

export type Entry = { domain: string, service: Service }

export type PlanPhase = { index: number, name: string, entries: { Entry } }

export type Plan = { PlanPhase }

export type Hooks = {
	definitions: (() -> string)?, -- phase 3, during the Init pass (_Registry, A1.6)
	network: (() -> string)?, -- phase 8, after every Start (remotes, A1.8)
}

export type Report = {
	order: { string }, -- "Domain/Service" in boot order
	phaseLines: { string },
	initMs: number,
	startMs: number,
	totalMs: number,
}

type PhaseSpec = { index: number, name: string, domains: { string } }

local PHASES: { PhaseSpec } = table.freeze({
	table.freeze({ index = 0, name = "Platform", domains = table.freeze({ "Platform" }) }),
	table.freeze({ index = 1, name = "Telemetry", domains = table.freeze({ "Telemetry" }) }),
	table.freeze({ index = 2, name = "Data", domains = table.freeze({ "Data" }) }),
	table.freeze({ index = 3, name = "Definitions", domains = table.freeze({}) }),
	table.freeze({ index = 4, name = "Economy", domains = table.freeze({ "Economy" }) }),
	table.freeze({ index = 5, name = "Progression", domains = table.freeze({ "Progression" }) }),
	table.freeze({ index = 6, name = "Combat → Encounter", domains = table.freeze({ "Combat", "Encounter" }) }),
	table.freeze({ index = 7, name = "Social, Facilities, LiveOps", domains = table.freeze({ "Social", "Facilities", "LiveOps" }) }),
	table.freeze({ index = 8, name = "Network", domains = table.freeze({}) }),
})

local DEFINITIONS_PHASE = 3

local DOMAIN_PHASE: { [string]: number } = {}
local DOMAIN_RANK: { [string]: number } = {}
local DOMAIN_ORDER: { string } = {}
for _, spec in PHASES do
	for _, domain in spec.domains do
		table.insert(DOMAIN_ORDER, domain)
		DOMAIN_PHASE[domain] = spec.index
		DOMAIN_RANK[domain] = #DOMAIN_ORDER
	end
end

local Lifecycle = {
	PHASES = PHASES,
	DOMAIN_ORDER = table.freeze(DOMAIN_ORDER),
	DOMAIN_COUNT = 10,
}

-- Boot state, non-nil only during an Init pass. Init cannot yield, so one pass runs at a time.
local initialized: { [string]: Service }? = nil
local pending: { [string]: string } = {} -- service name -> "Domain/Name" for every service in the running plan
local currentId = "?"
local phaseNow: number? = nil -- the §5.2 phase being booted (Init pass, Start pass or network step); nil outside a boot

local function fail(message: string): never
	error("[Boot] " .. message, 0)
end

local function isBuiltinServiceName(name: string): boolean
	-- FindService succeeds (returning the service or nil) for every Roblox service class name and errors for any other name.
	return (pcall(game.FindService, game, name))
end

local function checkShape(service: unknown, id: string)
	if typeof(service) ~= "table" then
		fail(`{id} must be a table with Name, Init and Start, got {typeof(service)}`)
	end
	local fields = service :: { [string]: unknown }
	local name = fields.Name
	if typeof(name) ~= "string" or name == "" then
		fail(`{id}.Name must be a non-empty string`)
	end
	if typeof(fields.Init) ~= "function" then
		fail(`{id}.Init must be a function`)
	end
	if typeof(fields.Start) ~= "function" then
		fail(`{id}.Start must be a function`)
	end
	if isBuiltinServiceName(name :: string) then
		fail(`{id}: "{name}" is a Roblox built-in service name; pick another name (CLAUDE.md rule 14)`)
	end
end

-- Builds the boot plan from the domain folders: every ModuleScript directly inside a domain folder is a service
-- (subfolders such as Data/Vendor are not). Requires each service and checks its shape and Name.
function Lifecycle.plan(domainsFolder: Instance): Plan
	local plan: Plan = {}
	for _, spec in PHASES do
		local entries: { Entry } = {}
		for _, domain in spec.domains do
			local folder = domainsFolder:FindFirstChild(domain)
			if folder == nil then
				fail(`missing domain folder {domainsFolder:GetFullName()}.{domain}`)
			end
			local modules: { ModuleScript } = {}
			for _, child in (folder :: Instance):GetChildren() do
				if child:IsA("ModuleScript") then
					table.insert(modules, child)
				end
			end
			table.sort(modules, function(a: ModuleScript, b: ModuleScript): boolean
				return a.Name < b.Name
			end)
			for _, module in modules do
				local id = `{domain}/{module.Name}`
				local ok, result = pcall(require, module)
				if not ok then
					fail(`{id}: require failed: {tostring(result)}`)
				end
				checkShape(result, id)
				local service = result :: Service
				if service.Name ~= module.Name then
					fail(`{id}.Name is "{service.Name}"; it must equal the module name`)
				end
				table.insert(entries, { domain = domain, service = service })
			end
		end
		table.insert(plan, { index = spec.index, name = spec.name, entries = entries })
	end
	for _, child in domainsFolder:GetChildren() do
		if DOMAIN_PHASE[child.Name] == nil then
			fail(`domain folder {child.Name} is not in any §5.2 phase`)
		end
	end
	return plan
end

-- Checks a plan against §5.2 without running anything.
function Lifecycle.validate(plan: Plan)
	if #plan ~= #PHASES then
		fail(`order: the plan has {#plan} phases, §5.2 has {#PHASES}`)
	end
	local seen: { [string]: string } = {}
	local lastDomain: string? = nil
	for position, phase in plan do
		local spec = PHASES[position]
		if phase.index ~= spec.index then
			fail(`order: plan position {position} is phase {phase.index}, expected phase {spec.index} ({spec.name})`)
		end
		for _, entry in phase.entries do
			local service = entry.service
			local id = `{entry.domain}/{if typeof(service) == "table" then tostring(service.Name) else "?"}`
			local home = DOMAIN_PHASE[entry.domain]
			if home == nil then
				fail(`unknown domain "{entry.domain}" ({id})`)
			end
			if home ~= phase.index then
				fail(`order: {id} belongs to phase {home} ({entry.domain}) but is listed in phase {phase.index} ({phase.name})`)
			end
			if lastDomain ~= nil and DOMAIN_RANK[entry.domain] < DOMAIN_RANK[lastDomain] then
				fail(`order: {id} boots after {lastDomain}, but §5.2 boots {entry.domain} first ({table.concat(DOMAIN_ORDER, " → ")})`)
			end
			lastDomain = entry.domain
			checkShape(service, id)
			local previous = seen[service.Name]
			if previous ~= nil then
				fail(`duplicate service name "{service.Name}" ({previous} and {id})`)
			end
			seen[service.Name] = id
		end
	end
end

-- The §5.2 phase index the running boot is in, or nil when no boot is running. Phase 8 means the network step.
function Lifecycle.currentPhase(): number?
	return phaseNow
end

-- Resolves a dependency during Init. The target's Init must already have run (an earlier phase, or earlier in name order
-- inside the same domain). Keep the returned reference; get is not available after Init.
function Lifecycle.get(name: string): Service
	local done = initialized
	if done == nil then
		fail(`Lifecycle.get("{name}") called outside Init; resolve dependencies in Init and keep the reference`)
	end
	local service = (done :: { [string]: Service })[name]
	if service == nil then
		local target = pending[name]
		if target ~= nil then
			fail(`order: {currentId} resolved {target} during Init, but {target} has not initialized; a dependency must boot earlier`)
		end
		fail(`{currentId} resolved unknown service "{name}"`)
	end
	return service :: Service
end

local function callInit(service: Service, id: string)
	local thread = coroutine.create(service.Init)
	local ok, err = coroutine.resume(thread, service)
	if not ok then
		fail(`{id}:Init failed: {tostring(err)}`)
	end
	if coroutine.status(thread) ~= "dead" then
		coroutine.close(thread)
		fail(`{id}:Init yielded; Init only resolves dependencies and must not yield (wait in Start)`)
	end
end

local function phaseLine(phase: PlanPhase, note: string?): string
	local parts: { string } = {}
	for _, domain in PHASES[phase.index + 1].domains do
		local names: { string } = {}
		for _, entry in phase.entries do
			if entry.domain == domain then
				table.insert(names, entry.service.Name)
			end
		end
		table.insert(parts, `{domain} [{if #names > 0 then table.concat(names, ", ") else "no services"}]`)
	end
	if note ~= nil then
		table.insert(parts, note)
	end
	return `phase {phase.index} {phase.name}: {table.concat(parts, "; ")}`
end

-- Validates the plan, runs every Init in phase order, then every Start in phase order, then the network step.
function Lifecycle.run(plan: Plan, hooks: Hooks?): Report
	if initialized ~= nil then
		fail("a boot is already running (Lifecycle.run called from inside Init)")
	end
	local startedAt = os.clock()
	Lifecycle.validate(plan)

	local order: { string } = {}
	local notes: { [number]: string } = {}
	local names: { [string]: string } = {}
	for _, phase in plan do
		for _, entry in phase.entries do
			local id = `{entry.domain}/{entry.service.Name}`
			table.insert(order, id)
			names[entry.service.Name] = id
		end
	end

	-- Init pass. Boot state is reset whether it succeeds or not.
	local done: { [string]: Service } = {}
	initialized = done
	pending = names
	local initCount = 0
	local ok, err = pcall(function()
		for _, phase in plan do
			phaseNow = phase.index
			if phase.index == DEFINITIONS_PHASE and hooks and hooks.definitions then
				notes[phase.index] = hooks.definitions()
			end
			for _, entry in phase.entries do
				local id = `{entry.domain}/{entry.service.Name}`
				currentId = id
				callInit(entry.service, id)
				done[entry.service.Name] = entry.service
				initCount += 1
			end
		end
	end)
	initialized = nil
	pending = {}
	currentId = "?"
	if not ok then
		phaseNow = nil
		error(err, 0)
	end
	local initEndedAt = os.clock()

	-- No Start before every Init has completed.
	if initCount ~= #order then
		phaseNow = nil
		fail(`order: {initCount} of {#order} services initialized before the Start pass`)
	end
	local startEndedAt = os.clock()
	local finished, finishErr = pcall(function()
		for _, phase in plan do
			phaseNow = phase.index
			for _, entry in phase.entries do
				local service = entry.service
				local started, startErr = pcall(function()
					service:Start()
				end)
				if not started then
					fail(`{entry.domain}/{entry.service.Name}:Start failed: {tostring(startErr)}`)
				end
			end
		end
		startEndedAt = os.clock()

		phaseNow = #PHASES - 1
		if hooks and hooks.network then
			notes[#PHASES - 1] = hooks.network()
		end
	end)
	phaseNow = nil
	if not finished then
		error(finishErr, 0)
	end

	local phaseLines: { string } = {}
	for _, phase in plan do
		table.insert(phaseLines, phaseLine(phase, notes[phase.index]))
	end
	return {
		order = order,
		phaseLines = phaseLines,
		initMs = (initEndedAt - startedAt) * 1000,
		startMs = (startEndedAt - initEndedAt) * 1000,
		totalMs = (os.clock() - startedAt) * 1000,
	}
end

-- Plans the domain folders and runs the boot.
function Lifecycle.boot(domainsFolder: Instance, hooks: Hooks?): Report
	return Lifecycle.run(Lifecycle.plan(domainsFolder), hooks)
end

return Lifecycle
