--!strict
local BackpackConfig = require("../../src/shared/Config/Backpack")
local DigAction = require("../../src/shared/DigAction")
local DigConfig = require("../../src/shared/Config/Dig")
local OnboardingConfig = require("../../src/shared/Config/Onboarding")
local Framework = require("../Framework")
local ProfileData = require("../../src/server/ProfileData")
local ShovelConfig = require("../../src/shared/Config/Shovel")
local TestConfig = require("../TestConfig")
local TestRules = require("../TestRules")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals
local assertNear = Framework.assertNear
local scriptedRng = Framework.scriptedRng

local rules = TestRules

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
		onboarding = {
			firstFindAfterBlocks = OnboardingConfig.firstFindAfterBlocks,
			firstFindMutation = OnboardingConfig.firstFindMutation,
		},
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

test("a rare find gets the next find id and the counter moves on", function()
	local profile = freshProfile()
	local draws = { 0.0, 0.0, 0.0, 0.99 } -- rare check passes, common find, first find, no mutation
	assertTrue(DigAction.perform(params(profile, scriptedRng(draws))).ok)
	assertTrue(DigAction.perform(params(profile, scriptedRng(draws), 50, 100)).ok)
	assertEquals(profile.backpack.finds[1].id, 1)
	assertEquals(profile.backpack.finds[2].id, 2)
	assertEquals(profile.nextFindId, 3)
end)

test("ore does not use up a find id", function()
	local profile = freshProfile()
	assertTrue(DigAction.perform(params(profile, scriptedRng(ORE_DRAWS))).ok)
	assertEquals(profile.nextFindId, 1)
end)

test("the dig that reaches the configured block count is a guaranteed golden find", function()
	local profile = freshProfile()
	profile.stats.blocksDug = OnboardingConfig.firstFindAfterBlocks - 1
	-- No rare check is drawn; rarity pick and find pick come from the script.
	local result = DigAction.perform(params(profile, scriptedRng({ 0.0, 0.0 })))
	assertTrue(result.ok)
	assertEquals(result.block.kind, "rare")
	assertEquals(result.block.mutationId, OnboardingConfig.firstFindMutation)
	assertEquals(profile.onboarding.firstFindGiven, true)
	assertEquals(profile.stats.blocksDug, OnboardingConfig.firstFindAfterBlocks)
end)

test("the guarantee is given only once", function()
	local profile = freshProfile()
	profile.stats.blocksDug = OnboardingConfig.firstFindAfterBlocks - 1
	profile.onboarding.firstFindGiven = true
	local result = DigAction.perform(params(profile, scriptedRng(ORE_DRAWS)))
	assertEquals(result.block.kind, "ore")
end)

test("no guarantee before the configured block count", function()
	local profile = freshProfile()
	profile.stats.blocksDug = OnboardingConfig.firstFindAfterBlocks - 2
	local result = DigAction.perform(params(profile, scriptedRng(ORE_DRAWS)))
	assertEquals(result.block.kind, "ore")
	assertEquals(profile.onboarding.firstFindGiven, false)
end)

test("a dig counts as dug block and moves the onboarding step", function()
	local profile = freshProfile()
	assertTrue(DigAction.perform(params(profile, scriptedRng(ORE_DRAWS))).ok)
	assertEquals(profile.stats.blocksDug, 1)
	assertEquals(profile.onboarding.step, 2)
	assertTrue(DigAction.perform(params(profile, scriptedRng({ 0.0, 0.0, 0.0, 0.99 }), 50, 100)).ok)
	assertEquals(profile.stats.blocksDug, 2)
	assertEquals(profile.onboarding.step, 3)
end)

test("a rejected dig changes neither the stats nor the onboarding", function()
	local profile = freshProfile()
	DigAction.perform(params(profile, failingRng, 99.9, 100))
	assertEquals(profile.stats.blocksDug, 0)
	assertEquals(profile.onboarding.step, 1)
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

test("snapshot describes depth, layer, backpack, coins and dig cooldown", function()
	local profile = freshProfile()
	profile.depth = 60.5
	profile.coins = 321
	profile.upgradeLevels.shovel = 2
	profile.backpack.ores.iron = 3
	table.insert(profile.backpack.finds, { id = 1, findId = "fossil", layerId = "rock", rarityId = "rare", value = 50 })
	local state = DigAction.snapshot(snapshotParams(profile))
	assertEquals(state.depth, 60.5)
	assertEquals(state.layerId, "rock")
	assertEquals(state.coins, 321)
	assertEquals(state.onboardingStep, 1)
	assertEquals(state.depotUsed, 0)
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

-- Modifiers ----------------------------------------------------------------------

local function modifiers(changes: { [string]: number }): DigAction.DigModifiers
	local result = { luck = 1, rareFindMultiplier = 1, speedMultiplier = 1, capacityMultiplier = 1 }
	for key, value in changes do
		(result :: any)[key] = value
	end
	return result
end

test("a speed multiplier shortens the cooldown", function()
	local profile = freshProfile()
	local gap = 0.4 -- below the level 1 cooldown tolerance, above half of it
	assertEquals(DigAction.perform(params(profile, failingRng, 100 - gap, 100)).reason, "cooldown")
	local fast = params(profile, scriptedRng(ORE_DRAWS), 100 - gap, 100)
	fast.modifiers = modifiers({ speedMultiplier = 2 })
	assertTrue(DigAction.perform(fast).ok)
end)

test("a capacity multiplier makes room for more blocks", function()
	local profile = freshProfile()
	profile.backpack.ores.coal = BackpackConfig.levels[1].capacity
	local boosted = params(profile, scriptedRng(ORE_DRAWS))
	boosted.modifiers = modifiers({ capacityMultiplier = 1.2 })
	local result = DigAction.perform(boosted)
	assertTrue(result.ok, tostring(result.reason))
	assertEquals(result.capacity, math.floor(BackpackConfig.levels[1].capacity * 1.2))
end)

test("a rare find multiplier raises the chance of a rare find", function()
	local draws = { 0.03, 0.0, 0.0, 0.99 } -- 3 percent: no rare find at 2 percent, a rare find at 4
	local plain = freshProfile()
	assertEquals(DigAction.perform(params(plain, scriptedRng({ 0.03, 0.0 }))).block.kind, "ore")
	local boosted = freshProfile()
	local boostedParams = params(boosted, scriptedRng(draws))
	boostedParams.modifiers = modifiers({ rareFindMultiplier = 2 })
	assertEquals(DigAction.perform(boostedParams).block.kind, "rare")
end)

test("luck shifts rare finds towards higher rarities", function()
	local draws = { 0.0, 0.7, 0.0, 0.99 } -- rare find, rarity roll 0.7, first find, no mutation
	local plain = freshProfile()
	assertEquals(DigAction.perform(params(plain, scriptedRng(draws))).block.rarityId, "rare")
	local lucky = freshProfile()
	local luckyParams = params(lucky, scriptedRng(draws))
	luckyParams.modifiers = modifiers({ luck = 10 })
	assertEquals(DigAction.perform(luckyParams).block.rarityId, "epic")
end)

test("the snapshot shows the boosted capacity and cooldown", function()
	local profile = freshProfile()
	local snapshot = snapshotParams(profile)
	snapshot.modifiers = modifiers({ speedMultiplier = 2, capacityMultiplier = 2 })
	local state = DigAction.snapshot(snapshot)
	assertEquals(state.capacity, BackpackConfig.levels[1].capacity * 2)
	assertNear(state.digCooldown, ShovelConfig.levels[1].digCooldown / 2, 1e-9)
end)

test("the snapshot counts the items in the depot", function()
	local profile = freshProfile()
	profile.depot.ores.coal = 7
	table.insert(
		profile.depot.finds,
		{ id = 1, findId = "shard", layerId = "sand_clay", rarityId = "common", value = 10 }
	)
	profile.nextFindId = 2
	assertEquals(DigAction.snapshot(snapshotParams(profile)).depotUsed, 8)
end)
