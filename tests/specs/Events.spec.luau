--!strict
local Calendar = require("../../src/shared/Calendar")
local EventConfig = require("../../src/shared/Config/Events")
local Events = require("../../src/shared/Events")
local Framework = require("../Framework")
local Modifiers = require("../../src/shared/Modifiers")
local Mutations = require("../../src/shared/Config/Mutations")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals

local config: Events.Config = EventConfig

local function mutationIds(): { string }
	local ids = {}
	for _, mutation in Mutations do
		table.insert(ids, mutation.id)
	end
	return ids
end

local function with(changes: { [string]: any }): Events.Config
	local copy: any = table.clone(config)
	for key, value in changes do
		copy[key] = value
	end
	return copy
end

-- Config -----------------------------------------------------------------------------

test("the shipped event config is valid", function()
	local ok, reason = Events.validateConfig(config, mutationIds())
	assertTrue(ok, reason)
end)

test("every shipped event bonus uses known Modifiers fields", function()
	for id, def in config.events do
		for field in def.bonus or {} do
			assertTrue(table.find(Modifiers.knownFields, field) ~= nil, id .. " uses unknown field " .. field)
		end
	end
end)

test("validateConfig rejects broken configs", function()
	local ids = mutationIds()
	assertTrue(not Events.validateConfig(with({ rotation = {} }), ids))
	assertTrue(not Events.validateConfig(with({ rotation = { "ghost" } }), ids))
	assertTrue(not Events.validateConfig(with({ rotation = { "opening" } }), ids), "events missing from the rotation")
	local function event(def: { [string]: any }): Events.Config
		return with({ rotation = { "x" }, events = { x = def } })
	end
	assertTrue(Events.validateConfig(event({ mutation = { id = "golden", factor = 2 } }), ids))
	assertTrue(not Events.validateConfig(event({ mutation = { id = "ghost", factor = 2 } }), ids))
	assertTrue(not Events.validateConfig(event({ mutation = { id = "golden", factor = 0.5 } }), ids))
	assertTrue(not Events.validateConfig(event({ bonus = { warp = 1 } }), ids))
	assertTrue(not Events.validateConfig(event({ bonus = { luckBonus = -1 } }), ids))
	assertTrue(not Events.validateConfig(event({ hostCoinFactor = 0.5 }), ids))
end)

-- Rotation ---------------------------------------------------------------------------

test("the event follows the week number and starts again after the last one", function()
	local week = Calendar.secondsPerWeek
	local base = 2800 * week -- an arbitrary week boundary
	local first = Events.current(config, base)
	local ids = {}
	for index = 0, #config.rotation do
		table.insert(ids, Events.current(config, base + index * week).id)
	end
	assertEquals(ids[1], first.id)
	assertEquals(ids[#config.rotation + 1], first.id, "the rotation repeats")
	for index = 1, #config.rotation do
		assertEquals(ids[index], config.rotation[(first.week + index - 1) % #config.rotation + 1])
	end
	assertTrue(ids[1] ~= ids[2])
end)

test("an event lasts the whole week and then changes", function()
	local week = Calendar.secondsPerWeek
	local start = 3000 * week
	local atStart = Events.current(config, start)
	assertEquals(atStart.secondsLeft, week)
	local almostEnd = Events.current(config, start + week - 1)
	assertEquals(almostEnd.id, atStart.id)
	assertEquals(almostEnd.secondsLeft, 1)
	local next = Events.current(config, start + week)
	assertTrue(next.id ~= atStart.id)
	assertEquals(next.week, atStart.week + 1)
end)

test("every server agrees: the same time gives the same event", function()
	assertEquals(Events.current(config, 1_800_000_000).id, Events.current(config, 1_800_000_000).id)
end)

-- Effects ----------------------------------------------------------------------------

test("an event returns its bonus part and host coin factor", function()
	assertTrue(Events.modifierPart(config.events.glow_week) ~= nil)
	assertEquals(Events.modifierPart({}), nil)
	assertEquals(Events.hostCoinFactor(config.events.friends_week), 2)
	assertEquals(Events.hostCoinFactor(config.events.glow_week), 1)
	assertEquals(Events.hostCoinFactor({}), 1)
	assertEquals(Events.hostCoinFactor({ hostCoinFactor = 0.2 }), 1, "never below 1")
end)

test("the boosted mutations of the rotation are all real mutations", function()
	local ids = mutationIds()
	for _, def in config.events do
		if def.mutation ~= nil then
			assertTrue(table.find(ids, def.mutation.id) ~= nil)
		end
	end
end)

test("the info carries what the client shows", function()
	local week = Calendar.secondsPerWeek
	local info = Events.info(Events.current(with({ rotation = { "glow_week" } }), 100 * week))
	assertEquals(info.id, "glow_week")
	assertEquals(info.mutationId, "glowing")
	assertEquals(info.mutationFactor, 4)
	assertEquals(info.hostCoinFactor, 1)
	assertEquals(info.secondsLeft, week)
	local friends = Events.info(Events.current(with({ rotation = { "friends_week" } }), 100 * week))
	assertEquals(friends.mutationId, nil)
	assertEquals(friends.hostCoinFactor, 2)
end)
