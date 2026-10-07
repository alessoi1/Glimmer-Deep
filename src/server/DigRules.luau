--!strict
-- Assembles the dig roll config from Config. Used by Main (startup check) and
-- the DigService so both always use the same rules.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DigRoll = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DigRoll"))

local DigRules = {}

function DigRules.build(): DigRoll.Config
	local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
	local Dig = require(Config:WaitForChild("Dig"))
	return {
		rareFindChance = Dig.rareFindChance,
		mutationChance = Dig.mutationChance,
		maxLuck = Dig.maxLuck,
		maxRareFindBonus = Dig.maxRareFindBonus,
		rarities = require(Config:WaitForChild("Rarities")),
		mutations = require(Config:WaitForChild("Mutations")),
		layers = require(Config:WaitForChild("Layers")),
	}
end

return DigRules
