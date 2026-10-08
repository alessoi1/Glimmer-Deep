--!strict
-- Builds the town around the plots once at start: roads with center dashes,
-- street lamps at the crossings, the grass belt with trees, a low stone wall on
-- the edge and an invisible wall behind it that keeps everyone inside the town.
-- The geometry is in TownLogic (tested); this module only creates the parts.
-- Only checkable in Roblox Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local ModelSpecs = require(Shared:WaitForChild("ModelSpecs"))
local Config = Shared:WaitForChild("Config")
local PlotConfig = require(Config:WaitForChild("Plot"))
local TownConfig = require(Config:WaitForChild("Town"))
local ModelFactory = require(script.Parent:WaitForChild("ModelFactory"))
local TownLogic = require(script.Parent:WaitForChild("TownLogic"))

local log = Log.new("Town")

local TownService = {}

-- Look of the town (colors, heights); not game values.
local COLOR_ROAD = Color3.fromRGB(62, 64, 70)
local COLOR_DASH = Color3.fromRGB(236, 206, 90)
local ROAD_TOP = 0.01 -- a hair above the ground slabs so nothing flickers
local DASH_TOP = 0.04
local DASH_THICKNESS = 0.1
local TREE_SCALE = 1.5

local started = false

local function color(rgb: { r: number, g: number, b: number }): Color3
	return Color3.fromRGB(rgb.r, rgb.g, rgb.b)
end

-- A flat slab over a rectangle: its top is at `top`, it is `thickness` thick.
local function slab(
	parent: Instance,
	origin: Vector3,
	rect: TownLogic.Rect,
	top: number,
	thickness: number,
	paint: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = rect.name
	part.Anchored = true
	part.Size = Vector3.new(rect.x1 - rect.x0, thickness, rect.z1 - rect.z0)
	part.Position = origin + Vector3.new((rect.x0 + rect.x1) / 2, top - thickness / 2, (rect.z0 + rect.z1) / 2)
	part.Color = paint
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function TownService.start()
	if started then
		log.warn("start called twice")
		return
	end
	started = true

	local town: TownLogic.TownConfig = TownConfig
	local ok, reason = TownLogic.validateConfig(PlotConfig, town)
	if not ok then
		log.error("town config is invalid, no town built", { reason = reason })
		return
	end

	local origin = Vector3.new(PlotConfig.origin.x, PlotConfig.origin.y, PlotConfig.origin.z)
	local palette = ModelFactory.palette
	local folder = Instance.new("Folder")
	folder.Name = "Town"

	local roads = TownLogic.roadRects(PlotConfig)
	for _, rect in roads do
		slab(folder, origin, rect, ROAD_TOP, town.roadThickness, COLOR_ROAD, Enum.Material.Asphalt)
	end
	local dashes = TownLogic.dashRects(PlotConfig, town)
	for _, rect in dashes do
		local dash = slab(folder, origin, rect, DASH_TOP, DASH_THICKNESS, COLOR_DASH, Enum.Material.SmoothPlastic)
		dash.CanCollide = false
	end

	for _, rect in TownLogic.grassRects(PlotConfig, town) do
		slab(folder, origin, rect, 0, town.roadThickness, color(palette.grass), Enum.Material.Grass)
	end

	for _, rect in TownLogic.wallRects(PlotConfig, town, town.lowWall.thickness, false) do
		local wall = slab(
			folder,
			origin,
			rect,
			town.lowWall.height,
			town.lowWall.height,
			color(palette.stone),
			Enum.Material.Cobblestone
		)
		wall.Name = "Low" .. rect.name
	end
	-- The invisible walls: nobody leaves the town, and nothing falls off the edge.
	for _, rect in TownLogic.wallRects(PlotConfig, town, town.invisibleWall.thickness, true) do
		local wall = slab(
			folder,
			origin,
			rect,
			town.invisibleWall.height,
			town.invisibleWall.height,
			COLOR_ROAD,
			Enum.Material.SmoothPlastic
		)
		wall.Name = "Boundary" .. rect.name
		wall.Transparency = 1
		wall.CanTouch = false
	end

	local lamps = TownLogic.lampPoints(PlotConfig, town)
	for _, point in lamps do
		ModelFactory.build(ModelSpecs.streetLamp(palette), origin + Vector3.new(point.x, 0, point.z), folder)
	end
	local trees = TownLogic.treePoints(PlotConfig, town)
	for _, point in trees do
		ModelFactory.build(ModelSpecs.tree(palette, TREE_SCALE), origin + Vector3.new(point.x, 0, point.z), folder)
	end

	folder.Parent = Workspace
	log.info("started", { roads = #roads, dashes = #dashes, lamps = #lamps, trees = #trees })
end

return TownService
