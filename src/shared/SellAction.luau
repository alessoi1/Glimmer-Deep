--!strict
-- Pure logic of one sell action: empties the sellable part of the backpack and
-- pays the coins into the profile. No Roblox services and no logging; the
-- SellService decides who may sell and logs the outcome. Server-side only use.

local Onboarding = require("./Onboarding")
local Selling = require("./Selling")

-- Structural subset of ProfileData.Profile (the profile is changed in place).
export type SellerProfile = {
	coins: number,
	backpack: Selling.Sellable,
	depot: Selling.Sellable,
	onboarding: Onboarding.State,
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
	local fromBackpack = Selling.sellAll(profile.backpack, oreValues, oreMultiplier)
	local fromDepot = Selling.sellAll(profile.depot, oreValues, oreMultiplier)
	local oreCount = fromBackpack.oreCount + fromDepot.oreCount
	local findCount = fromBackpack.findCount + fromDepot.findCount
	local unknownOres = fromBackpack.unknownOres
	for oreId, count in fromDepot.unknownOres do
		unknownOres[oreId] = (unknownOres[oreId] or 0) + count
	end

	if oreCount == 0 and findCount == 0 then
		return {
			ok = false,
			reason = "empty",
			coinsEarned = 0,
			oreCount = 0,
			findCount = 0,
			unknownOres = unknownOres,
		}
	end

	local coins = fromBackpack.coins + fromDepot.coins
	profile.coins += coins
	Onboarding.advance(profile.onboarding, "sold")
	return {
		ok = true,
		reason = nil,
		coinsEarned = coins,
		oreCount = oreCount,
		findCount = findCount,
		unknownOres = unknownOres,
	}
end

return SellAction
