--!strict
-- Client entry point. Starts the interface; the client holds no game values.

local DigUI = require(script.Parent:WaitForChild("DigUI"))
local SellUI = require(script.Parent:WaitForChild("SellUI"))

DigUI.start()
SellUI.start()
