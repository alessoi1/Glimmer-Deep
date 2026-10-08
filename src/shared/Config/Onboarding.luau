--!strict
-- The first minutes of a new player. Starting values.
-- firstFindAfterBlocks: the dig that reaches this block count (counted over the
--   profile's lifetime) yields a guaranteed rare find. Must stay below the
--   starting backpack capacity (50) so it comes before the first full backpack.
-- firstFindMutation: mutation id of that find (the "golden" clip moment).

return {
	firstFindAfterBlocks = 30,
	firstFindMutation = "golden",
}
