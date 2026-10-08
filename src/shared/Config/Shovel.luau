--!strict
-- Shovel levels, from wood to crystal. Placeholder starting values, to be balanced.
-- price: coins for reaching this level (level 1 is free). The concept asks for
--   level 2 at about 100 and level 10 at about 1,000,000 with each level 2 to 3
--   times the previous one; these steps are 3x to 3.3x so both ends match.
-- digCooldown: seconds between two dig actions (a starting backpack of 50 blocks
--   fills in about 30 seconds).
-- rangeBonus: extra studs the player may stand from the shaft while digging
--   (the bigger the shovel, the longer the reach; base range is Config/Dig.digRange).
-- cooldownTolerance: the server accepts a dig once this fraction of the cooldown
--   has passed, to absorb network jitter.

return {
	cooldownTolerance = 0.9,
	levels = {
		{ id = "wood", price = 0, digCooldown = 0.6, rangeBonus = 0 },
		{ id = "stone", price = 100, digCooldown = 0.55, rangeBonus = 0 },
		{ id = "copper", price = 300, digCooldown = 0.5, rangeBonus = 1 },
		{ id = "iron", price = 1000, digCooldown = 0.45, rangeBonus = 1 },
		{ id = "steel", price = 3000, digCooldown = 0.4, rangeBonus = 2 },
		{ id = "silver", price = 10000, digCooldown = 0.35, rangeBonus = 2 },
		{ id = "gold", price = 30000, digCooldown = 0.3, rangeBonus = 3 },
		{ id = "obsidian", price = 100000, digCooldown = 0.25, rangeBonus = 3 },
		{ id = "amethyst", price = 300000, digCooldown = 0.2, rangeBonus = 4 },
		{ id = "crystal", price = 1000000, digCooldown = 0.15, rangeBonus = 5 },
	},
}
