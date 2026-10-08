--!strict
-- The look of the world: colors and lighting. Not game values; nothing here
-- changes how the game plays. Colors are { r, g, b } from 0 to 255.
-- palette: the colors the placeholder models are built from.
-- lighting: the sky, sun and post effects. clockTime is the hour of the day
--   (14 = afternoon sun); a fixed time keeps the world readable.
-- scenery: where trees and rocks stand on a plot (x, z from the plot center)
--   and how far apart the fence posts are. A spec checks that nothing blocks
--   the shaft, pads, signs, showcases or decoration.

return {
	palette = {
		grass = { r = 112, g = 158, b = 78 },
		grassDark = { r = 84, g = 128, b = 62 },
		dirt = { r = 122, g = 92, b = 64 },
		stone = { r = 150, g = 150, b = 156 },
		stoneDark = { r = 98, g = 98, b = 106 },
		wood = { r = 150, g = 104, b = 62 },
		woodDark = { r = 98, g = 66, b = 40 },
		roof = { r = 176, g = 70, b = 60 },
		cloth = { r = 236, g = 226, b = 200 },
		glass = { r = 170, g = 215, b = 235 },
		gold = { r = 255, g = 205, b = 70 },
		metal = { r = 70, g = 74, b = 84 },
		marble = { r = 232, g = 232, b = 236 },
		water = { r = 90, g = 170, b = 225 },
		leaf = { r = 76, g = 140, b = 70 },
		leafLight = { r = 104, g = 168, b = 84 },
		terracotta = { r = 190, g = 110, b = 80 },
		sellPad = { r = 90, g = 190, b = 120 },
	},
	lighting = {
		clockTime = 14,
		brightness = 2.4,
		ambient = { r = 92, g = 96, b = 110 },
		outdoorAmbient = { r = 120, g = 124, b = 138 },
		exposure = 0.2,
		atmosphere = {
			density = 0.28,
			offset = 0.12,
			color = { r = 198, g = 214, b = 236 },
			decay = { r = 150, g = 170, b = 205 },
			glare = 0.1,
			haze = 0.6,
		},
		bloom = { intensity = 0.3, size = 22, threshold = 1.0 },
		colorCorrection = { saturation = 0.12, contrast = 0.06, brightness = 0 },
		sunRays = { intensity = 0.08, spread = 0.6 },
	},
	scenery = {
		trees = {
			{ x = -43.5, z = 43.5 },
			{ x = 43.5, z = 43.5 },
			{ x = 43.5, z = -9 },
			{ x = -43.5, z = 3 },
		},
		rocks = {
			{ x = -18, z = 36, size = 3.6 },
			{ x = 18, z = -7.5, size = 2.7 },
			{ x = 36, z = 33, size = 3.3 },
			{ x = -12, z = -21, size = 2.4 },
		},
		fencePostSpacing = 12,
	},
}
