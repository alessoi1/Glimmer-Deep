--!strict
-- Boosters (Developer Products, bought repeatedly with Robux). Starting values
-- from the concept, to be tested. A booster only works for its buyer, runs for a
-- fixed time and never changes auction prices.
-- productId: the id from the Creator Dashboard. 0 means "not created yet": the
--   shop shows the booster as not available and never prompts a purchase.
-- robux: the price shown in the shop (the real price is set in the dashboard).
-- durationSeconds: how long one purchase runs.
-- effect: bonuses while running, as a Modifiers part (see src/shared/Modifiers).
-- paidRandom: true for boosters that change chances (paid random items). They
--   are hidden from players whom PolicyService restricts; those players get
--   freeClaim instead.
-- maxStackSeconds: buying again while a booster runs adds time, but the
--   remaining time never exceeds this.
-- receiptHistory: how many purchase ids the profile remembers to catch
--   repeated receipts.
-- freeClaim: the way to get the luck booster for restricted players, without
--   Robux: one free run per cooldown.

return {
	order = { "luck_booster", "tempo_booster" },
	boosters = {
		luck_booster = {
			productId = 0,
			robux = 39,
			durationSeconds = 15 * 60,
			effect = { luckBonus = 0.25 },
			paidRandom = true,
		},
		tempo_booster = {
			productId = 0,
			robux = 49,
			durationSeconds = 30 * 60,
			effect = { tempoBonus = 1 }, -- x2 dig speed
			paidRandom = false,
		},
	},
	maxStackSeconds = 2 * 60 * 60,
	receiptHistory = 100,
	freeClaim = { boosterId = "luck_booster", cooldownSeconds = 24 * 60 * 60 },
}
