--!strict
-- Guests: friends dig together on one plot. A guest stands at the host's guest
-- sign and joins; from then on they can dig at the host's shaft as well as at
-- their own. The guest keeps all ore (own backpack and depth), the host gets a
-- few coins per guest block, up to a daily cap. The client only presses the
-- prompt; friendship, limits and positions are decided here. Only checkable in
-- Roblox Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Calendar = require(Shared:WaitForChild("Calendar"))
local GuestMessages = require(Shared:WaitForChild("GuestMessages"))
local Guests = require(Shared:WaitForChild("Guests"))
local Log = require(Shared:WaitForChild("Log"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))
local Config = Shared:WaitForChild("Config")
local DigConfig = require(Config:WaitForChild("Dig"))
local GuestConfig = require(Config:WaitForChild("Guests"))
local PlotConfig = require(Config:WaitForChild("Plot"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PlotLogic = require(script.Parent:WaitForChild("PlotLogic"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local RejectLimiter = require(script.Parent:WaitForChild("RejectLimiter"))

local log = Log.new("Guests")

local GuestService = {}

local LABEL_WIDTH = 140
local LABEL_HEIGHT = 36
local LABEL_LIFT = 1

local config: Guests.Config = GuestConfig
local registry: Guests.Registry
local signPositions: { [number]: Vector3 } = {}
local prompts: { [number]: ProximityPrompt } = {}
local lastActionAt: { [Player]: number } = {}
local rejects: RejectLimiter.Limiter
local guestStatus: RemoteEvent
local started = false

local function playerByUserId(userId: number): Player?
	return Players:GetPlayerByUserId(userId)
end

local function statusFor(player: Player, reason: string?): GuestMessages.Status & { reason: string? }
	local hostId = registry.hostOf(player.UserId)
	if hostId ~= nil then
		local host = playerByUserId(hostId)
		return { role = "guest", hostName = if host ~= nil then host.DisplayName else nil, reason = reason }
	end
	local names: { string } = {}
	for _, guestId in registry.guestsOf(player.UserId) do
		local guest = playerByUserId(guestId)
		if guest ~= nil then
			table.insert(names, guest.DisplayName)
		end
	end
	if #names > 0 then
		return {
			role = "host",
			names = names,
			earnedToday = registry.earnedToday(player.UserId, Calendar.dayOf(os.time())),
			reason = reason,
		}
	end
	return { role = "none", reason = reason }
end

local function sendStatus(player: Player, reason: string?)
	if player.Parent == Players then
		guestStatus:FireClient(player, statusFor(player, reason))
	end
end

-- Positions ------------------------------------------------------------------------

-- The shafts a player can dig at: their own and, as a guest, the host's.
-- Returns the shaft positions with the user id of the plot owner for each.
function GuestService.shaftsOf(player: Player): { { position: Vector3, ownerId: number } }
	local list = {}
	local own = PlotService.getShaftPosition(player)
	if own ~= nil then
		table.insert(list, { position = own, ownerId = player.UserId })
	end
	local hostId = registry.hostOf(player.UserId)
	local host = if hostId ~= nil then playerByUserId(hostId) else nil
	local hostShaft = if host ~= nil then PlotService.getShaftPosition(host) else nil
	if host ~= nil and hostShaft ~= nil then
		table.insert(list, { position = hostShaft, ownerId = host.UserId })
	end
	return list
end

-- Pays the host for one block that a guest dug at the host's shaft. Returns the
-- coins paid (0 when the cap is reached).
function GuestService.rewardHost(guest: Player, hostId: number): number
	local host = playerByUserId(hostId)
	local profile = if host ~= nil then DataService.getData(host) else nil
	if host == nil or profile == nil then
		return 0
	end
	local coins = registry.creditBlock(hostId, Calendar.dayOf(os.time()))
	if coins <= 0 then
		return 0
	end
	profile.coins += coins
	log.debug("host paid for a guest block", { hostId = hostId, guestId = guest.UserId, coins = coins })
	return coins
end

-- World -----------------------------------------------------------------------------

local function buildSigns()
	local signBox = PlotLogic.guestSignBox(PlotConfig)
	local color =
		Color3.fromRGB(PlotConfig.colors.guestSign.r, PlotConfig.colors.guestSign.g, PlotConfig.colors.guestSign.b)
	for slot = 1, PlotService.getSlotCount() do
		local model = PlotService.getModel(slot)
		local center = PlotService.getPlotCenter(slot)
		if model == nil or center == nil then
			log.error("plot missing for guest sign", { plot = slot })
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
		label.Text = Strings.guests.signLabel
		label.Parent = billboard

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = Strings.guests.promptAction
		prompt.ObjectText = ""
		prompt.KeyboardKeyCode = Enum.KeyCode.H -- E digs, F is the museum, G the house
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = config.promptDistance
		prompt.Enabled = false
		prompt.Parent = sign
		prompts[slot] = prompt
	end
end

local function refreshPrompt(slot: number)
	local prompt = prompts[slot]
	if prompt == nil then
		return
	end
	local ownerId = PlotService.getOwnerId(slot)
	local owner = if ownerId ~= nil then playerByUserId(ownerId) else nil
	prompt.Enabled = owner ~= nil
	prompt.ObjectText = if owner ~= nil then string.format(Strings.guests.promptObject, owner.DisplayName) else ""
end

-- Handlers --------------------------------------------------------------------------

local function handlePrompt(slot: number, player: Player)
	local remote = "GuestPrompt"
	local ownerId = PlotService.getOwnerId(slot)
	local owner = if ownerId ~= nil then playerByUserId(ownerId) else nil
	if owner == nil then
		return
	end
	if DataService.getData(player) == nil or DataService.getData(owner) == nil then
		rejects.reject(player.UserId, remote, "profile_not_loaded")
		return
	end
	local now = os.clock()
	local previous = lastActionAt[player]
	if previous ~= nil and now - previous < config.joinCooldown then
		rejects.reject(player.UserId, remote, "cooldown")
		return
	end
	lastActionAt[player] = now

	-- The sign also ends a visit: using it again at the same plot leaves.
	if registry.hostOf(player.UserId) == owner.UserId then
		registry.leave(player.UserId)
		log.info("guest left", { guestId = player.UserId, hostId = owner.UserId })
		sendStatus(player, nil)
		sendStatus(owner, nil)
		return
	end

	local distance = PlotService.horizontalDistance(player, signPositions[slot])
	if distance == nil or distance > config.joinDistance then
		rejects.reject(player.UserId, remote, "too_far")
		sendStatus(player, "too_far")
		return
	end

	local areFriends = false
	if config.friendsOnly and player ~= owner then
		local ok, result = pcall(function()
			return player:IsFriendsWith(owner.UserId)
		end)
		if not ok then
			log.warn("friendship check failed", { userId = player.UserId, error = tostring(result) })
		end
		areFriends = ok and result == true
	end
	-- A guest of another plot first leaves that one.
	local previousHost = registry.leave(player.UserId)
	local joined, reason = registry.join(player.UserId, owner.UserId, areFriends)
	if not joined then
		rejects.reject(player.UserId, remote, reason or "unknown")
		sendStatus(player, reason)
		if previousHost ~= nil then
			local old = playerByUserId(previousHost)
			if old ~= nil then
				sendStatus(old, nil)
			end
		end
		return
	end
	log.info(
		"guest joined",
		{ guestId = player.UserId, hostId = owner.UserId, guests = #registry.guestsOf(owner.UserId) }
	)
	sendStatus(player, nil)
	sendStatus(owner, nil)
	if previousHost ~= nil then
		local old = playerByUserId(previousHost)
		if old ~= nil then
			sendStatus(old, nil)
		end
	end
end

local function handleLeaving(player: Player)
	local userId = player.UserId
	local hostId = registry.hostOf(userId)
	local orphaned = registry.forget(userId)
	if hostId ~= nil then
		local host = playerByUserId(hostId)
		if host ~= nil then
			sendStatus(host, nil)
		end
	end
	for _, guestId in orphaned do
		local guest = playerByUserId(guestId)
		if guest ~= nil then
			sendStatus(guest, nil)
		end
	end
	lastActionAt[player] = nil
	rejects.forget(userId)
end

function GuestService.start()
	if started then
		log.warn("start called twice")
		return
	end
	started = true

	local ok, reason = Guests.validateConfig(config)
	if not ok then
		log.error("guest config is invalid", { reason = reason })
	end
	registry = Guests.new(config)
	rejects = RejectLimiter.new(log, DigConfig.warnInterval, os.clock)
	guestStatus = Remotes.event(Remotes.names.guestStatus)

	buildSigns()
	for slot, prompt in prompts do
		prompt.Triggered:Connect(function(player: Player)
			handlePrompt(slot, player)
		end)
	end
	PlotService.onAssigned(function(_player: Player, slot: number)
		refreshPrompt(slot)
	end)
	PlotService.onReleased(function(_userId: number, slot: number)
		refreshPrompt(slot)
	end)
	Players.PlayerRemoving:Connect(handleLeaving)

	log.info("started", { maxGuests = config.maxGuests })
end

return GuestService
