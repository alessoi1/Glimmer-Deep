--!strict
local Framework = require("../Framework")
local OfflineMessages = require("../../src/shared/OfflineMessages")

local test = Framework.test
local assertEquals = Framework.assertEquals

local strings: OfflineMessages.Strings = {
	ore = { coal = "Kohle", copper = "Kupfer" },
	find = { fossil = "Fossil" },
	rarity = { epic = "Episch" },
	mutation = { golden = "Golden" },
	layer = {},
	offline = {
		title = "Während du weg warst",
		away = "Du warst %s weg.",
		blocks = "Dein Bagger hat %d Blöcke gegraben.",
		oreLine = "%d× %s",
		findsLabel = "Seltene Funde:",
		capped = "Der Bagger arbeitet höchstens %s lang.",
		lost = "Das Lager war voll, %d Blöcke gingen verloren.",
		nothing = "Es war nichts zu holen.",
		durationHours = "%d Std %d Min",
		durationMinutes = "%d Min",
	},
	museum = {
		find = "%s (%s)",
		findMutated = "%s %s (%s)",
		setProgress = "",
		setComplete = "",
		incomeReady = "",
		displayed = "",
		removed = "",
		collected = "",
		admired = "",
		admiredBy = "",
		nothingToCollect = "",
		backpackFull = "",
		slotTaken = "",
		noSuchFind = "",
		alreadyAdmired = "",
		emptyMuseum = "",
		tooFar = "",
		unknown = "",
	},
}

test("durations read as hours and minutes", function()
	assertEquals(OfflineMessages.formatDuration(strings, 59), "0 Min")
	assertEquals(OfflineMessages.formatDuration(strings, 600), "10 Min")
	assertEquals(OfflineMessages.formatDuration(strings, 3600), "1 Std 0 Min")
	assertEquals(OfflineMessages.formatDuration(strings, 3600 * 5 + 60 * 7 + 30), "5 Std 7 Min")
end)

local function report(changes: { [string]: any }?): OfflineMessages.Report
	local base: { [string]: any } = {
		seconds = 7200,
		hours = 2,
		capped = false,
		blocks = 120,
		lost = 0,
		ores = { coal = 100, copper = 18 },
		finds = { { findId = "fossil", layerId = "rock", rarityId = "epic", mutationId = "golden" } },
	}
	for key, value in changes or {} do
		base[key] = value
	end
	return base :: any
end

test("a report lists the time, the blocks, the ore and the finds", function()
	local lines = OfflineMessages.describeReport(strings, report(), 4 * 3600)
	assertEquals(lines[1], "Du warst 2 Std 0 Min weg.")
	assertEquals(lines[2], "Dein Bagger hat 120 Blöcke gegraben.")
	assertEquals(lines[3], "100× Kohle")
	assertEquals(lines[4], "18× Kupfer")
	assertEquals(lines[5], "Seltene Funde:")
	assertEquals(lines[6], "Golden Fossil (Episch)")
	assertEquals(#lines, 6)
end)

test("a capped absence says how long the digger works at most", function()
	local lines = OfflineMessages.describeReport(strings, report({ capped = true }), 4 * 3600)
	assertEquals(lines[#lines], "Der Bagger arbeitet höchstens 4 Std 0 Min lang.")
end)

test("lost blocks and an empty yield are mentioned", function()
	local lost = OfflineMessages.describeReport(strings, report({ lost = 15 }), 4 * 3600)
	assertEquals(lost[#lost], "Das Lager war voll, 15 Blöcke gingen verloren.")
	local empty = OfflineMessages.describeReport(strings, report({ blocks = 0, ores = {}, finds = {} }), 4 * 3600)
	assertEquals(empty[#empty], "Es war nichts zu holen.")
end)
