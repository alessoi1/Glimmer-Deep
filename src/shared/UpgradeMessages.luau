--!strict
-- Pure text building for the upgrade UI: turns upgrade entries and results into
-- German player texts using Strings. No Roblox services; the client displays
-- what this returns.

local SellMessages = require("./SellMessages")

export type Strings = {
	upgrade: { [string]: string }, -- upgrade id -> name
	shovel: { [string]: string }, -- shovel level id -> name
	upgrades: {
		offer: string,
		maxed: string,
		capacity: string,
		blocksPerHour: string,
		level: string,
		bought: string,
		notEnoughCoins: string,
		maxLevel: string,
		unknown: string,
	},
}

-- Structural subset of UpgradeAction.Entry.
export type Entry = {
	id: string,
	level: number,
	nextPrice: number?,
	nextId: string?,
	nextCapacity: number?,
	nextBlocksPerHour: number?,
}

local UpgradeMessages = {}

local function nameOf(names: { [string]: string }, id: string): string
	return names[id] or id
end

-- What the next level brings: the shovel name, the backpack capacity or the level number.
local function describeNext(strings: Strings, entry: Entry): string
	if entry.nextId ~= nil then
		return nameOf(strings.shovel, entry.nextId)
	elseif entry.nextCapacity ~= nil then
		return string.format(strings.upgrades.capacity, entry.nextCapacity)
	elseif entry.nextBlocksPerHour ~= nil then
		return string.format(strings.upgrades.blocksPerHour, entry.nextBlocksPerHour)
	end
	return string.format(strings.upgrades.level, entry.level + 1)
end

-- Button text for one upgrade, for example "Schaufel: Steinschaufel (100 Münzen)".
function UpgradeMessages.describeOffer(strings: Strings, entry: Entry): string
	local name = nameOf(strings.upgrade, entry.id)
	if entry.nextPrice == nil then
		return string.format(strings.upgrades.maxed, name)
	end
	return string.format(
		strings.upgrades.offer,
		name,
		describeNext(strings, entry),
		SellMessages.formatCoins(entry.nextPrice)
	)
end

-- Message after a purchase attempt; unknown reasons give a neutral text.
function UpgradeMessages.describeResult(strings: Strings, ok: boolean, upgradeId: string?, reason: string?): string
	if ok and upgradeId ~= nil then
		return string.format(strings.upgrades.bought, nameOf(strings.upgrade, upgradeId))
	elseif reason == "not_enough_coins" then
		return strings.upgrades.notEnoughCoins
	elseif reason == "max_level" then
		return strings.upgrades.maxLevel
	end
	return strings.upgrades.unknown
end

return UpgradeMessages
