--!strict
-- Armor and weapons (concept: "Schmiede, Rüstung und Waffen"). Starting values,
-- to be balanced. The tier follows the ore; tiers 1 to 5 ship at launch, the
-- later ores (obsidian, ruby, sapphire, glow ore) come with the later biomes.
--
-- life: bonus life of a complete armor set of this tier (shared among the four
--   armor slots by lifeShare). damage: damage per hit of the weapon of this tier.
-- Strength (for the zones of the overworld) is life times damage.

return {
	slots = { "weapon", "helmet", "armor", "legs", "boots" },
	weaponSlot = "weapon",
	baseLife = 100,
	baseDamage = 10,
	tiers = {
		{ id = "copper", ore = "copper", life = 30, damage = 14 },
		{ id = "iron", ore = "iron", life = 70, damage = 19 },
		{ id = "silver", ore = "silver", life = 120, damage = 26 },
		{ id = "gold", ore = "gold", life = 180, damage = 35 },
		{ id = "crystal", ore = "crystal", life = 250, damage = 46 },
	},
	-- Share of the tier's life that each armor slot gives (adds up to 1).
	lifeShare = { helmet = 0.2, armor = 0.4, legs = 0.25, boots = 0.15 },
	-- Ore needed per piece (of the tier's ore) and coins for the lowest tier.
	oreCost = { weapon = 15, helmet = 10, armor = 20, legs = 15, boots = 10 },
	coinCost = { weapon = 100, helmet = 60, armor = 120, legs = 90, boots = 60 },
	-- Coin cost multiplier for each tier above the first.
	coinGrowth = 3,
	-- Highest tier that can come from Robux packages (they are account-bound).
	shopMaxTier = 3,
	-- How many pieces a player may own.
	maxOwned = 60,
}
