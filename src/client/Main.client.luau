--!strict
-- Client entry point. Starts the interface; the client holds no game values.

local DigUI = require(script.Parent:WaitForChild("DigUI"))
local SellUI = require(script.Parent:WaitForChild("SellUI"))
local QuestUI = require(script.Parent:WaitForChild("QuestUI"))
local OfflineUI = require(script.Parent:WaitForChild("OfflineUI"))
local MuseumUI = require(script.Parent:WaitForChild("MuseumUI"))
local UpgradeUI = require(script.Parent:WaitForChild("UpgradeUI"))

DigUI.start()
SellUI.start()
UpgradeUI.start()
MuseumUI.start()
OfflineUI.start()
QuestUI.start()
