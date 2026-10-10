--!strict
local BackpackConfig = require("../../src/shared/Config/Backpack")
local Cave = require("../../src/shared/Cave")
local CaveAction = require("../../src/shared/CaveAction")
local CaveConfig = require("../../src/shared/Config/Cave")
local Framework = require("../Framework")
local Layers = require("../../src/shared/Config/Layers")
local OnboardingConfig = require("../../src/shared/Config/Onboarding")
local ProfileData = require("../../src/server/ProfileData")
local ShovelConfig = require("../../src/shared/Config/Shovel")
local TestConfig = require("../TestConfig")
local TestRules = require("../TestRules")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals
local scriptedRng = Framework.scriptedRng

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

local CLOCK = 100
local TIME = 1700000000

local function failingRng(): number
	error("rng must not be used")
end

local function newProfile(): ProfileData.Profile
	local profile = ProfileData.new(TestRules, Framework.seededRng(1), TIME)
	-- Past the onboarding guarantee unless a test wants it.
	profile.onboarding.firstFindGiven = true
	return profile
end

-- A cave with a long pre-dug corridor, so there are many exposed wall cells.
local function newCave(profile: ProfileData.Profile): Cave.State
	local cave = Cave.new(profile.cave.seed)
	cave.preDugRow = 200
	cave.deepestRow = 200
	return cave
end

-- First exposed cell of the given kind in the corridor walls.
local function findCell(cave: Cave.State, kind: Cave.CellKind): Cave.Position
	for row = caveConfig.entranceRows, 200 do
		for x = -3, 3 do
			for y = 0, 4 do
				local cell = Cave.cellKind(cave, caveConfig, row, x, y, TIME)
				if cell.kind == kind and Cave.isExposed(cave, caveConfig, row, x, y, TIME) then
					return { row = row, x = x, y = y }
				end
			end
		end
	end
	error("no exposed cell of kind " .. kind)
end

-- A cave without a corridor, with the whole plane of row `row` opened (x -3..3, y 0..5),
-- so the next plane is exposed everywhere.
local function caveWithOpenPlane(profile: ProfileData.Profile, row: number): Cave.State
	local cave = Cave.new(profile.cave.seed)
	for r = caveConfig.entranceRows, row do
		for x = -3, 3 do
			for y = 0, caveConfig.height - 1 do
				Cave.mine(cave, caveConfig, 10, r, x, y, TIME)
			end
		end
	end
	return cave
end

local function params(profile: ProfileData.Profile, cave: Cave.State, hit: Cave.Position, rng: CaveAction.Rng?)
	return {
		profile = profile,
		cave = cave,
		caveConfig = caveConfig,
		digConfig = TestConfig,
		shovelLevels = ShovelConfig.levels,
		cooldownTolerance = ShovelConfig.cooldownTolerance,
		backpackLevels = BackpackConfig.levels,
		onboarding = {
			firstFindAfterBlocks = OnboardingConfig.firstFindAfterBlocks,
			firstFindMutation = OnboardingConfig.firstFindMutation,
		},
		hit = hit,
		axis = "row",
		lastDigAt = nil,
		now = CLOCK,
		time = TIME,
		rng = rng or failingRng,
	} :: CaveAction.Params
end

test("mining an ore cell puts the ore into the backpack, opens the cell and keeps the rng unused", function()
	local profile = newProfile()
	local cave = newCave(profile)
	local hit = findCell(cave, "ore")
	local expected = Cave.cellKind(cave, caveConfig, hit.row, hit.x, hit.y, TIME)
	local result = CaveAction.perform(params(profile, cave, hit))
	assertTrue(result.ok, tostring(result.reason))
	assertEquals(#result.mined, 1)
	assertEquals(result.mined[1].kind, "ore")
	assertEquals(profile.backpack.ores[expected.itemId :: string], 1)
	assertEquals(Cave.cellKind(cave, caveConfig, hit.row, hit.x, hit.y, TIME).kind, "air")
	assertEquals(result.used, 1)
	assertEquals(result.capacity, BackpackConfig.levels[1].capacity)
	assertEquals(profile.stats.blocksDug, 1)
end)

test("an herb goes into the backpack under its own id", function()
	local profile = newProfile()
	local cave = newCave(profile)
	local hit = findCell(cave, "herb")
	local expected = Cave.cellKind(cave, caveConfig, hit.row, hit.x, hit.y, TIME)
	local result = CaveAction.perform(params(profile, cave, hit))
	assertTrue(result.ok, tostring(result.reason))
	assertEquals(profile.backpack.ores[expected.itemId :: string], 1)
end)

test("rock gives no loot but counts as a dug block and costs no backpack space", function()
	local profile = newProfile()
	local cave = newCave(profile)
	local hit = findCell(cave, "rock")
	local result = CaveAction.perform(params(profile, cave, hit))
	assertTrue(result.ok, tostring(result.reason))
	assertEquals(result.mined[1].kind, "rock")
	assertEquals(result.used, 0)
	assertEquals(profile.stats.blocksDug, 1)
end)

test("a find spot rolls a rare find with a unique id", function()
	local profile = newProfile()
	local cave = newCave(profile)
	local hit = findCell(cave, "find_spot")
	-- Rarity, find, mutation check (no mutation): the rare check is skipped by the guarantee.
	local result = CaveAction.perform(params(profile, cave, hit, scriptedRng({ 0.0, 0.0, 0.99 })))
	assertTrue(result.ok, tostring(result.reason))
	assertEquals(#result.finds, 1)
	assertEquals(#profile.backpack.finds, 1)
	assertEquals(profile.backpack.finds[1].id, 1)
	assertEquals(profile.nextFindId, 2)
	assertEquals(result.finds[1].kind, "rare")
end)

test("a cooldown that has not passed changes nothing", function()
	local profile = newProfile()
	local cave = newCave(profile)
	local hit = findCell(cave, "ore")
	local p = params(profile, cave, hit)
	p.lastDigAt = CLOCK - 0.01
	local result = CaveAction.perform(p)
	assertEquals(result.ok, false)
	assertEquals(result.reason, "cooldown")
	assertEquals(profile.stats.blocksDug, 0)
	assertEquals(Cave.cellKind(cave, caveConfig, hit.row, hit.x, hit.y, TIME).kind, "ore")
end)

test("a swing covers the area of the pickaxe level and mines each cell once", function()
	local profile = newProfile()
	profile.upgradeLevels.shovel = 5 -- 3 x 3
	local cave = caveWithOpenPlane(profile, caveConfig.entranceRows)
	local blocksBefore = profile.stats.blocksDug
	local target = { row = caveConfig.entranceRows + 1, x = 0, y = 2 }
	local result = CaveAction.perform(params(profile, cave, target, Framework.seededRng(3)))
	assertTrue(result.ok, tostring(result.reason))
	assertEquals(#result.mined, 9)
	assertEquals(profile.stats.blocksDug, blocksBefore + 9)
	-- The same swing again finds only open cells.
	local again = CaveAction.perform(params(profile, cave, target, Framework.seededRng(3)))
	assertEquals(again.ok, false)
	assertEquals(again.reason, "nothing_mined")
end)

test("the swing stops taking loot when the backpack is full but still clears rock", function()
	local profile = newProfile()
	profile.upgradeLevels.shovel = 9 -- 5 x 5
	local cave = caveWithOpenPlane(profile, caveConfig.entranceRows)
	local row = caveConfig.entranceRows + 1
	local target = { row = row, x = 0, y = 2 }
	local cells = Cave.areaCells(target, "row", 5)
	local lootBefore, rockBefore = 0, 0
	for _, cell in cells do
		local kind = Cave.cellKind(cave, caveConfig, cell.row, cell.x, cell.y, TIME).kind
		if kind == "rock" then
			rockBefore += 1
		elseif kind == "ore" or kind == "herb" or kind == "find_spot" then
			lootBefore += 1
		end
	end
	assertTrue(lootBefore >= 2, "test seed needs two loot cells in the swing, got " .. lootBefore)

	-- One free place in the backpack.
	profile.backpack.ores = { coal = BackpackConfig.levels[1].capacity - 1 }
	local result = CaveAction.perform(params(profile, cave, target, Framework.seededRng(4)))
	assertTrue(result.ok, tostring(result.reason))
	assertEquals(result.stoppedFull, true)
	assertEquals(result.used, result.capacity)

	local lootAfter, rockAfter = 0, 0
	for _, cell in cells do
		local kind = Cave.cellKind(cave, caveConfig, cell.row, cell.x, cell.y, TIME).kind
		if kind == "rock" then
			rockAfter += 1
		elseif kind == "ore" or kind == "herb" or kind == "find_spot" then
			lootAfter += 1
		end
	end
	assertEquals(lootAfter, lootBefore - 1, "exactly one loot cell was taken")
	assertEquals(rockAfter, 0, "all rock of the swing was cleared")
	assertEquals(rockBefore + 1, #result.mined)
end)

test("a full backpack and only loot cells in the swing fails with backpack_full", function()
	local profile = newProfile()
	local cave = newCave(profile)
	local hit = findCell(cave, "ore")
	profile.backpack.ores = { coal = BackpackConfig.levels[1].capacity }
	local result = CaveAction.perform(params(profile, cave, hit))
	assertEquals(result.ok, false)
	assertEquals(result.reason, "backpack_full")
	assertEquals(Cave.cellKind(cave, caveConfig, hit.row, hit.x, hit.y, TIME).kind, "ore")
	assertEquals(profile.stats.blocksDug, 0)
end)

test("an invalid hit changes nothing", function()
	local profile = newProfile()
	local cave = newCave(profile)
	local p = params(profile, cave, { row = 1.5, x = 0, y = 0 })
	local result = CaveAction.perform(p)
	assertEquals(result.ok, false)
	assertEquals(result.reason, "invalid_hit")
	local q = params(profile, cave, { row = 5, x = 0, y = 0 })
	q.axis = "diagonal" :: any
	assertEquals(CaveAction.perform(q).reason, "invalid_hit")
	assertEquals(profile.stats.blocksDug, 0)
end)

test("a hit that reaches nothing fails with nothing_mined", function()
	local profile = newProfile()
	local cave = newCave(profile)
	-- Deep inside the rock, not exposed.
	local result = CaveAction.perform(params(profile, cave, { row = 300, x = 0, y = 0 }))
	assertEquals(result.ok, false)
	assertEquals(result.reason, "nothing_mined")
	assertEquals(profile.stats.blocksDug, 0)
end)

test("the legacy depth follows the cave depth", function()
	local profile = newProfile()
	local cave = Cave.new(profile.cave.seed)
	local hit = { row = caveConfig.entranceRows, x = 0, y = 0 }
	local result = CaveAction.perform(params(profile, cave, hit, Framework.seededRng(5)))
	assertTrue(result.ok, tostring(result.reason))
	assertEquals(profile.depth, Cave.depth(cave, caveConfig))
	assertEquals(result.depth, profile.depth)
	assertEquals(profile.depth, caveConfig.entranceRows * caveConfig.metersPerRow)
end)

test("the onboarding guarantee turns the next loot cell into a golden rare find, once", function()
	local profile = newProfile()
	profile.onboarding.firstFindGiven = false
	profile.stats.blocksDug = OnboardingConfig.firstFindAfterBlocks - 1
	local cave = newCave(profile)
	local hit = findCell(cave, "ore")
	-- Rarity, find and no further draws: the mutation is fixed by the guarantee.
	local result = CaveAction.perform(params(profile, cave, hit, scriptedRng({ 0.0, 0.0 })))
	assertTrue(result.ok, tostring(result.reason))
	assertEquals(#result.finds, 1)
	assertEquals(result.finds[1].mutationId, OnboardingConfig.firstFindMutation)
	assertEquals(profile.onboarding.firstFindGiven, true)

	-- The next ore is an ordinary ore again.
	local again = findCell(cave, "ore")
	local second = CaveAction.perform(params(profile, cave, again))
	assertTrue(second.ok, tostring(second.reason))
	assertEquals(#second.finds, 0)
end)

test("a bonus on the rare find chance can turn an ore cell into a find", function()
	local profile = newProfile()
	local cave = newCave(profile)
	local hit = findCell(cave, "ore")
	local p = params(profile, cave, hit, scriptedRng({ 0.0, 0.0, 0.0, 0.99 }))
	p.modifiers = { luck = 1, rareFindMultiplier = 3, speedMultiplier = 1, capacityMultiplier = 1 }
	local result = CaveAction.perform(p)
	assertTrue(result.ok, tostring(result.reason))
	assertEquals(#result.finds, 1)
end)

test("no bonus means the rng is never drawn for plain ore", function()
	local profile = newProfile()
	local cave = newCave(profile)
	local hit = findCell(cave, "ore")
	local result = CaveAction.perform(params(profile, cave, hit, failingRng))
	assertTrue(result.ok, tostring(result.reason))
end)

test("harvesting records the time in the cave for regrowth", function()
	local profile = newProfile()
	local cave = newCave(profile)
	local hit = findCell(cave, "ore")
	CaveAction.perform(params(profile, cave, hit))
	assertEquals(Cave.harvestedAt(cave, caveConfig, Cave.sliceOf(caveConfig, hit.row)), TIME)
end)

test("onboarding advances for a dig and for a find", function()
	local profile = newProfile()
	profile.onboarding = { step = 1, firstFindGiven = true }
	local cave = newCave(profile)
	local hit = findCell(cave, "ore")
	CaveAction.perform(params(profile, cave, hit))
	assertTrue(profile.onboarding.step >= 2)
end)
