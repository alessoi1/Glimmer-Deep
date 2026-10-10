--!strict
-- Run with: lune run tests/run
local process = require("@lune/process")

local Framework = require("./Framework")

-- Every spec file registers its tests via Framework.test on require.
local specs: { () -> () } = {
	function()
		require("./specs/DigRoll.spec")
	end,
	function()
		require("./specs/Log.spec")
	end,
	function()
		require("./specs/Backpack.spec")
	end,
	function()
		require("./specs/Selling.spec")
	end,
	function()
		require("./specs/Shovel.spec")
	end,
	function()
		require("./specs/Upgrades.spec")
	end,
	function()
		require("./specs/ProfileData.spec")
	end,
	function()
		require("./specs/DataLogic.spec")
	end,
	function()
		require("./specs/PlotLogic.spec")
	end,
	function()
		require("./specs/DigAction.spec")
	end,
	function()
		require("./specs/DigMessages.spec")
	end,
	function()
		require("./specs/SellAction.spec")
	end,
	function()
		require("./specs/SellMessages.spec")
	end,
	function()
		require("./specs/RejectLimiter.spec")
	end,
	function()
		require("./specs/UpgradeAction.spec")
	end,
	function()
		require("./specs/UpgradeMessages.spec")
	end,
	function()
		require("./specs/Onboarding.spec")
	end,
	function()
		require("./specs/Modifiers.spec")
	end,
	function()
		require("./specs/Calendar.spec")
	end,
	function()
		require("./specs/MuseumLogic.spec")
	end,
	function()
		require("./specs/MuseumMessages.spec")
	end,
	function()
		require("./specs/OfflineLogic.spec")
	end,
	function()
		require("./specs/OfflineMessages.spec")
	end,
	function()
		require("./specs/UpgradeEffects.spec")
	end,
	function()
		require("./specs/Quests.spec")
	end,
	function()
		require("./specs/LoginChain.spec")
	end,
	function()
		require("./specs/QuestMessages.spec")
	end,
	function()
		require("./specs/ShopLogic.spec")
	end,
	function()
		require("./specs/ShopMessages.spec")
	end,
	function()
		require("./specs/Boosters.spec")
	end,
	function()
		require("./specs/BoosterMessages.spec")
	end,
	function()
		require("./specs/Pets.spec")
	end,
	function()
		require("./specs/PetMessages.spec")
	end,
	function()
		require("./specs/House.spec")
	end,
	function()
		require("./specs/HouseMessages.spec")
	end,
	function()
		require("./specs/Guests.spec")
	end,
	function()
		require("./specs/GuestMessages.spec")
	end,
	function()
		require("./specs/Prestige.spec")
	end,
	function()
		require("./specs/RebirthReset.spec")
	end,
	function()
		require("./specs/RebirthMessages.spec")
	end,
	function()
		require("./specs/Events.spec")
	end,
	function()
		require("./specs/Season.spec")
	end,
	function()
		require("./specs/ModelSpecs.spec")
	end,
	function()
		require("./specs/TownLogic.spec")
	end,
	function()
		require("./specs/SeasonMessages.spec")
	end,
	function()
		require("./specs/CaveCodec.spec")
	end,
	function()
		require("./specs/Cave.spec")
	end,
	function()
		require("./specs/CaveAction.spec")
	end,
}

local passed = 0
local failed = 0

for _, loadSpec in specs do
	loadSpec()
	for _, case in Framework.takeCases() do
		local ok, err = pcall(case.run)
		if ok then
			passed += 1
			print("  ok   " .. case.name)
		else
			failed += 1
			print("  FAIL " .. case.name)
			print("       " .. tostring(err))
		end
	end
end

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	process.exit(1)
end
