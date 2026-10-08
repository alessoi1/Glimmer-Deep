--!strict
-- Boosters bought as Developer Products: registers their bonuses, opens the
-- purchase prompt, handles their receipts (the ReceiptService confirms them)
-- and hands restricted players a free run of the luck booster instead of the
-- paid one. Purchases happen only through MarketplaceService; the client only
-- says which offer it wants to look at. Only checkable in Roblox Studio.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosters = require(Shared:WaitForChild("Boosters"))
local DigRoll = require(Shared:WaitForChild("DigRoll"))
local Log = require(Shared:WaitForChild("Log"))
local Onboarding = require(Shared:WaitForChild("Onboarding"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Config = Shared:WaitForChild("Config")
local BoosterConfig = require(Config:WaitForChild("Boosters"))
local DigConfig = require(Config:WaitForChild("Dig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local DigRules = require(script.Parent:WaitForChild("DigRules"))
local ModifierService = require(script.Parent:WaitForChild("ModifierService"))
local PaidRandomPolicy = require(script.Parent:WaitForChild("PaidRandomPolicy"))
local ProfileData = require(script.Parent:WaitForChild("ProfileData"))
local ReceiptService = require(script.Parent:WaitForChild("ReceiptService"))
local RejectLimiter = require(script.Parent:WaitForChild("RejectLimiter"))

local log = Log.new("Boosters")

local BoosterService = {}

local ACTION_COOLDOWN = 1 -- seconds between two offers or claims per player

local config: Boosters.Config = BoosterConfig
local digRollConfig: DigRoll.Config
local lastActionAt: { [Player]: number } = {}
local rejects: RejectLimiter.Limiter
local boosterResult: RemoteEvent
local started = false

local function snapshotFor(player: Player, profile: ProfileData.Profile): Boosters.Snapshot
	local now = os.time()
	local view = Boosters.view(
		profile.boosters,
		config,
		now,
		Onboarding.isDone(profile.onboarding),
		PaidRandomPolicy.isRestricted(player)
	)
	local luckBoosterId = config.freeClaim.boosterId
	local luckBonus = config.boosters[luckBoosterId].effect.luckBonus or 0
	local currentLuck = ModifierService.get(profile).luck
	return {
		view = view,
		chances = Boosters.chanceRows(
			DigRoll.getRarityChances(digRollConfig, currentLuck),
			DigRoll.getRarityChances(digRollConfig, currentLuck + luckBonus)
		),
		mutationBase = DigRoll.getMutationChance(digRollConfig, currentLuck),
		mutationBoosted = DigRoll.getMutationChance(digRollConfig, currentLuck + luckBonus),
		luckBoosterId = luckBoosterId,
	}
end

local function reply(player: Player, profile: ProfileData.Profile, ok: boolean, reason: string?)
	boosterResult:FireClient(player, { ok = ok, reason = reason, snapshot = snapshotFor(player, profile) })
end

-- Throttles per player; returns false when the call came too soon.
local function underCooldown(player: Player): boolean
	local now = os.clock()
	local previous = lastActionAt[player]
	if previous ~= nil and now - previous < ACTION_COOLDOWN then
		return true
	end
	lastActionAt[player] = now
	return false
end

local function handleOffer(player: Player, boosterId: any, ...: any)
	local remote = Remotes.names.boosterOffer
	if select("#", ...) > 0 or type(boosterId) ~= "string" then
		rejects.reject(player.UserId, remote, "bad_arguments")
		return
	end
	local profile = DataService.getData(player)
	if profile == nil then
		rejects.reject(player.UserId, remote, "profile_not_loaded")
		return
	end
	if underCooldown(player) then
		rejects.reject(player.UserId, remote, "cooldown")
		return
	end
	local def = config.boosters[boosterId]
	if def == nil then
		rejects.reject(player.UserId, remote, "unknown_booster")
		return
	end
	-- No offers during the first minutes of a new player.
	if not Onboarding.isDone(profile.onboarding) then
		rejects.reject(player.UserId, remote, "not_available")
		reply(player, profile, false, "not_available")
		return
	end
	-- Paid random items are never offered to restricted players.
	if def.paidRandom and PaidRandomPolicy.isRestricted(player) then
		rejects.reject(player.UserId, remote, "restricted")
		reply(player, profile, false, "not_available")
		return
	end
	-- Not buyable without a dashboard id, and not when the time would be wasted.
	local remaining = Boosters.remaining(profile.boosters, boosterId, os.time())
	if def.productId <= 0 or remaining + def.durationSeconds > config.maxStackSeconds then
		reply(player, profile, false, "not_available")
		return
	end
	log.info("booster offer shown", { userId = player.UserId, booster = boosterId })
	MarketplaceService:PromptProductPurchase(player, def.productId)
end

local function handleFree(player: Player, ...: any)
	local remote = Remotes.names.boosterFree
	if select("#", ...) > 0 then
		rejects.reject(player.UserId, remote, "bad_arguments")
		return
	end
	local profile = DataService.getData(player)
	if profile == nil then
		rejects.reject(player.UserId, remote, "profile_not_loaded")
		return
	end
	if underCooldown(player) then
		rejects.reject(player.UserId, remote, "cooldown")
		return
	end
	if not Onboarding.isDone(profile.onboarding) then
		rejects.reject(player.UserId, remote, "not_available")
		reply(player, profile, false, "not_available")
		return
	end
	-- The free run is only for players known to be restricted; an unknown policy
	-- gets no free run (and no paid random item either).
	local ok, reason =
		Boosters.claimFree(profile.boosters, config, PaidRandomPolicy.isKnownRestricted(player), os.time())
	if not ok then
		rejects.reject(player.UserId, remote, reason or "not_available")
		reply(player, profile, false, if reason == "cooldown" then "cooldown" else "not_available")
		return
	end
	log.info("free booster claimed", { userId = player.UserId, booster = config.freeClaim.boosterId })
	reply(player, profile, true, nil)
end

local function handleReceipt(profile: ProfileData.Profile, info: ReceiptService.Info): ReceiptService.Outcome?
	if Boosters.keyOfProduct(config, info.productId) == nil then
		return nil
	end
	return Boosters.processReceipt(profile.boosters, config, info.purchaseId, info.productId, os.time())
end

function BoosterService.start()
	if started then
		log.warn("start called twice")
		return
	end
	started = true

	local ok, reason = Boosters.validateConfig(config)
	if not ok then
		log.error("booster config is invalid", { reason = reason })
	end
	digRollConfig = DigRules.build()
	rejects = RejectLimiter.new(log, DigConfig.warnInterval, os.clock)

	for key in config.boosters do
		ModifierService.register("booster_" .. key, function(profile: ProfileData.Profile)
			return Boosters.effectOf(profile.boosters, key, config, os.time())
		end)
	end

	boosterResult = Remotes.event(Remotes.names.boosterResult)
	Remotes.event(Remotes.names.boosterOffer).OnServerEvent:Connect(handleOffer)
	Remotes.event(Remotes.names.boosterFree).OnServerEvent:Connect(handleFree)
	Remotes.func(Remotes.names.getBoosters).OnServerInvoke = function(player: Player, ...: any)
		if select("#", ...) > 0 then
			return nil
		end
		local profile = DataService.getData(player)
		if profile == nil then
			return nil
		end
		return snapshotFor(player, profile)
	end

	ReceiptService.register({
		name = "boosters",
		handle = handleReceipt,
		onGranted = function(player: Player, profile: ProfileData.Profile)
			reply(player, profile, true, nil)
		end,
	})
	PaidRandomPolicy.onKnown(function(player: Player)
		local profile = DataService.getData(player)
		if profile ~= nil then
			reply(player, profile, true, nil)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastActionAt[player] = nil
		rejects.forget(player.UserId)
	end)

	log.info("started", { boosters = #config.order })
end

return BoosterService
