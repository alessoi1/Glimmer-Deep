--!strict
-- Museum values. Placeholder starting values, to be balanced.
-- slotsByHouseLevel: number of showcases per house level (concept: 4, 12, 30, 60).
-- incomePerHourFraction: visitors pay this fraction of the displayed find value
--   (NPC value, already including the mutation multiplier) per hour.
-- incomeMaxHours: income stops growing after this many hours without collecting.
-- setCoinBonus / setLuckBonus: bonus per completed layer set (a find of every
--   type of that layer on display). The coin bonus applies to ore sales and
--   visitor income; luck raises rarity and mutation chances.
-- admireCooldown: seconds before the same visitor can admire the same museum
--   again (kept in server memory only).
-- promptDistance: studs within which the museum prompt is shown.

return {
	slotsByHouseLevel = { 4, 12, 30, 60 },
	incomePerHourFraction = 0.1,
	incomeMaxHours = 4,
	setCoinBonus = 0.1,
	setLuckBonus = 0.05,
	admireCooldown = 6 * 3600,
	promptDistance = 12,
}
