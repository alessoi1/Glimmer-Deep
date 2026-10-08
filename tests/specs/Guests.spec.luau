--!strict
local Framework = require("../Framework")
local Guests = require("../../src/shared/Guests")
local GuestConfig = require("../../src/shared/Config/Guests")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals

local config: Guests.Config = GuestConfig

local HOST = 100

local function with(changes: { [string]: any }): Guests.Config
	local copy: any = table.clone(config)
	for key, value in changes do
		copy[key] = value
	end
	return copy
end

-- Config -----------------------------------------------------------------------------

test("the shipped guest config is valid and allows four guests", function()
	local ok, reason = Guests.validateConfig(config)
	assertTrue(ok, reason)
	assertEquals(config.maxGuests, 4)
	assertTrue(config.friendsOnly)
end)

test("validateConfig rejects broken configs", function()
	assertTrue(not Guests.validateConfig(with({ maxGuests = 0 })))
	assertTrue(not Guests.validateConfig(with({ hostCoinsPerBlock = 1.5 })))
	assertTrue(not Guests.validateConfig(with({ hostDailyCap = -1 })))
	assertTrue(not Guests.validateConfig(with({ friendsOnly = "yes" })))
	assertTrue(not Guests.validateConfig(with({ joinDistance = 0 })))
end)

-- Joining ----------------------------------------------------------------------------

test("a friend joins and is a guest of the host", function()
	local registry = Guests.new(config)
	local ok, reason = registry.join(1, HOST, true)
	assertTrue(ok, reason)
	assertEquals(registry.hostOf(1), HOST)
	assertEquals(#registry.guestsOf(HOST), 1)
end)

test("nobody joins their own plot, twice, or without being a friend", function()
	local registry = Guests.new(config)
	local ok, reason = registry.join(HOST, HOST, true)
	assertTrue(not ok and reason == "own_plot")
	ok, reason = registry.join(1, HOST, false)
	assertTrue(not ok and reason == "not_friends")
	registry.join(1, HOST, true)
	ok, reason = registry.join(1, 200, true)
	assertTrue(not ok and reason == "already_guest")
	ok, reason = registry.join(1, HOST, true)
	assertTrue(not ok and reason == "already_guest")
	assertEquals(registry.hostOf(1), HOST, "unchanged")
end)

test("strangers can join when friendsOnly is off", function()
	local registry = Guests.new(with({ friendsOnly = false }))
	local ok = registry.join(1, HOST, false)
	assertTrue(ok)
end)

test("a plot hosts at most four guests", function()
	local registry = Guests.new(config)
	for guest = 1, 4 do
		assertTrue(registry.join(guest, HOST, true))
	end
	local ok, reason = registry.join(5, HOST, true)
	assertTrue(not ok and reason == "full")
	assertEquals(#registry.guestsOf(HOST), 4)
	assertEquals(registry.hostOf(5), nil)
	-- Another host is not affected.
	assertTrue(registry.join(5, 200, true))
end)

test("a freed place can be taken by another guest", function()
	local registry = Guests.new(config)
	for guest = 1, 4 do
		registry.join(guest, HOST, true)
	end
	assertEquals(registry.leave(2), HOST)
	assertEquals(#registry.guestsOf(HOST), 3)
	assertTrue(registry.join(5, HOST, true))
	assertEquals(#registry.guestsOf(HOST), 4)
end)

-- Leaving ----------------------------------------------------------------------------

test("leaving without being a guest does nothing", function()
	local registry = Guests.new(config)
	assertEquals(registry.leave(1), nil)
end)

test("a guest who left can join another plot", function()
	local registry = Guests.new(config)
	registry.join(1, HOST, true)
	registry.leave(1)
	assertEquals(registry.hostOf(1), nil)
	assertTrue(registry.join(1, 200, true))
	assertEquals(registry.hostOf(1), 200)
end)

test("when the host leaves the server the guests lose their visit", function()
	local registry = Guests.new(config)
	registry.join(1, HOST, true)
	registry.join(2, HOST, true)
	local orphaned = registry.forget(HOST)
	table.sort(orphaned)
	assertEquals(#orphaned, 2)
	assertEquals(orphaned[1], 1)
	assertEquals(registry.hostOf(1), nil)
	assertEquals(registry.hostOf(2), nil)
	assertEquals(#registry.guestsOf(HOST), 0)
end)

test("when a guest leaves the server the host keeps the others", function()
	local registry = Guests.new(config)
	registry.join(1, HOST, true)
	registry.join(2, HOST, true)
	local orphaned = registry.forget(1)
	assertEquals(#orphaned, 0)
	assertEquals(#registry.guestsOf(HOST), 1)
	assertEquals(registry.guestsOf(HOST)[1], 2)
end)

test("guestsOf returns a copy", function()
	local registry = Guests.new(config)
	registry.join(1, HOST, true)
	local list = registry.guestsOf(HOST)
	table.insert(list, 99)
	assertEquals(#registry.guestsOf(HOST), 1)
end)

-- Host bonus -------------------------------------------------------------------------

test("the host gets coins per guest block up to the daily cap", function()
	local small = with({ hostCoinsPerBlock = 2, hostDailyCap = 5 })
	local registry = Guests.new(small)
	assertEquals(registry.creditBlock(HOST, 20000), 2)
	assertEquals(registry.creditBlock(HOST, 20000), 2)
	assertEquals(registry.creditBlock(HOST, 20000), 1, "only what is left of the cap")
	assertEquals(registry.creditBlock(HOST, 20000), 0)
	assertEquals(registry.earnedToday(HOST, 20000), 5)
end)

test("the cap starts again on a new day and is per host", function()
	local small = with({ hostCoinsPerBlock = 2, hostDailyCap = 2 })
	local registry = Guests.new(small)
	assertEquals(registry.creditBlock(HOST, 1), 2)
	assertEquals(registry.creditBlock(HOST, 1), 0)
	assertEquals(registry.creditBlock(HOST, 2), 2, "next day")
	assertEquals(registry.creditBlock(200, 2), 2, "another host")
	assertEquals(registry.earnedToday(HOST, 1), 0, "an old day is not counted")
end)

test("the shipped daily cap covers at least one block", function()
	assertTrue(config.hostDailyCap >= config.hostCoinsPerBlock)
end)
