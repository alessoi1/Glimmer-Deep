--!strict
-- Server entry point. Wires config into the pure logic modules and fails
-- loudly (warn) when the config is broken. Only checkable in Roblox Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
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

local ok, reason = DigRoll.validateConfig(digConfig)
if not ok then
	warn("Dig config is invalid: " .. tostring(reason))
end
