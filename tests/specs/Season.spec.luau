--!strict
local BoosterConfig = require("../../src/shared/Config/Boosters")
local Boosters = require("../../src/shared/Boosters")
local Calendar = require("../../src/shared/Calendar")
local Framework = require("../Framework")
local HouseConfig = require("../../src/shared/Config/House")
local Quests = require("../../src/shared/Quests")
local Season = require("../../src/shared/Season")
local SeasonConfig = require("../../src/shared/Config/Season")
local ShopConfig = require("../../src/shared/Config/Shop")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals

local config: Season.Config = SeasonConfig

local function refs(): Season.Refs
	local prices: { [string]: number } = {}
	for id, def in HouseConfig.items do
		prices[id] = def.price
	end
	return { boosters = BoosterConfig, decorPrices = prices }
end

local function with(changes: { [string]: any }): Season.Config
	local copy: any = table.clone(config)
	for key, value in changes do
		copy[key] = value
	end
	return copy
end

local WEEK = Calendar.secondsPerWeek
local SEASON_START = 700 * config.seasonWeeks * WEEK -- a season boundary
local NOW = SEASON_START + 3 * 86400

local function newSubject(): Season.Subject
	return {
		coins = 0,
		pets = { eggs = 0 },
		boosters = Boosters.newState(),
		house = { decor = { owned = {} } },
	}
end

-- Config -----------------------------------------------------------------------------

test("the shipped season config is valid", function()
	local ok, reason = Season.validateConfig(config, refs())
	assertTrue(ok, reason)
end)

test("the season pass key is a pass in the shop config", function()
	assertTrue(ShopConfig.passes[config.passKey] ~= nil, "add the pass to Config/Shop")
end)

test("season points only come from known quest events", function()
	local known: { [string]: boolean } = {}
	for _, event in Quests.events do
		known[event] = true
	end
	for name in config.xp do
		assertTrue(known[name], name .. " is not a game event")
	end
end)

test("validateConfig rejects broken configs", function()
	local r = refs()
	assertTrue(not Season.validateConfig(with({ seasonWeeks = 0 }), r))
	assertTrue(not Season.validateConfig(with({ passKey = "" }), r))
	assertTrue(not Season.validateConfig(with({ levelXp = {} }), r))
	assertTrue(not Season.validateConfig(with({ levelXp = { 0 } }), r))
	assertTrue(not Season.validateConfig(with({ xp = { dig = 0 } }), r))
	local short: any = table.clone(config.free)
	table.remove(short)
	assertTrue(not Season.validateConfig(with({ free = short }), r), "one reward per level")
	local function reward(track: string, value: { [string]: any }): Season.Config
		local list: any = table.clone((config :: any)[track])
		list[1] = value
		return with({ [track] = list })
	end
	assertTrue(not Season.validateConfig(reward("free", { kind = "coins", amount = 0 }), r))
	assertTrue(not Season.validateConfig(reward("free", { kind = "booster", id = "ghost", amount = 1 }), r))
	assertTrue(not Season.validateConfig(reward("premium", { kind = "decor", id = "ghost" }), r))
	assertTrue(not Season.validateConfig(reward("premium", { kind = "gift" }), r))
end)

-- Season and points ------------------------------------------------------------------

test("a season lasts the configured weeks and then the next one starts", function()
	assertEquals(Season.seasonOf(SEASON_START, config), 700)
	assertEquals(Season.seasonOf(SEASON_START + config.seasonWeeks * WEEK - 1, config), 700)
	assertEquals(Season.seasonOf(SEASON_START + config.seasonWeeks * WEEK, config), 701)
	assertEquals(Season.secondsLeft(SEASON_START, config), config.seasonWeeks * WEEK)
	assertEquals(Season.secondsLeft(SEASON_START + config.seasonWeeks * WEEK - 1, config), 1)
end)

test("a new season starts the progress again", function()
	local state = Season.newState()
	Season.addXp(state, config, 1200, NOW)
	assertEquals(state.id, 700)
	assertTrue(Season.claim(state, config, "free", 1, false, NOW).ok)
	assertEquals(Season.sync(state, NOW + 1, config), false)
	assertEquals(Season.sync(state, SEASON_START + config.seasonWeeks * WEEK, config), true)
	assertEquals(state.id, 701)
	assertEquals(state.xp, 0)
	assertEquals(#state.claimedFree, 0)
	assertEquals(#state.claimedPremium, 0)
end)

test("levels follow the points", function()
	assertEquals(Season.levelOf(0, config), 0)
	assertEquals(Season.levelOf(499, config), 0)
	assertEquals(Season.levelOf(500, config), 1)
	assertEquals(Season.levelOf(1099, config), 1)
	assertEquals(Season.levelOf(1100, config), 2)
	local total = 0
	for _, needed in config.levelXp do
		total += needed
	end
	assertEquals(Season.levelOf(total, config), #config.levelXp)
	assertEquals(Season.levelOf(total * 5, config), #config.levelXp)
end)

test("points stop at the highest level and report gained levels", function()
	local state = Season.newState()
	assertEquals(Season.addXp(state, config, 499, NOW), 0)
	assertEquals(Season.addXp(state, config, 1, NOW), 1)
	assertEquals(Season.addXp(state, config, 1300, NOW), 2, "two levels at once")
	assertEquals(Season.addXp(state, config, 1e9, NOW), #config.levelXp - 3)
	assertEquals(Season.addXp(state, config, 100, NOW), 0)
	assertEquals(Season.levelOf(state.xp, config), #config.levelXp)
	assertEquals(Season.addXp(state, config, -50, NOW), 0, "negative points change nothing")
end)

test("game events give points only when configured", function()
	assertEquals(Season.xpFor("dig", 1, config), 1)
	assertEquals(Season.xpFor("rare", 2, config), 30)
	assertEquals(Season.xpFor("sold", 5, config), 0)
	assertEquals(Season.xpFor("dig", 0, config), 0)
	assertEquals(Season.xpFor("dig", -3, config), 0)
end)

-- Claiming ---------------------------------------------------------------------------

test("a reward is claimed once per level and track", function()
	local state = Season.newState()
	Season.addXp(state, config, 1200, NOW)
	local result = Season.claim(state, config, "free", 1, false, NOW)
	assertTrue(result.ok, result.reason)
	assertEquals(result.reward and result.reward.kind, config.free[1].kind)
	result = Season.claim(state, config, "free", 1, false, NOW)
	assertTrue(not result.ok and result.reason == "already_claimed")
	result = Season.claim(state, config, "free", 2, false, NOW)
	assertTrue(result.ok, result.reason)
	assertEquals(#state.claimedFree, 2)
end)

test("a level that is not reached cannot be claimed", function()
	local state = Season.newState()
	Season.addXp(state, config, 499, NOW)
	local result = Season.claim(state, config, "free", 1, false, NOW)
	assertTrue(not result.ok and result.reason == "locked_level")
	assertEquals(#state.claimedFree, 0)
end)

test("the premium track needs the pass", function()
	local state = Season.newState()
	Season.addXp(state, config, 1200, NOW)
	local result = Season.claim(state, config, "premium", 1, false, NOW)
	assertTrue(not result.ok and result.reason == "no_premium")
	assertEquals(#state.claimedPremium, 0)
	result = Season.claim(state, config, "premium", 1, true, NOW)
	assertTrue(result.ok, result.reason)
	result = Season.claim(state, config, "premium", 1, true, NOW)
	assertTrue(not result.ok and result.reason == "already_claimed")
	assertTrue(Season.claim(state, config, "free", 1, false, NOW).ok, "tracks are separate")
end)

test("bad input is rejected", function()
	local state = Season.newState()
	Season.addXp(state, config, 1e9, NOW)
	for _, case in { { "free", 0 }, { "free", 11 }, { "free", 1.5 }, { "gold", 1 }, { "free", -1 } } do
		local result = Season.claim(state, config, case[1] :: string, case[2] :: number, true, NOW)
		assertTrue(not result.ok and result.reason == "bad_input", tostring(case[1]) .. tostring(case[2]))
	end
	assertEquals(#state.claimedFree, 0)
end)

test("a reward from an old season cannot be claimed in the new one", function()
	local state = Season.newState()
	Season.addXp(state, config, 1200, NOW)
	local result = Season.claim(state, config, "free", 1, false, SEASON_START + config.seasonWeeks * WEEK)
	assertTrue(not result.ok and result.reason == "locked_level")
end)

-- Paying -----------------------------------------------------------------------------

test("coins and eggs are paid into the profile", function()
	local subject = newSubject()
	local paid = Season.pay(subject, { kind = "coins", amount = 300 }, refs(), NOW)
	assertEquals(subject.coins, 300)
	assertEquals(paid.coins, 300)
	paid = Season.pay(subject, { kind = "egg", amount = 2 }, refs(), NOW)
	assertEquals(subject.pets.eggs, 2)
	assertEquals(paid.eggs, 2)
end)

test("a booster reward starts the booster, and repeated runs add up", function()
	local subject = newSubject()
	Season.pay(subject, { kind = "booster", id = "luck_booster", amount = 2 }, refs(), NOW)
	assertEquals(
		Boosters.remaining(subject.boosters, "luck_booster", NOW),
		2 * BoosterConfig.boosters.luck_booster.durationSeconds
	)
end)

test("a decoration reward is added once; an owned one pays its price", function()
	local subject = newSubject()
	local paid = Season.pay(subject, { kind = "decor", id = "lantern" }, refs(), NOW)
	assertTrue(subject.house.decor.owned.lantern)
	assertEquals(subject.coins, 0)
	assertEquals(paid.coins, nil)
	paid = Season.pay(subject, { kind = "decor", id = "lantern" }, refs(), NOW)
	assertEquals(subject.coins, HouseConfig.items.lantern.price)
	assertEquals(paid.coins, HouseConfig.items.lantern.price)
end)

test("an unknown reward kind pays nothing", function()
	local subject = newSubject()
	Season.pay(subject, { kind = "gift" }, refs(), NOW)
	assertEquals(subject.coins, 0)
	assertEquals(subject.pets.eggs, 0)
end)

-- View -------------------------------------------------------------------------------

test("the view shows level, progress and what can be claimed", function()
	local state = Season.newState()
	Season.addXp(state, config, 1250, NOW)
	Season.claim(state, config, "free", 1, false, NOW)
	local view = Season.view(state, config, true, NOW)
	assertEquals(view.season, 700)
	assertEquals(view.level, 2)
	assertEquals(view.xp, 1250)
	assertEquals(view.xpIntoLevel, 150)
	assertEquals(view.xpForNext, 700)
	assertEquals(view.maxLevel, 10)
	assertTrue(view.premium)
	assertEquals(#view.levels, 10)
	assertTrue(view.levels[1].freeClaimed and not view.levels[1].freeReady)
	assertTrue(view.levels[2].freeReady and view.levels[2].premiumReady)
	assertTrue(not view.levels[3].reached and not view.levels[3].freeReady)
	local without = Season.view(state, config, false, NOW)
	assertTrue(not without.levels[2].premiumReady and without.levels[2].freeReady)
end)

test("the view of an old save shows an empty new season and changes nothing", function()
	local state = Season.newState()
	Season.addXp(state, config, 1200, NOW)
	local view = Season.view(state, config, false, SEASON_START + config.seasonWeeks * WEEK)
	assertEquals(view.xp, 0)
	assertEquals(view.level, 0)
	assertEquals(state.xp, 1200, "the stored state is only reset by sync")
end)

test("at the highest level there is no next level", function()
	local state = Season.newState()
	Season.addXp(state, config, 1e9, NOW)
	local view = Season.view(state, config, false, NOW)
	assertEquals(view.level, view.maxLevel)
	assertEquals(view.xpForNext, nil)
end)
