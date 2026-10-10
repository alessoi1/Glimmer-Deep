--!strict
-- Potions (concept: "Tränke"). Starting values, to be balanced. Herbs grow on
-- the cave walls (see Config/Layers); a potion is brewed at the alchemy table
-- from herbs in the stash plus a few coins. Nothing here is sold for Robux.
--
-- effect: "heal" (instant, amount = share of the maximum life), "damage" (multiplier
--   on the damage of hits), "speed" (multiplier on dig and walking speed), "luck"
--   (multiplier on rarity and mutation chances, like the luck booster),
--   "night_vision" (light in the deep biomes, client only).
-- duration: seconds the effect lasts (0 for instant). cooldown: seconds before
--   the same potion can be drunk again.

return {
	order = { "heal", "strength", "speed", "night_vision", "luck" },
	maxOwnedPerPotion = 20,
	maxBrewAtOnce = 5,
	-- A running effect never lasts longer than this many seconds from now.
	maxDuration = 600,
	potions = {
		heal = {
			recipe = { moss_fern = 3 },
			coins = 10,
			effect = "heal",
			amount = 0.4,
			duration = 0,
			cooldown = 20,
		},
		strength = {
			recipe = { shadow_mushroom = 3 },
			coins = 40,
			effect = "damage",
			amount = 1.2,
			duration = 300,
			cooldown = 0,
		},
		speed = {
			recipe = { moss_fern = 2, shadow_mushroom = 1 },
			coins = 30,
			effect = "speed",
			amount = 1.25,
			duration = 300,
			cooldown = 0,
		},
		night_vision = {
			recipe = { shadow_mushroom = 2 },
			coins = 25,
			effect = "night_vision",
			amount = 1,
			duration = 300,
			cooldown = 0,
		},
		luck = {
			recipe = { glimmer_flower = 3 },
			coins = 150,
			effect = "luck",
			amount = 1.25,
			duration = 300,
			cooldown = 0,
		},
	},
}
