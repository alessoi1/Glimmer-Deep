--!strict
-- Handles the "sell" intention of the client. The client sends no data; the
-- server checks profile, plot, distance and cooldown, sells the backpack at the
-- config prices and pays the coins into the profile. Only checkable in Roblox
-- Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SellAction = require(Shared:WaitForChild("SellAction"))
local Config = Shared:WaitForChild("Config")
local DigConfig = require(Config:WaitForChild("Dig"))
local OreConfig = require(Config:WaitForChild("Ores"))
local SellConfig = require(Config:WaitForChild("Sell"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local DigService = require(script.Parent:WaitForChild("DigService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local RejectLimiter = require(script.Parent:WaitForChild("RejectLimiter"))

local log = Log.new("Sell")

local SellService = {}

local lastSellAt: { [Player]: number } = {}
local rejects: RejectLimiter.Limiter
local sellResult: RemoteEvent
local started = false

local function handleSell(player: Player, ...: any)
	if select("#", ...) > 0 then
		rejects.reject(player.UserId, Remotes.names.sell, "unexpected_arguments")
		return
	end

	local profile = DataService.getData(player)
	if profile == nil then
		rejects.reject(player.UserId, Remotes.names.sell, "profile_not_loaded")
		return
	end

	local distance = PlotService.horizontalDistance(player, PlotService.getSellPosition(player))
	if distance == nil then
		rejects.reject(player.UserId, Remotes.names.sell, "no_plot_or_character")
		return
	end

	local now = os.clock()
	local previous = lastSellAt[player]
	if previous ~= nil and now - previous < SellConfig.cooldown then
		rejects.reject(player.UserId, Remotes.names.sell, "cooldown")
		return
	end
	lastSellAt[player] = now

	local state = DigService.getState(player)
	if distance > SellConfig.range then
		rejects.reject(player.UserId, Remotes.names.sell, "too_far")
		sellResult:FireClient(player, { ok = false, reason = "too_far", state = state })
		return
	end

	local result = SellAction.perform(profile, OreConfig, nil)
	for oreId, count in result.unknownOres do
		log.warn("ore without price stays in the backpack", { userId = player.UserId, oreId = oreId, count = count })
	end
	if not result.ok then
		log.debug("sell rejected", { userId = player.UserId, reason = result.reason })
		sellResult:FireClient(player, { ok = false, reason = result.reason, state = state })
		return
	end

	log.info("backpack sold", {
		userId = player.UserId,
		coinsEarned = result.coinsEarned,
		oreCount = result.oreCount,
		findCount = result.findCount,
		coins = profile.coins,
		depth = profile.depth,
	})
	sellResult:FireClient(player, { ok = true, coinsEarned = result.coinsEarned, state = DigService.getState(player) })
end

function SellService.start()
	if started then
		log.warn("start called twice")
		return
	end
	started = true
	rejects = RejectLimiter.new(log, DigConfig.warnInterval, os.clock)

	sellResult = Remotes.event(Remotes.names.sellResult)
	Remotes.event(Remotes.names.sell).OnServerEvent:Connect(handleSell)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastSellAt[player] = nil
		rejects.forget(player.UserId)
	end)

	log.info("started", { range = SellConfig.range, cooldown = SellConfig.cooldown })
end

return SellService
