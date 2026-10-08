--!strict
-- Plots (studs). 8 plots per server in a grid joined by roads (see Config/Town);
-- each plot is a square ground slab with a fixed square shaft in the middle.
-- Everything is drawn for a player of about 5 studs height. Starting values.

return {
	count = 8,
	columns = 4,
	size = 96,
	gap = 24, -- the width of the roads between the plots
	shaftSize = 12,
	shaftDepth = 60,
	bottomThickness = 2,
	spawnSize = 9,
	spawnHeight = 1.5,
	sellSize = 9,
	sellHeight = 1.5,
	-- World position of the first plot's center (ground surface at y). Far away
	-- from the default Baseplate so Studio test places do not overlap.
	origin = { x = 3000, y = 0, z = 0 },
	-- Museum area east of the shaft: showcases in a grid (first column x, first row
	-- z, centers) and the sign with the prompt in front of it.
	museum = {
		x = 15,
		z = -39,
		columns = 5,
		spacing = 6,
		vitrineSize = 3,
		vitrineHeight = 4.5,
		signX = 30,
		signZ = -45,
		signSize = 4.5,
	},
	-- Decoration places west of the shaft: a grid (first column x, first row z,
	-- centers) of square cells; every decoration stays inside its cell.
	decor = {
		x = -36,
		z = -39,
		columns = 3,
		spacing = 10.5,
		cell = 7.5,
		-- The house sign (with the house prompt) stands between the decoration and the shaft.
		signX = -27,
		signZ = -15,
		signSize = 4.5,
	},
	-- The guest sign (with the guest prompt) stands south-west of the shaft.
	guestSign = { x = -27, z = 15, size = 4.5 },
	-- The rebirth sign (with the rebirth prompt) stands east of the shaft, below the showcases.
	rebirthSign = { x = 24, z = 12, size = 4.5 },
	-- The season sign (with the season prompt) stands east of the shaft, below the rebirth sign.
	seasonSign = { x = 24, z = 21, size = 4.5 },
	colors = {
		ground = { r = 96, g = 120, b = 70 },
		shaftBottom = { r = 70, g = 60, b = 50 },
		spawn = { r = 230, g = 200, b = 90 },
		sell = { r = 90, g = 190, b = 120 },
		vitrine = { r = 200, g = 200, b = 215 },
		vitrineFilled = { r = 240, g = 200, b = 90 },
		sign = { r = 120, g = 90, b = 200 },
		seasonSign = { r = 230, g = 190, b = 90 },
		rebirthSign = { r = 200, g = 90, b = 90 },
		guestSign = { r = 90, g = 190, b = 190 },
		houseSign = { r = 220, g = 150, b = 80 },
	},
}
