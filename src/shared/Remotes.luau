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
		getQuests = "GetQuests", -- client -> server function: quest view, nil while loading
		questClaim = "QuestClaim", -- client -> server event: (kind "quest" | "bonus" | "login", quest id)
		questResult = "QuestResult", -- server -> client event: outcome, new view and state
		questDone = "QuestDone", -- server -> client event: ids of quests that were just completed
		getShop = "GetShop", -- client -> server function: shop view, nil while loading
		shopOffer = "ShopOffer", -- client -> server event: (pass key) look at an offer
		shopResult = "ShopResult", -- server -> client event: outcome, new view and state
		getBoosters = "GetBoosters", -- client -> server function: booster snapshot, nil while loading
		boosterOffer = "BoosterOffer", -- client -> server event: (booster id) look at an offer
		boosterFree = "BoosterFree", -- client -> server event: claim the free run (no arguments)
		boosterResult = "BoosterResult", -- server -> client event: outcome and new snapshot
		getPets = "GetPets", -- client -> server function: pet snapshot, nil while loading
		petOffer = "PetOffer", -- client -> server event: look at the egg offer (no arguments)
		petOpen = "PetOpen", -- client -> server event: open an egg (no arguments)
		petEquip = "PetEquip", -- client -> server event: (pet instance id) toggle working
		petFree = "PetFree", -- client -> server event: claim the free egg (no arguments)
		petResult = "PetResult", -- server -> client event: outcome, new snapshot and hatch result
		houseOpen = "HouseOpen", -- server -> client event: open the house panel with this view
		getHouse = "GetHouse", -- client -> server function: house view, nil while loading
		houseUpgrade = "HouseUpgrade", -- client -> server event: buy the next house level (no arguments)
		houseBuy = "HouseBuy", -- client -> server event: (decoration id) buy it
		housePlace = "HousePlace", -- client -> server event: (decoration id, place number)
		houseRemove = "HouseRemove", -- client -> server event: (place number) take the decoration back
		houseResult = "HouseResult", -- server -> client event: outcome, new view and state
		quickTravel = "QuickTravel", -- client -> server event: (target "sell" | "shaft")
		getOfflineReport = "GetOfflineReport", -- client -> server function: { ready, report?, maxSeconds? }, nil while loading
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
