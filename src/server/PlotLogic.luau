--!strict
-- Pure plot logic: grid layout, placeholder geometry and plot allocation.
-- No Roblox services or instances (positions are plain numbers), so it is
-- testable without Studio. The PlotService builds the parts and logs.
--
-- Each plot is a square ground slab (shaftDepth thick) with a square shaft in
-- the middle, plus a bottom plate. The plot center is x = 0, z = 0 at ground
-- surface height y = 0.

export type MuseumLayout = {
	x: number,
	z: number,
	columns: number,
	spacing: number,
	vitrineSize: number,
	vitrineHeight: number,
	signX: number,
	signZ: number,
	signSize: number,
}

export type DecorLayout = {
	x: number,
	z: number,
	columns: number,
	spacing: number,
	cell: number,
	signX: number,
	signZ: number,
	signSize: number,
}

export type GuestSignLayout = { x: number, z: number, size: number }

export type RebirthSignLayout = { x: number, z: number, size: number }

export type SeasonSignLayout = { x: number, z: number, size: number }

export type Config = {
	count: number,
	columns: number,
	size: number,
	gap: number,
	shaftSize: number,
	shaftDepth: number,
	bottomThickness: number,
	spawnSize: number,
	spawnHeight: number,
	sellSize: number,
	sellHeight: number,
	museum: MuseumLayout,
	decor: DecorLayout,
	guestSign: GuestSignLayout,
	rebirthSign: RebirthSignLayout,
	seasonSign: SeasonSignLayout,
}

-- Offset of a plot center from the first plot center.
export type Slot = { index: number, x: number, z: number }

-- A box relative to the plot center: size and center position.
export type Box = {
	name: string,
	sizeX: number,
	sizeY: number,
	sizeZ: number,
	x: number,
	y: number,
	z: number,
}

export type Allocator = {
	claim: (owner: number) -> number?,
	release: (owner: number) -> number?,
	slotOf: (owner: number) -> number?,
	ownerOf: (slot: number) -> number?,
	freeCount: () -> number,
}

local PlotLogic = {}

local function isPositiveInteger(value: any): boolean
	return type(value) == "number" and value >= 1 and value % 1 == 0 and value < math.huge
end

local function isPositive(value: any): boolean
	return type(value) == "number" and value > 0 and value < math.huge
end

function PlotLogic.validateConfig(config: Config): (boolean, string?)
	if not isPositiveInteger(config.count) then
		return false, "count must be a positive integer"
	end
	if not isPositiveInteger(config.columns) or config.columns > config.count then
		return false, "columns must be an integer from 1 to count"
	end
	if not isPositive(config.size) then
		return false, "size must be positive"
	end
	if type(config.gap) ~= "number" or config.gap < 0 or config.gap == math.huge then
		return false, "gap must be a non-negative number"
	end
	if not isPositive(config.shaftSize) or config.shaftSize >= config.size then
		return false, "shaftSize must be positive and smaller than size"
	end
	if not isPositive(config.shaftDepth) then
		return false, "shaftDepth must be positive"
	end
	if not isPositive(config.bottomThickness) then
		return false, "bottomThickness must be positive"
	end
	if not isPositive(config.spawnHeight) then
		return false, "spawnHeight must be positive"
	end
	if not isPositive(config.spawnSize) or config.spawnSize > (config.size - config.shaftSize) / 2 then
		return false, "spawnSize must be positive and fit beside the shaft"
	end
	if not isPositive(config.sellHeight) then
		return false, "sellHeight must be positive"
	end
	if not isPositive(config.sellSize) or config.sellSize > (config.size - config.shaftSize) / 2 then
		return false, "sellSize must be positive and fit beside the shaft"
	end
	local museum = config.museum
	if not isPositiveInteger(museum.columns) then
		return false, "museum.columns must be a positive integer"
	end
	if
		not isPositive(museum.vitrineSize)
		or not isPositive(museum.vitrineHeight)
		or not isPositive(museum.signSize)
	then
		return false, "museum sizes must be positive"
	end
	if not isPositive(museum.spacing) or museum.spacing <= museum.vitrineSize then
		return false, "museum.spacing must be larger than vitrineSize"
	end
	local decor = config.decor
	if not isPositiveInteger(decor.columns) or not isPositive(decor.cell) then
		return false, "decor.columns must be a positive integer and decor.cell positive"
	end
	if not isPositive(config.seasonSign.size) then
		return false, "seasonSign.size must be positive"
	end
	if not isPositive(config.rebirthSign.size) then
		return false, "rebirthSign.size must be positive"
	end
	if not isPositive(config.guestSign.size) then
		return false, "guestSign.size must be positive"
	end
	if not isPositive(decor.signSize) then
		return false, "decor.signSize must be positive"
	end
	if not isPositive(decor.spacing) or decor.spacing <= decor.cell then
		return false, "decor.spacing must be larger than decor.cell"
	end
	return true, nil
end

-- Grid positions of all plots, row by row, relative to the first plot.
function PlotLogic.layout(config: Config): { Slot }
	local pitch = config.size + config.gap
	local slots = {}
	for index = 1, config.count do
		local column = (index - 1) % config.columns
		local row = (index - 1) // config.columns
		table.insert(slots, { index = index, x = column * pitch, z = row * pitch })
	end
	return slots
end

local function box(name: string, sizeX: number, sizeY: number, sizeZ: number, x: number, y: number, z: number): Box
	return { name = name, sizeX = sizeX, sizeY = sizeY, sizeZ = sizeZ, x = x, y = y, z = z }
end

-- The ground around the shaft as four slabs, plus the bottom plate of the shaft.
function PlotLogic.groundBoxes(config: Config): { Box }
	local size, depth = config.size, config.shaftDepth
	local half = config.shaftSize / 2
	local edge = size / 2
	local strip = edge - half -- width of the ground beside the shaft
	local centerOffset = half + strip / 2
	local y = -depth / 2
	return {
		box("GroundNorth", size, depth, strip, 0, y, -centerOffset),
		box("GroundSouth", size, depth, strip, 0, y, centerOffset),
		box("GroundWest", strip, depth, config.shaftSize, -centerOffset, y, 0),
		box("GroundEast", strip, depth, config.shaftSize, centerOffset, y, 0),
		box("ShaftBottom", size, config.bottomThickness, size, 0, -depth - config.bottomThickness / 2, 0),
	}
end

-- The spawn pad rests on the surface in the middle of the ground south of the shaft.
function PlotLogic.spawnBox(config: Config): Box
	local half = config.shaftSize / 2
	local centerZ = (half + config.size / 2) / 2
	return box("Spawn", config.spawnSize, config.spawnHeight, config.spawnSize, 0, config.spawnHeight / 2, centerZ)
end

-- The sell point rests on the surface in the middle of the ground north of the
-- shaft, opposite the spawn pad.
function PlotLogic.sellBox(config: Config): Box
	local half = config.shaftSize / 2
	local centerZ = -(half + config.size / 2) / 2
	return box("SellPoint", config.sellSize, config.sellHeight, config.sellSize, 0, config.sellHeight / 2, centerZ)
end

-- Showcase number `slot` (1-based): columns fill first, then the next row south.
function PlotLogic.vitrineBox(config: Config, slot: number): Box
	local museum = config.museum
	local column = (slot - 1) % museum.columns
	local row = (slot - 1) // museum.columns
	return box(
		"Vitrine" .. slot,
		museum.vitrineSize,
		museum.vitrineHeight,
		museum.vitrineSize,
		museum.x + column * museum.spacing,
		museum.vitrineHeight / 2,
		museum.z + row * museum.spacing
	)
end

-- Decoration place `slot` (1-based): columns fill first, then the next row south.
-- The box is the cell the decoration stands in.
function PlotLogic.decorBox(config: Config, slot: number): Box
	local decor = config.decor
	local column = (slot - 1) % decor.columns
	local row = (slot - 1) // decor.columns
	return box(
		"Decor" .. slot,
		decor.cell,
		1,
		decor.cell,
		decor.x + column * decor.spacing,
		0.5,
		decor.z + row * decor.spacing
	)
end

-- The sign with the house prompt.
function PlotLogic.houseSignBox(config: Config): Box
	local decor = config.decor
	return box(
		"HouseSign",
		decor.signSize,
		decor.signSize,
		decor.signSize,
		decor.signX,
		decor.signSize / 2,
		decor.signZ
	)
end

-- The sign with the guest prompt.
function PlotLogic.guestSignBox(config: Config): Box
	local sign = config.guestSign
	return box("GuestSign", sign.size, sign.size, sign.size, sign.x, sign.size / 2, sign.z)
end

-- The sign with the rebirth prompt.
function PlotLogic.rebirthSignBox(config: Config): Box
	local sign = config.rebirthSign
	return box("RebirthSign", sign.size, sign.size, sign.size, sign.x, sign.size / 2, sign.z)
end

-- The sign with the season prompt.
function PlotLogic.seasonSignBox(config: Config): Box
	local sign = config.seasonSign
	return box("SeasonSign", sign.size, sign.size, sign.size, sign.x, sign.size / 2, sign.z)
end

-- The sign (with the museum prompt) stands in front of the showcases.
function PlotLogic.museumSignBox(config: Config): Box
	local museum = config.museum
	return box(
		"MuseumSign",
		museum.signSize,
		museum.signSize,
		museum.signSize,
		museum.signX,
		museum.signSize / 2,
		museum.signZ
	)
end

-- Hands out plots 1..count to owners (user ids). Not thread-safe by design: the
-- server runs it from a single place without yielding between check and claim.
function PlotLogic.newAllocator(count: number): Allocator
	local slotByOwner: { [number]: number } = {}
	local ownerBySlot: { [number]: number } = {}
	local taken = 0

	local function claim(owner: number): number?
		local existing = slotByOwner[owner]
		if existing ~= nil then
			return existing
		end
		for slot = 1, count do
			if ownerBySlot[slot] == nil then
				ownerBySlot[slot] = owner
				slotByOwner[owner] = slot
				taken += 1
				return slot
			end
		end
		return nil
	end

	local function release(owner: number): number?
		local slot = slotByOwner[owner]
		if slot == nil then
			return nil
		end
		slotByOwner[owner] = nil
		ownerBySlot[slot] = nil
		taken -= 1
		return slot
	end

	return {
		claim = claim,
		release = release,
		ownerOf = function(slot: number): number?
			return ownerBySlot[slot]
		end,
		slotOf = function(owner: number): number?
			return slotByOwner[owner]
		end,
		freeCount = function(): number
			return count - taken
		end,
	}
end

return PlotLogic
