--!strict
local Framework = require("../Framework")
local HouseConfig = require("../../src/shared/Config/House")
local Look = require("../../src/shared/Config/Look")
local ModelSpecs = require("../../src/shared/ModelSpecs")
local MuseumConfig = require("../../src/shared/Config/Museum")
local PlotConfig = require("../../src/shared/Config/Plot")
local PlotLogic = require("../../src/server/PlotLogic")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals

local palette: ModelSpecs.Palette = Look.palette
local PLOT_HALF = PlotConfig.size / 2

local function allSpecs(): { ModelSpecs.ModelSpec }
	local specs = {
		ModelSpecs.shaftRim(palette, PlotConfig.shaftSize),
		ModelSpecs.sellStand(palette, PlotConfig.sellSize, PlotConfig.sellHeight),
		ModelSpecs.sign(palette, PlotConfig.guestSign.size, PlotConfig.colors.guestSign),
		ModelSpecs.vitrine(palette, PlotConfig.museum.vitrineSize, PlotConfig.museum.vitrineHeight, false),
		ModelSpecs.vitrine(palette, PlotConfig.museum.vitrineSize, PlotConfig.museum.vitrineHeight, true),
		ModelSpecs.museumFloor(palette, PlotConfig.museum.columns, 3, PlotConfig.museum.spacing),
		ModelSpecs.scenery(palette, PlotConfig.size, Look.scenery),
	}
	for _, id in HouseConfig.order do
		local decor = ModelSpecs.decor(palette, id)
		assertTrue(decor ~= nil, "decor spec for " .. id)
		if decor ~= nil then
			table.insert(specs, decor)
		end
	end
	return specs
end

local function overlaps(a: ModelSpecs.Footprint, b: ModelSpecs.Footprint): boolean
	return math.abs(a.x - b.x) < a.halfX + b.halfX and math.abs(a.z - b.z) < a.halfZ + b.halfZ
end

local function boxFootprint(box: PlotLogic.Box): ModelSpecs.Footprint
	return { x = box.x, z = box.z, halfX = box.sizeX / 2, halfZ = box.sizeZ / 2 }
end

-- Basic rules --------------------------------------------------------------------------

test("every part has a valid shape, material, color, size and unique name", function()
	for _, spec in allSpecs() do
		for _, p in spec.parts do
			if p.shape == "Ball" then
				assertTrue(p.sx == p.sy and p.sy == p.sz, spec.name .. "/" .. p.name .. " is a ball with unequal sizes")
			end
		end
		local names: { [string]: boolean } = {}
		local hasPrimary = false
		for _, p in spec.parts do
			local label = spec.name .. "/" .. p.name
			assertTrue(table.find(ModelSpecs.shapes, p.shape) ~= nil, label .. " shape " .. p.shape)
			assertTrue(table.find(ModelSpecs.materials, p.material) ~= nil, label .. " material " .. p.material)
			assertTrue(p.sx > 0 and p.sy > 0 and p.sz > 0, label .. " has a positive size")
			for _, channel in { p.color.r, p.color.g, p.color.b } do
				assertTrue(channel >= 0 and channel <= 255, label .. " color channel")
			end
			assertTrue(p.transparency == nil or (p.transparency >= 0 and p.transparency <= 1), label .. " transparency")
			assertTrue(not names[p.name], label .. " has a duplicate name")
			names[p.name] = true
			if p.name == spec.primary then
				hasPrimary = true
			end
			if p.light ~= nil then
				assertTrue(p.light.brightness > 0 and p.light.range > 0, label .. " light")
			end
		end
		assertTrue(hasPrimary, spec.name .. " has its primary part")
	end
end)

test("nothing starts below the ground", function()
	for _, spec in allSpecs() do
		for _, p in spec.parts do
			local bottom = ModelSpecs.heightRange(p)
			assertTrue(bottom >= -1e-9, spec.name .. "/" .. p.name .. " bottom " .. bottom)
		end
	end
end)

test("the kinds are unique names, so an uploaded model can replace each one", function()
	local seen: { [string]: boolean } = {}
	for _, kind in ModelSpecs.kinds do
		assertTrue(not seen[kind], kind .. " is used twice")
		seen[kind] = true
	end
	for _, id in HouseConfig.order do
		local kind = ModelSpecs.decorKind(id)
		assertTrue(not seen[kind], kind .. " is used twice")
		seen[kind] = true
	end
end)

test("an unknown decoration has no spec", function()
	assertEquals(ModelSpecs.decor(palette, "ghost"), nil)
end)

-- Footprints ---------------------------------------------------------------------------

test("footprints follow rotation", function()
	local base: ModelSpecs.PartSpec = {
		name = "x",
		shape = "Block",
		sx = 4,
		sy = 1,
		sz = 2,
		x = 5,
		y = 0.5,
		z = -3,
		color = palette.stone,
		material = "Rock",
	}
	local plain = ModelSpecs.footprint(base)
	assertEquals(plain.halfX, 2)
	assertEquals(plain.halfZ, 1)
	local turned = ModelSpecs.footprint(setmetatable({ rotY = 90 }, { __index = base }) :: any)
	assertEquals(turned.halfX, 1)
	assertEquals(turned.halfZ, 2)
	local slanted = ModelSpecs.footprint(setmetatable({ rotY = 30 }, { __index = base }) :: any)
	assertTrue(slanted.halfX >= 2 and slanted.halfX == slanted.halfZ, "the circle around the part")
	local upright = ModelSpecs.footprint(
		setmetatable({ shape = "Cylinder", rotZ = 90, sx = 1, sy = 3, sz = 3 }, { __index = base }) :: any
	)
	assertEquals(upright.halfX, 1.5, "an upright cylinder is as wide as its diameter")
end)

-- Fit ----------------------------------------------------------------------------------

test("the shaft rim leaves the opening free", function()
	local spec = ModelSpecs.shaftRim(palette, PlotConfig.shaftSize)
	local hole: ModelSpecs.Footprint =
		{ x = 0, z = 0, halfX = PlotConfig.shaftSize / 2, halfZ = PlotConfig.shaftSize / 2 }
	for _, p in spec.parts do
		if p.collide ~= false then
			assertTrue(not overlaps(ModelSpecs.footprint(p), hole), p.name .. " stands in the opening")
		end
	end
end)

test("the rim and the pads do not touch", function()
	local rim = ModelSpecs.shaftRim(palette, PlotConfig.shaftSize)
	local pads = { boxFootprint(PlotLogic.spawnBox(PlotConfig)), boxFootprint(PlotLogic.sellBox(PlotConfig)) }
	for _, p in rim.parts do
		for _, pad in pads do
			assertTrue(not overlaps(ModelSpecs.footprint(p), pad), p.name .. " touches a pad")
		end
	end
end)

test("the sell stand keeps the size of the old sell pad", function()
	local spec = ModelSpecs.sellStand(palette, PlotConfig.sellSize, PlotConfig.sellHeight)
	local pad
	for _, p in spec.parts do
		if p.name == spec.primary then
			pad = p
		end
	end
	assertTrue(pad ~= nil)
	if pad ~= nil then
		assertEquals(pad.sx, PlotConfig.sellSize)
		assertEquals(pad.sy, PlotConfig.sellHeight)
		assertEquals(pad.y, PlotConfig.sellHeight / 2)
	end
end)

test("a vitrine fits its place and is as high as configured", function()
	for _, filled in { false, true } do
		local spec = ModelSpecs.vitrine(palette, PlotConfig.museum.vitrineSize, PlotConfig.museum.vitrineHeight, filled)
		local top = 0
		for _, p in spec.parts do
			local fp = ModelSpecs.footprint(p)
			assertTrue(fp.halfX * 2 <= PlotConfig.museum.vitrineSize + 1e-9, p.name .. " wider than the place")
			assertTrue(fp.halfZ * 2 <= PlotConfig.museum.vitrineSize + 1e-9, p.name .. " deeper than the place")
			local _, upper = ModelSpecs.heightRange(p)
			top = math.max(top, upper)
		end
		assertEquals(top, PlotConfig.museum.vitrineHeight)
	end
	local empty = ModelSpecs.vitrine(palette, 2, 3, false)
	local filled = ModelSpecs.vitrine(palette, 2, 3, true)
	assertEquals(#filled.parts, #empty.parts + 1, "the filled showcase has a gem")
	assertTrue(empty.name ~= filled.name)
end)

test("the museum floor covers the showcases of the highest launch level", function()
	local rows = math.ceil(MuseumConfig.slotsByHouseLevel[2] / PlotConfig.museum.columns)
	local spec = ModelSpecs.museumFloor(palette, PlotConfig.museum.columns, rows, PlotConfig.museum.spacing)
	local floor = spec.parts[1]
	assertEquals(floor.sx, PlotConfig.museum.columns * PlotConfig.museum.spacing)
	assertEquals(floor.sz, rows * PlotConfig.museum.spacing)
end)

test("every decoration stays inside its cell and below a sensible height", function()
	local half = PlotConfig.decor.cell / 2
	for _, id in HouseConfig.order do
		local spec = ModelSpecs.decor(palette, id)
		assertTrue(spec ~= nil)
		if spec ~= nil then
			for _, p in spec.parts do
				local fp = ModelSpecs.footprint(p)
				assertTrue(math.abs(fp.x) + fp.halfX <= half + 1e-9, id .. "/" .. p.name .. " leaves the cell (x)")
				assertTrue(math.abs(fp.z) + fp.halfZ <= half + 1e-9, id .. "/" .. p.name .. " leaves the cell (z)")
				local _, top = ModelSpecs.heightRange(p)
				assertTrue(top <= 6.5, id .. "/" .. p.name .. " is too high")
			end
		end
	end
end)

test("the museum sign and the other signs have a board of the configured width", function()
	for _, size in
		{
			PlotConfig.museum.signSize,
			PlotConfig.decor.signSize,
			PlotConfig.guestSign.size,
			PlotConfig.rebirthSign.size,
			PlotConfig.seasonSign.size,
		}
	do
		local spec = ModelSpecs.sign(palette, size, palette.stone)
		for _, p in spec.parts do
			if p.name == spec.primary then
				assertEquals(p.sx, size)
			end
		end
	end
end)

test("scenery stays on the plot and clear of everything that matters", function()
	local spec = ModelSpecs.scenery(palette, PlotConfig.size, Look.scenery)
	local obstacles: { ModelSpecs.Footprint } = {
		boxFootprint(PlotLogic.spawnBox(PlotConfig)),
		boxFootprint(PlotLogic.sellBox(PlotConfig)),
		boxFootprint(PlotLogic.museumSignBox(PlotConfig)),
		boxFootprint(PlotLogic.houseSignBox(PlotConfig)),
		boxFootprint(PlotLogic.guestSignBox(PlotConfig)),
		boxFootprint(PlotLogic.rebirthSignBox(PlotConfig)),
		boxFootprint(PlotLogic.seasonSignBox(PlotConfig)),
		{ x = 0, z = 0, halfX = PlotConfig.shaftSize / 2 + 1.5, halfZ = PlotConfig.shaftSize / 2 + 1.5 },
	}
	for number = 1, MuseumConfig.slotsByHouseLevel[2] do
		table.insert(obstacles, boxFootprint(PlotLogic.vitrineBox(PlotConfig, number)))
	end
	for number = 1, HouseConfig.decorSlotsByLevel[HouseConfig.maxLevel] do
		table.insert(obstacles, boxFootprint(PlotLogic.decorBox(PlotConfig, number)))
	end
	for _, p in spec.parts do
		local fp = ModelSpecs.footprint(p)
		assertTrue(math.abs(fp.x) + fp.halfX <= PLOT_HALF + 1e-9, p.name .. " leaves the plot (x)")
		assertTrue(math.abs(fp.z) + fp.halfZ <= PLOT_HALF + 1e-9, p.name .. " leaves the plot (z)")
		for _, obstacle in obstacles do
			assertTrue(not overlaps(fp, obstacle), p.name .. " stands in the way")
		end
	end
end)

test("the fence leaves a gate on the south side and has no solid post", function()
	local spec = ModelSpecs.scenery(palette, PlotConfig.size, Look.scenery)
	local posts = 0
	for _, p in spec.parts do
		if string.sub(p.name, 1, 5) == "Fence" then
			posts += 1
			assertEquals(p.collide, false, p.name .. " must not block walking")
			if string.sub(p.name, 6, 10) == "South" then
				assertTrue(math.abs(p.x) >= 8, p.name .. " stands in the gate")
			end
		end
	end
	assertTrue(posts > 20)
end)

test("the look config has sane lighting values", function()
	local look = Look.lighting
	assertTrue(look.clockTime >= 0 and look.clockTime <= 24)
	assertTrue(look.brightness > 0)
	for _, rgb in { look.ambient, look.outdoorAmbient, look.atmosphere.color, look.atmosphere.decay } do
		for _, channel in { rgb.r, rgb.g, rgb.b } do
			assertTrue(channel >= 0 and channel <= 255)
		end
	end
	assertTrue(look.atmosphere.density >= 0 and look.atmosphere.density <= 1)
	assertTrue(look.atmosphere.haze >= 0 and look.atmosphere.haze <= 10)
	assertTrue(look.bloom.intensity >= 0 and look.bloom.size >= 0 and look.bloom.threshold >= 0)
	assertTrue(look.colorCorrection.saturation >= -1 and look.colorCorrection.saturation <= 1)
	assertTrue(look.sunRays.intensity >= 0 and look.sunRays.intensity <= 1)
end)

test("the sign kinds are named by id", function()
	assertEquals(ModelSpecs.signKind("Museum"), "Sign_Museum")
	local spec = ModelSpecs.sign(palette, 3, palette.stone, ModelSpecs.signKind("House"))
	assertEquals(spec.name, "Sign_House")
	assertEquals(ModelSpecs.sign(palette, 3, palette.stone).name, ModelSpecs.kinds.sign)
end)

test("only the museum floor refuses an uploaded replacement", function()
	for _, spec in allSpecs() do
		if spec.name == ModelSpecs.kinds.museumFloor then
			assertEquals(spec.allowOverride, false)
		else
			assertTrue(spec.allowOverride ~= false, spec.name .. " can be replaced")
		end
	end
end)
