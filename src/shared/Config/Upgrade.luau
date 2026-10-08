--!strict
-- Buying upgrades with coins. Starting values.
-- order: upgrade ids in the order they are shown.
-- cooldown: minimum seconds between two accepted purchase calls per player.

return {
	order = { "shovel", "backpack" },
	cooldown = 0.3,
}
