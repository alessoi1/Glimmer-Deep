--!strict
-- Server entry point. Wires config into the pure logic modules and fails
-- loudly (log) when the config is broken. Only checkable in Roblox Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local DigRoll = require(Shared:WaitForChild("DigRoll"))
local Config = Shared:WaitForChild("Config")
local Dig = require(Config:WaitForChild("Dig"))

local digConfig: DigRoll.Config = {
	rareFindChance = Dig.rareFindChance,
	mutationChance = Dig.mutationChance,
	maxLuck = Dig.maxLuck,
	maxRareFindBonus = Dig.maxRareFindBonus,
	rarities = require(Config:WaitForChild("Rarities")),
	mutations = require(Config:WaitForChild("Mutations")),
	layers = require(Config:WaitForChild("Layers")),
}

local log = Log.new("Main")

local ok, reason = DigRoll.validateConfig(digConfig)
if not ok then
	log.error("dig config is invalid", { reason = reason })
else
	log.info("dig config is valid", { layers = #digConfig.layers, rarities = #digConfig.rarities })
end
