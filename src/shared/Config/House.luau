--!strict
-- House values. Placeholder starting values, to be balanced.
-- maxLevel: the highest house level that can be bought. The concept has four
--   levels; levels 3 and 4 are Update 2, so the launch stops at 2.
-- upgradeCosts: coins to reach the level with this number (level 1 is free).
-- decorSlotsByLevel: how many decoration places the house has per level.
-- items: decoration that costs coins and is kept once bought. Purely cosmetic.
--   size and color are only used to build the placeholder in the world.
-- order: the order of the decorations in the panel.
-- actionCooldown: minimum seconds between two house actions per player.
-- promptDistance: studs within which the house prompt is shown.
-- useDistance: studs within which the owner can open the panel.

return {
	maxLevel = 2,
	upgradeCosts = { 0, 10000 },
	decorSlotsByLevel = { 0, 6 },
	actionCooldown = 0.4,
	promptDistance = 12,
	useDistance = 24,
	order = { "potted_plant", "lantern", "rug", "banner", "statue", "fountain" },
	items = {
		potted_plant = { price = 250, sizeX = 2, sizeY = 3, sizeZ = 2, color = { r = 70, g = 150, b = 80 } },
		lantern = { price = 400, sizeX = 1, sizeY = 5, sizeZ = 1, color = { r = 240, g = 200, b = 100 } },
		rug = { price = 600, sizeX = 5, sizeY = 0.2, sizeZ = 4, color = { r = 170, g = 70, b = 70 } },
		banner = { price = 900, sizeX = 3, sizeY = 6, sizeZ = 0.4, color = { r = 90, g = 100, b = 190 } },
		statue = { price = 1500, sizeX = 2.5, sizeY = 5, sizeZ = 2.5, color = { r = 190, g = 190, b = 200 } },
		fountain = { price = 2500, sizeX = 4, sizeY = 2.5, sizeZ = 4, color = { r = 90, g = 170, b = 220 } },
	},
}
