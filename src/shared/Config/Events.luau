--!strict
-- Weekly events. Placeholder starting values, to be balanced. One event runs
-- for a whole week (Thursday 00:00 UTC to the next); the week number picks
-- the event from the rotation, so every server shows the same one and a
-- finished rotation starts again at the first event.
-- rotation: event ids in the order they run.
-- events: what an event does while it runs.
--   mutation: a mutation that is `factor` times more likely among mutated finds
--     (digging only; the offline digger does not use it).
--   bonus: a Modifiers part that every player gets (see src/shared/Modifiers).
--   hostCoinFactor: multiplies the coins a host gets for guest blocks.
-- Everything an event gives can also be earned without it, only slower.

return {
	rotation = { "opening", "glow_week", "friends_week", "season_finale" },
	events = {
		opening = {
			mutation = { id = "golden", factor = 2 },
			bonus = { coinBonus = 0.05 },
			hostCoinFactor = 1,
		},
		glow_week = {
			mutation = { id = "glowing", factor = 4 },
			bonus = { luckBonus = 0.05 },
			hostCoinFactor = 1,
		},
		friends_week = {
			bonus = { coinBonus = 0.1 },
			hostCoinFactor = 2,
		},
		season_finale = {
			mutation = { id = "shimmering", factor = 3 },
			bonus = { tempoBonus = 0.1 },
			hostCoinFactor = 1,
		},
	},
}
