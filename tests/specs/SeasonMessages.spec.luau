--!strict
local Framework = require("../Framework")
local SeasonMessages = require("../../src/shared/SeasonMessages")

local test = Framework.test
local assertEquals = Framework.assertEquals

local strings: SeasonMessages.Strings = {
	shop = { boosters = { booster = { tempo_booster = { name = "Tempo-Booster" } } } },
	house = { item = { lantern = "Laterne" } },
	events = { glow_week = { name = "Glühwoche", description = "Glühend häufiger" } },
	mutation = { glowing = "Glühend" },
	season = {
		eventLine = "Event: %s (endet in %s)",
		mutationLine = "%s %dx häufiger",
		durationDays = "%d Tg %d Std",
		durationHours = "%d Std %d Min",
		durationMinutes = "%d Min",
		seasonLine = "Saison %d: noch %s",
		levelLine = "Stufe %d/%d",
		xpLine = "%d/%d Punkte",
		xpMax = "Höchste Stufe",
		resetsIn = "?",
		rewardCoins = "%s Münzen",
		rewardEgg = "%d Eier",
		rewardBooster = "%s x%d",
		rewardDecor = "Deko: %s",
		claim = "Abholen",
		claimed = "Abgeholt",
		locked = "Gesperrt",
		premiumLocked = "Premium",
		paid = "Belohnung erhalten",
		levelUp = "Saison-Stufe %d",
		notReached = "Noch nicht erreicht",
		noPremium = "Nur mit Premium",
		alreadyClaimed = "Schon abgeholt",
		unknown = "?",
	},
}

test("events show their name and description, with the id as fallback", function()
	assertEquals(SeasonMessages.eventName(strings, "glow_week"), "Glühwoche")
	assertEquals(SeasonMessages.eventDescription(strings, "glow_week"), "Glühend häufiger")
	assertEquals(SeasonMessages.eventName(strings, "mystery"), "mystery")
	assertEquals(SeasonMessages.eventDescription(strings, "mystery"), "")
end)

test("durations show days, hours or minutes", function()
	assertEquals(SeasonMessages.durationText(strings, 3 * 86400 + 4 * 3600 + 59), "3 Tg 4 Std")
	assertEquals(SeasonMessages.durationText(strings, 5 * 3600 + 12 * 60), "5 Std 12 Min")
	assertEquals(SeasonMessages.durationText(strings, 7 * 60 + 30), "7 Min")
	assertEquals(SeasonMessages.durationText(strings, 20), "1 Min", "never 0 Min")
end)

test("the event line names the event and the time left", function()
	local event: SeasonMessages.EventView = { id = "glow_week", secondsLeft = 2 * 86400 }
	assertEquals(SeasonMessages.eventLine(strings, event), "Event: Glühwoche (endet in 2 Tg 0 Std)")
end)

test("the mutation line appears only for a boosted mutation", function()
	assertEquals(
		SeasonMessages.mutationLine(strings, { id = "x", secondsLeft = 1, mutationId = "glowing", mutationFactor = 4 }),
		"Glühend 4x häufiger"
	)
	assertEquals(SeasonMessages.mutationLine(strings, { id = "x", secondsLeft = 1 }), "")
end)

test("season lines and progress", function()
	assertEquals(SeasonMessages.seasonLine(strings, 700, 86400 * 10), "Saison 700: noch 10 Tg 0 Std")
	assertEquals(SeasonMessages.levelText(strings, 3, 10), "Stufe 3/10")
	assertEquals(SeasonMessages.xpText(strings, 250, 700), "250/700 Punkte")
	assertEquals(SeasonMessages.xpText(strings, 0, nil), "Höchste Stufe")
	assertEquals(SeasonMessages.levelUpText(strings, 4), "Saison-Stufe 4")
end)

test("rewards are described by kind", function()
	assertEquals(SeasonMessages.rewardText(strings, { kind = "coins", amount = 2500 }), "2.500 Münzen")
	assertEquals(SeasonMessages.rewardText(strings, { kind = "egg", amount = 2 }), "2 Eier")
	assertEquals(
		SeasonMessages.rewardText(strings, { kind = "booster", id = "tempo_booster", amount = 1 }),
		"Tempo-Booster x1"
	)
	assertEquals(SeasonMessages.rewardText(strings, { kind = "decor", id = "lantern" }), "Deko: Laterne")
	assertEquals(SeasonMessages.rewardText(strings, { kind = "decor", id = "ghost" }), "Deko: ghost")
	assertEquals(SeasonMessages.rewardText(strings, { kind = "gift" }), "")
end)

test("the claim button depends on progress, claim state and the premium lock", function()
	assertEquals(SeasonMessages.claimText(strings, true, true, false), "Abgeholt")
	assertEquals(SeasonMessages.claimText(strings, true, false, true), "Premium")
	assertEquals(SeasonMessages.claimText(strings, false, false, false), "Gesperrt")
	assertEquals(SeasonMessages.claimText(strings, true, false, false), "Abholen")
end)

test("results name the failure with a neutral fallback", function()
	assertEquals(SeasonMessages.describeResult(strings, true, nil), "Belohnung erhalten")
	assertEquals(SeasonMessages.describeResult(strings, false, "locked_level"), "Noch nicht erreicht")
	assertEquals(SeasonMessages.describeResult(strings, false, "no_premium"), "Nur mit Premium")
	assertEquals(SeasonMessages.describeResult(strings, false, "already_claimed"), "Schon abgeholt")
	assertEquals(SeasonMessages.describeResult(strings, false, "other"), "?")
end)
