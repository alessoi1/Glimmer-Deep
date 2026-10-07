--!strict
local Framework = require("../Framework")
local Shovel = require("../../src/shared/Shovel")
local ShovelConfig = require("../../src/shared/Config/Shovel")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals
local assertNear = Framework.assertNear

local levels = ShovelConfig.levels
local tolerance = ShovelConfig.cooldownTolerance

test("shipped shovel config is valid", function()
	local ok, reason = Shovel.validateConfig(ShovelConfig)
	assertTrue(ok, reason)
end)

test("the shovel has 10 levels with the prices from the concept", function()
	assertEquals(#levels, 10)
	assertEquals(levels[1].price, 0)
	assertEquals(levels[2].price, 100)
	assertEquals(levels[10].price, 1000000)
end)

test("each level costs 2 to 3.5 times the previous one", function()
	for index = 3, #levels do
		local ratio = levels[index].price / levels[index - 1].price
		assertTrue(ratio >= 2 and ratio <= 3.5, string.format("level %d ratio %.2f", index, ratio))
	end
end)

test("getLevel returns the level definition and clamps out-of-range input", function()
	assertEquals(Shovel.getLevel(levels, 1).id, levels[1].id)
	assertEquals(Shovel.getLevel(levels, 10).id, levels[10].id)
	assertEquals(Shovel.getLevel(levels, 0).id, levels[1].id)
	assertEquals(Shovel.getLevel(levels, 99).id, levels[10].id)
	assertEquals(Shovel.getLevel(levels, 0 / 0).id, levels[1].id)
end)

test("higher levels dig faster", function()
	for index = 2, #levels do
		assertTrue(Shovel.getDigCooldown(levels, index) < Shovel.getDigCooldown(levels, index - 1))
	end
end)

test("a speed multiplier divides the cooldown, invalid ones are ignored", function()
	local base = Shovel.getDigCooldown(levels, 1)
	assertNear(Shovel.getDigCooldown(levels, 1, 2), base / 2, 1e-9)
	for _, multiplier in { 0, -2, 0 / 0 } do
		assertNear(Shovel.getDigCooldown(levels, 1, multiplier), base, 1e-9)
	end
	assertNear(Shovel.getDigCooldown(levels, 1, nil), base, 1e-9)
end)

test("a starting backpack takes about 30 seconds to fill", function()
	local backpackCapacity = 50
	local seconds = backpackCapacity * Shovel.getDigCooldown(levels, 1)
	assertNear(seconds, 30, 3)
end)

test("isReady allows the first dig and respects the cooldown", function()
	local cooldown = 1
	assertEquals(Shovel.isReady(nil, 100, cooldown, tolerance), true)
	assertEquals(Shovel.isReady(100, 101, cooldown, tolerance), true)
	assertEquals(Shovel.isReady(100, 100 + cooldown * tolerance, cooldown, tolerance), true)
	assertEquals(Shovel.isReady(100, 100.5, cooldown, tolerance), false)
	assertEquals(Shovel.isReady(100, 100, cooldown, tolerance), false)
end)

test("isReady rejects a clock that went backwards and invalid times", function()
	assertEquals(Shovel.isReady(100, 99, 1, tolerance), false)
	assertEquals(Shovel.isReady(100, 0 / 0, 1, tolerance), false)
end)

test("validateConfig rejects broken level tables", function()
	local function withLevels(modified: { Shovel.LevelDef }): Shovel.Config
		return { cooldownTolerance = tolerance, levels = modified }
	end
	assertEquals((Shovel.validateConfig(withLevels({}))), false)
	assertEquals((Shovel.validateConfig(withLevels({ { id = "a", price = 5, digCooldown = 1 } }))), false)
	assertEquals((Shovel.validateConfig(withLevels({
		{ id = "a", price = 0, digCooldown = 1 },
		{ id = "b", price = 0, digCooldown = 0.5 },
	}))), false)
	assertEquals((Shovel.validateConfig(withLevels({
		{ id = "a", price = 0, digCooldown = 1 },
		{ id = "b", price = 100, digCooldown = 1 },
	}))), false)
	assertEquals((Shovel.validateConfig(withLevels({
		{ id = "a", price = 0, digCooldown = 1 },
		{ id = "a", price = 100, digCooldown = 0.5 },
	}))), false)
	assertEquals(
		(Shovel.validateConfig({ cooldownTolerance = 1.5, levels = { { id = "a", price = 0, digCooldown = 1 } } })),
		false
	)
end)
