--!strict
-- Boosters bought as Developer Products: registers their bonuses, opens the
-- purchase prompt, confirms receipts (ProcessReceipt) and hands restricted
-- players a free run of the luck booster instead of the paid one.
-- Purchases happen only through MarketplaceService; the client only says which
-- offer it wants to look at. A receipt is confirmed only after the profile was
-- saved, and a repeated receipt never grants twice. Only checkable in Roblox
-- Studio.

local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
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
local ProfileData = require(script.Parent:WaitForChild("ProfileData"))
local RejectLimiter = require(script.Parent:WaitForChild("RejectLimiter"))

local log = Log.new("Boosters")

local BoosterService = {}

local ACTION_COOLDOWN = 1 -- seconds between two offers or claims per player

local config: Boosters.Config = BoosterConfig
local digRollConfig: DigRoll.Config
local lastActionAt: { [Player]: number } = {}
-- true = PolicyService restricts paid random items. nil = not known yet; treated
-- as restricted, so a paid random item is never offered by mistake.
local restricted: { [Player]: boolean } = {}
local rejects: RejectLimiter.Limiter
local boosterResult: RemoteEvent
local started = false

local function isRestricted(player: Player): boolean
	return restricted[player] ~= false
end

local function snapshotFor(player: Player, profile: ProfileData.Profile): Boosters.Snapshot
	local now = os.time()
	local view =
		Boosters.view(profile.boosters, config, now, Onboarding.isDone(profile.onboarding), isRestricted(player))
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
	if def.paidRandom and isRestricted(player) then
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
	local ok, reason = Boosters.claimFree(profile.boosters, config, restricted[player] == true, os.time())
	if not ok then
		rejects.reject(player.UserId, remote, reason or "not_available")
		reply(player, profile, false, if reason == "cooldown" then "cooldown" else "not_available")
		return
	end
	log.info("free booster claimed", { userId = player.UserId, booster = config.freeClaim.boosterId })
	reply(player, profile, true, nil)
end

-- Roblox calls this for every purchase of a Developer Product, again and again
-- until PurchaseGranted comes back. Never errors out: an error counts as not
-- processed.
local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local notYet = Enum.ProductPurchaseDecision.NotProcessedYet
	local userId = info.PlayerId
	local purchaseId = info.PurchaseId
	local productId = info.ProductId
	local player = if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	if player == nil then
		-- The player left; Roblox asks again when they come back.
		log.info("receipt for an absent player", { userId = userId, productId = productId })
		return notYet
	end
	local profile = DataService.getData(player)
	if profile == nil then
		log.warn("receipt before the profile is loaded", { userId = userId, productId = productId })
		return notYet
	end

	local outcome = Boosters.processReceipt(profile.boosters, config, purchaseId, productId, os.time())
	if outcome == "unknown_product" or outcome == "bad_receipt" then
		log.error("receipt cannot be processed", { userId = userId, productId = productId, outcome = outcome })
		return notYet
	end
	log.info(
		"receipt processed",
		{ userId = userId, productId = productId, purchaseId = purchaseId, outcome = outcome }
	)

	-- Confirm only when the grant is on disk. A repeated receipt saves again, so a
	-- failed first save is retried by Roblox's next call.
	if not DataService.saveNow(player) then
		log.error("receipt not confirmed, save failed", { userId = userId, purchaseId = purchaseId })
		return notYet
	end
	if outcome == "granted" and player.Parent == Players then
		reply(player, profile, true, nil)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function loadPolicy(player: Player)
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if not ok then
		-- Stays "unknown", which counts as restricted.
		log.warn("policy lookup failed", { userId = player.UserId, error = tostring(info) })
		return
	end
	restricted[player] = info.ArePaidRandomItemsRestricted == true
	log.info("policy known", { userId = player.UserId, paidRandomRestricted = restricted[player] })
	local profile = DataService.getData(player)
	if profile ~= nil and player.Parent == Players then
		reply(player, profile, true, nil)
	end
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

	MarketplaceService.ProcessReceipt = processReceipt
	DataService.onLoaded(function(player: Player, _profile: ProfileData.Profile)
		task.spawn(loadPolicy, player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastActionAt[player] = nil
		restricted[player] = nil
		rejects.forget(player.UserId)
	end)

	log.info("started", { boosters = #config.order })
end

return BoosterService
