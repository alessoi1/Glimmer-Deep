--!strict
-- The house of every plot: buys the next house level (more showcases), buys
-- decoration with coins and places it on the decoration places west of the
-- shaft. The client only sends intentions (an item id, a place number); the
-- server checks the coins and decides. Only checkable in Roblox Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local House = require(Shared:WaitForChild("House"))
local Log = require(Shared:WaitForChild("Log"))
local ModelSpecs = require(Shared:WaitForChild("ModelSpecs"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))
local Config = Shared:WaitForChild("Config")
local DigConfig = require(Config:WaitForChild("Dig"))
local HouseConfig = require(Config:WaitForChild("House"))
local PlotConfig = require(Config:WaitForChild("Plot"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local DigService = require(script.Parent:WaitForChild("DigService"))
local MuseumService = require(script.Parent:WaitForChild("MuseumService"))
local ModelFactory = require(script.Parent:WaitForChild("ModelFactory"))
local PlotLogic = require(script.Parent:WaitForChild("PlotLogic"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local ProfileData = require(script.Parent:WaitForChild("ProfileData"))
local RejectLimiter = require(script.Parent:WaitForChild("RejectLimiter"))

local log = Log.new("House")

local HouseService = {}

local LABEL_LIFT = 1

local config: House.Config = HouseConfig
local decorFolders: { [number]: Folder } = {}
local signPositions: { [number]: Vector3 } = {}
local prompts: { [number]: ProximityPrompt } = {}
local lastActionAt: { [Player]: number } = {}
local rejects: RejectLimiter.Limiter
local houseResult: RemoteEvent
local houseOpen: RemoteEvent
local started = false

local function viewFor(profile: ProfileData.Profile): House.View
	return House.view(profile, config)
end

local function reply(player: Player, profile: ProfileData.Profile, ok: boolean, reason: string?)
	houseResult:FireClient(player, {
		ok = ok,
		reason = reason,
		view = viewFor(profile),
		state = DigService.getState(player),
	})
end

-- World ---------------------------------------------------------------------------

local function buildFolders()
	for slot = 1, PlotService.getSlotCount() do
		local model = PlotService.getModel(slot)
		if model == nil then
			log.error("plot missing for decoration", { plot = slot })
			continue
		end
		local folder = Instance.new("Folder")
		folder.Name = "Decor"
		folder.Parent = model
		decorFolders[slot] = folder
	end
end

local function buildSigns()
	local signBox = PlotLogic.houseSignBox(PlotConfig)
	for slot = 1, PlotService.getSlotCount() do
		local model = PlotService.getModel(slot)
		local center = PlotService.getPlotCenter(slot)
		if model == nil or center == nil then
			continue
		end
		local sign = ModelFactory.sign(
			"House",
			model,
			center,
			signBox.sizeX,
			signBox.x,
			signBox.z,
			PlotConfig.colors.houseSign,
			Strings.house.signLabel
		)
		signPositions[slot] = sign.Position

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = Strings.house.promptAction
		prompt.ObjectText = ""
		prompt.KeyboardKeyCode = Enum.KeyCode.G -- E digs, F is the museum
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = HouseConfig.promptDistance
		prompt.Parent = sign
		prompts[slot] = prompt
	end
end

-- Opens the panel for the owner who used the sign of this plot.
local function handlePrompt(slot: number, player: Player)
	if PlotService.getSlotOf(player) ~= slot then
		return -- only the owner changes the house
	end
	local profile = DataService.getData(player)
	if profile == nil then
		rejects.reject(player.UserId, "HousePrompt", "profile_not_loaded")
		return
	end
	local distance = PlotService.horizontalDistance(player, signPositions[slot])
	if distance == nil or distance > HouseConfig.useDistance then
		rejects.reject(player.UserId, "HousePrompt", "too_far")
		return
	end
	houseOpen:FireClient(player, viewFor(profile))
end

-- Rebuilds the decoration of a plot from the owner's profile (none for a free plot).
local function refreshDecor(slot: number)
	local folder = decorFolders[slot]
	local center = PlotService.getPlotCenter(slot)
	if folder == nil or center == nil then
		return
	end
	folder:ClearAllChildren()

	local ownerId = PlotService.getOwnerId(slot)
	local owner = if ownerId ~= nil then Players:GetPlayerByUserId(ownerId) else nil
	local profile = if owner ~= nil then DataService.getData(owner) else nil
	if profile == nil then
		return
	end
	for _, entry in House.view(profile, config).placed do
		local cell = PlotLogic.decorBox(PlotConfig, entry.slot)
		local spec = ModelSpecs.decor(ModelFactory.palette, entry.id)
		if spec ~= nil then
			local model, primary = ModelFactory.build(spec, center + Vector3.new(cell.x, 0, cell.z), folder)
			ModelFactory.addLabel(model, primary, Strings.house.item[entry.id] or entry.id, LABEL_LIFT)
		end
	end
end

-- Handlers ------------------------------------------------------------------------

-- Common checks of every house remote: no unexpected arguments, a loaded
-- profile, a plot and the cooldown. Returns the profile and the plot number, or
-- nil after the rejection was logged.
local function guard(player: Player, remote: string, extra: number, ...: any): (ProfileData.Profile?, number?)
	if select("#", ...) > extra then
		rejects.reject(player.UserId, remote, "unexpected_arguments")
		return nil, nil
	end
	local profile = DataService.getData(player)
	if profile == nil then
		rejects.reject(player.UserId, remote, "profile_not_loaded")
		return nil, nil
	end
	local slot = PlotService.getSlotOf(player)
	if slot == nil then
		rejects.reject(player.UserId, remote, "no_plot")
		return nil, nil
	end
	local now = os.clock()
	local previous = lastActionAt[player]
	if previous ~= nil and now - previous < config.actionCooldown then
		rejects.reject(player.UserId, remote, "cooldown")
		return nil, nil
	end
	lastActionAt[player] = now
	return profile, slot
end

local function finish(
	player: Player,
	profile: ProfileData.Profile,
	slot: number,
	remote: string,
	kind: string,
	result: House.Result,
	context: { [string]: any }
)
	if not result.ok then
		local reason = result.reason or "unknown"
		if reason == "unknown_item" or reason == "bad_slot" then
			rejects.reject(player.UserId, remote, reason)
		else
			log.debug("house action rejected", { userId = player.UserId, remote = remote, reason = reason })
		end
		reply(player, profile, false, reason)
		return
	end
	context.userId = player.UserId
	context.kind = kind
	context.coins = profile.coins
	log.info("house changed", context)
	refreshDecor(slot)
	if kind == "upgraded" then
		MuseumService.refresh(player)
	end
	reply(player, profile, true, nil)
end

local function handleUpgrade(player: Player, ...: any)
	local remote = Remotes.names.houseUpgrade
	local profile, slot = guard(player, remote, 0, ...)
	if profile == nil or slot == nil then
		return
	end
	local result = House.upgrade(profile, config)
	finish(player, profile, slot, remote, "upgraded", result, { level = profile.house.level })
end

local function handleBuy(player: Player, itemId: any, ...: any)
	local remote = Remotes.names.houseBuy
	if type(itemId) ~= "string" then
		rejects.reject(player.UserId, remote, "bad_arguments")
		return
	end
	local profile, slot = guard(player, remote, 0, ...)
	if profile == nil or slot == nil then
		return
	end
	local result = House.buy(profile, config, itemId)
	finish(player, profile, slot, remote, "bought", result, { item = itemId })
end

local function handlePlace(player: Player, itemId: any, place: any, ...: any)
	local remote = Remotes.names.housePlace
	if type(itemId) ~= "string" or type(place) ~= "number" then
		rejects.reject(player.UserId, remote, "bad_arguments")
		return
	end
	local profile, slot = guard(player, remote, 0, ...)
	if profile == nil or slot == nil then
		return
	end
	local result = House.place(profile, config, itemId, place)
	finish(player, profile, slot, remote, "placed", result, { item = itemId, place = place })
end

local function handleRemove(player: Player, place: any, ...: any)
	local remote = Remotes.names.houseRemove
	if type(place) ~= "number" or place % 1 ~= 0 then
		rejects.reject(player.UserId, remote, "bad_arguments")
		return
	end
	local profile, slot = guard(player, remote, 0, ...)
	if profile == nil or slot == nil then
		return
	end
	local result = House.remove(profile, place)
	finish(player, profile, slot, remote, "removed", result, { place = place })
end

function HouseService.start()
	if started then
		log.warn("start called twice")
		return
	end
	started = true

	local ok, reason = House.validateConfig(config)
	if not ok then
		log.error("house config is invalid", { reason = reason })
	end
	local plotOk, plotReason = PlotLogic.validateConfig(PlotConfig)
	if not plotOk then
		log.error("plot config is invalid", { reason = plotReason })
	end
	rejects = RejectLimiter.new(log, DigConfig.warnInterval, os.clock)

	buildFolders()
	buildSigns()
	for slot, prompt in prompts do
		prompt.Triggered:Connect(function(player: Player)
			handlePrompt(slot, player)
		end)
	end
	PlotService.onAssigned(function(_player: Player, slot: number)
		refreshDecor(slot)
	end)
	PlotService.onReleased(function(_userId: number, slot: number)
		refreshDecor(slot)
	end)

	houseResult = Remotes.event(Remotes.names.houseResult)
	houseOpen = Remotes.event(Remotes.names.houseOpen)
	Remotes.event(Remotes.names.houseUpgrade).OnServerEvent:Connect(handleUpgrade)
	Remotes.event(Remotes.names.houseBuy).OnServerEvent:Connect(handleBuy)
	Remotes.event(Remotes.names.housePlace).OnServerEvent:Connect(handlePlace)
	Remotes.event(Remotes.names.houseRemove).OnServerEvent:Connect(handleRemove)
	Remotes.func(Remotes.names.getHouse).OnServerInvoke = function(player: Player, ...: any)
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

	log.info("started")
end

return HouseService
