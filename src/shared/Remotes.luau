--!strict
-- The remotes between client and server. The server creates them (once, at
-- start); the client waits for them. Names are defined only here.
-- Client -> server remotes carry intentions only, never prices or amounts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local Remotes = {
	names = {
		dig = "Dig", -- client -> server event: "I want to dig" (no arguments)
		digResult = "DigResult", -- server -> client event: outcome and new state
		getDigState = "GetDigState", -- client -> server function: current state, nil while loading
		sell = "Sell", -- client -> server event: "I want to sell my backpack" (no arguments)
		sellResult = "SellResult", -- server -> client event: outcome and new state
		buyUpgrade = "BuyUpgrade", -- client -> server event: one argument, the upgrade id (string)
		upgradeResult = "UpgradeResult", -- server -> client event: outcome, upgrades and new state
		getUpgrades = "GetUpgrades", -- client -> server function: upgrade entries, nil while loading
		museumOpen = "MuseumOpen", -- server -> client event: open the museum panel with this view
		museumDisplay = "MuseumDisplay", -- client -> server event: (find id, showcase number)
		museumRemove = "MuseumRemove", -- client -> server event: (showcase number)
		museumCollect = "MuseumCollect", -- client -> server event: collect the visitor income
		museumResult = "MuseumResult", -- server -> client event: outcome, message data and new view
		getMuseum = "GetMuseum", -- client -> server function: own museum view, nil while loading
	},
}

local function getFolder(): Instance
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing ~= nil then
			return existing
		end
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local function getRemote(name: string, className: string): Instance
	local folder = getFolder()
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing ~= nil then
			return existing
		end
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name)
end

function Remotes.event(name: string): RemoteEvent
	return getRemote(name, "RemoteEvent") :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	return getRemote(name, "RemoteFunction") :: RemoteFunction
end

return Remotes
