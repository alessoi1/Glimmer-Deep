--!strict
local Framework = require("../Framework")
local Modifiers = require("../../src/shared/Modifiers")
local PetConfig = require("../../src/shared/Config/Pets")
local Pets = require("../../src/shared/Pets")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals
local assertNear = Framework.assertNear

local config: Pets.Config = PetConfig

local NOW = 1_000_000

local function with(changes: { [string]: any }): Pets.Config
	local copy: any = table.clone(config)
	for key, value in changes do
		copy[key] = value
	end
	return copy
end

local function withProduct(): Pets.Config
	local egg: any = table.clone(config.egg)
	egg.productId = 4242
	return with({ egg = egg })
end

local function stateWithEggs(count: number): Pets.State
	local state = Pets.newState()
	state.eggs = count
	return state
end

-- Config -----------------------------------------------------------------------------

test("the shipped pet config is valid", function()
	local ok, reason = Pets.validateConfig(config)
	assertTrue(ok, reason)
end)

test("the shipped egg chances match the concept and sum to 100", function()
	assertEquals(config.egg.robux, 99)
	assertEquals(config.pity.afterEggs, 10)
	assertEquals(config.pity.minRarity, "rare")
	local total = 0
	for _, row in Pets.rarityRows(config) do
		total += row.percent
	end
	assertNear(total, 100, 1e-9)
	local petTotal = 0
	for _, row in Pets.petRows(config) do
		petTotal += row.percent
	end
	assertNear(petTotal, 100, 1e-9)
end)

test("every shipped pet has an effect with known fields", function()
	for petId, def in config.pets do
		for field in def.effect do
			assertTrue(table.find(Modifiers.knownFields, field) ~= nil, petId .. " uses unknown field " .. field)
		end
	end
end)

test("validateConfig rejects broken configs", function()
	local function egg(changes: { [string]: any }): Pets.Config
		local copy: any = table.clone(config.egg)
		copy.chances = table.clone(config.egg.chances)
		for key, value in changes do
			copy[key] = value
		end
		return with({ egg = copy })
	end
	assertTrue(
		not Pets.validateConfig(egg({ chances = { common = 50, rare = 25, epic = 10, legendary = 4, mythic = 1 } }))
	)
	assertTrue(
		not Pets.validateConfig(egg({ chances = { common = 60, rare = 25, epic = 10, legendary = 4 } })),
		"missing"
	)
	assertTrue(
		not Pets.validateConfig(
			egg({ chances = { common = 59, rare = 25, epic = 10, legendary = 4, mythic = 1, x = 1 } })
		)
	)
	assertTrue(not Pets.validateConfig(egg({ robux = 0 })))
	assertTrue(not Pets.validateConfig(egg({ productId = -1 })))
	assertTrue(not Pets.validateConfig(with({ pity = { afterEggs = 1, minRarity = "rare" } })))
	assertTrue(not Pets.validateConfig(with({ pity = { afterEggs = 10, minRarity = "ghost" } })))
	assertTrue(not Pets.validateConfig(with({ slots = 0 })))
	assertTrue(not Pets.validateConfig(with({ maxOwned = 0 })))
	assertTrue(not Pets.validateConfig(with({ receiptHistory = 0 })))
	assertTrue(not Pets.validateConfig(with({ freeEgg = { cooldownSeconds = 0 } })))
	assertTrue(not Pets.validateConfig(with({ order = { "ghost" } })))
	assertTrue(not Pets.validateConfig(with({ order = {} })), "pets missing from the order")
	local badRarity: any = table.clone(config.pets)
	badRarity.mole = { rarity = "ghost", effect = { tempoBonus = 0.1 } }
	assertTrue(not Pets.validateConfig(with({ pets = badRarity })))
	local noEffect: any = table.clone(config.pets)
	noEffect.mole = { rarity = "common", effect = {} }
	assertTrue(not Pets.validateConfig(with({ pets = noEffect })))
	local badField: any = table.clone(config.pets)
	badField.mole = { rarity = "common", effect = { warp = 1 } }
	assertTrue(not Pets.validateConfig(with({ pets = badField })))
	local negative: any = table.clone(config.pets)
	negative.mole = { rarity = "common", effect = { tempoBonus = -0.1 } }
	assertTrue(not Pets.validateConfig(with({ pets = negative })))
end)

-- Roll -------------------------------------------------------------------------------

test("a roll picks the rarity by cumulative chance, then a pet inside the rarity", function()
	local state = Pets.newState()
	local function roll(first: number, second: number): (string, string)
		local values = { first, second }
		local index = 0
		local petId, rarityId = Pets.roll(state, config, function()
			index += 1
			return values[index]
		end)
		return petId, rarityId
	end
	local petId, rarityId = roll(0, 0)
	assertEquals(rarityId, "common")
	assertEquals(petId, "mole")
	petId, rarityId = roll(0.59, 0.99)
	assertEquals(rarityId, "common")
	assertEquals(petId, "glowworm")
	_, rarityId = roll(0.6, 0)
	assertEquals(rarityId, "rare")
	_, rarityId = roll(0.85, 0)
	assertEquals(rarityId, "epic")
	_, rarityId = roll(0.95, 0)
	assertEquals(rarityId, "legendary")
	petId, rarityId = roll(0.99, 0)
	assertEquals(rarityId, "mythic")
	assertEquals(petId, "stone_dragon")
	petId, rarityId = roll(0.999999, 0.999999)
	assertEquals(petId, "star_beetle")
end)

test("over many eggs the pet shares match the shown percentages", function()
	local rng = Framework.seededRng(7)
	local counts: { [string]: number } = {}
	local total = 20000
	for _ = 1, total do
		local state = stateWithEggs(1)
		state.sinceRare = 0
		local result = Pets.open(state, config, rng)
		assertTrue(result ~= nil)
		if result ~= nil then
			counts[result.rarityId] = (counts[result.rarityId] or 0) + 1
		end
	end
	-- The guarantee never applies (sinceRare resets each time), so the plain
	-- chances hold.
	for _, row in Pets.rarityRows(config) do
		local share = (counts[row.rarityId] or 0) / total * 100
		assertNear(share, row.percent, 1.5, row.rarityId)
	end
end)

-- Opening and the guarantee ----------------------------------------------------------

test("opening an egg needs an egg and room in the collection", function()
	local rng = Framework.seededRng(1)
	local empty = Pets.newState()
	local result, reason = Pets.open(empty, config, rng)
	assertTrue(result == nil and reason == "no_egg")

	local full = stateWithEggs(1)
	local small = with({ maxOwned = 1 })
	full.owned = { { id = 1, petId = "mole" } }
	full.nextId = 2
	result, reason = Pets.open(full, small, rng)
	assertTrue(result == nil and reason == "full")
	assertEquals(full.eggs, 1, "the egg is kept")
end)

test("opening gives exactly one pet with a fresh instance id", function()
	local state = stateWithEggs(2)
	local rng = Framework.seededRng(3)
	local first = Pets.open(state, config, rng)
	local second = Pets.open(state, config, rng)
	assertTrue(first ~= nil and second ~= nil)
	if first == nil or second == nil then
		return
	end
	assertEquals(state.eggs, 0)
	assertEquals(#state.owned, 2)
	assertTrue(first.instanceId ~= second.instanceId)
	assertEquals(state.nextId, 3)
end)

test("the tenth egg without a rare or better is guaranteed to be rare or better", function()
	-- The lowest possible roll (0) always gives a common pet without the guarantee.
	local state = stateWithEggs(10)
	local lowest = function()
		return 0
	end
	for number = 1, 9 do
		local result = Pets.open(state, config, lowest)
		assertTrue(result ~= nil and result.rarityId == "common", "egg " .. number)
		assertTrue(result ~= nil and not result.guaranteed)
	end
	assertEquals(state.sinceRare, 9)
	assertTrue(Pets.guaranteeApplies(state, config))
	assertEquals(Pets.eggsUntilGuarantee(state, config), 1)
	local tenth = Pets.open(state, config, lowest)
	assertTrue(tenth ~= nil)
	if tenth == nil then
		return
	end
	assertEquals(tenth.rarityId, "rare", "guaranteed at least rare")
	assertTrue(tenth.guaranteed)
	assertEquals(state.sinceRare, 0, "the counter starts again")
	assertEquals(Pets.eggsUntilGuarantee(state, config), 10)
end)

test("a rare find resets the guarantee counter early", function()
	local state = stateWithEggs(3)
	local lowest = function()
		return 0
	end
	Pets.open(state, config, lowest)
	Pets.open(state, config, lowest)
	assertEquals(state.sinceRare, 2)
	local highest = function()
		return 0.999999
	end
	local result = Pets.open(state, config, highest)
	assertTrue(result ~= nil and result.rarityId == "mythic")
	assertEquals(state.sinceRare, 0)
end)

test("the guarantee never lowers a good roll", function()
	local state = stateWithEggs(1)
	state.sinceRare = 9
	local result = Pets.open(state, config, function()
		return 0.999999
	end)
	assertTrue(result ~= nil and result.rarityId == "mythic")
end)

test("with the guarantee the shares above the minimum are renormalized", function()
	local rng = Framework.seededRng(11)
	local counts: { [string]: number } = {}
	local total = 20000
	for _ = 1, total do
		local state = stateWithEggs(1)
		state.sinceRare = 9
		local result = Pets.open(state, config, rng)
		if result ~= nil then
			counts[result.rarityId] = (counts[result.rarityId] or 0) + 1
		end
	end
	assertEquals(counts.common, nil, "no common pet with the guarantee")
	-- 25 : 10 : 4 : 1 out of 40
	assertNear((counts.rare or 0) / total * 100, 62.5, 2)
	assertNear((counts.mythic or 0) / total * 100, 2.5, 1)
end)

-- Equipping and effect ---------------------------------------------------------------

local function stateWithPets(): Pets.State
	local state = Pets.newState()
	state.owned = { { id = 1, petId = "mole" }, { id = 2, petId = "star_beetle" }, { id = 3, petId = "badger" } }
	state.nextId = 4
	return state
end

test("an equipped pet gives its bonus; nothing equipped gives none", function()
	local state = stateWithPets()
	assertEquals(Pets.effectOf(state, config), nil)
	assertTrue(Pets.equip(state, config, 2))
	local part = Pets.effectOf(state, config)
	assertTrue(part ~= nil and part.luckBonus == 0.15 and part.offlineBonus == 0.3)
end)

test("with one slot a new pet replaces the working one", function()
	local state = stateWithPets()
	Pets.equip(state, config, 1)
	Pets.equip(state, config, 3)
	assertEquals(#state.equipped, 1)
	assertEquals(state.equipped[1], 3)
	local part = Pets.effectOf(state, config)
	assertTrue(part ~= nil and part.tempoBonus == 0.06)
end)

test("with two slots the bonuses of both pets add up", function()
	local two = with({ slots = 2 })
	local state = stateWithPets()
	Pets.equip(state, two, 1)
	Pets.equip(state, two, 3)
	assertEquals(#state.equipped, 2)
	local part = Pets.effectOf(state, two)
	assertTrue(part ~= nil)
	if part ~= nil then
		assertNear(part.tempoBonus or 0, 0.09, 1e-9)
	end
	Pets.equip(state, two, 2)
	assertEquals(#state.equipped, 2, "the oldest steps down")
	assertTrue(table.find(state.equipped, 1) == nil)
end)

test("equip rejects unknown and already working pets; unequip removes", function()
	local state = stateWithPets()
	local ok, reason = Pets.equip(state, config, 99)
	assertTrue(not ok and reason == "unknown_pet")
	Pets.equip(state, config, 1)
	ok, reason = Pets.equip(state, config, 1)
	assertTrue(not ok and reason == "already_equipped")
	assertTrue(Pets.unequip(state, 1))
	assertTrue(not Pets.unequip(state, 1))
	assertEquals(Pets.effectOf(state, config), nil)
end)

test("a stored pet that no longer exists in the config gives no bonus", function()
	local state = Pets.newState()
	state.owned = { { id = 1, petId = "retired" } }
	state.equipped = { 1 }
	assertEquals(Pets.effectOf(state, config), nil)
end)

test("pet bonuses combine through Modifiers", function()
	local state = stateWithPets()
	Pets.equip(state, config, 2)
	local part = Pets.effectOf(state, config)
	assertTrue(part ~= nil)
	if part ~= nil then
		local result = Modifiers.combine({ part })
		assertNear(result.luck, 1.15, 1e-9)
		assertNear(result.offlineMultiplier, 1.3, 1e-9)
	end
end)

-- Receipts ---------------------------------------------------------------------------

test("a receipt gives one egg once; a repeated receipt changes nothing", function()
	local cfg = withProduct()
	local state = Pets.newState()
	assertEquals(Pets.processReceipt(state, cfg, "p1", 4242), "granted")
	assertEquals(state.eggs, 1)
	assertEquals(Pets.processReceipt(state, cfg, "p1", 4242), "duplicate")
	assertEquals(Pets.processReceipt(state, cfg, "p1", 4242), "duplicate")
	assertEquals(state.eggs, 1)
	assertEquals(Pets.processReceipt(state, cfg, "p2", 4242), "granted")
	assertEquals(state.eggs, 2)
end)

test("an unknown product, product id 0 or a bad receipt gives nothing", function()
	local cfg = withProduct()
	local state = Pets.newState()
	assertEquals(Pets.processReceipt(state, cfg, "p1", 9999), "unknown_product")
	assertEquals(Pets.processReceipt(state, config, "p1", 0), "unknown_product", "unset product id")
	assertEquals(Pets.processReceipt(state, cfg, "", 4242), "bad_receipt")
	assertEquals(Pets.processReceipt(state, cfg, "p1", "x" :: any), "bad_receipt")
	assertEquals(state.eggs, 0)
	assertEquals(#state.receipts, 0)
end)

test("a paid egg is kept even when the collection is full", function()
	local cfg: any = withProduct()
	cfg.maxOwned = 1
	local state = Pets.newState()
	state.owned = { { id = 1, petId = "mole" } }
	assertEquals(Pets.processReceipt(state, cfg, "p1", 4242), "granted")
	assertEquals(state.eggs, 1)
end)

test("the receipt list keeps only the latest purchase ids", function()
	local cfg: any = withProduct()
	cfg.receiptHistory = 3
	local state = Pets.newState()
	for index = 1, 5 do
		Pets.processReceipt(state, cfg, "p" .. index, 4242)
	end
	assertEquals(#state.receipts, 3)
	assertTrue(not Pets.hasReceipt(state, "p1"))
	assertTrue(Pets.hasReceipt(state, "p5"))
end)

-- Free egg for restricted players ----------------------------------------------------

test("only restricted players get the free egg, once per cooldown", function()
	local state = Pets.newState()
	local ok, reason = Pets.claimFree(state, config, false, NOW)
	assertTrue(not ok and reason == "not_restricted")
	assertEquals(state.eggs, 0)
	ok, reason = Pets.claimFree(state, config, true, NOW)
	assertTrue(ok, reason)
	assertEquals(state.eggs, 1)
	ok, reason = Pets.claimFree(state, config, true, NOW + 60)
	assertTrue(not ok and reason == "cooldown")
	assertEquals(state.eggs, 1)
	ok = Pets.claimFree(state, config, true, NOW + config.freeEgg.cooldownSeconds)
	assertTrue(ok)
	assertEquals(state.eggs, 2)
end)

-- View -------------------------------------------------------------------------------

test("a normal player sees the egg offer and no free egg", function()
	local cfg = withProduct()
	local state = stateWithPets()
	Pets.equip(state, cfg, 2)
	local view = Pets.view(state, cfg, NOW, true, false)
	assertTrue(view.available and not view.restricted)
	assertTrue(view.egg ~= nil and view.egg.buyable and view.egg.robux == 99)
	assertEquals(view.free, nil)
	assertEquals(#view.owned, 3)
	assertTrue(view.owned[2].equipped and not view.owned[1].equipped)
	assertEquals(view.owned[2].rarityId, "mythic")
	assertEquals(view.eggsUntilGuarantee, 10)
end)

test("the egg is not buyable while the product id is unset", function()
	local view = Pets.view(Pets.newState(), config, NOW, true, false)
	assertTrue(view.egg ~= nil and not view.egg.buyable)
end)

test("a restricted player sees no paid egg but the free egg", function()
	local state = Pets.newState()
	local view = Pets.view(state, config, NOW, true, true)
	assertEquals(view.egg, nil)
	assertTrue(view.free ~= nil and view.free.canClaim)
	Pets.claimFree(state, config, true, NOW)
	local after = Pets.view(state, config, NOW + 10, true, true)
	assertTrue(after.free ~= nil and not after.free.canClaim)
	assertEquals(after.free and after.free.secondsUntil, config.freeEgg.cooldownSeconds - 10)
end)

test("the snapshot carries the chances and the guarantee", function()
	local snapshot = Pets.snapshot(Pets.newState(), config, NOW, true, false)
	assertEquals(#snapshot.rarities, 5)
	assertEquals(#snapshot.pets, #config.order)
	assertEquals(snapshot.pityAfter, 10)
	assertEquals(snapshot.pityRarity, "rare")
end)
