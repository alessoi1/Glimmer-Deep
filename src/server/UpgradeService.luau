--!strict
-- Handles the "buy upgrade" intention of the client. The client sends only the
-- upgrade id; the server checks profile, cooldown and id, takes price and level
-- from config and changes the profile. Only checkable in Roblox Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local Quests = require(Shared:WaitForChild("Quests"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local UpgradeAction = require(Shared:WaitForChild("UpgradeAction"))
local UpgradeEffects = require(Shared:WaitForChild("UpgradeEffects"))
local Config = Shared:WaitForChild("Config")
local DigConfig = require(Config:WaitForChild("Dig"))
local UpgradeConfig = require(Config:WaitForChild("Upgrade"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local DigService = require(script.Parent:WaitForChild("DigService"))
local ModifierService = require(script.Parent:WaitForChild("ModifierService"))
local MovementService = require(script.Parent:WaitForChild("MovementService"))
local ProfileData = require(script.Parent:WaitForChild("ProfileData"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))
local RejectLimiter = require(script.Parent:WaitForChild("RejectLimiter"))
local UpgradeRules = require(script.Parent:WaitForChild("UpgradeRules"))

local log = Log.new("Upgrade")

local UpgradeService = {}

local tracks = UpgradeRules.build()
local lastBuyAt: { [Player]: number } = {}
local rejects: RejectLimiter.Limiter
local upgradeResult: RemoteEvent
local started = false

-- Reasons that point to a manipulated client or a broken profile, not to a
-- normal "too expensive" click.
local SUSPICIOUS_REASONS = { bad_id = true, unknown_upgrade = true, invalid_state = true }

local function entriesFor(profile: DataService.Profile): { UpgradeAction.Entry }
	return UpgradeAction.snapshot(profile, tracks, UpgradeConfig.order)
end

local function handleBuy(player: Player, upgradeId: any, ...: any)
	local remote = Remotes.names.buyUpgrade
	if select("#", ...) > 0 then
		rejects.reject(player.UserId, remote, "unexpected_arguments")
		return
	end

	local profile = DataService.getData(player)
	if profile == nil then
		rejects.reject(player.UserId, remote, "profile_not_loaded")
		return
	end

	local now = os.clock()
	local previous = lastBuyAt[player]
	if previous ~= nil and now - previous < UpgradeConfig.cooldown then
		rejects.reject(player.UserId, remote, "cooldown")
		return
	end
	lastBuyAt[player] = now

	local result = UpgradeAction.buy(profile, tracks, upgradeId)
	if not result.ok then
		local reason = result.reason or "unknown"
		if SUSPICIOUS_REASONS[reason] then
			rejects.reject(player.UserId, remote, reason)
		else
			log.debug("upgrade rejected", { userId = player.UserId, reason = reason })
		end
		if reason == "invalid_state" then
			log.error("profile has inconsistent upgrade levels", { userId = player.UserId })
		end
		upgradeResult:FireClient(player, {
			ok = false,
			reason = reason,
			upgrades = entriesFor(profile),
			state = DigService.getState(player),
		})
		return
	end

	MovementService.refresh(player)
	QuestService.record(player, Quests.events.upgraded, 1)
	log.info("upgrade bought", {
		userId = player.UserId,
		upgradeId = upgradeId,
		newLevel = result.newLevel,
		price = result.price,
		coins = profile.coins,
	})
	upgradeResult:FireClient(player, {
		ok = true,
		upgradeId = upgradeId,
		upgrades = entriesFor(profile),
		state = DigService.getState(player),
	})
end

function UpgradeService.start()
	if started then
		log.warn("start called twice")
		return
	end
	started = true
	rejects = RejectLimiter.new(log, DigConfig.warnInterval, os.clock)

	-- Skills and the shovel's reach give bonuses to the whole game.
	ModifierService.register("upgrades", function(profile: ProfileData.Profile)
		return UpgradeEffects.part(profile.upgradeLevels, tracks)
	end)

	upgradeResult = Remotes.event(Remotes.names.upgradeResult)
	Remotes.event(Remotes.names.buyUpgrade).OnServerEvent:Connect(handleBuy)
	Remotes.func(Remotes.names.getUpgrades).OnServerInvoke = function(player: Player, ...: any)
		if select("#", ...) > 0 then
			return nil
		end
		local profile = DataService.getData(player)
		if profile == nil then
			return nil
		end
		return entriesFor(profile)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		lastBuyAt[player] = nil
		rejects.forget(player.UserId)
	end)

	log.info("started", { cooldown = UpgradeConfig.cooldown })
end

return UpgradeService
