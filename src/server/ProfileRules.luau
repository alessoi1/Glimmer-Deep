--!strict
-- Assembles the profile rules from Config. Used by Main (startup check) and the
-- DataService so both always check against the same rules.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Migrations = require(script.Parent:WaitForChild("Migrations"))
local ProfileData = require(script.Parent:WaitForChild("ProfileData"))
local ProfileRulesLogic = require(script.Parent:WaitForChild("ProfileRulesLogic"))

local ProfileRules = {}

function ProfileRules.build(): ProfileData.Rules
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Config = Shared:WaitForChild("Config")
	local profileConfig = require(Config:WaitForChild("Profile"))
	return ProfileRulesLogic.build({
		migrations = Migrations,
		layers = require(Config:WaitForChild("Layers")),
		levelCounts = {
			shovel = #require(Config:WaitForChild("Shovel")).levels,
			backpack = #require(Config:WaitForChild("Backpack")).levels,
		},
		startCoins = profileConfig.startCoins,
		startDepth = profileConfig.startDepth,
		onboardingMaxStep = require(Shared:WaitForChild("Onboarding")).maxStep,
	})
end

return ProfileRules
