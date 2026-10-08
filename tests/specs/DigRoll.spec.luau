--!strict
local Framework = require("../Framework")
local DigRoll = require("../../src/shared/DigRoll")
local TestConfig = require("../TestConfig")
local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals
local assertNear = Framework.assertNear
local assertErrors = Framework.assertErrors
local scriptedRng = Framework.scriptedRng

local config: DigRoll.Config = TestConfig

local function copyConfig(): DigRoll.Config
	local copy = table.clone(config)
	copy.rarities = table.clone(config.rarities)
	copy.mutations = table.clone(config.mutations)
	copy.layers = table.clone(config.layers)
	return copy
end

local function chanceOf(chances: { DigRoll.RarityChance }, rarityId: string): number
	for _, entry in chances do
		if entry.rarityId == rarityId then
			return entry.percent
		end
	end
	error("rarity not found: " .. rarityId)
end

local function sumOf(chances: { DigRoll.RarityChance }): number
	local sum = 0
	for _, entry in chances do
		sum += entry.percent
	end
	return sum
end

-- Config ---------------------------------------------------------------

test("shipped config is valid", function()
	local ok, reason = DigRoll.validateConfig(config)
	assertTrue(ok, reason)
end)

test("validateConfig rejects rarity chances that do not sum to 100", function()
	local bad = copyConfig()
	bad.rarities = {
		{ id = "common", chance = 60, minValue = 10 },
		{ id = "rare", chance = 30, minValue = 50 },
	}
	local ok, reason = DigRoll.validateConfig(bad)
	assertEquals(ok, false)
	assertTrue(reason ~= nil and string.find(reason, "100", 1, true) ~= nil, "reason should mention 100")
end)

test("validateConfig rejects layers with a gap", function()
	local bad = copyConfig()
	bad.layers = {
		{ id = "a", minDepth = 0, maxDepth = 50, ores = { "coal" }, finds = { "shard" } },
		{ id = "b", minDepth = 60, maxDepth = 100, ores = { "iron" }, finds = { "fossil" } },
	}
	local ok = DigRoll.validateConfig(bad)
	assertEquals(ok, false)
end)

test("validateConfig rejects a mutation multiplier below 1", function()
	local bad = copyConfig()
	bad.mutations = { { id = "weak", multiplier = 0.5, weight = 1 } }
	local ok = DigRoll.validateConfig(bad)
	assertEquals(ok, false)
end)

test("validateConfig rejects a layer without ores", function()
	local bad = copyConfig()
	bad.layers = { { id = "empty", minDepth = 0, maxDepth = 50, ores = {}, finds = { "shard" } } }
	local ok = DigRoll.validateConfig(bad)
	assertEquals(ok, false)
end)

-- Layers ---------------------------------------------------------------

test("getLayer picks the layer by depth and respects boundaries", function()
	assertEquals(DigRoll.getLayer(config, 0).id, "sand_clay")
	assertEquals(DigRoll.getLayer(config, 49.9).id, "sand_clay")
	assertEquals(DigRoll.getLayer(config, 50).id, "rock")
	assertEquals(DigRoll.getLayer(config, 149.9).id, "rock")
	assertEquals(DigRoll.getLayer(config, 150).id, "crystal")
	assertEquals(DigRoll.getLayer(config, 299.9).id, "crystal")
end)

test("getLayer clamps depths outside the configured range", function()
	assertEquals(DigRoll.getLayer(config, -5).id, "sand_clay")
	assertEquals(DigRoll.getLayer(config, 10000).id, "crystal")
end)

test("getLayer rejects invalid depth values", function()
	assertErrors(function()
		DigRoll.getLayer(config, 0 / 0)
	end, "depth")
end)

-- Chances (info window) ------------------------------------------------

test("rarity chances equal the configured percentages at luck 1", function()
	local chances = DigRoll.getRarityChances(config, 1)
	assertNear(chanceOf(chances, "common"), 60, 1e-9)
	assertNear(chanceOf(chances, "rare"), 25, 1e-9)
	assertNear(chanceOf(chances, "epic"), 10, 1e-9)
	assertNear(chanceOf(chances, "legendary"), 4, 1e-9)
	assertNear(chanceOf(chances, "mythic"), 1, 1e-9)
end)

test("rarity chances always sum to 100", function()
	for _, luck in { 1, 1.5, 3, 7.25, config.maxLuck } do
		assertNear(sumOf(DigRoll.getRarityChances(config, luck)), 100, 1e-9, "luck " .. tostring(luck))
	end
end)

test("luck lowers the common chance and raises every higher rarity", function()
	local base = DigRoll.getRarityChances(config, 1)
	local lucky = DigRoll.getRarityChances(config, 3)
	assertTrue(chanceOf(lucky, "common") < chanceOf(base, "common"))
	for _, rarityId in { "rare", "epic", "legendary", "mythic" } do
		assertTrue(chanceOf(lucky, rarityId) > chanceOf(base, rarityId), rarityId)
	end
end)

test("luck is clamped to the configured range", function()
	local atMax = DigRoll.getRarityChances(config, config.maxLuck)
	local beyond = DigRoll.getRarityChances(config, config.maxLuck * 100)
	assertNear(chanceOf(beyond, "mythic"), chanceOf(atMax, "mythic"), 1e-9)

	local base = DigRoll.getRarityChances(config, 1)
	local below = DigRoll.getRarityChances(config, 0.1)
	assertNear(chanceOf(below, "mythic"), chanceOf(base, "mythic"), 1e-9)

	local nan = DigRoll.getRarityChances(config, 0 / 0)
	assertNear(chanceOf(nan, "mythic"), chanceOf(base, "mythic"), 1e-9)
end)

test("mutation chance scales with luck and never exceeds 100", function()
	assertNear(DigRoll.getMutationChance(config, 1), config.mutationChance, 1e-9)
	assertNear(DigRoll.getMutationChance(config, 2), config.mutationChance * 2, 1e-9)
	assertTrue(DigRoll.getMutationChance(config, config.maxLuck) <= 100)
end)

-- Single rolls ---------------------------------------------------------

test("a normal block yields ore from the current layer", function()
	-- draw 1: rare check (50 >= 2 -> no rare); draw 2: ore index
	local result = DigRoll.rollBlock(config, scriptedRng({ 0.5, 0.0 }), { depth = 10 })
	assertEquals(result.kind, "ore")
	assertEquals(result.layerId, "sand_clay")
	assertEquals(result.oreId, config.layers[1].ores[1])

	local second = DigRoll.rollBlock(config, scriptedRng({ 0.5, 0.999999 }), { depth = 10 })
	assertEquals(second.oreId, config.layers[1].ores[#config.layers[1].ores])
end)

test("a rare find rolls rarity, find and mutation in that order", function()
	-- draws: rare check, rarity, find, mutation check (no mutation)
	local result = DigRoll.rollBlock(config, scriptedRng({ 0.0, 0.0, 0.0, 0.99 }), { depth = 60 })
	assertEquals(result.kind, "rare")
	assertEquals(result.layerId, "rock")
	assertEquals(result.rarityId, "common")
	assertEquals(result.findId, config.layers[2].finds[1])
	assertEquals(result.mutationId, nil)
	assertEquals(result.value, 10)
end)

test("the highest rarity is reachable with a roll near 1", function()
	local result = DigRoll.rollBlock(config, scriptedRng({ 0.0, 0.999999, 0.0, 0.99 }), { depth = 60 })
	assertEquals(result.rarityId, "mythic")
	assertEquals(result.value, 20000)
end)

test("a mutation multiplies the value", function()
	-- mutation check 0.01 -> 1% < 5% -> mutated; pick roll 0 -> first mutation
	local result = DigRoll.rollBlock(config, scriptedRng({ 0.0, 0.0, 0.0, 0.01, 0.0 }), { depth = 60 })
	local first = config.mutations[1]
	assertEquals(result.mutationId, first.id)
	assertEquals(result.value, 10 * first.multiplier)
end)

test("rare find chance boundary: below hits, at the chance misses", function()
	local hit = DigRoll.rollBlock(config, scriptedRng({ 0.0199, 0.0, 0.0, 0.99 }), { depth = 10 })
	assertEquals(hit.kind, "rare")
	local miss = DigRoll.rollBlock(config, scriptedRng({ 0.02, 0.0 }), { depth = 10 })
	assertEquals(miss.kind, "ore")
end)

test("rareFindBonus raises the rare find chance and is clamped", function()
	-- 0.05 is a miss at bonus 1 (chance 2%) but a hit at bonus 3 (chance 6%)
	local missing = DigRoll.rollBlock(config, scriptedRng({ 0.05, 0.0 }), { depth = 10 })
	assertEquals(missing.kind, "ore")
	local hitting = DigRoll.rollBlock(config, scriptedRng({ 0.05, 0.0, 0.0, 0.99 }), { depth = 10, rareFindBonus = 3 })
	assertEquals(hitting.kind, "rare")

	assertNear(DigRoll.getRareFindChance(config, 1), config.rareFindChance, 1e-9)
	assertNear(DigRoll.getRareFindChance(config, 1000), config.rareFindChance * config.maxRareFindBonus, 1e-9)
end)

test("guaranteedRare skips the rare check", function()
	-- no draw for the rare check: rarity, find, mutation check
	local result = DigRoll.rollBlock(config, scriptedRng({ 0.0, 0.0, 0.99 }), { depth = 10, guaranteedRare = true })
	assertEquals(result.kind, "rare")
end)

test("guaranteedMutation forces the given mutation (onboarding find)", function()
	local result = DigRoll.rollBlock(config, scriptedRng({ 0.0, 0.0 }), {
		depth = 10,
		guaranteedRare = true,
		guaranteedMutation = "golden",
	})
	assertEquals(result.kind, "rare")
	assertEquals(result.mutationId, "golden")
	local golden
	for _, mutation in config.mutations do
		if mutation.id == "golden" then
			golden = mutation
		end
	end
	assertTrue(golden ~= nil, "golden mutation must exist in config")
	assertEquals(result.value, 10 * golden.multiplier)
end)

test("guaranteedMutation with an unknown id raises an error", function()
	assertErrors(function()
		DigRoll.rollBlock(config, scriptedRng({ 0.0, 0.0 }), {
			depth = 10,
			guaranteedRare = true,
			guaranteedMutation = "does_not_exist",
		})
	end, "does_not_exist")
end)

test("rollBlock rejects a roll outside [0, 1)", function()
	assertErrors(function()
		DigRoll.rollBlock(config, scriptedRng({ 1.5 }), { depth = 10 })
	end, "rng")
end)

test("rare finds only come from the current layer", function()
	local rng = Framework.seededRng(7)
	for _, layer in config.layers do
		local depth = layer.minDepth + 1
		local allowed: { [string]: boolean } = {}
		for _, findId in layer.finds do
			allowed[findId] = true
		end
		for _ = 1, 500 do
			local result = DigRoll.rollBlock(config, rng, { depth = depth, guaranteedRare = true })
			assertEquals(result.kind, "rare")
			assertTrue(allowed[result.findId or ""] == true, "find from wrong layer: " .. tostring(result.findId))
		end
	end
end)

-- Distribution ---------------------------------------------------------

test("rolls match the configured probabilities over many blocks", function()
	local rng = Framework.seededRng(12345)
	local total = 200000
	local rareCount = 0
	local mutatedCount = 0
	local rarityCounts: { [string]: number } = {}

	for _ = 1, total do
		local result = DigRoll.rollBlock(config, rng, { depth = 100 })
		if result.kind == "rare" then
			rareCount += 1
			rarityCounts[result.rarityId or ""] = (rarityCounts[result.rarityId or ""] or 0) + 1
			if result.mutationId ~= nil then
				mutatedCount += 1
			end
		end
	end

	assertNear(rareCount / total * 100, config.rareFindChance, 0.15, "rare find share")
	assertNear(mutatedCount / rareCount * 100, config.mutationChance, 1.2, "mutation share")
	for _, rarity in config.rarities do
		local share = (rarityCounts[rarity.id] or 0) / rareCount * 100
		assertNear(share, rarity.chance, math.max(1.0, rarity.chance * 0.25), "share of " .. rarity.id)
	end
end)

test("higher luck produces more high-rarity finds", function()
	local function mythicShare(luck: number): number
		local rng = Framework.seededRng(99)
		local mythic = 0
		local rare = 0
		for _ = 1, 50000 do
			local result = DigRoll.rollBlock(config, rng, { depth = 100, guaranteedRare = true, luck = luck })
			rare += 1
			if result.rarityId == "mythic" then
				mythic += 1
			end
		end
		return mythic / rare
	end
	-- luck 3: weights 60/75/30/12/3 -> mythic 1.67% instead of 1%
	assertNear(mythicShare(3) / mythicShare(1), 5 / 3, 0.3, "mythic ratio at luck 3")
end)

test("an event boost makes one mutation more likely and leaves the draw order alone", function()
	local boost = { id = "glowing", factor = 4 }
	-- weights 40/30/20/10 become 160/30/20/10: glowing owns 160 of 220
	local shares = DigRoll.getMutationShares(config, boost)
	local total = 0
	for _, share in shares do
		total += share.percent
	end
	assertNear(total, 100, 1e-9)
	assertNear(shares[1].percent, 160 / 220 * 100, 1e-9)
	assertNear(shares[4].percent, 10 / 220 * 100, 1e-9)

	-- rare check, rarity, find, mutation check, mutation pick
	local function mutationWith(pick: number, params: { [string]: any }): string?
		local block = DigRoll.rollBlock(config, scriptedRng({ 0, 0, 0, 0, pick }), {
			depth = 0,
			mutationBoost = params.mutationBoost,
		})
		return block.mutationId
	end
	-- 0.7 lands on icy without the boost (40 + 30 > 70), on glowing with it (160 of 220).
	assertEquals(mutationWith(0.45, {}), "icy")
	assertEquals(mutationWith(0.45, { mutationBoost = boost }), "glowing")
end)

test("an invalid event boost is ignored", function()
	local plain = DigRoll.getMutationShares(config, nil)
	for _, boost in
		{ { id = "glowing", factor = 0.5 }, { id = "ghost", factor = 5 }, { id = "glowing", factor = 0 / 0 } }
	do
		local shares = DigRoll.getMutationShares(config, boost)
		for index, share in shares do
			assertNear(share.percent, plain[index].percent, 1e-9)
		end
	end
end)
