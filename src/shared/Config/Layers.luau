--!strict
-- The three launch layers (depth in meters). Layers must be contiguous:
-- maxDepth of one layer equals minDepth of the next. Deeper than the last
-- layer keeps using the last layer until further layers ship.
-- herbs: plants that grow on the cave walls of this layer (potions, later).

return {
	{
		id = "sand_clay",
		minDepth = 0,
		maxDepth = 50,
		ores = { "coal", "copper" },
		herbs = { "moss_fern" },
		finds = { "shard", "shell" },
	},
	{
		id = "rock",
		minDepth = 50,
		maxDepth = 150,
		ores = { "iron", "silver" },
		herbs = { "shadow_mushroom" },
		finds = { "fossil", "amber" },
	},
	{
		id = "crystal",
		minDepth = 150,
		maxDepth = 300,
		ores = { "gold", "crystal" },
		herbs = { "glimmer_flower" },
		finds = { "gemstone" },
	},
}
