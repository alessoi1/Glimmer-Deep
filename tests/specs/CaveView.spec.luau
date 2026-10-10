--!strict
local Cave = require("../../src/shared/Cave")
local CaveConfig = require("../../src/shared/Config/Cave")
local CaveView = require("../../src/shared/CaveView")
local Framework = require("../Framework")
local Layers = require("../../src/shared/Config/Layers")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals
local assertNear = Framework.assertNear

local caveConfig: Cave.Config = {
	height = CaveConfig.height,
	sliceRows = CaveConfig.sliceRows,
	metersPerRow = CaveConfig.metersPerRow,
	entranceRows = CaveConfig.entranceRows,
	corridorHalfWidth = CaveConfig.corridorHalfWidth,
	corridorHeight = CaveConfig.corridorHeight,
	startRadius = CaveConfig.startRadius,
	maxRadius = CaveConfig.maxRadius,
	radiusByLevel = CaveConfig.radiusByLevel,
	areaByLevel = CaveConfig.areaByLevel,
	resourceDensity = CaveConfig.resourceDensity,
	herbShare = CaveConfig.herbShare,
	findSpotShare = CaveConfig.findSpotShare,
	regrowSeconds = CaveConfig.regrowSeconds,
	chestChance = CaveConfig.chestChance,
	chestMinRow = CaveConfig.chestMinRow,
	chestRespawnSeconds = CaveConfig.chestRespawnSeconds,
	biomes = Layers,
}

local world = CaveConfig.world
local blockSize = CaveConfig.blockSize
local NOW = 1700000000
local SEED = 777

local function dot(a: CaveView.Vec, b: CaveView.Vec): number
	return a.x * b.x + a.y * b.y + a.z * b.z
end

test("shipped world config is valid", function()
	local ok, reason = CaveView.validateWorld(world, CaveConfig.blockSize, caveConfig)
	assertTrue(ok, reason)
end)

test("validateWorld rejects broken values", function()
	local function bad(change: (copy: any) -> ()): boolean
		local copy: any = table.clone(world)
		copy.origin = table.clone(world.origin)
		change(copy)
		local ok = CaveView.validateWorld(copy, blockSize, caveConfig)
		return not ok
	end
	assertTrue(bad(function(w)
		w.slopeDegrees = 0
	end))
	assertTrue(bad(function(w)
		w.slopeDegrees = 80
	end))
	assertTrue(bad(function(w)
		w.slotSpacing = 50
	end))
	assertTrue(bad(function(w)
		w.windowAhead = -1
	end))
	assertTrue(bad(function(w)
		w.reachStuds = 0
	end))
	assertTrue(bad(function(w)
		w.maxParts = 10
	end))
end)

test("the cave axes are unit length and at right angles, and the cave goes down", function()
	local axes = CaveView.axes(world)
	assertNear(dot(axes.forward, axes.forward), 1, 1e-9)
	assertNear(dot(axes.up, axes.up), 1, 1e-9)
	assertNear(dot(axes.right, axes.right), 1, 1e-9)
	assertNear(dot(axes.forward, axes.up), 0, 1e-9)
	assertNear(dot(axes.forward, axes.right), 0, 1e-9)
	assertTrue(axes.forward.y < 0, "forward must descend")
	assertTrue(axes.up.y > 0, "up must point up")
end)

test("neighboring cells are exactly one block apart", function()
	local a = CaveView.cellCenter(world, blockSize, 1, 10, 2, 1)
	local nextRow = CaveView.cellCenter(world, blockSize, 1, 11, 2, 1)
	local nextX = CaveView.cellCenter(world, blockSize, 1, 10, 3, 1)
	local nextY = CaveView.cellCenter(world, blockSize, 1, 10, 2, 2)
	assertNear(CaveView.distance(a, nextRow), blockSize, 1e-9)
	assertNear(CaveView.distance(a, nextX), blockSize, 1e-9)
	assertNear(CaveView.distance(a, nextY), blockSize, 1e-9)
end)

test("each deeper row is lower in the world", function()
	local top = CaveView.cellCenter(world, blockSize, 1, 0, 0, 0)
	local deep = CaveView.cellCenter(world, blockSize, 1, 100, 0, 0)
	assertTrue(deep.y < top.y)
end)

test("caves of different slots do not touch each other", function()
	local width = (caveConfig.maxRadius * 2 + 1) * blockSize
	local a = CaveView.cellCenter(world, blockSize, 1, 0, 0, 0)
	local b = CaveView.cellCenter(world, blockSize, 2, 0, 0, 0)
	assertTrue(math.abs(b.x - a.x) >= width + blockSize, "slot spacing must exceed the cave width")
end)

test("rowAt is the inverse of cellCenter", function()
	for _, row in { 0, 1, 17, 150, 299 } do
		for _, x in { -12, 0, 5 } do
			local center = CaveView.cellCenter(world, blockSize, 3, row, x, 2)
			assertEquals(CaveView.rowAt(world, blockSize, 3, center), row)
		end
	end
end)

test("windowRows clamps at the entrance and keeps the configured size", function()
	local from, to = CaveView.windowRows(world, 0)
	assertEquals(from, 0)
	assertEquals(to, world.windowAhead)
	local middleFrom, middleTo = CaveView.windowRows(world, 100)
	assertEquals(middleFrom, 100 - world.windowBehind)
	assertEquals(middleTo, 100 + world.windowAhead)
end)

-- Visible cells ------------------------------------------------------------------------

local function bruteForceVisible(state: Cave.State, fromRow: number, toRow: number): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for row = fromRow, toRow do
		for x = -caveConfig.maxRadius - 1, caveConfig.maxRadius + 1 do
			for y = -1, caveConfig.height do
				if
					not Cave.isOpen(state, caveConfig, row, x, y, NOW)
					and Cave.isExposed(state, caveConfig, row, x, y, NOW)
				then
					set[CaveView.key(row, x, y)] = true
				end
			end
		end
	end
	return set
end

test("visible cells are exactly the solid cells next to open space", function()
	local state = Cave.new(SEED)
	state.preDugRow = 30
	state.deepestRow = 30
	local visible = CaveView.visibleCells(state, caveConfig, 0, 40, NOW)
	local expected = bruteForceVisible(state, 0, 40)
	local seen: { [string]: boolean } = {}
	for _, cell in visible do
		local key = CaveView.key(cell.row, cell.x, cell.y)
		assertTrue(expected[key] == true, "unexpected cell " .. key)
		assertTrue(cell.kind ~= "air")
		assertTrue(not seen[key], "duplicate " .. key)
		seen[key] = true
	end
	for key in expected do
		assertTrue(seen[key] == true, "missing cell " .. key)
	end
end)

test("an untouched cave shows only the walls around the hall", function()
	local state = Cave.new(SEED)
	local visible = CaveView.visibleCells(state, caveConfig, 0, 60, NOW)
	assertTrue(#visible > 0)
	for _, cell in visible do
		assertTrue(cell.row <= caveConfig.entranceRows, "no cell beyond the hall's back wall: row " .. cell.row)
	end
end)

test("the hall has a bedrock floor and ceiling and the grid cells keep their kind", function()
	local state = Cave.new(SEED)
	local visible = CaveView.visibleCells(state, caveConfig, 0, 2, NOW)
	local floor, ceiling = 0, 0
	for _, cell in visible do
		if cell.y == -1 then
			floor += 1
			assertEquals(cell.kind, "bedrock")
		elseif cell.y == caveConfig.height then
			ceiling += 1
			assertEquals(cell.kind, "bedrock")
		end
	end
	-- Rows 0 to 2 are the hall: 13 columns of floor and of ceiling in each row.
	assertEquals(floor, 3 * (caveConfig.startRadius * 2 + 1))
	assertEquals(ceiling, 3 * (caveConfig.startRadius * 2 + 1))
end)

test("mining a cell reveals its neighbors and hides the mined cell", function()
	local state = Cave.new(SEED)
	local before = CaveView.visibleCells(state, caveConfig, 0, 20, NOW)
	assertTrue(Cave.mine(state, caveConfig, 10, caveConfig.entranceRows, 0, 0, NOW).ok)
	local after = CaveView.visibleCells(state, caveConfig, 0, 20, NOW)
	local keysAfter: { [string]: boolean } = {}
	for _, cell in after do
		keysAfter[CaveView.key(cell.row, cell.x, cell.y)] = true
	end
	assertTrue(not keysAfter[CaveView.key(caveConfig.entranceRows, 0, 0)], "the mined cell is gone")
	assertTrue(keysAfter[CaveView.key(caveConfig.entranceRows + 1, 0, 0)], "the cell behind it shows now")
	assertTrue(#after >= #before - 1)
end)

test("a chest shows as a chest cell", function()
	local state = Cave.new(SEED)
	local found = false
	for sliceIndex = 1, 400 do
		local position = Cave.chestPosition(caveConfig, state.seed, sliceIndex)
		if position ~= nil then
			-- Open one neighbor so it is exposed.
			local slice = state.slices[Cave.sliceOf(caveConfig, position.row)] or { mined = {} }
			state.slices[Cave.sliceOf(caveConfig, position.row)] = slice
			local nx, ny = position.x, position.y
			ny = if ny + 1 < caveConfig.height then ny + 1 else ny - 1
			slice.mined[Cave.localIndex(caveConfig, position.row, nx, ny)] = true
			local visible = CaveView.visibleCells(state, caveConfig, position.row, position.row, NOW)
			for _, cell in visible do
				if cell.row == position.row and cell.x == position.x and cell.y == position.y then
					assertEquals(cell.kind, "chest")
					found = true
				end
			end
			break
		end
	end
	assertTrue(found, "the chest must be among the visible cells")
end)

test("a window of a long corridor stays inside the part budget", function()
	local state = Cave.new(SEED)
	state.preDugRow = 300
	state.deepestRow = 300
	local from, to = CaveView.windowRows(world, 150)
	local visible = CaveView.visibleCells(state, caveConfig, from, to, NOW)
	assertTrue(#visible <= world.maxParts, "window needs " .. #visible .. " parts, budget " .. world.maxParts)
end)

-- Streaming difference -----------------------------------------------------------------------

test("diff reports cells to add and keys to remove", function()
	local state = Cave.new(SEED)
	local first = CaveView.visibleCells(state, caveConfig, 0, 20, NOW)
	local built: { [string]: boolean } = {}
	local initial = CaveView.diff(built, first)
	assertEquals(#initial.add, #first)
	assertEquals(#initial.remove, 0)
	for _, cell in initial.add do
		built[CaveView.key(cell.row, cell.x, cell.y)] = true
	end

	-- Nothing changed: nothing to do.
	local same = CaveView.diff(built, first)
	assertEquals(#same.add, 0)
	assertEquals(#same.remove, 0)

	-- Mine a cell: the mined cell goes, the one behind it comes.
	Cave.mine(state, caveConfig, 10, caveConfig.entranceRows, 0, 0, NOW)
	local second = CaveView.visibleCells(state, caveConfig, 0, 20, NOW)
	local change = CaveView.diff(built, second)
	assertTrue(#change.add >= 1)
	assertEquals(#change.remove, 1)
	assertEquals(change.remove[1], CaveView.key(caveConfig.entranceRows, 0, 0))
end)

test("diff removes cells that left the window", function()
	local state = Cave.new(SEED)
	state.preDugRow = 60
	state.deepestRow = 60
	local early = CaveView.visibleCells(state, caveConfig, 0, 20, NOW)
	local built: { [string]: boolean } = {}
	for _, cell in early do
		built[CaveView.key(cell.row, cell.x, cell.y)] = true
	end
	local late = CaveView.visibleCells(state, caveConfig, 40, 60, NOW)
	local change = CaveView.diff(built, late)
	assertEquals(#change.remove, #early)
	assertEquals(#change.add, #late)
end)

-- Reach ------------------------------------------------------------------------------------------

test("a cell within reach of the player's position can be hit, a far one cannot", function()
	local near = CaveView.cellCenter(world, blockSize, 2, 20, 0, 1)
	local playerNear = { x = near.x, y = near.y, z = near.z + 3 }
	assertEquals(CaveView.inReach(world, blockSize, 2, playerNear, 20, 0, 1), true)
	local far = { x = near.x, y = near.y, z = near.z + world.reachStuds + 20 }
	assertEquals(CaveView.inReach(world, blockSize, 2, far, 20, 0, 1), false)
	assertEquals(CaveView.inReach(world, blockSize, 2, { x = 0 / 0, y = 0, z = 0 }, 20, 0, 1), false)
end)
