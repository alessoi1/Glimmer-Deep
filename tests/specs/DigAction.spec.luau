--!strict
local BackpackConfig = require("../../src/shared/Config/Backpack")
local DigAction = require("../../src/shared/DigAction")
local DigConfig = require("../../src/shared/Config/Dig")
local Framework = require("../Framework")
local Layers = require("../../src/shared/Config/Layers")
local Migrations = require("../../src/server/Migrations")
local ProfileConfig = require("../../src/shared/Config/Profile")
local ProfileData = require("../../src/server/ProfileData")
local ShovelConfig = require("../../src/shared/Config/Shovel")
local TestConfig = require("../TestConfig")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals
local assertNear = Framework.assertNear
local scriptedRng = Framework.scriptedRng

local layerIds = {}
for _, layer in Layers do
	table.insert(layerIds, layer.id)
end

local rules: ProfileData.Rules = {
	version = ProfileData.currentVersion(Migrations),
	startCoins = ProfileConfig.startCoins,
	startDepth = ProfileConfig.startDepth,
	levelCounts = { shovel = #ShovelConfig.levels, backpack = #BackpackConfig.levels },
	layerIds = layerIds,
}

local function freshProfile(): ProfileData.Profile
	return ProfileData.new(rules, Framework.seededRng(1), 1700000000)
end

local function failingRng(): number
	error("rng must not be used")
end

local function params(profile: ProfileData.Profile, rng: DigAction.Rng, lastDigAt: number?, now: number?)
	return {
		profile = profile,
		digConfig = TestConfig,
		shovelLevels = ShovelConfig.levels,
		cooldownTolerance = ShovelConfig.cooldownTolerance,
		backpackLevels = BackpackConfig.levels,
		metersPerBlock = DigConfig.metersPerBlock,
		lastDigAt = lastDigAt,
		now = now or 100,
		rng = rng,
	} :: DigAction.Params
end

-- A draw of 0.99 fails the rare check (2 %), then 0.0 picks the first ore.
local ORE_DRAWS = { 0.99, 0.0 }

test("a dig puts the ore into the backpack and adds depth", function()
	local profile = freshProfile()
	local result = DigAction.perform(params(profile, scriptedRng(ORE_DRAWS)))
	assertTrue(result.ok, tostring(result.reason))
	assertEquals(result.block ~= nil and result.block.kind, "ore")
	assertEquals(profile.backpack.ores.coal, 1)
	assertNear(profile.depth, DigConfig.metersPerBlock, 1e-9)
	assertNear(result.depth, profile.depth, 1e-9)
	assertEquals(result.used, 1)
	assertEquals(result.capacity, BackpackConfig.levels[1].capacity)
end)

test("a rare find is stored with its value in the finds list", function()
	local profile = freshProfile()
	-- rare check, rarity (common), find (first), mutation check (no mutation)
	local result = DigAction.perform(params(profile, scriptedRng({ 0.0, 0.0, 0.0, 0.99 })))
	assertTrue(result.ok, tostring(result.reason))
	assertEquals(#profile.backpack.finds, 1)
	assertEquals(profile.backpack.finds[1].rarityId, "common")
	assertEquals(profile.backpack.finds[1].value, 10)
	assertEquals(next(profile.backpack.ores), nil)
end)

test("the layer comes from the stored depth", function()
	local profile = freshProfile()
	profile.depth = 60
	local result = DigAction.perform(params(profile, scriptedRng(ORE_DRAWS)))
	assertTrue(result.ok, tostring(result.reason))
	assertEquals(result.block ~= nil and result.block.layerId, "rock")
	assertEquals(profile.backpack.ores.iron, 1)
end)

test("a dig inside the cooldown is rejected and changes nothing", function()
	local profile = freshProfile()
	local result = DigAction.perform(params(profile, failingRng, 99.9, 100))
	assertTrue(not result.ok)
	assertEquals(result.reason, "cooldown")
	assertEquals(result.block, nil)
	assertEquals(profile.depth, 0)
	assertEquals(next(profile.backpack.ores), nil)
end)

test("a dig after the cooldown is accepted", function()
	local profile = freshProfile()
	local result = DigAction.perform(params(profile, scriptedRng(ORE_DRAWS), 99.0, 100))
	assertTrue(result.ok, tostring(result.reason))
end)

test("a better shovel digs faster", function()
	local slow = freshProfile()
	local fast = freshProfile()
	fast.upgradeLevels.shovel = #ShovelConfig.levels
	local gap = 0.2 -- below the level 1 cooldown, above the last level's
	assertEquals(DigAction.perform(params(slow, failingRng, 100 - gap, 100)).reason, "cooldown")
	assertTrue(DigAction.perform(params(fast, scriptedRng(ORE_DRAWS), 100 - gap, 100)).ok)
end)

test("a full backpack rejects the dig without rolling or adding depth", function()
	local profile = freshProfile()
	profile.backpack.ores.coal = BackpackConfig.levels[1].capacity
	local result = DigAction.perform(params(profile, failingRng))
	assertTrue(not result.ok)
	assertEquals(result.reason, "backpack_full")
	assertEquals(profile.depth, 0)
	assertEquals(profile.backpack.ores.coal, BackpackConfig.levels[1].capacity)
	assertEquals(result.used, BackpackConfig.levels[1].capacity)
end)

test("a bigger backpack level holds more blocks", function()
	local profile = freshProfile()
	profile.upgradeLevels.backpack = 2
	profile.backpack.ores.coal = BackpackConfig.levels[1].capacity
	local result = DigAction.perform(params(profile, scriptedRng(ORE_DRAWS)))
	assertTrue(result.ok, tostring(result.reason))
	assertEquals(result.capacity, BackpackConfig.levels[2].capacity)
end)

test("digging until the backpack is full keeps the profile valid", function()
	local profile = freshProfile()
	local rng = Framework.seededRng(42)
	local digs = 0
	local now = 0
	while true do
		now += 10
		local result = DigAction.perform(params(profile, rng, now - 10, now))
		if not result.ok then
			assertEquals(result.reason, "backpack_full")
			break
		end
		digs += 1
		assertTrue(digs <= BackpackConfig.levels[1].capacity, "dug more blocks than the backpack holds")
	end
	assertEquals(digs, BackpackConfig.levels[1].capacity)
	assertNear(profile.depth, digs * DigConfig.metersPerBlock, 1e-9)
	local ok, reason = ProfileData.validate(profile, rules)
	assertTrue(ok, reason)
end)

-- Snapshot ---------------------------------------------------------------------

local function snapshotParams(profile: ProfileData.Profile): DigAction.SnapshotParams
	return {
		profile = profile,
		digConfig = TestConfig,
		shovelLevels = ShovelConfig.levels,
		backpackLevels = BackpackConfig.levels,
	}
end

test("snapshot describes depth, layer, backpack and dig cooldown", function()
	local profile = freshProfile()
	profile.depth = 60.5
	profile.upgradeLevels.shovel = 2
	profile.backpack.ores.iron = 3
	table.insert(profile.backpack.finds, { findId = "fossil", layerId = "rock", rarityId = "rare", value = 50 })
	local state = DigAction.snapshot(snapshotParams(profile))
	assertEquals(state.depth, 60.5)
	assertEquals(state.layerId, "rock")
	assertEquals(state.used, 4)
	assertEquals(state.capacity, BackpackConfig.levels[1].capacity)
	assertEquals(state.digCooldown, ShovelConfig.levels[2].digCooldown)
end)

test("snapshot does not change the profile", function()
	local profile = freshProfile()
	DigAction.snapshot(snapshotParams(profile))
	assertEquals(profile.depth, 0)
	assertEquals(next(profile.backpack.ores), nil)
end)
