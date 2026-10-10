--!strict
-- Pure logic of one swing in the cave (the counterpart of DigAction for the
-- shaft): cooldown, swing area, mining, loot into the backpack, finds,
-- onboarding and depth. No Roblox services and no logging; the CaveService
-- decides who may swing and logs the outcome. Server-side only: the rolls and
-- the profile and cave changes must never run on the client.

local Backpack = require("./Backpack")
local Cave = require("./Cave")
local DigRoll = require("./DigRoll")
local Onboarding = require("./Onboarding")
local Shovel = require("./Shovel")

export type Rng = DigRoll.Rng

-- Structural subset of ProfileData.Profile (changed in place).
export type DiggerProfile = {
	depth: number,
	nextFindId: number,
	onboarding: Onboarding.State,
	stats: { blocksDug: number },
	upgradeLevels: { [string]: number },
	backpack: {
		ores: { [string]: number },
		finds: { Backpack.Find },
	},
}

export type OnboardingParams = {
	firstFindAfterBlocks: number,
	firstFindMutation: string,
}

-- Bonuses from the player (see Modifiers.Result). All 1 when absent.
export type DigModifiers = {
	luck: number,
	rareFindMultiplier: number,
	speedMultiplier: number,
	capacityMultiplier: number,
}

export type Params = {
	profile: DiggerProfile,
	cave: Cave.State,
	caveConfig: Cave.Config,
	digConfig: DigRoll.Config,
	shovelLevels: { Shovel.LevelDef },
	cooldownTolerance: number,
	backpackLevels: { Backpack.LevelDef },
	onboarding: OnboardingParams,
	modifiers: DigModifiers?,
	mutationBoost: DigRoll.MutationBoost?,
	hit: Cave.Position, -- the cell the player aims at
	axis: "row" | "x" | "y", -- the direction the hit face looks along
	lastDigAt: number?, -- clock of the last accepted swing, nil for the first
	now: number, -- clock in seconds (sub-second precision), for the cooldown
	time: number, -- server time (os.time), for regrowth and harvest times
	rng: Rng,
}

export type FailureReason = "cooldown" | "backpack_full" | "invalid_hit" | "nothing_mined"

export type MinedCell = { cell: Cave.Position, kind: Cave.CellKind, itemId: string? }

-- On failure nothing was changed. `depth`, `used` and `capacity` describe the
-- state after the call.
export type Result = {
	ok: boolean,
	reason: FailureReason?,
	mined: { MinedCell }, -- every cell that was removed, for the client's view
	finds: { DigRoll.BlockResult }, -- rare finds that went into the backpack
	stoppedFull: boolean, -- loot cells were left standing because the backpack was full
	depth: number,
	used: number,
	capacity: number,
}

local SHOVEL_UPGRADE = "shovel"
local BACKPACK_UPGRADE = "backpack"
local PERCENT = 100

local CaveAction = {}

local function isWholeNumber(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge and value % 1 == 0
end

function CaveAction.perform(params: Params): Result
	local profile = params.profile
	local bonus = params.modifiers
	local caveConfig = params.caveConfig

	-- Shares the profile's tables, so adding loot changes the profile.
	local backpack: Backpack.Backpack = {
		capacity = Backpack.capacityForLevel(
			params.backpackLevels,
			profile.upgradeLevels[BACKPACK_UPGRADE],
			if bonus then bonus.capacityMultiplier else nil
		),
		ores = profile.backpack.ores,
		finds = profile.backpack.finds,
	}

	local mined: { MinedCell } = {}
	local finds: { DigRoll.BlockResult } = {}
	local stoppedFull = false

	local function result(ok: boolean, reason: FailureReason?): Result
		return {
			ok = ok,
			reason = reason,
			mined = mined,
			finds = finds,
			stoppedFull = stoppedFull,
			depth = profile.depth,
			used = Backpack.getUsed(backpack),
			capacity = backpack.capacity,
		}
	end

	local hit = params.hit
	if
		type(hit) ~= "table"
		or not isWholeNumber(hit.row)
		or not isWholeNumber(hit.x)
		or not isWholeNumber(hit.y)
		or (params.axis ~= "row" and params.axis ~= "x" and params.axis ~= "y")
	then
		return result(false, "invalid_hit")
	end

	local cooldown = Shovel.getDigCooldown(
		params.shovelLevels,
		profile.upgradeLevels[SHOVEL_UPGRADE],
		if bonus then bonus.speedMultiplier else nil
	)
	if not Shovel.isReady(params.lastDigAt, params.now, cooldown, params.cooldownTolerance) then
		return result(false, "cooldown")
	end

	local level = profile.upgradeLevels[SHOVEL_UPGRADE]
	local cells = Cave.areaCells(hit, params.axis, Cave.areaFor(caveConfig, level))
	local luck = if bonus then bonus.luck else nil
	local rareFindMultiplier = if bonus then bonus.rareFindMultiplier else 1

	for _, cell in cells do
		local before = Cave.cellKind(params.cave, caveConfig, cell.row, cell.x, cell.y, params.time)
		local isLoot = before.kind == "ore" or before.kind == "herb" or before.kind == "find_spot"
		if isLoot and Backpack.isFull(backpack) then
			stoppedFull = true
			continue
		end

		local outcome = Cave.mine(params.cave, caveConfig, level, cell.row, cell.x, cell.y, params.time)
		if not outcome.ok then
			continue
		end
		table.insert(mined, { cell = cell, kind = before.kind, itemId = before.itemId })
		profile.stats.blocksDug += 1
		if not isLoot then
			continue
		end

		-- The dig that reaches the configured block count turns the next ore into a
		-- guaranteed rare find with a fixed mutation, once per profile.
		local guarantee = before.kind ~= "herb"
			and not profile.onboarding.firstFindGiven
			and profile.stats.blocksDug >= params.onboarding.firstFindAfterBlocks
		local isFind = before.kind == "find_spot" or guarantee
		if not isFind and before.kind == "ore" and rareFindMultiplier > 1 then
			-- A bonus on the rare find chance (skill "Erzspürer") turns some ores into finds.
			local multiplier = math.min(rareFindMultiplier, params.digConfig.maxRareFindBonus)
			if params.rng() < (params.caveConfig.findSpotShare / PERCENT) * (multiplier - 1) then
				isFind = true
			end
		end

		if isFind then
			local depthOfCell = cell.row * caveConfig.metersPerRow
			local block = DigRoll.rollBlock(params.digConfig, params.rng, {
				depth = depthOfCell,
				luck = luck,
				guaranteedRare = true,
				guaranteedMutation = if guarantee then params.onboarding.firstFindMutation else nil,
				mutationBoost = params.mutationBoost,
			})
			if Backpack.addBlock(backpack, block, profile.nextFindId) then
				profile.nextFindId += 1
				table.insert(finds, block)
				if guarantee then
					profile.onboarding.firstFindGiven = true
				end
			end
		else
			local biome = Cave.biomeAt(caveConfig, cell.row * caveConfig.metersPerRow)
			Backpack.addBlock(backpack, {
				kind = "ore",
				layerId = biome.id,
				oreId = before.itemId,
			})
		end
	end

	if #mined == 0 then
		return result(false, if stoppedFull then "backpack_full" else "nothing_mined")
	end

	profile.depth = math.max(profile.depth, Cave.depth(params.cave, caveConfig))
	Onboarding.advance(profile.onboarding, "dug")
	if #finds > 0 then
		Onboarding.advance(profile.onboarding, "found")
	end
	return result(true, nil)
end

return CaveAction
