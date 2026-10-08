--!strict
-- Daily quests and the login chain. Other services report what happens
-- (QuestService.record); the player claims rewards with an intention. The day
-- always comes from the server clock. Only checkable in Roblox Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Calendar = require(Shared:WaitForChild("Calendar"))
local Log = require(Shared:WaitForChild("Log"))
local LoginChain = require(Shared:WaitForChild("LoginChain"))
local Quests = require(Shared:WaitForChild("Quests"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Config = Shared:WaitForChild("Config")
local DigConfig = require(Config:WaitForChild("Dig"))
local QuestConfig = require(Config:WaitForChild("Quests"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local ProfileData = require(script.Parent:WaitForChild("ProfileData"))
local RejectLimiter = require(script.Parent:WaitForChild("RejectLimiter"))

local log = Log.new("Quest")

local QuestService = {}

-- What the quest panel shows.
type Snapshot = {
	quests: Quests.View,
	login: LoginChain.View,
	secondsToReset: number,
}

local CLAIM_COOLDOWN = 0.3 -- seconds between two claims per player

local lastClaimAt: { [Player]: number } = {}
local rejects: RejectLimiter.Limiter
local questResult: RemoteEvent
local questDone: RemoteEvent
local getState: ((Player) -> any)? = nil
local started = false

-- Makes sure the quests and the login chain are those of today. Returns true
-- when something changed.
local function refresh(player: Player, profile: ProfileData.Profile): boolean
	local now = os.time()
	local day = Calendar.dayOf(now)
	local changed = false
	if Quests.refresh(profile.quests, QuestConfig.pool, QuestConfig.perDay, day, player.UserId) then
		log.info(
			"daily quests picked",
			{ userId = player.UserId, day = day, ids = table.concat(profile.quests.ids, ",") }
		)
		changed = true
	end
	local change = LoginChain.update(profile.login, day, #QuestConfig.login.rewards)
	if change ~= "same" then
		log.info("login chain updated", { userId = player.UserId, change = change, streak = profile.login.streak })
		changed = true
	end
	return changed
end

local function snapshotFor(profile: ProfileData.Profile): Snapshot
	return {
		quests = Quests.view(profile.quests, QuestConfig.pool, QuestConfig.allDoneBonus),
		login = LoginChain.view(profile.login, QuestConfig.login.rewards),
		secondsToReset = Calendar.secondsUntilNextDay(os.time()),
	}
end

-- Counts a game event for the player's quests of the day. Called by the
-- services that know what happened (digging, selling, upgrades, museum).
function QuestService.record(player: Player, event: string, amount: number)
	local profile = DataService.getData(player)
	if profile == nil then
		return
	end
	refresh(player, profile)
	local reached = Quests.record(profile.quests, QuestConfig.pool, event, amount)
	if #reached > 0 then
		log.info("quests completed", { userId = player.UserId, ids = table.concat(reached, ",") })
		questDone:FireClient(player, reached)
	end
end

local function reply(
	player: Player,
	profile: ProfileData.Profile,
	ok: boolean,
	kind: string?,
	coins: number,
	reason: string?
)
	questResult:FireClient(player, {
		ok = ok,
		kind = kind,
		coins = coins,
		reason = reason,
		snapshot = snapshotFor(profile),
		state = if getState ~= nil then getState(player) else nil,
	})
end

local function handleClaim(player: Player, kind: any, questId: any, ...: any)
	local remote = Remotes.names.questClaim
	if select("#", ...) > 0 or (kind ~= "quest" and kind ~= "bonus" and kind ~= "login") then
		rejects.reject(player.UserId, remote, "bad_arguments")
		return
	end
	local profile = DataService.getData(player)
	if profile == nil then
		rejects.reject(player.UserId, remote, "profile_not_loaded")
		return
	end
	local now = os.clock()
	local previous = lastClaimAt[player]
	if previous ~= nil and now - previous < CLAIM_COOLDOWN then
		rejects.reject(player.UserId, remote, "cooldown")
		return
	end
	lastClaimAt[player] = now

	refresh(player, profile)
	local result: { ok: boolean, reason: string?, coins: number }
	if kind == "quest" then
		result = Quests.claim(profile.quests, QuestConfig.pool, questId)
	elseif kind == "bonus" then
		result = Quests.claimBonus(profile.quests, QuestConfig.allDoneBonus)
	else
		result = LoginChain.claim(profile.login, QuestConfig.login.rewards)
	end

	if not result.ok then
		if result.reason == "unknown_quest" or result.reason == "not_picked" then
			rejects.reject(player.UserId, remote, result.reason)
		end
		reply(player, profile, false, kind, 0, result.reason)
		return
	end
	profile.coins += result.coins
	log.info("quest reward claimed", {
		userId = player.UserId,
		kind = kind,
		questId = if kind == "quest" then questId else nil,
		coinsEarned = result.coins,
		coins = profile.coins,
	})
	reply(player, profile, true, kind, result.coins, nil)
end

-- `stateProvider` returns the dig state of a player (coins, backpack) so a claim
-- can update the HUD; it is passed in to keep the services free of cycles.
function QuestService.start(stateProvider: (Player) -> any)
	if started then
		log.warn("start called twice")
		return
	end
	started = true
	getState = stateProvider

	local ok, reason = Quests.validatePool(QuestConfig.pool, QuestConfig.perDay)
	if not ok then
		log.error("quest pool is invalid", { reason = reason })
	end
	rejects = RejectLimiter.new(log, DigConfig.warnInterval, os.clock)

	questResult = Remotes.event(Remotes.names.questResult)
	questDone = Remotes.event(Remotes.names.questDone)
	Remotes.event(Remotes.names.questClaim).OnServerEvent:Connect(handleClaim)
	Remotes.func(Remotes.names.getQuests).OnServerInvoke = function(player: Player, ...: any)
		if select("#", ...) > 0 then
			return nil
		end
		local profile = DataService.getData(player)
		if profile == nil then
			return nil
		end
		refresh(player, profile)
		return snapshotFor(profile)
	end

	DataService.onLoaded(function(player: Player, profile: ProfileData.Profile)
		refresh(player, profile)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastClaimAt[player] = nil
		rejects.forget(player.UserId)
	end)

	log.info("started", { perDay = QuestConfig.perDay, poolSize = #QuestConfig.pool })
end

return QuestService
