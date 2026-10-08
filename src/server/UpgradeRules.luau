--!strict
-- Assembles the upgrade tracks from Config. Used by Main (startup check) and
-- the UpgradeService so both always use the same rules.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeAction = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeAction"))

local UpgradeRules = {}

function UpgradeRules.build(): UpgradeAction.Tracks
	local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
	local tracks: UpgradeAction.Tracks = {
		shovel = { levels = require(Config:WaitForChild("Shovel")).levels },
		backpack = { levels = require(Config:WaitForChild("Backpack")).levels },
		digger = { levels = require(Config:WaitForChild("Digger")).levels },
	}
	for upgradeId, track in require(Config:WaitForChild("Skills")).tracks do
		tracks[upgradeId] = track
	end
	return tracks
end

return UpgradeRules
