--!strict
local Framework = require("../Framework")
local Modifiers = require("../../src/shared/Modifiers")
local ShopConfig = require("../../src/shared/Config/Shop")
local ShopLogic = require("../../src/shared/ShopLogic")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals

local config: ShopLogic.Config = ShopConfig

local function with(changes: { [string]: any }): ShopLogic.Config
	local copy: { [string]: any } = table.clone(config :: any)
	for key, value in changes do
		copy[key] = value
	end
	return copy :: any
end

-- Config -----------------------------------------------------------------------------

test("the shipped shop config is valid", function()
	local ok, reason = ShopLogic.validateConfig(config)
	assertTrue(ok, reason)
end)

test("validateConfig rejects broken passes", function()
	local function pass(changes: { [string]: any }): ShopLogic.Config
		local entry: { [string]: any } = { gamePassId = 1, robux = 100, effect = { capacityBonus = 0.1 } }
		for key, value in changes do
			entry[key] = value
		end
		return with({ order = { "p" }, passes = { p = entry } })
	end
	assertTrue(ShopLogic.validateConfig(pass({})))
	assertTrue(not ShopLogic.validateConfig(pass({ robux = 0 })))
	assertTrue(not ShopLogic.validateConfig(pass({ robux = 9.5 })))
	assertTrue(not ShopLogic.validateConfig(pass({ gamePassId = -1 })))
	assertTrue(not ShopLogic.validateConfig(pass({ effect = { speedOfLight = 3 } })), "unknown effect")
	assertTrue(not ShopLogic.validateConfig(with({ order = { "ghost" } })), "order names an unknown pass")
	assertTrue(not ShopLogic.validateConfig(with({ order = {} })), "a pass is missing from the order")
end)

test("every effect field is a known Modifiers field", function()
	for key, def in config.passes do
		for field in def.effect or {} do
			assertTrue(table.find(Modifiers.knownFields, field) ~= nil, key .. " uses unknown field " .. field)
		end
	end
end)

-- Effects ---------------------------------------------------------------------------

test("an owned pass gives its effect, an unowned one nothing", function()
	assertEquals(ShopLogic.effectOf({}, "backpack_plus", config), nil)
	local part = ShopLogic.effectOf({ backpack_plus = true }, "backpack_plus", config)
	assertTrue(part ~= nil)
	assertEquals((part :: Modifiers.Part).capacityBonus, 0.2)
end)

test("a pass with only a perk or an unknown key gives no part", function()
	assertEquals(ShopLogic.effectOf({ quick_travel = true }, "quick_travel", config), nil)
	assertEquals(ShopLogic.effectOf({ ghost = true }, "ghost", config), nil)
end)

test("the pass for double coins only doubles ore sales", function()
	local part = ShopLogic.effectOf({ double_coins = true }, "double_coins", config) :: Modifiers.Part
	local result = Modifiers.combine({ part })
	assertEquals(result.oreSaleFactor, 2)
	assertEquals(result.coinMultiplier, 1)
	assertEquals(result.luck, 1)
end)

test("a perk is recognized only while the pass is owned", function()
	assertEquals(ShopLogic.hasPerk({}, "quickTravel", config), false)
	assertEquals(ShopLogic.hasPerk({ quick_travel = true }, "quickTravel", config), true)
	assertEquals(ShopLogic.hasPerk({ night_shift = true }, "quickTravel", config), false)
end)

-- View ------------------------------------------------------------------------------

test("the view lists the passes in order with price, state and availability", function()
	local view = ShopLogic.view({ night_shift = true }, config, true)
	assertEquals(view.available, true)
	assertEquals(#view.passes, #config.order)
	assertEquals(view.passes[1].key, "night_shift")
	assertEquals(view.passes[1].owned, true)
	assertEquals(view.passes[1].robux, 299)
	assertEquals(view.passes[2].owned, false)
end)

test("a pass without an id from the dashboard cannot be bought yet", function()
	local view = ShopLogic.view({}, config, true)
	for _, pass in view.passes do
		assertEquals(pass.buyable, config.passes[pass.key].gamePassId > 0)
	end
	local ready = with({ order = { "p" }, passes = { p = { gamePassId = 77, robux = 100 } } })
	assertEquals(ShopLogic.view({}, ready, true).passes[1].buyable, true)
	assertEquals(ShopLogic.view({ p = true }, ready, true).passes[1].buyable, false, "already owned")
end)

test("the shop is closed while it is not available (first minutes)", function()
	assertEquals(ShopLogic.view({}, config, false).available, false)
end)

test("finding a pass by its id from the dashboard", function()
	local ready = with({ order = { "p" }, passes = { p = { gamePassId = 77, robux = 100 } } })
	assertEquals(ShopLogic.keyOfGamePass(ready, 77), "p")
	assertEquals(ShopLogic.keyOfGamePass(ready, 78), nil)
	assertEquals(ShopLogic.keyOfGamePass(config, 0), nil, "unconfigured ids never match")
end)
