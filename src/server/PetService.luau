--!strict
-- Pets from fossil eggs: opens the purchase prompt, hatches eggs (the roll runs
-- only here), equips pets, registers their bonuses, handles the egg receipts
-- (the ReceiptService confirms them) and gives restricted players a free egg
-- instead of the paid one. The client only sends intentions (which pet, "open
-- an egg"); it never sends prices or results. Only checkable in Roblox Studio.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local Onboarding = require(Shared:WaitForChild("Onboarding"))
local Pets = require(Shared:WaitForChild("Pets"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Config = Shared:WaitForChild("Config")
local DigConfig = require(Config:WaitForChild("Dig"))
local PetConfig = require(Config:WaitForChild("Pets"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local ModifierService = require(script.Parent:WaitForChild("ModifierService"))
local PaidRandomPolicy = require(script.Parent:WaitForChild("PaidRandomPolicy"))
local ProfileData = require(script.Parent:WaitForChild("ProfileData"))
local ReceiptService = require(script.Parent:WaitForChild("ReceiptService"))
local RejectLimiter = require(script.Parent:WaitForChild("RejectLimiter"))

local log = Log.new("Pets")

local PetService = {}

local ACTION_COOLDOWN = 0.5 -- seconds between two actions per player
local EPIC_INDEX = 3 -- hatches of this rarity tier or better are logged as rare finds

local config: Pets.Config = PetConfig
local random = Random.new()
local lastActionAt: { [Player]: number } = {}
local rejects: RejectLimiter.Limiter
local petResult: RemoteEvent
local started = false

local function snapshotFor(player: Player, profile: ProfileData.Profile): Pets.Snapshot
	return Pets.snapshot(
		profile.pets,
		config,
		os.time(),
		Onboarding.isDone(profile.onboarding),
		PaidRandomPolicy.isRestricted(player)
	)
end

local function reply(
	player: Player,
	profile: ProfileData.Profile,
	ok: boolean,
	reason: string?,
	hatched: Pets.OpenResult?
)
	petResult:FireClient(player, {
		ok = ok,
		reason = reason,
		snapshot = snapshotFor(player, profile),
		hatched = hatched,
	})
end

-- Throttles per player; returns true when the call came too soon.
local function underCooldown(player: Player): boolean
	local now = os.clock()
	local previous = lastActionAt[player]
	if previous ~= nil and now - previous < ACTION_COOLDOWN then
		return true
	end
	lastActionAt[player] = now
	return false
end

-- Common checks of every pet remote: no unexpected arguments, a loaded profile,
-- the cooldown and a finished onboarding. Returns the profile, or nil after the
-- rejection was logged.
local function guard(player: Player, remote: string, extra: number, ...: any): ProfileData.Profile?
	if select("#", ...) > extra then
		rejects.reject(player.UserId, remote, "bad_arguments")
		return nil
	end
	local profile = DataService.getData(player)
	if profile == nil then
		rejects.reject(player.UserId, remote, "profile_not_loaded")
		return nil
	end
	if underCooldown(player) then
		rejects.reject(player.UserId, remote, "cooldown")
		return nil
	end
	-- No offers and no panel actions during the first minutes of a new player.
	if not Onboarding.isDone(profile.onboarding) then
		rejects.reject(player.UserId, remote, "not_available")
		reply(player, profile, false, "not_available")
		return nil
	end
	return profile
end

local function handleOffer(player: Player, ...: any)
	local remote = Remotes.names.petOffer
	local profile = guard(player, remote, 0, ...)
	if profile == nil then
		return
	end
	-- A paid random item is never offered to restricted players.
	if PaidRandomPolicy.isRestricted(player) then
		rejects.reject(player.UserId, remote, "restricted")
		reply(player, profile, false, "not_available")
		return
	end
	if config.egg.productId <= 0 then
		reply(player, profile, false, "not_available")
		return
	end
	log.info("egg offer shown", { userId = player.UserId })
	MarketplaceService:PromptProductPurchase(player, config.egg.productId)
end

local function handleOpen(player: Player, ...: any)
	local profile = guard(player, Remotes.names.petOpen, 0, ...)
	if profile == nil then
		return
	end
	local result, reason = Pets.open(profile.pets, config, function()
		return random:NextNumber()
	end)
	if result == nil then
		rejects.reject(player.UserId, Remotes.names.petOpen, reason or "unknown")
		reply(player, profile, false, reason)
		return
	end
	local rarityIndex = table.find(config.rarityOrder, result.rarityId) or 0
	local context = {
		userId = player.UserId,
		pet = result.petId,
		rarity = result.rarityId,
		guaranteed = result.guaranteed,
		eggsLeft = profile.pets.eggs,
	}
	if rarityIndex >= EPIC_INDEX then
		log.info("rare pet hatched", context)
	else
		log.debug("pet hatched", context)
	end
	reply(player, profile, true, nil, result)
end

local function handleEquip(player: Player, instanceId: any, ...: any)
	local remote = Remotes.names.petEquip
	if type(instanceId) ~= "number" or instanceId % 1 ~= 0 or instanceId < 1 then
		rejects.reject(player.UserId, remote, "bad_arguments")
		return
	end
	local profile = guard(player, remote, 0, ...)
	if profile == nil then
		return
	end
	-- One press toggles: a working pet steps down, a resting pet starts working.
	if table.find(profile.pets.equipped, instanceId) ~= nil then
		Pets.unequip(profile.pets, instanceId)
		log.debug("pet unequipped", { userId = player.UserId, instanceId = instanceId })
		reply(player, profile, true, nil)
		return
	end
	local ok, reason = Pets.equip(profile.pets, config, instanceId)
	if not ok then
		rejects.reject(player.UserId, remote, reason or "unknown")
		reply(player, profile, false, "not_available")
		return
	end
	log.debug("pet equipped", { userId = player.UserId, instanceId = instanceId })
	reply(player, profile, true, nil)
end

local function handleFree(player: Player, ...: any)
	local remote = Remotes.names.petFree
	local profile = guard(player, remote, 0, ...)
	if profile == nil then
		return
	end
	-- The free egg is only for players known to be restricted; an unknown policy
	-- gets no free egg (and no paid egg either).
	local ok, reason = Pets.claimFree(profile.pets, config, PaidRandomPolicy.isKnownRestricted(player), os.time())
	if not ok then
		rejects.reject(player.UserId, remote, reason or "not_available")
		reply(player, profile, false, if reason == "cooldown" then "cooldown" else "not_available")
		return
	end
	log.info("free egg claimed", { userId = player.UserId })
	reply(player, profile, true, nil)
end

local function handleReceipt(profile: ProfileData.Profile, info: ReceiptService.Info): ReceiptService.Outcome?
	if config.egg.productId <= 0 or info.productId ~= config.egg.productId then
		return nil
	end
	return Pets.processReceipt(profile.pets, config, info.purchaseId, info.productId)
end

function PetService.start()
	if started then
		log.warn("start called twice")
		return
	end
	started = true

	local ok, reason = Pets.validateConfig(config)
	if not ok then
		log.error("pet config is invalid", { reason = reason })
	end
	rejects = RejectLimiter.new(log, DigConfig.warnInterval, os.clock)

	ModifierService.register("pets", function(profile: ProfileData.Profile)
		return Pets.effectOf(profile.pets, config)
	end)

	petResult = Remotes.event(Remotes.names.petResult)
	Remotes.event(Remotes.names.petOffer).OnServerEvent:Connect(handleOffer)
	Remotes.event(Remotes.names.petOpen).OnServerEvent:Connect(handleOpen)
	Remotes.event(Remotes.names.petEquip).OnServerEvent:Connect(handleEquip)
	Remotes.event(Remotes.names.petFree).OnServerEvent:Connect(handleFree)
	Remotes.func(Remotes.names.getPets).OnServerInvoke = function(player: Player, ...: any)
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
		name = "pets",
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

	log.info("started", { pets = #config.order })
end

return PetService
