--!strict
-- Skills the player buys with coins. Placeholder starting values, to be balanced.
-- Each track is a normal upgrade track: level 1 is free and has no effect, price
-- is for reaching the level. The bonus of a level replaces the one of the level
-- before (it is not added up). Bonuses are fractions (0.05 = +5 %).
--   strong_arms: tempoBonus    faster digging ("Starke Arme")
--   ore_finder:  rareFindBonus higher chance of a rare find per block ("Erzspürer")
--   cable_winch: walkSpeedBonus faster walking between shaft, sell point and
--                museum ("Seilwinde"; there is no lift to speed up)
--   lamp:        luckBonus     better rarity and mutation chances ("Lampe")
-- baseWalkSpeed: Roblox default walk speed that the winch bonus is applied to.

return {
	baseWalkSpeed = 16,
	tracks = {
		strong_arms = {
			levels = {
				{ price = 0 },
				{ price = 300, tempoBonus = 0.05 },
				{ price = 1500, tempoBonus = 0.1 },
				{ price = 7500, tempoBonus = 0.15 },
				{ price = 40000, tempoBonus = 0.2 },
			},
		},
		ore_finder = {
			levels = {
				{ price = 0 },
				{ price = 400, rareFindBonus = 0.1 },
				{ price = 2000, rareFindBonus = 0.2 },
				{ price = 10000, rareFindBonus = 0.3 },
				{ price = 50000, rareFindBonus = 0.4 },
			},
		},
		cable_winch = {
			levels = {
				{ price = 0 },
				{ price = 250, walkSpeedBonus = 0.1 },
				{ price = 1200, walkSpeedBonus = 0.2 },
				{ price = 6000, walkSpeedBonus = 0.3 },
			},
		},
		lamp = {
			levels = {
				{ price = 0 },
				{ price = 500, luckBonus = 0.05 },
				{ price = 2500, luckBonus = 0.1 },
				{ price = 12500, luckBonus = 0.15 },
				{ price = 60000, luckBonus = 0.2 },
			},
		},
	},
}
