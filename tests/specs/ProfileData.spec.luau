--!strict
local BackpackConfig = require("../../src/shared/Config/Backpack")
local Framework = require("../Framework")
local Layers = require("../../src/shared/Config/Layers")
local Migrations = require("../../src/server/Migrations")
local ProfileConfig = require("../../src/shared/Config/Profile")
local ProfileData = require("../../src/server/ProfileData")
local ShovelConfig = require("../../src/shared/Config/Shovel")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals
local assertDeepEquals = Framework.assertDeepEquals

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

local function fresh(): ProfileData.Profile
	return ProfileData.new(rules, Framework.seededRng(1), 1700000000)
end

-- Frozen copy of a version 1 profile as it was stored. If the format changes,
-- add a migration; this fixture must keep migrating and validating.
local function version1Fixture(): { [string]: any }
	return {
		version = 1,
		createdAt = 1700000000,
		coins = 250,
		upgradeLevels = { shovel = 3, backpack = 2 },
		depth = 120.5,
		layerSeeds = { sand_clay = 111, rock = 222, crystal = 333 },
		backpack = {
			ores = { coal = 4, iron = 2 },
			finds = {
				{ findId = "fossil", layerId = "rock", rarityId = "epic", mutationId = "golden", value = 2500 },
				{ findId = "shard", layerId = "sand_clay", rarityId = "common", value = 10 },
			},
		},
	}
end

-- Creating profiles --------------------------------------------------------

test("a new profile has the starting values and is valid", function()
	local profile = fresh()
	assertEquals(profile.version, rules.version)
	assertEquals(profile.createdAt, 1700000000)
	assertEquals(profile.coins, ProfileConfig.startCoins)
	assertEquals(profile.depth, ProfileConfig.startDepth)
	assertEquals(profile.upgradeLevels.shovel, 1)
	assertEquals(profile.upgradeLevels.backpack, 1)
	assertEquals(next(profile.backpack.ores), nil)
	assertEquals(#profile.backpack.finds, 0)
	local ok, reason = ProfileData.validate(profile, rules)
	assertTrue(ok, reason)
end)

test("a new profile gets one integer seed per layer, different per layer", function()
	local profile = fresh()
	local seen: { [number]: boolean } = {}
	for _, layerId in layerIds do
		local seed = profile.layerSeeds[layerId]
		assertTrue(seed ~= nil and seed >= 1 and seed % 1 == 0, "bad seed for " .. layerId)
		assertTrue(not seen[seed], "duplicate seed")
		seen[seed] = true
	end
end)

test("different rng streams give different seeds", function()
	local a = ProfileData.new(rules, Framework.seededRng(1), 0)
	local b = ProfileData.new(rules, Framework.seededRng(2), 0)
	assertTrue(a.layerSeeds[layerIds[1]] ~= b.layerSeeds[layerIds[1]])
end)

-- Validation ---------------------------------------------------------------

local function expectInvalid(mutate: (profile: any) -> (), fragment: string)
	local profile: any = fresh()
	mutate(profile)
	local ok, reason = ProfileData.validate(profile, rules)
	assertEquals(ok, false, "expected invalid: " .. fragment)
	assertTrue(reason ~= nil and string.find(reason, fragment, 1, true) ~= nil, "reason was: " .. tostring(reason))
end

test("validate rejects bad coins", function()
	expectInvalid(function(p)
		p.coins = -1
	end, "coins")
	expectInvalid(function(p)
		p.coins = 1.5
	end, "coins")
	expectInvalid(function(p)
		p.coins = 0 / 0
	end, "coins")
	expectInvalid(function(p)
		p.coins = "100"
	end, "coins")
end)

test("validate rejects bad depth", function()
	expectInvalid(function(p)
		p.depth = -0.5
	end, "depth")
	expectInvalid(function(p)
		p.depth = math.huge
	end, "depth")
	expectInvalid(function(p)
		p.depth = 0 / 0
	end, "depth")
end)

test("validate rejects bad upgrade levels", function()
	expectInvalid(function(p)
		p.upgradeLevels.shovel = 0
	end, "shovel")
	expectInvalid(function(p)
		p.upgradeLevels.shovel = rules.levelCounts.shovel + 1
	end, "shovel")
	expectInvalid(function(p)
		p.upgradeLevels.backpack = 1.5
	end, "backpack")
	expectInvalid(function(p)
		p.upgradeLevels.backpack = nil
	end, "backpack")
	expectInvalid(function(p)
		p.upgradeLevels = nil
	end, "upgradeLevels")
end)

test("validate rejects bad layer seeds", function()
	expectInvalid(function(p)
		p.layerSeeds[layerIds[1]] = nil
	end, layerIds[1])
	expectInvalid(function(p)
		p.layerSeeds[layerIds[2]] = 1.5
	end, layerIds[2])
	expectInvalid(function(p)
		p.layerSeeds[layerIds[2]] = 0
	end, layerIds[2])
end)

test("validate rejects bad backpack contents", function()
	expectInvalid(function(p)
		p.backpack.ores.coal = -1
	end, "coal")
	expectInvalid(function(p)
		p.backpack.ores.coal = 1.5
	end, "coal")
	expectInvalid(function(p)
		p.backpack = nil
	end, "backpack")
	expectInvalid(function(p)
		table.insert(p.backpack.finds, { findId = "shard", layerId = "sand_clay", rarityId = "common" })
	end, "find")
	expectInvalid(function(p)
		table.insert(p.backpack.finds, { findId = "shard", layerId = "sand_clay", rarityId = "common", value = -5 })
	end, "find")
	expectInvalid(function(p)
		table.insert(
			p.backpack.finds,
			{ findId = "shard", layerId = "sand_clay", rarityId = "common", mutationId = 5, value = 10 }
		)
	end, "find")
end)

test("validate rejects a wrong version and a bad creation time", function()
	expectInvalid(function(p)
		p.version = rules.version + 1
	end, "version")
	expectInvalid(function(p)
		p.createdAt = -1
	end, "createdAt")
end)

test("validate rejects values that cannot be stored (functions, nested junk)", function()
	expectInvalid(function(p)
		p.backpack.ores.coal = function() end
	end, "coal")
end)

-- Migration ----------------------------------------------------------------

local function twoStepMigrations(): { ProfileData.Migration }
	return {
		function(data)
			data.nickname = "miner"
			return data
		end,
		function(data)
			data.nickname = string.upper(data.nickname)
			data.extra = 1
			return data
		end,
	}
end

test("currentVersion is the number of migrations plus one", function()
	assertEquals(ProfileData.currentVersion({}), 1)
	assertEquals(ProfileData.currentVersion(twoStepMigrations()), 3)
	assertEquals(ProfileData.currentVersion(Migrations), #Migrations + 1)
end)

test("the frozen version 1 profile migrates to the current version and validates", function()
	local migrated, reason = ProfileData.migrate(version1Fixture(), Migrations)
	assertTrue(migrated ~= nil, reason)
	if migrated == nil then
		return
	end
	local ok, validationReason = ProfileData.validate(migrated :: any, rules)
	assertTrue(ok, validationReason)
	assertEquals(migrated.coins, 250)
	assertEquals(migrated.upgradeLevels.shovel, 3)
	assertEquals(migrated.backpack.finds[1].value, 2500)
end)

test("migrate applies every step from the stored version up", function()
	local migrations = twoStepMigrations()
	local fromV1, reason = ProfileData.migrate({ version = 1 }, migrations)
	assertTrue(fromV1 ~= nil, reason)
	assertDeepEquals(fromV1, { version = 3, nickname = "MINER", extra = 1 })

	local fromV2 = ProfileData.migrate({ version = 2, nickname = "abc" }, migrations)
	assertDeepEquals(fromV2, { version = 3, nickname = "ABC", extra = 1 })

	local alreadyCurrent = ProfileData.migrate({ version = 3, nickname = "X" }, migrations)
	assertDeepEquals(alreadyCurrent, { version = 3, nickname = "X" })
end)

test("migrate does not modify its input", function()
	local input = { version = 1 }
	local copy = { version = 1 }
	ProfileData.migrate(input, twoStepMigrations())
	assertDeepEquals(input, copy)
end)

test("migrate rejects missing, invalid and newer versions", function()
	local function expectFailure(data: any, fragment: string)
		local migrated, reason = ProfileData.migrate(data, twoStepMigrations())
		assertEquals(migrated, nil)
		assertTrue(reason ~= nil and string.find(reason, fragment, 1, true) ~= nil, "reason was: " .. tostring(reason))
	end
	expectFailure({}, "version")
	expectFailure({ version = 0 }, "version")
	expectFailure({ version = 1.5 }, "version")
	expectFailure({ version = "1" }, "version")
	expectFailure({ version = 0 / 0 }, "version")
	expectFailure({ version = 4 }, "newer")
	expectFailure("not a table", "table")
end)

test("a failing migration returns nil with the reason and leaves the input intact", function()
	local migrations: { ProfileData.Migration } = {
		function(_data)
			error("boom")
		end,
	}
	local input = { version = 1, coins = 5 }
	local migrated, reason = ProfileData.migrate(input, migrations)
	assertEquals(migrated, nil)
	assertTrue(reason ~= nil and string.find(reason, "boom", 1, true) ~= nil, "reason was: " .. tostring(reason))
	assertDeepEquals(input, { version = 1, coins = 5 })
end)

test("a migration that returns a non-table fails cleanly", function()
	local migrations: { ProfileData.Migration } = {
		function(_data)
			return nil :: any
		end,
	}
	local migrated, reason = ProfileData.migrate({ version = 1 }, migrations)
	assertEquals(migrated, nil)
	assertTrue(reason ~= nil)
end)
