--!strict
local Framework = require("../Framework")
local ShopMessages = require("../../src/shared/ShopMessages")

local test = Framework.test
local assertEquals = Framework.assertEquals

local strings: ShopMessages.Strings = {
	shop = {
		pass = {
			night_shift = { name = "Nachtschicht", description = "8 statt 4 Stunden" },
		},
		price = "%s Robux",
		viewOffer = "Angebot ansehen",
		owned = "Gekauft",
		soon = "Bald verfügbar",
		travelDone = "Unterwegs",
		notAvailable = "Noch nicht verfügbar",
		cooldown = "Einen Moment",
		unknown = "?",
	},
}

test("a pass shows its name and description, with the key as fallback", function()
	assertEquals(ShopMessages.passName(strings, "night_shift"), "Nachtschicht")
	assertEquals(ShopMessages.passDescription(strings, "night_shift"), "8 statt 4 Stunden")
	assertEquals(ShopMessages.passName(strings, "mystery"), "mystery")
	assertEquals(ShopMessages.passDescription(strings, "mystery"), "")
end)

test("the price uses thousands separators", function()
	assertEquals(ShopMessages.priceText(strings, 299), "299 Robux")
	assertEquals(ShopMessages.priceText(strings, 1500), "1.500 Robux")
end)

test("the action text depends on ownership and availability, never pushy", function()
	assertEquals(ShopMessages.actionText(strings, { owned = true, buyable = false }), "Gekauft")
	assertEquals(ShopMessages.actionText(strings, { owned = false, buyable = true }), "Angebot ansehen")
	assertEquals(ShopMessages.actionText(strings, { owned = false, buyable = false }), "Bald verfügbar")
end)

test("results name the failure with a neutral fallback", function()
	assertEquals(ShopMessages.describeResult(strings, true, nil), "Unterwegs")
	assertEquals(ShopMessages.describeResult(strings, false, "not_available"), "Noch nicht verfügbar")
	assertEquals(ShopMessages.describeResult(strings, false, "cooldown"), "Einen Moment")
	assertEquals(ShopMessages.describeResult(strings, false, "other"), "?")
end)
