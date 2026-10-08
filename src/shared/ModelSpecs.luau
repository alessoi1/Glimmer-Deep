--!strict
-- Pure descriptions of the placeholder models: lists of simple parts (blocks,
-- cylinders, balls) with sizes, positions, colors and materials. Nothing here
-- creates instances; the server's ModelFactory builds them, and uses an
-- uploaded model from assets/models instead when one with the same name
-- exists. No Roblox services, so sizes and positions are checked in specs.
--
-- Coordinates: x, z are studs from the object's center, y is the height of the
-- part's center above the ground at the object's base. Angles are in degrees.
-- A cylinder's axis is x (as in Roblox); rotate it by 90 degrees about z to
-- stand it upright.

export type Rgb = { r: number, g: number, b: number }

export type Palette = {
	grass: Rgb,
	grassDark: Rgb,
	dirt: Rgb,
	stone: Rgb,
	stoneDark: Rgb,
	wood: Rgb,
	woodDark: Rgb,
	roof: Rgb,
	cloth: Rgb,
	glass: Rgb,
	gold: Rgb,
	metal: Rgb,
	marble: Rgb,
	water: Rgb,
	leaf: Rgb,
	leafLight: Rgb,
	terracotta: Rgb,
	sellPad: Rgb,
}

export type Light = { brightness: number, range: number, color: Rgb }

export type PartSpec = {
	name: string,
	shape: string, -- "Block" | "Cylinder" | "Ball"
	sx: number,
	sy: number,
	sz: number,
	x: number,
	y: number,
	z: number,
	rotX: number?,
	rotY: number?,
	rotZ: number?,
	color: Rgb,
	material: string, -- the name of an Enum.Material
	transparency: number?,
	collide: boolean?, -- false for decoration that must not block walking; default true
	light: Light?,
}

export type ModelSpec = {
	name: string,
	primary: string, -- the part prompts and labels attach to
	parts: { PartSpec },
	-- false for models whose size depends on the game state (the museum floor
	-- grows with the house level), so an uploaded model cannot replace them.
	allowOverride: boolean?,
}

export type SceneryConfig = {
	trees: { { x: number, z: number } },
	rocks: { { x: number, z: number, size: number } },
	fencePostSpacing: number,
}

-- Ground box of a part, for checks: center and half sizes on x and z.
export type Footprint = { x: number, z: number, halfX: number, halfZ: number }

local ModelSpecs = {}

ModelSpecs.shapes = { "Block", "Cylinder", "Ball" }
ModelSpecs.materials = {
	"Plastic",
	"SmoothPlastic",
	"Wood",
	"WoodPlanks",
	"Cobblestone",
	"Slate",
	"Brick",
	"Metal",
	"Glass",
	"Neon",
	"Fabric",
	"Grass",
	"Sand",
	"Rock",
	"Concrete",
	"Marble",
	"Granite",
	"Ground",
}

-- Kinds of models the factory builds. The name is also the name of the file in
-- assets/models that replaces the placeholder.
ModelSpecs.kinds = {
	shaft = "ShaftRim",
	sell = "SellStand",
	sign = "Sign",
	vitrine = "Vitrine",
	vitrineFilled = "VitrineFilled",
	museumFloor = "MuseumFloor",
	scenery = "Scenery",
}

local DEFAULT_DECOR_PREFIX = "Decor_"

-- Name of the sign model with this id ("Museum", "House", "Guests", "Rebirth", "Season").
function ModelSpecs.signKind(id: string): string
	return "Sign_" .. id
end

function ModelSpecs.decorKind(id: string): string
	return DEFAULT_DECOR_PREFIX .. id
end

local function part(
	name: string,
	shape: string,
	size: { number },
	position: { number },
	color: Rgb,
	material: string,
	extra: { [string]: any }?
): PartSpec
	local spec: PartSpec = {
		name = name,
		shape = shape,
		sx = size[1],
		sy = size[2],
		sz = size[3],
		x = position[1],
		y = position[2],
		z = position[3],
		color = color,
		material = material,
	}
	for key, value in extra or {} do
		(spec :: any)[key] = value
	end
	return spec
end

-- Horizontal footprint of a part. A rotation that is not a multiple of 90
-- degrees about y uses the circle around the part, which is always safe.
function ModelSpecs.footprint(spec: PartSpec): Footprint
	local sx, sy, sz = spec.sx, spec.sy, spec.sz
	local rotX = (spec.rotX or 0) % 180
	local rotZ = (spec.rotZ or 0) % 180
	if rotZ == 90 then
		sx, sy = sy, sx
	end
	if rotX == 90 then
		sy, sz = sz, sy
	end
	if spec.shape == "Ball" then
		local diameter = math.max(sx, sy, sz)
		sx, sz = diameter, diameter
	end
	local rotY = (spec.rotY or 0) % 90
	if rotY ~= 0 then
		local radius = math.sqrt(sx * sx + sz * sz) / 2
		return { x = spec.x, z = spec.z, halfX = radius, halfZ = radius }
	end
	if (spec.rotY or 0) % 180 == 90 then
		sx, sz = sz, sx
	end
	return { x = spec.x, z = spec.z, halfX = sx / 2, halfZ = sz / 2 }
end

-- Height range of a part (bottom, top), for checks.
function ModelSpecs.heightRange(spec: PartSpec): (number, number)
	local sx, sy, sz = spec.sx, spec.sy, spec.sz
	local rotX = (spec.rotX or 0) % 180
	local rotZ = (spec.rotZ or 0) % 180
	if rotZ == 90 then
		sy = sx
	elseif rotX == 90 then
		sy = sz
	end
	if spec.shape == "Ball" then
		sy = math.max(sx, sy, sz)
	end
	return spec.y - sy / 2, spec.y + sy / 2
end

-- Shaft rim and winch ------------------------------------------------------------------

local RIM_WIDTH = 1.2
local RIM_HEIGHT = 0.6
local POST_HEIGHT = 4
local DRUM_RADIUS = 0.5

-- A stone rim around the shaft opening with a winch, rope and bucket. The
-- opening stays free: nothing stands inside `shaftSize`.
function ModelSpecs.shaftRim(palette: Palette, shaftSize: number): ModelSpec
	local half = shaftSize / 2
	local full = shaftSize + 2 * RIM_WIDTH
	local offset = half + RIM_WIDTH / 2
	local postX = half + RIM_WIDTH / 2
	local drumY = RIM_HEIGHT + POST_HEIGHT
	return {
		name = ModelSpecs.kinds.shaft,
		primary = "RimNorth",
		parts = {
			part(
				"RimNorth",
				"Block",
				{ full, RIM_HEIGHT, RIM_WIDTH },
				{ 0, RIM_HEIGHT / 2, -offset },
				palette.stone,
				"Cobblestone"
			),
			part(
				"RimSouth",
				"Block",
				{ full, RIM_HEIGHT, RIM_WIDTH },
				{ 0, RIM_HEIGHT / 2, offset },
				palette.stone,
				"Cobblestone"
			),
			part(
				"RimWest",
				"Block",
				{ RIM_WIDTH, RIM_HEIGHT, shaftSize },
				{ -offset, RIM_HEIGHT / 2, 0 },
				palette.stone,
				"Cobblestone"
			),
			part(
				"RimEast",
				"Block",
				{ RIM_WIDTH, RIM_HEIGHT, shaftSize },
				{ offset, RIM_HEIGHT / 2, 0 },
				palette.stone,
				"Cobblestone"
			),
			part(
				"PostWest",
				"Block",
				{ 0.5, POST_HEIGHT, 0.5 },
				{ -postX, RIM_HEIGHT + POST_HEIGHT / 2, 0 },
				palette.woodDark,
				"Wood"
			),
			part(
				"PostEast",
				"Block",
				{ 0.5, POST_HEIGHT, 0.5 },
				{ postX, RIM_HEIGHT + POST_HEIGHT / 2, 0 },
				palette.woodDark,
				"Wood"
			),
			part(
				"Drum",
				"Cylinder",
				{ shaftSize, DRUM_RADIUS * 2, DRUM_RADIUS * 2 },
				{ 0, drumY, 0 },
				palette.wood,
				"Wood",
				{ collide = false }
			),
			part(
				"Crank",
				"Block",
				{ 0.3, 0.3, 1.6 },
				{ postX + 0.6, drumY, 0.6 },
				palette.metal,
				"Metal",
				{ collide = false }
			),
			part(
				"Rope",
				"Block",
				{ 0.1, 2.6, 0.1 },
				{ 0, drumY - 1.5, 0 },
				palette.cloth,
				"Fabric",
				{ collide = false }
			),
			part(
				"Bucket",
				"Block",
				{ 0.9, 0.8, 0.9 },
				{ 0, drumY - 3.2, 0 },
				palette.woodDark,
				"Wood",
				{ collide = false }
			),
		},
	}
end

-- Sell stand ---------------------------------------------------------------------------

-- A stall on the green sell pad: counter, roof on four posts, crates and a
-- coin pile with a lantern. The pad is the primary part and keeps the size of
-- the old placeholder.
function ModelSpecs.sellStand(palette: Palette, size: number, height: number): ModelSpec
	local corner = size / 2 - 0.4
	local postHeight = 3.6
	local roofY = height + postHeight + 0.2
	return {
		name = ModelSpecs.kinds.sell,
		primary = "SellPoint",
		parts = {
			part("SellPoint", "Block", { size, height, size }, { 0, height / 2, 0 }, palette.sellPad, "SmoothPlastic"),
			part(
				"PostA",
				"Block",
				{ 0.4, postHeight, 0.4 },
				{ -corner, height + postHeight / 2, -corner },
				palette.woodDark,
				"Wood"
			),
			part(
				"PostB",
				"Block",
				{ 0.4, postHeight, 0.4 },
				{ corner, height + postHeight / 2, -corner },
				palette.woodDark,
				"Wood"
			),
			part(
				"PostC",
				"Block",
				{ 0.4, postHeight, 0.4 },
				{ -corner, height + postHeight / 2, corner },
				palette.woodDark,
				"Wood"
			),
			part(
				"PostD",
				"Block",
				{ 0.4, postHeight, 0.4 },
				{ corner, height + postHeight / 2, corner },
				palette.woodDark,
				"Wood"
			),
			part(
				"Roof",
				"Block",
				{ size + 0.8, 0.4, size + 0.8 },
				{ 0, roofY, 0 },
				palette.roof,
				"Fabric",
				{ collide = false }
			),
			part(
				"Counter",
				"Block",
				{ size * 0.66, 1.4, 1.2 },
				{ 0, height + 0.7, -corner + 1.0 },
				palette.wood,
				"WoodPlanks"
			),
			part(
				"CrateA",
				"Block",
				{ 1.1, 1.1, 1.1 },
				{ -corner + 0.9, height + 0.55, corner - 0.9 },
				palette.woodDark,
				"WoodPlanks"
			),
			part(
				"CrateB",
				"Block",
				{ 0.9, 0.9, 0.9 },
				{ -corner + 2.1, height + 0.45, corner - 0.8 },
				palette.wood,
				"WoodPlanks"
			),
			part(
				"CoinPile",
				"Cylinder",
				{ 0.3, 0.9, 0.9 },
				{ 0.4, height + 1.55, -corner + 1.0 },
				palette.gold,
				"Neon",
				{ rotZ = 90, collide = false }
			),
			part("Lantern", "Ball", { 0.5, 0.5, 0.5 }, { 0, roofY - 0.6, 0 }, palette.gold, "Neon", {
				collide = false,
				light = { brightness = 1.2, range = 14, color = palette.gold },
			}),
		},
	}
end

-- Signs --------------------------------------------------------------------------------

-- A wooden post with a colored board. The board is the primary part; prompts and
-- labels attach to it. `size` is the width of the board.
function ModelSpecs.sign(palette: Palette, size: number, color: Rgb, name: string?): ModelSpec
	local postHeight = 2
	local boardHeight = size * 0.66
	local boardY = postHeight + boardHeight / 2
	return {
		name = name or ModelSpecs.kinds.sign,
		primary = "Board",
		parts = {
			part("Post", "Block", { 0.5, postHeight, 0.5 }, { 0, postHeight / 2, 0 }, palette.woodDark, "Wood"),
			part("Board", "Block", { size, boardHeight, 0.4 }, { 0, boardY, 0 }, color, "WoodPlanks"),
			part(
				"Cap",
				"Block",
				{ size + 0.4, 0.25, 0.8 },
				{ 0, boardY + boardHeight / 2 + 0.12, 0 },
				palette.woodDark,
				"Wood",
				{ collide = false }
			),
		},
	}
end

-- Museum -------------------------------------------------------------------------------

-- A glass showcase on a wooden base. The glass is the primary part. A filled
-- showcase shows a glowing gem.
function ModelSpecs.vitrine(palette: Palette, size: number, height: number, filled: boolean): ModelSpec
	local baseHeight = height * 0.33
	local glassHeight = height * 0.6
	local capHeight = height - baseHeight - glassHeight
	local glassY = baseHeight + glassHeight / 2
	local parts: { PartSpec } = {
		part("Base", "Block", { size, baseHeight, size }, { 0, baseHeight / 2, 0 }, palette.woodDark, "WoodPlanks"),
		part(
			"Cushion",
			"Block",
			{ size * 0.7, 0.15, size * 0.7 },
			{ 0, baseHeight + 0.07, 0 },
			palette.roof,
			"Fabric",
			{ collide = false }
		),
		part(
			"Vitrine",
			"Block",
			{ size * 0.9, glassHeight, size * 0.9 },
			{ 0, glassY, 0 },
			palette.glass,
			"Glass",
			{ transparency = 0.55 }
		),
		part("Cap", "Block", { size, capHeight, size }, { 0, height - capHeight / 2, 0 }, palette.woodDark, "Wood"),
	}
	if filled then
		table.insert(
			parts,
			part("Gem", "Ball", { 0.7, 0.7, 0.7 }, { 0, baseHeight + 0.55, 0 }, palette.gold, "Neon", {
				collide = false,
				light = { brightness = 0.8, range = 8, color = palette.gold },
			})
		)
	end
	return {
		name = if filled then ModelSpecs.kinds.vitrineFilled else ModelSpecs.kinds.vitrine,
		primary = "Vitrine",
		parts = parts,
	}
end

-- A floor under the showcase grid. `columns` x `rows` showcases `spacing` apart.
function ModelSpecs.museumFloor(palette: Palette, columns: number, rows: number, spacing: number): ModelSpec
	local width = columns * spacing
	local depth = rows * spacing
	return {
		name = ModelSpecs.kinds.museumFloor,
		primary = "Floor",
		allowOverride = false,
		parts = {
			part("Floor", "Block", { width, 0.2, depth }, { 0, 0.1, 0 }, palette.marble, "Marble", { collide = false }),
			part(
				"Carpet",
				"Block",
				{ width - 1, 0.22, depth - 1 },
				{ 0, 0.11, 0 },
				palette.roof,
				"Fabric",
				{ collide = false }
			),
		},
	}
end

-- Decoration ---------------------------------------------------------------------------

local decorBuilders: { [string]: (palette: Palette) -> { PartSpec } } = {
	potted_plant = function(palette)
		return {
			part("Pot", "Block", { 1.4, 1, 1.4 }, { 0, 0.5, 0 }, palette.terracotta, "Concrete"),
			part("LeavesLow", "Ball", { 2, 2, 2 }, { 0, 1.9, 0 }, palette.leaf, "Grass", { collide = false }),
			part(
				"LeavesHigh",
				"Ball",
				{ 1.3, 1.3, 1.3 },
				{ 0.2, 2.9, 0.1 },
				palette.leafLight,
				"Grass",
				{ collide = false }
			),
		}
	end,
	lantern = function(palette)
		return {
			part("Base", "Block", { 1, 0.3, 1 }, { 0, 0.15, 0 }, palette.stoneDark, "Concrete"),
			part("Pole", "Block", { 0.3, 4, 0.3 }, { 0, 2.3, 0 }, palette.metal, "Metal"),
			part("Lamp", "Block", { 0.9, 0.9, 0.9 }, { 0, 4.75, 0 }, palette.gold, "Neon", {
				collide = false,
				light = { brightness = 1.4, range = 16, color = palette.gold },
			}),
			part("Hood", "Block", { 1.2, 0.2, 1.2 }, { 0, 5.3, 0 }, palette.metal, "Metal", { collide = false }),
		}
	end,
	rug = function(palette)
		return {
			part("Rug", "Block", { 5, 0.15, 4 }, { 0, 0.075, 0 }, palette.roof, "Fabric", { collide = false }),
			part("Inlay", "Block", { 4, 0.18, 3 }, { 0, 0.09, 0 }, palette.cloth, "Fabric", { collide = false }),
			part("Center", "Block", { 2.4, 0.2, 1.6 }, { 0, 0.1, 0 }, palette.roof, "Fabric", { collide = false }),
		}
	end,
	banner = function(palette)
		return {
			part("PoleLeft", "Block", { 0.25, 6, 0.25 }, { -1.5, 3, 0 }, palette.woodDark, "Wood"),
			part("PoleRight", "Block", { 0.25, 6, 0.25 }, { 1.5, 3, 0 }, palette.woodDark, "Wood"),
			part("Beam", "Block", { 3.4, 0.25, 0.25 }, { 0, 5.9, 0 }, palette.woodDark, "Wood", { collide = false }),
			part(
				"Cloth",
				"Block",
				{ 2.6, 3.8, 0.15 },
				{ 0, 3.8, 0 },
				{ r = 90, g = 100, b = 190 },
				"Fabric",
				{ collide = false }
			),
			part("Emblem", "Ball", { 0.8, 0.8, 0.8 }, { 0, 4.2, 0.1 }, palette.gold, "Neon", { collide = false }),
		}
	end,
	statue = function(palette)
		return {
			part("Pedestal", "Block", { 2.5, 1.5, 2.5 }, { 0, 0.75, 0 }, palette.marble, "Marble"),
			part("Body", "Block", { 1, 2, 0.8 }, { 0, 2.5, 0 }, palette.marble, "Marble"),
			part("Head", "Ball", { 0.9, 0.9, 0.9 }, { 0, 3.9, 0 }, palette.marble, "Marble"),
			part(
				"ArmLeft",
				"Block",
				{ 0.3, 1.6, 0.3 },
				{ -0.7, 2.6, 0 },
				palette.marble,
				"Marble",
				{ collide = false }
			),
			part(
				"ArmRight",
				"Block",
				{ 0.3, 1.9, 0.3 },
				{ 0.7, 3.1, 0 },
				palette.marble,
				"Marble",
				{ collide = false }
			),
			part("Torch", "Ball", { 0.5, 0.5, 0.5 }, { 0.7, 4.2, 0 }, palette.gold, "Neon", {
				collide = false,
				light = { brightness = 1, range = 10, color = palette.gold },
			}),
		}
	end,
	fountain = function(palette)
		return {
			part("Basin", "Cylinder", { 0.9, 4.2, 4.2 }, { 0, 0.45, 0 }, palette.stone, "Cobblestone", { rotZ = 90 }),
			part(
				"Water",
				"Cylinder",
				{ 0.2, 3.6, 3.6 },
				{ 0, 0.85, 0 },
				palette.water,
				"SmoothPlastic",
				{ rotZ = 90, transparency = 0.35, collide = false }
			),
			part("Column", "Cylinder", { 2.4, 0.6, 0.6 }, { 0, 1.9, 0 }, palette.stone, "Cobblestone", { rotZ = 90 }),
			part(
				"Bowl",
				"Cylinder",
				{ 0.4, 1.8, 1.8 },
				{ 0, 3.2, 0 },
				palette.stone,
				"Cobblestone",
				{ rotZ = 90, collide = false }
			),
			part(
				"Spray",
				"Ball",
				{ 0.7, 0.7, 0.7 },
				{ 0, 3.7, 0 },
				palette.water,
				"Neon",
				{ collide = false, transparency = 0.2 }
			),
		}
	end,
}

-- The decoration with this id, or nil for an unknown id. The primary part is
-- the first one, so a label attaches to the base.
function ModelSpecs.decor(palette: Palette, id: string): ModelSpec?
	local builder = decorBuilders[id]
	if builder == nil then
		return nil
	end
	local parts = builder(palette)
	return { name = ModelSpecs.decorKind(id), primary = parts[1].name, parts = parts }
end

-- Scenery -----------------------------------------------------------------------------

local TREE_TRUNK_HEIGHT = 5
local TREE_TRUNK_WIDTH = 1.2
local FENCE_POST_HEIGHT = 1.8
local FENCE_INSET = 0.6
local FENCE_GATE = 8 -- half width of the gap on the south side
local ROCK_SQUASH = 0.7

-- Trees, rocks and fence posts for one plot, positions from the plot center.
function ModelSpecs.scenery(palette: Palette, plotSize: number, scenery: SceneryConfig): ModelSpec
	local parts: { PartSpec } = {}
	for index, tree in scenery.trees do
		table.insert(
			parts,
			part(
				"TreeTrunk" .. index,
				"Block",
				{ TREE_TRUNK_WIDTH, TREE_TRUNK_HEIGHT, TREE_TRUNK_WIDTH },
				{ tree.x, TREE_TRUNK_HEIGHT / 2, tree.z },
				palette.woodDark,
				"Wood"
			)
		)
		table.insert(
			parts,
			part(
				"TreeLeavesA" .. index,
				"Ball",
				{ 5.4, 5.4, 5.4 },
				{ tree.x, TREE_TRUNK_HEIGHT + 1.6, tree.z },
				palette.leaf,
				"Grass",
				{ collide = false }
			)
		)
		table.insert(
			parts,
			part(
				"TreeLeavesB" .. index,
				"Ball",
				{ 3.6, 3.6, 3.6 },
				{ tree.x + 0.5, TREE_TRUNK_HEIGHT + 3.8, tree.z - 0.3 },
				palette.leafLight,
				"Grass",
				{ collide = false }
			)
		)
	end
	for index, rock in scenery.rocks do
		table.insert(
			parts,
			part(
				"Rock" .. index,
				"Block",
				{ rock.size, rock.size * ROCK_SQUASH, rock.size * 0.9 },
				{ rock.x, rock.size * ROCK_SQUASH / 2, rock.z },
				palette.stoneDark,
				"Rock",
				{ rotY = 30 + index * 40 }
			)
		)
	end
	-- Fence posts along the edge, with a gap at the south side (the entrance).
	local half = plotSize / 2 - FENCE_INSET
	local spacing = scenery.fencePostSpacing
	local steps = math.floor(plotSize / spacing)
	for step = 0, steps do
		local at = -half + step * (2 * half / steps)
		for _, side in { "North", "South", "West", "East" } do
			local x, z = at, -half
			if side == "South" then
				z = half
			elseif side == "West" then
				x, z = -half, at
			elseif side == "East" then
				x, z = half, at
			end
			local isGate = side == "South" and math.abs(x) < FENCE_GATE
			if not isGate then
				table.insert(
					parts,
					part(
						"Fence" .. side .. step,
						"Block",
						{ 0.3, FENCE_POST_HEIGHT, 0.3 },
						{ x, FENCE_POST_HEIGHT / 2, z },
						palette.wood,
						"Wood",
						{ collide = false }
					)
				)
			end
		end
	end
	return { name = ModelSpecs.kinds.scenery, primary = parts[1].name, parts = parts }
end

return ModelSpecs
