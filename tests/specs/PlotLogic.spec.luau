--!strict
local Framework = require("../Framework")
local PlotConfig = require("../../src/shared/Config/Plot")
local PlotLogic = require("../../src/server/PlotLogic")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals
local assertNear = Framework.assertNear

local config: PlotLogic.Config = PlotConfig

local function with(changes: { [string]: any }): PlotLogic.Config
	local copy: { [string]: any } = table.clone(config :: any)
	for key, value in changes do
		copy[key] = value
	end
	return copy :: any
end

-- Config -----------------------------------------------------------------------

test("the shipped plot config is valid", function()
	local ok, reason = PlotLogic.validateConfig(config)
	assertTrue(ok, reason)
	assertEquals(config.count, 8)
end)

test("validateConfig rejects broken values", function()
	assertTrue(not PlotLogic.validateConfig(with({ count = 0 })))
	assertTrue(not PlotLogic.validateConfig(with({ count = 2.5 })))
	assertTrue(not PlotLogic.validateConfig(with({ columns = 0 })))
	assertTrue(not PlotLogic.validateConfig(with({ columns = 9 })))
	assertTrue(not PlotLogic.validateConfig(with({ size = 0 })))
	assertTrue(not PlotLogic.validateConfig(with({ gap = -1 })))
	assertTrue(not PlotLogic.validateConfig(with({ shaftSize = config.size })), "shaft must be smaller than the plot")
	assertTrue(not PlotLogic.validateConfig(with({ shaftDepth = 0 })))
	assertTrue(not PlotLogic.validateConfig(with({ bottomThickness = 0 })))
	assertTrue(not PlotLogic.validateConfig(with({ spawnSize = config.size })), "spawn must fit beside the shaft")
	assertTrue(not PlotLogic.validateConfig(with({ spawnHeight = 0 })))
	assertTrue(not PlotLogic.validateConfig(with({ sellSize = 0 })))
	assertTrue(not PlotLogic.validateConfig(with({ sellSize = config.size })), "sell point must fit beside the shaft")
	assertTrue(not PlotLogic.validateConfig(with({ sellHeight = 0 })))
end)

-- Layout -----------------------------------------------------------------------

test("layout gives one slot per plot with indexes 1..count", function()
	local slots = PlotLogic.layout(config)
	assertEquals(#slots, config.count)
	for index, slot in slots do
		assertEquals(slot.index, index)
	end
end)

test("layout places plots in a grid starting at the origin", function()
	local slots = PlotLogic.layout(config)
	local pitch = config.size + config.gap
	assertEquals(slots[1].x, 0)
	assertEquals(slots[1].z, 0)
	assertEquals(slots[2].x, pitch)
	assertEquals(slots[2].z, 0)
	assertEquals(slots[config.columns + 1].x, 0)
	assertEquals(slots[config.columns + 1].z, pitch)
end)

test("no two plots overlap and the gap is kept", function()
	local slots = PlotLogic.layout(config)
	for i = 1, #slots do
		for j = i + 1, #slots do
			local dx = math.abs(slots[i].x - slots[j].x)
			local dz = math.abs(slots[i].z - slots[j].z)
			assertTrue(
				dx >= config.size + config.gap or dz >= config.size + config.gap,
				string.format("plots %d and %d are too close", i, j)
			)
		end
	end
end)

-- Geometry ---------------------------------------------------------------------

test("the ground covers the plot except the shaft", function()
	local area = 0
	for _, box in PlotLogic.groundBoxes(config) do
		if box.y > -config.shaftDepth - 0.001 and box.y < 0 then
			area += box.sizeX * box.sizeZ
		end
	end
	assertNear(area, config.size * config.size - config.shaftSize * config.shaftSize, 0.001)
end)

test("ground boxes are centered at their own half height below the surface", function()
	for _, box in PlotLogic.groundBoxes(config) do
		if box.name ~= "ShaftBottom" then
			assertNear(box.y, -config.shaftDepth / 2, 0.001)
			assertNear(box.sizeY, config.shaftDepth, 0.001)
		end
	end
end)

test("no ground box reaches into the shaft", function()
	local half = config.shaftSize / 2
	for _, box in PlotLogic.groundBoxes(config) do
		if box.name ~= "ShaftBottom" then
			local overlapsX = box.x - box.sizeX / 2 < half and box.x + box.sizeX / 2 > -half
			local overlapsZ = box.z - box.sizeZ / 2 < half and box.z + box.sizeZ / 2 > -half
			assertTrue(not (overlapsX and overlapsZ), box.name .. " overlaps the shaft")
		end
	end
end)

test("the shaft has a bottom below the shaft depth", function()
	local bottom
	for _, box in PlotLogic.groundBoxes(config) do
		if box.name == "ShaftBottom" then
			bottom = box
		end
	end
	assertTrue(bottom ~= nil, "bottom missing")
	assertNear(bottom.y + bottom.sizeY / 2, -config.shaftDepth, 0.001)
end)

test("the spawn sits on the surface beside the shaft", function()
	local spawn = PlotLogic.spawnBox(config)
	assertNear(spawn.y - spawn.sizeY / 2, 0, 0.001, "spawn must rest on the surface")
	assertTrue(math.abs(spawn.z) - spawn.sizeZ / 2 >= config.shaftSize / 2, "spawn must not hang over the shaft")
	assertTrue(math.abs(spawn.z) + spawn.sizeZ / 2 <= config.size / 2, "spawn must stay on the plot")
end)

test("the sell point rests on the surface north of the shaft", function()
	local sell = PlotLogic.sellBox(config)
	assertNear(sell.y - sell.sizeY / 2, 0, 0.001, "sell point must rest on the surface")
	assertTrue(sell.z < 0, "sell point lies opposite the spawn")
	assertTrue(math.abs(sell.z) - sell.sizeZ / 2 >= config.shaftSize / 2, "sell point must not hang over the shaft")
	assertTrue(math.abs(sell.z) + sell.sizeZ / 2 <= config.size / 2, "sell point must stay on the plot")
end)

test("the sell point does not overlap the spawn", function()
	local sell = PlotLogic.sellBox(config)
	local spawn = PlotLogic.spawnBox(config)
	local gap = math.abs(sell.z - spawn.z) - (sell.sizeZ + spawn.sizeZ) / 2
	assertTrue(gap >= 0, "sell point and spawn must not overlap")
end)

-- Allocation -------------------------------------------------------------------

test("claim hands out the lowest free plot and remembers the owner", function()
	local plots = PlotLogic.newAllocator(3)
	assertEquals(plots.claim(100), 1)
	assertEquals(plots.claim(200), 2)
	assertEquals(plots.slotOf(100), 1)
	assertEquals(plots.slotOf(200), 2)
	assertEquals(plots.freeCount(), 1)
end)

test("claiming twice for the same owner returns the same plot", function()
	local plots = PlotLogic.newAllocator(3)
	assertEquals(plots.claim(100), 1)
	assertEquals(plots.claim(100), 1)
	assertEquals(plots.freeCount(), 2)
end)

test("claim returns nil when every plot is taken", function()
	local plots = PlotLogic.newAllocator(2)
	plots.claim(1)
	plots.claim(2)
	assertEquals(plots.claim(3), nil)
	assertEquals(plots.slotOf(3), nil)
	assertEquals(plots.freeCount(), 0)
end)

test("release frees the plot for the next owner", function()
	local plots = PlotLogic.newAllocator(2)
	plots.claim(1)
	plots.claim(2)
	assertEquals(plots.release(1), 1)
	assertEquals(plots.slotOf(1), nil)
	assertEquals(plots.claim(3), 1)
end)

test("release of an unknown owner does nothing", function()
	local plots = PlotLogic.newAllocator(2)
	assertEquals(plots.release(99), nil)
	assertEquals(plots.freeCount(), 2)
end)

-- Museum layout ------------------------------------------------------------------

local MAX_SHOWCASES = 60

local function overlapsXZ(a: PlotLogic.Box, b: PlotLogic.Box): boolean
	return math.abs(a.x - b.x) < (a.sizeX + b.sizeX) / 2 and math.abs(a.z - b.z) < (a.sizeZ + b.sizeZ) / 2
end

test("validateConfig rejects a broken museum layout", function()
	local museum = config.museum
	assertTrue(not PlotLogic.validateConfig(with({
		museum = {
			x = museum.x,
			z = museum.z,
			columns = 0,
			spacing = museum.spacing,
			vitrineSize = museum.vitrineSize,
			vitrineHeight = museum.vitrineHeight,
			signX = museum.signX,
			signZ = museum.signZ,
			signSize = museum.signSize,
		},
	})))
	assertTrue(not PlotLogic.validateConfig(with({
		museum = {
			x = museum.x,
			z = museum.z,
			columns = museum.columns,
			spacing = 1,
			vitrineSize = 2,
			vitrineHeight = museum.vitrineHeight,
			signX = museum.signX,
			signZ = museum.signZ,
			signSize = museum.signSize,
		},
	})), "showcases must not overlap")
end)

test("showcases are placed in a grid, first column first", function()
	local first = PlotLogic.vitrineBox(config, 1)
	local second = PlotLogic.vitrineBox(config, 2)
	local nextRow = PlotLogic.vitrineBox(config, config.museum.columns + 1)
	assertNear(first.x, config.museum.x, 0.001)
	assertNear(first.z, config.museum.z, 0.001)
	assertNear(second.x - first.x, config.museum.spacing, 0.001)
	assertNear(nextRow.z - first.z, config.museum.spacing, 0.001)
	assertNear(nextRow.x, first.x, 0.001)
	assertNear(first.y - first.sizeY / 2, 0, 0.001, "showcases rest on the surface")
end)

test("all showcases of the highest house level fit on the plot without overlaps", function()
	local boxes: { PlotLogic.Box } =
		{ PlotLogic.spawnBox(config), PlotLogic.sellBox(config), PlotLogic.museumSignBox(config) }
	table.insert(
		boxes,
		{ name = "Shaft", sizeX = config.shaftSize, sizeY = 1, sizeZ = config.shaftSize, x = 0, y = 0, z = 0 }
	)
	for slot = 1, MAX_SHOWCASES do
		local box = PlotLogic.vitrineBox(config, slot)
		assertTrue(math.abs(box.x) + box.sizeX / 2 <= config.size / 2, "showcase " .. slot .. " leaves the plot (x)")
		assertTrue(math.abs(box.z) + box.sizeZ / 2 <= config.size / 2, "showcase " .. slot .. " leaves the plot (z)")
		for _, other in boxes do
			assertTrue(not overlapsXZ(box, other), string.format("showcase %d overlaps %s", slot, other.name))
		end
		table.insert(boxes, box)
	end
end)

test("the museum sign stands on the plot surface", function()
	local sign = PlotLogic.museumSignBox(config)
	assertNear(sign.y - sign.sizeY / 2, 0, 0.001)
	assertTrue(math.abs(sign.x) + sign.sizeX / 2 <= config.size / 2)
	assertTrue(math.abs(sign.z) + sign.sizeZ / 2 <= config.size / 2)
end)

test("the owner of a plot can be looked up and ends with the release", function()
	local allocator = PlotLogic.newAllocator(2)
	local slot = allocator.claim(500) :: number
	assertEquals(allocator.ownerOf(slot), 500)
	assertEquals(allocator.ownerOf(slot + 1), nil)
	allocator.release(500)
	assertEquals(allocator.ownerOf(slot), nil)
end)

test("the museum floor is centered under the showcases of the house level", function()
	local museum = config.museum
	local x, z, rows = PlotLogic.museumFloor(config, 12)
	assertEquals(rows, math.ceil(12 / museum.columns))
	assertEquals(x, museum.x + (museum.columns - 1) * museum.spacing / 2)
	assertEquals(z, museum.z + (rows - 1) * museum.spacing / 2)
	local _, _, oneRow = PlotLogic.museumFloor(config, 1)
	assertEquals(oneRow, 1)
	local _, _, none = PlotLogic.museumFloor(config, 0)
	assertEquals(none, 1, "at least one row")
end)
