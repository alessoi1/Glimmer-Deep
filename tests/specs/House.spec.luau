--!strict
local Framework = require("../Framework")
local House = require("../../src/shared/House")
local HouseConfig = require("../../src/shared/Config/House")
local MuseumConfig = require("../../src/shared/Config/Museum")
local PlotConfig = require("../../src/shared/Config/Plot")
local PlotLogic = require("../../src/server/PlotLogic")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals

local config: House.Config = HouseConfig

local function subject(coins: number, level: number?): House.Subject
	return { coins = coins, house = { level = level or 1, decor = House.newDecor() } }
end

local function with(changes: { [string]: any }): House.Config
	local copy: any = table.clone(config)
	for key, value in changes do
		copy[key] = value
	end
	return copy
end

-- Config -----------------------------------------------------------------------------

test("the shipped house config is valid", function()
	local ok, reason = House.validateConfig(config)
	assertTrue(ok, reason)
end)

test("the house levels match the concept and the museum config", function()
	assertEquals(config.maxLevel, 2, "launch scope: levels 1 and 2")
	assertEquals(config.upgradeCosts[2], 10000)
	assertTrue(config.maxLevel <= #MuseumConfig.slotsByHouseLevel, "every house level has a showcase count")
	assertTrue(MuseumConfig.slotsByHouseLevel[2] > MuseumConfig.slotsByHouseLevel[1])
end)

test("validateConfig rejects broken configs", function()
	assertTrue(not House.validateConfig(with({ maxLevel = 0 })))
	assertTrue(not House.validateConfig(with({ maxLevel = 3 })), "no cost for level 3")
	assertTrue(not House.validateConfig(with({ upgradeCosts = { 0, 0 } })), "upgrading must cost coins")
	assertTrue(not House.validateConfig(with({ upgradeCosts = { 0, 1.5 } })))
	assertTrue(not House.validateConfig(with({ decorSlotsByLevel = { 4, 2 } })), "must not shrink")
	assertTrue(not House.validateConfig(with({ actionCooldown = -1 })))
	assertTrue(not House.validateConfig(with({ order = { "ghost" } })))
	assertTrue(not House.validateConfig(with({ order = {} })), "items missing from the order")
	local items: any = table.clone(config.items)
	items.rug = { price = 0, sizeX = 1, sizeY = 1, sizeZ = 1, color = { r = 0, g = 0, b = 0 } }
	assertTrue(not House.validateConfig(with({ items = items })))
end)

-- Upgrade ----------------------------------------------------------------------------

test("the upgrade costs coins and raises the level", function()
	local player = subject(10500)
	local result = House.upgrade(player, config)
	assertTrue(result.ok, result.reason)
	assertEquals(player.coins, 500)
	assertEquals(player.house.level, 2)
end)

test("the upgrade needs enough coins and stops at the highest level", function()
	local poor = subject(9999)
	local result = House.upgrade(poor, config)
	assertTrue(not result.ok and result.reason == "not_enough_coins")
	assertEquals(poor.coins, 9999)
	assertEquals(poor.house.level, 1)

	local maxed = subject(1e9, 2)
	result = House.upgrade(maxed, config)
	assertTrue(not result.ok and result.reason == "max_level")
	assertEquals(maxed.coins, 1e9)
end)

-- Decoration -------------------------------------------------------------------------

test("decoration cannot be bought in a house without places", function()
	local player = subject(5000, 1)
	local result = House.buy(player, config, "rug")
	assertTrue(not result.ok and result.reason == "no_decor_yet")
	assertEquals(player.coins, 5000)
end)

test("buying decoration takes coins once", function()
	local player = subject(1000, 2)
	local result = House.buy(player, config, "rug")
	assertTrue(result.ok, result.reason)
	assertEquals(player.coins, 400)
	assertTrue(player.house.decor.owned.rug)
	result = House.buy(player, config, "rug")
	assertTrue(not result.ok and result.reason == "already_owned")
	assertEquals(player.coins, 400)
	result = House.buy(player, config, "ghost")
	assertTrue(not result.ok and result.reason == "unknown_item")
	result = House.buy(player, config, "fountain")
	assertTrue(not result.ok and result.reason == "not_enough_coins")
	assertEquals(player.coins, 400)
end)

test("placing needs an owned item and a valid place", function()
	local player = subject(10000, 2)
	local result = House.place(player, config, "rug", 1)
	assertTrue(not result.ok and result.reason == "not_owned")
	House.buy(player, config, "rug")
	for _, slot in { 0, 7, 1.5, -1 } do
		result = House.place(player, config, "rug", slot)
		assertTrue(not result.ok and result.reason == "bad_slot", "slot " .. slot)
	end
	result = House.place(player, config, "rug", 3)
	assertTrue(result.ok, result.reason)
	assertEquals(#player.house.decor.placed, 1)
end)

test("an item stands in one place; a new item takes over an occupied place", function()
	local player = subject(10000, 2)
	House.buy(player, config, "rug")
	House.buy(player, config, "lantern")
	House.place(player, config, "rug", 1)
	House.place(player, config, "rug", 2)
	assertEquals(#player.house.decor.placed, 1, "moved, not copied")
	assertEquals(player.house.decor.placed[1].slot, 2)
	House.place(player, config, "lantern", 2)
	assertEquals(#player.house.decor.placed, 1, "the lantern replaced the rug")
	assertEquals(player.house.decor.placed[1].id, "lantern")
	assertTrue(player.house.decor.owned.rug, "the rug is still owned")
end)

test("removing takes the item back but keeps it owned", function()
	local player = subject(10000, 2)
	House.buy(player, config, "banner")
	House.place(player, config, "banner", 4)
	local result = House.remove(player, 4)
	assertTrue(result.ok, result.reason)
	assertEquals(#player.house.decor.placed, 0)
	assertTrue(player.house.decor.owned.banner)
	result = House.remove(player, 4)
	assertTrue(not result.ok and result.reason == "empty_slot")
end)

-- View -------------------------------------------------------------------------------

test("the view shows the next cost, ownership and places", function()
	local player = subject(20000, 1)
	local view = House.view(player, config)
	assertEquals(view.level, 1)
	assertEquals(view.nextCost, 10000)
	assertTrue(view.canUpgrade)
	assertEquals(view.decorSlots, 0)
	assertEquals(#view.items, #config.order)
	assertTrue(view.items[1].owned == false and view.items[1].placedSlot == nil)

	House.upgrade(player, config)
	House.buy(player, config, "rug")
	House.place(player, config, "rug", 2)
	view = House.view(player, config)
	assertEquals(view.level, 2)
	assertEquals(view.nextCost, nil)
	assertTrue(not view.canUpgrade)
	assertEquals(view.decorSlots, 6)
	assertEquals(#view.placed, 1)
	local rug
	for _, item in view.items do
		if item.id == "rug" then
			rug = item
		end
	end
	assertTrue(rug ~= nil and rug.owned and rug.placedSlot == 2)
end)

test("the view hides places that no longer exist or unknown items", function()
	local player = subject(0, 1)
	player.house.decor.owned.rug = true
	player.house.decor.placed = { { slot = 5, id = "rug" }, { slot = 1, id = "retired" } }
	assertEquals(#House.view(player, config).placed, 0)
end)

-- World ------------------------------------------------------------------------------

test("every decoration place fits on the plot without touching shaft, pads or showcases", function()
	local half = PlotConfig.size / 2
	local maxSlots = config.decorSlotsByLevel[config.maxLevel]
	local boxes = {}
	for slot = 1, maxSlots do
		table.insert(boxes, PlotLogic.decorBox(PlotConfig, slot))
	end
	local obstacles = {
		PlotLogic.spawnBox(PlotConfig),
		PlotLogic.sellBox(PlotConfig),
		PlotLogic.museumSignBox(PlotConfig),
		PlotLogic.houseSignBox(PlotConfig),
		PlotLogic.guestSignBox(PlotConfig),
		PlotLogic.rebirthSignBox(PlotConfig),
		{ name = "Shaft", sizeX = PlotConfig.shaftSize, sizeY = 1, sizeZ = PlotConfig.shaftSize, x = 0, y = 0, z = 0 },
	}
	for number = 1, MuseumConfig.slotsByHouseLevel[config.maxLevel] do
		table.insert(obstacles, PlotLogic.vitrineBox(PlotConfig, number))
	end
	local function overlap(a: PlotLogic.Box, b: PlotLogic.Box): boolean
		return math.abs(a.x - b.x) < (a.sizeX + b.sizeX) / 2 and math.abs(a.z - b.z) < (a.sizeZ + b.sizeZ) / 2
	end
	for index, box in boxes do
		assertTrue(math.abs(box.x) + box.sizeX / 2 <= half, "decor " .. index .. " inside the plot (x)")
		assertTrue(math.abs(box.z) + box.sizeZ / 2 <= half, "decor " .. index .. " inside the plot (z)")
		for _, other in obstacles do
			assertTrue(not overlap(box, other), "decor " .. index .. " overlaps " .. other.name)
		end
		for otherIndex = index + 1, #boxes do
			assertTrue(not overlap(box, boxes[otherIndex]), "decor " .. index .. " overlaps " .. otherIndex)
		end
	end
end)
