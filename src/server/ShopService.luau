--!strict
-- The shop for game passes: asks Roblox who owns a pass, keeps the verified
-- result in the profile, registers the pass bonuses and handles the quick trip
-- perk. Purchases happen only through MarketplaceService; the client only says
-- which offer it wants to look at. Only checkable in Roblox Studio.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local Onboarding = require(Shared:WaitForChild("Onboarding"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ShopLogic = require(Shared:WaitForChild("ShopLogic"))
local Config = Shared:WaitForChild("Config")
local DigConfig = require(Config:WaitForChild("Dig"))
local PlotConfig = require(Config:WaitForChild("Plot"))
local ShopConfig = require(Config:WaitForChild("Shop"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local DigService = require(script.Parent:WaitForChild("DigService"))
local ModifierService = require(script.Parent:WaitForChild("ModifierService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local ProfileData = require(script.Parent:WaitForChild("ProfileData"))
local RejectLimiter = require(script.Parent:WaitForChild("RejectLimiter"))

local log = Log.new("Shop")

local ShopService = {}

local PERK_QUICK_TRAVEL = "quickTravel"
local OFFER_COOLDOWN = 1 -- seconds between two offers per player
local TRAVEL_LIFT = 4 -- studs above the target so the character lands on the ground
local TRAVEL_MARGIN = 4 -- studs from the shaft edge for the shaft target

local config: ShopLogic.Config = ShopConfig
local lastOfferAt: { [Player]: number } = {}
local lastTravelAt: { [Player]: number } = {}
local rejects: RejectLimiter.Limiter
local shopResult: RemoteEvent
local started = false

local function viewFor(profile: ProfileData.Profile): ShopLogic.View
	return ShopLogic.view(profile.passes, config, Onboarding.isDone(profile.onboarding))
end

local function reply(player: Player, profile: ProfileData.Profile, ok: boolean, reason: string?)
	shopResult:FireClient(player, {
		ok = ok,
		reason = reason,
		snapshot = viewFor(profile),
		state = DigService.getState(player),
	})
end

-- Asks Roblox whether the player owns the pass. Returns nil when the call failed.
local function ownsPass(player: Player, gamePassId: number): boolean?
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassId)
	end)
	if not ok then
		log.warn(
			"pass ownership check failed",
			{ userId = player.UserId, gamePassId = gamePassId, error = tostring(result) }
		)
		return nil
	end
	return result == true
end

-- Brings the stored pass flags in line with what Roblox says. Returns true when
-- a flag changed.
local function verifyPass(player: Player, profile: ProfileData.Profile, key: string): boolean
	local def = config.passes[key]
	if def == nil or def.gamePassId <= 0 then
		return false
	end
	local owns = ownsPass(player, def.gamePassId)
	if owns == nil then
		return false
	end
	local had = profile.passes[key] == true
	if owns and not had then
		profile.passes[key] = true
		log.info("pass owned", { userId = player.UserId, pass = key })
		return true
	elseif not owns and had then
		profile.passes[key] = nil
		log.info("pass no longer owned", { userId = player.UserId, pass = key })
		return true
	end
	return false
end

local function verifyAll(player: Player)
	local profile = DataService.getData(player)
	if profile == nil then
		return
	end
	local changed = false
	for _, key in config.order do
		if verifyPass(player, profile, key) then
			changed = true
		end
	end
	if changed and player.Parent == Players then
		reply(player, profile, true, nil)
	end
end

local function handlePurchaseFinished(player: Player, gamePassId: number, wasPurchased: boolean)
	local key = ShopLogic.keyOfGamePass(config, gamePassId)
	if key == nil then
		return
	end
	log.info("pass purchase finished", { userId = player.UserId, pass = key, purchased = wasPurchased })
	if not wasPurchased then
		return
	end
	local profile = DataService.getData(player)
	if profile == nil then
		return
	end
	-- Trust Roblox, not the event: check the ownership again.
	if verifyPass(player, profile, key) then
		reply(player, profile, true, nil)
	end
end

local function handleOffer(player: Player, passKey: any, ...: any)
	local remote = Remotes.names.shopOffer
	if select("#", ...) > 0 or type(passKey) ~= "string" then
		rejects.reject(player.UserId, remote, "bad_arguments")
		return
	end
	local profile = DataService.getData(player)
	if profile == nil then
		rejects.reject(player.UserId, remote, "profile_not_loaded")
		return
	end
	local now = os.clock()
	local previous = lastOfferAt[player]
	if previous ~= nil and now - previous < OFFER_COOLDOWN then
		rejects.reject(player.UserId, remote, "cooldown")
		return
	end
	lastOfferAt[player] = now

	local def = config.passes[passKey]
	if def == nil then
		rejects.reject(player.UserId, remote, "unknown_pass")
		return
	end
	-- No offers during the first minutes of a new player.
	if not Onboarding.isDone(profile.onboarding) then
		rejects.reject(player.UserId, remote, "not_available")
		reply(player, profile, false, "not_available")
		return
	end
	if def.gamePassId <= 0 or profile.passes[passKey] == true then
		reply(player, profile, false, "not_available")
		return
	end
	log.info("pass offer shown", { userId = player.UserId, pass = passKey })
	MarketplaceService:PromptGamePassPurchase(player, def.gamePassId)
end

local function handleTravel(player: Player, target: any, ...: any)
	local remote = Remotes.names.quickTravel
	if select("#", ...) > 0 or (target ~= "sell" and target ~= "shaft") then
		rejects.reject(player.UserId, remote, "bad_arguments")
		return
	end
	local profile = DataService.getData(player)
	if profile == nil then
		rejects.reject(player.UserId, remote, "profile_not_loaded")
		return
	end
	if not ShopLogic.hasPerk(profile.passes, PERK_QUICK_TRAVEL, config) then
		rejects.reject(player.UserId, remote, "not_owned")
		reply(player, profile, false, "not_available")
		return
	end
	local now = os.clock()
	local previous = lastTravelAt[player]
	if previous ~= nil and now - previous < config.quickTravelCooldown then
		reply(player, profile, false, "cooldown")
		return
	end

	local destination: Vector3? = nil
	if target == "sell" then
		destination = PlotService.getSellPosition(player)
	else
		local shaft = PlotService.getShaftPosition(player)
		if shaft ~= nil then
			destination = shaft + Vector3.new(0, 0, PlotConfig.shaftSize / 2 + TRAVEL_MARGIN)
		end
	end
	local character = player.Character
	if destination == nil or character == nil then
		rejects.reject(player.UserId, remote, "no_plot_or_character")
		return
	end
	lastTravelAt[player] = now
	character:PivotTo(CFrame.new(destination + Vector3.new(0, TRAVEL_LIFT, 0)))
	log.debug("quick travel", { userId = player.UserId, target = target })
	reply(player, profile, true, nil)
end

function ShopService.start()
	if started then
		log.warn("start called twice")
		return
	end
	started = true

	local ok, reason = ShopLogic.validateConfig(config)
	if not ok then
		log.error("shop config is invalid", { reason = reason })
	end
	rejects = RejectLimiter.new(log, DigConfig.warnInterval, os.clock)

	for key in config.passes do
		ModifierService.register("pass_" .. key, function(profile: ProfileData.Profile)
			return ShopLogic.effectOf(profile.passes, key, config)
		end)
	end

	shopResult = Remotes.event(Remotes.names.shopResult)
	Remotes.event(Remotes.names.shopOffer).OnServerEvent:Connect(handleOffer)
	Remotes.event(Remotes.names.quickTravel).OnServerEvent:Connect(handleTravel)
	Remotes.func(Remotes.names.getShop).OnServerInvoke = function(player: Player, ...: any)
		if select("#", ...) > 0 then
			return nil
		end
		local profile = DataService.getData(player)
		if profile == nil then
			return nil
		end
		return viewFor(profile)
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(handlePurchaseFinished)
	DataService.onLoaded(function(player: Player, _profile: ProfileData.Profile)
		task.spawn(verifyAll, player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastOfferAt[player] = nil
		lastTravelAt[player] = nil
		rejects.forget(player.UserId)
	end)

	log.info("started", { passes = #config.order })
end

return ShopService
