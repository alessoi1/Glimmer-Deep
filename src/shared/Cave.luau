--!strict
-- Pure model of the cave under the castle: grid, content from the seed, mining
-- with a swing area, regrowth of ores and herbs, chests and the save format.
-- No Roblox services and no logging; the CaveService decides who may mine and
-- builds the blocks. Server-side only use for anything that changes the cave.
--
-- Grid: row = along the slope (0 = entrance), x = sideways from the middle
-- line, y = height above the floor. Content of every cell is a pure function
-- of the seed, so only the mined cells, the harvest times and the chest times
-- are saved (see serialize).

local CaveCodec = require("./CaveCodec")

export type Biome = {
	id: string,
	minDepth: number,
	maxDepth: number,
	ores: { string },
	herbs: { string },
}

export type Config = {
	height: number,
	sliceRows: number,
	metersPerRow: number,
	entranceRows: number,
	corridorHalfWidth: number,
	corridorHeight: number,
	startRadius: number,
	maxRadius: number,
	radiusByLevel: { number },
	areaByLevel: { number },
	resourceDensity: number, -- percent of wall cells that hold ore or an herb
	herbShare: number, -- percent of resource cells that are herbs
	findSpotShare: number, -- percent of ore cells that are find spots
	regrowSeconds: number,
	chestChance: number, -- percent of slices with a chest
	chestMinRow: number,
	chestRespawnSeconds: number,
	biomes: { Biome },
}

export type Slice = {
	mined: { [number]: boolean }, -- local index -> true
	harvestedAt: number?, -- server time of the last ore or herb harvest here
	dirty: boolean?, -- changed since the last flush into the profile
}

export type State = {
	seed: number,
	deepestRow: number,
	preDugRow: number, -- rows up to here are an open corridor (players from before the cave); 0 = none
	slices: { [number]: Slice },
	chests: { [number]: number }, -- slice index -> server time the chest was opened
}

export type CellKind = "air" | "rock" | "ore" | "herb" | "find_spot" | "chest"

export type Cell = { kind: CellKind, itemId: string? }

export type Position = { row: number, x: number, y: number }

export type FailureReason =
	"out_of_bounds"
	| "out_of_area"
	| "already_open"
	| "not_exposed"
	| "is_chest"
	| "not_a_chest"

export type MineResult = {
	ok: boolean,
	reason: FailureReason?,
	kind: CellKind?,
	itemId: string?,
}

export type Rejected = { cell: Position, reason: FailureReason }

export type AreaSummary = {
	mined: { { cell: Position, kind: CellKind, itemId: string? } },
	rejected: { Rejected },
}

export type SavedSlice = { bits: string, harvestedAt: number? }

export type SavedCave = {
	seed: number,
	deepestRow: number,
	preDugRow: number,
	slices: { [string]: SavedSlice },
	chests: { [string]: number },
}

local TWO_32 = 4294967296
local SEED_LIMIT = 2147483646
local PERCENT_UNITS = 100 -- hash buckets per percent (hash % 10000)
local BUCKETS = 10000

-- Hash salts, one per decision, so decisions of one cell are independent.
local SALT_RESOURCE = 1
local SALT_HERB = 2
local SALT_ITEM = 3
local SALT_SPOT = 4
local SALT_CHEST_HERE = 5
local SALT_CHEST_ROW = 6
local SALT_CHEST_X = 7
local SALT_CHEST_Y = 8

local NEIGHBORS = {
	{ 1, 0, 0 },
	{ -1, 0, 0 },
	{ 0, 1, 0 },
	{ 0, -1, 0 },
	{ 0, 0, 1 },
	{ 0, 0, -1 },
}

local Cave = {}

-- 32-bit multiply without losing precision in doubles.
local function mul32(a: number, b: number): number
	local aLow = a % 65536
	local aHigh = (a - aLow) / 65536
	local bLow = b % 65536
	local bHigh = (b - bLow) / 65536
	return (((aHigh * bLow + aLow * bHigh) % 65536) * 65536 + aLow * bLow) % TWO_32
end

local function hash(seed: number, a: number, b: number, c: number, salt: number): number
	local h = bit32.bxor(seed % TWO_32, 0x9E3779B9)
	for _, value in { a, b, c, salt } do
		h = mul32(bit32.bxor(h, value % TWO_32), 0x85EBCA6B)
		h = bit32.bxor(h, bit32.rshift(h, 15))
	end
	h = mul32(h, 0xC2B2AE35)
	return bit32.bxor(h, bit32.rshift(h, 13))
end

local function isInteger(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge and value % 1 == 0
end

local function width(config: Config): number
	return config.maxRadius * 2 + 1
end

local function cellsPerSlice(config: Config): number
	return config.sliceRows * width(config) * config.height
end

function Cave.sliceOf(config: Config, row: number): number
	return math.floor(row / config.sliceRows)
end

function Cave.localIndex(config: Config, row: number, x: number, y: number): number
	return ((row % config.sliceRows) * width(config) + (x + config.maxRadius)) * config.height + y
end

local function positionOf(config: Config, sliceIndex: number, index: number): Position
	local y = index % config.height
	local rest = (index - y) / config.height
	local columns = width(config)
	local column = rest % columns
	local rowInSlice = (rest - column) / columns
	return { row = sliceIndex * config.sliceRows + rowInSlice, x = column - config.maxRadius, y = y }
end

local function inStructure(config: Config, row: number, x: number, y: number): boolean
	return isInteger(row)
		and isInteger(x)
		and isInteger(y)
		and row >= 0
		and math.abs(x) <= config.maxRadius
		and y >= 0
		and y < config.height
end

local function clampedLevelValue(values: { number }, level: number): number
	local index = 1
	if level == level then
		index = math.clamp(math.floor(level), 1, #values)
	end
	return values[index]
end

function Cave.radiusFor(config: Config, pickaxeLevel: number): number
	return clampedLevelValue(config.radiusByLevel, pickaxeLevel)
end

function Cave.areaFor(config: Config, pickaxeLevel: number): number
	return clampedLevelValue(config.areaByLevel, pickaxeLevel)
end

function Cave.biomeAt(config: Config, depth: number): Biome
	local biomes = config.biomes
	if depth ~= depth or depth < biomes[1].minDepth then
		return biomes[1]
	end
	for _, biome in biomes do
		if depth >= biome.minDepth and depth < biome.maxDepth then
			return biome
		end
	end
	return biomes[#biomes]
end

function Cave.new(seed: number): State
	if not isInteger(seed) or seed < 1 or seed > SEED_LIMIT then
		error("cave seed must be an integer from 1 to " .. SEED_LIMIT, 2)
	end
	return { seed = seed, deepestRow = 0, preDugRow = 0, slices = {}, chests = {} }
end

function Cave.depth(state: State, config: Config): number
	return state.deepestRow * config.metersPerRow
end

function Cave.harvestedAt(state: State, _config: Config, sliceIndex: number): number?
	local slice = state.slices[sliceIndex]
	return if slice then slice.harvestedAt else nil
end

local function isEntrance(config: Config, row: number, x: number, y: number): boolean
	return row < config.entranceRows and math.abs(x) <= config.startRadius and y >= 0 and y < config.height
end

local function isCorridor(state: State, config: Config, row: number, x: number, y: number): boolean
	return row >= config.entranceRows
		and row <= state.preDugRow
		and math.abs(x) <= config.corridorHalfWidth
		and y < config.corridorHeight
end

local function isMinedBit(state: State, config: Config, row: number, x: number, y: number): boolean
	local slice = state.slices[Cave.sliceOf(config, row)]
	return slice ~= nil and slice.mined[Cave.localIndex(config, row, x, y)] == true
end

-- Position of the chest of a slice, or nil when the slice has none.
function Cave.chestPosition(config: Config, seed: number, sliceIndex: number): Position?
	if hash(seed, sliceIndex, 0, 0, SALT_CHEST_HERE) % BUCKETS >= config.chestChance * PERCENT_UNITS then
		return nil
	end
	local firstRow = sliceIndex * config.sliceRows
	local lowestRow = math.max(firstRow, config.chestMinRow)
	local lastRow = firstRow + config.sliceRows - 1
	if lowestRow > lastRow then
		return nil
	end
	local rowSpan = lastRow - lowestRow + 1
	return {
		row = lowestRow + hash(seed, sliceIndex, 0, 0, SALT_CHEST_ROW) % rowSpan,
		x = hash(seed, sliceIndex, 0, 0, SALT_CHEST_X) % width(config) - config.maxRadius,
		y = hash(seed, sliceIndex, 0, 0, SALT_CHEST_Y) % config.height,
	}
end

local function chestPresent(state: State, config: Config, sliceIndex: number, now: number): boolean
	local openedAt = state.chests[sliceIndex]
	return openedAt == nil or now - openedAt >= config.chestRespawnSeconds
end

local function isChestCell(state: State, config: Config, row: number, x: number, y: number, now: number): boolean
	local sliceIndex = Cave.sliceOf(config, row)
	local position = Cave.chestPosition(config, state.seed, sliceIndex)
	return position ~= nil
		and position.row == row
		and position.x == x
		and position.y == y
		and chestPresent(state, config, sliceIndex, now)
end

-- What the seed puts into a cell (ignoring everything that was mined).
local function seedContent(state: State, config: Config, row: number, x: number, y: number): Cell
	local seed = state.seed
	if hash(seed, row, x, y, SALT_RESOURCE) % BUCKETS >= config.resourceDensity * PERCENT_UNITS then
		return { kind = "rock" }
	end
	local biome = Cave.biomeAt(config, row * config.metersPerRow)
	if hash(seed, row, x, y, SALT_HERB) % BUCKETS < config.herbShare * PERCENT_UNITS then
		return { kind = "herb", itemId = biome.herbs[hash(seed, row, x, y, SALT_ITEM) % #biome.herbs + 1] }
	end
	local itemId = biome.ores[hash(seed, row, x, y, SALT_ITEM) % #biome.ores + 1]
	if hash(seed, row, x, y, SALT_SPOT) % BUCKETS < config.findSpotShare * PERCENT_UNITS then
		return { kind = "find_spot", itemId = itemId }
	end
	return { kind = "ore", itemId = itemId }
end

local function isResource(kind: CellKind): boolean
	return kind == "ore" or kind == "herb" or kind == "find_spot"
end

-- True when the cell is empty space: the entrance hall, a mined cell, or the
-- spot of a chest that was opened and has not come back yet.
function Cave.isOpen(state: State, config: Config, row: number, x: number, y: number, now: number): boolean
	if not inStructure(config, row, x, y) then
		return false
	end
	if isEntrance(config, row, x, y) or isCorridor(state, config, row, x, y) then
		return true
	end
	if isMinedBit(state, config, row, x, y) then
		return true
	end
	local position = Cave.chestPosition(config, state.seed, Cave.sliceOf(config, row))
	return position ~= nil
		and position.row == row
		and position.x == x
		and position.y == y
		and not chestPresent(state, config, Cave.sliceOf(config, row), now)
end

function Cave.cellKind(state: State, config: Config, row: number, x: number, y: number, now: number): Cell
	if Cave.isOpen(state, config, row, x, y, now) then
		return { kind = "air" }
	end
	if isChestCell(state, config, row, x, y, now) then
		return { kind = "chest" }
	end
	return seedContent(state, config, row, x, y)
end

-- A cell can only be reached when one of its six neighbors is open.
function Cave.isExposed(state: State, config: Config, row: number, x: number, y: number, now: number): boolean
	for _, offset in NEIGHBORS do
		if Cave.isOpen(state, config, row + offset[1], x + offset[2], y + offset[3], now) then
			return true
		end
	end
	return false
end

-- A neighbor outside the structure counts as solid (the cave is walled in).
function Cave.hasSolidNeighbor(state: State, config: Config, row: number, x: number, y: number, now: number): boolean
	for _, offset in NEIGHBORS do
		if not Cave.isOpen(state, config, row + offset[1], x + offset[2], y + offset[3], now) then
			return true
		end
	end
	return false
end

local function checkReach(
	state: State,
	config: Config,
	pickaxeLevel: number,
	row: number,
	x: number,
	y: number,
	now: number
): FailureReason?
	if not inStructure(config, row, x, y) then
		return "out_of_bounds"
	end
	if math.abs(x) > Cave.radiusFor(config, pickaxeLevel) then
		return "out_of_area"
	end
	if Cave.isOpen(state, config, row, x, y, now) then
		return "already_open"
	end
	if not Cave.isExposed(state, config, row, x, y, now) then
		return "not_exposed"
	end
	return nil
end

local function sliceFor(state: State, sliceIndex: number): Slice
	local slice = state.slices[sliceIndex]
	if slice == nil then
		slice = { mined = {} }
		state.slices[sliceIndex] = slice
	end
	return slice
end

-- Mines one cell. On failure nothing changes.
function Cave.mine(
	state: State,
	config: Config,
	pickaxeLevel: number,
	row: number,
	x: number,
	y: number,
	now: number
): MineResult
	local reason = checkReach(state, config, pickaxeLevel, row, x, y, now)
	if reason ~= nil then
		return { ok = false, reason = reason }
	end
	if isChestCell(state, config, row, x, y, now) then
		return { ok = false, reason = "is_chest" }
	end

	local cell = seedContent(state, config, row, x, y)
	local slice = sliceFor(state, Cave.sliceOf(config, row))
	slice.mined[Cave.localIndex(config, row, x, y)] = true
	slice.dirty = true
	if isResource(cell.kind) then
		slice.harvestedAt = now
	end
	if row > state.deepestRow then
		state.deepestRow = row
	end
	return { ok = true, kind = cell.kind, itemId = cell.itemId }
end

-- The square of cells a swing hits: `size` by `size` in the plane of the face
-- that was hit. `axis` is the direction the face looks along (row, x or y).
function Cave.areaCells(hit: Position, axis: "row" | "x" | "y", size: number): { Position }
	local low = -math.floor((size - 1) / 2)
	local high = low + size - 1
	local cells: { Position } = {}
	for a = low, high do
		for b = low, high do
			if axis == "row" then
				table.insert(cells, { row = hit.row, x = hit.x + a, y = hit.y + b })
			elseif axis == "x" then
				table.insert(cells, { row = hit.row + a, x = hit.x, y = hit.y + b })
			else
				table.insert(cells, { row = hit.row + a, x = hit.x + b, y = hit.y })
			end
		end
	end
	table.sort(cells, function(p, q)
		if p.row ~= q.row then
			return p.row < q.row
		end
		if p.x ~= q.x then
			return p.x < q.x
		end
		return p.y < q.y
	end)
	return cells
end

-- Mines every reachable cell of a swing in the given order; the rest is reported.
function Cave.mineArea(
	state: State,
	config: Config,
	pickaxeLevel: number,
	cells: { Position },
	now: number
): AreaSummary
	local summary: AreaSummary = { mined = {}, rejected = {} }
	for _, cell in cells do
		local result = Cave.mine(state, config, pickaxeLevel, cell.row, cell.x, cell.y, now)
		if result.ok and result.kind ~= nil then
			table.insert(summary.mined, { cell = cell, kind = result.kind, itemId = result.itemId })
		else
			table.insert(summary.rejected, { cell = cell, reason = result.reason or "out_of_bounds" })
		end
	end
	return summary
end

-- Opens the chest at a cell. The loot is rolled by the caller (server).
function Cave.openChest(
	state: State,
	config: Config,
	pickaxeLevel: number,
	row: number,
	x: number,
	y: number,
	now: number
): MineResult
	if not inStructure(config, row, x, y) then
		return { ok = false, reason = "out_of_bounds" }
	end
	if not isChestCell(state, config, row, x, y, now) then
		return { ok = false, reason = "not_a_chest" }
	end
	if math.abs(x) > Cave.radiusFor(config, pickaxeLevel) then
		return { ok = false, reason = "out_of_area" }
	end
	if not Cave.isExposed(state, config, row, x, y, now) then
		return { ok = false, reason = "not_exposed" }
	end
	state.chests[Cave.sliceOf(config, row)] = now
	return { ok = true, kind = "chest" }
end

-- Brings mined ores and herbs of a slice back when the regrow time has passed
-- since the last harvest. Only cells with a solid neighbor grow back (they
-- stay on the wall); mined rock never does. Returns the number of cells.
function Cave.regrow(state: State, config: Config, sliceIndex: number, now: number): number
	local slice = state.slices[sliceIndex]
	if slice == nil or slice.harvestedAt == nil or now - slice.harvestedAt < config.regrowSeconds then
		return 0
	end
	local back: { number } = {}
	for index in slice.mined do
		local position = positionOf(config, sliceIndex, index)
		if
			not isEntrance(config, position.row, position.x, position.y)
			and not isCorridor(state, config, position.row, position.x, position.y)
		then
			local content = seedContent(state, config, position.row, position.x, position.y)
			if
				isResource(content.kind)
				and Cave.hasSolidNeighbor(state, config, position.row, position.x, position.y, now)
			then
				table.insert(back, index)
			end
		end
	end
	for _, index in back do
		slice.mined[index] = nil
	end
	slice.harvestedAt = nil
	slice.dirty = true
	return #back
end

function Cave.regrowAll(state: State, config: Config, now: number): number
	local total = 0
	local indexes: { number } = {}
	for sliceIndex in state.slices do
		table.insert(indexes, sliceIndex)
	end
	for _, sliceIndex in indexes do
		total += Cave.regrow(state, config, sliceIndex, now)
	end
	return total
end

-- Save format ------------------------------------------------------------------
-- Times are server seconds (os.time); serialize rounds them down to whole seconds.

function Cave.serialize(state: State, config: Config): SavedCave
	local total = cellsPerSlice(config)
	local slices: { [string]: SavedSlice } = {}
	for sliceIndex, slice in state.slices do
		if next(slice.mined) ~= nil then
			slices[tostring(sliceIndex)] = {
				bits = CaveCodec.encode(slice.mined, total),
				harvestedAt = if slice.harvestedAt then math.floor(slice.harvestedAt) else nil,
			}
		end
	end
	local chests: { [string]: number } = {}
	for sliceIndex, openedAt in state.chests do
		chests[tostring(sliceIndex)] = math.floor(openedAt)
	end
	return {
		seed = state.seed,
		deepestRow = state.deepestRow,
		preDugRow = state.preDugRow,
		slices = slices,
		chests = chests,
	}
end

-- Writes everything that changed since the last flush into `saved` (the cave
-- table of the profile) and returns how many slices were written. Cheap enough
-- to call after every swing and before saving; unchanged slices are not encoded.
function Cave.flush(state: State, config: Config, saved: SavedCave): number
	saved.seed = state.seed
	saved.deepestRow = state.deepestRow
	saved.preDugRow = state.preDugRow
	for key in saved.chests do
		saved.chests[key] = nil
	end
	for sliceIndex, openedAt in state.chests do
		saved.chests[tostring(sliceIndex)] = math.floor(openedAt)
	end

	local total = cellsPerSlice(config)
	local written = 0
	for sliceIndex, slice in state.slices do
		if slice.dirty then
			local key = tostring(sliceIndex)
			if next(slice.mined) == nil then
				saved.slices[key] = nil
			else
				saved.slices[key] = {
					bits = CaveCodec.encode(slice.mined, total),
					harvestedAt = if slice.harvestedAt then math.floor(slice.harvestedAt) else nil,
				}
			end
			slice.dirty = nil
			written += 1
		end
	end
	return written
end

local function parseIndex(key: any): number?
	if type(key) ~= "string" or not string.match(key, "^%d+$") then
		return nil
	end
	local value = tonumber(key)
	if value == nil or not isInteger(value) then
		return nil
	end
	return value
end

-- Returns the state, or nil and a reason when the saved data is unusable.
function Cave.deserialize(data: any, config: Config): (State?, string?)
	if type(data) ~= "table" then
		return nil, "cave data must be a table"
	end
	local seed = data.seed
	if not isInteger(seed) or seed < 1 or seed > SEED_LIMIT then
		return nil, "cave seed is invalid"
	end
	if not isInteger(data.deepestRow) or data.deepestRow < 0 then
		return nil, "deepestRow is invalid"
	end
	if data.preDugRow ~= nil and (not isInteger(data.preDugRow) or data.preDugRow < 0) then
		return nil, "preDugRow is invalid"
	end
	if type(data.slices) ~= "table" or type(data.chests) ~= "table" then
		return nil, "cave slices and chests must be tables"
	end

	local total = cellsPerSlice(config)
	local state = Cave.new(seed)
	state.deepestRow = data.deepestRow
	state.preDugRow = data.preDugRow or 0
	for key, saved in data.slices do
		local sliceIndex = parseIndex(key)
		if sliceIndex == nil then
			return nil, "slice key is invalid"
		end
		if type(saved) ~= "table" then
			return nil, "slice " .. tostring(key) .. " must be a table"
		end
		local mined = CaveCodec.decode(saved.bits, total)
		if mined == nil then
			return nil, "slice " .. tostring(key) .. " has invalid bits"
		end
		if saved.harvestedAt ~= nil and (not isInteger(saved.harvestedAt) or saved.harvestedAt < 0) then
			return nil, "slice " .. tostring(key) .. " has an invalid harvest time"
		end
		state.slices[sliceIndex] = { mined = mined, harvestedAt = saved.harvestedAt }
	end
	for key, openedAt in data.chests do
		local sliceIndex = parseIndex(key)
		if sliceIndex == nil then
			return nil, "chest key is invalid"
		end
		if not isInteger(openedAt) or openedAt < 0 then
			return nil, "chest " .. tostring(key) .. " has an invalid time"
		end
		state.chests[sliceIndex] = openedAt
	end
	return state, nil
end

-- Returns true when the config is usable, otherwise false and a reason.
function Cave.validateConfig(config: Config): (boolean, string?)
	if not isInteger(config.height) or config.height < 1 then
		return false, "height must be a positive integer"
	end
	if not isInteger(config.sliceRows) or config.sliceRows < 1 then
		return false, "sliceRows must be a positive integer"
	end
	if not isInteger(config.entranceRows) or config.entranceRows < 1 then
		return false, "entranceRows must be a positive integer"
	end
	if not isInteger(config.startRadius) or not isInteger(config.maxRadius) then
		return false, "radii must be integers"
	end
	if config.startRadius < 1 or config.startRadius > config.maxRadius then
		return false, "startRadius must be from 1 to maxRadius"
	end
	if
		not isInteger(config.corridorHalfWidth)
		or config.corridorHalfWidth < 0
		or config.corridorHalfWidth > config.maxRadius
	then
		return false, "corridorHalfWidth must be an integer from 0 to maxRadius"
	end
	if not isInteger(config.corridorHeight) or config.corridorHeight < 1 or config.corridorHeight > config.height then
		return false, "corridorHeight must be an integer from 1 to height"
	end
	if not (config.metersPerRow > 0) then
		return false, "metersPerRow must be positive"
	end
	if #config.radiusByLevel == 0 or #config.areaByLevel == 0 then
		return false, "radiusByLevel and areaByLevel need entries"
	end
	local previous = 0
	for _, radius in config.radiusByLevel do
		if not isInteger(radius) or radius < previous or radius < config.startRadius or radius > config.maxRadius then
			return false, "radiusByLevel must not decrease and stay from startRadius to maxRadius"
		end
		previous = radius
	end
	previous = 0
	for _, area in config.areaByLevel do
		if not isInteger(area) or area < 1 or area < previous then
			return false, "areaByLevel must be positive integers that do not decrease"
		end
		previous = area
	end
	for name, value in
		{
			resourceDensity = config.resourceDensity,
			herbShare = config.herbShare,
			findSpotShare = config.findSpotShare,
			chestChance = config.chestChance,
		}
	do
		if type(value) ~= "number" or not (value >= 0 and value <= 100) then
			return false, name .. " must be a percentage from 0 to 100"
		end
	end
	if not (config.regrowSeconds > 0) or not (config.chestRespawnSeconds > 0) then
		return false, "regrowSeconds and chestRespawnSeconds must be positive"
	end
	if not isInteger(config.chestMinRow) or config.chestMinRow < config.entranceRows then
		return false, "chestMinRow must be an integer from entranceRows up"
	end
	if #config.biomes == 0 then
		return false, "no biomes configured"
	end
	for _, biome in config.biomes do
		if #biome.ores == 0 or #biome.herbs == 0 then
			return false, "biome " .. biome.id .. " needs ores and herbs"
		end
	end
	return true, nil
end

return Cave
