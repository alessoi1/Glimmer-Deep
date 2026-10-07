--!strict
-- Shovel levels, from wood to crystal. Placeholder starting values, to be balanced.
-- price: coins for reaching this level (level 1 is free). The concept asks for
--   level 2 at about 100 and level 10 at about 1,000,000 with each level 2 to 3
--   times the previous one; these steps are 3x to 3.3x so both ends match.
-- digCooldown: seconds between two dig actions (a starting backpack of 50 blocks
--   fills in about 30 seconds).
-- cooldownTolerance: the server accepts a dig once this fraction of the cooldown
--   has passed, to absorb network jitter.

return {
	cooldownTolerance = 0.9,
	levels = {
		{ id = "wood", price = 0, digCooldown = 0.6 },
		{ id = "stone", price = 100, digCooldown = 0.55 },
		{ id = "copper", price = 300, digCooldown = 0.5 },
		{ id = "iron", price = 1000, digCooldown = 0.45 },
		{ id = "steel", price = 3000, digCooldown = 0.4 },
		{ id = "silver", price = 10000, digCooldown = 0.35 },
		{ id = "gold", price = 30000, digCooldown = 0.3 },
		{ id = "obsidian", price = 100000, digCooldown = 0.25 },
		{ id = "amethyst", price = 300000, digCooldown = 0.2 },
		{ id = "crystal", price = 1000000, digCooldown = 0.15 },
	},
}
