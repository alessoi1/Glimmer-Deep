--!strict
-- Pure text building for the booster section of the shop. Texts stay neutral
-- ("Angebot ansehen"), never pushy. No Roblox services; the client displays
-- what this returns.

local SellMessages = require("./SellMessages")

export type Strings = {
	shop: {
		viewOffer: string,
		soon: string,
		price: string,
		boosters: {
			booster: { [string]: { name: string, description: string } },
			chanceLine: string,
			mutationLine: string,
			running: string,
			durationHours: string,
			durationMinutes: string,
			freeIn: string,
			freeClaim: string,
			granted: string,
			notAvailable: string,
			cooldown: string,
			unknown: string,
		},
	},
	rarity: { [string]: string },
}

-- Structural subsets of Boosters.BoosterView and Boosters.FreeView.
export type BoosterState = { buyable: boolean, remaining: number }
export type FreeState = { canClaim: boolean, secondsUntil: number }

local SECONDS_PER_MINUTE = 60
local MINUTES_PER_HOUR = 60

local BoosterMessages = {}

function BoosterMessages.name(strings: Strings, key: string): string
	local entry = strings.shop.boosters.booster[key]
	return if entry ~= nil then entry.name else key
end

function BoosterMessages.description(strings: Strings, key: string): string
	local entry = strings.shop.boosters.booster[key]
	return if entry ~= nil then entry.description else ""
end

-- "15 Min" or "1 Std 5 Min". Rounds up so a running booster never shows "0 Min".
function BoosterMessages.durationText(strings: Strings, seconds: number): string
	local totalMinutes = math.ceil(seconds / SECONDS_PER_MINUTE)
	local hours = totalMinutes // MINUTES_PER_HOUR
	local minutes = totalMinutes % MINUTES_PER_HOUR
	if hours > 0 then
		return string.format(strings.shop.boosters.durationHours, hours, minutes)
	end
	return string.format(strings.shop.boosters.durationMinutes, minutes)
end

function BoosterMessages.runningText(strings: Strings, seconds: number): string
	return string.format(strings.shop.boosters.running, BoosterMessages.durationText(strings, seconds))
end

-- A percentage with one decimal and a decimal comma: 4.5 -> "4,5".
function BoosterMessages.percentText(percent: number): string
	return (string.gsub(string.format("%.1f", percent), "%.", ","))
end

-- "Selten: 25,0 % -> 27,3 %"; unknown rarities show their id.
function BoosterMessages.chanceLine(strings: Strings, rarityId: string, base: number, boosted: number): string
	return string.format(
		strings.shop.boosters.chanceLine,
		strings.rarity[rarityId] or rarityId,
		BoosterMessages.percentText(base),
		BoosterMessages.percentText(boosted)
	)
end

function BoosterMessages.mutationLine(strings: Strings, base: number, boosted: number): string
	return string.format(
		strings.shop.boosters.mutationLine,
		BoosterMessages.percentText(base),
		BoosterMessages.percentText(boosted)
	)
end

function BoosterMessages.priceText(strings: Strings, robux: number): string
	return string.format(strings.shop.price, SellMessages.formatCoins(robux))
end

function BoosterMessages.actionText(strings: Strings, booster: BoosterState): string
	if booster.buyable then
		return strings.shop.viewOffer
	end
	return strings.shop.soon
end

function BoosterMessages.freeText(strings: Strings, free: FreeState): string
	if free.canClaim then
		return strings.shop.boosters.freeClaim
	end
	return string.format(strings.shop.boosters.freeIn, BoosterMessages.durationText(strings, free.secondsUntil))
end

-- Message after a booster action; unknown reasons give a neutral text.
function BoosterMessages.describeResult(strings: Strings, ok: boolean, reason: string?): string
	if ok then
		return strings.shop.boosters.granted
	elseif reason == "not_available" then
		return strings.shop.boosters.notAvailable
	elseif reason == "cooldown" then
		return strings.shop.boosters.cooldown
	end
	return strings.shop.boosters.unknown
end

return BoosterMessages
