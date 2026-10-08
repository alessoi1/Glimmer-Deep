--!strict
-- The small town around the plots: roads in the gaps between the plots and
-- around them, a grass belt, a low stone wall and an invisible wall that keeps
-- players inside. Starting values; nothing here changes how the game plays.
-- The road width is the plot gap (Config/Plot).
-- margin: studs of grass between the outer road and the boundary.
-- roadThickness: thickness of road and grass slabs (their top is the ground).
-- lowWall: the visible stone wall on the boundary (height, thickness).
-- invisibleWall: the wall behind it that nobody can climb (height, thickness).
-- dash: the yellow line in the middle of a road (length, gap between two dashes,
--   width). Dashes stay out of the crossings.
-- lampInset: how far a street lamp stands from the middle of a crossing, towards
--   its corner.
-- treeSpacing: distance between two trees in the grass belt.

return {
	margin = 60,
	roadThickness = 2,
	lowWall = { height = 4, thickness = 2 },
	invisibleWall = { height = 120, thickness = 6 },
	dash = { length = 6, gap = 8, width = 0.8 },
	lampInset = 3,
	treeSpacing = 40,
}
