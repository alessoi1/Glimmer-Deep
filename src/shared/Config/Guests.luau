--!strict
-- Guest values (friends dig together on one plot). Placeholder starting values,
-- to be balanced.
-- maxGuests: how many guests one plot hosts at the same time (concept: 4).
-- hostCoinsPerBlock: coins the host gets for every block a guest digs. The
--   guest keeps all of the ore (own backpack, own depth).
-- hostDailyCap: most coins a host can get from guests per day (UTC), so a
--   second account cannot farm coins. Kept in server memory only.
-- friendsOnly: only friends of the host can join.
-- promptDistance: studs within which the guest sign is shown.
-- joinDistance: studs within which a player can join at the sign.
-- joinCooldown: minimum seconds between two join or leave actions per player.

return {
	maxGuests = 4,
	hostCoinsPerBlock = 2,
	hostDailyCap = 3000,
	friendsOnly = true,
	promptDistance = 12,
	joinDistance = 24,
	joinCooldown = 1.5,
}
