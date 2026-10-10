--!strict
local CaveCodec = require("../../src/shared/CaveCodec")
local Framework = require("../Framework")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals

local function toSet(indexes: { number }): { [number]: boolean }
	local set = {}
	for _, index in indexes do
		set[index] = true
	end
	return set
end

test("an empty set encodes to zeros and has the expected length", function()
	local text = CaveCodec.encode({}, 100)
	assertEquals(#text, CaveCodec.charCount(100))
	assertEquals(CaveCodec.charCount(100), 17)
	assertEquals(text, string.rep("A", 17))
end)

test("encode and decode round-trip a set", function()
	local bits = toSet({ 0, 1, 5, 6, 63, 64, 99 })
	local decoded = CaveCodec.decode(CaveCodec.encode(bits, 100), 100)
	assertTrue(decoded ~= nil)
	assertEquals(next(decoded :: any) ~= nil, true)
	for index = 0, 99 do
		assertEquals((decoded :: any)[index] == true, bits[index] == true, "bit " .. index)
	end
end)

test("round trip with a seeded random set", function()
	local rng = Framework.seededRng(5)
	local total = 2400
	local bits: { [number]: boolean } = {}
	for index = 0, total - 1 do
		if rng() < 0.3 then
			bits[index] = true
		end
	end
	local text = CaveCodec.encode(bits, total)
	assertEquals(#text, 400)
	local decoded = CaveCodec.decode(text, total)
	assertTrue(decoded ~= nil)
	for index = 0, total - 1 do
		if (decoded :: any)[index] ~= bits[index] then
			error("bit differs at " .. index)
		end
	end
end)

test("decode rejects a wrong length and foreign characters", function()
	assertEquals(CaveCodec.decode("AAA", 100), nil)
	assertEquals(CaveCodec.decode(string.rep("A", 16), 100), nil)
	assertEquals(CaveCodec.decode(string.rep("A", 16) .. "!", 100), nil)
	assertEquals(CaveCodec.decode(string.rep("A", 17) .. "A", 100), nil)
end)

test("decode rejects set bits beyond the total", function()
	-- 100 bits use 17 chars (102 bits); the last 2 bits of the last char must stay zero.
	local text = string.rep("A", 16) .. "/"
	assertEquals(CaveCodec.decode(text, 100), nil)
end)

test("encode ignores indexes outside the range", function()
	local text = CaveCodec.encode(toSet({ -1, 100, 5000 }), 100)
	assertEquals(text, string.rep("A", 17))
end)
