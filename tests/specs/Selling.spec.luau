--!strict
local Backpack = require("../../src/shared/Backpack")
local DigRoll = require("../../src/shared/DigRoll")
local Framework = require("../Framework")
local Layers = require("../../src/shared/Config/Layers")
local Ores = require("../../src/shared/Config/Ores")
local Selling = require("../../src/shared/Selling")
local TestConfig = require("../TestConfig")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals

local prices: Selling.OreValues = { coal = 1, copper = 2, gold = 16 }

local function filled(): Backpack.Backpack
	local backpack = Backpack.new(100)
	for _ = 1, 10 do
		Backpack.addBlock(backpack, { kind = "ore", layerId = "sand_clay", oreId = "coal" })
	end
	for _ = 1, 5 do
		Backpack.addBlock(backpack, { kind = "ore", layerId = "sand_clay", oreId = "copper" })
	end
	return backpack
end

local function addFind(backpack: Backpack.Backpack, value: number)
	Backpack.addBlock(backpack, {
		kind = "rare",
		layerId = "sand_clay",
		findId = "shard",
		rarityId = "common",
		value = value,
	})
end

test("selling ore pays count times price and empties the backpack", function()
	local backpack = filled()
	local result = Selling.sellAll(backpack, prices)
	assertEquals(result.oreCoins, 10 * 1 + 5 * 2)
	assertEquals(result.findCoins, 0)
	assertEquals(result.coins, 20)
	assertEquals(result.oreCount, 15)
	assertEquals(result.findCount, 0)
	assertEquals(Backpack.getUsed(backpack), 0)
end)

test("rare finds are sold at their value", function()
	local backpack = Backpack.new(10)
	addFind(backpack, 10)
	addFind(backpack, 2500)
	local result = Selling.sellAll(backpack, prices)
	assertEquals(result.findCoins, 2510)
	assertEquals(result.coins, 2510)
	assertEquals(result.findCount, 2)
	assertEquals(Backpack.getUsed(backpack), 0)
end)

test("the ore multiplier applies to ore only, never to finds", function()
	local backpack = filled()
	addFind(backpack, 50)
	local result = Selling.sellAll(backpack, prices, 2)
	assertEquals(result.oreCoins, 40)
	assertEquals(result.findCoins, 50)
	assertEquals(result.coins, 90)
end)

test("a fractional multiplier rounds the ore total down", function()
	local backpack = filled() -- 20 base coins
	local result = Selling.sellAll(backpack, prices, 1.15) -- 23.0 -> 23
	assertEquals(result.oreCoins, 23)
	local other = Backpack.new(10)
	Backpack.addBlock(other, { kind = "ore", layerId = "sand_clay", oreId = "coal" })
	assertEquals(Selling.sellAll(other, prices, 1.9).oreCoins, 1)
end)

test("invalid multipliers fall back to 1", function()
	for _, multiplier in { 0, -3, 0 / 0 } do
		local result = Selling.sellAll(filled(), prices, multiplier)
		assertEquals(result.oreCoins, 20)
	end
	assertEquals(Selling.sellAll(filled(), prices, nil).oreCoins, 20)
end)

test("unknown ore stays in the backpack and is reported, not paid", function()
	local backpack = filled()
	Backpack.addBlock(backpack, { kind = "ore", layerId = "sand_clay", oreId = "mystery" })
	Backpack.addBlock(backpack, { kind = "ore", layerId = "sand_clay", oreId = "mystery" })
	local result = Selling.sellAll(backpack, prices)
	assertEquals(result.oreCoins, 20)
	assertEquals(result.unknownOres.mystery, 2)
	assertEquals(backpack.ores.mystery, 2)
	assertEquals(Backpack.getUsed(backpack), 2)
	assertEquals(result.oreCount, 15)
end)

test("selling an empty backpack pays nothing", function()
	local result = Selling.sellAll(Backpack.new(5), prices)
	assertEquals(result.coins, 0)
	assertEquals(result.oreCount, 0)
	assertEquals(result.findCount, 0)
end)

test("selling twice does not pay twice", function()
	local backpack = filled()
	assertEquals(Selling.sellAll(backpack, prices).coins, 20)
	assertEquals(Selling.sellAll(backpack, prices).coins, 0)
end)

test("shipped ore prices cover every ore of every layer", function()
	local ok, reason = Selling.validateOreValues(Layers, Ores)
	assertTrue(ok, reason)
end)

test("every herb of every layer has a price too", function()
	for _, layer in Layers do
		for _, herbId in layer.herbs do
			assertTrue(Ores[herbId] ~= nil, "no price for herb " .. herbId)
		end
	end
	local withoutHerbs = table.clone(Ores)
	withoutHerbs.moss_fern = nil
	assertEquals((Selling.validateOreValues(Layers, withoutHerbs)), false)
end)

test("herbs sell like ore", function()
	local backpack = Backpack.new(10)
	backpack.ores.moss_fern = 3
	local result = Selling.sellAll(backpack, Ores)
	assertEquals(result.coins, 3 * Ores.moss_fern)
	assertEquals(next(result.unknownOres), nil)
end)

test("validateOreValues rejects missing and invalid prices", function()
	assertEquals((Selling.validateOreValues(Layers, { coal = 1 })), false)

	local negative = table.clone(Ores)
	negative.coal = -1
	assertEquals((Selling.validateOreValues(Layers, negative)), false)

	local fractional = table.clone(Ores)
	fractional.coal = 1.5
	assertEquals((Selling.validateOreValues(Layers, fractional)), false)
end)

test("deeper layers pay more per ore than shallower ones", function()
	local function cheapestAndBest(layer: DigRoll.LayerDef): (number, number)
		local cheapest = math.huge
		local best = 0
		for _, oreId in layer.ores do
			cheapest = math.min(cheapest, Ores[oreId])
			best = math.max(best, Ores[oreId])
		end
		return cheapest, best
	end
	for index = 2, #Layers do
		local _, previousBest = cheapestAndBest(Layers[index - 1])
		local cheapest = cheapestAndBest(Layers[index])
		assertTrue(cheapest > previousBest, Layers[index].id .. " should pay more than " .. Layers[index - 1].id)
	end
end)

test("dig, store and sell: coins equal the sum of what was dug", function()
	local rng = Framework.seededRng(2026)
	local backpack = Backpack.new(200)
	local expected = 0
	while not Backpack.isFull(backpack) do
		local block = DigRoll.rollBlock(TestConfig, rng, { depth = 120 })
		assertTrue(Backpack.addBlock(backpack, block))
		if block.kind == "ore" then
			expected += Ores[block.oreId :: string]
		else
			expected += block.value :: number
		end
	end
	local result = Selling.sellAll(backpack, Ores)
	assertEquals(result.coins, expected)
	assertEquals(result.oreCount + result.findCount, 200)
	assertEquals(Backpack.getUsed(backpack), 0)
end)
