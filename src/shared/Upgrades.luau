--!strict
-- Pure upgrade purchase logic for level-based upgrades (shovel, backpack).
-- The client only sends an upgrade id; price and level come from config here.
-- No Roblox services; the server applies and persists the resulting state.

export type Tracks = { [string]: { levels: { { price: number } } } }

export type State = {
	coins: number,
	levels: { [string]: number }, -- upgrade id -> current level (starts at 1)
}

export type FailureReason = "unknown_upgrade" | "invalid_state" | "max_level" | "not_enough_coins"

export type PurchaseResult = {
	ok: boolean,
	reason: FailureReason?,
	price: number?,
	newLevel: number?,
}

local Upgrades = {}

local function isInteger(value: number): boolean
	return value == value and value > -math.huge and value < math.huge and value % 1 == 0
end

-- Current level when the state is consistent for this track, otherwise nil.
local function readLevel(state: State, upgradeId: string, levelCount: number): number?
	if not isInteger(state.coins) or state.coins < 0 then
		return nil
	end
	local level = state.levels[upgradeId]
	if level == nil or not isInteger(level) or level < 1 or level > levelCount then
		return nil
	end
	return level
end

-- Buys the next level of an upgrade. On success the price is deducted and the
-- level raised in `state`; on failure `state` is left untouched.
function Upgrades.purchase(state: State, tracks: Tracks, upgradeId: string): PurchaseResult
	local track = tracks[upgradeId]
	if track == nil then
		return { ok = false, reason = "unknown_upgrade" }
	end

	local level = readLevel(state, upgradeId, #track.levels)
	if level == nil then
		return { ok = false, reason = "invalid_state" }
	end
	if level >= #track.levels then
		return { ok = false, reason = "max_level" }
	end

	local price = track.levels[level + 1].price
	if state.coins < price then
		return { ok = false, reason = "not_enough_coins", price = price }
	end

	state.coins -= price
	state.levels[upgradeId] = level + 1
	return { ok = true, price = price, newLevel = level + 1 }
end

-- Price of the next level for display, or nil when unknown, maxed or the state is invalid.
function Upgrades.getNextPrice(state: State, tracks: Tracks, upgradeId: string): number?
	local track = tracks[upgradeId]
	if track == nil then
		return nil
	end
	local level = readLevel(state, upgradeId, #track.levels)
	if level == nil or level >= #track.levels then
		return nil
	end
	return track.levels[level + 1].price
end

-- Each track needs a free first level and strictly increasing integer prices.
function Upgrades.validateTracks(tracks: Tracks): (boolean, string?)
	for upgradeId, track in tracks do
		if #track.levels == 0 then
			return false, upgradeId .. " has no levels"
		end
		if track.levels[1].price ~= 0 then
			return false, upgradeId .. " level 1 must be free"
		end
		local previous = -1
		for index, level in track.levels do
			if not isInteger(level.price) or level.price <= previous then
				return false, string.format("%s level %d needs a higher integer price", upgradeId, index)
			end
			previous = level.price
		end
	end
	return true, nil
end

return Upgrades
