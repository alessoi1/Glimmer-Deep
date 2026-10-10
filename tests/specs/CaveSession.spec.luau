--!strict
local BackpackConfig = require("../../src/shared/Config/Backpack")
local Cave = require("../../src/shared/Cave")
local CaveConfig = require("../../src/shared/Config/Cave")
local CaveSession = require("../../src/shared/CaveSession")
local CaveView = require("../../src/shared/CaveView")
local ChestLoot = require("../../src/shared/ChestLoot")
local ChestsConfig = require("../../src/shared/Config/Chests")
local Equipment = require("../../src/shared/Equipment")
local EquipmentConfig = require("../../src/shared/Config/Equipment")
local Framework = require("../Framework")
local Layers = require("../../src/shared/Config/Layers")
local OnboardingConfig = require("../../src/shared/Config/Onboarding")
local PotionsConfig = require("../../src/shared/Config/Potions")
local Potions = require("../../src/shared/Potions")
local ProfileData = require("../../src/server/ProfileData")
local ShovelConfig = require("../../src/shared/Config/Shovel")
local TestConfig = require("../TestConfig")
local TestRules = require("../TestRules")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals

local config = CaveSession.assemble({
	blockSize = CaveConfig.blockSize,
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
	world = CaveConfig.world,
}, Layers)

local world: CaveView.World = CaveConfig.world
local BLOCK = CaveConfig.blockSize
local TIME = 1700000000
local CLOCK = 100
local SLOT = 2

local function failingRng(): number
	error("rng must not be used")
end

local function newProfile(corridor: number): ProfileData.Profile
	local profile = ProfileData.new(TestRules, Framework.seededRng(1), TIME)
	profile.onboarding.firstFindGiven = true
	profile.cave.preDugRow = corridor
	profile.cave.deepestRow = corridor
	return profile
end

local function newSession(profile: ProfileData.Profile): CaveSession.Session
	local session, reason = CaveSession.new(profile.cave, config, world, BLOCK, SLOT)
	assertTrue(session ~= nil, reason)
	return session :: CaveSession.Session
end

local function standingAt(session: CaveSession.Session, row: number): CaveView.Vec
	return CaveView.cellCenter(world, BLOCK, session.slot, row, 0, 1)
end

-- First exposed cell of a kind in the corridor walls.
local function findCell(session: CaveSession.Session, kind: Cave.CellKind): Cave.Position
	for row = config.entranceRows, 150 do
		for x = -3, 3 do
			for y = 0, 4 do
				local cell = Cave.cellKind(session.cave, config, row, x, y, TIME)
				if cell.kind == kind and Cave.isExposed(session.cave, config, row, x, y, TIME) then
					return { row = row, x = x, y = y }
				end
			end
		end
	end
	error("no exposed cell of kind " .. kind)
end

local function swingParams(
	profile: ProfileData.Profile,
	position: CaveView.Vec,
	hit: Cave.Position
): CaveSession.SwingParams
	return {
		profile = profile,
		position = position,
		hit = hit,
		axis = "row",
		digConfig = TestConfig,
		shovelLevels = ShovelConfig.levels,
		cooldownTolerance = ShovelConfig.cooldownTolerance,
		backpackLevels = BackpackConfig.levels,
		onboarding = {
			firstFindAfterBlocks = OnboardingConfig.firstFindAfterBlocks,
			firstFindMutation = OnboardingConfig.firstFindMutation,
		},
		now = CLOCK,
		time = TIME,
		rng = failingRng,
	}
end

test("a new session loads the cave and refuses broken saved data", function()
	local profile = newProfile(40)
	local session = newSession(profile)
	assertEquals(session.cave.seed, profile.cave.seed)
	assertEquals(session.cave.preDugRow, 40)
	local broken: any = { seed = "x", deepestRow = 0, preDugRow = 0, slices = {}, chests = {} }
	local none, reason = CaveSession.new(broken, config, world, BLOCK, SLOT)
	assertTrue(none == nil)
	assertTrue(reason ~= nil)
	local noSlot, slotReason = CaveSession.new(profile.cave, config, world, BLOCK, -1)
	assertTrue(noSlot == nil)
	assertTrue(slotReason ~= nil)
end)

test("the entry point lies in the hall of the player's own slot", function()
	local session = newSession(newProfile(0))
	local point = CaveSession.entryPoint(session)
	assertEquals(CaveView.rowAt(world, BLOCK, SLOT, point), 1)
	local other = newSession(newProfile(0))
	other.slot = SLOT + 1
	assertTrue(math.abs(CaveSession.entryPoint(other).x - point.x) >= world.slotSpacing - 1)
end)

test("refresh builds the window once and then only changes what moved", function()
	local session = newSession(newProfile(60))
	local position = standingAt(session, 10)
	local first = CaveSession.refresh(session, position, TIME)
	assertTrue(#first.diff.add > 0)
	assertEquals(#first.diff.remove, 0)
	assertEquals(first.count, #first.diff.add)
	assertTrue(not first.overBudget)
	assertEquals(first.row, 10)

	local again = CaveSession.refresh(session, position, TIME)
	assertEquals(#again.diff.add, 0)
	assertEquals(#again.diff.remove, 0)

	local moved = CaveSession.refresh(session, standingAt(session, 30), TIME)
	assertTrue(#moved.diff.add > 0)
	assertTrue(#moved.diff.remove > 0)
	for _, key in moved.diff.remove do
		assertTrue(session.built[key] == nil)
	end
end)

test("a position before the cave counts as row 0", function()
	local session = newSession(newProfile(0))
	local before = CaveView.cellCenter(world, BLOCK, SLOT, -20, 0, 1)
	assertEquals(CaveSession.refresh(session, before, TIME).row, 0)
end)

test("clearBuilt makes the next refresh rebuild everything", function()
	local session = newSession(newProfile(60))
	local first = CaveSession.refresh(session, standingAt(session, 10), TIME)
	CaveSession.clearBuilt(session)
	local second = CaveSession.refresh(session, standingAt(session, 10), TIME)
	assertEquals(#second.diff.add, #first.diff.add)
end)

test("a swing mines the cell, fills the backpack and writes the cave into the profile", function()
	local profile = newProfile(150)
	local session = newSession(profile)
	local hit = findCell(session, "ore")
	local result = CaveSession.swing(session, swingParams(profile, standingAt(session, hit.row), hit))
	assertTrue(result.ok, tostring(result.reason))
	assertTrue(result.action ~= nil and #result.action.mined >= 1)
	assertTrue(Cave.isOpen(session.cave, config, hit.row, hit.x, hit.y, TIME))
	assertEquals(session.lastDigAt, CLOCK)
	-- The mined cell is saved in the profile and loads again.
	local reloaded = Cave.deserialize(profile.cave, config)
	assertTrue(reloaded ~= nil and Cave.isOpen(reloaded, config, hit.row, hit.x, hit.y, TIME))
end)

test("a swing from too far away or at a wrong cell changes nothing", function()
	local profile = newProfile(150)
	local session = newSession(profile)
	local hit = findCell(session, "ore")
	local far = standingAt(session, hit.row + 40)
	local tooFar = CaveSession.swing(session, swingParams(profile, far, hit))
	assertTrue(not tooFar.ok)
	assertEquals(tooFar.reason, "out_of_reach")
	assertTrue(not Cave.isOpen(session.cave, config, hit.row, hit.x, hit.y, TIME))
	assertEquals(session.lastDigAt, nil)

	local bad: any = { row = 1.5, x = 0, y = 0 }
	assertEquals(CaveSession.swing(session, swingParams(profile, far, bad)).reason, "invalid_hit")
	local nan: any = { row = 0 / 0, x = 0, y = 0 }
	assertEquals(CaveSession.swing(session, swingParams(profile, far, nan)).reason, "invalid_hit")
	local nilHit: any = nil
	assertEquals(CaveSession.swing(session, swingParams(profile, far, nilHit)).reason, "invalid_hit")
	assertEquals(profile.stats.blocksDug, 0)
end)

test("a second swing inside the cooldown is refused and keeps the first time", function()
	local profile = newProfile(150)
	local session = newSession(profile)
	local first = findCell(session, "ore")
	local position = standingAt(session, first.row)
	assertTrue(CaveSession.swing(session, swingParams(profile, position, first)).ok)
	local second = findCell(session, "ore")
	local params = swingParams(profile, position, second)
	params.now = CLOCK + 0.01
	local result = CaveSession.swing(session, params)
	assertTrue(not result.ok)
	assertEquals(result.reason, "cooldown")
	assertEquals(session.lastDigAt, CLOCK)
end)

test("the cave of another slot is out of reach", function()
	local profile = newProfile(150)
	local session = newSession(profile)
	local hit = findCell(session, "ore")
	local inOtherCave = CaveView.cellCenter(world, BLOCK, SLOT + 1, hit.row, 0, 1)
	local result = CaveSession.swing(session, swingParams(profile, inOtherCave, hit))
	assertEquals(result.reason, "out_of_reach")
end)

test("after a swing the next refresh removes the mined cell and shows what lies behind", function()
	local profile = newProfile(150)
	local session = newSession(profile)
	local hit = findCell(session, "rock")
	local position = standingAt(session, hit.row)
	CaveSession.refresh(session, position, TIME)
	local key = CaveView.key(hit.row, hit.x, hit.y)
	assertTrue(session.built[key] == true)
	assertTrue(CaveSession.swing(session, swingParams(profile, position, hit)).ok)
	local refresh = CaveSession.refresh(session, position, TIME)
	local removed = false
	for _, removedKey in refresh.diff.remove do
		if removedKey == key then
			removed = true
		end
	end
	assertTrue(removed)
	assertTrue(session.built[key] == nil)
end)

-- Looks for a slice whose chest cell is exposed inside a long corridor-free cave
-- by opening the way to it, then returns the session and the chest position.
local function sessionWithChestInReach(): (CaveSession.Session, ProfileData.Profile, Cave.Position)
	for seed = 1, 400 do
		local profile = newProfile(0)
		profile.cave.seed = seed
		local session = newSession(profile)
		for sliceIndex = 0, 6 do
			local chest = Cave.chestPosition(config, seed, sliceIndex)
			if chest ~= nil and math.abs(chest.x) <= CaveConfig.startRadius then
				-- Open the whole plane in front of the chest so it is exposed.
				for row = config.entranceRows, chest.row - 1 do
					for x = -chest.x - 1, chest.x + 1 do
						for y = 0, config.height - 1 do
							Cave.mine(session.cave, config, 10, row, x, y, TIME)
						end
					end
					for x = -config.startRadius, config.startRadius do
						for y = 0, config.height - 1 do
							Cave.mine(session.cave, config, 10, row, x, y, TIME)
						end
					end
				end
				if Cave.isExposed(session.cave, config, chest.row, chest.x, chest.y, TIME) then
					return session, profile, chest
				end
			end
		end
	end
	error("no suitable chest found")
end

local lootDeps: ChestLoot.Deps = {
	equipment = EquipmentConfig :: Equipment.Config,
	potions = PotionsConfig :: Potions.Config,
}

local function chestParams(
	profile: ProfileData.Profile,
	position: CaveView.Vec,
	hit: Cave.Position
): CaveSession.ChestParams
	return {
		profile = profile :: any,
		position = position,
		hit = hit,
		digConfig = TestConfig,
		lootConfig = ChestsConfig,
		lootDeps = lootDeps,
		luck = nil,
		mutationBoost = nil,
		time = TIME,
		rng = Framework.seededRng(7),
	}
end

test("opening a chest puts loot into the profile, saves it and empties the spot", function()
	local session, profile, chest = sessionWithChestInReach()
	local position = standingAt(session, chest.row)
	local coinsBefore = profile.coins
	local result = CaveSession.openChest(session, chestParams(profile, position, chest))
	assertTrue(result.ok, tostring(result.reason))
	assertTrue(#result.entries >= ChestsConfig.rolls.min)
	assertEquals(result.biomeIndex, 1)
	assertTrue(result.summary ~= nil)
	assertTrue(Cave.isOpen(session.cave, config, chest.row, chest.x, chest.y, TIME))
	assertEquals(profile.cave.chests[tostring(Cave.sliceOf(config, chest.row))], TIME)
	assertTrue(profile.coins >= coinsBefore)
	-- Opening it again does not give a second reward.
	local again = CaveSession.openChest(session, chestParams(profile, position, chest))
	assertTrue(not again.ok)
	assertEquals(#again.entries, 0)
end)

test("a chest cannot be opened from too far away or at a wrong cell", function()
	local session, profile, chest = sessionWithChestInReach()
	local far = standingAt(session, chest.row + 60)
	local result = CaveSession.openChest(session, chestParams(profile, far, chest))
	assertEquals(result.reason, "out_of_reach")
	local notChest = { row = chest.row, x = chest.x + 1, y = chest.y }
	local wrong = CaveSession.openChest(session, chestParams(profile, standingAt(session, chest.row), notChest))
	assertTrue(not wrong.ok)
	local bad: any = { row = 0 / 0, x = 0, y = 0 }
	assertTrue(not CaveSession.openChest(session, chestParams(profile, far, bad)).ok)
	assertEquals(profile.cave.chests[tostring(Cave.sliceOf(config, chest.row))], nil)
end)

test("save writes unsaved changes and reports how many slices were written", function()
	local profile = newProfile(150)
	local session = newSession(profile)
	local hit = findCell(session, "rock")
	Cave.mine(session.cave, config, 10, hit.row, hit.x, hit.y, TIME)
	assertEquals(CaveSession.save(session), 1)
	assertEquals(CaveSession.save(session), 0)
end)
