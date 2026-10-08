--!strict
local Framework = require("../Framework")
local Migrations = require("../../src/server/Migrations")
local ProfileData = require("../../src/server/ProfileData")
local TestRules = require("../TestRules")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals
local assertDeepEquals = Framework.assertDeepEquals

local rules = TestRules
local layerIds = rules.layerIds

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
	assertEquals(profile.coins, rules.startCoins)
	assertEquals(profile.depth, rules.startDepth)
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

test("validate rejects bad find ids and a stale next id", function()
	local function find(id: any): any
		return { id = id, findId = "shard", layerId = "sand_clay", rarityId = "common", value = 10 }
	end
	expectInvalid(function(p)
		table.insert(p.backpack.finds, find(nil))
		p.nextFindId = 2
	end, "find")
	expectInvalid(function(p)
		table.insert(p.backpack.finds, find(0))
		p.nextFindId = 2
	end, "find")
	expectInvalid(function(p)
		table.insert(p.backpack.finds, find(1.5))
		p.nextFindId = 3
	end, "find")
	expectInvalid(function(p)
		table.insert(p.backpack.finds, find(1))
		table.insert(p.backpack.finds, find(1))
		p.nextFindId = 2
	end, "duplicate")
	expectInvalid(function(p)
		table.insert(p.backpack.finds, find(5))
		p.nextFindId = 5
	end, "nextFindId")
	expectInvalid(function(p)
		p.nextFindId = 0
	end, "nextFindId")
end)

test("a new profile starts the onboarding and the stats", function()
	local profile = fresh()
	assertEquals(profile.onboarding.step, 1)
	assertEquals(profile.onboarding.firstFindGiven, false)
	assertEquals(profile.stats.blocksDug, 0)
end)

test("validate rejects bad onboarding and stats", function()
	expectInvalid(function(p)
		p.onboarding = nil
	end, "onboarding")
	expectInvalid(function(p)
		p.onboarding.step = 0
	end, "onboarding")
	expectInvalid(function(p)
		p.onboarding.step = rules.onboardingMaxStep + 1
	end, "onboarding")
	expectInvalid(function(p)
		p.onboarding.firstFindGiven = "yes"
	end, "onboarding")
	expectInvalid(function(p)
		p.stats = nil
	end, "stats")
	expectInvalid(function(p)
		p.stats.blocksDug = -1
	end, "blocksDug")
end)

test("migrating a version 2 profile with progress skips the onboarding", function()
	local migrated = ProfileData.migrate(version1Fixture(), Migrations)
	assertTrue(migrated ~= nil)
	if migrated == nil then
		return
	end
	assertEquals(migrated.onboarding.step, rules.onboardingMaxStep)
	assertEquals(migrated.onboarding.firstFindGiven, true)
	assertEquals(migrated.stats.blocksDug, 0)
end)

test("migrating an untouched profile keeps the onboarding at the start", function()
	local fixture = version1Fixture()
	fixture.coins = 0
	fixture.depth = 0
	fixture.backpack = { ores = {}, finds = {} }
	local migrated = ProfileData.migrate(fixture, Migrations)
	assertTrue(migrated ~= nil)
	if migrated == nil then
		return
	end
	assertEquals(migrated.onboarding.step, 1)
	assertEquals(migrated.onboarding.firstFindGiven, false)
end)

test("a new profile has house level 1 and an empty museum", function()
	local profile = fresh()
	assertEquals(profile.house.level, 1)
	assertEquals(#profile.museum.displays, 0)
	assertEquals(profile.museum.incomeSince, 1700000000)
	assertEquals(profile.museum.admires, 0)
	assertEquals(profile.museum.week, 0)
	assertEquals(profile.museum.weekAdmires, 0)
end)

local function display(slot: any, id: any): any
	return { slot = slot, find = { id = id, findId = "shard", layerId = "sand_clay", rarityId = "common", value = 10 } }
end

test("validate accepts displayed finds with unique ids and slots", function()
	local profile: any = fresh()
	table.insert(profile.museum.displays, display(1, 1))
	table.insert(profile.museum.displays, display(4, 2))
	profile.nextFindId = 3
	local ok, reason = ProfileData.validate(profile, rules)
	assertTrue(ok, reason)
end)

test("validate rejects bad house and museum values", function()
	expectInvalid(function(p)
		p.house = nil
	end, "house")
	expectInvalid(function(p)
		p.house.level = 0
	end, "house")
	expectInvalid(function(p)
		p.house.level = #rules.museumSlotsByHouseLevel + 1
	end, "house")
	expectInvalid(function(p)
		p.museum = nil
	end, "museum")
	expectInvalid(function(p)
		p.museum.incomeSince = -1
	end, "incomeSince")
	expectInvalid(function(p)
		p.museum.admires = 1.5
	end, "admires")
	expectInvalid(function(p)
		p.museum.weekAdmires = -1
	end, "weekAdmires")
	expectInvalid(function(p)
		p.museum.week = "x"
	end, "week")
	expectInvalid(function(p)
		p.museum.displays = nil
	end, "displays")
end)

test("validate rejects bad showcases", function()
	expectInvalid(function(p)
		table.insert(p.museum.displays, display(0, 1))
		p.nextFindId = 2
	end, "slot")
	expectInvalid(function(p)
		table.insert(p.museum.displays, display(rules.museumSlotsByHouseLevel[1] + 1, 1))
		p.nextFindId = 2
	end, "slot")
	expectInvalid(function(p)
		table.insert(p.museum.displays, display(1, 1))
		table.insert(p.museum.displays, display(1, 2))
		p.nextFindId = 3
	end, "slot")
	expectInvalid(function(p)
		table.insert(p.museum.displays, display(1, 1))
		table.insert(p.backpack.finds, display(1, 1).find)
		p.nextFindId = 2
	end, "duplicate")
	expectInvalid(function(p)
		table.insert(p.museum.displays, display(1, 5))
		p.nextFindId = 5
	end, "nextFindId")
	expectInvalid(function(p)
		table.insert(p.museum.displays, { slot = 1, find = { id = 1, findId = "shard" } })
		p.nextFindId = 2
	end, "find")
end)

test("migrating adds the house and an empty museum whose income starts at creation", function()
	local migrated = ProfileData.migrate(version1Fixture(), Migrations)
	assertTrue(migrated ~= nil)
	if migrated == nil then
		return
	end
	assertEquals(migrated.house.level, 1)
	assertEquals(#migrated.museum.displays, 0)
	assertEquals(migrated.museum.incomeSince, 1700000000)
	assertEquals(migrated.museum.admires, 0)
	local ok, reason = ProfileData.validate(migrated :: any, rules)
	assertTrue(ok, reason)
end)

test("a new profile has an empty depot, no absence time and digger level 1", function()
	local profile = fresh()
	assertEquals(#profile.depot.finds, 0)
	assertEquals(next(profile.depot.ores), nil)
	assertEquals(profile.digger.leftAt, nil)
	assertEquals(profile.upgradeLevels.digger, 1)
end)

test("validate rejects bad depot and digger values", function()
	expectInvalid(function(p)
		p.depot = nil
	end, "depot")
	expectInvalid(function(p)
		p.depot.ores.coal = -1
	end, "depot")
	expectInvalid(function(p)
		table.insert(p.depot.finds, { id = 1, findId = "shard", layerId = "sand_clay" })
		p.nextFindId = 2
	end, "depot")
	expectInvalid(function(p)
		table.insert(p.depot.finds, display(1, 1).find)
		table.insert(p.backpack.finds, display(1, 1).find)
		p.nextFindId = 2
	end, "duplicate")
	expectInvalid(function(p)
		p.digger = nil
	end, "digger")
	expectInvalid(function(p)
		p.digger.leftAt = -5
	end, "leftAt")
	expectInvalid(function(p)
		p.upgradeLevels.digger = nil
	end, "digger")
end)

test("validate accepts a stored absence time and depot finds", function()
	local profile: any = fresh()
	profile.digger.leftAt = 1700000500
	table.insert(profile.depot.finds, display(1, 1).find)
	profile.nextFindId = 2
	local ok, reason = ProfileData.validate(profile, rules)
	assertTrue(ok, reason)
end)

test("migrating adds the depot, the digger and digger level 1", function()
	local migrated = ProfileData.migrate(version1Fixture(), Migrations)
	assertTrue(migrated ~= nil)
	if migrated == nil then
		return
	end
	assertEquals(#migrated.depot.finds, 0)
	assertEquals(migrated.digger.leftAt, nil)
	assertEquals(migrated.upgradeLevels.digger, 1)
	assertEquals(migrated.upgradeLevels.shovel, 3, "existing levels stay")
	local ok, reason = ProfileData.validate(migrated :: any, rules)
	assertTrue(ok, reason)
end)

test("a new profile has every skill at level 1", function()
	local profile = fresh()
	for _, skillId in { "strong_arms", "ore_finder", "cable_winch", "lamp" } do
		assertEquals(profile.upgradeLevels[skillId], 1)
	end
end)

test("migrating adds the skills at level 1 and keeps the other levels", function()
	local migrated = ProfileData.migrate(version1Fixture(), Migrations)
	assertTrue(migrated ~= nil)
	if migrated == nil then
		return
	end
	for _, skillId in { "strong_arms", "ore_finder", "cable_winch", "lamp" } do
		assertEquals(migrated.upgradeLevels[skillId], 1)
	end
	assertEquals(migrated.upgradeLevels.shovel, 3)
	assertEquals(migrated.upgradeLevels.backpack, 2)
end)

test("a new profile has no quests picked and no login yet", function()
	local profile = fresh()
	assertEquals(profile.quests.day, 0)
	assertEquals(#profile.quests.ids, 0)
	assertEquals(profile.quests.bonusClaimed, false)
	assertEquals(profile.login.lastDay, 0)
	assertEquals(profile.login.streak, 0)
	assertEquals(profile.login.claimed, true)
end)

test("validate accepts picked quests with progress and a running login chain", function()
	local profile: any = fresh()
	profile.quests = {
		day = 19000,
		ids = { "dig_blocks", "sell_trips" },
		progress = { dig_blocks = 20 },
		claimed = { sell_trips = true },
		bonusClaimed = false,
	}
	profile.login = { lastDay = 19000, streak = 3, claimed = false }
	local ok, reason = ProfileData.validate(profile, rules)
	assertTrue(ok, reason)
end)

test("validate rejects bad quests and login values", function()
	expectInvalid(function(p)
		p.quests = nil
	end, "quests")
	expectInvalid(function(p)
		p.quests.day = -1
	end, "quests")
	expectInvalid(function(p)
		p.quests.ids = { 5 }
	end, "quests")
	expectInvalid(function(p)
		p.quests.progress = { dig_blocks = -2 }
	end, "quests")
	expectInvalid(function(p)
		p.quests.progress = { dig_blocks = 1.5 }
	end, "quests")
	expectInvalid(function(p)
		p.quests.claimed = { dig_blocks = "yes" }
	end, "quests")
	expectInvalid(function(p)
		p.quests.bonusClaimed = 1
	end, "quests")
	expectInvalid(function(p)
		p.login = nil
	end, "login")
	expectInvalid(function(p)
		p.login.streak = rules.loginChainLength + 1
	end, "login")
	expectInvalid(function(p)
		p.login.lastDay = -3
	end, "login")
	expectInvalid(function(p)
		p.login.claimed = "no"
	end, "login")
end)

test("migrating adds empty quests and a login chain that has not started", function()
	local migrated = ProfileData.migrate(version1Fixture(), Migrations)
	assertTrue(migrated ~= nil)
	if migrated == nil then
		return
	end
	assertEquals(migrated.quests.day, 0)
	assertEquals(#migrated.quests.ids, 0)
	assertEquals(migrated.login.streak, 0)
	assertEquals(migrated.login.claimed, true)
	local ok, reason = ProfileData.validate(migrated :: any, rules)
	assertTrue(ok, reason)
end)

test("a new profile starts the find ids at 1", function()
	assertEquals(fresh().nextFindId, 1)
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

test("migrating version 1 gives stored finds unique ids and sets the next id", function()
	local migrated = ProfileData.migrate(version1Fixture(), Migrations)
	assertTrue(migrated ~= nil)
	if migrated == nil then
		return
	end
	assertEquals(migrated.backpack.finds[1].id, 1)
	assertEquals(migrated.backpack.finds[2].id, 2)
	assertEquals(migrated.nextFindId, 3)
end)

test("migrating a version 1 profile without finds starts the ids at 1", function()
	local fixture = version1Fixture()
	fixture.backpack.finds = {}
	local migrated = ProfileData.migrate(fixture, Migrations)
	assertTrue(migrated ~= nil)
	if migrated == nil then
		return
	end
	assertEquals(migrated.nextFindId, 1)
	local ok, reason = ProfileData.validate(migrated :: any, rules)
	assertTrue(ok, reason)
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
