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
	sellSize = 6,
	sellHeight = 1,
	-- World position of the first plot's center (ground surface at y). Far away
	-- from the default Baseplate so Studio test places do not overlap.
	origin = { x = 3000, y = 0, z = 0 },
	-- Museum area east of the shaft: showcases in a grid (first column x, first row
	-- z, centers) and the sign with the prompt in front of it.
	museum = {
		x = 10,
		z = -26,
		columns = 5,
		spacing = 4,
		vitrineSize = 2,
		vitrineHeight = 3,
		signX = 20,
		signZ = -30,
		signSize = 3,
	},
	colors = {
		ground = { r = 96, g = 120, b = 70 },
		shaftBottom = { r = 70, g = 60, b = 50 },
		spawn = { r = 230, g = 200, b = 90 },
		sell = { r = 90, g = 190, b = 120 },
		vitrine = { r = 200, g = 200, b = 215 },
		vitrineFilled = { r = 240, g = 200, b = 90 },
		sign = { r = 120, g = 90, b = 200 },
	},
}
