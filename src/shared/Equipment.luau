--!strict
-- Pure equipment logic: pieces of armor and weapons, crafting from stored ore,
-- the stats they give and the rules for trading. No Roblox services and no
-- logging; the ForgeService decides who may do what and logs the outcome.

export type TierDef = { id: string, ore: string, life: number, damage: number }

export type Config = {
	slots: { string },
	weaponSlot: string,
	baseLife: number,
	baseDamage: number,
	tiers: { TierDef },
	lifeShare: { [string]: number },
	oreCost: { [string]: number },
	coinCost: { [string]: number },
	coinGrowth: number,
	shopMaxTier: number,
	maxOwned: number,
}

export type Source = "crafted" | "chest" | "shop"

export type Gear = {
	id: number, -- unique within the profile (globally: userId:id)
	slot: string,
	tier: number,
	source: Source,
	bound: boolean, -- account-bound pieces cannot be traded
}

export type State = {
	owned: { Gear },
	equipped: { [string]: number }, -- slot -> gear id
	nextId: number,
}

export type Stats = { life: number, damage: number, strength: number }

export type Cost = { ore: string, oreCount: number, coins: number }

export type Stash = { ores: { [string]: number } }
export type Wallet = { coins: number }

export type FailureReason =
	"unknown_slot"
	| "unknown_tier"
	| "not_enough_ore"
	| "not_enough_coins"
	| "too_many_items"
	| "not_owned"
	| "nothing_equipped"

export type Result = { ok: boolean, reason: FailureReason?, gear: Gear? }

local SOURCES: { [string]: boolean } = { crafted = true, chest = true, shop = true }
local SHARE_TOLERANCE = 1e-9

local Equipment = {}

local function isInteger(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge and value % 1 == 0
end

local function hasSlot(config: Config, slot: any): boolean
	return type(slot) == "string" and table.find(config.slots, slot) ~= nil
end

function Equipment.new(): State
	return { owned = {}, equipped = {}, nextId = 1 }
end

local function findOwned(state: State, gearId: number): Gear?
	for _, gear in state.owned do
		if gear.id == gearId then
			return gear
		end
	end
	return nil
end

function Equipment.strengthOf(life: number, damage: number): number
	return life * damage
end

function Equipment.stats(state: State, config: Config): Stats
	local life = config.baseLife
	local damage = config.baseDamage
	for slot, gearId in state.equipped do
		local gear = findOwned(state, gearId)
		local tier = if gear then config.tiers[gear.tier] else nil
		if gear ~= nil and tier ~= nil then
			if slot == config.weaponSlot then
				damage = tier.damage
			else
				life += tier.life * (config.lifeShare[slot] or 0)
			end
		end
	end
	return { life = life, damage = damage, strength = Equipment.strengthOf(life, damage) }
end

-- Ore and coins needed for a piece, or nil for an unknown slot or tier.
function Equipment.cost(config: Config, slot: string, tier: number): Cost?
	local def = if isInteger(tier) then config.tiers[tier] else nil
	local oreCount = config.oreCost[slot]
	local baseCoins = config.coinCost[slot]
	if def == nil or oreCount == nil or baseCoins == nil then
		return nil
	end
	return { ore = def.ore, oreCount = oreCount, coins = baseCoins * config.coinGrowth ^ (tier - 1) }
end

-- Adds a piece without paying (chest loot, shop package, crafting after payment).
-- Returns nil for an unknown slot or tier, for a shop piece above the shop cap,
-- or when the player owns too many pieces.
function Equipment.grant(state: State, config: Config, slot: string, tier: number, source: Source): Gear?
	if not hasSlot(config, slot) or not isInteger(tier) or config.tiers[tier] == nil then
		return nil
	end
	if source == "shop" and tier > config.shopMaxTier then
		return nil
	end
	if #state.owned >= config.maxOwned then
		return nil
	end
	local gear: Gear = { id = state.nextId, slot = slot, tier = tier, source = source, bound = source == "shop" }
	state.nextId += 1
	table.insert(state.owned, gear)
	return gear
end

-- Pays with stashed ore and coins and adds the piece. On failure nothing changes.
function Equipment.craft(state: State, stash: Stash, wallet: Wallet, config: Config, slot: string, tier: number): Result
	if not hasSlot(config, slot) then
		return { ok = false, reason = "unknown_slot" }
	end
	local cost = Equipment.cost(config, slot, tier)
	if cost == nil then
		return { ok = false, reason = "unknown_tier" }
	end
	if #state.owned >= config.maxOwned then
		return { ok = false, reason = "too_many_items" }
	end
	if (stash.ores[cost.ore] or 0) < cost.oreCount then
		return { ok = false, reason = "not_enough_ore" }
	end
	if wallet.coins < cost.coins then
		return { ok = false, reason = "not_enough_coins" }
	end

	local gear = Equipment.grant(state, config, slot, tier, "crafted")
	if gear == nil then
		return { ok = false, reason = "unknown_tier" }
	end
	local left = (stash.ores[cost.ore] :: number) - cost.oreCount
	stash.ores[cost.ore] = if left > 0 then left else nil
	wallet.coins -= cost.coins
	return { ok = true, gear = gear }
end

-- Moves the ore that armor and weapons are made of from the backpack to the
-- stash. Other ore and herbs stay (they are for selling). Returns the amount.
function Equipment.deposit(backpackOres: { [string]: number }, stash: Stash, config: Config): number
	local moved = 0
	for _, tier in config.tiers do
		local count = backpackOres[tier.ore]
		if count ~= nil and count > 0 then
			stash.ores[tier.ore] = (stash.ores[tier.ore] or 0) + count
			backpackOres[tier.ore] = nil
			moved += count
		end
	end
	return moved
end

function Equipment.equip(state: State, gearId: number): Result
	local gear = findOwned(state, gearId)
	if gear == nil then
		return { ok = false, reason = "not_owned" }
	end
	state.equipped[gear.slot] = gear.id
	return { ok = true, gear = gear }
end

function Equipment.unequip(state: State, config: Config, slot: string): Result
	if not hasSlot(config, slot) then
		return { ok = false, reason = "unknown_slot" }
	end
	if state.equipped[slot] == nil then
		return { ok = false, reason = "nothing_equipped" }
	end
	state.equipped[slot] = nil
	return { ok = true }
end

function Equipment.tradable(gear: Gear): boolean
	return not gear.bound
end

-- Returns true when the config is usable, otherwise false and a reason.
function Equipment.validateConfig(config: Config): (boolean, string?)
	if #config.slots == 0 then
		return false, "no slots"
	end
	local seenSlots: { [string]: boolean } = {}
	for _, slot in config.slots do
		if seenSlots[slot] then
			return false, "duplicate slot " .. slot
		end
		seenSlots[slot] = true
	end
	if not seenSlots[config.weaponSlot] then
		return false, "weaponSlot must be one of the slots"
	end
	if not (config.baseLife > 0 and config.baseDamage > 0) then
		return false, "baseLife and baseDamage must be positive"
	end
	if #config.tiers == 0 then
		return false, "no tiers"
	end
	local previousLife, previousDamage = 0, 0
	local seenIds: { [string]: boolean } = {}
	for index, tier in config.tiers do
		if seenIds[tier.id] then
			return false, "duplicate tier " .. tier.id
		end
		seenIds[tier.id] = true
		if not (tier.life > previousLife and tier.damage > previousDamage) then
			return false, string.format("tier %d must give more life and damage than tier %d", index, index - 1)
		end
		previousLife, previousDamage = tier.life, tier.damage
	end
	local shareSum = 0
	for _, slot in config.slots do
		if slot ~= config.weaponSlot then
			local share = config.lifeShare[slot]
			if share == nil or not (share > 0) then
				return false, "lifeShare needs a positive share for " .. slot
			end
			shareSum += share
		end
		local ore, coins = config.oreCost[slot], config.coinCost[slot]
		if ore == nil or not isInteger(ore) or ore < 1 then
			return false, "oreCost needs a positive integer for " .. slot
		end
		if coins == nil or not isInteger(coins) or coins < 0 then
			return false, "coinCost needs a non-negative integer for " .. slot
		end
	end
	if math.abs(shareSum - 1) > SHARE_TOLERANCE then
		return false, "lifeShare must add up to 1"
	end
	if not isInteger(config.coinGrowth) or config.coinGrowth < 1 then
		return false, "coinGrowth must be a positive integer"
	end
	if not isInteger(config.shopMaxTier) or config.shopMaxTier < 0 or config.shopMaxTier > #config.tiers then
		return false, "shopMaxTier must be from 0 to the number of tiers"
	end
	if not isInteger(config.maxOwned) or config.maxOwned < #config.slots then
		return false, "maxOwned must be at least the number of slots"
	end
	return true, nil
end

-- Returns true when the stored equipment is consistent, otherwise false and a reason.
function Equipment.validate(state: any, config: Config): (boolean, string?)
	if type(state) ~= "table" or type(state.owned) ~= "table" or type(state.equipped) ~= "table" then
		return false, "equipment needs owned, equipped and nextId"
	end
	if not isInteger(state.nextId) or state.nextId < 1 then
		return false, "nextId must be a positive integer"
	end
	if #state.owned > config.maxOwned then
		return false, "too many pieces"
	end
	local byId: { [number]: any } = {}
	for _, gear in state.owned do
		if type(gear) ~= "table" or not isInteger(gear.id) or gear.id < 1 or gear.id >= state.nextId then
			return false, "a piece has an invalid id"
		end
		if byId[gear.id] ~= nil then
			return false, "duplicate piece id " .. gear.id
		end
		byId[gear.id] = gear
		if not hasSlot(config, gear.slot) then
			return false, "piece " .. gear.id .. " has an unknown slot"
		end
		if not isInteger(gear.tier) or config.tiers[gear.tier] == nil then
			return false, "piece " .. gear.id .. " has an invalid tier"
		end
		if SOURCES[gear.source] ~= true then
			return false, "piece " .. gear.id .. " has an unknown source"
		end
		if type(gear.bound) ~= "boolean" or gear.bound ~= (gear.source == "shop") then
			return false, "piece " .. gear.id .. ": only shop pieces are bound"
		end
		if gear.source == "shop" and gear.tier > config.shopMaxTier then
			return false, "shop piece " .. gear.id .. " is above the shop tier cap"
		end
	end
	for slot, gearId in state.equipped do
		if not hasSlot(config, slot) then
			return false, "equipped has an unknown slot"
		end
		local gear = byId[gearId]
		if gear == nil or gear.slot ~= slot then
			return false, "equipped " .. tostring(slot) .. " does not match an owned piece"
		end
	end
	return true, nil
end

return Equipment
