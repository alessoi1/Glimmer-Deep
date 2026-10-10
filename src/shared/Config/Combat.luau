--!strict
-- Overworld combat (concept: "Oberwelt und Kampf"). Starting values, to be
-- balanced. Strength is life times damage (see Config/Equipment): a complete
-- copper set is about 1,800, iron 3,200, silver 5,700, gold 9,800, crystal 16,100.

return {
	-- Zones by strength. A player may enter a zone from its minStrength up to
	-- maxStrength plus entryMargin (so a player who just grew out of a zone is
	-- not locked out at once, but is clearly over it later on).
	zones = {
		{ id = "foothills", minStrength = 0, maxStrength = 4000, bounty = 50 },
		{ id = "highlands", minStrength = 4000, maxStrength = 10500, bounty = 150 },
		{ id = "peaks", minStrength = 10500, maxStrength = 1e9, bounty = 450 },
	},
	entryMargin = 0.1,

	attackCooldown = 0.6, -- seconds between two hits of one player
	reachStuds = 8, -- melee reach, measured on the server
	respawnSeconds = 5,
	spawnProtectionSeconds = 4,

	-- Bounty (coins created by the system, nothing is taken from the loser).
	bountyVictimLockSeconds = 600, -- one reward per defeated player per 10 minutes
	bountyDailyCap = 1500, -- coins per day and player
	bountyMinStrengthRatio = 0.5, -- no reward if the loser is weaker than this share of the winner
	secondsPerDay = 86400,

	-- Portal: needs a weapon and at least this many armor pieces worn.
	portalMinArmorPieces = 1,
}
