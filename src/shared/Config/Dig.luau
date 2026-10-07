--!strict
-- Starting values from docs concept (section "Spielsysteme"); to be balanced in playtests.
-- All chances are percentages (0-100).

return {
	-- Chance that a dug block contains a rare find instead of ore (1 in 50).
	rareFindChance = 2,
	-- Base chance that a rare find carries a mutation.
	mutationChance = 5,
	-- Upper bound for luck multipliers (skills, pets, boosters).
	maxLuck = 10,
	-- Upper bound for the multiplier on the rare find chance (skill "Erzspürer").
	maxRareFindBonus = 5,
}
