--!strict
-- Loot of the chests in the cave (concept: "Truhen"). Starting values. Chests
-- are never bought with Robux; the chances are shown in the game as percent.
--
-- rolls: how many items one chest holds (inclusive range).
-- entries: kinds of loot with their weight (the chance is weight over the sum).
-- gear: tier = the biome's number, with gearBonusChance percent one higher.
-- coins: coinBase for the first biome, times coinGrowth for each biome after it.

return {
	rolls = { min = 2, max = 3 },
	entries = {
		{ kind = "gear", weight = 25 },
		{ kind = "potion", weight = 25 },
		{ kind = "herb", weight = 20 },
		{ kind = "coins", weight = 20 },
		{ kind = "find", weight = 10 },
	},
	gearBonusChance = 20,
	herbCount = { min = 3, max = 6 },
	potionCount = { min = 1, max = 2 },
	coinBase = 50,
	coinGrowth = 3,
}
