--!strict
local Framework = require("../Framework")
local UpgradeMessages = require("../../src/shared/UpgradeMessages")

local test = Framework.test
local assertEquals = Framework.assertEquals

local strings: UpgradeMessages.Strings = {
	upgrade = { shovel = "Schaufel", backpack = "Rucksack" },
	shovel = { stone = "Steinschaufel" },
	upgrades = {
		offer = "%s: %s (%s Münzen)",
		maxed = "%s: Maximal",
		capacity = "%d Plätze",
		blocksPerHour = "%d Blöcke/Std",
		level = "Stufe %d",
		bought = "Verbessert: %s",
		notEnoughCoins = "Nicht genug Münzen",
		maxLevel = "Höchste Stufe",
		unknown = "?",
	},
}

local function entry(changes: { [string]: any }): UpgradeMessages.Entry
	local base: { [string]: any } = { id = "shovel", level = 1, maxLevel = 10, canAfford = true }
	for key, value in changes do
		base[key] = value
	end
	return base :: any
end

test("a shovel offer names the next shovel and the price", function()
	local text = UpgradeMessages.describeOffer(strings, entry({ nextPrice = 1500, nextId = "stone" }))
	assertEquals(text, "Schaufel: Steinschaufel (1.500 Münzen)")
end)

test("a backpack offer names the capacity", function()
	local text = UpgradeMessages.describeOffer(strings, entry({ id = "backpack", nextPrice = 150, nextCapacity = 100 }))
	assertEquals(text, "Rucksack: 100 Plätze (150 Münzen)")
end)

test("a digger offer names the blocks per hour", function()
	local text =
		UpgradeMessages.describeOffer(strings, entry({ id = "digger", nextPrice = 500, nextBlocksPerHour = 120 }))
	assertEquals(text, "digger: 120 Blöcke/Std (500 Münzen)")
end)

test("an offer without details falls back to the level", function()
	local text = UpgradeMessages.describeOffer(strings, entry({ id = "pet", level = 2, nextPrice = 5 }))
	assertEquals(text, "pet: Stufe 3 (5 Münzen)")
end)

test("an unknown shovel id falls back to the id", function()
	local text = UpgradeMessages.describeOffer(strings, entry({ nextPrice = 5, nextId = "mystery" }))
	assertEquals(text, "Schaufel: mystery (5 Münzen)")
end)

test("a maxed upgrade reads as maximal", function()
	assertEquals(UpgradeMessages.describeOffer(strings, entry({ nextPrice = nil })), "Schaufel: Maximal")
end)

test("results name the upgrade or the failure", function()
	assertEquals(UpgradeMessages.describeResult(strings, true, "backpack", nil), "Verbessert: Rucksack")
	assertEquals(UpgradeMessages.describeResult(strings, false, "backpack", "not_enough_coins"), "Nicht genug Münzen")
	assertEquals(UpgradeMessages.describeResult(strings, false, "backpack", "max_level"), "Höchste Stufe")
	assertEquals(UpgradeMessages.describeResult(strings, false, nil, "bad_id"), "?")
end)
