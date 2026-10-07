--!strict
local Backpack = require("../../src/shared/Backpack")
local DigRoll = require("../../src/shared/DigRoll")
local Framework = require("../Framework")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals
local assertErrors = Framework.assertErrors

local function ore(oreId: string): DigRoll.BlockResult
	return { kind = "ore", layerId = "sand_clay", oreId = oreId }
end

local function rare(value: number): DigRoll.BlockResult
	return {
		kind = "rare",
		layerId = "sand_clay",
		findId = "shard",
		rarityId = "common",
		mutationId = nil,
		value = value,
	}
end

local levels: { Backpack.LevelDef } = {
	{ capacity = 50 },
	{ capacity = 100 },
	{ capacity = 200 },
}

test("a new backpack is empty and not full", function()
	local backpack = Backpack.new(5)
	assertEquals(backpack.capacity, 5)
	assertEquals(Backpack.getUsed(backpack), 0)
	assertEquals(Backpack.getFree(backpack), 5)
	assertEquals(Backpack.isFull(backpack), false)
end)

test("new rejects invalid capacities", function()
	for _, capacity in { 0, -1, 2.5, 0 / 0, math.huge } do
		assertErrors(function()
			Backpack.new(capacity)
		end, "capacity")
	end
end)

test("adding ore counts per ore id and uses slots", function()
	local backpack = Backpack.new(10)
	assertTrue(Backpack.addBlock(backpack, ore("coal")))
	assertTrue(Backpack.addBlock(backpack, ore("coal")))
	assertTrue(Backpack.addBlock(backpack, ore("copper")))
	assertEquals(backpack.ores.coal, 2)
	assertEquals(backpack.ores.copper, 1)
	assertEquals(Backpack.getUsed(backpack), 3)
	assertEquals(Backpack.getFree(backpack), 7)
end)

test("adding a rare find stores its details and uses a slot", function()
	local backpack = Backpack.new(10)
	local added = Backpack.addBlock(backpack, {
		kind = "rare",
		layerId = "rock",
		findId = "fossil",
		rarityId = "epic",
		mutationId = "golden",
		value = 2500,
	})
	assertTrue(added)
	assertEquals(#backpack.finds, 1)
	local find = backpack.finds[1]
	assertEquals(find.findId, "fossil")
	assertEquals(find.rarityId, "epic")
	assertEquals(find.mutationId, "golden")
	assertEquals(find.value, 2500)
	assertEquals(Backpack.getUsed(backpack), 1)
end)

test("a full backpack rejects blocks and stays unchanged", function()
	local backpack = Backpack.new(2)
	assertTrue(Backpack.addBlock(backpack, ore("coal")))
	assertTrue(Backpack.addBlock(backpack, rare(10)))
	assertEquals(Backpack.isFull(backpack), true)

	assertEquals(Backpack.addBlock(backpack, ore("coal")), false)
	assertEquals(Backpack.addBlock(backpack, rare(10)), false)
	assertEquals(backpack.ores.coal, 1)
	assertEquals(#backpack.finds, 1)
	assertEquals(Backpack.getUsed(backpack), 2)
	assertEquals(Backpack.getFree(backpack), 0)
end)

test("clear empties the backpack but keeps the capacity", function()
	local backpack = Backpack.new(3)
	Backpack.addBlock(backpack, ore("coal"))
	Backpack.addBlock(backpack, rare(10))
	Backpack.clear(backpack)
	assertEquals(Backpack.getUsed(backpack), 0)
	assertEquals(backpack.capacity, 3)
	assertEquals(next(backpack.ores), nil)
	assertEquals(#backpack.finds, 0)
end)

test("malformed block results raise errors", function()
	local backpack = Backpack.new(3)
	assertErrors(function()
		Backpack.addBlock(backpack, { kind = "ore", layerId = "sand_clay" })
	end, "oreId")
	assertErrors(function()
		Backpack.addBlock(backpack, { kind = "rare", layerId = "sand_clay", findId = "shard" })
	end, "rare")
	assertEquals(Backpack.getUsed(backpack), 0)
end)

test("capacityForLevel returns the configured capacity", function()
	assertEquals(Backpack.capacityForLevel(levels, 1), 50)
	assertEquals(Backpack.capacityForLevel(levels, 2), 100)
	assertEquals(Backpack.capacityForLevel(levels, 3), 200)
end)

test("capacityForLevel clamps levels outside the range", function()
	assertEquals(Backpack.capacityForLevel(levels, 0), 50)
	assertEquals(Backpack.capacityForLevel(levels, 99), 200)
	assertEquals(Backpack.capacityForLevel(levels, 0 / 0), 50)
end)

test("capacityForLevel applies a capacity multiplier and rounds down", function()
	assertEquals(Backpack.capacityForLevel(levels, 1, 1.2), 60)
	assertEquals(Backpack.capacityForLevel(levels, 1, 1.01), 50)
	assertEquals(Backpack.capacityForLevel(levels, 1, 0.5), 50)
	assertEquals(Backpack.capacityForLevel(levels, 1, 0 / 0), 50)
end)

test("shipped backpack levels are valid and increasing", function()
	local shipped = require("../../src/shared/Config/Backpack")
	local ok, reason = Backpack.validateLevels(shipped.levels)
	assertTrue(ok, reason)
	assertEquals(Backpack.capacityForLevel(shipped.levels, 1), shipped.startCapacity)
end)

test("validateLevels rejects empty, non-increasing and invalid capacities", function()
	assertEquals((Backpack.validateLevels({})), false)
	assertEquals((Backpack.validateLevels({ { capacity = 50 }, { capacity = 50 } })), false)
	assertEquals((Backpack.validateLevels({ { capacity = 50 }, { capacity = 40 } })), false)
	assertEquals((Backpack.validateLevels({ { capacity = 0 } })), false)
	assertEquals((Backpack.validateLevels({ { capacity = 10.5 } })), false)
end)
