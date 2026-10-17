--!strict
-- DEADZONE mirror export, Studio side (A1.3). See docs/MIRROR.md.
-- Paste this whole file into execute_luau (datamodel Edit). It returns one JSON string:
--   manifest  every script and StringValue under the 4 roots: studio path, class, byte length, FNV-1a
--   tree      the 4 roots (every instance, for mirror/sourcemap.json)
--   sources   source text, sorted by path from START, as many as fit under LIMIT characters
--   next      index to pass as START on the next call, or absent when the export is complete
--   errors    anything that would break the one-to-one mapping; tools/mirror_write.py refuses to write if non-empty
-- Read-only: it changes nothing in the place.

local START = 1 -- first source to send (1-based, in manifest order); set to the previous result's `next`
local INCLUDE_VENDOR = false -- true also sends */Vendor/* sources (only needed when a vendor module changed)
local MANIFEST_ONLY = false -- true sends no sources: the mirror files already hold them (hash-checked drafts, A2.4); every file is still verified
local LIMIT = 95000 -- execute_luau truncates results near 100K characters
local PAD_TO = 66000 -- smaller results are padded so the harness saves them to a file instead of inlining them

local HttpService = game:GetService("HttpService")

type Entry = { path: string, className: string, len: number, hash: string, vendor: boolean }
type Node = { name: string, className: string, studioPath: string?, children: { Node }? }

local starterPlayerScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ROOTS: { { name: string, service: string, inst: Instance? } } = {
	{ name = "Shared", service = "ReplicatedStorage", inst = game:GetService("ReplicatedStorage"):FindFirstChild("Shared") },
	{ name = "Server", service = "ServerScriptService", inst = game:GetService("ServerScriptService"):FindFirstChild("Server") },
	{ name = "Client", service = "StarterPlayerScripts", inst = starterPlayerScripts and starterPlayerScripts:FindFirstChild("Client") },
	{ name = "Tests", service = "ServerStorage", inst = game:GetService("ServerStorage"):FindFirstChild("Tests") },
}

local errors: { string } = {}
local entries: { Entry } = {}
local bodies: { [string]: string } = {}

-- FNV-1a 32-bit. 16777619 = 2^24 + 403; split so the product stays exact in a double.
local function fnv(s: string): string
	local h = 2166136261
	for i = 1, #s do
		h = bit32.bxor(h, string.byte(s, i))
		h = (bit32.lshift(h, 24) + h * 403) % 4294967296
	end
	return string.format("%08x", h)
end

local function exported(inst: Instance): boolean
	return inst:IsA("LuaSourceContainer") or inst:IsA("StringValue")
end

local function walk(inst: Instance, path: string): Node
	local node: Node = { name = inst.Name, className = inst.ClassName }
	if inst.Name:find('[<>:"/\\|%?%*%c]') or inst.Name:find("[%. ]$") or inst.Name == "" then
		table.insert(errors, "name not usable as a file name: " .. path)
	end
	if exported(inst) then
		node.studioPath = path
		local text = if inst:IsA("StringValue") then inst.Value else (inst :: any).Source :: string
		table.insert(entries, {
			path = path,
			className = inst.ClassName,
			len = #text,
			hash = fnv(text),
			vendor = path:find("/Vendor/", 1, true) ~= nil,
		})
		bodies[path] = text
		for _, d in inst:GetDescendants() do
			if exported(d) then
				table.insert(errors, "nested script/StringValue not supported: " .. d:GetFullName())
			end
		end
	end
	local seen: { [string]: boolean } = {}
	local kids: { Node } = {}
	for _, c in inst:GetChildren() do
		local key = c.Name:lower()
		if seen[key] then
			table.insert(errors, "duplicate sibling name (case-insensitive): " .. path .. "/" .. c.Name)
		end
		seen[key] = true
		table.insert(kids, walk(c, path .. "/" .. c.Name))
	end
	table.sort(kids, function(a: Node, b: Node): boolean
		return a.name < b.name
	end)
	if #kids > 0 then
		node.children = kids
	end
	return node
end

local tree: { [string]: any } = {}
for _, r in ROOTS do
	if r.inst then
		local n = walk(r.inst :: Instance, r.name)
		tree[r.name] = { service = r.service, node = n }
	else
		table.insert(errors, "root missing: " .. r.service .. "/" .. r.name)
	end
end
table.sort(entries, function(a: Entry, b: Entry): boolean
	return a.path < b.path
end)

-- Every script in the place must live under a root; count them all as the one-to-one reference.
local insideRoots = 0
local dataModelScripts = 0
for _, svc in game:GetChildren() do
	local ok, all = pcall(function()
		return svc:GetDescendants()
	end)
	if ok then
		for _, d in all do
			if d:IsA("LuaSourceContainer") then
				dataModelScripts += 1
				local underRoot = false
				for _, r in ROOTS do
					if r.inst and d:IsDescendantOf(r.inst :: Instance) then
						underRoot = true
					end
				end
				if underRoot then
					insideRoots += 1
				else
					table.insert(errors, "script outside the mirrored roots: " .. d:GetFullName())
				end
			end
		end
	end
end

local manifest = {}
for _, e in entries do
	table.insert(manifest, { path = e.path, className = e.className, len = e.len, hash = e.hash })
end
local out: { [string]: any } = {
	format = 1,
	placeId = game.PlaceId,
	dataModelScripts = dataModelScripts,
	scriptsUnderRoots = insideRoots,
	includeVendor = INCLUDE_VENDOR,
	start = START,
	manifest = manifest,
	tree = tree,
	errors = errors,
	sources = {},
}

local used = #HttpService:JSONEncode(out) + 64
local sources: { [string]: string } = {}
local sent = 0
local i = if MANIFEST_ONLY then #entries + 1 else START
while i <= #entries do
	local e = entries[i]
	if e.vendor and not INCLUDE_VENDOR then
		i += 1
		continue
	end
	local cost = #HttpService:JSONEncode(bodies[e.path]) + #e.path + 4
	if used + cost > LIMIT then
		if sent == 0 then
			table.insert(errors, "source too large for one call: " .. e.path)
			i += 1
		end
		break
	end
	sources[e.path] = bodies[e.path]
	used += cost
	sent += 1
	i += 1
end
out.sources = sources
out.sent = sent
for j = i, #entries do
	if INCLUDE_VENDOR or not entries[j].vendor then
		out.next = i -- more to send: run again with START = next
		break
	end
end

local json = HttpService:JSONEncode(out)
if #json < PAD_TO then
	out.pad = string.rep(" ", PAD_TO - #json)
	json = HttpService:JSONEncode(out)
end
return json
