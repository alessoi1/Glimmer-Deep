--!strict
-- Rebirth "Neue Bohrung" values. Placeholder starting values, to be balanced.
-- requiredDepth: meters the hole must reach before a rebirth is possible. It is
--   the end of the deepest layer shipped at launch (a spec checks this).
-- points: prestige points a rebirth gives: base + perRebirth for every rebirth
--   done before. Points are spent on permanent bonuses.
-- upgrades: permanent bonuses. Each level gives perLevel (a Modifiers part, see
--   src/shared/Modifiers); costs[level] is the price in prestige points for that
--   level. A rebirth never takes them away.
-- order: the order of the bonuses in the panel.
-- actionCooldown: minimum seconds between two rebirth actions per player.
-- promptDistance / useDistance: studs of the rebirth sign prompt and panel.

return {
	requiredDepth = 300,
	points = { base = 5, perRebirth = 2 },
	actionCooldown = 1,
	promptDistance = 12,
	useDistance = 24,
	order = { "coins", "tempo", "luck", "offline" },
	upgrades = {
		coins = { costs = { 1, 2, 3, 5, 8 }, perLevel = { coinBonus = 0.1 } },
		tempo = { costs = { 1, 2, 3, 5, 8 }, perLevel = { tempoBonus = 0.05 } },
		luck = { costs = { 1, 2, 3, 5, 8 }, perLevel = { luckBonus = 0.05 } },
		offline = { costs = { 1, 2, 3, 5, 8 }, perLevel = { offlineBonus = 0.1 } },
	},
}
