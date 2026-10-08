--!strict
-- Pure backpack logic: stores dug blocks until they are sold.
-- Each block (ore or rare find) takes one slot. No Roblox services.

-- Must match DigRoll.BlockResult (kept structural so this module has no requires).
export type Block = {
	kind: "ore" | "rare",
	layerId: string,
	oreId: string?,
	findId: string?,
	rarityId: string?,
	mutationId: string?,
	value: number?,
}

export type Find = {
	id: number?, -- set when the find is stored in a profile
	findId: string,
	layerId: string,
	rarityId: string,
	mutationId: string?,
	value: number,
}

export type Backpack = {
	capacity: number,
	ores: { [string]: number },
	finds: { Find },
}

export type LevelDef = { capacity: number }

-- Guards float rounding such as 20 * 1.15 = 22.999999999999996.
local ROUNDING_EPSILON = 1e-9

local Backpack = {}

local function isPositiveInteger(value: number): boolean
	return value == value and value >= 1 and value < math.huge and value % 1 == 0
end

function Backpack.new(capacity: number): Backpack
	if not isPositiveInteger(capacity) then
		error(string.format("capacity must be a positive integer, got %s", tostring(capacity)), 2)
	end
	return { capacity = capacity, ores = {}, finds = {} }
end

function Backpack.getUsed(backpack: Backpack): number
	local used = #backpack.finds
	for _, count in backpack.ores do
		used += count
	end
	return used
end

function Backpack.getFree(backpack: Backpack): number
	return math.max(backpack.capacity - Backpack.getUsed(backpack), 0)
end

function Backpack.isFull(backpack: Backpack): boolean
	return Backpack.getUsed(backpack) >= backpack.capacity
end

-- Adds one dug block. Returns false (and changes nothing) when the backpack is
-- full. Raises an error for malformed blocks, which indicates a server bug.
-- `newFindId` is the unique id a rare find is stored with (ignored for ore).
function Backpack.addBlock(backpack: Backpack, block: Block, newFindId: number?): boolean
	local oreId = block.oreId
	local findId, rarityId, value = block.findId, block.rarityId, block.value
	if block.kind == "ore" then
		if oreId == nil then
			error("ore block without oreId", 2)
		end
	elseif block.kind == "rare" then
		if findId == nil or rarityId == nil or value == nil then
			error("rare block without findId, rarityId or value", 2)
		end
	else
		error("unknown block kind: " .. tostring(block.kind), 2)
	end

	if Backpack.isFull(backpack) then
		return false
	end

	if oreId ~= nil then
		backpack.ores[oreId] = (backpack.ores[oreId] or 0) + 1
	elseif findId ~= nil and rarityId ~= nil and value ~= nil then
		table.insert(backpack.finds, {
			id = newFindId,
			findId = findId,
			layerId = block.layerId,
			rarityId = rarityId,
			mutationId = block.mutationId,
			value = value,
		})
	end
	return true
end

function Backpack.clear(backpack: Backpack)
	table.clear(backpack.ores)
	table.clear(backpack.finds)
end

-- Capacity for an upgrade level (clamped to the configured range), with an
-- optional multiplier >= 1 (for example the "Rucksack Plus" pass), rounded down.
function Backpack.capacityForLevel(levels: { LevelDef }, level: number, capacityMultiplier: number?): number
	local index = 1
	if level == level then
		index = math.clamp(math.floor(level), 1, #levels)
	end
	local multiplier = capacityMultiplier
	if multiplier == nil or multiplier ~= multiplier or multiplier < 1 then
		multiplier = 1
	end
	return math.floor(levels[index].capacity * multiplier + ROUNDING_EPSILON)
end

-- Returns true when the levels are usable, otherwise false and a reason.
function Backpack.validateLevels(levels: { LevelDef }): (boolean, string?)
	if #levels == 0 then
		return false, "no backpack levels configured"
	end
	local previous = 0
	for index, level in levels do
		if not isPositiveInteger(level.capacity) then
			return false, string.format("backpack level %d needs a positive integer capacity", index)
		end
		if level.capacity <= previous then
			return false, string.format("backpack level %d must hold more than level %d", index, index - 1)
		end
		previous = level.capacity
	end
	return true, nil
end

return Backpack
