--!strict
-- Backpack sizes. Each dug block (ore or rare find) takes one slot.
-- capacity: slots at this level. price: coins for reaching this level (level 1
-- is free). Placeholder starting values, to be balanced.

return {
	startCapacity = 50,
	levels = {
		{ capacity = 50, price = 0 },
		{ capacity = 100, price = 150 },
		{ capacity = 200, price = 600 },
		{ capacity = 400, price = 2500 },
		{ capacity = 800, price = 10000 },
	},
}
