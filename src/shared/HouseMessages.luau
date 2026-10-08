--!strict
-- Pure text building for the house panel. No Roblox services; the client
-- displays what this returns.

local SellMessages = require("./SellMessages")

export type Strings = {
	house: {
		item: { [string]: string },
		levelName: { [string]: string },
		levelLine: string,
		upgradeLine: string,
		maxLevel: string,
		coinsPrice: string,
		slotLine: string,
		upgraded: string,
		bought: string,
		placed: string,
		removed: string,
		notEnoughCoins: string,
		noDecorYet: string,
		alreadyOwned: string,
		unknown: string,
	},
}

local HouseMessages = {}

function HouseMessages.itemName(strings: Strings, id: string): string
	return strings.house.item[id] or id
end

-- "Haus: Stufe 2 (Werkstatt-Haus)"; an unnamed level shows only the number.
function HouseMessages.levelText(strings: Strings, level: number): string
	local name = strings.house.levelName[tostring(level)]
	return string.format(strings.house.levelLine, level, name or "")
end

function HouseMessages.priceText(strings: Strings, coins: number): string
	return string.format(strings.house.coinsPrice, SellMessages.formatCoins(coins))
end

-- "Ausbauen auf Stufe 2: 10.000 Münzen" or the maximum text.
function HouseMessages.upgradeText(strings: Strings, level: number, nextCost: number?): string
	if nextCost == nil then
		return strings.house.maxLevel
	end
	return string.format(strings.house.upgradeLine, level + 1, SellMessages.formatCoins(nextCost))
end

function HouseMessages.slotsText(strings: Strings, used: number, slots: number): string
	return string.format(strings.house.slotLine, used, slots)
end

-- Message after a house action; unknown reasons give a neutral text.
function HouseMessages.describeResult(strings: Strings, ok: boolean, reason: string?): string
	if ok then
		return ""
	elseif reason == "not_enough_coins" then
		return strings.house.notEnoughCoins
	elseif reason == "no_decor_yet" then
		return strings.house.noDecorYet
	elseif reason == "already_owned" then
		return strings.house.alreadyOwned
	end
	return strings.house.unknown
end

return HouseMessages
