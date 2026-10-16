--!strict
-- Net/Guard (architecture §19, docs/API_CONTRACTS.md Rules): hand-written type guards for remote payloads.
-- A guard is a function (value) -> (ok, reason?). It never throws and never trusts the shape of what it gets: wrong types,
-- NaN, inf, out-of-range numbers, oversized strings/arrays/maps, unknown record fields, sparse arrays and tables with
-- metatables are all rejected before any game logic runs. Builders are checked when the guard is built (a contract with a
-- malformed guard fails at require time).

export type Check = (value: unknown) -> (boolean, string?)

export type NumberOptions = { min: number?, max: number?, integer: boolean? }
export type VectorOptions = { maxMagnitude: number?, unit: boolean? }

local UNIT_TOLERANCE = 1e-3

local function fail(message: string): never
	error("[Guard] " .. message, 0)
end

local function finite(x: number): boolean
	return x == x and x ~= math.huge and x ~= -math.huge
end

local function plainTable(value: unknown): boolean
	return typeof(value) == "table" and getmetatable(value :: any) == nil
end

local function checkBound(name: string, x: number?)
	if x ~= nil and not finite(x) then
		fail(`{name} must be finite`)
	end
end

local Guard = {}

function Guard.number(options: NumberOptions?): Check
	local min = options and options.min
	local max = options and options.max
	local integer = options ~= nil and options.integer == true
	checkBound("min", min)
	checkBound("max", max)
	if min and max and min > max then
		fail(`min {min} is above max {max}`)
	end
	return function(value: unknown): (boolean, string?)
		if typeof(value) ~= "number" then
			return false, `expected number, got {typeof(value)}`
		end
		local n = value :: number
		if not finite(n) then
			return false, "number is not finite"
		end
		if integer and n % 1 ~= 0 then
			return false, `{n} is not a whole number`
		end
		if min and n < min then
			return false, `{n} is below {min}`
		end
		if max and n > max then
			return false, `{n} is above {max}`
		end
		return true, nil
	end
end

function Guard.integer(min: number, max: number): Check
	return Guard.number({ min = min, max = max, integer = true })
end

function Guard.boolean(): Check
	return function(value: unknown): (boolean, string?)
		if typeof(value) ~= "boolean" then
			return false, `expected boolean, got {typeof(value)}`
		end
		return true, nil
	end
end

-- A string of at most maxLength bytes; empty only when allowEmpty.
function Guard.string(maxLength: number, allowEmpty: boolean?): Check
	if maxLength % 1 ~= 0 or maxLength < 1 then
		fail("string maxLength must be a whole number ≥ 1")
	end
	return function(value: unknown): (boolean, string?)
		if typeof(value) ~= "string" then
			return false, `expected string, got {typeof(value)}`
		end
		local s = value :: string
		if #s > maxLength then
			return false, `string of {#s} bytes exceeds {maxLength}`
		end
		if #s == 0 and not allowEmpty then
			return false, "string is empty"
		end
		return true, nil
	end
end

-- One of the given string literals.
function Guard.literal(...: string): Check
	local options = { ... }
	if #options == 0 then
		fail("literal needs at least one option")
	end
	local label = table.concat(options, "|")
	return function(value: unknown): (boolean, string?)
		if typeof(value) ~= "string" or table.find(options, value :: string) == nil then
			return false, `expected {label}, got {tostring(value)}`
		end
		return true, nil
	end
end

function Guard.vector3(options: VectorOptions?): Check
	local maxMagnitude = options and options.maxMagnitude
	local unit = options ~= nil and options.unit == true
	checkBound("maxMagnitude", maxMagnitude)
	return function(value: unknown): (boolean, string?)
		if typeof(value) ~= "Vector3" then
			return false, `expected Vector3, got {typeof(value)}`
		end
		local v = value :: Vector3
		if not (finite(v.X) and finite(v.Y) and finite(v.Z)) then
			return false, "Vector3 is not finite"
		end
		local magnitude = v.Magnitude
		if unit and math.abs(magnitude - 1) > UNIT_TOLERANCE then
			return false, `Vector3 magnitude {magnitude} is not 1`
		end
		if maxMagnitude and magnitude > maxMagnitude then
			return false, `Vector3 magnitude {magnitude} exceeds {maxMagnitude}`
		end
		return true, nil
	end
end

function Guard.buffer(maxBytes: number): Check
	if maxBytes % 1 ~= 0 or maxBytes < 1 then
		fail("buffer maxBytes must be a whole number ≥ 1")
	end
	return function(value: unknown): (boolean, string?)
		if typeof(value) ~= "buffer" then
			return false, `expected buffer, got {typeof(value)}`
		end
		if buffer.len(value :: buffer) > maxBytes then
			return false, `buffer of {buffer.len(value :: buffer)} bytes exceeds {maxBytes}`
		end
		return true, nil
	end
end

-- nil, or a value the inner guard accepts.
function Guard.optional(inner: Check): Check
	return function(value: unknown): (boolean, string?)
		if value == nil then
			return true, nil
		end
		return inner(value)
	end
end

function Guard.oneOf(...: Check): Check
	local options = { ... }
	if #options < 2 then
		fail("oneOf needs at least two guards")
	end
	return function(value: unknown): (boolean, string?)
		local reasons: { string } = {}
		for _, check in options do
			local ok, reason = check(value)
			if ok then
				return true, nil
			end
			table.insert(reasons, reason or "?")
		end
		return false, `no option matched ({table.concat(reasons, "; ")})`
	end
end

-- A table with exactly these fields (optional ones may be absent) and nothing else.
function Guard.record(fields: { [string]: Check }): Check
	local count = 0
	for name, check in fields do
		if typeof(name) ~= "string" or typeof(check) ~= "function" then
			fail("record fields map names to guards")
		end
		count += 1
	end
	if count == 0 then
		fail("a record needs at least one field (use Guard.empty for {})")
	end
	return function(value: unknown): (boolean, string?)
		if not plainTable(value) then
			return false, `expected table, got {typeof(value)}`
		end
		local t = value :: { [unknown]: unknown }
		for key in t do
			if typeof(key) ~= "string" or fields[key :: string] == nil then
				return false, `unknown field {tostring(key)}`
			end
		end
		for name, check in fields do
			local ok, reason = check(t[name])
			if not ok then
				return false, `{name}: {reason}`
			end
		end
		return true, nil
	end
end

-- The empty table {} (payload of requests with no fields).
function Guard.empty(): Check
	return function(value: unknown): (boolean, string?)
		if not plainTable(value) then
			return false, `expected table, got {typeof(value)}`
		end
		if next(value :: { [unknown]: unknown }) ~= nil then
			return false, "expected an empty table"
		end
		return true, nil
	end
end

-- A dense array 0..maxLength long whose items all pass.
function Guard.array(item: Check, maxLength: number): Check
	if maxLength % 1 ~= 0 or maxLength < 1 then
		fail("array maxLength must be a whole number ≥ 1")
	end
	return function(value: unknown): (boolean, string?)
		if not plainTable(value) then
			return false, `expected array, got {typeof(value)}`
		end
		local t = value :: { [unknown]: unknown }
		local count = 0
		for key in t do
			count += 1
			if count > maxLength then
				return false, `array exceeds {maxLength} items`
			end
			if typeof(key) ~= "number" or (key :: number) % 1 ~= 0 or (key :: number) < 1 then
				return false, `array key {tostring(key)}`
			end
		end
		for i = 1, count do
			if t[i] == nil then
				return false, "array is sparse"
			end
			local ok, reason = item(t[i])
			if not ok then
				return false, `[{i}]: {reason}`
			end
		end
		return true, nil
	end
end

-- A map with at most maxEntries entries whose keys and values pass.
function Guard.map(key: Check, value: Check, maxEntries: number): Check
	if maxEntries % 1 ~= 0 or maxEntries < 1 then
		fail("map maxEntries must be a whole number ≥ 1")
	end
	return function(input: unknown): (boolean, string?)
		if not plainTable(input) then
			return false, `expected map, got {typeof(input)}`
		end
		local count = 0
		for k, v in input :: { [unknown]: unknown } do
			count += 1
			if count > maxEntries then
				return false, `map exceeds {maxEntries} entries`
			end
			local okKey, keyReason = key(k)
			if not okKey then
				return false, `key: {keyReason}`
			end
			local okValue, valueReason = value(v)
			if not okValue then
				return false, `[{tostring(k)}]: {valueReason}`
			end
		end
		return true, nil
	end
end

return table.freeze(Guard)
