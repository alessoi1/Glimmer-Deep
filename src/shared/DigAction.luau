--!strict
-- Pure logic of one dig action: cooldown, backpack space, block roll, filling
-- the backpack and advancing the depth. No Roblox services and no logging; the
-- DigService decides who may dig and logs the outcome. Server-side only use:
-- the roll and the profile change must never run on the client.

local Backpack = require("./Backpack")
local DigRoll = require("./DigRoll")
local Shovel = require("./Shovel")

export type Rng = DigRoll.Rng

-- Structural subset of ProfileData.Profile (the profile is changed in place).
export type DiggerProfile = {
	depth: number,
	coins: number,
	nextFindId: number,
	upgradeLevels: { [string]: number },
	backpack: {
		ores: { [string]: number },
		finds: { Backpack.Find },
	},
}

export type Params = {
	profile: DiggerProfile,
	digConfig: DigRoll.Config,
	shovelLevels: { Shovel.LevelDef },
	cooldownTolerance: number,
	backpackLevels: { Backpack.LevelDef },
	metersPerBlock: number,
	lastDigAt: number?, -- server time of the last accepted dig, nil for the first
	now: number, -- server time in seconds (sub-second precision)
	rng: Rng,
}

export type FailureReason = "cooldown" | "backpack_full"

-- On failure nothing was changed and `block` is nil. `depth`, `used` and
-- `capacity` always describe the state after the call.
export type Result = {
	ok: boolean,
	reason: FailureReason?,
	block: DigRoll.BlockResult?,
	depth: number,
	used: number,
	capacity: number,
}

export type SnapshotParams = {
	profile: DiggerProfile,
	digConfig: DigRoll.Config,
	shovelLevels: { Shovel.LevelDef },
	backpackLevels: { Backpack.LevelDef },
}

-- What the client needs to show: it never computes game values itself.
export type State = {
	depth: number,
	coins: number,
	layerId: string,
	used: number,
	capacity: number,
	digCooldown: number, -- seconds between digs with the current shovel
}

local SHOVEL_UPGRADE = "shovel"
local BACKPACK_UPGRADE = "backpack"

local DigAction = {}

function DigAction.perform(params: Params): Result
	local profile = params.profile

	-- Shares the profile's tables, so adding a block changes the profile.
	local backpack: Backpack.Backpack = {
		capacity = Backpack.capacityForLevel(params.backpackLevels, profile.upgradeLevels[BACKPACK_UPGRADE]),
		ores = profile.backpack.ores,
		finds = profile.backpack.finds,
	}

	local function result(ok: boolean, reason: FailureReason?, block: DigRoll.BlockResult?): Result
		return {
			ok = ok,
			reason = reason,
			block = block,
			depth = profile.depth,
			used = Backpack.getUsed(backpack),
			capacity = backpack.capacity,
		}
	end

	local cooldown = Shovel.getDigCooldown(params.shovelLevels, profile.upgradeLevels[SHOVEL_UPGRADE])
	if not Shovel.isReady(params.lastDigAt, params.now, cooldown, params.cooldownTolerance) then
		return result(false, "cooldown", nil)
	end

	if Backpack.isFull(backpack) then
		return result(false, "backpack_full", nil)
	end

	local block = DigRoll.rollBlock(params.digConfig, params.rng, { depth = profile.depth })
	if not Backpack.addBlock(backpack, block, profile.nextFindId) then
		-- Cannot happen after the isFull check; guard against a logic error.
		return result(false, "backpack_full", nil)
	end
	if block.kind == "rare" then
		profile.nextFindId += 1
	end
	profile.depth += params.metersPerBlock

	return result(true, nil, block)
end

-- Read-only view of the digger's current state.
function DigAction.snapshot(params: SnapshotParams): State
	local profile = params.profile
	local backpack: Backpack.Backpack = {
		capacity = Backpack.capacityForLevel(params.backpackLevels, profile.upgradeLevels[BACKPACK_UPGRADE]),
		ores = profile.backpack.ores,
		finds = profile.backpack.finds,
	}
	return {
		depth = profile.depth,
		coins = profile.coins,
		layerId = DigRoll.getLayer(params.digConfig, profile.depth).id,
		used = Backpack.getUsed(backpack),
		capacity = backpack.capacity,
		digCooldown = Shovel.getDigCooldown(params.shovelLevels, profile.upgradeLevels[SHOVEL_UPGRADE]),
	}
end

return DigAction
