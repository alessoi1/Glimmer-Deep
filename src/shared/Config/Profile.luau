--!strict
-- Starting values of a new player profile and where profiles are stored.

return {
	startCoins = 0,
	startDepth = 0,
	-- DataStore name. Never rename it after launch: players would lose their data.
	-- A breaking format change gets a migration, not a new name.
	storeName = "PlayerProfiles_v1",
}
