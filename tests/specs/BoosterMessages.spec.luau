--!strict
local BoosterMessages = require("../../src/shared/BoosterMessages")
local Framework = require("../Framework")

local test = Framework.test
local assertEquals = Framework.assertEquals

local strings: BoosterMessages.Strings = {
	shop = {
		viewOffer = "Angebot ansehen",
		soon = "Bald verfügbar",
		price = "%s Robux",
		boosters = {
			booster = { luck_booster = { name = "Glücks-Booster", description = "Mehr Glück" } },
			chanceLine = "%s: %s %% -> %s %%",
			mutationLine = "Mutation: %s %% -> %s %%",
			running = "Läuft noch %s",
			durationHours = "%d Std %d Min",
			durationMinutes = "%d Min",
			freeIn = "Wieder möglich in %s",
			freeClaim = "Gratis abholen",
			granted = "Booster aktiv",
			notAvailable = "Noch nicht verfügbar",
			cooldown = "Einen Moment",
			unknown = "?",
		},
	},
	rarity = { rare = "Selten" },
}

test("a booster shows its name and description, with the key as fallback", function()
	assertEquals(BoosterMessages.name(strings, "luck_booster"), "Glücks-Booster")
	assertEquals(BoosterMessages.description(strings, "luck_booster"), "Mehr Glück")
	assertEquals(BoosterMessages.name(strings, "mystery"), "mystery")
	assertEquals(BoosterMessages.description(strings, "mystery"), "")
end)

test("durations show minutes, then hours and minutes, rounded up", function()
	assertEquals(BoosterMessages.durationText(strings, 900), "15 Min")
	assertEquals(BoosterMessages.durationText(strings, 1), "1 Min")
	assertEquals(BoosterMessages.durationText(strings, 3900), "1 Std 5 Min")
	assertEquals(BoosterMessages.durationText(strings, 7200), "2 Std 0 Min")
	assertEquals(BoosterMessages.runningText(strings, 600), "Läuft noch 10 Min")
end)

test("percentages use one decimal and a comma", function()
	assertEquals(BoosterMessages.percentText(25), "25,0")
	assertEquals(BoosterMessages.percentText(4.56), "4,6")
end)

test("chance lines name the rarity with base and boosted chance", function()
	assertEquals(BoosterMessages.chanceLine(strings, "rare", 25, 27.31), "Selten: 25,0 % -> 27,3 %")
	assertEquals(BoosterMessages.chanceLine(strings, "ghost", 1, 2), "ghost: 1,0 % -> 2,0 %")
	assertEquals(BoosterMessages.mutationLine(strings, 5, 6.31), "Mutation: 5,0 % -> 6,3 %")
end)

test("action and free texts are neutral", function()
	assertEquals(BoosterMessages.actionText(strings, { buyable = true, remaining = 0 }), "Angebot ansehen")
	assertEquals(BoosterMessages.actionText(strings, { buyable = false, remaining = 0 }), "Bald verfügbar")
	assertEquals(BoosterMessages.freeText(strings, { canClaim = true, secondsUntil = 0 }), "Gratis abholen")
	assertEquals(
		BoosterMessages.freeText(strings, { canClaim = false, secondsUntil = 3600 }),
		"Wieder möglich in 1 Std 0 Min"
	)
end)

test("results name the failure with a neutral fallback", function()
	assertEquals(BoosterMessages.describeResult(strings, true, nil), "Booster aktiv")
	assertEquals(BoosterMessages.describeResult(strings, false, "not_available"), "Noch nicht verfügbar")
	assertEquals(BoosterMessages.describeResult(strings, false, "cooldown"), "Einen Moment")
	assertEquals(BoosterMessages.describeResult(strings, false, "x"), "?")
end)
