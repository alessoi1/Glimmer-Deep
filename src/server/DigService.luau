--!strict
-- Handles the "dig" intention of the client. The client sends no data; the
-- server checks profile, plot, distance, cooldown and backpack, rolls the
-- block and changes the profile. Only checkable in Roblox Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local DigAction = require(Shared:WaitForChild("DigAction"))
local Config = Shared:WaitForChild("Config")
local DigConfig = require(Config:WaitForChild("Dig"))
local BackpackConfig = require(Config:WaitForChild("Backpack"))
local ShovelConfig = require(Config:WaitForChild("Shovel"))
local Rarities = require(Config:WaitForChild("Rarities"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local DigRules = require(script.Parent:WaitForChild("DigRules"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local RejectLimiter = require(script.Parent:WaitForChild("RejectLimiter"))

local log = Log.new("Dig")

local DigService = {}

local digRules = DigRules.build()
local random = Random.new()
local lastDigAt: { [Player]: number } = {}
local rejects: RejectLimiter.Limiter
local rarityIndex: { [string]: number } = {}
local logFromIndex = math.huge
local digResult: RemoteEvent
local started = false

local function warnRejected(player: Player, reason: string)
	rejects.reject(player.UserId, Remotes.names.dig, reason)
end

local function snapshot(profile: DataService.Profile): DigAction.State
	return DigAction.snapshot({
		profile = profile,
		digConfig = digRules,
		shovelLevels = ShovelConfig.levels,
		backpackLevels = BackpackConfig.levels,
	})
end

local function handleDig(player: Player, ...: any)
	if select("#", ...) > 0 then
		warnRejected(player, "unexpected_arguments")
		return
	end

	local profile = DataService.getData(player)
	if profile == nil then
		warnRejected(player, "profile_not_loaded")
		return
	end

	local distance = PlotService.horizontalDistance(player, PlotService.getShaftPosition(player))
	if distance == nil then
		warnRejected(player, "no_plot_or_character")
		return
	end
	if distance > DigConfig.digRange then
		warnRejected(player, "too_far")
		digResult:FireClient(player, { ok = false, reason = "too_far", state = snapshot(profile) })
		return
	end

	local now = os.clock()
	local result = DigAction.perform({
		profile = profile,
		digConfig = digRules,
		shovelLevels = ShovelConfig.levels,
		cooldownTolerance = ShovelConfig.cooldownTolerance,
		backpackLevels = BackpackConfig.levels,
		metersPerBlock = DigConfig.metersPerBlock,
		lastDigAt = lastDigAt[player],
		now = now,
		rng = function()
			return random:NextNumber()
		end,
	})

	if result.reason == "cooldown" then
		log.debug("dig inside cooldown", { userId = player.UserId })
		return
	end
	if not result.ok then
		log.debug("dig rejected", { userId = player.UserId, reason = result.reason })
		digResult:FireClient(player, { ok = false, reason = result.reason, state = snapshot(profile) })
		return
	end

	lastDigAt[player] = now
	local block = result.block
	if block == nil then
		log.error("dig succeeded without a block", { userId = player.UserId })
		return
	end
	log.debug("block dug", { userId = player.UserId, kind = block.kind, depth = result.depth, used = result.used })
	if block.kind == "rare" and block.rarityId ~= nil and (rarityIndex[block.rarityId] or 0) >= logFromIndex then
		log.info("rare find", {
			userId = player.UserId,
			findId = block.findId,
			rarityId = block.rarityId,
			mutationId = block.mutationId,
			value = block.value,
			depth = result.depth,
		})
	end
	digResult:FireClient(player, { ok = true, block = block, state = snapshot(profile) })
end

-- Current state of a loaded player for display, or nil while the profile loads.
function DigService.getState(player: Player): DigAction.State?
	local profile = DataService.getData(player)
	if profile == nil then
		return nil
	end
	return snapshot(profile)
end

function DigService.start()
	if started then
		log.warn("start called twice")
		return
	end
	started = true
	rejects = RejectLimiter.new(log, DigConfig.warnInterval, os.clock)

	for index, rarity in Rarities do
		rarityIndex[rarity.id] = index
	end
	logFromIndex = rarityIndex[DigConfig.logFromRarity] or math.huge
	if logFromIndex == math.huge then
		log.error("unknown logFromRarity in Config/Dig", { rarityId = DigConfig.logFromRarity })
	end

	digResult = Remotes.event(Remotes.names.digResult)
	Remotes.event(Remotes.names.dig).OnServerEvent:Connect(handleDig)
	Remotes.func(Remotes.names.getDigState).OnServerInvoke = function(player: Player, ...: any)
		if select("#", ...) > 0 then
			return nil
		end
		local profile = DataService.getData(player)
		if profile == nil then
			return nil
		end
		return snapshot(profile)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		lastDigAt[player] = nil
		rejects.forget(player.UserId)
	end)

	log.info("started", { metersPerBlock = DigConfig.metersPerBlock, digRange = DigConfig.digRange })
end

return DigService
