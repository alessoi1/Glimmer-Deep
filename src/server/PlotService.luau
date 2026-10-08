--!strict
-- Builds the placeholder plots at startup and gives every player a free plot
-- once their profile is loaded. The player spawns (and respawns) on their plot.
-- Characters are not loaded automatically: nobody spawns before owning a plot.
-- Only checkable in Roblox Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local LookConfig = require(Shared:WaitForChild("Config"):WaitForChild("Look"))
local ModelSpecs = require(Shared:WaitForChild("ModelSpecs"))
local Strings = require(Shared:WaitForChild("Strings"))
local PlotConfig = require(Shared:WaitForChild("Config"):WaitForChild("Plot"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local ModelFactory = require(script.Parent:WaitForChild("ModelFactory"))
local PlotLogic = require(script.Parent:WaitForChild("PlotLogic"))

local log = Log.new("Plot")

local PlotService = {}

local allocator: PlotLogic.Allocator = PlotLogic.newAllocator(PlotConfig.count)
local spawns: { [number]: SpawnLocation } = {}
local models: { [number]: Model } = {}
local assignedListeners: { (player: Player, slot: number) -> () } = {}
local releasedListeners: { (userId: number, slot: number) -> () } = {}
local shaftCenters: { [number]: Vector3 } = {} -- plot index -> shaft center at ground height
local sellPositions: { [number]: Vector3 } = {} -- plot index -> sell point center
local started = false

-- A grass layer ends a hair above the ground slabs so the two do not flicker.
local GRASS_THICKNESS = 0.4
local GRASS_TOP = 0.02
local SELL_LABEL_LIFT = 1.5

local function color(rgb: { r: number, g: number, b: number }): Color3
	return Color3.fromRGB(rgb.r, rgb.g, rgb.b)
end

local function newPart(box: PlotLogic.Box, center: Vector3, className: string): BasePart
	local part = Instance.new(className) :: BasePart
	part.Name = box.name
	part.Size = Vector3.new(box.sizeX, box.sizeY, box.sizeZ)
	part.Position = center + Vector3.new(box.x, box.y, box.z)
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function buildPlot(slot: PlotLogic.Slot, parent: Instance)
	local origin = PlotConfig.origin
	local center = Vector3.new(origin.x + slot.x, origin.y, origin.z + slot.z)

	local model = Instance.new("Model")
	model.Name = "Plot_" .. slot.index
	shaftCenters[slot.index] = center

	local palette = ModelFactory.palette
	for _, box in PlotLogic.groundBoxes(PlotConfig) do
		local part = newPart(box, center, "Part")
		part.Color = if box.name == "ShaftBottom" then color(PlotConfig.colors.shaftBottom) else color(palette.dirt)
		part.Material = Enum.Material.Ground
		part.Parent = model
		-- A thin grass layer on top of the ground slabs (the walls of the shaft stay dirt).
		if box.name ~= "ShaftBottom" then
			local cap = newPart(box, center, "Part")
			cap.Name = box.name .. "Grass"
			cap.Size = Vector3.new(box.sizeX, GRASS_THICKNESS, box.sizeZ)
			cap.Position = center + Vector3.new(box.x, GRASS_TOP - GRASS_THICKNESS / 2, box.z)
			cap.Color = color(palette.grass)
			cap.Material = Enum.Material.Grass
			cap.Parent = model
		end
	end
	ModelFactory.build(ModelSpecs.shaftRim(palette, PlotConfig.shaftSize), center, model)
	ModelFactory.build(ModelSpecs.scenery(palette, PlotConfig.size, LookConfig.scenery), center, model)

	local spawn = newPart(PlotLogic.spawnBox(PlotConfig), center, "SpawnLocation") :: SpawnLocation
	spawn.Color = color(PlotConfig.colors.spawn)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.CanCollide = true
	spawn.Parent = model
	spawns[slot.index] = spawn

	local sellBox = PlotLogic.sellBox(PlotConfig)
	local stand, pad = ModelFactory.build(
		ModelSpecs.sellStand(palette, PlotConfig.sellSize, PlotConfig.sellHeight),
		center + Vector3.new(sellBox.x, 0, sellBox.z),
		model
	)
	sellPositions[slot.index] = pad.Position
	ModelFactory.addLabel(stand, pad, Strings.sell.pointLabel, SELL_LABEL_LIFT)

	models[slot.index] = model
	model.Parent = parent
end

local function spawnCharacter(player: Player)
	if player.Parent ~= Players or allocator.slotOf(player.UserId) == nil then
		return
	end
	local ok, err = pcall(function()
		player:LoadCharacter()
	end)
	if not ok then
		log.error("loading character failed", { userId = player.UserId, error = tostring(err) })
	end
end

-- Respawns the player on their own plot after the character died.
local function watchDeath(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid == nil then
		log.warn("character without humanoid", { userId = player.UserId })
		return
	end
	humanoid.Died:Once(function()
		task.delay(Players.RespawnTime, spawnCharacter, player)
	end)
end

local function assignPlot(player: Player)
	local userId = player.UserId
	local slot = allocator.claim(userId)
	if slot == nil then
		log.warn("no free plot", { userId = userId, players = #Players:GetPlayers() })
		player:Kick(Strings.plot.serverFull)
		return
	end

	player.RespawnLocation = spawns[slot]
	log.info("plot assigned", { userId = userId, plot = slot, free = allocator.freeCount() })
	task.spawn(spawnCharacter, player)
	for _, listener in assignedListeners do
		local ok, err = pcall(listener, player, slot)
		if not ok then
			log.error("assigned listener failed", { userId = userId, error = tostring(err) })
		end
	end
end

local function releasePlot(player: Player)
	local slot = allocator.release(player.UserId)
	if slot ~= nil then
		log.info("plot released", { userId = player.UserId, plot = slot, free = allocator.freeCount() })
		for _, listener in releasedListeners do
			local ok, err = pcall(listener, player.UserId, slot)
			if not ok then
				log.error("released listener failed", { userId = player.UserId, error = tostring(err) })
			end
		end
	end
end

-- Shaft center (at ground height) of the plot owned by the player, or nil
-- when the player has no plot.
function PlotService.getShaftPosition(player: Player): Vector3?
	local slot = allocator.slotOf(player.UserId)
	if slot == nil then
		return nil
	end
	return shaftCenters[slot]
end

-- Number of the plot owned by the player, or nil.
function PlotService.getSlotOf(player: Player): number?
	return allocator.slotOf(player.UserId)
end

-- User id of the owner of plot `slot`, or nil when the plot is free.
function PlotService.getOwnerId(slot: number): number?
	return allocator.ownerOf(slot)
end

-- Number of plots on this server.
function PlotService.getSlotCount(): number
	return PlotConfig.count
end

-- Model and shaft center (ground height) of a plot, whether it is taken or not.
function PlotService.getModel(slot: number): Model?
	return models[slot]
end

function PlotService.getPlotCenter(slot: number): Vector3?
	return shaftCenters[slot]
end

-- Called after a player got a plot / after a player's plot was released.
function PlotService.onAssigned(listener: (player: Player, slot: number) -> ())
	table.insert(assignedListeners, listener)
end

function PlotService.onReleased(listener: (userId: number, slot: number) -> ())
	table.insert(releasedListeners, listener)
end

-- Center of the sell point on the plot owned by the player, or nil when the
-- player has no plot.
function PlotService.getSellPosition(player: Player): Vector3?
	local slot = allocator.slotOf(player.UserId)
	if slot == nil then
		return nil
	end
	return sellPositions[slot]
end

-- Horizontal distance (studs) from the player's character to a point, or nil
-- when there is no point or no character with a root part.
function PlotService.horizontalDistance(player: Player, target: Vector3?): number?
	local character = player.Character
	if target == nil or character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local offset = root.Position - target
	return Vector3.new(offset.X, 0, offset.Z).Magnitude
end

function PlotService.start()
	if started then
		log.warn("start called twice")
		return
	end
	started = true

	local ok, reason = PlotLogic.validateConfig(PlotConfig)
	if not ok then
		log.error("plot config is invalid", { reason = reason })
		return
	end

	Players.CharacterAutoLoads = false

	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	for _, slot in PlotLogic.layout(PlotConfig) do
		buildPlot(slot, folder)
	end
	folder.Parent = workspace

	DataService.onLoaded(function(player: Player)
		assignPlot(player)
	end)
	Players.PlayerRemoving:Connect(releasePlot)
	local function track(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			watchDeath(player, character)
		end)
	end
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end

	log.info("started", { plots = PlotConfig.count })
end

return PlotService
