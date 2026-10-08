--!strict
-- Selling at the sell stand of the own plot. Nobody presses a button: while a
-- player stands at their own sell stand the server sells the backpack and the
-- depot at the config prices and pays the coins into the profile. The client
-- sends nothing and only shows the result. Only checkable in Roblox Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Quests = require(Shared:WaitForChild("Quests"))
local SellAction = require(Shared:WaitForChild("SellAction"))
local Config = Shared:WaitForChild("Config")
local OreConfig = require(Config:WaitForChild("Ores"))
local SellConfig = require(Config:WaitForChild("Sell"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local DigService = require(script.Parent:WaitForChild("DigService"))
local ModifierService = require(script.Parent:WaitForChild("ModifierService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))

local log = Log.new("Sell")

local SellService = {}

local lastSellAt: { [Player]: number } = {}
local sellResult: RemoteEvent
local started = false

-- Sells for one player when they stand at their own sell stand. Does nothing
-- (and says nothing) when they are elsewhere, on cooldown or have nothing to sell.
local function sellIfAtStand(player: Player)
	local profile = DataService.getData(player)
	if profile == nil then
		return
	end
	local distance = PlotService.horizontalDistance(player, PlotService.getSellPosition(player))
	if distance == nil or distance > SellConfig.range then
		return
	end
	local now = os.clock()
	local previous = lastSellAt[player]
	if previous ~= nil and now - previous < SellConfig.cooldown then
		return
	end

	-- Bonuses and the sale pass apply to ore only, never to rare finds.
	local bonuses = ModifierService.get(profile)
	local result = SellAction.perform(profile, OreConfig, bonuses.coinMultiplier * bonuses.oreSaleFactor)
	for oreId, count in result.unknownOres do
		log.warn("ore without price stays in the backpack", { userId = player.UserId, oreId = oreId, count = count })
	end
	if not result.ok then
		-- Standing at the stand with nothing to sell is normal; no message, no cooldown.
		log.debug("nothing sold", { userId = player.UserId, reason = result.reason })
		return
	end
	lastSellAt[player] = now

	log.info("backpack sold", {
		userId = player.UserId,
		coinsEarned = result.coinsEarned,
		oreCount = result.oreCount,
		findCount = result.findCount,
		coins = profile.coins,
		depth = profile.depth,
	})
	QuestService.record(player, Quests.events.sold, 1)
	sellResult:FireClient(player, { ok = true, coinsEarned = result.coinsEarned, state = DigService.getState(player) })
end

function SellService.start()
	if started then
		log.warn("start called twice")
		return
	end
	started = true

	sellResult = Remotes.event(Remotes.names.sellResult)

	task.spawn(function()
		while true do
			task.wait(SellConfig.checkInterval)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(sellIfAtStand, player)
				if not ok then
					log.error("auto sell failed", { userId = player.UserId, error = tostring(err) })
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastSellAt[player] = nil
	end)

	log.info("started", { range = SellConfig.range, cooldown = SellConfig.cooldown })
end

return SellService
