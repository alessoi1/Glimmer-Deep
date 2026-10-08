--!strict
-- Pure pet logic: config checks, the egg roll with its guarantee, opening eggs,
-- equipping, receipts (idempotent), the free egg for restricted players and the
-- view the pet panel shows. Times are server times (os.time seconds) and the
-- random source is passed in. No Roblox services; the PetService talks to
-- MarketplaceService and PolicyService.

local Modifiers = require("./Modifiers")

export type Rng = () -> number -- returns a number in [0, 1)

export type PetDef = { rarity: string, effect: Modifiers.Part }

export type Config = {
	rarityOrder: { string },
	egg: { productId: number, robux: number, chances: { [string]: number } },
	pity: { afterEggs: number, minRarity: string },
	slots: number,
	maxOwned: number,
	freeEgg: { cooldownSeconds: number },
	receiptHistory: number,
	order: { string },
	pets: { [string]: PetDef },
}

export type OwnedPet = { id: number, petId: string }

-- What the profile stores.
export type State = {
	owned: { OwnedPet },
	nextId: number, -- next free pet instance id
	equipped: { number }, -- instance ids of working pets, first = oldest
	eggs: number, -- eggs waiting to be opened
	sinceRare: number, -- eggs opened since the last pet of minRarity or better
	freeEggAt: number, -- server time of the last free egg, 0 = never
	receipts: { string }, -- latest purchase ids, oldest first
}

export type OpenResult = {
	instanceId: number,
	petId: string,
	rarityId: string,
	guaranteed: boolean, -- the guarantee decided the rarity tier
}

export type PetRow = {
	instanceId: number,
	petId: string,
	rarityId: string,
	effect: Modifiers.Part,
	equipped: boolean,
}

export type ChanceRow = { petId: string, rarityId: string, percent: number, effect: Modifiers.Part }
export type RarityRow = { rarityId: string, percent: number }

export type FreeView = { canClaim: boolean, secondsUntil: number }

export type View = {
	available: boolean, -- false during the first minutes (no purchase offers yet)
	restricted: boolean, -- PolicyService restricts paid random items
	eggs: number,
	slots: number,
	owned: { PetRow },
	maxOwned: number,
	egg: { robux: number, buyable: boolean }?, -- nil when restricted (paid random item)
	free: FreeView?, -- only for restricted players
	eggsUntilGuarantee: number, -- how many eggs at most until the guarantee applies
}

-- What the server sends to the pet panel: the view plus the shown chances.
export type Snapshot = {
	view: View,
	rarities: { RarityRow }, -- egg chances per rarity in percent, sum 100
	pets: { ChanceRow }, -- chance per pet in percent, sum 100
	pityAfter: number,
	pityRarity: string,
}

export type ReceiptOutcome = "granted" | "duplicate" | "unknown_product" | "bad_receipt"

local PERCENT_TOLERANCE = 1e-6

local Pets = {}

local function isPositiveInteger(value: any): boolean
	return type(value) == "number" and value >= 1 and value < math.huge and value % 1 == 0
end

local function rarityIndex(config: Config, rarityId: string): number?
	return table.find(config.rarityOrder, rarityId)
end

local function petsOfRarity(config: Config, rarityId: string): { string }
	local list = {}
	for _, petId in config.order do
		if config.pets[petId].rarity == rarityId then
			table.insert(list, petId)
		end
	end
	return list
end

-- Returns true when the config is usable, otherwise false and a reason.
function Pets.validateConfig(config: Config): (boolean, string?)
	if #config.rarityOrder == 0 then
		return false, "rarityOrder is empty"
	end
	local inOrder: { [string]: boolean } = {}
	for _, petId in config.order do
		if config.pets[petId] == nil then
			return false, "order names the unknown pet " .. petId
		end
		inOrder[petId] = true
	end
	local total = 0
	for _, rarityId in config.rarityOrder do
		local chance = config.egg.chances[rarityId]
		if type(chance) ~= "number" or chance < 0 or chance ~= chance then
			return false, "egg needs a chance for " .. rarityId
		end
		total += chance
		if #petsOfRarity(config, rarityId) == 0 and chance > 0 then
			return false, rarityId .. " has a chance but no pets"
		end
	end
	for rarityId in config.egg.chances do
		if rarityIndex(config, rarityId) == nil then
			return false, "egg has a chance for the unknown rarity " .. tostring(rarityId)
		end
	end
	if math.abs(total - 100) > PERCENT_TOLERANCE then
		return false, "egg chances must sum to 100, got " .. tostring(total)
	end
	if not isPositiveInteger(config.egg.robux) then
		return false, "egg needs a positive integer price"
	end
	if type(config.egg.productId) ~= "number" or config.egg.productId < 0 or config.egg.productId % 1 ~= 0 then
		return false, "egg needs a non-negative integer productId"
	end

	for petId, def in config.pets do
		if not inOrder[petId] then
			return false, petId .. " is missing from the order"
		end
		if rarityIndex(config, def.rarity) == nil then
			return false, petId .. " has the unknown rarity " .. tostring(def.rarity)
		end
		local fields = 0
		for field, value in def.effect do
			fields += 1
			if table.find(Modifiers.knownFields, field) == nil then
				return false, string.format("%s has the unknown effect %s", petId, tostring(field))
			end
			if type(value) ~= "number" or value <= 0 or value ~= value or value == math.huge then
				return false, string.format("%s needs a positive %s", petId, tostring(field))
			end
		end
		if fields == 0 then
			return false, petId .. " needs an effect"
		end
	end

	if rarityIndex(config, config.pity.minRarity) == nil then
		return false, "pity names the unknown rarity " .. tostring(config.pity.minRarity)
	end
	if not isPositiveInteger(config.pity.afterEggs) or config.pity.afterEggs < 2 then
		return false, "pity.afterEggs must be an integer of at least 2"
	end
	-- The guarantee needs a chance to get minRarity or better at all.
	local reachable = 0
	for index = rarityIndex(config, config.pity.minRarity) :: number, #config.rarityOrder do
		reachable += config.egg.chances[config.rarityOrder[index]]
	end
	if reachable <= 0 then
		return false, "no egg chance at or above the pity rarity"
	end
	if not isPositiveInteger(config.slots) then
		return false, "slots must be a positive integer"
	end
	if not isPositiveInteger(config.maxOwned) then
		return false, "maxOwned must be a positive integer"
	end
	if not isPositiveInteger(config.freeEgg.cooldownSeconds) then
		return false, "freeEgg needs a positive integer cooldown"
	end
	if not isPositiveInteger(config.receiptHistory) then
		return false, "receiptHistory must be a positive integer"
	end
	return true, nil
end

function Pets.newState(): State
	return { owned = {}, nextId = 1, equipped = {}, eggs = 0, sinceRare = 0, freeEggAt = 0, receipts = {} }
end

-- Egg chances per rarity as percent rows, in rarity order. They sum to 100.
function Pets.rarityRows(config: Config): { RarityRow }
	local rows: { RarityRow } = {}
	for _, rarityId in config.rarityOrder do
		table.insert(rows, { rarityId = rarityId, percent = config.egg.chances[rarityId] })
	end
	return rows
end

-- Chance per pet in percent, in panel order. They sum to 100: a rarity's chance
-- is shared equally between its pets.
function Pets.petRows(config: Config): { ChanceRow }
	local rows: { ChanceRow } = {}
	for _, petId in config.order do
		local rarityId = config.pets[petId].rarity
		table.insert(rows, {
			petId = petId,
			rarityId = rarityId,
			percent = config.egg.chances[rarityId] / #petsOfRarity(config, rarityId),
			effect = config.pets[petId].effect,
		})
	end
	return rows
end

-- True when the next egg is the one the guarantee applies to.
function Pets.guaranteeApplies(state: State, config: Config): boolean
	return state.sinceRare + 1 >= config.pity.afterEggs
end

-- Eggs at most until the guarantee applies (1 = the next egg).
function Pets.eggsUntilGuarantee(state: State, config: Config): number
	return math.max(1, config.pity.afterEggs - state.sinceRare)
end

local function pickRarity(config: Config, guaranteed: boolean, roll: number): string
	local first = if guaranteed then rarityIndex(config, config.pity.minRarity) :: number else 1
	local total = 0
	for index = first, #config.rarityOrder do
		total += config.egg.chances[config.rarityOrder[index]]
	end
	local target = roll * total
	local running = 0
	local last = config.rarityOrder[first]
	for index = first, #config.rarityOrder do
		local rarityId = config.rarityOrder[index]
		local chance = config.egg.chances[rarityId]
		if chance > 0 then
			running += chance
			last = rarityId
			if target < running then
				return rarityId
			end
		end
	end
	return last
end

-- Rolls one egg without changing the state. Draw order: rarity, then pet.
function Pets.roll(state: State, config: Config, rng: Rng): (string, string, boolean)
	local guaranteed = Pets.guaranteeApplies(state, config)
	local rarityId = pickRarity(config, guaranteed, rng())
	local candidates = petsOfRarity(config, rarityId)
	local index = math.min(math.floor(rng() * #candidates) + 1, #candidates)
	return candidates[index], rarityId, guaranteed
end

-- Opens one egg: takes it, rolls, adds the pet and updates the guarantee counter.
-- Returns the result, or nil and a reason ("no_egg", "full").
function Pets.open(state: State, config: Config, rng: Rng): (OpenResult?, string?)
	if state.eggs <= 0 then
		return nil, "no_egg"
	end
	if #state.owned >= config.maxOwned then
		return nil, "full"
	end
	local petId, rarityId, guaranteed = Pets.roll(state, config, rng)
	state.eggs -= 1
	local instanceId = state.nextId
	state.nextId += 1
	table.insert(state.owned, { id = instanceId, petId = petId })
	local reached = (rarityIndex(config, rarityId) :: number) >= (rarityIndex(config, config.pity.minRarity) :: number)
	state.sinceRare = if reached then 0 else state.sinceRare + 1
	return { instanceId = instanceId, petId = petId, rarityId = rarityId, guaranteed = guaranteed }, nil
end

local function find(state: State, instanceId: number): OwnedPet?
	for _, pet in state.owned do
		if pet.id == instanceId then
			return pet
		end
	end
	return nil
end

-- Puts an owned pet to work. When all slots are taken the oldest working pet
-- steps down. Returns false and a reason ("unknown_pet", "already_equipped").
function Pets.equip(state: State, config: Config, instanceId: number): (boolean, string?)
	if find(state, instanceId) == nil then
		return false, "unknown_pet"
	end
	if table.find(state.equipped, instanceId) ~= nil then
		return false, "already_equipped"
	end
	table.insert(state.equipped, instanceId)
	while #state.equipped > config.slots do
		table.remove(state.equipped, 1)
	end
	return true, nil
end

function Pets.unequip(state: State, instanceId: number): boolean
	local index = table.find(state.equipped, instanceId)
	if index == nil then
		return false
	end
	table.remove(state.equipped, index)
	return true
end

-- The combined bonus of the working pets (at most `slots` of them); nil without pets.
function Pets.effectOf(state: State, config: Config): Modifiers.Part?
	local total: { [string]: number } = {}
	local count = 0
	for _, instanceId in state.equipped do
		if count >= config.slots then
			break
		end
		local pet = find(state, instanceId)
		local def = if pet ~= nil then config.pets[pet.petId] else nil
		if def ~= nil then
			count += 1
			for field, value in def.effect do
				total[field] = (total[field] or 0) + value
			end
		end
	end
	if count == 0 then
		return nil
	end
	return total :: any
end

function Pets.hasReceipt(state: State, purchaseId: string): boolean
	return table.find(state.receipts, purchaseId) ~= nil
end

-- Handles one purchase receipt: gives one egg per purchase id. A known purchase
-- id is "duplicate" and changes nothing, so Roblox may retry a receipt as often
-- as it wants. Paid eggs are never refused for a full collection; they wait.
function Pets.processReceipt(state: State, config: Config, purchaseId: string, productId: number): ReceiptOutcome
	if type(purchaseId) ~= "string" or purchaseId == "" or type(productId) ~= "number" then
		return "bad_receipt"
	end
	if Pets.hasReceipt(state, purchaseId) then
		return "duplicate"
	end
	if productId <= 0 or productId ~= config.egg.productId then
		return "unknown_product"
	end
	state.eggs += 1
	table.insert(state.receipts, purchaseId)
	while #state.receipts > config.receiptHistory do
		table.remove(state.receipts, 1)
	end
	return "granted"
end

-- Seconds until the next free egg; 0 when it can be claimed now.
function Pets.secondsUntilFree(state: State, config: Config, now: number): number
	if state.freeEggAt <= 0 then
		return 0
	end
	return math.max(0, state.freeEggAt + config.freeEgg.cooldownSeconds - now)
end

-- The free egg for restricted players. Returns true when it was given, else
-- false and a reason ("not_restricted", "cooldown").
function Pets.claimFree(state: State, config: Config, restricted: boolean, now: number): (boolean, string?)
	if not restricted then
		return false, "not_restricted"
	end
	if Pets.secondsUntilFree(state, config, now) > 0 then
		return false, "cooldown"
	end
	state.eggs += 1
	state.freeEggAt = now
	return true, nil
end

function Pets.view(state: State, config: Config, now: number, available: boolean, restricted: boolean): View
	local owned: { PetRow } = {}
	for _, pet in state.owned do
		local def = config.pets[pet.petId]
		-- A pet that was removed from the config stays in the profile but is not shown.
		if def ~= nil then
			table.insert(owned, {
				instanceId = pet.id,
				petId = pet.petId,
				rarityId = def.rarity,
				effect = def.effect,
				equipped = table.find(state.equipped, pet.id) ~= nil,
			})
		end
	end
	local free: FreeView? = nil
	if restricted then
		local untilFree = Pets.secondsUntilFree(state, config, now)
		free = { canClaim = untilFree <= 0, secondsUntil = untilFree }
	end
	return {
		available = available,
		restricted = restricted,
		eggs = state.eggs,
		slots = config.slots,
		owned = owned,
		maxOwned = config.maxOwned,
		egg = if restricted then nil else { robux = config.egg.robux, buyable = config.egg.productId > 0 },
		free = free,
		eggsUntilGuarantee = Pets.eggsUntilGuarantee(state, config),
	}
end

function Pets.snapshot(state: State, config: Config, now: number, available: boolean, restricted: boolean): Snapshot
	return {
		view = Pets.view(state, config, now, available, restricted),
		rarities = Pets.rarityRows(config),
		pets = Pets.petRows(config),
		pityAfter = config.pity.afterEggs,
		pityRarity = config.pity.minRarity,
	}
end

return Pets
