--!strict
-- Pure logic of buying an upgrade and of listing the upgrades for display.
-- Wraps Upgrades.purchase for the profile and validates the id that comes from
-- the client. No Roblox services and no logging; the UpgradeService decides who
-- may buy and logs the outcome. Server-side only use for buying.

local Onboarding = require("./Onboarding")
local Upgrades = require("./Upgrades")

-- Level definitions as in Config/Shovel and Config/Backpack: the price is
-- required, id (shovel) and capacity (backpack) are only used for display.
export type Level = { price: number, id: string?, capacity: number? }
export type Tracks = { [string]: { levels: { Level } } }

-- Structural subset of ProfileData.Profile (the profile is changed in place).
export type UpgraderProfile = {
	coins: number,
	upgradeLevels: { [string]: number },
	onboarding: Onboarding.State,
}

export type FailureReason = Upgrades.FailureReason | "bad_id"

export type BuyResult = {
	ok: boolean,
	reason: FailureReason?,
	price: number?,
	newLevel: number?,
}

-- What the client needs to show one upgrade: it never computes prices itself.
export type Entry = {
	id: string,
	level: number,
	maxLevel: number,
	nextPrice: number?, -- nil when maxed
	nextId: string?,
	nextCapacity: number?,
	canAfford: boolean,
}

local UpgradeAction = {}

-- Buys the next level of an upgrade. `upgradeId` is untrusted input from the
-- client. On failure the profile is left untouched.
function UpgradeAction.buy(profile: UpgraderProfile, tracks: Upgrades.Tracks, upgradeId: any): BuyResult
	if type(upgradeId) ~= "string" then
		return { ok = false, reason = "bad_id" }
	end

	local state: Upgrades.State = { coins = profile.coins, levels = profile.upgradeLevels }
	local result = Upgrades.purchase(state, tracks, upgradeId)
	if result.ok then
		profile.coins = state.coins
		Onboarding.advance(profile.onboarding, "upgraded")
	end
	return result
end

-- Read-only view of the given upgrades in the given order; unknown ids are skipped.
function UpgradeAction.snapshot(profile: UpgraderProfile, tracks: Tracks, order: { string }): { Entry }
	local entries: { Entry } = {}
	for _, upgradeId in order do
		local track = tracks[upgradeId]
		local level = profile.upgradeLevels[upgradeId]
		if track ~= nil and level ~= nil then
			local nextLevel = track.levels[level + 1]
			table.insert(entries, {
				id = upgradeId,
				level = level,
				maxLevel = #track.levels,
				nextPrice = if nextLevel ~= nil then nextLevel.price else nil,
				nextId = if nextLevel ~= nil then nextLevel.id else nil,
				nextCapacity = if nextLevel ~= nil then nextLevel.capacity else nil,
				canAfford = nextLevel ~= nil and profile.coins >= nextLevel.price,
			})
		end
	end
	return entries
end

return UpgradeAction
