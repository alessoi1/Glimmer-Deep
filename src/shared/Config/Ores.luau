--!strict
-- NPC sell price per ore in coins. Placeholder starting values, to be balanced:
-- a full starting backpack (50 slots) in layer 1 pays about 75 to 85 coins, so
-- the first shovel upgrade (100 coins) is afforded with the golden onboarding
-- find or a second trip. Deeper layers pay more per ore.

return {
	-- Layer 1: Sand und Lehm
	coal = 1,
	copper = 2,
	-- Layer 2: Fels
	iron = 4,
	silver = 8,
	-- Layer 3: Kristallschicht
	gold = 16,
	crystal = 32,
}
