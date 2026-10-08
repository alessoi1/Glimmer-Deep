--!strict
local Framework = require("../Framework")
local HouseMessages = require("../../src/shared/HouseMessages")

local test = Framework.test
local assertEquals = Framework.assertEquals

local strings: HouseMessages.Strings = {
	house = {
		item = { rug = "Teppich" },
		levelName = { ["2"] = "Werkstatt-Haus" },
		levelLine = "Haus: Stufe %d %s",
		upgradeLine = "Ausbauen auf Stufe %d: %s Münzen",
		maxLevel = "Höchste Stufe",
		coinsPrice = "%s Münzen",
		slotLine = "Plätze: %d/%d",
		upgraded = "Ausgebaut",
		bought = "Gekauft",
		placed = "Aufgestellt",
		removed = "Entfernt",
		notEnoughCoins = "Nicht genug Münzen",
		noDecorYet = "Erst das Haus ausbauen",
		alreadyOwned = "Schon gekauft",
		unknown = "?",
	},
}

test("items show their name, with the id as fallback", function()
	assertEquals(HouseMessages.itemName(strings, "rug"), "Teppich")
	assertEquals(HouseMessages.itemName(strings, "mystery"), "mystery")
end)

test("the level text names the level when it has a name", function()
	assertEquals(HouseMessages.levelText(strings, 2), "Haus: Stufe 2 Werkstatt-Haus")
	assertEquals(HouseMessages.levelText(strings, 1), "Haus: Stufe 1 ")
end)

test("prices use thousands separators", function()
	assertEquals(HouseMessages.priceText(strings, 250), "250 Münzen")
	assertEquals(HouseMessages.priceText(strings, 10000), "10.000 Münzen")
	assertEquals(HouseMessages.upgradeText(strings, 1, 10000), "Ausbauen auf Stufe 2: 10.000 Münzen")
	assertEquals(HouseMessages.upgradeText(strings, 2, nil), "Höchste Stufe")
end)

test("the places text shows used and total places", function()
	assertEquals(HouseMessages.slotsText(strings, 2, 6), "Plätze: 2/6")
end)

test("results name the failure with a neutral fallback", function()
	assertEquals(HouseMessages.describeResult(strings, true, nil), "")
	assertEquals(HouseMessages.describeResult(strings, false, "not_enough_coins"), "Nicht genug Münzen")
	assertEquals(HouseMessages.describeResult(strings, false, "no_decor_yet"), "Erst das Haus ausbauen")
	assertEquals(HouseMessages.describeResult(strings, false, "already_owned"), "Schon gekauft")
	assertEquals(HouseMessages.describeResult(strings, false, "other"), "?")
end)
