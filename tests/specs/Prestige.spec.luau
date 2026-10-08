--!strict
local Framework = require("../Framework")
local Layers = require("../../src/shared/Config/Layers")
local Modifiers = require("../../src/shared/Modifiers")
local Prestige = require("../../src/shared/Prestige")
local RebirthConfig = require("../../src/shared/Config/Rebirth")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals
local assertNear = Framework.assertNear

local config: Prestige.Config = RebirthConfig

local function with(changes: { [string]: any }): Prestige.Config
	local copy: any = table.clone(config)
	for key, value in changes do
		copy[key] = value
	end
	return copy
end

-- Config -----------------------------------------------------------------------------

test("the shipped rebirth config is valid", function()
	local ok, reason = Prestige.validateConfig(config)
	assertTrue(ok, reason)
end)

test("the required depth is the end of the deepest launch layer", function()
	assertEquals(config.requiredDepth, Layers[#Layers].maxDepth)
end)

test("validateConfig rejects broken configs", function()
	assertTrue(not Prestige.validateConfig(with({ requiredDepth = 0 })))
	assertTrue(not Prestige.validateConfig(with({ points = { base = 0, perRebirth = 1 } })))
	assertTrue(not Prestige.validateConfig(with({ points = { base = 5, perRebirth = -1 } })))
	assertTrue(not Prestige.validateConfig(with({ actionCooldown = -1 })))
	assertTrue(not Prestige.validateConfig(with({ order = { "ghost" } })))
	assertTrue(not Prestige.validateConfig(with({ order = {} })), "bonuses missing from the order")
	local function upgrade(def: { [string]: any }): Prestige.Config
		return with({ order = { "x" }, upgrades = { x = def } })
	end
	assertTrue(Prestige.validateConfig(upgrade({ costs = { 1, 2 }, perLevel = { coinBonus = 0.1 } })))
	assertTrue(not Prestige.validateConfig(upgrade({ costs = {}, perLevel = { coinBonus = 0.1 } })))
	assertTrue(not Prestige.validateConfig(upgrade({ costs = { 3, 1 }, perLevel = { coinBonus = 0.1 } })), "cheaper")
	assertTrue(not Prestige.validateConfig(upgrade({ costs = { 0 }, perLevel = { coinBonus = 0.1 } })))
	assertTrue(not Prestige.validateConfig(upgrade({ costs = { 1 }, perLevel = {} })))
	assertTrue(not Prestige.validateConfig(upgrade({ costs = { 1 }, perLevel = { warp = 1 } })))
	assertTrue(not Prestige.validateConfig(upgrade({ costs = { 1 }, perLevel = { coinBonus = -1 } })))
end)

-- Rebirth ----------------------------------------------------------------------------

test("a rebirth needs the required depth", function()
	assertTrue(not Prestige.canRebirth(config.requiredDepth - 0.5, config))
	assertTrue(Prestige.canRebirth(config.requiredDepth, config))
	assertTrue(Prestige.canRebirth(config.requiredDepth + 100, config))
end)

test("every rebirth gives more points than the one before", function()
	assertEquals(Prestige.pointsFor(0, config), 5)
	assertEquals(Prestige.pointsFor(1, config), 7)
	assertEquals(Prestige.pointsFor(3, config), 11)
end)

test("completing a rebirth gives the points and counts it", function()
	local state = Prestige.newState()
	assertEquals(Prestige.complete(state, config), 5)
	assertEquals(state.points, 5)
	assertEquals(state.rebirths, 1)
	assertEquals(Prestige.complete(state, config), 7)
	assertEquals(state.points, 12)
	assertEquals(state.rebirths, 2)
end)

-- Buying -----------------------------------------------------------------------------

test("buying a bonus takes points level by level", function()
	local state = Prestige.newState()
	state.points = 4
	local result = Prestige.buy(state, config, "coins")
	assertTrue(result.ok, result.reason)
	assertEquals(state.points, 3)
	assertEquals(state.levels.coins, 1)
	result = Prestige.buy(state, config, "coins")
	assertTrue(result.ok, result.reason)
	assertEquals(state.points, 1)
	assertEquals(state.levels.coins, 2)
	result = Prestige.buy(state, config, "coins")
	assertTrue(not result.ok and result.reason == "not_enough_points")
	assertEquals(state.levels.coins, 2)
	assertEquals(state.points, 1)
end)

test("an unknown bonus and the maximum level are rejected", function()
	local state = Prestige.newState()
	state.points = 1000
	local result = Prestige.buy(state, config, "ghost")
	assertTrue(not result.ok and result.reason == "unknown_upgrade")
	for _ = 1, #config.upgrades.luck.costs do
		assertTrue(Prestige.buy(state, config, "luck").ok)
	end
	result = Prestige.buy(state, config, "luck")
	assertTrue(not result.ok and result.reason == "max_level")
	assertEquals(state.levels.luck, #config.upgrades.luck.costs)
end)

-- Effect -----------------------------------------------------------------------------

test("no bought level gives no effect", function()
	assertEquals(Prestige.effectOf(Prestige.newState(), config), nil)
end)

test("bought levels add up per bonus and combine through Modifiers", function()
	local state = Prestige.newState()
	state.levels = { coins = 3, tempo = 2, luck = 1, offline = 5 }
	local part = Prestige.effectOf(state, config)
	assertTrue(part ~= nil)
	if part == nil then
		return
	end
	local result = Modifiers.combine({ part })
	assertNear(result.coinMultiplier, 1.3, 1e-9)
	assertNear(result.speedMultiplier, 1.1, 1e-9)
	assertNear(result.luck, 1.05, 1e-9)
	assertNear(result.offlineMultiplier, 1.5, 1e-9)
end)

test("a stored level above the maximum counts only up to the maximum", function()
	local state = Prestige.newState()
	state.levels = { coins = 99 }
	local part = Prestige.effectOf(state, config)
	assertTrue(part ~= nil and part.coinBonus ~= nil)
	assertNear(part and part.coinBonus or 0, 0.1 * #config.upgrades.coins.costs, 1e-9)
end)

-- View -------------------------------------------------------------------------------

test("the view shows points, next costs and whether a rebirth is possible", function()
	local state = Prestige.newState()
	state.points = 2
	state.rebirths = 1
	state.levels = { coins = 5 }
	local view = Prestige.view(state, 120, config)
	assertEquals(view.rebirths, 1)
	assertEquals(view.points, 2)
	assertTrue(not view.canRebirth)
	assertEquals(view.requiredDepth, config.requiredDepth)
	assertEquals(view.pointsForNext, 7)
	assertEquals(#view.upgrades, #config.order)
	local coins = view.upgrades[1]
	assertEquals(coins.id, "coins")
	assertEquals(coins.level, 5)
	assertEquals(coins.nextCost, nil)
	assertTrue(not coins.affordable)
	local tempo = view.upgrades[2]
	assertEquals(tempo.level, 0)
	assertEquals(tempo.nextCost, 1)
	assertTrue(tempo.affordable)
	assertTrue(Prestige.view(state, config.requiredDepth, config).canRebirth)
end)
