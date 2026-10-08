--!strict
local Framework = require("../Framework")
local SellMessages = require("../../src/shared/SellMessages")

local test = Framework.test
local assertEquals = Framework.assertEquals

local strings: SellMessages.Strings = {
	sold = "Verkauft: +%s Münzen",
	empty = "Rucksack leer",
	tooFar = "Geh näher",
	unknown = "?",
}

test("coins get a dot as thousands separator", function()
	assertEquals(SellMessages.formatCoins(0), "0")
	assertEquals(SellMessages.formatCoins(999), "999")
	assertEquals(SellMessages.formatCoins(1000), "1.000")
	assertEquals(SellMessages.formatCoins(1234567), "1.234.567")
end)

test("coins are rounded down to whole numbers", function()
	assertEquals(SellMessages.formatCoins(12.9), "12")
end)

test("a sale reads as the earned coins", function()
	assertEquals(SellMessages.describeSale(strings, 1500), "Verkauft: +1.500 Münzen")
end)

test("known failures have their own text, others a neutral one", function()
	assertEquals(SellMessages.describeFailure(strings, "empty"), "Rucksack leer")
	assertEquals(SellMessages.describeFailure(strings, "too_far"), "Geh näher")
	assertEquals(SellMessages.describeFailure(strings, "something_else"), "?")
end)
