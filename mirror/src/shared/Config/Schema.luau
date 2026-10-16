--!strict
-- Config/Schema (architecture §4.3 Config, §20): the shape of feature flags and tunables. Each entry has a typed default;
-- an override (from the `Config` DataStore, RemoteConfigService) is accepted only when it has the default's type and
-- passes the entry's bounds. Flags and Tunables check their tables with `Schema.build` at require time, so a malformed
-- entry fails the boot.

export type Value = boolean | number | string

export type Entry = {
	Default: Value,
	Description: string,
	Since: string, -- substage that added it
	Client: boolean?, -- flags only: replicated to clients through FlagsUpdate
	Min: number?, -- numbers
	Max: number?,
	Integer: boolean?,
	Options: { string }?, -- strings: the allowed values
}

local MAX_NAME = 64
local MAX_STRING = 200

local function finite(x: number): boolean
	return x == x and x ~= math.huge and x ~= -math.huge
end

local Schema = { MAX_NAME = MAX_NAME, MAX_STRING = MAX_STRING }

-- Whether value may replace entry's default; reason when it may not.
function Schema.check(entry: Entry, value: unknown): (boolean, string?)
	local kind = typeof(entry.Default)
	if typeof(value) ~= kind then
		return false, `expected {kind}, got {typeof(value)}`
	end
	if kind == "number" then
		local n = value :: number
		if not finite(n) then
			return false, "number is not finite"
		end
		if entry.Integer and n % 1 ~= 0 then
			return false, `{n} is not a whole number`
		end
		if entry.Min and n < entry.Min then
			return false, `{n} is below {entry.Min}`
		end
		if entry.Max and n > entry.Max then
			return false, `{n} is above {entry.Max}`
		end
	elseif kind == "string" then
		local s = value :: string
		if #s > MAX_STRING then
			return false, `string of {#s} bytes exceeds {MAX_STRING}`
		end
		if entry.Options and table.find(entry.Options, s) == nil then
			return false, `{s} is not one of {table.concat(entry.Options, ", ")}`
		end
	end
	return true, nil
end

-- Every problem in a table of entries (empty when valid). allowClient: whether `Client` may be set (flags only).
function Schema.problems(entries: { [string]: Entry }, allowClient: boolean): { string }
	local problems: { string } = {}
	for name, entry in entries do
		if typeof(name) ~= "string" or not string.match(name, "^%u%w*$") or #name > MAX_NAME then
			table.insert(problems, `{tostring(name)}: names are PascalCase letters and digits, at most {MAX_NAME} bytes`)
			continue
		end
		if typeof(entry) ~= "table" then
			table.insert(problems, `{name}: not a table`)
			continue
		end
		local kind = typeof(entry.Default)
		if kind ~= "boolean" and kind ~= "number" and kind ~= "string" then
			table.insert(problems, `{name}: Default must be a boolean, number or string`)
			continue
		end
		if typeof(entry.Description) ~= "string" or entry.Description == "" then
			table.insert(problems, `{name}: Description is required`)
		end
		if typeof(entry.Since) ~= "string" or not string.match(entry.Since, "^%u%d+%.%d+$") then
			table.insert(problems, `{name}: Since must be a substage id such as A1.8`)
		end
		if entry.Client ~= nil and (not allowClient or typeof(entry.Client) ~= "boolean") then
			table.insert(problems, `{name}: Client is a boolean, on flags only`)
		end
		if kind ~= "number" and (entry.Min ~= nil or entry.Max ~= nil or entry.Integer ~= nil) then
			table.insert(problems, `{name}: Min/Max/Integer apply to numbers only`)
		end
		if kind ~= "string" and entry.Options ~= nil then
			table.insert(problems, `{name}: Options apply to strings only`)
		end
		if entry.Min and entry.Max and entry.Min > entry.Max then
			table.insert(problems, `{name}: Min is above Max`)
		end
		local ok, reason = Schema.check(entry, entry.Default)
		if not ok then
			table.insert(problems, `{name}: Default fails its own bounds ({reason})`)
		end
		for key in (entry :: any) :: { [string]: unknown } do
			if not table.find({ "Default", "Description", "Since", "Client", "Min", "Max", "Integer", "Options" }, key) then
				table.insert(problems, `{name}: unknown field {key}`)
			end
		end
	end
	table.sort(problems)
	return problems
end

-- Checks and deep-freezes a table of entries; throws one "[Config] ..." error listing every problem.
function Schema.build(label: string, entries: { [string]: Entry }, allowClient: boolean): { [string]: Entry }
	local problems = Schema.problems(entries, allowClient)
	if #problems > 0 then
		error(`[Config] {#problems} problems in {label}:\n- {table.concat(problems, "\n- ")}`, 0)
	end
	for _, entry in entries do
		if entry.Options then
			table.freeze(entry.Options)
		end
		table.freeze(entry)
	end
	return table.freeze(entries)
end

return table.freeze(Schema)
