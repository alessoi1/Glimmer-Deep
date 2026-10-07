--!strict
-- Shared config for specs: the shipped config, assembled like the server does.

local DigRoll = require("../src/shared/DigRoll")
local Dig = require("../src/shared/Config/Dig")
local Layers = require("../src/shared/Config/Layers")
local Mutations = require("../src/shared/Config/Mutations")
local Rarities = require("../src/shared/Config/Rarities")

local config: DigRoll.Config = {
	rareFindChance = Dig.rareFindChance,
	mutationChance = Dig.mutationChance,
	maxLuck = Dig.maxLuck,
	maxRareFindBonus = Dig.maxRareFindBonus,
	rarities = Rarities,
	mutations = Mutations,
	layers = Layers,
}

return config
