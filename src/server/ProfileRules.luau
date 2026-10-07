--!strict
-- Assembles the profile rules from Config. Used by Main (startup check) and the
-- DataService so both always check against the same rules.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Migrations = require(script.Parent:WaitForChild("Migrations"))
local ProfileData = require(script.Parent:WaitForChild("ProfileData"))

local ProfileRules = {}

function ProfileRules.build(): ProfileData.Rules
	local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
	local layers = require(Config:WaitForChild("Layers"))
	local shovelConfig = require(Config:WaitForChild("Shovel"))
	local backpackConfig = require(Config:WaitForChild("Backpack"))
	local profileConfig = require(Config:WaitForChild("Profile"))

	local layerIds = {}
	for _, layer in layers do
		table.insert(layerIds, layer.id)
	end

	return {
		version = ProfileData.currentVersion(Migrations),
		startCoins = profileConfig.startCoins,
		startDepth = profileConfig.startDepth,
		levelCounts = { shovel = #shovelConfig.levels, backpack = #backpackConfig.levels },
		layerIds = layerIds,
	}
end

return ProfileRules
