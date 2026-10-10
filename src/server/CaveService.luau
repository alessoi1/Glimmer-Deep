--!strict
-- The cave in the world: builds the blocks around a player, takes swings and
-- chest openings and moves the player down and up. All rules live in
-- CaveSession (tested under Lune); this service only does the Roblox side
-- (parts, remotes, teleport) and the logging. Switched off by
-- Config/Cave.enabled until it was tested in Roblox Studio. Only checkable in
-- Roblox Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cave = require(Shared:WaitForChild("Cave"))
local CaveSession = require(Shared:WaitForChild("CaveSession"))
local CaveView = require(Shared:WaitForChild("CaveView"))
local Log = require(Shared:WaitForChild("Log"))
local Quests = require(Shared:WaitForChild("Quests"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Config = Shared:WaitForChild("Config")
local BackpackConfig = require(Config:WaitForChild("Backpack"))
local CaveConfig = require(Config:WaitForChild("Cave"))
local ChestsConfig = require(Config:WaitForChild("Chests"))
local DigConfig = require(Config:WaitForChild("Dig"))
local EquipmentConfig = require(Config:WaitForChild("Equipment"))
local Layers = require(Config:WaitForChild("Layers"))
local OnboardingConfig = require(Config:WaitForChild("Onboarding"))
local PotionsConfig = require(Config:WaitForChild("Potions"))
local Rarities = require(Config:WaitForChild("Rarities"))
local ShovelConfig = require(Config:WaitForChild("Shovel"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local DigRules = require(script.Parent:WaitForChild("DigRules"))
local DigService = require(script.Parent:WaitForChild("DigService"))
local EventService = require(script.Parent:WaitForChild("EventService"))
local ModifierService = require(script.Parent:WaitForChild("ModifierService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))
local RejectLimiter = require(script.Parent:WaitForChild("RejectLimiter"))

local log = Log.new("Cave")

local CaveService = {}

local WORLD_FOLDER = "Caves"
local ARRIVAL_LIFT = 3 -- studs above the floor spot where the player is put
local RETURN_LIFT = 4 -- studs above the respawn point when going back up
local VALID_AXES: { [string]: boolean } = { row = true, x = true, y = true }
local PARTS_PER_STEP = 250 -- parts built per frame; the rest follows on the next frames
local FOLLOW_SECONDS = 0.25 -- how often the view follows a walking player

local settings: CaveSession.Settings
local caveConfig: Cave.Config
local digRules = DigRules.build()
local random = Random.new()
local rejects: RejectLimiter.Limiter
local caveResult: RemoteEvent
local worldFolder: Folder
local started = false
local rarityIndex: { [string]: number } = {}
local logFromIndex = math.huge

local sessions: { [Player]: CaveSession.Session } = {}
local inCave: { [Player]: boolean } = {}
local folders: { [Player]: Folder } = {}
local parts: { [Player]: { [string]: BasePart } } = {}
local radii: { [Player]: number } = {} -- sideways reach of the pickaxe the view was built for
local lastRow: { [Player]: number } = {} -- row the view was last built around

local function warnRejected(player: Player, remote: string, reason: string)
	rejects.reject(player.UserId, remote, reason)
end

local function toVec3(vec: CaveView.Vec): Vector3
	return Vector3.new(vec.x, vec.y, vec.z)
end

local function toVec(position: Vector3): CaveView.Vec
	return { x = position.X, y = position.Y, z = position.Z }
end

local function rootPart(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Cells the player cannot mine (the shell, and the side walls beyond the
-- pickaxe's reach) look and count as bedrock.
local function isUnbreakable(cell: CaveView.VisibleCell, radius: number): boolean
	return cell.kind == "bedrock" or math.abs(cell.x) > radius
end

local function colorFor(cell: CaveView.VisibleCell, radius: number): Color3
	local look = CaveConfig.look
	if isUnbreakable(cell, radius) then
		return Color3.fromRGB(look.bedrock.r, look.bedrock.g, look.bedrock.b)
	end
	local rgb = look[cell.kind]
	if cell.kind == "ore" then
		rgb = look.ore[cell.itemId or ""] or look.oreFallback
	end
	if rgb == nil then
		rgb = look.rock
	end
	return Color3.fromRGB(rgb.r, rgb.g, rgb.b)
end

local function buildPart(player: Player, session: CaveSession.Session, cell: CaveView.VisibleCell, folder: Folder)
	local axes = CaveView.axes(session.world)
	local center = CaveView.cellCenter(session.world, session.blockSize, session.slot, cell.row, cell.x, cell.y)
	local up = toVec3(axes.up)
	local right = toVec3(axes.right)
	local part = Instance.new("Part")
	part.Name = CaveView.key(cell.row, cell.x, cell.y)
	part.Size = Vector3.one * session.blockSize
	part.CFrame = CFrame.fromMatrix(toVec3(center), right, up)
	part.Anchored = true
	local unbreakable = isUnbreakable(cell, radii[player] or 0)
	part.Color = colorFor(cell, radii[player] or 0)
	part.Material = if unbreakable then Enum.Material.Slate else Enum.Material.Rock
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	-- Read by the client only to choose between swing and chest; the server never trusts it.
	part:SetAttribute("Kind", if unbreakable then "bedrock" else cell.kind)
	part.Parent = folder
	parts[player][part.Name] = part
end

-- Takes down what is not wanted any more at once and builds the new parts
-- nearest first, PARTS_PER_STEP per frame (thousands of parts in one frame
-- stall the server and the client). Returns after the first step; the rest
-- follows in a task that stops when the cave view is gone or the cell was
-- taken down again in the meantime.
local function applyDiff(player: Player, session: CaveSession.Session, refresh: CaveSession.Refresh)
	local folder = folders[player]
	local built = parts[player]
	if folder == nil or built == nil then
		return
	end
	for _, key in refresh.diff.remove do
		local part = built[key]
		if part ~= nil then
			part:Destroy()
			built[key] = nil
		end
	end
	if refresh.overBudget then
		log.warn("cave window is over the part budget", { userId = player.UserId, count = refresh.count })
	end

	local pending = refresh.diff.add
	local centerRow = refresh.row
	table.sort(pending, function(a: CaveView.VisibleCell, b: CaveView.VisibleCell)
		return math.abs(a.row - centerRow) < math.abs(b.row - centerRow)
	end)

	local nextIndex = 1
	local function buildStep()
		local stop = math.min(nextIndex + PARTS_PER_STEP - 1, #pending)
		for index = nextIndex, stop do
			local cell = pending[index]
			if session.built[CaveView.key(cell.row, cell.x, cell.y)] then
				buildPart(player, session, cell, folder)
			end
		end
		nextIndex = stop + 1
	end

	buildStep()
	if nextIndex > #pending then
		return
	end
	task.spawn(function()
		while nextIndex <= #pending do
			task.wait()
			if folders[player] ~= folder or parts[player] ~= built then
				return
			end
			buildStep()
		end
	end)
end

local function pickaxeRadius(profile: DataService.Profile): number
	return Cave.radiusFor(caveConfig, profile.upgradeLevels.shovel)
end

local function clearParts(player: Player, session: CaveSession.Session)
	local built = parts[player]
	if built ~= nil then
		for _, part in built do
			part:Destroy()
		end
	end
	parts[player] = {}
	CaveSession.clearBuilt(session)
end

local function updateView(player: Player, session: CaveSession.Session)
	local root = rootPart(player)
	local profile = DataService.getData(player)
	if root == nil or profile == nil then
		return
	end
	-- A better pickaxe reaches further sideways: color the walls again.
	local radius = pickaxeRadius(profile)
	if radii[player] ~= radius then
		radii[player] = radius
		clearParts(player, session)
	end
	local refresh = CaveSession.refresh(session, toVec(root.Position), os.time())
	lastRow[player] = refresh.row
	applyDiff(player, session, refresh)
	log.debug("cave view updated", {
		userId = player.UserId,
		row = refresh.row,
		added = #refresh.diff.add,
		removed = #refresh.diff.remove,
	})
end

local function removeView(player: Player)
	local folder = folders[player]
	if folder ~= nil then
		folder:Destroy()
	end
	folders[player] = nil
	parts[player] = nil
	radii[player] = nil
	lastRow[player] = nil
	local session = sessions[player]
	if session ~= nil then
		CaveSession.clearBuilt(session)
	end
end

local function leaveCave(player: Player, reason: string)
	if not inCave[player] then
		return
	end
	inCave[player] = nil
	local session = sessions[player]
	if session ~= nil then
		local written = CaveSession.save(session)
		log.debug("cave saved", { userId = player.UserId, slices = written })
	end
	removeView(player)
	log.info("left the cave", { userId = player.UserId, reason = reason })
end

local function loadSession(player: Player): CaveSession.Session?
	local existing = sessions[player]
	if existing ~= nil then
		return existing
	end
	local profile = DataService.getData(player)
	local slot = PlotService.getSlotOf(player)
	if profile == nil or slot == nil then
		warnRejected(player, Remotes.names.caveEnter, "profile_or_plot_missing")
		return nil -- handleEnter answers the client with "unavailable"
	end
	local session, reason = CaveSession.new(profile.cave, caveConfig, settings.world, settings.blockSize, slot)
	if session == nil then
		log.error("saved cave is unusable", { userId = player.UserId, reason = reason })
		return nil
	end
	sessions[player] = session
	log.info("cave loaded", { userId = player.UserId, slot = slot, depthRow = session.cave.deepestRow })
	return session
end

local function handleEnter(player: Player, ...: any)
	if select("#", ...) > 0 then
		warnRejected(player, Remotes.names.caveEnter, "unexpected_arguments")
		return
	end
	if inCave[player] then
		warnRejected(player, Remotes.names.caveEnter, "already_in_cave")
		return
	end
	local root = rootPart(player)
	if root == nil then
		warnRejected(player, Remotes.names.caveEnter, "no_character")
		caveResult:FireClient(player, { ok = false, reason = "unavailable" })
		return
	end
	local session = loadSession(player)
	if session == nil then
		-- Profile or plot not ready yet, or the saved cave is unusable: tell the
		-- client so the player can try again instead of seeing nothing.
		caveResult:FireClient(player, { ok = false, reason = "unavailable" })
		return
	end

	inCave[player] = true
	local ok, err = pcall(function()
		local folder = Instance.new("Folder")
		folder.Name = "Cave_" .. player.UserId
		folder.Parent = worldFolder
		folders[player] = folder
		parts[player] = {}
		local profile = DataService.getData(player)
		radii[player] = if profile ~= nil then pickaxeRadius(profile) else caveConfig.startRadius

		local entry = CaveSession.entryPoint(session)
		local axes = CaveView.axes(session.world)
		local position = toVec3(entry) + Vector3.new(0, ARRIVAL_LIFT, 0)
		local refresh = CaveSession.refresh(session, entry, os.time())
		lastRow[player] = refresh.row
		applyDiff(player, session, refresh)
		root.CFrame = CFrame.lookAt(position, position + toVec3(axes.forward))
	end)
	if not ok then
		-- Never stay half inside: otherwise every later try ends in "already_in_cave".
		log.error("entering the cave failed", { userId = player.UserId, error = tostring(err) })
		inCave[player] = nil
		removeView(player)
		caveResult:FireClient(player, { ok = false, reason = "unavailable" })
		return
	end
	log.info("entered the cave", { userId = player.UserId, slot = session.slot })
	caveResult:FireClient(player, { ok = true, entered = true, state = DigService.getState(player) })
end

local function handleLeave(player: Player, ...: any)
	if select("#", ...) > 0 then
		warnRejected(player, Remotes.names.caveLeave, "unexpected_arguments")
		return
	end
	if not inCave[player] then
		warnRejected(player, Remotes.names.caveLeave, "not_in_cave")
		return
	end
	leaveCave(player, "requested")
	local root = rootPart(player)
	local spawn = player.RespawnLocation
	if root ~= nil and spawn ~= nil then
		root.CFrame = spawn.CFrame + Vector3.new(0, RETURN_LIFT, 0)
	end
	caveResult:FireClient(player, { ok = true, left = true, state = DigService.getState(player) })
end

-- Whole numbers only; the session checks the range against the cave.
local function isWhole(value: any): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and math.abs(value) < 1e9
end

local function readHit(player: Player, remote: string, row: any, x: any, y: any): { row: number, x: number, y: number }?
	if not isWhole(row) or not isWhole(x) or not isWhole(y) then
		warnRejected(player, remote, "invalid_arguments")
		return nil
	end
	return { row = row, x = x, y = y }
end

local function activeSession(player: Player, remote: string): (CaveSession.Session?, BasePart?)
	local session = sessions[player]
	if not inCave[player] or session == nil then
		warnRejected(player, remote, "not_in_cave")
		return nil, nil
	end
	local root = rootPart(player)
	if root == nil then
		warnRejected(player, remote, "no_character")
		return nil, nil
	end
	return session, root
end

local function recordQuests(player: Player, action: any)
	QuestService.record(player, Quests.events.dig, #action.mined)
	for _, block in action.finds do
		QuestService.record(player, Quests.events.rare, 1)
		if block.mutationId ~= nil then
			QuestService.record(player, Quests.events.mutation, 1)
		end
	end
	if action.used >= action.capacity then
		QuestService.record(player, Quests.events.backpackFilled, 1)
	end
end

local function handleSwing(player: Player, row: any, x: any, y: any, axis: any, ...: any)
	if select("#", ...) > 0 or type(axis) ~= "string" or not VALID_AXES[axis] then
		warnRejected(player, Remotes.names.caveSwing, "invalid_arguments")
		return
	end
	local hit = readHit(player, Remotes.names.caveSwing, row, x, y)
	local session, root = activeSession(player, Remotes.names.caveSwing)
	local profile = DataService.getData(player)
	if hit == nil or session == nil or root == nil or profile == nil then
		return
	end

	local result = CaveSession.swing(session, {
		profile = profile,
		position = toVec(root.Position),
		hit = hit,
		axis = axis :: "row" | "x" | "y",
		digConfig = digRules,
		shovelLevels = ShovelConfig.levels,
		cooldownTolerance = ShovelConfig.cooldownTolerance,
		backpackLevels = BackpackConfig.levels,
		onboarding = OnboardingConfig,
		modifiers = ModifierService.get(profile),
		mutationBoost = EventService.mutationBoost(),
		now = os.clock(),
		time = os.time(),
		rng = function()
			return random:NextNumber()
		end,
	})

	local action = result.action
	if result.reason == "cooldown" then
		log.debug("swing inside cooldown", { userId = player.UserId })
		return
	end
	if not result.ok or action == nil then
		log.debug("swing rejected", { userId = player.UserId, reason = result.reason })
		caveResult:FireClient(player, { ok = false, reason = result.reason, state = DigService.getState(player) })
		return
	end

	log.debug("swing", { userId = player.UserId, mined = #action.mined, depth = action.depth })
	for _, block in action.finds do
		if block.rarityId ~= nil and (rarityIndex[block.rarityId] or 0) >= logFromIndex then
			log.info("rare find", {
				userId = player.UserId,
				findId = block.findId,
				rarityId = block.rarityId,
				mutationId = block.mutationId,
				value = block.value,
				depth = action.depth,
			})
		end
	end
	recordQuests(player, action)
	updateView(player, session)
	caveResult:FireClient(player, {
		ok = true,
		mined = #action.mined,
		finds = #action.finds,
		stoppedFull = action.stoppedFull,
		state = DigService.getState(player),
	})
end

local function countValues(map: { [string]: number }): number
	local total = 0
	for _, count in map do
		total += count
	end
	return total
end

local function handleChest(player: Player, row: any, x: any, y: any, ...: any)
	if select("#", ...) > 0 then
		warnRejected(player, Remotes.names.caveChest, "unexpected_arguments")
		return
	end
	local hit = readHit(player, Remotes.names.caveChest, row, x, y)
	local session, root = activeSession(player, Remotes.names.caveChest)
	local profile = DataService.getData(player)
	if hit == nil or session == nil or root == nil or profile == nil then
		return
	end

	local modifiers = ModifierService.get(profile)
	local result = CaveSession.openChest(session, {
		profile = profile :: any,
		position = toVec(root.Position),
		hit = hit,
		digConfig = digRules,
		lootConfig = ChestsConfig,
		lootDeps = { equipment = EquipmentConfig, potions = PotionsConfig },
		luck = modifiers.luck,
		mutationBoost = EventService.mutationBoost(),
		time = os.time(),
		rng = function()
			return random:NextNumber()
		end,
	})
	local summary = result.summary
	if not result.ok or summary == nil then
		log.debug("chest rejected", { userId = player.UserId, reason = result.reason })
		caveResult:FireClient(player, { ok = false, reason = result.reason, state = DigService.getState(player) })
		return
	end

	log.info("chest opened", {
		userId = player.UserId,
		row = hit.row,
		biome = result.biomeIndex,
		coins = summary.coins,
		gear = #summary.gear,
		potions = countValues(summary.potions),
		herbs = countValues(summary.herbs),
		finds = #summary.finds,
		converted = summary.converted,
	})
	updateView(player, session)
	caveResult:FireClient(player, {
		ok = true,
		chest = {
			coins = summary.coins,
			gear = #summary.gear,
			potions = countValues(summary.potions),
			herbs = countValues(summary.herbs),
			finds = #summary.finds,
		},
		state = DigService.getState(player),
	})
end

-- Ore and herbs grow back over time; look again while a player is in the cave.
local function refreshLoop()
	while true do
		task.wait(CaveConfig.refreshSeconds)
		for player, session in sessions do
			if inCave[player] then
				local ok, err = pcall(function()
					local changed = Cave.regrowAll(session.cave, caveConfig, os.time())
					if changed > 0 then
						log.debug("cave regrown", { userId = player.UserId, cells = changed })
						CaveSession.save(session)
						updateView(player, session)
					end
				end)
				if not ok then
					log.error("cave refresh failed", { userId = player.UserId, error = tostring(err) })
				end
			end
		end
	end
end

-- Builds the cave ahead while a player walks (not only after a swing).
local function followLoop()
	while true do
		task.wait(FOLLOW_SECONDS)
		for player, session in sessions do
			local root = if inCave[player] then rootPart(player) else nil
			if root ~= nil then
				local row = CaveView.rowAt(session.world, session.blockSize, session.slot, toVec(root.Position))
				if math.max(row, 0) ~= lastRow[player] then
					local ok, err = pcall(updateView, player, session)
					if not ok then
						log.error("cave follow failed", { userId = player.UserId, error = tostring(err) })
					end
				end
			end
		end
	end
end

function CaveService.isInCave(player: Player): boolean
	return inCave[player] == true
end

function CaveService.start()
	if started then
		log.warn("start called twice")
		return
	end
	started = true
	if not CaveConfig.enabled then
		log.info("cave is switched off (Config/Cave.enabled)")
		return
	end

	settings = {
		blockSize = CaveConfig.blockSize,
		height = CaveConfig.height,
		sliceRows = CaveConfig.sliceRows,
		metersPerRow = CaveConfig.metersPerRow,
		entranceRows = CaveConfig.entranceRows,
		corridorHalfWidth = CaveConfig.corridorHalfWidth,
		corridorHeight = CaveConfig.corridorHeight,
		startRadius = CaveConfig.startRadius,
		maxRadius = CaveConfig.maxRadius,
		radiusByLevel = CaveConfig.radiusByLevel,
		areaByLevel = CaveConfig.areaByLevel,
		resourceDensity = CaveConfig.resourceDensity,
		herbShare = CaveConfig.herbShare,
		findSpotShare = CaveConfig.findSpotShare,
		regrowSeconds = CaveConfig.regrowSeconds,
		chestChance = CaveConfig.chestChance,
		chestMinRow = CaveConfig.chestMinRow,
		chestRespawnSeconds = CaveConfig.chestRespawnSeconds,
		world = CaveConfig.world,
	}
	caveConfig = CaveSession.assemble(settings, Layers)

	local okConfig, configReason = Cave.validateConfig(caveConfig)
	local okWorld, worldReason = CaveView.validateWorld(settings.world, settings.blockSize, caveConfig)
	if not okConfig or not okWorld then
		log.error("cave config is invalid, cave stays off", { reason = configReason or worldReason })
		return
	end

	rejects = RejectLimiter.new(log, DigConfig.warnInterval, os.clock)
	for index, rarity in Rarities do
		rarityIndex[rarity.id] = index
	end
	logFromIndex = rarityIndex[DigConfig.logFromRarity] or math.huge

	-- The cave runs below the default destroy height for a deep cave: lower it so
	-- nobody is killed for being deep down (may be refused by Roblox; then the
	-- world origin keeps the cave above it for a while).
	local okHeight, heightError = pcall(function()
		Workspace.FallenPartsDestroyHeight = CaveConfig.fallenPartsDestroyHeight
	end)
	if not okHeight then
		log.warn("could not lower FallenPartsDestroyHeight", { error = tostring(heightError) })
	end

	worldFolder = Instance.new("Folder")
	worldFolder.Name = WORLD_FOLDER
	worldFolder.Parent = Workspace
	caveResult = Remotes.event(Remotes.names.caveResult)
	Remotes.event(Remotes.names.caveEnter).OnServerEvent:Connect(handleEnter)
	Remotes.event(Remotes.names.caveLeave).OnServerEvent:Connect(handleLeave)
	Remotes.event(Remotes.names.caveSwing).OnServerEvent:Connect(handleSwing)
	Remotes.event(Remotes.names.caveChest).OnServerEvent:Connect(handleChest)

	DataService.onLeaving(function(player: Player)
		leaveCave(player, "player_leaving")
		local session = sessions[player]
		if session ~= nil then
			CaveSession.save(session)
		end
		sessions[player] = nil
	end)
	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function()
			-- A respawn (death, reset) puts the player back on the plot.
			leaveCave(player, "respawned")
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function()
			leaveCave(player, "respawned")
		end)
	end

	task.spawn(refreshLoop)
	task.spawn(followLoop)
	log.info("started", { slots = PlotService.getSlotCount() })
end

return CaveService
