--!strict
local Framework = require("../Framework")
local Modifiers = require("../../src/shared/Modifiers")

local test = Framework.test
local assertEquals = Framework.assertEquals
local assertNear = Framework.assertNear

test("without any parts every modifier is neutral", function()
	local result = Modifiers.combine({})
	assertEquals(result.coinMultiplier, 1)
	assertEquals(result.oreSaleFactor, 1)
	assertEquals(result.luck, 1)
	assertEquals(result.rareFindMultiplier, 1)
	assertEquals(result.speedMultiplier, 1)
	assertEquals(result.capacityMultiplier, 1)
	assertEquals(result.offlineMultiplier, 1)
	assertEquals(result.rangeBonus, 0)
	assertEquals(result.offlineExtraHours, 0)
	assertEquals(result.walkSpeedMultiplier, 1)
end)

test("bonuses of several parts add up", function()
	local result = Modifiers.combine({
		{ coinBonus = 0.1, luckBonus = 0.05, tempoBonus = 0.2 },
		{ coinBonus = 0.1, capacityBonus = 0.2, offlineBonus = 0.5, rareFindBonus = 0.25, rangeBonus = 4 },
		{ rangeBonus = 2, offlineHoursBonus = 3 },
		{ offlineHoursBonus = 1, walkSpeedBonus = 0.1 },
		{ walkSpeedBonus = 0.2 },
	})
	assertNear(result.coinMultiplier, 1.2, 1e-9)
	assertNear(result.luck, 1.05, 1e-9)
	assertNear(result.speedMultiplier, 1.2, 1e-9)
	assertNear(result.capacityMultiplier, 1.2, 1e-9)
	assertNear(result.offlineMultiplier, 1.5, 1e-9)
	assertNear(result.rareFindMultiplier, 1.25, 1e-9)
	assertEquals(result.rangeBonus, 6)
	assertEquals(result.offlineExtraHours, 4)
	assertNear(result.walkSpeedMultiplier, 1.3, 1e-9)
end)

test("sale factors multiply instead of adding", function()
	local result = Modifiers.combine({ { oreSaleFactor = 2 }, { oreSaleFactor = 1.5 } })
	assertEquals(result.oreSaleFactor, 3)
	assertEquals(result.coinMultiplier, 1)
end)

test("negative, missing and invalid numbers are ignored", function()
	local result = Modifiers.combine({
		{ coinBonus = -0.5, luckBonus = 0 / 0, tempoBonus = math.huge, oreSaleFactor = 0 },
	})
	assertEquals(result.coinMultiplier, 1)
	assertEquals(result.luck, 1)
	assertEquals(result.speedMultiplier, 1)
	assertEquals(result.oreSaleFactor, 1)
end)

test("knownFields lists every field of a part", function()
	for _, field in Modifiers.knownFields do
		local part: any = { [field] = 1 }
		Modifiers.combine({ part })
	end
	assertEquals(#Modifiers.knownFields, 10)
end)
