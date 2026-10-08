--!strict
-- Pure offline digger logic: what the digger helper dug while the player was
-- away. No Roblox services, no background timers and no logging; the server
-- stores the time the player left and calls this when the player returns. The
-- result goes into the depot (the "Lager"), which is sold together with the
-- backpack. Server-side only use: the rolls must never run on the client.

local DigRoll = require("./DigRoll")

export type Find = {
	id: number,
	findId: string,
	layerId: string,
	rarityId: string,
	mutationId: string?,
	value: number,
}

export type Stash = {
	ores: { [string]: number },
	finds: { Find },
}

export type LevelDef = { blocksPerHour: number }

export type Config = {
	maxHours: number,
	rareFindChanceFactor: number,
	minSeconds: number,
	maxBlocks: number,
	depotCapacity: number,
}

export type Params = {
	leftAt: number?, -- server time the player left, nil when unknown
	now: number, -- server time in seconds
	digConfig: DigRoll.Config,
	rng: DigRoll.Rng,
	depth: number, -- current depth in meters; decides the layer
	levels: { LevelDef },
	level: number, -- digger level
	config: Config,
	extraHours: number, -- extra hours on top of maxHours (the "Nachtschicht" pass)
	yieldMultiplier: number, -- bonus on the blocks dug (pets, skills)
	luck: number, -- luck multiplier on rarity and mutation chances
	depot: Stash, -- changed in place
	nextFindId: number,
}

-- What the player is told on return. `seconds` is the real absence, `hours` the
-- time that counted; `lost` counts blocks that did not fit into the depot.
export type Report = {
	seconds: number,
	hours: number,
	capped: boolean,
	blocks: number,
	lost: number,
	ores: { [string]: number },
	finds: { Find },
}

export type Result = {
	report: Report?, -- nil when nothing happened (no absence, too short)
	nextFindId: number,
}

local ROUNDING_EPSILON = 1e-9
local SECONDS_PER_HOUR = 3600

local OfflineLogic = {}

local function usedSpace(depot: Stash): number
	local total = #depot.finds
	for _, count in depot.ores do
		total += count
	end
	return total
end

local function validMultiplier(value: number): number
	if value ~= value or value < 0 or value == math.huge then
		return 1
	end
	return value
end

-- Digs the blocks of the absence into the depot.
function OfflineLogic.run(params: Params): Result
	local unchanged: Result = { report = nil, nextFindId = params.nextFindId }
	local leftAt = params.leftAt
	if leftAt == nil then
		return unchanged
	end
	local seconds = params.now - leftAt
	if not (seconds >= params.config.minSeconds) then
		return unchanged
	end

	local maxHours = params.config.maxHours + math.max(params.extraHours, 0)
	local absentHours = seconds / SECONDS_PER_HOUR
	local hours = math.min(absentHours, maxHours)
	local levelIndex = math.clamp(math.floor(params.level), 1, #params.levels)
	local blocksPerHour = params.levels[levelIndex].blocksPerHour
	local planned = math.min(
		math.floor(blocksPerHour * hours * validMultiplier(params.yieldMultiplier) + ROUNDING_EPSILON),
		params.config.maxBlocks
	)

	local rollConfig = table.clone(params.digConfig)
	rollConfig.rareFindChance = params.digConfig.rareFindChance * params.config.rareFindChanceFactor

	local report: Report = {
		seconds = seconds,
		hours = hours,
		capped = absentHours > maxHours,
		blocks = 0,
		lost = 0,
		ores = {},
		finds = {},
	}
	local depot = params.depot
	local used = usedSpace(depot)
	local nextFindId = params.nextFindId

	for index = 1, planned do
		if used >= params.config.depotCapacity then
			report.lost = planned - (index - 1)
			break
		end
		local block = DigRoll.rollBlock(rollConfig, params.rng, { depth = params.depth, luck = params.luck })
		if block.kind == "ore" and block.oreId ~= nil then
			depot.ores[block.oreId] = (depot.ores[block.oreId] or 0) + 1
			report.ores[block.oreId] = (report.ores[block.oreId] or 0) + 1
		elseif block.findId ~= nil and block.rarityId ~= nil and block.value ~= nil then
			local find: Find = {
				id = nextFindId,
				findId = block.findId,
				layerId = block.layerId,
				rarityId = block.rarityId,
				mutationId = block.mutationId,
				value = block.value,
			}
			nextFindId += 1
			table.insert(depot.finds, find)
			table.insert(report.finds, table.clone(find))
		end
		used += 1
		report.blocks += 1
	end

	return { report = report, nextFindId = nextFindId }
end

return OfflineLogic
