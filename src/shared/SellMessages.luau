--!strict
-- Pure text building for the sell UI: turns results into German player texts
-- using Strings. No Roblox services; the client displays what this returns.

export type Strings = {
	sold: string,
	empty: string,
	tooFar: string,
	unknown: string,
}

local SellMessages = {}

-- Whole coins with a dot as thousands separator, for example "1.234.567".
function SellMessages.formatCoins(coins: number): string
	local text = string.format("%d", math.floor(coins))
	local formatted = text
	while true do
		local replaced, count = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1.%2")
		formatted = replaced
		if count == 0 then
			break
		end
	end
	return formatted
end

function SellMessages.describeSale(strings: Strings, coinsEarned: number): string
	return string.format(strings.sold, SellMessages.formatCoins(coinsEarned))
end

-- Text for a rejected sale; unknown reasons give a neutral text.
function SellMessages.describeFailure(strings: Strings, reason: string): string
	if reason == "empty" then
		return strings.empty
	elseif reason == "too_far" then
		return strings.tooFar
	end
	return strings.unknown
end

return SellMessages
