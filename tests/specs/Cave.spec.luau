--!strict
local Cave = require("../../src/shared/Cave")
local CaveConfig = require("../../src/shared/Config/Cave")
local Framework = require("../Framework")
local Layers = require("../../src/shared/Config/Layers")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals
local assertNear = Framework.assertNear
local assertDeepEquals = Framework.assertDeepEquals

local config: Cave.Config = {
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

local NOW = 1000000
local SEED = 123456

local function listContains(list: { string }, value: string?): boolean
	return value ~= nil and table.find(list, value) ~= nil
end

-- Mines a straight corridor of one block (y = 0) from the entrance to `toRow`.
local function digCorridor(state: Cave.State, toRow: number, level: number?, now: number?)
	for row = config.entranceRows, toRow do
		local result = Cave.mine(state, config, level or 10, row, 0, 0, now or NOW)
		assertTrue(result.ok, "corridor row " .. row .. ": " .. tostring(result.reason))
	end
end

-- Test-only: opens a cell by writing the data (as if it had been mined earlier).
local function pokeOpen(state: Cave.State, row: number, x: number, y: number)
	local sliceIndex = Cave.sliceOf(config, row)
	local slice = state.slices[sliceIndex]
	if slice == nil then
		slice = { mined = {} }
		state.slices[sliceIndex] = slice
	end
	slice.mined[Cave.localIndex(config, row, x, y)] = true
end

local function openNeighbors(state: Cave.State, row: number, x: number, y: number)
	for _, offset in { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } } do
		local r, nx, ny = row + offset[1], x + offset[2], y + offset[3]
		if r >= 0 and math.abs(nx) <= config.maxRadius and ny >= 0 and ny < config.height then
			pokeOpen(state, r, nx, ny)
		end
	end
end

-- An exposed resource cell near the corridor (row range, small sideways range).
local function findExposedResource(state: Cave.State, fromRow: number, toRow: number): Cave.Position
	for row = fromRow, toRow do
		for x = -2, 2 do
			for y = 0, 2 do
				local kind = Cave.cellKind(state, config, row, x, y, NOW).kind
				if
					(kind == "ore" or kind == "herb" or kind == "find_spot")
					and Cave.isExposed(state, config, row, x, y, NOW)
				then
					return { row = row, x = x, y = y }
				end
			end
		end
	end
	error("no exposed resource cell between rows " .. fromRow .. " and " .. toRow)
end

-- Config -----------------------------------------------------------------

test("shipped cave config is valid", function()
	local ok, reason = Cave.validateConfig(config)
	assertTrue(ok, reason)
end)

test("validateConfig rejects broken values", function()
	local function with(change: (copy: any) -> ()): boolean
		local copy: any = table.clone(config)
		change(copy)
		local ok = Cave.validateConfig(copy)
		return ok
	end
	assertEquals(
		with(function(c)
			c.startRadius = 20
		end),
		false
	)
	assertEquals(
		with(function(c)
			c.radiusByLevel = { 6, 5 }
		end),
		false
	)
	assertEquals(
		with(function(c)
			c.radiusByLevel = { 6, 13 }
		end),
		false
	)
	assertEquals(
		with(function(c)
			c.areaByLevel = { 0 }
		end),
		false
	)
	assertEquals(
		with(function(c)
			c.resourceDensity = 101
		end),
		false
	)
	assertEquals(
		with(function(c)
			c.sliceRows = 0
		end),
		false
	)
	assertEquals(
		with(function(c)
			c.biomes = {}
		end),
		false
	)
	assertEquals(
		with(function(c)
			c.entranceRows = 0
		end),
		false
	)
	assertEquals(
		with(function(c)
			c.chestMinRow = 1
		end),
		false
	)
	assertEquals(
		with(function(c)
			c.corridorHalfWidth = 13
		end),
		false
	)
	assertEquals(
		with(function(c)
			c.corridorHeight = 0
		end),
		false
	)
end)

test("play area radius and swing area follow the pickaxe level and clamp", function()
	assertEquals(Cave.radiusFor(config, 1), 6)
	assertEquals(Cave.radiusFor(config, 10), 12)
	assertEquals(Cave.radiusFor(config, 0), 6)
	assertEquals(Cave.radiusFor(config, 99), 12)
	assertEquals(Cave.radiusFor(config, 0 / 0), 6)
	assertEquals(Cave.areaFor(config, 1), 1)
	assertEquals(Cave.areaFor(config, 5), 3)
	assertEquals(Cave.areaFor(config, 10), 5)
	assertEquals(Cave.areaFor(config, 99), 5)
end)

-- New state and depth -----------------------------------------------------

test("a new cave starts at depth 0 and rejects an invalid seed", function()
	local state = Cave.new(SEED)
	assertEquals(Cave.depth(state, config), 0)
	assertEquals(state.deepestRow, 0)
	for _, bad in { 0, -5, 1.5, 0 / 0, math.huge, 2 ^ 40 } do
		local ok = pcall(Cave.new, bad)
		assertEquals(ok, false)
	end
end)

-- Cell content --------------------------------------------------------------

test("the entrance hall is air and the wall behind it is not", function()
	local state = Cave.new(SEED)
	for row = 0, config.entranceRows - 1 do
		for x = -config.startRadius, config.startRadius do
			for y = 0, config.height - 1 do
				assertEquals(Cave.cellKind(state, config, row, x, y, NOW).kind, "air")
			end
		end
	end
	assertTrue(Cave.cellKind(state, config, config.entranceRows, 0, 0, NOW).kind ~= "air")
	assertTrue(Cave.cellKind(state, config, 0, config.startRadius + 1, 0, NOW).kind ~= "air")
end)

test("content is deterministic per seed and differs between seeds", function()
	local a = Cave.new(SEED)
	local b = Cave.new(SEED)
	local c = Cave.new(SEED + 1)
	local differs = 0
	for row = 3, 30 do
		for x = -12, 12 do
			for y = 0, 5 do
				local ka = Cave.cellKind(a, config, row, x, y, NOW)
				local kb = Cave.cellKind(b, config, row, x, y, NOW)
				local kc = Cave.cellKind(c, config, row, x, y, NOW)
				assertEquals(ka.kind, kb.kind)
				assertEquals(ka.itemId, kb.itemId)
				if ka.kind ~= kc.kind or ka.itemId ~= kc.itemId then
					differs += 1
				end
			end
		end
	end
	assertTrue(differs > 1000, "different seeds should differ, got " .. differs)
end)

test("resource density, herb share and find spot share match the config", function()
	local state = Cave.new(SEED)
	local total, resources, herbs, ores, spots = 0, 0, 0, 0, 0
	for row = 3, 120 do
		for x = -12, 12 do
			for y = 0, 5 do
				local cell = Cave.cellKind(state, config, row, x, y, NOW)
				if cell.kind == "chest" then
					continue
				end
				total += 1
				if cell.kind == "ore" or cell.kind == "herb" or cell.kind == "find_spot" then
					resources += 1
				end
				if cell.kind == "herb" then
					herbs += 1
				elseif cell.kind == "ore" then
					ores += 1
				elseif cell.kind == "find_spot" then
					spots += 1
				end
			end
		end
	end
	assertNear(resources / total * 100, config.resourceDensity, 1.0, "resource density")
	assertNear(herbs / resources * 100, config.herbShare, 1.5, "herb share")
	assertNear(spots / (ores + spots) * 100, config.findSpotShare, 0.6, "find spot share")
end)

test("ore and herb ids come from the biome of the row", function()
	local state = Cave.new(SEED)
	for row = 3, 260 do
		local depth = row * config.metersPerRow
		local biome = Cave.biomeAt(config, depth)
		for x = -3, 3 do
			local cell = Cave.cellKind(state, config, row, x, 1, NOW)
			if cell.kind == "ore" or cell.kind == "find_spot" then
				assertTrue(listContains(biome.ores, cell.itemId), "ore " .. tostring(cell.itemId) .. " in " .. biome.id)
			elseif cell.kind == "herb" then
				assertTrue(
					listContains(biome.herbs, cell.itemId),
					"herb " .. tostring(cell.itemId) .. " in " .. biome.id
				)
			end
		end
	end
end)

test("biomeAt follows the depth and clamps", function()
	assertEquals(Cave.biomeAt(config, 0).id, "sand_clay")
	assertEquals(Cave.biomeAt(config, 49.9).id, "sand_clay")
	assertEquals(Cave.biomeAt(config, 50).id, "rock")
	assertEquals(Cave.biomeAt(config, 150).id, "crystal")
	assertEquals(Cave.biomeAt(config, 9999).id, "crystal")
	assertEquals(Cave.biomeAt(config, -3).id, "sand_clay")
end)

-- Bounds and reach ---------------------------------------------------------------

test("cells outside the structure or the play area cannot be mined", function()
	local state = Cave.new(SEED)
	local function reason(level: number, row: number, x: number, y: number): string?
		return Cave.mine(state, config, level, row, x, y, NOW).reason
	end
	assertEquals(reason(10, -1, 0, 0), "out_of_bounds")
	assertEquals(reason(10, 3, 13, 0), "out_of_bounds")
	assertEquals(reason(10, 3, 0, -1), "out_of_bounds")
	assertEquals(reason(10, 3, 0, config.height), "out_of_bounds")
	assertEquals(reason(10, 3.5, 0, 0), "out_of_bounds")
	-- Inside the structure but wider than the radius of a level 1 pickaxe.
	assertEquals(reason(1, config.entranceRows, 7, 0), "out_of_area")
end)

test("a cell that is open already cannot be mined again", function()
	local state = Cave.new(SEED)
	assertEquals(Cave.mine(state, config, 10, 0, 0, 0, NOW).reason, "already_open")
	digCorridor(state, 3)
	assertEquals(Cave.mine(state, config, 10, 3, 0, 0, NOW).reason, "already_open")
end)

test("only exposed cells can be mined (no digging through walls)", function()
	local state = Cave.new(SEED)
	-- Directly behind the hall: exposed. Two rows further: not.
	assertEquals(Cave.isExposed(state, config, config.entranceRows, 0, 0, NOW), true)
	assertEquals(Cave.isExposed(state, config, config.entranceRows + 1, 0, 0, NOW), false)
	assertEquals(Cave.mine(state, config, 10, config.entranceRows + 1, 0, 0, NOW).reason, "not_exposed")
	assertTrue(Cave.mine(state, config, 10, config.entranceRows, 0, 0, NOW).ok)
	assertEquals(Cave.isExposed(state, config, config.entranceRows + 1, 0, 0, NOW), true)
end)

-- Mining -------------------------------------------------------------------------

test("mining returns the content, marks the cell and deepens the cave", function()
	local state = Cave.new(SEED)
	local expected = Cave.cellKind(state, config, config.entranceRows, 0, 0, NOW)
	local result = Cave.mine(state, config, 1, config.entranceRows, 0, 0, NOW)
	assertTrue(result.ok)
	assertEquals(result.kind, expected.kind)
	assertEquals(result.itemId, expected.itemId)
	assertEquals(Cave.cellKind(state, config, config.entranceRows, 0, 0, NOW).kind, "air")
	assertEquals(state.deepestRow, config.entranceRows)
	assertEquals(Cave.depth(state, config), config.entranceRows * config.metersPerRow)
end)

test("deepestRow never goes back", function()
	local state = Cave.new(SEED)
	digCorridor(state, 8)
	assertEquals(state.deepestRow, 8)
	assertTrue(Cave.mine(state, config, 10, 5, 1, 0, NOW).ok)
	assertEquals(state.deepestRow, 8)
end)

test("rock gives no harvest time, resources do", function()
	local state = Cave.new(SEED)
	local rockCell: { number }? = nil
	local resourceCell: { number }? = nil
	for x = -6, 6 do
		for y = 0, 5 do
			local kind = Cave.cellKind(state, config, config.entranceRows, x, y, NOW).kind
			if kind == "rock" and rockCell == nil then
				rockCell = { x, y }
			elseif kind ~= "rock" and kind ~= "chest" and resourceCell == nil then
				resourceCell = { x, y }
			end
		end
	end
	assertTrue(
		rockCell ~= nil and resourceCell ~= nil,
		"test seed needs a rock and a resource cell in the first wall row"
	)
	local rock = rockCell :: { number }
	local resource = resourceCell :: { number }
	assertTrue(Cave.mine(state, config, 10, config.entranceRows, rock[1], rock[2], NOW).ok)
	assertEquals(Cave.harvestedAt(state, config, 0), nil)
	assertTrue(Cave.mine(state, config, 10, config.entranceRows, resource[1], resource[2], NOW + 5).ok)
	assertEquals(Cave.harvestedAt(state, config, 0), NOW + 5)
end)

-- Swing area -------------------------------------------------------------------------

test("areaCells returns a square in the plane of the hit face", function()
	local one = Cave.areaCells({ row = 5, x = 0, y = 2 }, "row", 1)
	assertEquals(#one, 1)
	local three = Cave.areaCells({ row = 5, x = 0, y = 2 }, "row", 3)
	assertEquals(#three, 9)
	for _, cell in three do
		assertEquals(cell.row, 5)
		assertTrue(math.abs(cell.x) <= 1 and cell.y >= 1 and cell.y <= 3)
	end
	local side = Cave.areaCells({ row = 5, x = 4, y = 2 }, "x", 2)
	assertEquals(#side, 4)
	for _, cell in side do
		assertEquals(cell.x, 4)
	end
end)

test("areaCells is ordered and has no duplicates", function()
	local cells = Cave.areaCells({ row = 7, x = 1, y = 3 }, "y", 4)
	assertEquals(#cells, 16)
	local seen: { [string]: boolean } = {}
	for _, cell in cells do
		local key = cell.row .. "," .. cell.x .. "," .. cell.y
		assertTrue(not seen[key], "duplicate " .. key)
		seen[key] = true
	end
end)

test("mineArea mines every reachable cell of the swing and skips the rest", function()
	local state = Cave.new(SEED)
	local row = config.entranceRows
	local cells = Cave.areaCells({ row = row, x = 0, y = 2 }, "row", 3)
	local summary = Cave.mineArea(state, config, 10, cells, NOW)
	assertEquals(#summary.mined + #summary.rejected, 9)
	assertEquals(#summary.mined, 9)
	-- A second swing at the same place finds only open cells.
	local again = Cave.mineArea(state, config, 10, cells, NOW)
	assertEquals(#again.mined, 0)
	assertEquals(#again.rejected, 9)
	assertEquals(again.rejected[1].reason, "already_open")
end)

test("mineArea clips at the structure and the play area", function()
	local state = Cave.new(SEED)
	local cells = Cave.areaCells({ row = config.entranceRows, x = 6, y = 0 }, "row", 3)
	-- Level 1 reaches 6 blocks sideways: x = 7 is out of the area; y = -1 is out of the structure.
	local summary = Cave.mineArea(state, config, 1, cells, NOW)
	assertEquals(#summary.mined, 4)
	assertEquals(#summary.rejected, 5)
end)

-- Pre-dug corridor (existing players keep their depth) -----------------------------------

test("a pre-dug corridor is open from the hall to its row, inside its shape only", function()
	local state = Cave.new(SEED)
	state.preDugRow = 40
	state.deepestRow = 40
	for row = config.entranceRows, 40 do
		for x = -config.corridorHalfWidth, config.corridorHalfWidth do
			for y = 0, config.corridorHeight - 1 do
				assertEquals(Cave.cellKind(state, config, row, x, y, NOW).kind, "air", row .. "," .. x .. "," .. y)
			end
		end
	end
	-- Outside the corridor shape and behind its end the rock is still there.
	assertTrue(Cave.cellKind(state, config, 20, config.corridorHalfWidth + 1, 0, NOW).kind ~= "air")
	assertTrue(Cave.cellKind(state, config, 20, 0, config.corridorHeight, NOW).kind ~= "air")
	assertTrue(Cave.cellKind(state, config, 41, 0, 0, NOW).kind ~= "air")
end)

test("the cell behind the end of the corridor is exposed and can be mined", function()
	local state = Cave.new(SEED)
	state.preDugRow = 40
	state.deepestRow = 40
	assertEquals(Cave.isExposed(state, config, 41, 0, 0, NOW), true)
	assertTrue(Cave.mine(state, config, 10, 41, 0, 0, NOW).ok)
	assertEquals(state.deepestRow, 41)
	assertEquals(Cave.depth(state, config), 41 * config.metersPerRow)
end)

test("walls of the pre-dug corridor can be mined from inside", function()
	local state = Cave.new(SEED)
	state.preDugRow = 40
	assertEquals(Cave.mine(state, config, 10, 20, config.corridorHalfWidth + 1, 0, NOW).reason ~= "not_exposed", true)
end)

test("the pre-dug row survives saving and loading and defaults to 0", function()
	local state = Cave.new(SEED)
	state.preDugRow = 120
	state.deepestRow = 120
	local data = Cave.serialize(state, config)
	assertEquals(data.preDugRow, 120)
	local restored = Cave.deserialize(data, config)
	assertTrue(restored ~= nil)
	assertEquals((restored :: Cave.State).preDugRow, 120)
	assertEquals(Cave.isOpen(restored :: Cave.State, config, 100, 0, 0, NOW), true)

	local old: any = Cave.serialize(Cave.new(SEED), config)
	old.preDugRow = nil
	local oldRestored = Cave.deserialize(old, config)
	assertTrue(oldRestored ~= nil)
	assertEquals((oldRestored :: Cave.State).preDugRow, 0)
end)

test("deserialize rejects a bad pre-dug row", function()
	local function bad(value: any): boolean
		local data: any = Cave.serialize(Cave.new(SEED), config)
		data.preDugRow = value
		return Cave.deserialize(data, config) == nil
	end
	assertTrue(bad(-1))
	assertTrue(bad(1.5))
	assertTrue(bad("40"))
end)

-- Regrowth -----------------------------------------------------------------------------

local function firstResourceCell(state: Cave.State, row: number): { number }
	for x = -config.startRadius, config.startRadius do
		for y = 0, config.height - 1 do
			local kind = Cave.cellKind(state, config, row, x, y, NOW).kind
			if kind == "ore" or kind == "herb" or kind == "find_spot" then
				return { x, y }
			end
		end
	end
	error("no resource cell in row " .. row)
end

test("a mined resource grows back after the regrow time, rock stays open", function()
	local state = Cave.new(SEED)
	local row = config.entranceRows
	local resource = firstResourceCell(state, row)
	assertTrue(Cave.mine(state, config, 10, row, resource[1], resource[2], NOW).ok)
	assertEquals(Cave.cellKind(state, config, row, resource[1], resource[2], NOW).kind, "air")

	assertEquals(Cave.regrow(state, config, 0, NOW + config.regrowSeconds - 1), 0)
	assertEquals(Cave.cellKind(state, config, row, resource[1], resource[2], NOW).kind, "air")

	local regrown = Cave.regrow(state, config, 0, NOW + config.regrowSeconds)
	assertEquals(regrown, 1)
	local back = Cave.cellKind(state, config, row, resource[1], resource[2], NOW)
	assertTrue(back.kind == "ore" or back.kind == "herb" or back.kind == "find_spot")
	assertEquals(Cave.harvestedAt(state, config, 0), nil)
end)

test("mined rock never grows back", function()
	local state = Cave.new(SEED)
	local row = config.entranceRows
	local rockCell: { number }? = nil
	for x = -6, 6 do
		if Cave.cellKind(state, config, row, x, 1, NOW).kind == "rock" then
			rockCell = { x, 1 }
			break
		end
	end
	assertTrue(rockCell ~= nil)
	local rock = rockCell :: { number }
	local resource = firstResourceCell(state, row)
	Cave.mine(state, config, 10, row, rock[1], rock[2], NOW)
	Cave.mine(state, config, 10, row, resource[1], resource[2], NOW)
	Cave.regrow(state, config, 0, NOW + config.regrowSeconds * 2)
	assertEquals(Cave.cellKind(state, config, row, rock[1], rock[2], NOW).kind, "air")
end)

test("a resource cell without any solid neighbor stays open", function()
	local state = Cave.new(SEED)
	local row, x, y = config.entranceRows + 4, 0, 2
	assertEquals(Cave.hasSolidNeighbor(state, config, row, x, y, NOW), true)
	openNeighbors(state, row, x, y)
	assertEquals(Cave.hasSolidNeighbor(state, config, row, x, y, NOW), false)
	-- Pretend the cell was harvested earlier: it is mined and the slice remembers the time.
	pokeOpen(state, row, x, y)
	state.slices[Cave.sliceOf(config, row)].harvestedAt = NOW
	local content = Cave.cellKind(state, config, row, x, y, NOW)
	assertEquals(content.kind, "air")
	-- Even if the seed puts a resource there, nothing holds it: it does not come back.
	assertEquals(Cave.regrow(state, config, Cave.sliceOf(config, row), NOW + config.regrowSeconds), 0)
	assertEquals(Cave.cellKind(state, config, row, x, y, NOW).kind, "air")
end)

test("regrowAll walks every slice", function()
	local state = Cave.new(SEED)
	digCorridor(state, 20)
	-- One harvest in slice 0 and one in slice 1.
	local first = findExposedResource(state, config.entranceRows, 10)
	assertTrue(Cave.mine(state, config, 10, first.row, first.x, first.y, NOW).ok)
	local second = findExposedResource(state, 16, 20)
	assertTrue(Cave.mine(state, config, 10, second.row, second.x, second.y, NOW).ok)
	assertTrue(Cave.sliceOf(config, first.row) ~= Cave.sliceOf(config, second.row))
	-- Digging the corridor harvested resources too, so at least these two come back.
	assertEquals(Cave.regrowAll(state, config, NOW + config.regrowSeconds - 1), 0)
	assertTrue(Cave.regrowAll(state, config, NOW + config.regrowSeconds) >= 2)
	assertEquals(Cave.cellKind(state, config, first.row, first.x, first.y, NOW).kind ~= "air", true)
	assertEquals(Cave.cellKind(state, config, second.row, second.x, second.y, NOW).kind ~= "air", true)
	assertEquals(Cave.harvestedAt(state, config, Cave.sliceOf(config, first.row)), nil)
	assertEquals(Cave.harvestedAt(state, config, Cave.sliceOf(config, second.row)), nil)
	assertEquals(Cave.regrowAll(state, config, NOW + config.regrowSeconds * 3), 0)
end)

-- Chests ---------------------------------------------------------------------------------

local function firstChest(
	state: Cave.State,
	fromSlice: number,
	count: number
): (number, { row: number, x: number, y: number })
	for sliceIndex = fromSlice, fromSlice + count do
		local position = Cave.chestPosition(config, state.seed, sliceIndex)
		if position ~= nil then
			return sliceIndex, position
		end
	end
	error("no chest found")
end

test("chest positions are deterministic, inside the structure and past the minimum row", function()
	local chests = 0
	local slices = 600
	for sliceIndex = 0, slices - 1 do
		local a = Cave.chestPosition(config, SEED, sliceIndex)
		local b = Cave.chestPosition(config, SEED, sliceIndex)
		assertDeepEquals(a, b)
		if a ~= nil then
			chests += 1
			assertEquals(Cave.sliceOf(config, a.row), sliceIndex)
			assertTrue(a.row >= config.chestMinRow)
			assertTrue(math.abs(a.x) <= config.maxRadius and a.y >= 0 and a.y < config.height)
		end
	end
	assertNear(chests / slices * 100, config.chestChance, 6, "chest chance")
end)

test("a chest cell is a chest and cannot be mined", function()
	local state = Cave.new(SEED)
	local _, position = firstChest(state, 1, 200)
	assertEquals(Cave.cellKind(state, config, position.row, position.x, position.y, NOW).kind, "chest")
	-- Hidden in the rock it is just unreachable; it does not give its place away.
	assertEquals(Cave.mine(state, config, 10, position.row, position.x, position.y, NOW).reason, "not_exposed")
	openNeighbors(state, position.row, position.x, position.y)
	assertEquals(Cave.mine(state, config, 10, position.row, position.x, position.y, NOW).reason, "is_chest")
end)

test("opening a chest needs it to be exposed and works once per respawn", function()
	local state = Cave.new(SEED)
	local _, position = firstChest(state, 1, 200)
	assertEquals(Cave.openChest(state, config, 10, position.row, position.x, position.y, NOW).reason, "not_exposed")

	openNeighbors(state, position.row, position.x, position.y)
	local opened = Cave.openChest(state, config, 10, position.row, position.x, position.y, NOW)
	assertTrue(opened.ok, tostring(opened.reason))
	assertEquals(Cave.cellKind(state, config, position.row, position.x, position.y, NOW).kind, "air")
	assertEquals(Cave.isOpen(state, config, position.row, position.x, position.y, NOW), true)
	assertEquals(Cave.openChest(state, config, 10, position.row, position.x, position.y, NOW + 1).reason, "not_a_chest")

	-- It comes back after the respawn time and can be opened again.
	local later = NOW + config.chestRespawnSeconds
	assertEquals(Cave.cellKind(state, config, position.row, position.x, position.y, later).kind, "chest")
	assertTrue(Cave.openChest(state, config, 10, position.row, position.x, position.y, later).ok)
end)

test("a chest outside the play area of the pickaxe cannot be opened yet", function()
	local state = Cave.new(SEED)
	for sliceIndex = 1, 400 do
		local position = Cave.chestPosition(config, state.seed, sliceIndex)
		if position ~= nil and math.abs(position.x) > config.radiusByLevel[1] then
			openNeighbors(state, position.row, position.x, position.y)
			assertEquals(
				Cave.openChest(state, config, 1, position.row, position.x, position.y, NOW).reason,
				"out_of_area"
			)
			assertTrue(Cave.openChest(state, config, 10, position.row, position.x, position.y, NOW).ok)
			return
		end
	end
	error("no wide chest found")
end)

test("opening something that is not a chest is rejected", function()
	local state = Cave.new(SEED)
	assertEquals(Cave.openChest(state, config, 10, config.entranceRows, 0, 0, NOW).reason, "not_a_chest")
	assertEquals(Cave.openChest(state, config, 10, -1, 0, 0, NOW).reason, "out_of_bounds")
end)

-- Save format ------------------------------------------------------------------------------

test("serialize and deserialize keep everything that matters", function()
	local state = Cave.new(SEED)
	digCorridor(state, 25)
	local resource = firstResourceCell(state, 20)
	Cave.mine(state, config, 10, 20, resource[1], resource[2], NOW + 77)
	local data = Cave.serialize(state, config)
	local copy, reason = Cave.deserialize(data, config)
	assertTrue(copy ~= nil, reason)
	local restored = copy :: Cave.State
	assertEquals(restored.seed, state.seed)
	assertEquals(restored.deepestRow, state.deepestRow)
	for row = 0, 30 do
		for x = -12, 12, 3 do
			for y = 0, 5 do
				local a = Cave.cellKind(state, config, row, x, y, NOW)
				local b = Cave.cellKind(restored, config, row, x, y, NOW)
				if a.kind ~= b.kind or a.itemId ~= b.itemId then
					error(string.format("cell %d,%d,%d differs: %s vs %s", row, x, y, a.kind, b.kind))
				end
			end
		end
	end
	assertEquals(
		Cave.harvestedAt(restored, config, Cave.sliceOf(config, 20)),
		Cave.harvestedAt(state, config, Cave.sliceOf(config, 20))
	)
end)

test("serialized data only holds plain values with string keys", function()
	local state = Cave.new(SEED)
	digCorridor(state, 40)
	local data = Cave.serialize(state, config)
	assertEquals(type(data.seed), "number")
	for key, slice in data.slices do
		assertEquals(type(key), "string")
		assertEquals(type(slice.bits), "string")
	end
	for key, openedAt in data.chests do
		assertEquals(type(key), "string")
		assertEquals(type(openedAt), "number")
	end
end)

test("fractional times are rounded down when saving, so the data always loads", function()
	local state = Cave.new(SEED)
	local resource = findExposedResource(state, config.entranceRows, config.entranceRows)
	assertTrue(Cave.mine(state, config, 10, resource.row, resource.x, resource.y, NOW + 0.75).ok)
	local _, chestPos = firstChest(state, 1, 200)
	openNeighbors(state, chestPos.row, chestPos.x, chestPos.y)
	assertTrue(Cave.openChest(state, config, 10, chestPos.row, chestPos.x, chestPos.y, NOW + 1.5).ok)
	local data = Cave.serialize(state, config)
	local restored, reason = Cave.deserialize(data, config)
	assertTrue(restored ~= nil, reason)
	assertEquals(Cave.harvestedAt(restored :: Cave.State, config, 0), NOW)
	assertEquals((restored :: Cave.State).chests[Cave.sliceOf(config, chestPos.row)], NOW + 1)
end)

test("an untouched cave serializes to almost nothing", function()
	local data = Cave.serialize(Cave.new(SEED), config)
	assertEquals(next(data.slices), nil)
	assertEquals(next(data.chests), nil)
end)

test("a cave with a long corridor stays small", function()
	local state = Cave.new(SEED)
	digCorridor(state, 300)
	local data = Cave.serialize(state, config)
	local size = 0
	for _, slice in data.slices do
		size += #slice.bits
	end
	assertTrue(size < 10000, "a 300 row corridor should stay below 10 KB, got " .. size)
end)

test("deserialize rejects corrupted data", function()
	local function bad(change: (data: any) -> ()): boolean
		local state = Cave.new(SEED)
		digCorridor(state, 20)
		local data: any = Cave.serialize(state, config)
		change(data)
		local restored = Cave.deserialize(data, config)
		return restored == nil
	end
	assertTrue(bad(function(d)
		d.seed = 0
	end))
	assertTrue(bad(function(d)
		d.deepestRow = -1
	end))
	assertTrue(bad(function(d)
		d.slices["x"] = d.slices["0"]
	end))
	assertTrue(bad(function(d)
		d.slices["0"].bits = "short"
	end))
	assertTrue(bad(function(d)
		d.slices["0"].harvestedAt = -5
	end))
	assertTrue(bad(function(d)
		d.chests["1"] = "yesterday"
	end))
	assertTrue(bad(function(d)
		d.slices = nil
	end))
	local notTable = Cave.deserialize(5 :: any, config)
	assertEquals(notTable, nil)
end)
