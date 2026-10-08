--!strict
-- Pure geometry of the town around the plots: the road network in and around the
-- plot grid, the grass belt, the walls, the center line dashes, the street lamps
-- and the trees in the belt. All positions are relative to the center of the
-- first plot, on the plane (x, z). No Roblox services; the TownService builds
-- the parts from these rectangles.

local PlotLogic = require("./PlotLogic")

export type TownConfig = {
	margin: number,
	roadThickness: number,
	lowWall: { height: number, thickness: number },
	invisibleWall: { height: number, thickness: number },
	dash: { length: number, gap: number, width: number },
	lampInset: number,
	treeSpacing: number,
}

-- A rectangle on the ground: from x0 to x1 and from z0 to z1.
export type Rect = { name: string, x0: number, x1: number, z0: number, z1: number }

export type Point = { x: number, z: number }

local TownLogic = {}

local function rect(name: string, x0: number, x1: number, z0: number, z1: number): Rect
	return { name = name, x0 = x0, x1 = x1, z0 = z0, z1 = z1 }
end

local function isPositive(value: any): boolean
	return type(value) == "number" and value > 0 and value < math.huge
end

-- Returns true when the town can be built, otherwise false and a reason.
function TownLogic.validateConfig(plot: PlotLogic.Config, town: TownConfig): (boolean, string?)
	if plot.count % plot.columns ~= 0 then
		return false, "the plots must fill whole rows (count is a multiple of columns)"
	end
	if not isPositive(plot.gap) then
		return false, "the plot gap is the road width and must be positive"
	end
	for _, field in { "margin", "roadThickness", "lampInset", "treeSpacing" } do
		if not isPositive((town :: any)[field]) then
			return false, field .. " must be positive"
		end
	end
	if not isPositive(town.lowWall.height) or not isPositive(town.lowWall.thickness) then
		return false, "lowWall needs a positive height and thickness"
	end
	if not isPositive(town.invisibleWall.height) or not isPositive(town.invisibleWall.thickness) then
		return false, "invisibleWall needs a positive height and thickness"
	end
	local dash = town.dash
	if not isPositive(dash.length) or not isPositive(dash.gap) or not isPositive(dash.width) then
		return false, "dash needs a positive length, gap and width"
	end
	if town.lampInset >= plot.gap / 2 then
		return false, "lampInset must keep the lamp on the road"
	end
	return true, nil
end

local function rows(plot: PlotLogic.Config): number
	return plot.count // plot.columns
end

local function pitch(plot: PlotLogic.Config): number
	return plot.size + plot.gap
end

-- The square of every plot, in plot order.
function TownLogic.plotRects(plot: PlotLogic.Config): { Rect }
	local list = {}
	local half = plot.size / 2
	for _, slot in PlotLogic.layout(plot) do
		table.insert(list, rect("Plot" .. slot.index, slot.x - half, slot.x + half, slot.z - half, slot.z + half))
	end
	return list
end

-- The area of all plots together with the roads around them.
function TownLogic.roadArea(plot: PlotLogic.Config): Rect
	local half = plot.size / 2
	local width = (plot.columns - 1) * pitch(plot)
	local depth = (rows(plot) - 1) * pitch(plot)
	return rect("RoadArea", -half - plot.gap, width + half + plot.gap, -half - plot.gap, depth + half + plot.gap)
end

-- Where a road line runs: the lines between the plot columns (x) and rows (z),
-- including the outer roads. Index 0 is the outer line before the first plot.
local function lineCenters(plot: PlotLogic.Config, count: number): { number }
	local half = plot.size / 2
	local centers = { -half - plot.gap / 2 }
	for index = 1, count - 1 do
		table.insert(centers, (index - 1) * pitch(plot) + half + plot.gap / 2)
	end
	return centers
end

-- Roads: whatever is between the plots and around them. Horizontal bands run
-- along the whole area; between them the vertical strips lie beside each plot row.
function TownLogic.roadRects(plot: PlotLogic.Config): { Rect }
	local half = plot.size / 2
	local area = TownLogic.roadArea(plot)
	local list: { Rect } = {}
	local rowCount, columnCount = rows(plot), plot.columns
	for index = 0, rowCount do
		local z0 = if index == 0 then area.z0 else (index - 1) * pitch(plot) + half
		local z1 = if index == rowCount then area.z1 else index * pitch(plot) - half
		table.insert(list, rect("RoadBand" .. index, area.x0, area.x1, z0, z1))
	end
	for row = 0, rowCount - 1 do
		for column = 0, columnCount do
			local x0 = if column == 0 then area.x0 else (column - 1) * pitch(plot) + half
			local x1 = if column == columnCount then area.x1 else column * pitch(plot) - half
			table.insert(
				list,
				rect("RoadStrip" .. row .. "_" .. column, x0, x1, row * pitch(plot) - half, row * pitch(plot) + half)
			)
		end
	end
	return list
end

-- The grass belt around the road area: four rectangles, the corners belong to
-- the northern and southern ones.
function TownLogic.grassRects(plot: PlotLogic.Config, town: TownConfig): { Rect }
	local area = TownLogic.roadArea(plot)
	local m = town.margin
	return {
		rect("GrassNorth", area.x0 - m, area.x1 + m, area.z0 - m, area.z0),
		rect("GrassSouth", area.x0 - m, area.x1 + m, area.z1, area.z1 + m),
		rect("GrassWest", area.x0 - m, area.x0, area.z0, area.z1),
		rect("GrassEast", area.x1, area.x1 + m, area.z0, area.z1),
	}
end

-- The outer edge of the town.
function TownLogic.boundary(plot: PlotLogic.Config, town: TownConfig): Rect
	local area = TownLogic.roadArea(plot)
	local m = town.margin
	return rect("Boundary", area.x0 - m, area.x1 + m, area.z0 - m, area.z1 + m)
end

-- Four walls of the given thickness along the boundary. `outside` puts them
-- just beyond the edge, otherwise they stand just inside it.
function TownLogic.wallRects(plot: PlotLogic.Config, town: TownConfig, thickness: number, outside: boolean): { Rect }
	local edge = TownLogic.boundary(plot, town)
	local t = thickness
	if outside then
		return {
			rect("WallNorth", edge.x0 - t, edge.x1 + t, edge.z0 - t, edge.z0),
			rect("WallSouth", edge.x0 - t, edge.x1 + t, edge.z1, edge.z1 + t),
			rect("WallWest", edge.x0 - t, edge.x0, edge.z0, edge.z1),
			rect("WallEast", edge.x1, edge.x1 + t, edge.z0, edge.z1),
		}
	end
	return {
		rect("WallNorth", edge.x0, edge.x1, edge.z0, edge.z0 + t),
		rect("WallSouth", edge.x0, edge.x1, edge.z1 - t, edge.z1),
		rect("WallWest", edge.x0, edge.x0 + t, edge.z0 + t, edge.z1 - t),
		rect("WallEast", edge.x1 - t, edge.x1, edge.z0 + t, edge.z1 - t),
	}
end

-- Street lamps: one at a corner of every crossing.
function TownLogic.lampPoints(plot: PlotLogic.Config, town: TownConfig): { Point }
	local points: { Point } = {}
	local reach = plot.gap / 2 - town.lampInset
	for _, z in lineCenters(plot, rows(plot) + 1) do
		for _, x in lineCenters(plot, plot.columns + 1) do
			table.insert(points, { x = x + reach, z = z + reach })
		end
	end
	return points
end

-- Dashes in the middle of the roads, never inside a crossing.
function TownLogic.dashRects(plot: PlotLogic.Config, town: TownConfig): { Rect }
	local dash = town.dash
	local period = dash.length + dash.gap
	local list: { Rect } = {}
	local area = TownLogic.roadArea(plot)
	local half = plot.size / 2
	local halfGap = plot.gap / 2
	local columnLines = lineCenters(plot, plot.columns + 1)

	local function crossesColumn(x0: number, x1: number): boolean
		for _, x in columnLines do
			if x1 > x - halfGap and x0 < x + halfGap then
				return true
			end
		end
		return false
	end

	-- Along the horizontal bands.
	for bandIndex, z in lineCenters(plot, rows(plot) + 1) do
		local x = area.x0
		local count = 0
		while x + dash.length <= area.x1 do
			if not crossesColumn(x, x + dash.length) then
				count += 1
				table.insert(
					list,
					rect(
						"DashBand" .. bandIndex .. "_" .. count,
						x,
						x + dash.length,
						z - dash.width / 2,
						z + dash.width / 2
					)
				)
			end
			x += period
		end
	end
	-- Along the vertical strips, between the bands.
	for row = 0, rows(plot) - 1 do
		for columnIndex, x in columnLines do
			local z = row * pitch(plot) - half + dash.gap / 2
			local limit = row * pitch(plot) + half - dash.gap / 2
			local count = 0
			while z + dash.length <= limit do
				count += 1
				table.insert(
					list,
					rect(
						"DashStrip" .. row .. "_" .. columnIndex .. "_" .. count,
						x - dash.width / 2,
						x + dash.width / 2,
						z,
						z + dash.length
					)
				)
				z += period
			end
		end
	end
	return list
end

-- Trees on the middle line of the grass belt, evenly spaced.
function TownLogic.treePoints(plot: PlotLogic.Config, town: TownConfig): { Point }
	local area = TownLogic.roadArea(plot)
	local m = town.margin / 2
	local x0, x1, z0, z1 = area.x0 - m, area.x1 + m, area.z0 - m, area.z1 + m
	local points: { Point } = {}
	local function along(fromX: number, fromZ: number, toX: number, toZ: number)
		local length = math.abs(toX - fromX) + math.abs(toZ - fromZ)
		local count = math.max(1, math.floor(length / town.treeSpacing))
		for step = 0, count - 1 do
			local t = step / count
			table.insert(points, { x = fromX + (toX - fromX) * t, z = fromZ + (toZ - fromZ) * t })
		end
	end
	along(x0, z0, x1, z0)
	along(x1, z0, x1, z1)
	along(x1, z1, x0, z1)
	along(x0, z1, x0, z0)
	return points
end

return TownLogic
