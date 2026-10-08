--!strict
-- The rebirth "Neue Bohrung": a sign with a prompt opens the panel; after the
-- deepest launch layer was reached the player can start a new hole (coins,
-- tools and depth reset) and gets prestige points for permanent bonuses. The
-- client only sends intentions; depth, points and prices are decided here. Only
-- checkable in Roblox Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local Prestige = require(Shared:WaitForChild("Prestige"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))
local Config = Shared:WaitForChild("Config")
local DigConfig = require(Config:WaitForChild("Dig"))
local PlotConfig = require(Config:WaitForChild("Plot"))
local RebirthConfig = require(Config:WaitForChild("Rebirth"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local DigService = require(script.Parent:WaitForChild("DigService"))
local ModifierService = require(script.Parent:WaitForChild("ModifierService"))
local MovementService = require(script.Parent:WaitForChild("MovementService"))
local PlotLogic = require(script.Parent:WaitForChild("PlotLogic"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local ProfileData = require(script.Parent:WaitForChild("ProfileData"))
local ProfileRules = require(script.Parent:WaitForChild("ProfileRules"))
local RebirthReset = require(script.Parent:WaitForChild("RebirthReset"))
local RejectLimiter = require(script.Parent:WaitForChild("RejectLimiter"))

local log = Log.new("Rebirth")

local RebirthService = {}

local LABEL_WIDTH = 160
local LABEL_HEIGHT = 36
local LABEL_LIFT = 1

local config: Prestige.Config = RebirthConfig
local rules: ProfileData.Rules
local random = Random.new()
local signPositions: { [number]: Vector3 } = {}
local prompts: { [number]: ProximityPrompt } = {}
local lastActionAt: { [Player]: number } = {}
local rejects: RejectLimiter.Limiter
local rebirthOpen: RemoteEvent
local rebirthResult: RemoteEvent
local started = false

local function viewFor(profile: ProfileData.Profile): Prestige.View
	return Prestige.view(profile.prestige, profile.depth, config)
end

local function reply(player: Player, profile: ProfileData.Profile, ok: boolean, kind: string?, reason: string?)
	rebirthResult:FireClient(player, {
		ok = ok,
		kind = kind,
		reason = reason,
		view = viewFor(profile),
		state = DigService.getState(player),
	})
end

-- World -----------------------------------------------------------------------------

local function buildSigns()
	local signBox = PlotLogic.rebirthSignBox(PlotConfig)
	local color = Color3.fromRGB(
		PlotConfig.colors.rebirthSign.r,
		PlotConfig.colors.rebirthSign.g,
		PlotConfig.colors.rebirthSign.b
	)
	for slot = 1, PlotService.getSlotCount() do
		local model = PlotService.getModel(slot)
		local center = PlotService.getPlotCenter(slot)
		if model == nil or center == nil then
			log.error("plot missing for rebirth sign", { plot = slot })
			continue
		end
		local sign = Instance.new("Part")
		sign.Name = signBox.name
		sign.Size = Vector3.new(signBox.sizeX, signBox.sizeY, signBox.sizeZ)
		sign.Position = center + Vector3.new(signBox.x, signBox.y, signBox.z)
		sign.Anchored = true
		sign.Color = color
		sign.Material = Enum.Material.SmoothPlastic
		sign.Parent = model
		signPositions[slot] = sign.Position

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(LABEL_WIDTH, LABEL_HEIGHT)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, signBox.sizeY / 2 + LABEL_LIFT, 0)
		billboard.MaxDistance = PlotConfig.size
		billboard.Parent = sign
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(245, 245, 245)
		label.TextStrokeTransparency = 0.5
		label.Text = Strings.rebirth.signLabel
		label.Parent = billboard

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = Strings.rebirth.promptAction
		prompt.ObjectText = ""
		prompt.KeyboardKeyCode = Enum.KeyCode.J -- E digs, F museum, G house, H guests
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = config.promptDistance
		prompt.Parent = sign
		prompts[slot] = prompt
	end
end

local function handlePrompt(slot: number, player: Player)
	if PlotService.getSlotOf(player) ~= slot then
		return -- only the owner starts a new hole
	end
	local profile = DataService.getData(player)
	if profile == nil then
		rejects.reject(player.UserId, "RebirthPrompt", "profile_not_loaded")
		return
	end
	local distance = PlotService.horizontalDistance(player, signPositions[slot])
	if distance == nil or distance > config.useDistance then
		rejects.reject(player.UserId, "RebirthPrompt", "too_far")
		return
	end
	rebirthOpen:FireClient(player, viewFor(profile))
end

-- Handlers --------------------------------------------------------------------------

-- Common checks of the rebirth remotes: no unexpected arguments, a loaded
-- profile and the cooldown. Returns the profile, or nil after the rejection was
-- logged.
local function guard(player: Player, remote: string, ...: any): ProfileData.Profile?
	if select("#", ...) > 0 then
		rejects.reject(player.UserId, remote, "unexpected_arguments")
		return nil
	end
	local profile = DataService.getData(player)
	if profile == nil then
		rejects.reject(player.UserId, remote, "profile_not_loaded")
		return nil
	end
	local now = os.clock()
	local previous = lastActionAt[player]
	if previous ~= nil and now - previous < config.actionCooldown then
		rejects.reject(player.UserId, remote, "cooldown")
		return nil
	end
	lastActionAt[player] = now
	return profile
end

local function handleRebirth(player: Player, ...: any)
	local remote = Remotes.names.rebirthDo
	local profile = guard(player, remote, ...)
	if profile == nil then
		return
	end
	if not Prestige.canRebirth(profile.depth, config) then
		rejects.reject(player.UserId, remote, "too_shallow")
		reply(player, profile, false, nil, "too_shallow")
		return
	end
	local depth = RebirthReset.apply(profile, rules, function()
		return random:NextNumber()
	end, os.time())
	local given = Prestige.complete(profile.prestige, config)
	MovementService.refresh(player)
	log.info("rebirth", {
		userId = player.UserId,
		depth = depth,
		pointsGiven = given,
		rebirths = profile.prestige.rebirths,
		coins = profile.coins,
	})
	reply(player, profile, true, "rebirth", nil)
end

local function handleBuy(player: Player, upgradeId: any, ...: any)
	local remote = Remotes.names.rebirthBuy
	if type(upgradeId) ~= "string" then
		rejects.reject(player.UserId, remote, "bad_arguments")
		return
	end
	local profile = guard(player, remote, ...)
	if profile == nil then
		return
	end
	local result = Prestige.buy(profile.prestige, config, upgradeId)
	if not result.ok then
		local reason = result.reason or "unknown"
		if reason == "unknown_upgrade" then
			rejects.reject(player.UserId, remote, reason)
		else
			log.debug("prestige purchase rejected", { userId = player.UserId, reason = reason })
		end
		reply(player, profile, false, nil, reason)
		return
	end
	log.info("prestige bonus bought", {
		userId = player.UserId,
		bonus = upgradeId,
		level = profile.prestige.levels[upgradeId],
		pointsLeft = profile.prestige.points,
	})
	MovementService.refresh(player)
	reply(player, profile, true, "bought", nil)
end

function RebirthService.start()
	if started then
		log.warn("start called twice")
		return
	end
	started = true

	local ok, reason = Prestige.validateConfig(config)
	if not ok then
		log.error("rebirth config is invalid", { reason = reason })
	end
	rules = ProfileRules.build()
	rejects = RejectLimiter.new(log, DigConfig.warnInterval, os.clock)

	ModifierService.register("prestige", function(profile: ProfileData.Profile)
		return Prestige.effectOf(profile.prestige, config)
	end)

	buildSigns()
	for slot, prompt in prompts do
		prompt.Triggered:Connect(function(player: Player)
			handlePrompt(slot, player)
		end)
	end

	rebirthOpen = Remotes.event(Remotes.names.rebirthOpen)
	rebirthResult = Remotes.event(Remotes.names.rebirthResult)
	Remotes.event(Remotes.names.rebirthDo).OnServerEvent:Connect(handleRebirth)
	Remotes.event(Remotes.names.rebirthBuy).OnServerEvent:Connect(handleBuy)
	Remotes.func(Remotes.names.getRebirth).OnServerInvoke = function(player: Player, ...: any)
		if select("#", ...) > 0 then
			return nil
		end
		local profile = DataService.getData(player)
		if profile == nil then
			return nil
		end
		return viewFor(profile)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		lastActionAt[player] = nil
		rejects.forget(player.UserId)
	end)

	log.info("started", { requiredDepth = config.requiredDepth })
end

return RebirthService
