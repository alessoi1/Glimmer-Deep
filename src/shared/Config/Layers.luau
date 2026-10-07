--!strict
-- The three launch layers (depth in meters). Layers must be contiguous:
-- maxDepth of one layer equals minDepth of the next. Deeper than the last
-- layer keeps using the last layer until further layers ship.

return {
	{
		id = "sand_clay",
		minDepth = 0,
		maxDepth = 50,
		ores = { "coal", "copper" },
		finds = { "shard", "shell" },
	},
	{
		id = "rock",
		minDepth = 50,
		maxDepth = 150,
		ores = { "iron", "silver" },
		finds = { "fossil", "amber" },
	},
	{
		id = "crystal",
		minDepth = 150,
		maxDepth = 300,
		ores = { "gold", "crystal" },
		finds = { "gemstone" },
	},
}
