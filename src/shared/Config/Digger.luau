--!strict
-- The digger helper that keeps digging while the player is away. Placeholder
-- starting values, to be balanced.
-- levels: price in coins for reaching the level (level 1 is free), blocksPerHour
--   is how many blocks it digs per hour of absence at that level.
-- maxHours: offline time that counts (the "Nachtschicht" pass adds hours on top).
-- rareFindChanceFactor: the rare find chance offline is this fraction of the
--   active chance (concept: lower than while digging actively).
-- minSeconds: shorter absences give no report and no yield.
-- maxBlocks: upper bound of blocks simulated per return.
-- depotCapacity: items (ore units and finds) the depot holds; more is lost.

return {
	maxHours = 4,
	rareFindChanceFactor = 0.5,
	minSeconds = 60,
	maxBlocks = 20000,
	depotCapacity = 3000,
	levels = {
		{ price = 0, blocksPerHour = 60 },
		{ price = 500, blocksPerHour = 120 },
		{ price = 2000, blocksPerHour = 240 },
		{ price = 8000, blocksPerHour = 480 },
		{ price = 30000, blocksPerHour = 960 },
		{ price = 120000, blocksPerHour = 1920 },
	},
}
