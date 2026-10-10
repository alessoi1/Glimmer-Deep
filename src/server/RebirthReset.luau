--!strict
-- The profile reset of a rebirth, as pure logic (no Roblox services). A fresh
-- profile is created with the same rules as a new player; from it the profile
-- takes coins, tools, depth, the hole shape and the cave. Museum, house, pets, boosters,
-- passes, quests, login chain, onboarding, prestige and all rare finds stay.
-- Ore is lost, but rare finds in the backpack and depot are kept: they cannot
-- be earned again like ore.

local ProfileData = require("./ProfileData")

local RebirthReset = {}

-- Resets the profile in place (the live profile table is owned by ProfileStore,
-- so it must not be replaced). Returns the depth the hole had before the reset.
function RebirthReset.apply(
	profile: ProfileData.Profile,
	rules: ProfileData.Rules,
	rng: () -> number,
	now: number
): number
	local previousDepth = profile.depth
	local fresh = ProfileData.new(rules, rng, now)

	profile.coins = fresh.coins
	profile.depth = fresh.depth
	profile.upgradeLevels = fresh.upgradeLevels
	profile.layerSeeds = fresh.layerSeeds
	profile.cave = fresh.cave
	profile.backpack.ores = {}
	profile.depot.ores = {}
	profile.digger.leftAt = nil
	return previousDepth
end

return RebirthReset
