--!strict
-- Pure assembly of the profile rules from already loaded config values. The
-- ProfileRules module reads the config in Roblox, the specs read it under Lune;
-- both call this function, so the rules can never differ between game and tests.

local ProfileData = require("./ProfileData")

export type Input = {
	migrations: { ProfileData.Migration },
	layers: { { id: string } },
	levelCounts: { [string]: number }, -- upgrade id -> number of levels
	startCoins: number,
	startDepth: number,
}

local ProfileRulesLogic = {}

function ProfileRulesLogic.build(input: Input): ProfileData.Rules
	local layerIds = {}
	for _, layer in input.layers do
		table.insert(layerIds, layer.id)
	end
	return {
		version = ProfileData.currentVersion(input.migrations),
		startCoins = input.startCoins,
		startDepth = input.startDepth,
		levelCounts = input.levelCounts,
		layerIds = layerIds,
	}
end

return ProfileRulesLogic
