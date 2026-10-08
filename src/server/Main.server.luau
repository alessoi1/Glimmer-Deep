--!strict
-- Server entry point. Wires config into the pure logic modules and fails
-- loudly (log) when the config is broken. Only checkable in Roblox Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local DigRules = require(script.Parent:WaitForChild("DigRules"))
local DigService = require(script.Parent:WaitForChild("DigService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))
local OfflineService = require(script.Parent:WaitForChild("OfflineService"))
local MuseumService = require(script.Parent:WaitForChild("MuseumService"))
local MovementService = require(script.Parent:WaitForChild("MovementService"))
local UpgradeRules = require(script.Parent:WaitForChild("UpgradeRules"))
local UpgradeService = require(script.Parent:WaitForChild("UpgradeService"))
local SellService = require(script.Parent:WaitForChild("SellService"))
local ProfileData = require(script.Parent:WaitForChild("ProfileData"))
local ProfileRules = require(script.Parent:WaitForChild("ProfileRules"))
local Backpack = require(Shared:WaitForChild("Backpack"))
local DigRoll = require(Shared:WaitForChild("DigRoll"))
local Selling = require(Shared:WaitForChild("Selling"))
local Shovel = require(Shared:WaitForChild("Shovel"))
local Upgrades = require(Shared:WaitForChild("Upgrades"))
local Config = Shared:WaitForChild("Config")

local digConfig = DigRules.build()

local log = Log.new("Main")

local function check(name: string, ok: boolean, reason: string?)
	if ok then
		log.info(name .. " is valid")
	else
		log.error(name .. " is invalid", { reason = reason })
	end
end

check("dig config", DigRoll.validateConfig(digConfig))
check("ore prices", Selling.validateOreValues(digConfig.layers, require(Config:WaitForChild("Ores"))))
local shovelConfig = require(Config:WaitForChild("Shovel"))
local backpackConfig = require(Config:WaitForChild("Backpack"))
check("backpack levels", Backpack.validateLevels(backpackConfig.levels))
check("shovel levels", Shovel.validateConfig(shovelConfig))
check("upgrade tracks", Upgrades.validateTracks(UpgradeRules.build()))

local profileRules = ProfileRules.build()
local random = Random.new()
local testProfile = ProfileData.new(profileRules, function()
	return random:NextNumber()
end, os.time())
check("new profile", ProfileData.validate(testProfile, profileRules))

DataService.start()
PlotService.start()
DigService.start()
SellService.start()
MuseumService.start()
OfflineService.start()
UpgradeService.start()
MovementService.start()
QuestService.start(DigService.getState)
