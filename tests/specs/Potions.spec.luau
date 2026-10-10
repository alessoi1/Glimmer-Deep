--!strict
local Framework = require("../Framework")
local Layers = require("../../src/shared/Config/Layers")
local Ores = require("../../src/shared/Config/Ores")
local PotionsConfig = require("../../src/shared/Config/Potions")
local Potions = require("../../src/shared/Potions")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals
local assertNear = Framework.assertNear

local config: Potions.Config = PotionsConfig
local NOW = 10000

local function stash(ores: { [string]: number }): Potions.Stash
	return { ores = ores }
end

local function wallet(coins: number): Potions.Wallet
	return { coins = coins }
end

test("shipped potion config is valid, every herb exists in a layer and has a price", function()
	local ok, reason = Potions.validateConfig(config)
	assertTrue(ok, reason)
	local herbs: { [string]: boolean } = {}
	for _, layer in Layers do
		for _, herb in layer.herbs do
			herbs[herb] = true
		end
	end
	for id, potion in config.potions do
		for herb in potion.recipe do
			assertTrue(herbs[herb] == true, id .. " needs unknown herb " .. herb)
			assertTrue(Ores[herb] ~= nil, "no price for herb " .. herb)
		end
	end
end)

test("validateConfig rejects broken values", function()
	local function bad(change: (copy: any) -> ()): boolean
		local copy: any = table.clone(config)
		copy.potions = table.clone(config.potions)
		copy.potions.heal = table.clone(config.potions.heal)
		copy.order = table.clone(config.order)
		change(copy)
		local ok = Potions.validateConfig(copy)
		return not ok
	end
	assertTrue(bad(function(c)
		c.order = { "heal", "ghost" }
	end))
	assertTrue(bad(function(c)
		c.order = { "heal" }
	end))
	assertTrue(bad(function(c)
		c.potions.heal.recipe = {}
	end))
	assertTrue(bad(function(c)
		c.potions.heal.effect = "teleport"
	end))
	assertTrue(bad(function(c)
		c.potions.heal.amount = 2
	end))
	assertTrue(bad(function(c)
		c.potions.heal.coins = -1
	end))
	assertTrue(bad(function(c)
		c.maxDuration = 10
	end))
	assertTrue(bad(function(c)
		c.maxBrewAtOnce = 0
	end))
end)

-- Brewing --------------------------------------------------------------------------------------

test("brewing takes the herbs from the stash and the coins and adds potions", function()
	local state = Potions.new()
	local herbs = stash({ moss_fern = 7 })
	local money = wallet(100)
	local result = Potions.brew(state, herbs, money, config, "heal", 2)
	assertTrue(result.ok, tostring(result.reason))
	assertEquals(herbs.ores.moss_fern, 1)
	assertEquals(money.coins, 100 - 2 * config.potions.heal.coins)
	assertEquals(state.owned.heal, 2)
end)

test("brewing with a two-herb recipe uses both herbs", function()
	local state = Potions.new()
	local herbs = stash({ moss_fern = 2, shadow_mushroom = 1 })
	assertTrue(Potions.brew(state, herbs, wallet(1000), config, "speed", 1).ok)
	assertEquals(herbs.ores.moss_fern, nil)
	assertEquals(herbs.ores.shadow_mushroom, nil)
end)

test("brewing fails without changes when something is missing or wrong", function()
	local state = Potions.new()
	local herbs = stash({ moss_fern = 2 })
	local money = wallet(1000)
	assertEquals(Potions.brew(state, herbs, money, config, "heal", 1).reason, "not_enough_herbs")
	assertEquals(Potions.brew(state, stash({ moss_fern = 9 }), wallet(5), config, "heal", 1).reason, "not_enough_coins")
	assertEquals(Potions.brew(state, herbs, money, config, "ghost", 1).reason, "unknown_potion")
	assertEquals(Potions.brew(state, herbs, money, config, "heal", 0).reason, "bad_count")
	assertEquals(Potions.brew(state, herbs, money, config, "heal", 1.5).reason, "bad_count")
	assertEquals(Potions.brew(state, herbs, money, config, "heal", config.maxBrewAtOnce + 1).reason, "bad_count")
	assertEquals(herbs.ores.moss_fern, 2)
	assertEquals(money.coins, 1000)
	assertEquals(next(state.owned), nil)
end)

test("brewing stops at the limit of potions of one kind", function()
	local state = Potions.new()
	state.owned.heal = config.maxOwnedPerPotion - 1
	local herbs = stash({ moss_fern = 100 })
	assertEquals(Potions.brew(state, herbs, wallet(1000), config, "heal", 2).reason, "too_many")
	assertTrue(Potions.brew(state, herbs, wallet(1000), config, "heal", 1).ok)
	assertEquals(state.owned.heal, config.maxOwnedPerPotion)
end)

test("depositHerbs moves only the herbs the recipes use and leaves other items", function()
	local backpack = { moss_fern = 4, shadow_mushroom = 1, coal = 9, copper = 3 }
	local herbs = stash({ moss_fern = 1 })
	local moved = Potions.depositHerbs(backpack, herbs, config)
	assertEquals(moved, 5)
	assertEquals(herbs.ores.moss_fern, 5)
	assertEquals(herbs.ores.shadow_mushroom, 1)
	assertEquals(backpack.moss_fern, nil)
	assertEquals(backpack.coal, 9)
	assertEquals(backpack.copper, 3)
end)

-- Drinking ---------------------------------------------------------------------------------------

test("drinking a healing potion uses one and reports the share of life", function()
	local state = Potions.new()
	state.owned.heal = 2
	local result = Potions.drink(state, config, "heal", NOW)
	assertTrue(result.ok, tostring(result.reason))
	assertEquals(result.effect, "heal")
	assertNear(result.amount :: number, config.potions.heal.amount, 1e-9)
	assertEquals(state.owned.heal, 1)
	assertEquals(next(state.active), nil, "an instant potion is not an active effect")
end)

test("a healing potion has a cooldown, other potions do not", function()
	local state = Potions.new()
	state.owned.heal = 3
	assertTrue(Potions.drink(state, config, "heal", NOW).ok)
	assertEquals(Potions.drink(state, config, "heal", NOW + config.potions.heal.cooldown - 1).reason, "cooldown")
	assertEquals(state.owned.heal, 2, "a refused drink costs nothing")
	assertTrue(Potions.drink(state, config, "heal", NOW + config.potions.heal.cooldown).ok)
end)

test("a timed potion starts an effect for its duration", function()
	local state = Potions.new()
	state.owned.strength = 1
	local result = Potions.drink(state, config, "strength", NOW)
	assertTrue(result.ok, tostring(result.reason))
	assertEquals(result.expiresAt, NOW + config.potions.strength.duration)
	assertEquals(state.active.strength, NOW + config.potions.strength.duration)
end)

test("drinking again refreshes the time but never beyond the maximum", function()
	local state = Potions.new()
	state.owned.strength = 5
	Potions.drink(state, config, "strength", NOW)
	Potions.drink(state, config, "strength", NOW + 100)
	assertEquals(state.active.strength, NOW + 100 + config.potions.strength.duration)
	assertTrue(state.active.strength - (NOW + 100) <= config.maxDuration)
end)

test("drinking something you do not own or that does not exist fails", function()
	local state = Potions.new()
	assertEquals(Potions.drink(state, config, "luck", NOW).reason, "none_owned")
	assertEquals(Potions.drink(state, config, "ghost", NOW).reason, "unknown_potion")
	assertEquals(next(state.active), nil)
end)

test("owned entries that reach zero are removed", function()
	local state = Potions.new()
	state.owned.luck = 1
	Potions.drink(state, config, "luck", NOW)
	assertEquals(state.owned.luck, nil)
end)

-- Effects ----------------------------------------------------------------------------------------------

test("with nothing active all effects are neutral", function()
	local effects = Potions.effects(Potions.new(), config, NOW)
	assertEquals(effects.damage, 1)
	assertEquals(effects.speed, 1)
	assertEquals(effects.luck, 1)
	assertEquals(effects.nightVision, false)
end)

test("active potions give their multipliers until they run out", function()
	local state = Potions.new()
	state.owned.strength, state.owned.luck, state.owned.night_vision = 1, 1, 1
	Potions.drink(state, config, "strength", NOW)
	Potions.drink(state, config, "luck", NOW)
	Potions.drink(state, config, "night_vision", NOW)
	local active = Potions.effects(state, config, NOW + 10)
	assertNear(active.damage, config.potions.strength.amount, 1e-9)
	assertNear(active.luck, config.potions.luck.amount, 1e-9)
	assertEquals(active.nightVision, true)
	local over = Potions.effects(state, config, NOW + 301)
	assertEquals(over.damage, 1)
	assertEquals(over.luck, 1)
	assertEquals(over.nightVision, false)
end)

test("prune removes expired effects and old cooldowns", function()
	local state = Potions.new()
	state.owned.strength, state.owned.heal = 1, 1
	Potions.drink(state, config, "strength", NOW)
	Potions.drink(state, config, "heal", NOW)
	Potions.prune(state, NOW + 1000)
	assertEquals(next(state.active), nil)
	assertEquals(next(state.cooldownUntil), nil)
end)

test("potions can be traded", function()
	assertEquals(Potions.tradable(), true)
end)

-- Validate --------------------------------------------------------------------------------------------------

test("validate accepts a state built by the module and rejects corrupt ones", function()
	local state = Potions.new()
	state.owned.luck = 2
	state.owned.strength = 1
	Potions.drink(state, config, "strength", NOW)
	local ok, reason = Potions.validate(state, config)
	assertTrue(ok, reason)

	local function bad(change: (s: any) -> ()): boolean
		local copy: any = Potions.new()
		copy.owned.luck = 2
		change(copy)
		local valid = Potions.validate(copy, config)
		return not valid
	end
	assertTrue(bad(function(s)
		s.owned.ghost = 1
	end))
	assertTrue(bad(function(s)
		s.owned.luck = -1
	end))
	assertTrue(bad(function(s)
		s.owned.luck = 1.5
	end))
	assertTrue(bad(function(s)
		s.owned.luck = config.maxOwnedPerPotion + 1
	end))
	assertTrue(bad(function(s)
		s.active.ghost = 5
	end))
	assertTrue(bad(function(s)
		s.active.luck = "soon"
	end))
	assertTrue(bad(function(s)
		s.cooldownUntil.heal = -1
	end))
	assertTrue(bad(function(s)
		s.owned = nil
	end))
end)
