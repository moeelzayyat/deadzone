--!strict
-- Net/Codec (architecture §7.2, §23): `buffer` packing for high-rate remotes (snapshots, FX bursts, client heartbeats).
-- A layout is an ordered list of { name, type } fields; `Codec.struct(fields)` packs a record into a fixed byte layout and
-- `Codec.list(struct, countType)` packs `[count][record]...`. Field types:
--   u8 u16 u32 i8 i16 i32   integers, range-checked
--   f32 f64                 finite floats (f32 rounds to single precision)
--   bool                    one byte, 0 or 1
--   vector3                 three f32 (12 bytes)
--   string                  u16 byte length + bytes, at most `maxString` bytes (default 255)
-- Encoding is server code: a bad value is a bug and throws "[Codec] ...". Decoding reads untrusted bytes: it never throws
-- and returns nil plus a reason for a wrong length, a truncated record, NaN/inf, a bool byte other than 0/1, or an
-- oversized string or count.

export type FieldType = "u8" | "u16" | "u32" | "i8" | "i16" | "i32" | "f32" | "f64" | "bool" | "vector3" | "string"
export type Field = { name: string, type: FieldType }
export type Value = number | boolean | Vector3 | string
export type Record = { [string]: Value }

export type Struct = {
	fields: { Field },
	fixedSize: number?, -- bytes per record when it has no string field
	sizeOf: (value: Record) -> number,
	write: (b: buffer, offset: number, value: Record) -> number, -- returns the next offset
	read: (b: buffer, offset: number) -> (Record?, number | string), -- record + next offset, or nil + reason
	encode: (value: Record) -> buffer,
	decode: (b: buffer) -> (Record?, string?),
}

export type List = {
	encode: (values: { Record }) -> buffer,
	decode: (b: buffer) -> ({ Record }?, string?),
}

export type Options = { maxString: number? }

local INT_RANGE: { [string]: { number } } = {
	u8 = { 0, 255, 1 },
	u16 = { 0, 65535, 2 },
	u32 = { 0, 4294967295, 4 },
	i8 = { -128, 127, 1 },
	i16 = { -32768, 32767, 2 },
	i32 = { -2147483648, 2147483647, 4 },
}

local FIXED_SIZE: { [string]: number } = {
	u8 = 1,
	u16 = 2,
	u32 = 4,
	i8 = 1,
	i16 = 2,
	i32 = 4,
	f32 = 4,
	f64 = 8,
	bool = 1,
	vector3 = 12,
}

local F32_MAX = 3.4028234663852886e38
local MAX_STRING_LIMIT = 65535
local DEFAULT_MAX_STRING = 255

local function fail(message: string): never
	error("[Codec] " .. message, 0)
end

local function finite(x: number): boolean
	return x == x and x ~= math.huge and x ~= -math.huge
end

local Codec = {
	TYPES = table.freeze({ "u8", "u16", "u32", "i8", "i16", "i32", "f32", "f64", "bool", "vector3", "string" }),
}

local function checkValue(field: Field, value: unknown, maxString: number)
	local t = field.type
	local range = INT_RANGE[t]
	if range then
		if typeof(value) ~= "number" or not finite(value) or value % 1 ~= 0 then
			fail(`{field.name}: {t} needs a whole number, got {tostring(value)}`)
		end
		local n = value :: number
		if n < range[1] or n > range[2] then
			fail(`{field.name}: {n} is outside {t} ({range[1]}..{range[2]})`)
		end
	elseif t == "f32" or t == "f64" then
		if typeof(value) ~= "number" or not finite(value) then
			fail(`{field.name}: {t} needs a finite number, got {tostring(value)}`)
		end
		if t == "f32" and math.abs(value :: number) > F32_MAX then
			fail(`{field.name}: {value} is outside f32`)
		end
	elseif t == "bool" then
		if typeof(value) ~= "boolean" then
			fail(`{field.name}: bool needs a boolean, got {typeof(value)}`)
		end
	elseif t == "vector3" then
		if typeof(value) ~= "Vector3" then
			fail(`{field.name}: vector3 needs a Vector3, got {typeof(value)}`)
		end
		local v = value :: Vector3
		for _, c in { v.X, v.Y, v.Z } do
			if not finite(c) or math.abs(c) > F32_MAX then
				fail(`{field.name}: vector3 component {c} is not a finite f32`)
			end
		end
	elseif t == "string" then
		if typeof(value) ~= "string" then
			fail(`{field.name}: string needs a string, got {typeof(value)}`)
		end
		if #(value :: string) > maxString then
			fail(`{field.name}: string of {#(value :: string)} bytes exceeds {maxString}`)
		end
	end
end

local function writeField(b: buffer, offset: number, t: FieldType, value: Value): number
	if t == "u8" then
		buffer.writeu8(b, offset, value :: number)
	elseif t == "u16" then
		buffer.writeu16(b, offset, value :: number)
	elseif t == "u32" then
		buffer.writeu32(b, offset, value :: number)
	elseif t == "i8" then
		buffer.writei8(b, offset, value :: number)
	elseif t == "i16" then
		buffer.writei16(b, offset, value :: number)
	elseif t == "i32" then
		buffer.writei32(b, offset, value :: number)
	elseif t == "f32" then
		buffer.writef32(b, offset, value :: number)
	elseif t == "f64" then
		buffer.writef64(b, offset, value :: number)
	elseif t == "bool" then
		buffer.writeu8(b, offset, if value then 1 else 0)
	elseif t == "vector3" then
		local v = value :: Vector3
		buffer.writef32(b, offset, v.X)
		buffer.writef32(b, offset + 4, v.Y)
		buffer.writef32(b, offset + 8, v.Z)
	else
		local s = value :: string
		buffer.writeu16(b, offset, #s)
		buffer.writestring(b, offset + 2, s)
		return offset + 2 + #s
	end
	return offset + FIXED_SIZE[t]
end

-- Reads one field; returns value + next offset, or nil + reason. Never reads past the buffer.
local function readField(b: buffer, offset: number, t: FieldType, maxString: number): (Value?, number | string)
	local length = buffer.len(b)
	if t == "string" then
		if offset + 2 > length then
			return nil, "truncated"
		end
		local n = buffer.readu16(b, offset)
		if n > maxString then
			return nil, `string of {n} bytes exceeds {maxString}`
		end
		if offset + 2 + n > length then
			return nil, "truncated"
		end
		return buffer.readstring(b, offset + 2, n), offset + 2 + n
	end
	local size = FIXED_SIZE[t]
	if offset + size > length then
		return nil, "truncated"
	end
	if t == "u8" then
		return buffer.readu8(b, offset), offset + size
	elseif t == "u16" then
		return buffer.readu16(b, offset), offset + size
	elseif t == "u32" then
		return buffer.readu32(b, offset), offset + size
	elseif t == "i8" then
		return buffer.readi8(b, offset), offset + size
	elseif t == "i16" then
		return buffer.readi16(b, offset), offset + size
	elseif t == "i32" then
		return buffer.readi32(b, offset), offset + size
	elseif t == "bool" then
		local byte = buffer.readu8(b, offset)
		if byte > 1 then
			return nil, `bool byte {byte}`
		end
		return byte == 1, offset + size
	elseif t == "vector3" then
		local x, y, z = buffer.readf32(b, offset), buffer.readf32(b, offset + 4), buffer.readf32(b, offset + 8)
		if not (finite(x) and finite(y) and finite(z)) then
			return nil, "vector3 is not finite"
		end
		return Vector3.new(x, y, z), offset + size
	end
	local x = if t == "f32" then buffer.readf32(b, offset) else buffer.readf64(b, offset)
	if not finite(x) then
		return nil, `{t} is not finite`
	end
	return x, offset + size
end

local function maxStringOf(options: Options?): number
	local maxString = if options and options.maxString then options.maxString else DEFAULT_MAX_STRING
	if maxString % 1 ~= 0 or maxString < 0 or maxString > MAX_STRING_LIMIT then
		fail(`maxString must be a whole number 0..{MAX_STRING_LIMIT}, got {maxString}`)
	end
	return maxString
end

-- A fixed record layout. Field names are unique and non-empty; types come from Codec.TYPES.
function Codec.struct(fields: { Field }, options: Options?): Struct
	local maxString = maxStringOf(options)
	if #fields == 0 then
		fail("a struct needs at least one field")
	end
	local seen: { [string]: boolean } = {}
	local fixed = 0
	local hasString = false
	local layout: { Field } = {}
	for i, field in fields do
		if typeof(field) ~= "table" or typeof(field.name) ~= "string" or field.name == "" then
			fail(`field {i} needs a non-empty name`)
		end
		if seen[field.name] then
			fail(`duplicate field {field.name}`)
		end
		seen[field.name] = true
		if not table.find(Codec.TYPES, field.type) then
			fail(`{field.name}: unknown type {tostring(field.type)}`)
		end
		if field.type == "string" then
			hasString = true
		else
			fixed += FIXED_SIZE[field.type]
		end
		table.insert(layout, table.freeze({ name = field.name, type = field.type }))
	end
	table.freeze(layout)

	local function sizeOf(value: Record): number
		local size = fixed
		if hasString then
			for _, field in layout do
				if field.type == "string" then
					local s = value[field.name]
					size += 2 + (if typeof(s) == "string" then #s else 0)
				end
			end
		end
		return size
	end

	local function write(b: buffer, offset: number, value: Record): number
		if typeof(value) ~= "table" then
			fail(`expected a record table, got {typeof(value)}`)
		end
		for key in value do
			if not seen[key] then
				fail(`unknown field {tostring(key)}`)
			end
		end
		local at = offset
		for _, field in layout do
			local v = value[field.name]
			checkValue(field, v, maxString)
			at = writeField(b, at, field.type, v)
		end
		return at
	end

	local function read(b: buffer, offset: number): (Record?, number | string)
		local out: Record = {}
		local at = offset
		for _, field in layout do
			local v, next = readField(b, at, field.type, maxString)
			if v == nil then
				return nil, `{field.name}: {next}`
			end
			out[field.name] = v
			at = next :: number
		end
		return out, at
	end

	local struct: Struct = {
		fields = layout,
		fixedSize = if hasString then nil else fixed,
		sizeOf = sizeOf,
		write = write,
		read = read,
		encode = function(value: Record): buffer
			local b = buffer.create(sizeOf(value))
			write(b, 0, value)
			return b
		end,
		decode = function(b: buffer): (Record?, string?)
			if typeof(b) ~= "buffer" then
				return nil, `expected a buffer, got {typeof(b)}`
			end
			local value, next = read(b, 0)
			if value == nil then
				return nil, next :: string
			end
			if next ~= buffer.len(b) then
				return nil, `{buffer.len(b) - (next :: number)} trailing bytes`
			end
			return value, nil
		end,
	}
	return table.freeze(struct)
end

-- `[count][record]...` with the count in countType (u8, u16 or u32; default u16) and at most maxCount records.
function Codec.list(struct: Struct, countType: FieldType?, maxCount: number?): List
	local ct: FieldType = countType or "u16"
	if ct ~= "u8" and ct ~= "u16" and ct ~= "u32" then
		fail(`list count type must be u8, u16 or u32, got {ct}`)
	end
	local limit = INT_RANGE[ct][2]
	local cap = maxCount or limit
	if cap % 1 ~= 0 or cap < 0 or cap > limit then
		fail(`maxCount must be a whole number 0..{limit}`)
	end
	local countSize = FIXED_SIZE[ct]
	local list: List = {
		encode = function(values: { Record }): buffer
			if #values > cap then
				fail(`{#values} records exceed the list limit {cap}`)
			end
			local size = countSize
			for _, value in values do
				size += struct.sizeOf(value)
			end
			local b = buffer.create(size)
			local at = writeField(b, 0, ct, #values)
			for _, value in values do
				at = struct.write(b, at, value)
			end
			return b
		end,
		decode = function(b: buffer): ({ Record }?, string?)
			if typeof(b) ~= "buffer" then
				return nil, `expected a buffer, got {typeof(b)}`
			end
			local count, at = readField(b, 0, ct, 0)
			if count == nil then
				return nil, `count: {at}`
			end
			local n = count :: number
			if n > cap then
				return nil, `count {n} exceeds {cap}`
			end
			local fixed = struct.fixedSize
			if fixed and countSize + n * fixed ~= buffer.len(b) then
				return nil, `length {buffer.len(b)} does not match {n} records of {fixed} bytes`
			end
			local out: { Record } = table.create(n)
			local offset = at :: number
			for i = 1, n do
				local value, next = struct.read(b, offset)
				if value == nil then
					return nil, `record {i}: {next}`
				end
				out[i] = value
				offset = next :: number
			end
			if offset ~= buffer.len(b) then
				return nil, `{buffer.len(b) - offset} trailing bytes`
			end
			return out, nil
		end,
	}
	return table.freeze(list)
end

return table.freeze(Codec)
