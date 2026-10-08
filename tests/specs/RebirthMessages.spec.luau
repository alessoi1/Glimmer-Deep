--!strict
local Framework = require("../Framework")
local RebirthMessages = require("../../src/shared/RebirthMessages")

local test = Framework.test
local assertEquals = Framework.assertEquals

local strings: RebirthMessages.Strings = {
	rebirth = {
		upgrade = { coins = "Münzen" },
		effectCoins = "Münzen +%d %%",
		effectTempo = "Tempo +%d %%",
		effectLuck = "Glück +%d %%",
		effectOffline = "Bagger +%d %%",
		countLine = "Neue Bohrungen: %d",
		pointsLine = "Punkte: %d",
		requirement = "Erreiche %d m (jetzt %d m)",
		ready = "Bereit",
		givesLine = "Gibt %d Punkte",
		levelLine = "Stufe %d/%d",
		costLine = "Kosten: %d Punkte",
		maxLevel = "Maximal",
		done = "Neue Bohrung",
		bought = "Gekauft",
		tooShallow = "Noch nicht tief genug",
		notEnoughPoints = "Nicht genug Punkte",
		unknown = "?",
	},
}

test("bonuses show their name, with the id as fallback", function()
	assertEquals(RebirthMessages.upgradeName(strings, "coins"), "Münzen")
	assertEquals(RebirthMessages.upgradeName(strings, "mystery"), "mystery")
end)

test("the effect text lists each bonus in a fixed order", function()
	assertEquals(RebirthMessages.effectText(strings, { coinBonus = 0.1 }), "Münzen +10 %")
	assertEquals(
		RebirthMessages.effectText(strings, { offlineBonus = 0.1, tempoBonus = 0.05 }),
		"Tempo +5 %, Bagger +10 %"
	)
	assertEquals(RebirthMessages.effectText(strings, {}), "")
end)

test("counts, points and gains", function()
	assertEquals(RebirthMessages.countText(strings, 2), "Neue Bohrungen: 2")
	assertEquals(RebirthMessages.pointsText(strings, 12), "Punkte: 12")
	assertEquals(RebirthMessages.givesText(strings, 7), "Gibt 7 Punkte")
	assertEquals(RebirthMessages.levelText(strings, 2, 5), "Stufe 2/5")
end)

test("the requirement shows the missing depth until it is reached", function()
	assertEquals(RebirthMessages.requirementText(strings, 120.9, 300), "Erreiche 300 m (jetzt 120 m)")
	assertEquals(RebirthMessages.requirementText(strings, 300, 300), "Bereit")
	assertEquals(RebirthMessages.requirementText(strings, 450, 300), "Bereit")
end)

test("the cost shows points or the maximum", function()
	assertEquals(RebirthMessages.costText(strings, 3), "Kosten: 3 Punkte")
	assertEquals(RebirthMessages.costText(strings, nil), "Maximal")
end)

test("results name the failure with a neutral fallback", function()
	assertEquals(RebirthMessages.describeResult(strings, true, "rebirth", nil), "Neue Bohrung")
	assertEquals(RebirthMessages.describeResult(strings, true, "bought", nil), "Gekauft")
	assertEquals(RebirthMessages.describeResult(strings, false, nil, "too_shallow"), "Noch nicht tief genug")
	assertEquals(RebirthMessages.describeResult(strings, false, nil, "not_enough_points"), "Nicht genug Punkte")
	assertEquals(RebirthMessages.describeResult(strings, false, nil, "other"), "?")
end)
