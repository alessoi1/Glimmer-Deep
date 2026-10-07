--!strict
-- Placeholder plots (studs). 8 plots per server in a grid; each plot is a square
-- ground slab with a fixed square shaft in the middle. Starting values.

return {
	count = 8,
	columns = 4,
	size = 64,
	gap = 16,
	shaftSize = 8,
	shaftDepth = 40,
	bottomThickness = 2,
	spawnSize = 6,
	spawnHeight = 1,
	-- World position of the first plot's center (ground surface at y). Far away
	-- from the default Baseplate so Studio test places do not overlap.
	origin = { x = 1000, y = 0, z = 0 },
	colors = {
		ground = { r = 96, g = 120, b = 70 },
		shaftBottom = { r = 70, g = 60, b = 50 },
		spawn = { r = 230, g = 200, b = 90 },
	},
}
