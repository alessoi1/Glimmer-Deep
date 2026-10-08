--!strict
local Boosters = require("../../src/shared/Boosters")
local BoosterConfig = require("../../src/shared/Config/Boosters")
local DigRoll = require("../../src/shared/DigRoll")
local TestConfig = require("../TestConfig")
local Framework = require("../Framework")
local Modifiers = require("../../src/shared/Modifiers")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals
local assertNear = Framework.assertNear

local config: Boosters.Config = BoosterConfig

local NOW = 1_000_000

local function withProducts(): Boosters.Config
	local copy: any = table.clone(config)
	copy.boosters = {}
	local id = 100
	for key, def in config.boosters do
		local entry: any = table.clone(def)
		id += 1
		entry.productId = id
		copy.boosters[key] = entry
	end
	return copy
end

local function productOf(cfg: Boosters.Config, key: string): number
	return cfg.boosters[key].productId
end

-- Config -----------------------------------------------------------------------------

test("the shipped booster config is valid", function()
	local ok, reason = Boosters.validateConfig(config)
	assertTrue(ok, reason)
end)

test("the shipped boosters match the concept (15 min luck, 30 min double speed)", function()
	assertEquals(config.boosters.luck_booster.durationSeconds, 900)
	assertEquals(config.boosters.luck_booster.robux, 39)
	assertEquals(config.boosters.tempo_booster.durationSeconds, 1800)
	assertEquals(config.boosters.tempo_booster.robux, 49)
	local result = Modifiers.combine({ config.boosters.tempo_booster.effect })
	assertEquals(result.speedMultiplier, 2)
	assertTrue(config.boosters.luck_booster.paidRandom, "luck is a paid random item")
	assertTrue(not config.boosters.tempo_booster.paidRandom)
end)

test("validateConfig rejects broken configs", function()
	local function with(changes: { [string]: any }): Boosters.Config
		local copy: any = table.clone(config)
		for key, value in changes do
			copy[key] = value
		end
		return copy
	end
	local function booster(changes: { [string]: any }): Boosters.Config
		local entry: any =
			{ productId = 1, robux = 10, durationSeconds = 60, effect = { luckBonus = 0.1 }, paidRandom = true }
		for key, value in changes do
			entry[key] = value
		end
		return with({
			order = { "b" },
			boosters = { b = entry },
			freeClaim = { boosterId = "b", cooldownSeconds = 60 },
		})
	end
	assertTrue(Boosters.validateConfig(booster({})))
	assertTrue(not Boosters.validateConfig(booster({ robux = 0 })))
	assertTrue(not Boosters.validateConfig(booster({ durationSeconds = 1.5 })))
	assertTrue(not Boosters.validateConfig(booster({ productId = -1 })))
	assertTrue(not Boosters.validateConfig(booster({ effect = {} })), "needs an effect")
	assertTrue(not Boosters.validateConfig(booster({ effect = { warp = 1 } })), "unknown effect")
	assertTrue(not Boosters.validateConfig(booster({ durationSeconds = 999999 })), "longer than the stack limit")
	assertTrue(not Boosters.validateConfig(with({ order = { "ghost" } })))
	assertTrue(not Boosters.validateConfig(with({ order = {} })))
	assertTrue(not Boosters.validateConfig(with({ maxStackSeconds = 0 })))
	assertTrue(not Boosters.validateConfig(with({ receiptHistory = 0 })))
	assertTrue(not Boosters.validateConfig(with({ freeClaim = { boosterId = "ghost", cooldownSeconds = 60 } })))
	assertTrue(not Boosters.validateConfig(with({ freeClaim = { boosterId = "luck_booster", cooldownSeconds = 0 } })))
end)

test("validateConfig rejects two boosters with the same product id", function()
	local cfg: any = withProducts()
	cfg.boosters.tempo_booster.productId = cfg.boosters.luck_booster.productId
	assertTrue(not Boosters.validateConfig(cfg))
end)

-- Running time -----------------------------------------------------------------------

test("a booster runs for its duration and then gives no effect", function()
	local state = Boosters.newState()
	assertEquals(Boosters.remaining(state, "luck_booster", NOW), 0)
	assertEquals(Boosters.effectOf(state, "luck_booster", config, NOW), nil)

	local expires = Boosters.grant(state, config, "luck_booster", NOW)
	assertEquals(expires, NOW + 900)
	assertEquals(Boosters.remaining(state, "luck_booster", NOW + 100), 800)
	local part = Boosters.effectOf(state, "luck_booster", config, NOW + 899)
	assertTrue(part ~= nil and part.luckBonus == 0.25)
	assertEquals(Boosters.effectOf(state, "luck_booster", config, NOW + 900), nil, "ends exactly at the end time")
	assertEquals(Boosters.remaining(state, "luck_booster", NOW + 5000), 0)
end)

test("buying again while it runs adds time, never above the stack limit", function()
	local state = Boosters.newState()
	Boosters.grant(state, config, "luck_booster", NOW)
	Boosters.grant(state, config, "luck_booster", NOW + 100)
	assertEquals(state.expires.luck_booster, NOW + 1800)
	for _ = 1, 30 do
		Boosters.grant(state, config, "luck_booster", NOW + 100)
	end
	assertEquals(state.expires.luck_booster, NOW + 100 + config.maxStackSeconds)
end)

test("an expired booster restarts from now, not from its old end", function()
	local state = Boosters.newState()
	state.expires.tempo_booster = NOW - 5000
	Boosters.grant(state, config, "tempo_booster", NOW)
	assertEquals(state.expires.tempo_booster, NOW + 1800)
end)

test("granting an unknown booster changes nothing", function()
	local state = Boosters.newState()
	assertEquals(Boosters.grant(state, config, "ghost", NOW), nil)
	assertEquals(next(state.expires), nil)
end)

-- Receipts ---------------------------------------------------------------------------

test("a receipt grants the booster once; a repeated receipt changes nothing", function()
	local cfg = withProducts()
	local state = Boosters.newState()
	local luck = productOf(cfg, "luck_booster")
	assertEquals(Boosters.processReceipt(state, cfg, "p1", luck, NOW), "granted")
	local expires = state.expires.luck_booster
	assertEquals(expires, NOW + 900)
	assertEquals(Boosters.processReceipt(state, cfg, "p1", luck, NOW + 10), "duplicate")
	assertEquals(Boosters.processReceipt(state, cfg, "p1", luck, NOW + 20), "duplicate")
	assertEquals(state.expires.luck_booster, expires)
	assertEquals(#state.receipts, 1)
	assertEquals(Boosters.processReceipt(state, cfg, "p2", luck, NOW + 30), "granted")
	assertEquals(state.expires.luck_booster, NOW + 30 + 900 + (expires - NOW - 30))
end)

test("a receipt for an unknown product or without data grants nothing", function()
	local cfg = withProducts()
	local state = Boosters.newState()
	assertEquals(Boosters.processReceipt(state, cfg, "p1", 9999, NOW), "unknown_product")
	assertEquals(Boosters.processReceipt(state, cfg, "p1", 0, NOW), "unknown_product")
	assertEquals(Boosters.processReceipt(state, cfg, "", productOf(cfg, "luck_booster"), NOW), "bad_receipt")
	assertEquals(Boosters.processReceipt(state, cfg, "p1", "x" :: any, NOW), "bad_receipt")
	assertEquals(next(state.expires), nil)
	assertEquals(#state.receipts, 0)
end)

test("an unset product id (0) never matches a receipt", function()
	local state = Boosters.newState()
	assertEquals(Boosters.processReceipt(state, config, "p1", 0, NOW), "unknown_product")
	assertEquals(Boosters.keyOfProduct(config, 0), nil)
end)

test("the receipt list keeps only the latest purchase ids", function()
	local cfg: any = withProducts()
	cfg.receiptHistory = 3
	local state = Boosters.newState()
	local tempo = productOf(cfg, "tempo_booster")
	for index = 1, 5 do
		Boosters.processReceipt(state, cfg, "p" .. index, tempo, NOW)
	end
	assertEquals(#state.receipts, 3)
	assertTrue(not Boosters.hasReceipt(state, "p1"))
	assertTrue(Boosters.hasReceipt(state, "p3"))
	assertTrue(Boosters.hasReceipt(state, "p5"))
end)

-- Free claim for restricted players --------------------------------------------------

test("only restricted players can claim the free run, once per cooldown", function()
	local state = Boosters.newState()
	local ok, reason = Boosters.claimFree(state, config, false, NOW)
	assertTrue(not ok and reason == "not_restricted")
	assertEquals(next(state.expires), nil)

	ok, reason = Boosters.claimFree(state, config, true, NOW)
	assertTrue(ok, reason)
	assertEquals(state.expires.luck_booster, NOW + 900)
	assertEquals(state.freeClaimedAt, NOW)

	ok, reason = Boosters.claimFree(state, config, true, NOW + 60)
	assertTrue(not ok and reason == "cooldown")
	assertEquals(Boosters.secondsUntilFree(state, config, NOW + 60), config.freeClaim.cooldownSeconds - 60)

	ok, reason = Boosters.claimFree(state, config, true, NOW + config.freeClaim.cooldownSeconds)
	assertTrue(ok, reason)
end)

-- View -------------------------------------------------------------------------------

test("the view lists both boosters for a normal player and no free run", function()
	local state = Boosters.newState()
	Boosters.grant(state, config, "tempo_booster", NOW)
	local view = Boosters.view(state, config, NOW + 30, true, false)
	assertTrue(view.available)
	assertEquals(#view.boosters, 2)
	assertEquals(view.boosters[1].key, "luck_booster")
	assertEquals(view.boosters[1].remaining, 0)
	assertEquals(view.boosters[1].luckBonus, 0.25)
	assertEquals(view.boosters[2].remaining, 1770)
	assertEquals(view.free, nil)
	assertTrue(view.boosters[1].buyable, "the shipped config has product ids")
end)

test("a booster without a product id is not buyable and never matches a receipt", function()
	local cfg: any = table.clone(config)
	cfg.boosters = { luck_booster = table.clone(config.boosters.luck_booster) }
	cfg.boosters.luck_booster.productId = 0
	cfg.order = { "luck_booster" }
	local view = Boosters.view(Boosters.newState(), cfg, NOW, true, false)
	assertTrue(not view.boosters[1].buyable)
end)

test("a restricted player does not see the paid luck booster but gets the free run", function()
	local state = Boosters.newState()
	local view = Boosters.view(state, config, NOW, true, true)
	assertTrue(view.restricted)
	assertEquals(#view.boosters, 1)
	assertEquals(view.boosters[1].key, "tempo_booster")
	assertTrue(view.free ~= nil and view.free.canClaim)
	Boosters.claimFree(state, config, true, NOW)
	local after = Boosters.view(state, config, NOW + 10, true, true)
	assertTrue(after.free ~= nil and not after.free.canClaim)
	assertEquals(after.free and after.free.secondsUntil, config.freeClaim.cooldownSeconds - 10)
end)

test("a booster is buyable only with a product id", function()
	local cfg = withProducts()
	local view = Boosters.view(Boosters.newState(), cfg, NOW, true, false)
	assertTrue(view.boosters[1].buyable and view.boosters[2].buyable)
end)

-- Shown chances ----------------------------------------------------------------------

test("the luck booster shows base and boosted rarity chances, both summing to 100", function()
	local digConfig = TestConfig
	local base = DigRoll.getRarityChances(digConfig, 1)
	local boosted = DigRoll.getRarityChances(digConfig, 1 + config.boosters.luck_booster.effect.luckBonus)
	local rows = Boosters.chanceRows(base, boosted)
	assertEquals(#rows, #digConfig.rarities)
	local baseSum, boostedSum = 0, 0
	for _, row in rows do
		baseSum += row.base
		boostedSum += row.boosted
	end
	assertNear(baseSum, 100, 1e-6)
	assertNear(boostedSum, 100, 1e-6)
	assertTrue(rows[1].boosted < rows[1].base, "common gets rarer")
	assertTrue(rows[#rows].boosted > rows[#rows].base, "the rarest tier gets more likely")
end)
