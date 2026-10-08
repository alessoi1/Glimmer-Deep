--!strict
-- The season ("Entdecker-Pass"). Placeholder starting values, to be balanced.
-- A season runs seasonWeeks weeks (counted from the Unix epoch, like events);
-- when a new one starts, progress and claimed rewards start again.
-- passKey: the game pass (Config/Shop) that unlocks the premium track. The
--   free track is fully usable without it.
-- xp: season points per game event (names from src/shared/Quests events).
-- levelXp: points needed for each level, one entry per level.
-- free / premium: the reward of each level, same length as levelXp. A reward is
--   { kind = "coins", amount }, { kind = "egg", amount }, { kind = "booster",
--   id, amount } (amount runs of the booster) or { kind = "decor", id }. A
--   decoration the player already owns is paid out as its coin price instead.
-- Premium rewards are cosmetic or small boni; nothing here is needed to play.

return {
	seasonWeeks = 4,
	passKey = "season_pass",
	xp = { dig = 1, rare = 15, mutation = 30 },
	levelXp = { 500, 600, 700, 800, 900, 1000, 1100, 1200, 1300, 1500 },
	free = {
		{ kind = "coins", amount = 300 },
		{ kind = "booster", id = "tempo_booster", amount = 1 },
		{ kind = "coins", amount = 600 },
		{ kind = "egg", amount = 1 },
		{ kind = "coins", amount = 1000 },
		{ kind = "booster", id = "luck_booster", amount = 1 },
		{ kind = "coins", amount = 1500 },
		{ kind = "egg", amount = 1 },
		{ kind = "coins", amount = 2500 },
		{ kind = "egg", amount = 2 },
	},
	premium = {
		{ kind = "decor", id = "potted_plant" },
		{ kind = "coins", amount = 1000 },
		{ kind = "egg", amount = 1 },
		{ kind = "decor", id = "lantern" },
		{ kind = "booster", id = "luck_booster", amount = 2 },
		{ kind = "coins", amount = 3000 },
		{ kind = "decor", id = "banner" },
		{ kind = "egg", amount = 2 },
		{ kind = "coins", amount = 5000 },
		{ kind = "decor", id = "statue" },
	},
}
