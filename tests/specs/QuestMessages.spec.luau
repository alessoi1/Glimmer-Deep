--!strict
local Framework = require("../Framework")
local QuestMessages = require("../../src/shared/QuestMessages")

local test = Framework.test
local assertEquals = Framework.assertEquals

local strings: QuestMessages.Strings = {
	quests = {
		text = { sell_trips = "Verkaufe %d-mal", dig_blocks = "Grabe %d Blöcke" },
		progress = "%d/%d",
		loginLine = "Tag %d von %d: %s Münzen",
		bonusLine = "Alle geschafft: +%s Münzen",
		resetIn = "Neue Aufgaben in %s",
		durationHours = "%d Std %d Min",
		durationMinutes = "%d Min",
		paid = "+%s Münzen",
		notDone = "Noch nicht geschafft",
		alreadyClaimed = "Schon abgeholt",
		completed = "Aufgabe geschafft: %s",
		unknown = "?",
	},
}

local function quest(id: string, target: number, progress: number): QuestMessages.QuestView
	return {
		id = id,
		event = "sold",
		target = target,
		progress = progress,
		reward = 150,
		done = progress >= target,
		claimed = false,
	}
end

test("a quest reads as its text with the target and the progress", function()
	assertEquals(QuestMessages.describeQuest(strings, quest("sell_trips", 3, 1)), "Verkaufe 3-mal (1/3)")
	assertEquals(QuestMessages.describeQuest(strings, quest("dig_blocks", 150, 150)), "Grabe 150 Blöcke (150/150)")
end)

test("an unknown quest falls back to its id", function()
	assertEquals(QuestMessages.describeQuest(strings, quest("mystery", 2, 0)), "mystery (0/2)")
end)

test("the quest title alone has no progress", function()
	assertEquals(QuestMessages.questTitle(strings, quest("sell_trips", 3, 1)), "Verkaufe 3-mal")
end)

test("the login line shows the day and the reward", function()
	assertEquals(
		QuestMessages.describeLogin(strings, { streak = 3, reward = 1500, claimable = true, chainLength = 7 }),
		"Tag 3 von 7: 1.500 Münzen"
	)
end)

test("the bonus line shows the bonus", function()
	assertEquals(QuestMessages.describeBonus(strings, 500), "Alle geschafft: +500 Münzen")
end)

test("the reset time reads as hours and minutes", function()
	assertEquals(QuestMessages.describeReset(strings, 3600 * 5 + 60 * 12), "Neue Aufgaben in 5 Std 12 Min")
	assertEquals(QuestMessages.describeReset(strings, 600), "Neue Aufgaben in 10 Min")
end)

test("results name the payout or the failure", function()
	assertEquals(QuestMessages.describeResult(strings, true, 1500, nil), "+1.500 Münzen")
	assertEquals(QuestMessages.describeResult(strings, false, 0, "not_done"), "Noch nicht geschafft")
	assertEquals(QuestMessages.describeResult(strings, false, 0, "already_claimed"), "Schon abgeholt")
	assertEquals(QuestMessages.describeResult(strings, false, 0, "whatever"), "?")
end)

test("the completed toast names the quest", function()
	assertEquals(
		QuestMessages.describeCompleted(strings, quest("sell_trips", 3, 3)),
		"Aufgabe geschafft: Verkaufe 3-mal"
	)
end)
