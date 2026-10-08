--!strict
local Framework = require("../Framework")
local MuseumMessages = require("../../src/shared/MuseumMessages")

local test = Framework.test
local assertEquals = Framework.assertEquals

local strings: MuseumMessages.Strings = {
	find = { fossil = "Fossil" },
	rarity = { epic = "Episch" },
	mutation = { golden = "Golden" },
	layer = { rock = "Fels" },
	museum = {
		find = "%s (%s)",
		findMutated = "%s %s (%s)",
		setProgress = "%s: %d/%d",
		setComplete = "%s: komplett",
		incomeReady = "%s bereit (%s pro Stunde)",
		displayed = "Ausgestellt",
		removed = "Zurück",
		collected = "+%s Münzen",
		admired = "Bewundert: %s",
		admiredBy = "%s bewundert dich",
		nothingToCollect = "Nichts",
		backpackFull = "Voll",
		slotTaken = "Belegt",
		noSuchFind = "Weg",
		alreadyAdmired = "Schon bewundert",
		emptyMuseum = "Leer",
		tooFar = "Zu weit",
		unknown = "?",
	},
}

test("a find reads as name and rarity, with the mutation in front", function()
	local plain = { id = 1, findId = "fossil", layerId = "rock", rarityId = "epic", value = 250 }
	assertEquals(MuseumMessages.describeFind(strings, plain), "Fossil (Episch)")
	local golden =
		{ id = 1, findId = "fossil", layerId = "rock", rarityId = "epic", mutationId = "golden", value = 2500 }
	assertEquals(MuseumMessages.describeFind(strings, golden), "Golden Fossil (Episch)")
end)

test("unknown ids fall back to the id", function()
	local odd = { id = 1, findId = "relic", layerId = "rock", rarityId = "mythic", value = 1 }
	assertEquals(MuseumMessages.describeFind(strings, odd), "relic (mythic)")
end)

test("set progress shows the counts or the finished set", function()
	local partial = { layerId = "rock", have = 1, need = 2, complete = false }
	local done = { layerId = "rock", have = 2, need = 2, complete = true }
	assertEquals(MuseumMessages.describeSet(strings, partial), "Fels: 1/2")
	assertEquals(MuseumMessages.describeSet(strings, done), "Fels: komplett")
end)

test("the income line uses thousands separators", function()
	assertEquals(MuseumMessages.describeIncome(strings, 1500, 250), "1.500 bereit (250 pro Stunde)")
end)

test("results name the outcome or the failure", function()
	assertEquals(MuseumMessages.describeResult(strings, true, "displayed", nil, 0, nil), "Ausgestellt")
	assertEquals(MuseumMessages.describeResult(strings, true, "removed", nil, 0, nil), "Zurück")
	assertEquals(MuseumMessages.describeResult(strings, true, "collected", nil, 1500, nil), "+1.500 Münzen")
	assertEquals(MuseumMessages.describeResult(strings, true, "admired", nil, 0, "Mia"), "Bewundert: Mia")
	assertEquals(MuseumMessages.describeResult(strings, true, "admiredBy", nil, 0, "Mia"), "Mia bewundert dich")
	assertEquals(MuseumMessages.describeResult(strings, false, nil, "nothing_to_collect", 0, nil), "Nichts")
	assertEquals(MuseumMessages.describeResult(strings, false, nil, "backpack_full", 0, nil), "Voll")
	assertEquals(MuseumMessages.describeResult(strings, false, nil, "slot_taken", 0, nil), "Belegt")
	assertEquals(MuseumMessages.describeResult(strings, false, nil, "no_such_find", 0, nil), "Weg")
	assertEquals(MuseumMessages.describeResult(strings, false, nil, "already_admired", 0, nil), "Schon bewundert")
	assertEquals(MuseumMessages.describeResult(strings, false, nil, "empty_museum", 0, nil), "Leer")
	assertEquals(MuseumMessages.describeResult(strings, false, nil, "too_far", 0, nil), "Zu weit")
	assertEquals(MuseumMessages.describeResult(strings, false, nil, "whatever", 0, nil), "?")
end)
