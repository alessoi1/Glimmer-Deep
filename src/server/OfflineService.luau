--!strict
-- The offline digger: remembers when a player left and, when the player returns,
-- lets the digger helper dig for the time away (limited to the maximum hours)
-- into the depot. No background timers: everything is calculated on return from
-- the stored time. The client asks for the report once it is ready.
-- Only checkable in Roblox Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local OfflineLogic = require(Shared:WaitForChild("OfflineLogic"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Config = Shared:WaitForChild("Config")
local DiggerConfig = require(Config:WaitForChild("Digger"))
local Rarities = require(Config:WaitForChild("Rarities"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local DigRules = require(script.Parent:WaitForChild("DigRules"))
local ModifierService = require(script.Parent:WaitForChild("ModifierService"))
local ProfileData = require(script.Parent:WaitForChild("ProfileData"))

local log = Log.new("Offline")

local OfflineService = {}

local SECONDS_PER_HOUR = 3600
-- Offline finds from this rarity upwards are written to the log as events.
local LOG_FROM_RARITY = "epic"

local random = Random.new()
local digRules = DigRules.build()
local reports: { [Player]: { report: OfflineLogic.Report?, maxSeconds: number } } = {}
local rarityIndex: { [string]: number } = {}
local started = false

local function onLoaded(player: Player, profile: ProfileData.Profile)
	local bonuses = ModifierService.get(profile)
	local result = OfflineLogic.run({
		leftAt = profile.digger.leftAt,
		now = os.time(),
		digConfig = digRules,
		rng = function()
			return random:NextNumber()
		end,
		depth = profile.depth,
		levels = DiggerConfig.levels,
		level = profile.upgradeLevels.digger,
		config = DiggerConfig,
		extraHours = bonuses.offlineExtraHours,
		yieldMultiplier = bonuses.offlineMultiplier,
		luck = bonuses.luck,
		depot = profile.depot,
		nextFindId = profile.nextFindId,
	})
	profile.nextFindId = result.nextFindId
	-- The absence is used up, whether or not it paid anything.
	profile.digger.leftAt = nil

	reports[player] = {
		report = result.report,
		maxSeconds = (DiggerConfig.maxHours + bonuses.offlineExtraHours) * SECONDS_PER_HOUR,
	}

	local report = result.report
	if report == nil then
		return
	end
	log.info("offline yield", {
		userId = player.UserId,
		seconds = report.seconds,
		hours = report.hours,
		blocks = report.blocks,
		finds = #report.finds,
		lost = report.lost,
		capped = report.capped,
		level = profile.upgradeLevels.digger,
	})
	local minimum = rarityIndex[LOG_FROM_RARITY] or math.huge
	for _, find in report.finds do
		if (rarityIndex[find.rarityId] or 0) >= minimum then
			log.info("rare offline find", {
				userId = player.UserId,
				findId = find.findId,
				rarityId = find.rarityId,
				mutationId = find.mutationId,
				value = find.value,
			})
		end
	end
end

local function onLeaving(player: Player, profile: ProfileData.Profile)
	profile.digger.leftAt = os.time()
	log.debug("absence started", { userId = player.UserId, leftAt = profile.digger.leftAt })
end

function OfflineService.start()
	if started then
		log.warn("start called twice")
		return
	end
	started = true

	for index, rarity in Rarities do
		rarityIndex[rarity.id] = index
	end

	DataService.onLoaded(onLoaded)
	DataService.onLeaving(onLeaving)

	-- The client may be ready before or after the profile: nil means "ask again",
	-- the report is handed out only once.
	Remotes.func(Remotes.names.getOfflineReport).OnServerInvoke = function(player: Player, ...: any)
		if select("#", ...) > 0 then
			return nil
		end
		local entry = reports[player]
		if entry == nil then
			return nil
		end
		reports[player] = nil
		return { ready = true, report = entry.report, maxSeconds = entry.maxSeconds }
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		reports[player] = nil
	end)

	log.info("started", { maxHours = DiggerConfig.maxHours, depotCapacity = DiggerConfig.depotCapacity })
end

return OfflineService
