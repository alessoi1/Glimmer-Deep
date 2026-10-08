--!strict
local Framework = require("../Framework")
local GuestMessages = require("../../src/shared/GuestMessages")

local test = Framework.test
local assertEquals = Framework.assertEquals

local strings: GuestMessages.Strings = {
	guests = {
		hosting = "Gäste: %s",
		guestOf = "Du gräbst bei %s mit",
		earned = "(+%d Münzen heute)",
		notFriends = "Nur Freunde",
		full = "Voll",
		ownPlot = "Das ist dein Grundstück",
		tooFar = "Geh näher",
		unknown = "?",
	},
}

test("the host sees the guest names and today's bonus", function()
	assertEquals(GuestMessages.statusText(strings, { role = "host", names = { "Ann", "Bo" } }), "Gäste: Ann, Bo")
	assertEquals(
		GuestMessages.statusText(strings, { role = "host", names = { "Ann" }, earnedToday = 12 }),
		"Gäste: Ann (+12 Münzen heute)"
	)
end)

test("a guest sees whose plot they dig on", function()
	assertEquals(GuestMessages.statusText(strings, { role = "guest", hostName = "Cy" }), "Du gräbst bei Cy mit")
end)

test("no role or an empty guest list shows nothing", function()
	assertEquals(GuestMessages.statusText(strings, { role = "none" }), "")
	assertEquals(GuestMessages.statusText(strings, { role = "host", names = {} }), "")
	assertEquals(GuestMessages.statusText(strings, { role = "guest" }), "")
end)

test("reasons are named with a neutral fallback", function()
	assertEquals(GuestMessages.describeReason(strings, "not_friends"), "Nur Freunde")
	assertEquals(GuestMessages.describeReason(strings, "full"), "Voll")
	assertEquals(GuestMessages.describeReason(strings, "own_plot"), "Das ist dein Grundstück")
	assertEquals(GuestMessages.describeReason(strings, "too_far"), "Geh näher")
	assertEquals(GuestMessages.describeReason(strings, "x"), "?")
	assertEquals(GuestMessages.describeReason(strings, nil), "?")
end)
