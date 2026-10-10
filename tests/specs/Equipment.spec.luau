--!strict
local EquipmentConfig = require("../../src/shared/Config/Equipment")
local Equipment = require("../../src/shared/Equipment")
local Framework = require("../Framework")
local Ores = require("../../src/shared/Config/Ores")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals
local assertNear = Framework.assertNear

local config: Equipment.Config = EquipmentConfig

local function wallet(coins: number): Equipment.Wallet
	return { coins = coins }
end

local function stashWith(ores: { [string]: number }): Equipment.Stash
	return { ores = ores }
end

test("shipped equipment config is valid and every tier ore has a price", function()
	local ok, reason = Equipment.validateConfig(config)
	assertTrue(ok, reason)
	for _, tier in config.tiers do
		assertTrue(Ores[tier.ore] ~= nil, "no price for ore " .. tier.ore)
	end
end)

test("validateConfig rejects broken values", function()
	local function bad(change: (copy: any) -> ()): boolean
		local copy: any = table.clone(config)
		copy.tiers = table.clone(config.tiers)
		copy.lifeShare = table.clone(config.lifeShare)
		copy.oreCost = table.clone(config.oreCost)
		copy.coinCost = table.clone(config.coinCost)
		change(copy)
		local ok = Equipment.validateConfig(copy)
		return not ok
	end
	assertTrue(bad(function(c)
		c.tiers = {}
	end))
	assertTrue(bad(function(c)
		c.lifeShare.helmet = 0.9
	end))
	assertTrue(bad(function(c)
		c.oreCost.weapon = 0
	end))
	assertTrue(bad(function(c)
		c.coinCost.boots = -1
	end))
	assertTrue(bad(function(c)
		c.shopMaxTier = 99
	end))
	assertTrue(bad(function(c)
		c.tiers = { { id = "a", ore = "x", life = 50, damage = 5 }, { id = "b", ore = "y", life = 40, damage = 9 } }
	end))
	assertTrue(bad(function(c)
		c.slots = { "weapon", "weapon" }
	end))
end)

-- Stats ----------------------------------------------------------------------------------

test("an empty state has the base life and damage", function()
	local state = Equipment.new()
	local stats = Equipment.stats(state, config)
	assertEquals(stats.life, config.baseLife)
	assertEquals(stats.damage, config.baseDamage)
	assertEquals(stats.strength, Equipment.strengthOf(config.baseLife, config.baseDamage))
end)

test("a full copper set and weapon give exactly the tier values", function()
	local state = Equipment.new()
	for _, slot in config.slots do
		local gear = Equipment.grant(state, config, slot, 1, "crafted")
		assertTrue(gear ~= nil)
		assertTrue(Equipment.equip(state, (gear :: Equipment.Gear).id).ok)
	end
	local stats = Equipment.stats(state, config)
	assertNear(stats.life, config.baseLife + config.tiers[1].life, 1e-9)
	assertEquals(stats.damage, config.tiers[1].damage)
end)

test("armor pieces add their share of the tier's life", function()
	local state = Equipment.new()
	local helmet = Equipment.grant(state, config, "helmet", 3, "crafted") :: Equipment.Gear
	Equipment.equip(state, helmet.id)
	local stats = Equipment.stats(state, config)
	assertNear(stats.life, config.baseLife + config.tiers[3].life * config.lifeShare.helmet, 1e-9)
	assertEquals(stats.damage, config.baseDamage)
end)

test("better gear means more strength at every step", function()
	local previous = 0
	for tier = 1, #config.tiers do
		local state = Equipment.new()
		for _, slot in config.slots do
			local gear = Equipment.grant(state, config, slot, tier, "crafted") :: Equipment.Gear
			Equipment.equip(state, gear.id)
		end
		local strength = Equipment.stats(state, config).strength
		assertTrue(strength > previous, "tier " .. tier)
		previous = strength
	end
end)

-- Cost and crafting ----------------------------------------------------------------------------

test("cost grows with the tier and uses the ore of the tier", function()
	local first = Equipment.cost(config, "weapon", 1)
	local second = Equipment.cost(config, "weapon", 2)
	assertEquals(first.ore, config.tiers[1].ore)
	assertEquals(second.ore, config.tiers[2].ore)
	assertEquals(first.oreCount, config.oreCost.weapon)
	assertEquals(first.coins, config.coinCost.weapon)
	assertEquals(second.coins, config.coinCost.weapon * config.coinGrowth)
	assertEquals(Equipment.cost(config, "nothing", 1), nil)
	assertEquals(Equipment.cost(config, "weapon", 99), nil)
end)

test("crafting takes the ore from the stash and the coins and adds one piece", function()
	local state = Equipment.new()
	local cost = Equipment.cost(config, "helmet", 1) :: Equipment.Cost
	local stash = stashWith({ [cost.ore] = cost.oreCount + 3 })
	local money = wallet(cost.coins + 10)
	local result = Equipment.craft(state, stash, money, config, "helmet", 1)
	assertTrue(result.ok, tostring(result.reason))
	assertEquals(stash.ores[cost.ore], 3)
	assertEquals(money.coins, 10)
	assertEquals(#state.owned, 1)
	assertEquals(state.owned[1].source, "crafted")
	assertEquals(state.owned[1].bound, false)
	assertEquals(state.nextId, 2)
end)

test("crafting fails without changes when ore or coins are missing", function()
	local state = Equipment.new()
	local cost = Equipment.cost(config, "armor", 2) :: Equipment.Cost
	local noOre =
		Equipment.craft(state, stashWith({ [cost.ore] = cost.oreCount - 1 }), wallet(cost.coins), config, "armor", 2)
	assertEquals(noOre.ok, false)
	assertEquals(noOre.reason, "not_enough_ore")
	local stash = stashWith({ [cost.ore] = cost.oreCount })
	local noCoins = Equipment.craft(state, stash, wallet(cost.coins - 1), config, "armor", 2)
	assertEquals(noCoins.reason, "not_enough_coins")
	assertEquals(stash.ores[cost.ore], cost.oreCount)
	assertEquals(#state.owned, 0)
	assertEquals(state.nextId, 1)
end)

test("crafting rejects unknown slots and tiers", function()
	local state = Equipment.new()
	local stash = stashWith({ copper = 1000 })
	assertEquals(Equipment.craft(state, stash, wallet(1e6), config, "cape", 1).reason, "unknown_slot")
	assertEquals(Equipment.craft(state, stash, wallet(1e6), config, "weapon", 0).reason, "unknown_tier")
	assertEquals(Equipment.craft(state, stash, wallet(1e6), config, "weapon", 1.5).reason, "unknown_tier")
	assertEquals(Equipment.craft(state, stash, wallet(1e6), config, "weapon", 99).reason, "unknown_tier")
end)

test("crafting stops at the limit of owned pieces", function()
	local state = Equipment.new()
	for _ = 1, config.maxOwned do
		Equipment.grant(state, config, "boots", 1, "crafted")
	end
	local cost = Equipment.cost(config, "boots", 1) :: Equipment.Cost
	local result = Equipment.craft(state, stashWith({ [cost.ore] = 999 }), wallet(1e6), config, "boots", 1)
	assertEquals(result.reason, "too_many_items")
end)

test("the stash empties exactly by the ore that was used up", function()
	local state = Equipment.new()
	local cost = Equipment.cost(config, "weapon", 1) :: Equipment.Cost
	local stash = stashWith({ [cost.ore] = cost.oreCount })
	assertTrue(Equipment.craft(state, stash, wallet(cost.coins), config, "weapon", 1).ok)
	assertEquals(stash.ores[cost.ore], nil, "a used up entry is removed")
end)

-- Deposit -------------------------------------------------------------------------------------------

test("deposit moves tier ore from the backpack to the stash and leaves the rest", function()
	local backpackOres = { copper = 7, coal = 5, iron = 2, moss_fern = 3 }
	local stash = stashWith({ copper = 1 })
	local moved = Equipment.deposit(backpackOres, stash, config)
	assertEquals(moved, 9)
	assertEquals(stash.ores.copper, 8)
	assertEquals(stash.ores.iron, 2)
	assertEquals(backpackOres.copper, nil)
	assertEquals(backpackOres.iron, nil)
	assertEquals(backpackOres.coal, 5)
	assertEquals(backpackOres.moss_fern, 3)
end)

test("deposit with nothing to move changes nothing", function()
	local backpackOres = { coal = 5 }
	local stash = stashWith({})
	assertEquals(Equipment.deposit(backpackOres, stash, config), 0)
	assertEquals(next(stash.ores), nil)
end)

-- Equip -----------------------------------------------------------------------------------------------

test("equipping replaces the piece in the same slot", function()
	local state = Equipment.new()
	local a = Equipment.grant(state, config, "weapon", 1, "crafted") :: Equipment.Gear
	local b = Equipment.grant(state, config, "weapon", 2, "crafted") :: Equipment.Gear
	assertTrue(Equipment.equip(state, a.id).ok)
	assertEquals(state.equipped.weapon, a.id)
	assertTrue(Equipment.equip(state, b.id).ok)
	assertEquals(state.equipped.weapon, b.id)
	assertEquals(Equipment.stats(state, config).damage, config.tiers[2].damage)
end)

test("equip and unequip reject things that are not owned", function()
	local state = Equipment.new()
	assertEquals(Equipment.equip(state, 42).reason, "not_owned")
	assertEquals(Equipment.unequip(state, config, "weapon").reason, "nothing_equipped")
	assertEquals(Equipment.unequip(state, config, "cape").reason, "unknown_slot")
	local gear = Equipment.grant(state, config, "helmet", 1, "crafted") :: Equipment.Gear
	Equipment.equip(state, gear.id)
	assertTrue(Equipment.unequip(state, config, "helmet").ok)
	assertEquals(state.equipped.helmet, nil)
	assertEquals(#state.owned, 1, "unequipping keeps the piece")
end)

-- Grant and trade rules ------------------------------------------------------------------------------------

test("grant rejects unknown slots and tiers", function()
	local state = Equipment.new()
	assertEquals(Equipment.grant(state, config, "cape", 1, "crafted"), nil)
	assertEquals(Equipment.grant(state, config, "weapon", 0, "crafted"), nil)
	assertEquals(Equipment.grant(state, config, "weapon", #config.tiers + 1, "crafted"), nil)
	assertEquals(state.nextId, 1)
end)

test("pieces from the shop are bound to the account and capped in tier", function()
	local state = Equipment.new()
	local ok = Equipment.grant(state, config, "weapon", config.shopMaxTier, "shop") :: Equipment.Gear
	assertTrue(ok ~= nil)
	assertEquals(ok.bound, true)
	assertEquals(Equipment.tradable(ok), false)
	assertEquals(Equipment.grant(state, config, "weapon", config.shopMaxTier + 1, "shop"), nil)
end)

test("crafted and chest pieces can be traded, shop pieces cannot", function()
	local state = Equipment.new()
	local crafted = Equipment.grant(state, config, "weapon", 1, "crafted") :: Equipment.Gear
	local chest = Equipment.grant(state, config, "armor", 2, "chest") :: Equipment.Gear
	assertEquals(Equipment.tradable(crafted), true)
	assertEquals(Equipment.tradable(chest), true)
end)

test("shop gear is never better than crafted gear of the same tier", function()
	local shop = Equipment.new()
	local crafted = Equipment.new()
	for _, slot in config.slots do
		Equipment.equip(shop, (Equipment.grant(shop, config, slot, config.shopMaxTier, "shop") :: Equipment.Gear).id)
		Equipment.equip(
			crafted,
			(Equipment.grant(crafted, config, slot, config.shopMaxTier, "crafted") :: Equipment.Gear).id
		)
	end
	local a, b = Equipment.stats(shop, config), Equipment.stats(crafted, config)
	assertEquals(a.life, b.life)
	assertEquals(a.damage, b.damage)
end)

test("ids are unique and never reused", function()
	local state = Equipment.new()
	local first = Equipment.grant(state, config, "boots", 1, "crafted") :: Equipment.Gear
	local second = Equipment.grant(state, config, "boots", 1, "crafted") :: Equipment.Gear
	assertTrue(first.id ~= second.id)
	assertEquals(state.nextId, 3)
end)

-- Validate --------------------------------------------------------------------------------------------------------

test("validate accepts a state built by the module", function()
	local state = Equipment.new()
	local a = Equipment.grant(state, config, "weapon", 2, "crafted") :: Equipment.Gear
	Equipment.grant(state, config, "helmet", 1, "shop")
	Equipment.equip(state, a.id)
	local ok, reason = Equipment.validate(state, config)
	assertTrue(ok, reason)
end)

test("validate rejects corrupt equipment", function()
	local function bad(change: (state: any) -> ()): boolean
		local state: any = Equipment.new()
		local a = Equipment.grant(state, config, "weapon", 2, "crafted") :: Equipment.Gear
		Equipment.equip(state, a.id)
		change(state)
		local ok = Equipment.validate(state, config)
		return not ok
	end
	assertTrue(bad(function(s)
		s.owned[1].tier = 99
	end))
	assertTrue(bad(function(s)
		s.owned[1].slot = "cape"
	end))
	assertTrue(bad(function(s)
		s.owned[1].source = "gift"
	end))
	assertTrue(bad(function(s)
		s.owned[1].bound = "yes"
	end))
	assertTrue(bad(function(s)
		s.owned[2] = table.clone(s.owned[1])
	end))
	assertTrue(bad(function(s)
		s.equipped.weapon = 77
	end))
	assertTrue(bad(function(s)
		s.equipped.helmet = s.owned[1].id
	end))
	assertTrue(bad(function(s)
		s.nextId = 1
	end))
	assertTrue(bad(function(s)
		s.owned[1].source = "shop"
		s.owned[1].tier = config.shopMaxTier + 1
		s.owned[1].bound = true
	end))
	assertTrue(bad(function(s)
		s.owned[1].source = "shop"
		s.owned[1].bound = false
	end))
end)
