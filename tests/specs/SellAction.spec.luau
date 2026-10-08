--!strict
local Framework = require("../Framework")
local OreConfig = require("../../src/shared/Config/Ores")
local SellAction = require("../../src/shared/SellAction")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals

local function profile(): SellAction.SellerProfile
	return { coins = 10, backpack = { ores = {}, finds = {} } }
end

test("selling ore adds its price to the coins and empties the ore", function()
	local p = profile()
	p.backpack.ores.coal = 4
	p.backpack.ores.copper = 3
	local result = SellAction.perform(p, OreConfig, nil)
	assertTrue(result.ok)
	assertEquals(result.coinsEarned, 4 * OreConfig.coal + 3 * OreConfig.copper)
	assertEquals(p.coins, 10 + 4 * OreConfig.coal + 3 * OreConfig.copper)
	assertEquals(next(p.backpack.ores), nil)
	assertEquals(result.oreCount, 7)
end)

test("rare finds are sold at their own value", function()
	local p = profile()
	table.insert(p.backpack.finds, { value = 250 })
	table.insert(p.backpack.finds, { value = 40 })
	local result = SellAction.perform(p, OreConfig, nil)
	assertTrue(result.ok)
	assertEquals(result.coinsEarned, 290)
	assertEquals(p.coins, 300)
	assertEquals(#p.backpack.finds, 0)
	assertEquals(result.findCount, 2)
end)

test("the multiplier applies to ore only", function()
	local p = profile()
	p.backpack.ores.coal = 10
	table.insert(p.backpack.finds, { value = 100 })
	local result = SellAction.perform(p, OreConfig, 2)
	assertEquals(result.coinsEarned, 10 * OreConfig.coal * 2 + 100)
end)

test("an empty backpack is rejected and nothing changes", function()
	local p = profile()
	local result = SellAction.perform(p, OreConfig, nil)
	assertTrue(not result.ok)
	assertEquals(result.reason, "empty")
	assertEquals(p.coins, 10)
end)

test("ore without a price stays in the backpack and is reported", function()
	local p = profile()
	p.backpack.ores.coal = 2
	p.backpack.ores.mystery = 5
	local result = SellAction.perform(p, OreConfig, nil)
	assertTrue(result.ok)
	assertEquals(p.backpack.ores.mystery, 5)
	assertEquals(result.unknownOres.mystery, 5)
end)

test("a backpack with only unpriced ore counts as nothing to sell", function()
	local p = profile()
	p.backpack.ores.mystery = 5
	local result = SellAction.perform(p, OreConfig, nil)
	assertTrue(not result.ok)
	assertEquals(result.reason, "empty")
	assertEquals(p.backpack.ores.mystery, 5)
	assertEquals(p.coins, 10)
end)

test("coins stay a non-negative integer", function()
	local p = profile()
	p.backpack.ores.coal = 7
	SellAction.perform(p, OreConfig, 1.5)
	assertTrue(p.coins >= 0 and p.coins % 1 == 0)
end)
