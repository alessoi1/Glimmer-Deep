--!strict
local Framework = require("../Framework")
local PlotConfig = require("../../src/shared/Config/Plot")
local PlotLogic = require("../../src/server/PlotLogic")
local TownConfig = require("../../src/shared/Config/Town")
local TownLogic = require("../../src/server/TownLogic")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals
local assertNear = Framework.assertNear

local plot: PlotLogic.Config = PlotConfig
local town: TownLogic.TownConfig = TownConfig

local EPSILON = 1e-6

local function area(r: TownLogic.Rect): number
	return (r.x1 - r.x0) * (r.z1 - r.z0)
end

local function overlap(a: TownLogic.Rect, b: TownLogic.Rect): boolean
	return a.x0 < b.x1 - EPSILON and b.x0 < a.x1 - EPSILON and a.z0 < b.z1 - EPSILON and b.z0 < a.z1 - EPSILON
end

local function inside(point: TownLogic.Point, r: TownLogic.Rect): boolean
	return point.x > r.x0 and point.x < r.x1 and point.z > r.z0 and point.z < r.z1
end

local function containedIn(inner: TownLogic.Rect, outer: TownLogic.Rect): boolean
	return inner.x0 >= outer.x0 - EPSILON
		and inner.x1 <= outer.x1 + EPSILON
		and inner.z0 >= outer.z0 - EPSILON
		and inner.z1 <= outer.z1 + EPSILON
end

local function with(changes: { [string]: any }): TownLogic.TownConfig
	local copy: any = table.clone(town)
	for key, value in changes do
		copy[key] = value
	end
	return copy
end

-- Config -----------------------------------------------------------------------------

test("the shipped town config is valid", function()
	local ok, reason = TownLogic.validateConfig(plot, town)
	assertTrue(ok, reason)
end)

test("validateConfig rejects a town that cannot be built", function()
	local broken: any = table.clone(plot)
	broken.count = 7
	assertTrue(not TownLogic.validateConfig(broken, town), "incomplete last row")
	broken = table.clone(plot)
	broken.gap = 0
	assertTrue(not TownLogic.validateConfig(broken, town), "no road")
	assertTrue(not TownLogic.validateConfig(plot, with({ margin = 0 })))
	assertTrue(not TownLogic.validateConfig(plot, with({ lampInset = plot.gap })), "lamp off the road")
	assertTrue(not TownLogic.validateConfig(plot, with({ dash = { length = 0, gap = 1, width = 1 } })))
	assertTrue(not TownLogic.validateConfig(plot, with({ lowWall = { height = 0, thickness = 1 } })))
	assertTrue(not TownLogic.validateConfig(plot, with({ invisibleWall = { height = 10, thickness = 0 } })))
end)

-- Roads ------------------------------------------------------------------------------

test("roads never overlap a plot or each other", function()
	local roads = TownLogic.roadRects(plot)
	local plots = TownLogic.plotRects(plot)
	assertEquals(#plots, plot.count)
	for _, road in roads do
		for _, p in plots do
			assertTrue(not overlap(road, p), road.name .. " overlaps " .. p.name)
		end
	end
	for index, road in roads do
		for other = index + 1, #roads do
			assertTrue(not overlap(road, roads[other]), road.name .. " overlaps " .. roads[other].name)
		end
	end
end)

test("the plots and the roads fill the road area completely", function()
	local total = 0
	for _, road in TownLogic.roadRects(plot) do
		assertTrue(area(road) > 0, road.name .. " has an area")
		total += area(road)
	end
	total += plot.count * plot.size * plot.size
	assertNear(total, area(TownLogic.roadArea(plot)), 1e-6)
end)

test("every road is as wide as the plot gap", function()
	for _, road in TownLogic.roadRects(plot) do
		local narrow = math.min(road.x1 - road.x0, road.z1 - road.z0)
		assertNear(narrow, plot.gap, 1e-9, road.name)
	end
end)

test("every plot touches a road on all four sides", function()
	local roads = TownLogic.roadRects(plot)
	for _, p in TownLogic.plotRects(plot) do
		local probes = {
			{ x = (p.x0 + p.x1) / 2, z = p.z0 - plot.gap / 2 },
			{ x = (p.x0 + p.x1) / 2, z = p.z1 + plot.gap / 2 },
			{ x = p.x0 - plot.gap / 2, z = (p.z0 + p.z1) / 2 },
			{ x = p.x1 + plot.gap / 2, z = (p.z0 + p.z1) / 2 },
		}
		for _, probe in probes do
			local found = false
			for _, road in roads do
				if inside(probe, road) then
					found = true
				end
			end
			assertTrue(found, p.name .. " has no road on one side")
		end
	end
end)

-- Grass and walls --------------------------------------------------------------------

test("the grass belt and the road area fill the town without overlap", function()
	local roadArea = TownLogic.roadArea(plot)
	local belt = TownLogic.grassRects(plot, town)
	local total = area(roadArea)
	for index, grass in belt do
		total += area(grass)
		assertTrue(not overlap(grass, roadArea), grass.name .. " overlaps the roads")
		for other = index + 1, #belt do
			assertTrue(not overlap(grass, belt[other]), grass.name .. " overlaps " .. belt[other].name)
		end
	end
	assertNear(total, area(TownLogic.boundary(plot, town)), 1e-6)
end)

test("the outside walls close the town on all sides and stay outside", function()
	local edge = TownLogic.boundary(plot, town)
	local walls = TownLogic.wallRects(plot, town, town.invisibleWall.thickness, true)
	assertEquals(#walls, 4)
	for _, wall in walls do
		assertTrue(not overlap(wall, edge), wall.name .. " reaches into the town")
	end
	-- The walls touch each other around the corners: no gap to slip through.
	local north, south, west, east = walls[1], walls[2], walls[3], walls[4]
	assertTrue(north.x0 <= west.x0 and north.x1 >= east.x1)
	assertTrue(south.x0 <= west.x0 and south.x1 >= east.x1)
	assertNear(west.x1, edge.x0, 1e-9)
	assertNear(east.x0, edge.x1, 1e-9)
	assertNear(north.z1, edge.z0, 1e-9)
	assertNear(south.z0, edge.z1, 1e-9)
	assertTrue(town.invisibleWall.height >= 60, "too high to jump over")
end)

test("the visible low wall stands inside the town edge without gaps", function()
	local edge = TownLogic.boundary(plot, town)
	local walls = TownLogic.wallRects(plot, town, town.lowWall.thickness, false)
	local total = 0
	for index, wall in walls do
		assertTrue(containedIn(wall, edge), wall.name .. " leaves the town")
		total += area(wall)
		for other = index + 1, #walls do
			assertTrue(not overlap(wall, walls[other]), wall.name .. " overlaps " .. walls[other].name)
		end
	end
	local t = town.lowWall.thickness
	local inner = (edge.x1 - edge.x0 - 2 * t) * (edge.z1 - edge.z0 - 2 * t)
	assertNear(total, area(edge) - inner, 1e-6, "a closed ring")
end)

-- Furniture --------------------------------------------------------------------------

test("a street lamp stands at every crossing, on the road and off the plots", function()
	local lamps = TownLogic.lampPoints(plot, town)
	local rowCount = plot.count // plot.columns
	assertEquals(#lamps, (rowCount + 1) * (plot.columns + 1))
	local roads = TownLogic.roadRects(plot)
	local plots = TownLogic.plotRects(plot)
	for index, lamp in lamps do
		local onRoad = false
		for _, road in roads do
			if inside(lamp, road) then
				onRoad = true
			end
		end
		assertTrue(onRoad, "lamp " .. index .. " is not on a road")
		for _, p in plots do
			assertTrue(not inside(lamp, p), "lamp " .. index .. " stands on " .. p.name)
		end
	end
end)

test("the center dashes lie on the roads, off the plots and out of the crossings", function()
	local dashes = TownLogic.dashRects(plot, town)
	assertTrue(#dashes > 20)
	local roads = TownLogic.roadRects(plot)
	local plots = TownLogic.plotRects(plot)
	local names: { [string]: boolean } = {}
	for _, dash in dashes do
		assertTrue(not names[dash.name], dash.name .. " is used twice")
		names[dash.name] = true
		local onRoad = false
		for _, road in roads do
			if containedIn(dash, road) then
				onRoad = true
			end
		end
		assertTrue(onRoad, dash.name .. " is not on one road")
		for _, p in plots do
			assertTrue(not overlap(dash, p), dash.name .. " overlaps " .. p.name)
		end
	end
	-- A band dash never reaches into a vertical road (the crossing stays free).
	for _, dash in dashes do
		if string.sub(dash.name, 1, 8) == "DashBand" then
			for _, road in roads do
				if string.sub(road.name, 1, 9) == "RoadStrip" then
					assertTrue(not overlap(dash, road), dash.name .. " crosses " .. road.name)
				end
			end
		end
	end
end)

test("trees stand in the grass belt", function()
	local trees = TownLogic.treePoints(plot, town)
	assertTrue(#trees >= 8)
	local belt = TownLogic.grassRects(plot, town)
	for index, tree in trees do
		local inBelt = false
		for _, grass in belt do
			if inside(tree, grass) then
				inBelt = true
			end
		end
		assertTrue(inBelt, "tree " .. index .. " is not in the grass belt")
	end
end)
