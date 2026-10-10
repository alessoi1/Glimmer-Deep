--!strict
local ChestLoot = require("../../src/shared/ChestLoot")
local ChestsConfig = require("../../src/shared/Config/Chests")
local Equipment = require("../../src/shared/Equipment")
local EquipmentConfig = require("../../src/shared/Config/Equipment")
local Framework = require("../Framework")
local PotionsConfig = require("../../src/shared/Config/Potions")
local Potions = require("../../src/shared/Potions")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals
local assertNear = Framework.assertNear
local scriptedRng = Framework.scriptedRng

local config: ChestLoot.Config = ChestsConfig
local deps = {
	equipment = EquipmentConfig :: Equipment.Config,
	potions = PotionsConfig :: Potions.Config,
}
local HERBS = { "moss_fern" }

local function roll(biomeIndex: number, rng: ChestLoot.Rng): { ChestLoot.Entry }
	return ChestLoot.roll(config, deps, biomeIndex, HERBS, rng)
end

test("shipped chest config is valid", function()
	local ok, reason = ChestLoot.validateConfig(config)
	assertTrue(ok, reason)
end)

test("validateConfig rejects broken values", function()
	local function bad(change: (copy: any) -> ()): boolean
		local copy: any = table.clone(config)
		copy.rolls = table.clone(config.rolls)
		copy.entries = table.clone(config.entries)
		change(copy)
		local ok = ChestLoot.validateConfig(copy)
		return not ok
	end
	assertTrue(bad(function(c)
		c.rolls = { min = 0, max = 2 }
	end))
	assertTrue(bad(function(c)
		c.rolls = { min = 3, max = 2 }
	end))
	assertTrue(bad(function(c)
		c.entries = {}
	end))
	assertTrue(bad(function(c)
		c.entries = { { kind = "treasure", weight = 1 } }
	end))
	assertTrue(bad(function(c)
		c.entries = { { kind = "gear", weight = 0 } }
	end))
	assertTrue(bad(function(c)
		c.gearBonusChance = 101
	end))
	assertTrue(bad(function(c)
		c.coinBase = 0
	end))
end)

test("chances are percentages that add up to 100", function()
	local chances = ChestLoot.chances(config)
	local sum = 0
	for _, entry in chances do
		sum += entry.percent
	end
	assertNear(sum, 100, 1e-9)
	assertEquals(#chances, #config.entries)
end)

-- Rolling ------------------------------------------------------------------------------------

test("the rng path of a roll is as documented", function()
	-- count 0.0 -> 2; first kind 0.0 -> gear, slot 0.0 -> weapon, bonus 0.99 -> none;
	-- second kind 0.99 -> find (the last entry).
	local entries = roll(2, scriptedRng({ 0.0, 0.0, 0.0, 0.99, 0.99 }))
	assertEquals(#entries, 2)
	assertEquals(entries[1].kind, "gear")
	assertEquals(entries[1].slot, EquipmentConfig.slots[1])
	assertEquals(entries[1].tier, 2)
	assertEquals(entries[2].kind, "find")
end)

test("the gear tier follows the biome, with a chance of one more, capped at the best tier", function()
	local withBonus = roll(2, scriptedRng({ 0.0, 0.0, 0.0, 0.0, 0.99 }))
	assertEquals(withBonus[1].tier, 3)
	local capped = roll(#EquipmentConfig.tiers, scriptedRng({ 0.0, 0.0, 0.0, 0.0, 0.99 }))
	assertEquals(capped[1].tier, #EquipmentConfig.tiers)
	local lowest = roll(1, scriptedRng({ 0.0, 0.0, 0.0, 0.99, 0.99 }))
	assertEquals(lowest[1].tier, 1)
end)

test("coins scale with the biome", function()
	local function coinsIn(biomeIndex: number): number
		-- Coins have weight 20 of 100 after gear 25, potion 25, herb 20: draw 0.7 selects coins.
		local entries = roll(biomeIndex, scriptedRng({ 0.0, 0.7, 0.7 }))
		assertEquals(entries[1].kind, "coins")
		return entries[1].amount :: number
	end
	assertEquals(coinsIn(1), config.coinBase)
	assertEquals(coinsIn(2), config.coinBase * config.coinGrowth)
	assertEquals(coinsIn(3), config.coinBase * config.coinGrowth ^ 2)
end)

test("herbs come from the biome's list and potions from the potion list", function()
	local herb = roll(1, scriptedRng({ 0.0, 0.55, 0.0, 0.0, 0.7 }))[1]
	assertEquals(herb.kind, "herb")
	assertEquals(herb.id, "moss_fern")
	assertEquals(herb.count, config.herbCount.min)
	local potion = roll(1, scriptedRng({ 0.0, 0.3, 0.999, 0.999, 0.7 }))[1]
	assertEquals(potion.kind, "potion")
	assertEquals(potion.id, PotionsConfig.order[#PotionsConfig.order])
	assertEquals(potion.count, config.potionCount.max)
end)

test("rolls give the configured number of items and only known kinds", function()
	local rng = Framework.seededRng(11)
	local kinds: { [string]: boolean } = { gear = true, potion = true, herb = true, coins = true, find = true }
	for _ = 1, 300 do
		local entries = roll(2, rng)
		assertTrue(#entries >= config.rolls.min and #entries <= config.rolls.max)
		for _, entry in entries do
			assertTrue(kinds[entry.kind] == true)
		end
	end
end)

test("over many chests the kinds match the shown chances", function()
	local rng = Framework.seededRng(21)
	local counts: { [string]: number } = {}
	local total = 0
	for _ = 1, 20000 do
		for _, entry in roll(2, rng) do
			counts[entry.kind] = (counts[entry.kind] or 0) + 1
			total += 1
		end
	end
	for _, chance in ChestLoot.chances(config) do
		assertNear((counts[chance.kind] or 0) / total * 100, chance.percent, 1.0, chance.kind)
	end
end)

-- Applying ---------------------------------------------------------------------------------------------

local function target(): ChestLoot.Target
	return {
		coins = 0,
		nextFindId = 1,
		depot = { ores = {}, finds = {} },
		stash = { ores = {} },
		gear = Equipment.new(),
		potions = Potions.new(),
	}
end

local function findBlock(): ChestLoot.FindBlock
	return { layerId = "rock", findId = "fossil", rarityId = "epic", mutationId = "golden", value = 2500 }
end

test("applying adds coins, gear, potions, herbs and finds where they belong", function()
	local t = target()
	local summary = ChestLoot.apply(t, {
		{ kind = "coins", amount = 150 },
		{ kind = "gear", slot = "boots", tier = 2 },
		{ kind = "potion", id = "heal", count = 2 },
		{ kind = "herb", id = "moss_fern", count = 4 },
		{ kind = "find" },
	}, deps, findBlock)
	assertEquals(t.coins, 150)
	assertEquals(#t.gear.owned, 1)
	assertEquals(t.gear.owned[1].source, "chest")
	assertEquals(t.gear.owned[1].tier, 2)
	assertEquals(t.potions.owned.heal, 2)
	assertEquals(t.stash.ores.moss_fern, 4)
	assertEquals(#t.depot.finds, 1)
	assertEquals(t.depot.finds[1].id, 1)
	assertEquals(t.depot.finds[1].mutationId, "golden")
	assertEquals(t.nextFindId, 2)
	assertEquals(summary.coins, 150)
	assertEquals(#summary.gear, 1)
	assertEquals(#summary.finds, 1)
	assertEquals(summary.converted, 0)
end)

test("gear over the limit is paid out as coins instead of being lost", function()
	local t = target()
	for _ = 1, EquipmentConfig.maxOwned do
		Equipment.grant(t.gear, EquipmentConfig, "boots", 1, "crafted")
	end
	local summary = ChestLoot.apply(t, { { kind = "gear", slot = "weapon", tier = 2 } }, deps, findBlock)
	local expected = (Equipment.cost(EquipmentConfig, "weapon", 2) :: Equipment.Cost).coins
	assertEquals(t.coins, expected)
	assertEquals(summary.converted, expected)
	assertEquals(#t.gear.owned, EquipmentConfig.maxOwned)
end)

test("potions over the limit are paid out as coins", function()
	local t = target()
	t.potions.owned.luck = PotionsConfig.maxOwnedPerPotion
	local summary = ChestLoot.apply(t, { { kind = "potion", id = "luck", count = 2 } }, deps, findBlock)
	assertEquals(t.potions.owned.luck, PotionsConfig.maxOwnedPerPotion)
	assertEquals(t.coins, PotionsConfig.potions.luck.coins * 2)
	assertEquals(summary.converted, PotionsConfig.potions.luck.coins * 2)
end)

test("a partly fitting potion stack is topped up and the rest paid out", function()
	local t = target()
	t.potions.owned.heal = PotionsConfig.maxOwnedPerPotion - 1
	ChestLoot.apply(t, { { kind = "potion", id = "heal", count = 2 } }, deps, findBlock)
	assertEquals(t.potions.owned.heal, PotionsConfig.maxOwnedPerPotion)
	assertEquals(t.coins, PotionsConfig.potions.heal.coins)
end)

test("two finds in one chest get different ids", function()
	local t = target()
	ChestLoot.apply(t, { { kind = "find" }, { kind = "find" } }, deps, findBlock)
	assertEquals(#t.depot.finds, 2)
	assertTrue(t.depot.finds[1].id ~= t.depot.finds[2].id)
	assertEquals(t.nextFindId, 3)
end)

test("applying an unknown or malformed entry is ignored without changes", function()
	local t = target()
	ChestLoot.apply(t, {
		{ kind = "treasure" },
		{ kind = "gear", slot = "cape", tier = 1 },
		{ kind = "potion", id = "ghost", count = 1 },
		{ kind = "coins", amount = -5 },
	}, deps, findBlock)
	assertEquals(t.coins, 0)
	assertEquals(#t.gear.owned, 0)
	assertEquals(next(t.potions.owned), nil)
end)
