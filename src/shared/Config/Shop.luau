--!strict
-- Game passes (bought once with Robux). Starting values from the concept, to be
-- tested. Everything here can also be reached by playing, only slower; passes
-- never change auction prices or the odds of finds directly.
-- gamePassId: the id from the Creator Dashboard. 0 means "not created yet": the
--   shop shows the pass as not available and never prompts a purchase. Fill in
--   the real ids after creating the passes (see docs/OFFEN.md).
-- robux: the price shown in the shop (the real price is set in the dashboard).
-- effect: bonuses while owned, as a Modifiers part (see src/shared/Modifiers).
--   "Doppelte Münzen" only affects ore sales, never finds or auctions.
-- perk: effects that are no plain bonus; the server code that handles them looks
--   for the name ("quickTravel").
-- order: the order of the passes in the shop.
-- Passes that need later content are listed in the concept but not here yet:
-- auction slots (Update 1), the second pet slot (pets) and the season pass.

return {
	order = { "night_shift", "double_coins", "quick_travel", "backpack_plus" },
	passes = {
		night_shift = { gamePassId = 2021582250, robux = 299, effect = { offlineHoursBonus = 4 } },
		double_coins = { gamePassId = 2019008458, robux = 399, effect = { oreSaleFactor = 2 } },
		quick_travel = { gamePassId = 2021462258, robux = 199, perk = "quickTravel" },
		backpack_plus = { gamePassId = 2021714253, robux = 249, effect = { capacityBonus = 0.2 } },
	},
	-- Seconds between two quick trips.
	quickTravelCooldown = 5,
}
