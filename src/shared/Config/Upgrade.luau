--!strict
-- Buying upgrades with coins. Starting values.
-- order: upgrade ids in the order they are shown.
-- cooldown: minimum seconds between two accepted purchase calls per player.

return {
	order = { "shovel", "backpack", "digger", "strong_arms", "ore_finder", "cable_winch", "lamp" },
	cooldown = 0.3,
}
