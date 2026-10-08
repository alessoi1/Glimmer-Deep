--!strict
-- The museum of every plot: the sign with the prompt, the showcases, the
-- remotes to display / remove finds and collect visitor income, admiration by
-- other players and the weekly board of this server. The client sends only
-- intentions (find id and showcase number); the server checks and decides.
-- Only checkable in Roblox Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Backpack = require(Shared:WaitForChild("Backpack"))
local Calendar = require(Shared:WaitForChild("Calendar"))
local Log = require(Shared:WaitForChild("Log"))
local MuseumLogic = require(Shared:WaitForChild("MuseumLogic"))
local MuseumMessages = require(Shared:WaitForChild("MuseumMessages"))
local Quests = require(Shared:WaitForChild("Quests"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))
local Config = Shared:WaitForChild("Config")
local BackpackConfig = require(Config:WaitForChild("Backpack"))
local DigConfig = require(Config:WaitForChild("Dig"))
local LayerConfig = require(Config:WaitForChild("Layers"))
local MuseumConfig = require(Config:WaitForChild("Museum"))
local PlotConfig = require(Config:WaitForChild("Plot"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local DigService = require(script.Parent:WaitForChild("DigService"))
local ModifierService = require(script.Parent:WaitForChild("ModifierService"))
local PlotLogic = require(script.Parent:WaitForChild("PlotLogic"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local ProfileData = require(script.Parent:WaitForChild("ProfileData"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))
local RejectLimiter = require(script.Parent:WaitForChild("RejectLimiter"))

local log = Log.new("Museum")

local MuseumService = {}

-- What the client panel shows: the pure view plus this server's weekly board.
type Snapshot = {
	view: MuseumLogic.View,
	board: { MuseumLogic.BoardEntry },
}

local COLOR_VITRINE =
	Color3.fromRGB(PlotConfig.colors.vitrine.r, PlotConfig.colors.vitrine.g, PlotConfig.colors.vitrine.b)
local COLOR_FILLED = Color3.fromRGB(
	PlotConfig.colors.vitrineFilled.r,
	PlotConfig.colors.vitrineFilled.g,
	PlotConfig.colors.vitrineFilled.b
)
local COLOR_SIGN = Color3.fromRGB(PlotConfig.colors.sign.r, PlotConfig.colors.sign.g, PlotConfig.colors.sign.b)
local LABEL_WIDTH = 180
local LABEL_HEIGHT = 36
local LABEL_LIFT = 2

local signPositions: { [number]: Vector3 } = {}
local prompts: { [number]: ProximityPrompt } = {}
local vitrineFolders: { [number]: Folder } = {}
local lastActionAt: { [Player]: number } = {}
local admiredAt: { [number]: { [number]: number } } = {} -- visitor user id -> owner user id -> server time
local rejects: RejectLimiter.Limiter
local museumOpen: RemoteEvent
local museumResult: RemoteEvent
local started = false

local function slotCountOf(profile: ProfileData.Profile): number
	return MuseumLogic.slotCount(MuseumConfig.slotsByHouseLevel, profile.house.level)
end

local function contextFor(profile: ProfileData.Profile, now: number): MuseumLogic.Context
	local bonuses = ModifierService.get(profile)
	return {
		now = now,
		slotCount = slotCountOf(profile),
		config = MuseumConfig,
		coinMultiplier = bonuses.coinMultiplier,
		backpackCapacity = Backpack.capacityForLevel(
			BackpackConfig.levels,
			profile.upgradeLevels.backpack,
			bonuses.capacityMultiplier
		),
	}
end

-- The most admired museums among the players on this server.
local function weeklyBoard(week: number): { MuseumLogic.BoardEntry }
	local entries: { MuseumLogic.BoardEntry } = {}
	for _, other in Players:GetPlayers() do
		local otherProfile = DataService.getData(other)
		if otherProfile ~= nil then
			table.insert(entries, {
				name = other.DisplayName,
				weekAdmires = MuseumLogic.weeklyAdmires(otherProfile.museum, week),
			})
		end
	end
	return MuseumLogic.board(entries, MuseumConfig.boardSize)
end

local function snapshotFor(profile: ProfileData.Profile): Snapshot
	local now = os.time()
	local week = Calendar.weekOf(now)
	return {
		view = MuseumLogic.view(profile, LayerConfig, contextFor(profile, now), week),
		board = weeklyBoard(week),
	}
end

-- World ---------------------------------------------------------------------------

local function newPart(box: PlotLogic.Box, center: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = box.name
	part.Size = Vector3.new(box.sizeX, box.sizeY, box.sizeZ)
	part.Position = center + Vector3.new(box.x, box.y, box.z)
	part.Anchored = true
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function addLabel(part: Part, text: string, lift: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(LABEL_WIDTH, LABEL_HEIGHT)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, part.Size.Y / 2 + lift, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = PlotConfig.size
	billboard.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextStrokeTransparency = 0.5
	label.Text = text
	label.Parent = billboard
end

-- Builds the sign, its prompt and the (empty) showcase folder of every plot.
local function buildSigns()
	local signBox = PlotLogic.museumSignBox(PlotConfig)
	for slot = 1, PlotService.getSlotCount() do
		local model = PlotService.getModel(slot)
		local center = PlotService.getPlotCenter(slot)
		if model == nil or center == nil then
			log.error("plot missing for museum sign", { plot = slot })
			continue
		end
		local sign = newPart(signBox, center, COLOR_SIGN)
		sign.Parent = model
		signPositions[slot] = sign.Position
		addLabel(sign, Strings.museum.title, LABEL_LIFT)

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = Strings.museum.promptAction
		prompt.ObjectText = ""
		prompt.KeyboardKeyCode = Enum.KeyCode.F -- E is the dig key
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = MuseumConfig.promptDistance
		prompt.Enabled = false
		prompt.Parent = sign
		prompts[slot] = prompt

		local folder = Instance.new("Folder")
		folder.Name = "Showcases"
		folder.Parent = model
		vitrineFolders[slot] = folder
	end
end

-- Rebuilds the showcases of a plot from the owner's profile (none for a free plot).
local function refreshShowcases(slot: number)
	local folder = vitrineFolders[slot]
	local center = PlotService.getPlotCenter(slot)
	if folder == nil or center == nil then
		return
	end
	folder:ClearAllChildren()

	local ownerId = PlotService.getOwnerId(slot)
	local owner = if ownerId ~= nil then Players:GetPlayerByUserId(ownerId) else nil
	local profile = if owner ~= nil then DataService.getData(owner) else nil
	local prompt = prompts[slot]
	if prompt ~= nil then
		prompt.Enabled = owner ~= nil and profile ~= nil
		prompt.ObjectText = if owner ~= nil then string.format(Strings.museum.promptObject, owner.DisplayName) else ""
	end
	if profile == nil then
		return
	end

	local displayBySlot: { [number]: MuseumLogic.Display } = {}
	for _, display in profile.museum.displays do
		displayBySlot[display.slot] = display
	end
	for number = 1, slotCountOf(profile) do
		local display = displayBySlot[number]
		local box = PlotLogic.vitrineBox(PlotConfig, number)
		local part = newPart(box, center, if display ~= nil then COLOR_FILLED else COLOR_VITRINE)
		if display ~= nil then
			addLabel(part, MuseumMessages.describeFind(Strings, display.find), LABEL_LIFT)
		end
		part.Parent = folder
	end
end

-- Results -------------------------------------------------------------------------

type ResultInfo = {
	ok: boolean,
	kind: string?,
	reason: string?,
	coins: number?,
	name: string?,
}

local function reply(player: Player, profile: ProfileData.Profile?, info: ResultInfo)
	museumResult:FireClient(player, {
		ok = info.ok,
		kind = info.kind,
		reason = info.reason,
		coins = info.coins or 0,
		name = info.name,
		snapshot = if profile ~= nil then snapshotFor(profile) else nil,
		state = DigService.getState(player),
	})
end

-- Common checks of the museum remotes. Returns the profile and the plot number
-- when the call may go on, otherwise nil after logging and answering.
local function checkAccess(player: Player, remote: string): (ProfileData.Profile?, number?)
	local profile = DataService.getData(player)
	if profile == nil then
		rejects.reject(player.UserId, remote, "profile_not_loaded")
		return nil, nil
	end
	local slot = PlotService.getSlotOf(player)
	local distance = PlotService.horizontalDistance(player, if slot ~= nil then signPositions[slot] else nil)
	if slot == nil or distance == nil then
		rejects.reject(player.UserId, remote, "no_plot_or_character")
		return nil, nil
	end

	local now = os.clock()
	local previous = lastActionAt[player]
	if previous ~= nil and now - previous < MuseumConfig.actionCooldown then
		rejects.reject(player.UserId, remote, "cooldown")
		return nil, nil
	end
	lastActionAt[player] = now

	if distance > MuseumConfig.useDistance then
		rejects.reject(player.UserId, remote, "too_far")
		reply(player, profile, { ok = false, reason = "too_far" })
		return nil, nil
	end
	return profile, slot
end

local function handleResult(
	player: Player,
	profile: ProfileData.Profile,
	slot: number,
	remote: string,
	kind: string,
	result: { ok: boolean, reason: string? }
)
	if not result.ok then
		local reason = result.reason or "unknown"
		if reason == "bad_input" or reason == "bad_slot" then
			rejects.reject(player.UserId, remote, reason)
		else
			log.debug("museum action rejected", { userId = player.UserId, remote = remote, reason = reason })
		end
		reply(player, profile, { ok = false, reason = reason })
		return
	end
	log.info("museum changed", {
		userId = player.UserId,
		kind = kind,
		displayed = #profile.museum.displays,
		coins = profile.coins,
	})
	refreshShowcases(slot)
	if kind == "displayed" then
		QuestService.record(player, Quests.events.displayed, 1)
	end
	reply(player, profile, { ok = true, kind = kind })
end

local function handleDisplay(player: Player, findId: any, showcase: any, ...: any)
	if select("#", ...) > 0 then
		rejects.reject(player.UserId, Remotes.names.museumDisplay, "unexpected_arguments")
		return
	end
	local profile, slot = checkAccess(player, Remotes.names.museumDisplay)
	if profile == nil or slot == nil then
		return
	end
	local result = MuseumLogic.display(profile, findId, showcase, contextFor(profile, os.time()))
	handleResult(player, profile, slot, Remotes.names.museumDisplay, "displayed", result)
end

local function handleRemove(player: Player, showcase: any, ...: any)
	if select("#", ...) > 0 then
		rejects.reject(player.UserId, Remotes.names.museumRemove, "unexpected_arguments")
		return
	end
	local profile, slot = checkAccess(player, Remotes.names.museumRemove)
	if profile == nil or slot == nil then
		return
	end
	local result = MuseumLogic.remove(profile, showcase, contextFor(profile, os.time()))
	handleResult(player, profile, slot, Remotes.names.museumRemove, "removed", result)
end

local function handleCollect(player: Player, ...: any)
	if select("#", ...) > 0 then
		rejects.reject(player.UserId, Remotes.names.museumCollect, "unexpected_arguments")
		return
	end
	local profile, slot = checkAccess(player, Remotes.names.museumCollect)
	if profile == nil or slot == nil then
		return
	end
	local result = MuseumLogic.collect(profile, contextFor(profile, os.time()))
	if not result.ok then
		log.debug("museum collect rejected", { userId = player.UserId, reason = result.reason })
		reply(player, profile, { ok = false, reason = result.reason })
		return
	end
	log.info("museum income collected", { userId = player.UserId, coinsEarned = result.coins, coins = profile.coins })
	QuestService.record(player, Quests.events.collected, 1)
	reply(player, profile, { ok = true, kind = "collected", coins = result.coins })
end

-- A visitor admires the museum of another player (a thumbs up, nothing is changed
-- or taken). Once per visitor and museum within the cooldown.
local function admire(visitor: Player, owner: Player, ownerProfile: ProfileData.Profile)
	if #ownerProfile.museum.displays == 0 then
		reply(visitor, nil, { ok = false, reason = "empty_museum" })
		return
	end
	local now = os.time()
	local byOwner = admiredAt[visitor.UserId]
	if byOwner == nil then
		byOwner = {}
		admiredAt[visitor.UserId] = byOwner
	end
	local previous = byOwner[owner.UserId]
	if previous ~= nil and now - previous < MuseumConfig.admireCooldown then
		reply(visitor, nil, { ok = false, reason = "already_admired" })
		return
	end
	byOwner[owner.UserId] = now

	MuseumLogic.admire(ownerProfile.museum, Calendar.weekOf(now))
	log.info("museum admired", {
		visitorId = visitor.UserId,
		ownerId = owner.UserId,
		admires = ownerProfile.museum.admires,
		weekAdmires = ownerProfile.museum.weekAdmires,
	})
	reply(visitor, nil, { ok = true, kind = "admired", name = owner.DisplayName })
	reply(owner, ownerProfile, { ok = true, kind = "admiredBy", name = visitor.DisplayName })
end

local function handlePrompt(slot: number, player: Player)
	local ownerId = PlotService.getOwnerId(slot)
	local owner = if ownerId ~= nil then Players:GetPlayerByUserId(ownerId) else nil
	if owner == nil then
		return
	end
	local ownerProfile = DataService.getData(owner)
	if ownerProfile == nil then
		return
	end
	local distance = PlotService.horizontalDistance(player, signPositions[slot])
	if distance == nil or distance > MuseumConfig.useDistance then
		rejects.reject(player.UserId, "MuseumPrompt", "too_far")
		return
	end

	if player == owner then
		museumOpen:FireClient(player, snapshotFor(ownerProfile))
		return
	end
	if DataService.getData(player) == nil then
		rejects.reject(player.UserId, "MuseumPrompt", "profile_not_loaded")
		return
	end
	admire(player, owner, ownerProfile)
end

-- Rebuilds the showcases of the player's plot (after the house level changed).
function MuseumService.refresh(player: Player)
	local slot = PlotService.getSlotOf(player)
	if slot ~= nil then
		refreshShowcases(slot)
	end
end

function MuseumService.start()
	if started then
		log.warn("start called twice")
		return
	end
	started = true
	rejects = RejectLimiter.new(log, DigConfig.warnInterval, os.clock)

	ModifierService.register("museum", function(profile: ProfileData.Profile)
		return MuseumLogic.modifierPart(profile.museum, LayerConfig, MuseumConfig)
	end)

	buildSigns()
	for slot, prompt in prompts do
		prompt.Triggered:Connect(function(player: Player)
			handlePrompt(slot, player)
		end)
	end
	PlotService.onAssigned(function(_player: Player, slot: number)
		refreshShowcases(slot)
	end)
	PlotService.onReleased(function(_userId: number, slot: number)
		refreshShowcases(slot)
	end)

	museumOpen = Remotes.event(Remotes.names.museumOpen)
	museumResult = Remotes.event(Remotes.names.museumResult)
	Remotes.event(Remotes.names.museumDisplay).OnServerEvent:Connect(handleDisplay)
	Remotes.event(Remotes.names.museumRemove).OnServerEvent:Connect(handleRemove)
	Remotes.event(Remotes.names.museumCollect).OnServerEvent:Connect(handleCollect)
	Remotes.func(Remotes.names.getMuseum).OnServerInvoke = function(player: Player, ...: any)
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
		admiredAt[player.UserId] = nil
		rejects.forget(player.UserId)
	end)

	log.info("started", { plots = PlotService.getSlotCount() })
end

return MuseumService
