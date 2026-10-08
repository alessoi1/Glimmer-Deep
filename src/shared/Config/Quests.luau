--!strict
-- Daily quests and the login chain. Placeholder starting values, to be balanced.
-- pool: every quest has an id, the event it counts (see Quests.record), the
--   target amount and the reward in coins. Two quests of the same event would
--   be counted together, so every event appears once.
-- perDay: quests per day, picked from the pool by day and player.
-- allDoneBonus: extra coins once all quests of the day are claimed.
-- login.rewards: coins for day 1 to 7 of the chain (the chain length is the
--   number of rewards). A missed day sets the chain back by one day, not to zero.

return {
	perDay = 3,
	allDoneBonus = 500,
	pool = {
		{ id = "fill_backpack", event = "backpackFilled", target = 3, reward = 300 },
		{ id = "find_mutation", event = "mutation", target = 1, reward = 500 },
		{ id = "display_find", event = "displayed", target = 1, reward = 300 },
		{ id = "dig_blocks", event = "dig", target = 150, reward = 200 },
		{ id = "sell_trips", event = "sold", target = 3, reward = 150 },
		{ id = "find_rare", event = "rare", target = 3, reward = 300 },
		{ id = "buy_upgrade", event = "upgraded", target = 1, reward = 200 },
		{ id = "collect_visitors", event = "collected", target = 1, reward = 150 },
	},
	login = {
		rewards = { 100, 150, 200, 300, 400, 600, 1000 },
	},
}
