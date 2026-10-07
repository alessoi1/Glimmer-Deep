--!strict
-- Builds the placeholder plots at startup and gives every player a free plot
-- once their profile is loaded. The player spawns (and respawns) on their plot.
-- Characters are not loaded automatically: nobody spawns before owning a plot.
-- Only checkable in Roblox Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local Strings = require(Shared:WaitForChild("Strings"))
local PlotConfig = require(Shared:WaitForChild("Config"):WaitForChild("Plot"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PlotLogic = require(script.Parent:WaitForChild("PlotLogic"))

local log = Log.new("Plot")

local PlotService = {}

local allocator: PlotLogic.Allocator = PlotLogic.newAllocator(PlotConfig.count)
local spawns: { [number]: SpawnLocation } = {}
local shaftCenters: { [number]: Vector3 } = {} -- plot index -> shaft center at ground height
local started = false

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

	for _, box in PlotLogic.groundBoxes(PlotConfig) do
		local part = newPart(box, center, "Part")
		part.Color =
			color(if box.name == "ShaftBottom" then PlotConfig.colors.shaftBottom else PlotConfig.colors.ground)
		part.Material = Enum.Material.Ground
		part.Parent = model
	end

	local spawn = newPart(PlotLogic.spawnBox(PlotConfig), center, "SpawnLocation") :: SpawnLocation
	spawn.Color = color(PlotConfig.colors.spawn)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.CanCollide = true
	spawn.Parent = model
	spawns[slot.index] = spawn

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
end

local function releasePlot(player: Player)
	local slot = allocator.release(player.UserId)
	if slot ~= nil then
		log.info("plot released", { userId = player.UserId, plot = slot, free = allocator.freeCount() })
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
