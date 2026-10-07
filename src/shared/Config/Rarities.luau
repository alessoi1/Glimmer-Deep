--!strict
-- Ordered from most common to rarest; the first entry is the "no luck bonus" tier.
-- chance: percent, must sum to 100. minValue: guaranteed NPC price in coins.

return {
	{ id = "common", chance = 60, minValue = 10 },
	{ id = "rare", chance = 25, minValue = 50 },
	{ id = "epic", chance = 10, minValue = 250 },
	{ id = "legendary", chance = 4, minValue = 2000 },
	{ id = "mythic", chance = 1, minValue = 20000 },
}
