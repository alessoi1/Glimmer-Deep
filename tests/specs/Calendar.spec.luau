--!strict
local Calendar = require("../../src/shared/Calendar")
local Framework = require("../Framework")

local test = Framework.test
local assertEquals = Framework.assertEquals

test("a day is 86400 seconds counted from the epoch", function()
	assertEquals(Calendar.dayOf(0), 0)
	assertEquals(Calendar.dayOf(86399), 0)
	assertEquals(Calendar.dayOf(86400), 1)
	assertEquals(Calendar.dayOf(1700000000), 19675)
end)

test("a week is seven days counted from the epoch", function()
	assertEquals(Calendar.weekOf(0), 0)
	assertEquals(Calendar.weekOf(604799), 0)
	assertEquals(Calendar.weekOf(604800), 1)
end)

test("a time slot of the given length", function()
	assertEquals(Calendar.slotOf(3600 * 4 - 1, 3600 * 4), 0)
	assertEquals(Calendar.slotOf(3600 * 4, 3600 * 4), 1)
end)

test("seconds until the next day or week", function()
	assertEquals(Calendar.secondsUntilNextDay(0), 86400)
	assertEquals(Calendar.secondsUntilNextDay(86399), 1)
	assertEquals(Calendar.secondsUntilNextWeek(604799), 1)
end)
