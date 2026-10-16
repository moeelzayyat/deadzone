--!strict
-- Net/Codec (A1.8): every field type round-trips at its edges, structs and lists round-trip, encoding rejects bad values,
-- and decoding untrusted bytes never throws. Runs on a clone of Shared (Studio caches require per ModuleScript in Edit).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestRunner = require(script.Parent.Parent.TestRunner)

type CodecModule = typeof(require(ReplicatedStorage.Shared.Net.Codec))

local shared = ReplicatedStorage.Shared:Clone()
local Codec: CodecModule = (require :: any)((shared :: any).Net.Codec)

local function one(fieldType: any, options: any?): any
	return Codec.struct({ { name = "v", type = fieldType } }, options)
end

local function roundTrip(fieldType: string, value: any, options: any?): any
	local struct = one(fieldType, options)
	local decoded, reason = struct.decode(struct.encode({ v = value }))
	assert(decoded ~= nil, `decode failed: {reason}`)
	return (decoded :: any).v
end

local function f32(x: number): number
	local b = buffer.create(4)
	buffer.writef32(b, 0, x)
	return buffer.readf32(b, 0)
end

-- One struct holding every field type.
local ALL = {
	{ name = "a", type = "u8" },
	{ name = "b", type = "u16" },
	{ name = "c", type = "u32" },
	{ name = "d", type = "i8" },
	{ name = "e", type = "i16" },
	{ name = "f", type = "i32" },
	{ name = "g", type = "f32" },
	{ name = "h", type = "f64" },
	{ name = "i", type = "bool" },
	{ name = "j", type = "vector3" },
	{ name = "k", type = "string" },
}

return function(t: TestRunner.Spec)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("field types round-trip", function()
		it("covers every type in Codec.TYPES", function()
			local names: { string } = {}
			for _, field in ALL do
				table.insert(names, field.type)
			end
			expect(names).toEqual(table.clone(Codec.TYPES))
		end)

		it("unsigned integers at 0, middle and max", function()
			for fieldType, max in { u8 = 255, u16 = 65535, u32 = 4294967295 } :: { [string]: number } do
				for _, v in { 0, 1, math.floor(max / 2), max } do
					expect(roundTrip(fieldType, v)).toBe(v)
				end
			end
		end)

		it("signed integers at min, -1, 0 and max", function()
			for fieldType, range in { i8 = { -128, 127 }, i16 = { -32768, 32767 }, i32 = { -2147483648, 2147483647 } } :: { [string]: { number } } do
				for _, v in { range[1], -1, 0, range[2] } do
					expect(roundTrip(fieldType, v)).toBe(v)
				end
			end
		end)

		it("f32 rounds to single precision; f64 is exact", function()
			for _, v in { 0, 1.5, -2.25, 1 / 3, 123456.789, 3.4e38, -3.4e38 } do
				expect(roundTrip("f32", v)).toBe(f32(v))
				expect(roundTrip("f64", v)).toBe(v)
			end
			expect(roundTrip("f32", 1 / 3)).toBeCloseTo(1 / 3, 1e-7)
		end)

		it("bool true and false", function()
			expect(roundTrip("bool", true)).toBe(true)
			expect(roundTrip("bool", false)).toBe(false)
		end)

		it("vector3 per component in f32", function()
			local v = Vector3.new(1.25, -1000.5, 1 / 3)
			local out = roundTrip("vector3", v) :: Vector3
			expect(out.X).toBe(1.25)
			expect(out.Y).toBe(-1000.5)
			expect(out.Z).toBe(f32(1 / 3))
			expect(roundTrip("vector3", Vector3.zero)).toBe(Vector3.zero)
		end)

		it("strings: empty, UTF-8, binary bytes and the max length", function()
			expect(roundTrip("string", "")).toBe("")
			expect(roundTrip("string", "Hold · Extract ☣")).toBe("Hold · Extract ☣")
			expect(roundTrip("string", "\0\1\255")).toBe("\0\1\255")
			expect(roundTrip("string", string.rep("x", 255))).toBe(string.rep("x", 255))
			expect(roundTrip("string", string.rep("y", 1000), { maxString = 1000 })).toBe(string.rep("y", 1000))
		end)

		it("a struct with all eleven types", function()
			local struct = Codec.struct(ALL :: any)
			local value: any = {
				a = 200,
				b = 60000,
				c = 4000000000,
				d = -100,
				e = -30000,
				f = -2000000000,
				g = 0.5,
				h = math.pi,
				i = true,
				j = Vector3.new(1, 2, 3),
				k = "Walker",
			}
			local b = struct.encode(value)
			expect(buffer.len(b)).toBe(1 + 2 + 4 + 1 + 2 + 4 + 4 + 8 + 1 + 12 + 2 + 6)
			expect(struct.sizeOf(value)).toBe(buffer.len(b))
			expect((struct.decode(b))).toEqual(value)
		end)

		it("fixed-size structs report their size", function()
			expect(Codec.struct({ { name = "x", type = "u16" }, { name = "p", type = "vector3" } }).fixedSize).toBe(14)
			expect(one("string").fixedSize).toBeNil()
		end)
	end)

	describe("lists", function()
		-- The EnemySnapshot shape from API_CONTRACTS (A2.3 uses it).
		local snapshot = Codec.struct({
			{ name = "id", type = "u16" },
			{ name = "x", type = "f32" },
			{ name = "y", type = "f32" },
			{ name = "z", type = "f32" },
			{ name = "yaw", type = "u8" },
			{ name = "state", type = "u8" },
			{ name = "hpPct", type = "u8" },
		})

		it("round-trip 0, 1 and 90 records", function()
			local list = Codec.list(snapshot)
			for _, n in { 0, 1, 90 } do
				local rows = {}
				for i = 1, n do
					table.insert(rows, { id = i, x = i * 0.5, y = 0, z = -i, yaw = i % 256, state = 1, hpPct = 100 })
				end
				local b = list.encode(rows :: any)
				expect(buffer.len(b)).toBe(2 + n * 17)
				expect((list.decode(b))).toEqual(rows)
			end
		end)

		it("lists of variable-size records", function()
			local list = Codec.list(Codec.struct({ { name = "s", type = "string" }, { name = "n", type = "u8" } }), "u8")
			local rows = { { s = "", n = 1 }, { s = "abc", n = 2 } }
			expect((list.decode(list.encode(rows :: any)))).toEqual(rows)
		end)

		it("enforce maxCount on both sides", function()
			local list = Codec.list(snapshot, "u16", 2)
			local row = { id = 1, x = 0, y = 0, z = 0, yaw = 0, state = 0, hpPct = 0 }
			expect(function()
				list.encode({ row, row, row } :: any)
			end).toThrow("exceed the list limit 2")
			local b = Codec.list(snapshot).encode({ row, row, row } :: any)
			local out, reason = list.decode(b)
			expect(out).toBeNil()
			expect(reason).toBe("count 3 exceeds 2")
		end)
	end)

	describe("encoding rejects bad values (server bugs throw)", function()
		it("integers out of range or fractional", function()
			expect(function()
				one("u8").encode({ v = 256 })
			end).toThrow("outside u8")
			expect(function()
				one("u16").encode({ v = -1 })
			end).toThrow("outside u16")
			expect(function()
				one("i8").encode({ v = 128 })
			end).toThrow("outside i8")
			expect(function()
				one("u32").encode({ v = 1.5 })
			end).toThrow("whole number")
		end)

		it("NaN, inf and out-of-f32 floats", function()
			expect(function()
				one("f32").encode({ v = 0 / 0 })
			end).toThrow("finite")
			expect(function()
				one("f64").encode({ v = math.huge })
			end).toThrow("finite")
			expect(function()
				one("f32").encode({ v = 1e39 })
			end).toThrow("outside f32")
			expect(function()
				one("vector3").encode({ v = Vector3.new(0 / 0, 0, 0) })
			end).toThrow("not a finite f32")
		end)

		it("wrong types, unknown and missing fields, oversized strings", function()
			expect(function()
				one("bool").encode({ v = 1 })
			end).toThrow("needs a boolean")
			expect(function()
				one("u8").encode({ v = 1, w = 2 })
			end).toThrow("unknown field w")
			expect(function()
				one("u8").encode({})
			end).toThrow("whole number")
			expect(function()
				one("string").encode({ v = string.rep("x", 256) })
			end).toThrow("exceeds 255")
		end)

		it("malformed layouts", function()
			expect(function()
				Codec.struct({})
			end).toThrow("at least one field")
			expect(function()
				Codec.struct({ { name = "a", type = "u8" }, { name = "a", type = "u8" } })
			end).toThrow("duplicate field a")
			expect(function()
				Codec.struct({ { name = "a", type = "u64" :: any } })
			end).toThrow("unknown type u64")
			expect(function()
				Codec.list(one("u8"), "i8")
			end).toThrow("count type")
		end)
	end)

	describe("decoding untrusted bytes never throws", function()
		it("rejects truncated and padded buffers", function()
			local struct = Codec.struct({ { name = "a", type = "u32" }, { name = "b", type = "u8" } })
			local good = struct.encode({ a = 7, b = 9 })
			expect((struct.decode(buffer.create(3)))).toBeNil()
			local padded = buffer.create(buffer.len(good) + 1)
			buffer.copy(padded, 0, good)
			local out, reason = struct.decode(padded)
			expect(out).toBeNil()
			expect(reason).toBe("1 trailing bytes")
		end)

		it("rejects a bool byte other than 0/1 and non-finite floats", function()
			local b = buffer.create(1)
			buffer.writeu8(b, 0, 2)
			expect((one("bool").decode(b))).toBeNil()
			local nan = buffer.create(4)
			buffer.writef32(nan, 0, 0 / 0)
			expect((one("f32").decode(nan))).toBeNil()
			local inf = buffer.create(12)
			buffer.writef32(inf, 4, math.huge)
			expect((one("vector3").decode(inf))).toBeNil()
		end)

		it("rejects oversized and truncated strings", function()
			local b = buffer.create(2 + 300)
			buffer.writeu16(b, 0, 300)
			local out, reason = one("string").decode(b)
			expect(out).toBeNil()
			expect(reason).toBe("v: string of 300 bytes exceeds 255")
			local short = buffer.create(4)
			buffer.writeu16(short, 0, 10)
			expect((one("string").decode(short))).toBeNil()
		end)

		it("rejects a list whose length disagrees with its count", function()
			local list = Codec.list(one("u16"))
			local b = buffer.create(2 + 3)
			buffer.writeu16(b, 0, 2)
			expect((list.decode(b))).toBeNil()
			local huge = buffer.create(2)
			buffer.writeu16(huge, 0, 65535)
			expect((list.decode(huge))).toBeNil()
		end)

		it("rejects non-buffers and survives 2,000 random buffers", function()
			local struct = Codec.struct(ALL :: any)
			expect((struct.decode("nope" :: any))).toBeNil()
			local list = Codec.list(struct)
			local rng = Random.new(18)
			for _ = 1, 1000 do
				local b = buffer.create(rng:NextInteger(0, 64))
				for i = 0, buffer.len(b) - 1 do
					buffer.writeu8(b, i, rng:NextInteger(0, 255))
				end
				local ok1 = pcall(struct.decode, b)
				local ok2 = pcall(list.decode, b)
				expect(ok1 and ok2).toBe(true)
			end
		end)
	end)
end
