--!strict
local Framework = require("../Framework")
local Layers = require("../../src/shared/Config/Layers")
local MuseumConfig = require("../../src/shared/Config/Museum")
local MuseumLogic = require("../../src/shared/MuseumLogic")
local Onboarding = require("../../src/shared/Onboarding")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals
local assertNear = Framework.assertNear

local NOW = 1700000000
local HOUR = 3600

local function find(id: number, findId: string, layerId: string, value: number): MuseumLogic.Find
	return { id = id, findId = findId, layerId = layerId, rarityId = "rare", value = value }
end

local function profile(): MuseumLogic.MuseumProfile
	return {
		coins = 0,
		backpack = { ores = {}, finds = {} },
		museum = { displays = {}, incomeSince = NOW, admires = 0, week = 0, weekAdmires = 0 },
		onboarding = Onboarding.new(),
	}
end

local function context(now: number?, capacity: number?, multiplier: number?): MuseumLogic.Context
	return {
		now = now or NOW,
		slotCount = 4,
		config = MuseumConfig,
		coinMultiplier = multiplier or 1,
		backpackCapacity = capacity or 50,
	}
end

-- Slots ------------------------------------------------------------------------

test("the slot count follows the house level and is clamped", function()
	assertEquals(MuseumLogic.slotCount(MuseumConfig.slotsByHouseLevel, 1), 4)
	assertEquals(MuseumLogic.slotCount(MuseumConfig.slotsByHouseLevel, 2), 12)
	assertEquals(MuseumLogic.slotCount(MuseumConfig.slotsByHouseLevel, 4), 60)
	assertEquals(MuseumLogic.slotCount(MuseumConfig.slotsByHouseLevel, 0), 4)
	assertEquals(MuseumLogic.slotCount(MuseumConfig.slotsByHouseLevel, 99), 60)
end)

test("the shipped museum config has growing showcase counts", function()
	local previous = 0
	for _, count in MuseumConfig.slotsByHouseLevel do
		assertTrue(count > previous and count % 1 == 0)
		previous = count
	end
end)

-- Display and remove -------------------------------------------------------------

test("displaying moves the find from the backpack into the showcase", function()
	local p = profile()
	table.insert(p.backpack.finds, find(7, "fossil", "rock", 250))
	table.insert(p.backpack.finds, find(8, "amber", "rock", 100))
	local result = MuseumLogic.display(p, 7, 2, context())
	assertTrue(result.ok, tostring(result.reason))
	assertEquals(#p.backpack.finds, 1)
	assertEquals(p.backpack.finds[1].id, 8)
	assertEquals(#p.museum.displays, 1)
	assertEquals(p.museum.displays[1].slot, 2)
	assertEquals(p.museum.displays[1].find.id, 7)
	assertEquals(p.museum.displays[1].find.value, 250)
end)

test("displaying moves the onboarding on to the hint about the digger", function()
	local p = profile()
	table.insert(p.backpack.finds, find(1, "shell", "sand_clay", 10))
	MuseumLogic.display(p, 1, 1, context())
	assertEquals(p.onboarding.step, 6)
end)

test("displaying rejects unknown finds, bad slots and taken slots without changes", function()
	local p = profile()
	table.insert(p.backpack.finds, find(1, "shell", "sand_clay", 10))
	table.insert(p.backpack.finds, find(2, "shard", "sand_clay", 10))
	assertEquals(MuseumLogic.display(p, 99, 1, context()).reason, "no_such_find")
	assertEquals(MuseumLogic.display(p, "1" :: any, 1, context()).reason, "bad_input")
	assertEquals(MuseumLogic.display(p, 1, 0, context()).reason, "bad_slot")
	assertEquals(MuseumLogic.display(p, 1, 5, context()).reason, "bad_slot")
	assertEquals(MuseumLogic.display(p, 1, 1.5, context()).reason, "bad_slot")
	assertEquals(MuseumLogic.display(p, 1, "x" :: any, context()).reason, "bad_input")
	assertEquals(MuseumLogic.display(p, 1, 1, context()).ok, true)
	assertEquals(MuseumLogic.display(p, 2, 1, context()).reason, "slot_taken")
	assertEquals(#p.backpack.finds, 1)
	assertEquals(#p.museum.displays, 1)
end)

test("removing puts the find back into the backpack", function()
	local p = profile()
	table.insert(p.backpack.finds, find(1, "shell", "sand_clay", 10))
	MuseumLogic.display(p, 1, 3, context())
	local result = MuseumLogic.remove(p, 3, context())
	assertTrue(result.ok, tostring(result.reason))
	assertEquals(#p.museum.displays, 0)
	assertEquals(#p.backpack.finds, 1)
	assertEquals(p.backpack.finds[1].id, 1)
end)

test("removing from an empty slot or with a full backpack changes nothing", function()
	local p = profile()
	table.insert(p.backpack.finds, find(1, "shell", "sand_clay", 10))
	MuseumLogic.display(p, 1, 1, context())
	assertEquals(MuseumLogic.remove(p, 2, context()).reason, "empty_slot")
	assertEquals(MuseumLogic.remove(p, 0, context()).reason, "bad_slot")
	p.backpack.ores.coal = 5
	assertEquals(MuseumLogic.remove(p, 1, context(nil, 5)).reason, "backpack_full")
	assertEquals(#p.museum.displays, 1)
	assertEquals(#p.backpack.finds, 0)
end)

-- Visitor income -----------------------------------------------------------------

test("income grows with the displayed values and the time", function()
	local p = profile()
	table.insert(p.backpack.finds, find(1, "fossil", "rock", 1000))
	MuseumLogic.display(p, 1, 1, context())
	local perHour = 1000 * MuseumConfig.incomePerHourFraction
	assertEquals(MuseumLogic.pendingIncome(p.museum, NOW, MuseumConfig, 1), 0)
	assertEquals(MuseumLogic.pendingIncome(p.museum, NOW + 2 * HOUR, MuseumConfig, 1), math.floor(perHour * 2))
end)

test("income stops at the maximum hours", function()
	local p = profile()
	table.insert(p.backpack.finds, find(1, "fossil", "rock", 1000))
	MuseumLogic.display(p, 1, 1, context())
	local perHour = 1000 * MuseumConfig.incomePerHourFraction
	local atCap = MuseumLogic.pendingIncome(p.museum, NOW + MuseumConfig.incomeMaxHours * HOUR, MuseumConfig, 1)
	local later = MuseumLogic.pendingIncome(p.museum, NOW + 100 * HOUR, MuseumConfig, 1)
	assertEquals(atCap, math.floor(perHour * MuseumConfig.incomeMaxHours))
	assertEquals(later, atCap)
end)

test("the coin multiplier raises the income", function()
	local p = profile()
	table.insert(p.backpack.finds, find(1, "fossil", "rock", 1000))
	MuseumLogic.display(p, 1, 1, context())
	local base = MuseumLogic.pendingIncome(p.museum, NOW + HOUR, MuseumConfig, 1)
	local boosted = MuseumLogic.pendingIncome(p.museum, NOW + HOUR, MuseumConfig, 1.5)
	assertEquals(boosted, math.floor(base * 1.5))
end)

test("a clock that went backwards pays nothing", function()
	local p = profile()
	table.insert(p.backpack.finds, find(1, "fossil", "rock", 1000))
	MuseumLogic.display(p, 1, 1, context())
	assertEquals(MuseumLogic.pendingIncome(p.museum, NOW - 500, MuseumConfig, 1), 0)
end)

test("collecting pays the coins once and restarts the timer", function()
	local p = profile()
	table.insert(p.backpack.finds, find(1, "fossil", "rock", 1000))
	MuseumLogic.display(p, 1, 1, context())
	local result = MuseumLogic.collect(p, context(NOW + 2 * HOUR))
	assertTrue(result.ok)
	assertEquals(result.coins, 200) -- 100 per hour for two hours
	assertEquals(p.coins, 200)
	assertEquals(p.museum.incomeSince, NOW + 2 * HOUR)
	local again = MuseumLogic.collect(p, context(NOW + 2 * HOUR))
	assertTrue(not again.ok)
	assertEquals(again.reason, "nothing_to_collect")
	assertEquals(p.coins, 200)
end)

test("changing the showcases first pays the income so far", function()
	local p = profile()
	table.insert(p.backpack.finds, find(1, "fossil", "rock", 1000))
	table.insert(p.backpack.finds, find(2, "amber", "rock", 1000))
	MuseumLogic.display(p, 1, 1, context())
	MuseumLogic.display(p, 2, 2, context(NOW + HOUR))
	assertEquals(p.coins, 100)
	assertEquals(p.museum.incomeSince, NOW + HOUR)
	MuseumLogic.remove(p, 1, context(NOW + 2 * HOUR))
	assertEquals(p.coins, 100 + 200)
end)

test("the first display does not pay for the time before it", function()
	local p = profile()
	table.insert(p.backpack.finds, find(1, "fossil", "rock", 1000))
	MuseumLogic.display(p, 1, 1, context(NOW + 50 * HOUR))
	assertEquals(p.coins, 0)
	assertEquals(p.museum.incomeSince, NOW + 50 * HOUR)
end)

-- Sets ---------------------------------------------------------------------------

local function displayAll(p: MuseumLogic.MuseumProfile, finds: { MuseumLogic.Find })
	for index, entry in finds do
		table.insert(p.backpack.finds, entry)
		local result = MuseumLogic.display(p, entry.id :: number, index, context())
		assertTrue(result.ok, tostring(result.reason))
	end
end

test("a set is complete when every find type of the layer is on display", function()
	local p = profile()
	displayAll(p, { find(1, "shard", "sand_clay", 10) })
	assertEquals(#MuseumLogic.completedSets(p.museum, Layers), 0)
	table.insert(p.backpack.finds, find(2, "shell", "sand_clay", 10))
	MuseumLogic.display(p, 2, 2, context())
	local completed = MuseumLogic.completedSets(p.museum, Layers)
	assertEquals(#completed, 1)
	assertEquals(completed[1], "sand_clay")
end)

test("two finds of the same type do not complete a set", function()
	local p = profile()
	displayAll(p, { find(1, "shard", "sand_clay", 10), find(2, "shard", "sand_clay", 20) })
	assertEquals(#MuseumLogic.completedSets(p.museum, Layers), 0)
end)

test("set progress lists every layer with have and need", function()
	local p = profile()
	displayAll(p, { find(1, "shard", "sand_clay", 10) })
	local progress = MuseumLogic.setProgress(p.museum, Layers)
	assertEquals(#progress, #Layers)
	assertEquals(progress[1].layerId, "sand_clay")
	assertEquals(progress[1].have, 1)
	assertEquals(progress[1].need, 2)
	assertEquals(progress[1].complete, false)
	assertEquals(progress[3].have, 0)
	assertEquals(progress[3].need, 1)
end)

test("each completed set adds the configured bonus", function()
	local p = profile()
	displayAll(p, {
		find(1, "shard", "sand_clay", 10),
		find(2, "shell", "sand_clay", 10),
		find(3, "gemstone", "crystal", 500),
	})
	local part = MuseumLogic.modifierPart(p.museum, Layers, MuseumConfig)
	assertNear(part.coinBonus :: number, 2 * MuseumConfig.setCoinBonus, 1e-9)
	assertNear(part.luckBonus :: number, 2 * MuseumConfig.setLuckBonus, 1e-9)
end)

-- Admiration ---------------------------------------------------------------------

test("admiring counts for the total and the current week", function()
	local p = profile()
	MuseumLogic.admire(p.museum, 10)
	MuseumLogic.admire(p.museum, 10)
	assertEquals(p.museum.admires, 2)
	assertEquals(p.museum.week, 10)
	assertEquals(p.museum.weekAdmires, 2)
end)

test("a new week restarts the weekly count but keeps the total", function()
	local p = profile()
	MuseumLogic.admire(p.museum, 10)
	MuseumLogic.admire(p.museum, 11)
	assertEquals(p.museum.admires, 2)
	assertEquals(p.museum.week, 11)
	assertEquals(p.museum.weekAdmires, 1)
end)

test("the weekly count of an old week reads as zero", function()
	local p = profile()
	MuseumLogic.admire(p.museum, 10)
	assertEquals(MuseumLogic.weeklyAdmires(p.museum, 10), 1)
	assertEquals(MuseumLogic.weeklyAdmires(p.museum, 11), 0)
end)

-- View ---------------------------------------------------------------------------

test("the view lists showcases, backpack finds, sets and income for the client", function()
	local p = profile()
	table.insert(p.backpack.finds, find(1, "shard", "sand_clay", 10))
	table.insert(p.backpack.finds, find(2, "fossil", "rock", 1000))
	MuseumLogic.display(p, 2, 3, context())
	local view = MuseumLogic.view(p, Layers, context(NOW + HOUR), 10)
	assertEquals(view.slotCount, 4)
	assertEquals(#view.displays, 1)
	assertEquals(view.displays[1].slot, 3)
	assertEquals(#view.backpackFinds, 1)
	assertEquals(view.backpackFinds[1].id, 1)
	assertEquals(#view.sets, #Layers)
	assertEquals(view.pendingIncome, 100)
	assertEquals(view.incomePerHour, 100)
	assertEquals(view.admires, 0)
	assertEquals(view.weekAdmires, 0)
end)
