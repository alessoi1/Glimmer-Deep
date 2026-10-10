--!strict
-- The cave under the castle (concept: "Höhle und Graben"). Starting values to
-- be balanced; sizes are in blocks. The cave is a straight tunnel in its own
-- grid (row = along the slope, x = sideways from the middle line, y = height
-- above the floor); the world only tilts and places it.

return {
	-- Edge length of one block in studs.
	blockSize = 4,
	-- Blocks from floor to ceiling.
	height = 6,
	-- Rows per slice (the unit that is loaded, saved and regrown together).
	sliceRows = 16,
	-- Meters of depth per row along the slope.
	metersPerRow = 1,
	-- The first rows are an open hall (always air) so the player never starts walled in.
	entranceRows = 3,
	-- Pre-dug corridor for players who already had depth before the cave existed
	-- (sideways radius and height in blocks); it leads from the hall down to the
	-- depth they had reached.
	corridorHalfWidth = 1,
	corridorHeight = 3,
	-- Sideways radius of the hall and the structure limit in blocks (the play
	-- area grows from the first to the last entry of radiusByLevel).
	startRadius = 6,
	maxRadius = 12,
	-- Sideways play-area radius and blocks per swing (edge of a square) by pickaxe level.
	radiusByLevel = { 6, 6, 7, 8, 8, 9, 10, 10, 11, 12 },
	areaByLevel = { 1, 1, 2, 2, 3, 3, 4, 4, 5, 5 },
	-- Share (percent) of wall cells that hold ore or an herb.
	resourceDensity = 30,
	-- Share (percent) of resource cells that are herbs.
	herbShare = 15,
	-- Share (percent) of ore cells that are a find spot (a rare find when mined).
	findSpotShare = 2,
	-- Mined ore and herb cells grow back this many seconds after the last harvest in their slice.
	regrowSeconds = 600,
	-- At most one chest per slice, in the given share (percent) of slices, not before this row.
	chestChance = 35,
	chestMinRow = 6,
	-- A chest comes back this many seconds after it was opened.
	chestRespawnSeconds = 21600,
	-- Seconds between two checks for regrown ore while a player is in the cave.
	refreshSeconds = 30,
	-- Look of the blocks (not a game value).
	look = {
		rock = { r = 96, g = 90, b = 84 },
		bedrock = { r = 52, g = 48, b = 46 },
		chest = { r = 176, g = 120, b = 40 },
		find_spot = { r = 90, g = 200, b = 230 },
		herb = { r = 70, g = 150, b = 70 },
		ore = {
			coal = { r = 30, g = 30, b = 34 },
			copper = { r = 184, g = 110, b = 70 },
			iron = { r = 170, g = 150, b = 140 },
			silver = { r = 200, g = 205, b = 215 },
			gold = { r = 230, g = 190, b = 60 },
			crystal = { r = 130, g = 90, b = 220 },
		},
		oreFallback = { r = 140, g = 140, b = 140 },
	},
	-- Master switch: while false the game keeps using the old shaft. Turn it on
	-- only after the cave was tested in Roblox Studio.
	enabled = false,
	-- Where and how the caves stand in the world. Every player's cave lies in
	-- its own slot, side by side, far below and away from the town.
	world = {
		origin = { x = 3000, y = -600, z = 1500 },
		slotSpacing = 160, -- studs between two caves; more than the cave width
		slopeDegrees = 25, -- how steeply the cave descends
		windowAhead = 24, -- rows built in front of the player
		windowBehind = 12, -- rows kept behind the player
		reachStuds = 16, -- how far the player may be from a cell and still hit it
		maxParts = 3000, -- upper bound of parts one window may need (phones)
	},
}
