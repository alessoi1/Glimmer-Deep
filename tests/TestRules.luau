--!strict
-- Profile rules for specs: the shipped config, assembled like the server does.

local BackpackConfig = require("../src/shared/Config/Backpack")
local DiggerConfig = require("../src/shared/Config/Digger")
local Layers = require("../src/shared/Config/Layers")
local MuseumConfig = require("../src/shared/Config/Museum")
local Onboarding = require("../src/shared/Onboarding")
local Migrations = require("../src/server/Migrations")
local ProfileConfig = require("../src/shared/Config/Profile")
local ProfileData = require("../src/server/ProfileData")
local ProfileRulesLogic = require("../src/server/ProfileRulesLogic")
local ShovelConfig = require("../src/shared/Config/Shovel")

local rules: ProfileData.Rules = ProfileRulesLogic.build({
	migrations = Migrations,
	layers = Layers,
	levelCounts = {
		shovel = #ShovelConfig.levels,
		backpack = #BackpackConfig.levels,
		digger = #DiggerConfig.levels,
	},
	startCoins = ProfileConfig.startCoins,
	startDepth = ProfileConfig.startDepth,
	onboardingMaxStep = Onboarding.maxStep,
	museumSlotsByHouseLevel = MuseumConfig.slotsByHouseLevel,
})

return rules
