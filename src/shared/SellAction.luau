--!strict
-- Pure logic of one sell action: empties the sellable part of the backpack and
-- pays the coins into the profile. No Roblox services and no logging; the
-- SellService decides who may sell and logs the outcome. Server-side only use.

local Selling = require("./Selling")

-- Structural subset of ProfileData.Profile (the profile is changed in place).
export type SellerProfile = {
	coins: number,
	backpack: Selling.Sellable,
}

export type FailureReason = "empty"

-- On failure nothing was changed. `unknownOres` lists ore that has no price and
-- stayed in the backpack, so the caller can log it.
export type Result = {
	ok: boolean,
	reason: FailureReason?,
	coinsEarned: number,
	oreCount: number,
	findCount: number,
	unknownOres: { [string]: number },
}

local SellAction = {}

-- Sells everything with a known price. oreMultiplier applies to ore only.
function SellAction.perform(profile: SellerProfile, oreValues: Selling.OreValues, oreMultiplier: number?): Result
	local sale = Selling.sellAll(profile.backpack, oreValues, oreMultiplier)
	if sale.oreCount == 0 and sale.findCount == 0 then
		return {
			ok = false,
			reason = "empty",
			coinsEarned = 0,
			oreCount = 0,
			findCount = 0,
			unknownOres = sale.unknownOres,
		}
	end

	profile.coins += sale.coins
	return {
		ok = true,
		reason = nil,
		coinsEarned = sale.coins,
		oreCount = sale.oreCount,
		findCount = sale.findCount,
		unknownOres = sale.unknownOres,
	}
end

return SellAction
