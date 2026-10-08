--!strict
-- The season: collects season points from game events, pays the free and
-- premium rewards once, and shows the weekly event next to it. A sign with a
-- prompt opens the panel. The client only asks to claim (track and level);
-- points, levels and rewards are decided here. Only checkable in Roblox Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Season = require(Shared:WaitForChild("Season"))
local Strings = require(Shared:WaitForChild("Strings"))
local Config = Shared:WaitForChild("Config")
local BoosterConfig = require(Config:WaitForChild("Boosters"))
local DigConfig = require(Config:WaitForChild("Dig"))
local HouseConfig = require(Config:WaitForChild("House"))
local PlotConfig = require(Config:WaitForChild("Plot"))
local SeasonConfig = require(Config:WaitForChild("Season"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local DigService = require(script.Parent:WaitForChild("DigService"))
local EventService = require(script.Parent:WaitForChild("EventService"))
local ModelFactory = require(script.Parent:WaitForChild("ModelFactory"))
local PlotLogic = require(script.Parent:WaitForChild("PlotLogic"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local ProfileData = require(script.Parent:WaitForChild("ProfileData"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))
local RejectLimiter = require(script.Parent:WaitForChild("RejectLimiter"))

local log = Log.new("Season")

local SeasonService = {}

local ACTION_COOLDOWN = 0.4 -- seconds between two claims per player
local USE_DISTANCE = 24 -- studs from the sign
local PROMPT_DISTANCE = 12

local config: Season.Config = SeasonConfig
local refs: Season.Refs
local signPositions: { [number]: Vector3 } = {}
local prompts: { [number]: ProximityPrompt } = {}
local lastActionAt: { [Player]: number } = {}
local rejects: RejectLimiter.Limiter
local seasonOpen: RemoteEvent
local seasonResult: RemoteEvent
local started = false

local function hasPremium(profile: ProfileData.Profile): boolean
	return profile.passes[config.passKey] == true
end

local function snapshotFor(profile: ProfileData.Profile): Season.Snapshot
	return {
		season = Season.view(profile.season, config, hasPremium(profile), os.time()),
		event = EventService.info(),
	}
end

local function reply(player: Player, profile: ProfileData.Profile, ok: boolean, reason: string?, level: number?)
	seasonResult:FireClient(player, {
		ok = ok,
		reason = reason,
		level = level,
		snapshot = snapshotFor(profile),
		state = DigService.getState(player),
	})
end

-- Season points ------------------------------------------------------------------

local function onRecord(player: Player, event: string, amount: number)
	local points = Season.xpFor(event, amount, config)
	if points <= 0 then
		return
	end
	local profile = DataService.getData(player)
	if profile == nil then
		return
	end
	local gained = Season.addXp(profile.season, config, points, os.time())
	if gained > 0 then
		local level = Season.levelOf(profile.season.xp, config)
		log.info("season level reached", { userId = player.UserId, level = level, xp = profile.season.xp })
		seasonResult:FireClient(player, { ok = true, reason = nil, level = level, snapshot = snapshotFor(profile) })
	end
end

-- World -----------------------------------------------------------------------------

local function buildSigns()
	local signBox = PlotLogic.seasonSignBox(PlotConfig)
	for slot = 1, PlotService.getSlotCount() do
		local model = PlotService.getModel(slot)
		local center = PlotService.getPlotCenter(slot)
		if model == nil or center == nil then
			log.error("plot missing for season sign", { plot = slot })
			continue
		end
		local sign = ModelFactory.sign(
			"Season",
			model,
			center,
			signBox.sizeX,
			signBox.x,
			signBox.z,
			PlotConfig.colors.seasonSign,
			Strings.season.signLabel
		)
		signPositions[slot] = sign.Position

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = Strings.season.promptAction
		prompt.ObjectText = ""
		prompt.KeyboardKeyCode = Enum.KeyCode.K -- E digs, F museum, G house, H guests, J rebirth
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = PROMPT_DISTANCE
		prompt.Parent = sign
		prompts[slot] = prompt
	end
end

-- Anyone may look at the season at any sign; it only shows their own progress.
local function handlePrompt(slot: number, player: Player)
	local profile = DataService.getData(player)
	if profile == nil then
		rejects.reject(player.UserId, "SeasonPrompt", "profile_not_loaded")
		return
	end
	local distance = PlotService.horizontalDistance(player, signPositions[slot])
	if distance == nil or distance > USE_DISTANCE then
		rejects.reject(player.UserId, "SeasonPrompt", "too_far")
		return
	end
	seasonOpen:FireClient(player, snapshotFor(profile))
end

local function handleClaim(player: Player, track: any, level: any, ...: any)
	local remote = Remotes.names.seasonClaim
	if select("#", ...) > 0 or type(track) ~= "string" or type(level) ~= "number" then
		rejects.reject(player.UserId, remote, "bad_arguments")
		return
	end
	local profile = DataService.getData(player)
	if profile == nil then
		rejects.reject(player.UserId, remote, "profile_not_loaded")
		return
	end
	local now = os.clock()
	local previous = lastActionAt[player]
	if previous ~= nil and now - previous < ACTION_COOLDOWN then
		rejects.reject(player.UserId, remote, "cooldown")
		return
	end
	lastActionAt[player] = now

	local result = Season.claim(profile.season, config, track, level, hasPremium(profile), os.time())
	if not result.ok or result.reward == nil then
		local reason = result.reason or "unknown"
		if reason == "bad_input" then
			rejects.reject(player.UserId, remote, reason)
		else
			log.debug("season claim rejected", { userId = player.UserId, reason = reason })
		end
		reply(player, profile, false, reason)
		return
	end
	local paid = Season.pay(profile, result.reward, refs, os.time())
	log.info("season reward claimed", {
		userId = player.UserId,
		track = track,
		level = level,
		kind = result.reward.kind,
		coins = paid.coins,
		eggs = paid.eggs,
	})
	reply(player, profile, true, nil)
end

function SeasonService.start()
	if started then
		log.warn("start called twice")
		return
	end
	started = true

	local decorPrices: { [string]: number } = {}
	for id, def in HouseConfig.items do
		decorPrices[id] = def.price
	end
	refs = { boosters = BoosterConfig, decorPrices = decorPrices }
	local ok, reason = Season.validateConfig(config, refs)
	if not ok then
		log.error("season config is invalid", { reason = reason })
	end
	rejects = RejectLimiter.new(log, DigConfig.warnInterval, os.clock)

	QuestService.onRecord(onRecord)

	buildSigns()
	for slot, prompt in prompts do
		prompt.Triggered:Connect(function(player: Player)
			handlePrompt(slot, player)
		end)
	end

	seasonOpen = Remotes.event(Remotes.names.seasonOpen)
	seasonResult = Remotes.event(Remotes.names.seasonResult)
	Remotes.event(Remotes.names.seasonClaim).OnServerEvent:Connect(handleClaim)
	Remotes.func(Remotes.names.getSeason).OnServerInvoke = function(player: Player, ...: any)
		if select("#", ...) > 0 then
			return nil
		end
		local profile = DataService.getData(player)
		if profile == nil then
			return nil
		end
		return snapshotFor(profile)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		lastActionAt[player] = nil
		rejects.forget(player.UserId)
	end)

	log.info("started", { levels = #config.levelXp, seasonWeeks = config.seasonWeeks })
end

return SeasonService
