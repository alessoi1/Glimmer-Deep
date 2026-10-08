--!strict
-- Selling happens by itself: whoever stands at the sell stand of their own plot
-- sells the backpack and the depot. Starting values.
-- range: how close (studs, horizontal, from the middle of the sell pad) a player
--   must be. The pad has a half width of 4.5, so this is about two studs around it.
-- cooldown: minimum seconds between two sales per player.
-- checkInterval: seconds between two looks at who stands at a sell stand.

return {
	range = 7,
	cooldown = 1,
	checkInterval = 0.4,
}
