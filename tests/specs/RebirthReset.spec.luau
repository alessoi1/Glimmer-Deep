--!strict
local Framework = require("../Framework")
local ProfileData = require("../../src/server/ProfileData")
local RebirthReset = require("../../src/server/RebirthReset")
local rules = require("../TestRules")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals

local NOW = 5000

local function playedProfile(): any
	local profile: any = ProfileData.new(rules, Framework.seededRng(1), 100)
	profile.coins = 123456
	profile.depth = 312.5
	for id in profile.upgradeLevels do
		profile.upgradeLevels[id] = 3
	end
	profile.backpack = {
		ores = { coal = 12 },
		finds = { { id = 1, findId = "shard", layerId = "sand_clay", rarityId = "rare", value = 90 } },
	}
	profile.depot = {
		ores = { iron = 40 },
		finds = {
			{ id = 2, findId = "fossil", layerId = "rock", rarityId = "epic", mutationId = "golden", value = 900 },
		},
	}
	profile.nextFindId = 3
	profile.digger = { leftAt = 99 }
	profile.house = { level = 2, decor = { owned = { rug = true }, placed = { { slot = 1, id = "rug" } } } }
	profile.museum.displays =
		{ { slot = 1, find = { id = 3, findId = "amber", layerId = "rock", rarityId = "rare", value = 80 } } }
	profile.nextFindId = 4
	profile.pets = {
		owned = { { id = 1, petId = "mole" } },
		nextId = 2,
		equipped = { 1 },
		eggs = 2,
		sinceRare = 3,
		freeEggAt = 7,
		receipts = { "r" },
	}
	profile.boosters = { expires = { luck_booster = 999999 }, receipts = { "b" }, freeClaimedAt = 0 }
	profile.passes = { double_coins = true }
	profile.stats = { blocksDug = 777 }
	profile.onboarding = { step = 7, firstFindGiven = true }
	return profile
end

test("the reset sets coins, depth, tools and the hole shape back", function()
	local profile = playedProfile()
	local oldSeeds = table.clone(profile.layerSeeds)
	local previous = RebirthReset.apply(profile, rules, Framework.seededRng(99), NOW)
	assertEquals(previous, 312.5)
	assertEquals(profile.coins, 0)
	assertEquals(profile.depth, 0)
	for id, level in profile.upgradeLevels do
		assertEquals(level, 1, id)
	end
	local changed = false
	for layerId, seed in profile.layerSeeds do
		if seed ~= oldSeeds[layerId] then
			changed = true
		end
	end
	assertTrue(changed, "new hole seeds")
	assertEquals(profile.digger.leftAt, nil)
end)

test("ore is lost but rare finds stay in backpack and depot", function()
	local profile = playedProfile()
	RebirthReset.apply(profile, rules, Framework.seededRng(2), NOW)
	assertEquals(next(profile.backpack.ores), nil)
	assertEquals(next(profile.depot.ores), nil)
	assertEquals(#profile.backpack.finds, 1)
	assertEquals(#profile.depot.finds, 1)
	assertEquals(profile.depot.finds[1].mutationId, "golden")
	assertEquals(profile.nextFindId, 4, "find ids stay unique")
end)

test("museum, house, pets, boosters, passes, onboarding and stats stay", function()
	local profile = playedProfile()
	RebirthReset.apply(profile, rules, Framework.seededRng(3), NOW)
	assertEquals(#profile.museum.displays, 1)
	assertEquals(profile.house.level, 2)
	assertTrue(profile.house.decor.owned.rug)
	assertEquals(#profile.pets.owned, 1)
	assertEquals(profile.pets.eggs, 2)
	assertEquals(profile.boosters.expires.luck_booster, 999999)
	assertTrue(profile.passes.double_coins)
	assertEquals(profile.stats.blocksDug, 777)
	assertEquals(profile.onboarding.step, 7)
end)

test("the reset gives a new, untouched cave", function()
	local profile = playedProfile()
	profile.cave = { seed = 4242, deepestRow = 300, preDugRow = 120, slices = {}, chests = { ["1"] = 5 } }
	RebirthReset.apply(profile, rules, Framework.seededRng(8), NOW)
	assertEquals(profile.cave.deepestRow, 0)
	assertEquals(profile.cave.preDugRow, 0)
	assertTrue(profile.cave.seed ~= 4242)
	assertEquals(next(profile.cave.chests), nil)
end)

test("equipment and the stash stay through a rebirth", function()
	local profile = playedProfile()
	profile.gear = {
		owned = { { id = 1, slot = "weapon", tier = 3, source = "crafted", bound = false } },
		equipped = { weapon = 1 },
		nextId = 2,
	}
	profile.stash = { ores = { iron = 9 } }
	profile.potions.owned = { heal = 3 }
	RebirthReset.apply(profile, rules, Framework.seededRng(9), NOW)
	assertEquals(#profile.gear.owned, 1)
	assertEquals(profile.gear.equipped.weapon, 1)
	assertEquals(profile.stash.ores.iron, 9)
	assertEquals(profile.potions.owned.heal, 3)
end)

test("a reset profile is still valid", function()
	local profile = playedProfile()
	RebirthReset.apply(profile, rules, Framework.seededRng(4), NOW)
	local ok, reason = ProfileData.validate(profile, rules)
	assertTrue(ok, reason)
end)

test("the reset changes the profile table in place", function()
	local profile = playedProfile()
	local backpack = profile.backpack
	local depot = profile.depot
	RebirthReset.apply(profile, rules, Framework.seededRng(5), NOW)
	assertTrue(profile.backpack == backpack and profile.depot == depot)
end)
