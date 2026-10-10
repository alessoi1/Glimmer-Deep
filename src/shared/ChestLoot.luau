--!strict
-- Pure loot of the chests in the cave: what a chest holds (rolled by the
-- server), the chances shown to the player, and how the items are put into the
-- profile. No Roblox services and no logging; the CaveService opens the chest
-- and logs. Chests are never for sale and never need Robux.

local Equipment = require("./Equipment")
local Potions = require("./Potions")

export type Rng = () -> number -- returns a number in [0, 1)

export type Range = { min: number, max: number }

export type Config = {
	rolls: Range,
	entries: { { kind: string, weight: number } },
	gearBonusChance: number,
	herbCount: Range,
	potionCount: Range,
	coinBase: number,
	coinGrowth: number,
}

export type Deps = {
	equipment: Equipment.Config,
	potions: Potions.Config,
}

export type Entry = {
	kind: string, -- "gear" | "potion" | "herb" | "coins" | "find"
	slot: string?,
	tier: number?,
	id: string?,
	count: number?,
	amount: number?,
}

export type Chance = { kind: string, percent: number }

-- The fields of a rolled rare find (see DigRoll.BlockResult).
export type FindBlock = {
	layerId: string,
	findId: string?,
	rarityId: string?,
	mutationId: string?,
	value: number?,
}

export type StoredFind = {
	id: number?,
	findId: string,
	layerId: string,
	rarityId: string,
	mutationId: string?,
	value: number,
}

-- Structural subset of ProfileData.Profile (changed in place).
export type Target = {
	coins: number,
	nextFindId: number,
	depot: {
		ores: { [string]: number },
		finds: { StoredFind },
	},
	stash: { ores: { [string]: number } },
	gear: Equipment.State,
	potions: Potions.State,
}

export type Summary = {
	coins: number, -- coins from coin items and from paid-out items
	gear: { Equipment.Gear },
	potions: { [string]: number },
	herbs: { [string]: number },
	finds: { StoredFind },
	converted: number, -- coins given instead of items that did not fit
}

local KINDS: { [string]: boolean } = { gear = true, potion = true, herb = true, coins = true, find = true }
local PERCENT = 100

local ChestLoot = {}

local function pickInRange(range: Range, roll: number): number
	return range.min + math.min(math.floor(roll * (range.max - range.min + 1)), range.max - range.min)
end

local function pickIndex(count: number, roll: number): number
	return math.min(math.floor(roll * count) + 1, count)
end

local function totalWeight(config: Config): number
	local total = 0
	for _, entry in config.entries do
		total += entry.weight
	end
	return total
end

-- The chance of each kind in percent (adds up to 100), for the info window.
function ChestLoot.chances(config: Config): { Chance }
	local total = totalWeight(config)
	local chances: { Chance } = {}
	for _, entry in config.entries do
		table.insert(chances, { kind = entry.kind, percent = entry.weight / total * PERCENT })
	end
	return chances
end

-- Rolls the content of one chest in the biome with the given number (1 for the
-- first biome). Draw order: number of items; then for each item its kind, and
-- gear: slot, bonus; potion: potion, count; herb: herb, count (coins and finds
-- draw nothing).
function ChestLoot.roll(config: Config, deps: Deps, biomeIndex: number, herbs: { string }, rng: Rng): { Entry }
	local entries: { Entry } = {}
	local count = pickInRange(config.rolls, rng())
	local total = totalWeight(config)
	for _ = 1, count do
		local target = rng() * total
		local kind = config.entries[#config.entries].kind
		local accumulated = 0
		for _, candidate in config.entries do
			accumulated += candidate.weight
			if target < accumulated then
				kind = candidate.kind
				break
			end
		end

		if kind == "gear" then
			local slot = deps.equipment.slots[pickIndex(#deps.equipment.slots, rng())]
			local bonus = if rng() * PERCENT < config.gearBonusChance then 1 else 0
			local tier = math.clamp(biomeIndex + bonus, 1, #deps.equipment.tiers)
			table.insert(entries, { kind = "gear", slot = slot, tier = tier })
		elseif kind == "potion" then
			local id = deps.potions.order[pickIndex(#deps.potions.order, rng())]
			table.insert(entries, { kind = "potion", id = id, count = pickInRange(config.potionCount, rng()) })
		elseif kind == "herb" then
			local id = herbs[pickIndex(#herbs, rng())]
			table.insert(entries, { kind = "herb", id = id, count = pickInRange(config.herbCount, rng()) })
		elseif kind == "coins" then
			table.insert(entries, { kind = "coins", amount = config.coinBase * config.coinGrowth ^ (biomeIndex - 1) })
		else
			table.insert(entries, { kind = "find" })
		end
	end
	return entries
end

-- Puts the rolled items into the profile. Nothing is lost: gear and potions that
-- do not fit (too many owned) are paid out as coins. Entries that are unknown
-- or malformed are ignored. `rollFind` returns a rare find for a find entry.
function ChestLoot.apply(target: Target, entries: { Entry }, deps: Deps, rollFind: () -> FindBlock): Summary
	local summary: Summary = { coins = 0, gear = {}, potions = {}, herbs = {}, finds = {}, converted = 0 }

	local function pay(amount: number, fromConversion: boolean)
		target.coins += amount
		summary.coins += amount
		if fromConversion then
			summary.converted += amount
		end
	end

	for _, entry in entries do
		if not KINDS[entry.kind] then
			continue
		end
		if entry.kind == "coins" then
			local amount = entry.amount
			if amount ~= nil and amount > 0 and amount % 1 == 0 then
				pay(amount, false)
			end
		elseif entry.kind == "gear" then
			local slot, tier = entry.slot, entry.tier
			local cost = if slot ~= nil and tier ~= nil then Equipment.cost(deps.equipment, slot, tier) else nil
			if slot ~= nil and tier ~= nil and cost ~= nil then
				local gear = Equipment.grant(target.gear, deps.equipment, slot, tier, "chest")
				if gear ~= nil then
					table.insert(summary.gear, gear)
				else
					pay(cost.coins, true)
				end
			end
		elseif entry.kind == "potion" then
			local id, count = entry.id, entry.count
			local def = if id ~= nil then deps.potions.potions[id] else nil
			if id ~= nil and def ~= nil and count ~= nil and count >= 1 then
				local owned = target.potions.owned[id] or 0
				local fits = math.min(count, deps.potions.maxOwnedPerPotion - owned)
				if fits > 0 then
					target.potions.owned[id] = owned + fits
					summary.potions[id] = (summary.potions[id] or 0) + fits
				end
				if count - fits > 0 then
					pay(def.coins * (count - fits), true)
				end
			end
		elseif entry.kind == "herb" then
			local id, count = entry.id, entry.count
			if id ~= nil and count ~= nil and count >= 1 then
				target.stash.ores[id] = (target.stash.ores[id] or 0) + count
				summary.herbs[id] = (summary.herbs[id] or 0) + count
			end
		else
			local block = rollFind()
			if block.findId ~= nil and block.rarityId ~= nil and block.value ~= nil then
				local find = {
					id = target.nextFindId,
					findId = block.findId,
					layerId = block.layerId,
					rarityId = block.rarityId,
					mutationId = block.mutationId,
					value = block.value,
				}
				target.nextFindId += 1
				table.insert(target.depot.finds, find)
				table.insert(summary.finds, find)
			end
		end
	end
	return summary
end

-- Returns true when the config is usable, otherwise false and a reason.
function ChestLoot.validateConfig(config: Config): (boolean, string?)
	for name, range in { rolls = config.rolls, herbCount = config.herbCount, potionCount = config.potionCount } do
		if
			type(range.min) ~= "number"
			or type(range.max) ~= "number"
			or range.min < 1
			or range.min > range.max
			or range.min % 1 ~= 0
			or range.max % 1 ~= 0
		then
			return false, name .. " needs integers with 1 <= min <= max"
		end
	end
	if #config.entries == 0 then
		return false, "no entries"
	end
	for _, entry in config.entries do
		if not KINDS[entry.kind] then
			return false, "unknown loot kind " .. tostring(entry.kind)
		end
		if not (entry.weight > 0) then
			return false, "weight of " .. entry.kind .. " must be positive"
		end
	end
	if not (config.gearBonusChance >= 0 and config.gearBonusChance <= 100) then
		return false, "gearBonusChance must be a percentage"
	end
	if not (config.coinBase >= 1) or config.coinBase % 1 ~= 0 then
		return false, "coinBase must be a positive integer"
	end
	if not (config.coinGrowth >= 1) or config.coinGrowth % 1 ~= 0 then
		return false, "coinGrowth must be a positive integer"
	end
	return true, nil
end

return ChestLoot
