--!strict
local BackpackConfig = require("../../src/shared/Config/Backpack")
local Framework = require("../Framework")
local Ores = require("../../src/shared/Config/Ores")
local Selling = require("../../src/shared/Selling")
local ShovelConfig = require("../../src/shared/Config/Shovel")
local Upgrades = require("../../src/shared/Upgrades")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals

local tracks: Upgrades.Tracks = {
	shovel = { levels = ShovelConfig.levels },
	backpack = { levels = BackpackConfig.levels },
}

local function newState(coins: number): Upgrades.State
	return { coins = coins, levels = { shovel = 1, backpack = 1 } }
end

test("shipped upgrade tracks are valid", function()
	local ok, reason = Upgrades.validateTracks(tracks)
	assertTrue(ok, reason)
end)

test("buying the next shovel level pays the price and raises the level", function()
	local state = newState(250)
	local result = Upgrades.purchase(state, tracks, "shovel")
	assertEquals(result.ok, true)
	assertEquals(result.price, 100)
	assertEquals(result.newLevel, 2)
	assertEquals(state.coins, 150)
	assertEquals(state.levels.shovel, 2)
	assertEquals(state.levels.backpack, 1)
end)

test("exactly enough coins is enough, one coin less is not", function()
	local exact = newState(100)
	assertEquals(Upgrades.purchase(exact, tracks, "shovel").ok, true)
	assertEquals(exact.coins, 0)

	local short = newState(99)
	local result = Upgrades.purchase(short, tracks, "shovel")
	assertEquals(result.ok, false)
	assertEquals(result.reason, "not_enough_coins")
	assertEquals(short.coins, 99)
	assertEquals(short.levels.shovel, 1)
end)

test("the backpack track is bought independently of the shovel", function()
	local state = newState(1000)
	local result = Upgrades.purchase(state, tracks, "backpack")
	assertEquals(result.ok, true)
	assertEquals(state.levels.backpack, 2)
	assertEquals(state.levels.shovel, 1)
	assertEquals(state.coins, 1000 - BackpackConfig.levels[2].price)
end)

test("the maximum level cannot be exceeded", function()
	local state = newState(10000000)
	state.levels.shovel = #ShovelConfig.levels
	local result = Upgrades.purchase(state, tracks, "shovel")
	assertEquals(result.ok, false)
	assertEquals(result.reason, "max_level")
	assertEquals(state.coins, 10000000)
	assertEquals(state.levels.shovel, #ShovelConfig.levels)
end)

test("an unknown upgrade id is rejected without changes", function()
	local state = newState(1000)
	for _, upgradeId in { "pickaxe", "", "coins", "__index" } do
		local result = Upgrades.purchase(state, tracks, upgradeId)
		assertEquals(result.ok, false)
		assertEquals(result.reason, "unknown_upgrade")
	end
	assertEquals(state.coins, 1000)
end)

test("corrupt state is rejected without changes", function()
	local function expectInvalid(state: Upgrades.State)
		local before = state.coins
		local result = Upgrades.purchase(state, tracks, "shovel")
		assertEquals(result.ok, false)
		assertEquals(result.reason, "invalid_state")
		assertTrue(state.coins == before or (before ~= before and state.coins ~= state.coins), "coins changed")
	end
	expectInvalid(newState(-5))
	expectInvalid(newState(10.5))
	expectInvalid(newState(0 / 0))
	expectInvalid({ coins = 500, levels = { backpack = 1 } })
	expectInvalid({ coins = 500, levels = { shovel = 0, backpack = 1 } })
	expectInvalid({ coins = 500, levels = { shovel = 99, backpack = 1 } })
	expectInvalid({ coins = 500, levels = { shovel = 1.5, backpack = 1 } })
end)

test("consecutive purchases drain the right amounts", function()
	local state = newState(100 + 300 + 1000)
	assertEquals(Upgrades.purchase(state, tracks, "shovel").ok, true)
	assertEquals(Upgrades.purchase(state, tracks, "shovel").ok, true)
	assertEquals(Upgrades.purchase(state, tracks, "shovel").ok, true)
	assertEquals(state.coins, 0)
	assertEquals(state.levels.shovel, 4)
	assertEquals(Upgrades.purchase(state, tracks, "shovel").ok, false)
end)

test("getNextPrice returns the price or nil at the maximum", function()
	local state = newState(0)
	assertEquals(Upgrades.getNextPrice(state, tracks, "shovel"), 100)
	assertEquals(Upgrades.getNextPrice(state, tracks, "pickaxe"), nil)
	state.levels.shovel = #ShovelConfig.levels
	assertEquals(Upgrades.getNextPrice(state, tracks, "shovel"), nil)
end)

test("validateTracks rejects bad prices", function()
	local function oneTrack(prices: { number }): Upgrades.Tracks
		local levels = {}
		for _, price in prices do
			table.insert(levels, { price = price })
		end
		return { test = { levels = levels } }
	end
	assertEquals((Upgrades.validateTracks(oneTrack({}))), false)
	assertEquals((Upgrades.validateTracks(oneTrack({ 5, 10 }))), false)
	assertEquals((Upgrades.validateTracks(oneTrack({ 0, 10, 10 }))), false)
	assertEquals((Upgrades.validateTracks(oneTrack({ 0, 10.5 }))), false)
	assertEquals((Upgrades.validateTracks(oneTrack({ 0, 10, 50 }))), true)
end)

test("the onboarding trip (full backpack with the golden first find) affords shovel level 2", function()
	-- 49 ore slots plus the guaranteed golden common find (10 coins x10 = 100).
	local state = newState(0)
	local sold = Selling.sellAll({
		ores = { coal = 25, copper = 24 },
		finds = { { value = 100 } },
	}, Ores)
	assertEquals(sold.oreCoins, 25 * 1 + 24 * 2)
	state.coins += sold.coins
	assertTrue(state.coins >= 100, "expected at least 100 coins, got " .. tostring(state.coins))
	assertEquals(Upgrades.purchase(state, tracks, "shovel").ok, true)
end)

test("ore alone from one starting backpack does not yet afford it", function()
	-- Documents the balance: the first upgrade needs the onboarding find or a second trip.
	local sold = Selling.sellAll({ ores = { coal = 25, copper = 25 }, finds = {} }, Ores)
	assertTrue(sold.coins < 100, "got " .. tostring(sold.coins))
end)
