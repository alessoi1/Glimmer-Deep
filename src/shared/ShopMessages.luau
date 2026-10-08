--!strict
-- Pure text building for the shop panel. The texts stay neutral ("Angebot
-- ansehen"), never pushy. No Roblox services; the client displays what this
-- returns.

local SellMessages = require("./SellMessages")

export type Strings = {
	shop: {
		pass: { [string]: { name: string, description: string } },
		price: string,
		viewOffer: string,
		owned: string,
		soon: string,
		travelDone: string,
		notAvailable: string,
		cooldown: string,
		unknown: string,
	},
}

-- Structural subset of ShopLogic.PassView.
export type PassState = { owned: boolean, buyable: boolean }

local ShopMessages = {}

function ShopMessages.passName(strings: Strings, key: string): string
	local entry = strings.shop.pass[key]
	return if entry ~= nil then entry.name else key
end

function ShopMessages.passDescription(strings: Strings, key: string): string
	local entry = strings.shop.pass[key]
	return if entry ~= nil then entry.description else ""
end

function ShopMessages.priceText(strings: Strings, robux: number): string
	return string.format(strings.shop.price, SellMessages.formatCoins(robux))
end

function ShopMessages.actionText(strings: Strings, pass: PassState): string
	if pass.owned then
		return strings.shop.owned
	elseif pass.buyable then
		return strings.shop.viewOffer
	end
	return strings.shop.soon
end

-- Message after a shop action; unknown reasons give a neutral text.
function ShopMessages.describeResult(strings: Strings, ok: boolean, reason: string?): string
	if ok then
		return strings.shop.travelDone
	elseif reason == "not_available" then
		return strings.shop.notAvailable
	elseif reason == "cooldown" then
		return strings.shop.cooldown
	end
	return strings.shop.unknown
end

return ShopMessages
