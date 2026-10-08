--!strict
local BackpackConfig = require("../../src/shared/Config/Backpack")
local DiggerConfig = require("../../src/shared/Config/Digger")
local Framework = require("../Framework")
local ShovelConfig = require("../../src/shared/Config/Shovel")
local Onboarding = require("../../src/shared/Onboarding")
local UpgradeAction = require("../../src/shared/UpgradeAction")
local UpgradeConfig = require("../../src/shared/Config/Upgrade")
local Upgrades = require("../../src/shared/Upgrades")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals

local tracks: UpgradeAction.Tracks = {
	shovel = { levels = ShovelConfig.levels },
	backpack = { levels = BackpackConfig.levels },
	digger = { levels = DiggerConfig.levels },
}

local function profile(coins: number): UpgradeAction.UpgraderProfile
	return { coins = coins, upgradeLevels = { shovel = 1, backpack = 1, digger = 1 }, onboarding = Onboarding.new() }
end

test("the shipped upgrade order names only existing tracks", function()
	assertTrue(#UpgradeConfig.order > 0)
	for _, upgradeId in UpgradeConfig.order do
		assertTrue(tracks[upgradeId] ~= nil, upgradeId)
	end
end)

test("buying pays the price from the profile coins and raises the level", function()
	local p = profile(250)
	local result = UpgradeAction.buy(p, tracks, "shovel")
	assertTrue(result.ok)
	assertEquals(result.newLevel, 2)
	assertEquals(p.upgradeLevels.shovel, 2)
	assertEquals(p.coins, 250 - ShovelConfig.levels[2].price)
end)

test("not enough coins changes nothing", function()
	local p = profile(ShovelConfig.levels[2].price - 1)
	local result = UpgradeAction.buy(p, tracks, "shovel")
	assertTrue(not result.ok)
	assertEquals(result.reason, "not_enough_coins")
	assertEquals(p.upgradeLevels.shovel, 1)
	assertEquals(p.coins, ShovelConfig.levels[2].price - 1)
end)

test("the top level cannot be bought again", function()
	local p = profile(10000000)
	p.upgradeLevels.backpack = #BackpackConfig.levels
	local result = UpgradeAction.buy(p, tracks, "backpack")
	assertEquals(result.reason, "max_level")
	assertEquals(p.coins, 10000000)
end)

test("ids from the client that are not a known string are rejected", function()
	local p = profile(1000)
	assertEquals(UpgradeAction.buy(p, tracks, "pet").reason, "unknown_upgrade")
	assertEquals(UpgradeAction.buy(p, tracks, nil).reason, "bad_id")
	assertEquals(UpgradeAction.buy(p, tracks, 5).reason, "bad_id")
	assertEquals(UpgradeAction.buy(p, tracks, {}).reason, "bad_id")
	assertEquals(UpgradeAction.buy(p, tracks, string.rep("a", 100)).reason, "unknown_upgrade")
	assertEquals(p.coins, 1000)
end)

test("a broken profile is rejected without changes", function()
	local p = profile(1000)
	p.upgradeLevels.shovel = 99
	local result = UpgradeAction.buy(p, tracks, "shovel")
	assertEquals(result.reason, "invalid_state")
	assertEquals(p.coins, 1000)
end)

test("snapshot lists upgrades in the configured order with next level and price", function()
	local p = profile(150)
	local entries = UpgradeAction.snapshot(p, tracks, { "shovel", "backpack" })
	assertEquals(#entries, 2)
	assertEquals(entries[1].id, "shovel")
	assertEquals(entries[1].level, 1)
	assertEquals(entries[1].maxLevel, #ShovelConfig.levels)
	assertEquals(entries[1].nextPrice, ShovelConfig.levels[2].price)
	assertEquals(entries[1].nextId, ShovelConfig.levels[2].id)
	assertEquals(entries[1].canAfford, true)
	assertEquals(entries[2].id, "backpack")
	assertEquals(entries[2].nextCapacity, BackpackConfig.levels[2].capacity)
	assertEquals(entries[2].canAfford, true)
end)

test("snapshot marks too expensive and maxed upgrades", function()
	local p = profile(50)
	p.upgradeLevels.backpack = #BackpackConfig.levels
	local entries = UpgradeAction.snapshot(p, tracks, { "shovel", "backpack" })
	assertEquals(entries[1].canAfford, false)
	assertEquals(entries[2].nextPrice, nil)
	assertEquals(entries[2].canAfford, false)
end)

test("snapshot does not change the profile and skips unknown ids", function()
	local p = profile(500)
	local entries = UpgradeAction.snapshot(p, tracks, { "pet", "shovel" })
	assertEquals(#entries, 1)
	assertEquals(p.coins, 500)
	assertEquals(p.upgradeLevels.shovel, 1)
end)

test("buy accepts the plain Upgrades tracks", function()
	local plain: Upgrades.Tracks = { shovel = { levels = ShovelConfig.levels } }
	local p = profile(500)
	assertTrue(UpgradeAction.buy(p, plain, "shovel").ok)
end)

test("a purchase moves the onboarding to the museum step, a failed one does not", function()
	local p = profile(5)
	UpgradeAction.buy(p, tracks, "shovel")
	assertEquals(p.onboarding.step, 1)
	p.coins = 500
	UpgradeAction.buy(p, tracks, "shovel")
	assertEquals(p.onboarding.step, 5)
end)

test("the digger is an upgrade that shows its next output", function()
	local p = profile(DiggerConfig.levels[2].price)
	local entries = UpgradeAction.snapshot(p, tracks, { "digger" })
	assertEquals(entries[1].nextPrice, DiggerConfig.levels[2].price)
	assertEquals(entries[1].nextBlocksPerHour, DiggerConfig.levels[2].blocksPerHour)
	assertTrue(UpgradeAction.buy(p, tracks, "digger").ok)
	assertEquals(p.upgradeLevels.digger, 2)
end)
