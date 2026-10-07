--!strict
local BackpackConfig = require("../../src/shared/Config/Backpack")
local DataLogic = require("../../src/server/DataLogic")
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

local NOW = 1700000000

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

local function prepare(raw: any, useRules: ProfileData.Rules?, migrations: { ProfileData.Migration }?)
	return DataLogic.prepare(raw, useRules or rules, migrations or Migrations, Framework.seededRng(7), NOW)
end

local function validProfile(): { [string]: any }
	return {
		version = rules.version,
		createdAt = NOW - 100,
		coins = 40,
		upgradeLevels = { shovel = 2, backpack = 1 },
		depth = 12.5,
		layerSeeds = { sand_clay = 1, rock = 2, crystal = 3 },
		backpack = { ores = { coal = 2 }, finds = {} },
	}
end

-- Profile keys ---------------------------------------------------------------

test("profileKey builds a stable key from a positive integer user id", function()
	assertEquals(DataLogic.profileKey(12345), "Player_12345")
end)

test("profileKey rejects ids that are not positive integers", function()
	assertEquals(DataLogic.profileKey(0), nil)
	assertEquals(DataLogic.profileKey(-3), nil)
	assertEquals(DataLogic.profileKey(1.5), nil)
	assertEquals(DataLogic.profileKey(math.huge), nil)
	assertEquals(DataLogic.profileKey(0 / 0), nil)
	assertEquals(DataLogic.profileKey("5" :: any), nil)
end)

-- Preparing loaded data --------------------------------------------------------

test("empty stored data becomes a new valid profile", function()
	local outcome = prepare({})
	assertEquals(outcome.status, "new")
	assertTrue(outcome.data ~= nil, "data missing")
	local ok, reason = ProfileData.validate(outcome.data, rules)
	assertTrue(ok, reason)
	assertEquals((outcome.data :: any).createdAt, NOW)
end)

test("a valid current profile is loaded unchanged", function()
	local raw = validProfile()
	local outcome = prepare(raw)
	assertEquals(outcome.status, "loaded")
	assertDeepEquals(outcome.data, validProfile())
end)

test("an older profile is migrated and validated", function()
	local migrations: { ProfileData.Migration } = {
		function(data)
			data.coins = data.coins + 1000
			return data
		end,
	}
	local newRules: ProfileData.Rules = table.clone(rules)
	newRules.version = 2
	local raw = validProfile()
	raw.version = 1
	local outcome = prepare(raw, newRules, migrations)
	assertEquals(outcome.status, "migrated")
	assertEquals((outcome.data :: any).version, 2)
	assertEquals((outcome.data :: any).coins, 1040)
	assertEquals(raw.version, 1, "input must stay untouched")
end)

test("a profile from a newer version is rejected and never replaced", function()
	local raw = validProfile()
	raw.version = rules.version + 1
	local outcome = prepare(raw)
	assertEquals(outcome.status, "rejected")
	assertEquals(outcome.data, nil)
	assertTrue(outcome.reason ~= nil and string.find(outcome.reason, "newer") ~= nil, "reason should mention newer")
end)

test("a profile with invalid values is rejected with the reason", function()
	local raw = validProfile()
	raw.coins = -5
	local outcome = prepare(raw)
	assertEquals(outcome.status, "rejected")
	assertEquals(outcome.data, nil)
	assertTrue(outcome.reason ~= nil and string.find(outcome.reason, "coins") ~= nil, "reason should mention coins")
end)

test("stored data without a version is rejected, not treated as new", function()
	local raw = validProfile()
	raw.version = nil
	local outcome = prepare(raw)
	assertEquals(outcome.status, "rejected")
end)

test("a non-table value is rejected", function()
	assertEquals(prepare(nil).status, "rejected")
	assertEquals(prepare("data").status, "rejected")
end)

test("a migration that produces invalid data is rejected", function()
	local migrations: { ProfileData.Migration } = {
		function(data)
			data.coins = "many"
			return data
		end,
	}
	local newRules: ProfileData.Rules = table.clone(rules)
	newRules.version = 2
	local raw = validProfile()
	raw.version = 1
	local outcome = prepare(raw, newRules, migrations)
	assertEquals(outcome.status, "rejected")
	assertEquals(outcome.data, nil)
end)

-- Replacing contents in place ----------------------------------------------------

test("replaceContents swaps the contents but keeps the same table", function()
	local target: { [string]: any } = { old = 1, shared = "a" }
	local same = target
	DataLogic.replaceContents(target, { shared = "b", extra = { 1, 2 } })
	assertTrue(target == same, "table identity changed")
	assertEquals(target.old, nil)
	assertEquals(target.shared, "b")
	assertDeepEquals(target.extra, { 1, 2 })
end)

test("replaceContents copies nested tables instead of sharing them", function()
	local source: { [string]: any } = { nested = { value = 1 } }
	local target: { [string]: any } = {}
	DataLogic.replaceContents(target, source)
	source.nested.value = 99
	assertEquals(target.nested.value, 1)
end)
