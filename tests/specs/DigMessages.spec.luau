--!strict
local DigMessages = require("../../src/shared/DigMessages")
local Framework = require("../Framework")

local test = Framework.test
local assertEquals = Framework.assertEquals

local strings: DigMessages.Strings = {
	ore = { coal = "Kohle" },
	find = { fossil = "Fossil" },
	rarity = { epic = "Episch" },
	mutation = { golden = "Golden" },
	layer = { rock = "Fels" },
	dig = {
		foundOre = "+1 %s",
		foundRare = "Fund: %s (%s)",
		foundRareMutated = "Fund: %s %s (%s)",
		backpackFull = "Rucksack voll",
		tooFar = "Geh näher an deinen Schacht",
		unknown = "?",
	},
}

test("depth is shown with one decimal and a comma", function()
	assertEquals(DigMessages.formatDepth(12.34), "12,3 m")
	assertEquals(DigMessages.formatDepth(0), "0,0 m")
	assertEquals(DigMessages.formatDepth(100), "100,0 m")
end)

test("an ore block reads as the ore name", function()
	assertEquals(DigMessages.describeBlock(strings, { kind = "ore", layerId = "rock", oreId = "coal" }), "+1 Kohle")
end)

test("a rare block shows find, rarity and mutation", function()
	local plain = { kind = "rare", layerId = "rock", findId = "fossil", rarityId = "epic", value = 250 }
	assertEquals(DigMessages.describeBlock(strings, plain), "Fund: Fossil (Episch)")
	local mutated =
		{ kind = "rare", layerId = "rock", findId = "fossil", rarityId = "epic", mutationId = "golden", value = 500 }
	assertEquals(DigMessages.describeBlock(strings, mutated), "Fund: Golden Fossil (Episch)")
end)

test("unknown ids fall back to the id instead of failing", function()
	assertEquals(
		DigMessages.describeBlock(strings, { kind = "ore", layerId = "rock", oreId = "mystery" }),
		"+1 mystery"
	)
end)

test("failure reasons have a player text", function()
	assertEquals(DigMessages.describeFailure(strings, "backpack_full"), "Rucksack voll")
	assertEquals(DigMessages.describeFailure(strings, "too_far"), "Geh näher an deinen Schacht")
	assertEquals(DigMessages.describeFailure(strings, "something_else"), "?")
end)

test("layer names come from the strings with the id as fallback", function()
	assertEquals(DigMessages.layerName(strings, "rock"), "Fels")
	assertEquals(DigMessages.layerName(strings, "deep"), "deep")
end)
