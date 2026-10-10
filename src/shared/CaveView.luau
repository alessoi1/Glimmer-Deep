--!strict
-- Pure geometry of the cave in the world: where a cell stands, which cells have
-- to be built around a player, what changed since the last update, and whether
-- a cell is within reach. No Roblox services; the CaveService turns the numbers
-- into parts. The cave is a straight tunnel in its own grid (see Cave); here it
-- is tilted down by the slope angle and placed in a slot of its own per player.

local Cave = require("./Cave")

export type Vec = { x: number, y: number, z: number }

export type World = {
	origin: Vec,
	slotSpacing: number,
	slopeDegrees: number,
	windowAhead: number,
	windowBehind: number,
	reachStuds: number,
	maxParts: number,
}

export type Axes = { forward: Vec, up: Vec, right: Vec }

-- "bedrock" marks the shell outside the grid (floor, ceiling and side walls).
-- "cap" marks the wall that closes the built window at its two ends.
export type VisibleCell = {
	row: number,
	x: number,
	y: number,
	kind: Cave.CellKind | "bedrock",
	itemId: string?,
	cap: boolean?,
}

export type Diff = { add: { VisibleCell }, remove: { string } }

local MIN_PARTS = 100
local MAX_SLOPE = 60

local CaveView = {}

function CaveView.axes(world: World): Axes
	local angle = math.rad(world.slopeDegrees)
	return {
		forward = { x = 0, y = -math.sin(angle), z = math.cos(angle) },
		up = { x = 0, y = math.cos(angle), z = math.sin(angle) },
		right = { x = 1, y = 0, z = 0 },
	}
end

local function slotOrigin(world: World, slot: number): Vec
	return { x = world.origin.x + slot * world.slotSpacing, y = world.origin.y, z = world.origin.z }
end

-- World position of the middle of a cell.
function CaveView.cellCenter(world: World, blockSize: number, slot: number, row: number, x: number, y: number): Vec
	local axes = CaveView.axes(world)
	local origin = slotOrigin(world, slot)
	local along = (row + 0.5) * blockSize
	local side = x * blockSize
	local height = (y + 0.5) * blockSize
	return {
		x = origin.x + axes.forward.x * along + axes.right.x * side + axes.up.x * height,
		y = origin.y + axes.forward.y * along + axes.right.y * side + axes.up.y * height,
		z = origin.z + axes.forward.z * along + axes.right.z * side + axes.up.z * height,
	}
end

function CaveView.distance(a: Vec, b: Vec): number
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- The row a world position lies in (projected on the slope direction).
function CaveView.rowAt(world: World, blockSize: number, slot: number, position: Vec): number
	local axes = CaveView.axes(world)
	local origin = slotOrigin(world, slot)
	local dx, dy, dz = position.x - origin.x, position.y - origin.y, position.z - origin.z
	local along = dx * axes.forward.x + dy * axes.forward.y + dz * axes.forward.z
	return math.floor(along / blockSize)
end

-- First and last row to keep built around a player standing in `centerRow`.
function CaveView.windowRows(world: World, centerRow: number): (number, number)
	return math.max(0, centerRow - world.windowBehind), centerRow + world.windowAhead
end

function CaveView.key(row: number, x: number, y: number): string
	return string.format("%d,%d,%d", row, x, y)
end

-- Every solid cell next to open space in the given rows, plus the bedrock shell
-- around the open space (the floor, the ceiling and the side walls lie outside
-- the grid and still have to be built).
function CaveView.visibleCells(
	state: Cave.State,
	config: Cave.Config,
	fromRow: number,
	toRow: number,
	time: number
): { VisibleCell }
	local cells: { VisibleCell } = {}
	local sideLimit = config.maxRadius + 1
	-- Row -1 is the closed back wall of the entrance hall (bedrock).
	local firstRow = if fromRow <= 0 then -1 else fromRow
	for row = firstRow, toRow do
		for x = -sideLimit, sideLimit do
			for y = -1, config.height do
				if
					not Cave.isOpen(state, config, row, x, y, time)
					and Cave.isExposed(state, config, row, x, y, time)
				then
					local inside = row >= 0 and math.abs(x) <= config.maxRadius and y >= 0 and y < config.height
					if inside then
						local cell = Cave.cellKind(state, config, row, x, y, time)
						table.insert(cells, { row = row, x = x, y = y, kind = cell.kind, itemId = cell.itemId })
					else
						table.insert(cells, { row = row, x = x, y = y, kind = "bedrock" })
					end
				end
			end
		end
	end
	return cells
end

-- The key of a visible cell; caps get their own keys so they never clash with
-- the real cell of the same row when the window moves on.
function CaveView.cellKey(cell: VisibleCell): string
	local key = CaveView.key(cell.row, cell.x, cell.y)
	if cell.cap then
		return "cap:" .. key
	end
	return key
end

-- Bedrock walls just outside the built rows, so that nobody looks out of the
-- window into the void (the cave itself has no end).
function CaveView.capCells(config: Cave.Config, fromRow: number, toRow: number): { VisibleCell }
	local cells: { VisibleCell } = {}
	local sideLimit = config.maxRadius + 1
	local rows = { toRow + 1 }
	if fromRow > 0 then
		table.insert(rows, fromRow - 1)
	end
	for _, row in rows do
		for x = -sideLimit, sideLimit do
			for y = -1, config.height do
				table.insert(cells, { row = row, x = x, y = y, kind = "bedrock", cap = true })
			end
		end
	end
	return cells
end

-- What to build and what to take down to get from the set of built cells
-- (keys) to the wanted cells.
function CaveView.diff(built: { [string]: boolean }, wanted: { VisibleCell }): Diff
	local wantedKeys: { [string]: boolean } = {}
	local add: { VisibleCell } = {}
	for _, cell in wanted do
		local key = CaveView.cellKey(cell)
		wantedKeys[key] = true
		if not built[key] then
			table.insert(add, cell)
		end
	end
	local remove: { string } = {}
	for key in built do
		if not wantedKeys[key] then
			table.insert(remove, key)
		end
	end
	table.sort(remove)
	return { add = add, remove = remove }
end

-- True when the player's position is close enough to hit the cell.
function CaveView.inReach(
	world: World,
	blockSize: number,
	slot: number,
	playerPosition: Vec,
	row: number,
	x: number,
	y: number
): boolean
	local px, py, pz = playerPosition.x, playerPosition.y, playerPosition.z
	if px ~= px or py ~= py or pz ~= pz then
		return false
	end
	return CaveView.distance(playerPosition, CaveView.cellCenter(world, blockSize, slot, row, x, y)) <= world.reachStuds
end

-- Returns true when the world config is usable, otherwise false and a reason.
function CaveView.validateWorld(world: World, blockSize: number, config: Cave.Config): (boolean, string?)
	if not (world.slopeDegrees >= 0 and world.slopeDegrees <= MAX_SLOPE) then
		return false, "slopeDegrees must be from 0 to " .. MAX_SLOPE
	end
	local width = (config.maxRadius * 2 + 1) * blockSize
	if not (world.slotSpacing > width + blockSize) then
		return false, "slotSpacing must exceed the cave width plus one block"
	end
	for name, value in { windowAhead = world.windowAhead, windowBehind = world.windowBehind } do
		if type(value) ~= "number" or value < 0 or value % 1 ~= 0 then
			return false, name .. " must be a non-negative integer"
		end
	end
	if not (world.reachStuds > 0) then
		return false, "reachStuds must be positive"
	end
	if not (world.maxParts >= MIN_PARTS) then
		return false, "maxParts must be at least " .. MIN_PARTS
	end
	for _, axis in { world.origin.x, world.origin.y, world.origin.z } do
		if type(axis) ~= "number" or axis ~= axis then
			return false, "origin needs numbers"
		end
	end
	return true, nil
end

return CaveView
