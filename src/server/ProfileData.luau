--!strict
-- Pure profile data logic: format, validation and version migration.
-- No Roblox services and no DataStore access; the DataService loads and saves
-- through ProfileStore and uses this module to check and upgrade what it got.
-- The hole is stored as depth plus one seed per layer, never as blocks.

export type Find = {
	id: number, -- unique within the profile
	findId: string,
	layerId: string,
	rarityId: string,
	mutationId: string?,
	value: number,
}

export type Stash = {
	ores: { [string]: number },
	finds: { Find },
}

export type Display = { slot: number, find: Find }

export type Museum = {
	displays: { Display },
	incomeSince: number, -- server time from which visitor income is counted
	admires: number,
	week: number, -- week number of weekAdmires
	weekAdmires: number,
}

export type QuestState = {
	day: number,
	ids: { string },
	progress: { [string]: number },
	claimed: { [string]: boolean },
	bonusClaimed: boolean,
}

export type Login = { lastDay: number, streak: number, claimed: boolean }

export type Onboarding = { step: number, firstFindGiven: boolean }

export type BoosterState = {
	expires: { [string]: number }, -- booster id -> server time it ends
	receipts: { string }, -- latest purchase ids, oldest first
	freeClaimedAt: number, -- server time of the last free claim, 0 = never
}

export type Profile = {
	version: number,
	createdAt: number, -- server time (os.time) when the profile was created
	coins: number,
	nextFindId: number, -- next free find id
	upgradeLevels: { [string]: number }, -- upgrade id -> level, starting at 1
	depth: number, -- meters
	layerSeeds: { [string]: number }, -- layer id -> random seed for the hole shape
	onboarding: Onboarding,
	house: { level: number },
	museum: Museum,
	depot: Stash, -- offline yield, sold together with the backpack
	digger: { leftAt: number? }, -- server time the player left; nil while playing
	quests: QuestState,
	login: Login,
	passes: { [string]: boolean }, -- game pass key -> true while owned (verified by the server)
	boosters: BoosterState,
	stats: { blocksDug: number },
	backpack: {
		ores: { [string]: number },
		finds: { Find },
	},
}

export type Data = { [string]: any }
export type Migration = (data: Data) -> Data

-- Everything needed to create and check profiles, assembled from Config by the caller.
export type Rules = {
	version: number,
	startCoins: number,
	startDepth: number,
	levelCounts: { [string]: number }, -- upgrade id -> number of levels
	layerIds: { string },
	onboardingMaxStep: number,
	museumSlotsByHouseLevel: { number }, -- showcases per house level; its length is the highest house level
	loginChainLength: number,
}

-- Upper bound for layer seeds (fits a 32-bit signed integer).
local SEED_RANGE = 2147483646

local ProfileData = {}

local function isInteger(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge and value % 1 == 0
end

local function isNonNegativeInteger(value: any): boolean
	return isInteger(value) and value >= 0
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value do
		copy[key] = deepCopy(inner)
	end
	return copy
end

function ProfileData.currentVersion(migrations: { Migration }): number
	return #migrations + 1
end

function ProfileData.new(rules: Rules, rng: () -> number, now: number): Profile
	local upgradeLevels: { [string]: number } = {}
	for upgradeId in rules.levelCounts do
		upgradeLevels[upgradeId] = 1
	end

	local layerSeeds: { [string]: number } = {}
	for _, layerId in rules.layerIds do
		layerSeeds[layerId] = math.floor(rng() * SEED_RANGE) + 1
	end

	return {
		version = rules.version,
		createdAt = now,
		coins = rules.startCoins,
		nextFindId = 1,
		upgradeLevels = upgradeLevels,
		depth = rules.startDepth,
		layerSeeds = layerSeeds,
		onboarding = { step = 1, firstFindGiven = false },
		house = { level = 1 },
		depot = { ores = {}, finds = {} },
		digger = {},
		quests = { day = 0, ids = {}, progress = {}, claimed = {}, bonusClaimed = false },
		login = { lastDay = 0, streak = 0, claimed = true },
		passes = {},
		boosters = { expires = {}, receipts = {}, freeClaimedAt = 0 },
		museum = { displays = {}, incomeSince = now, admires = 0, week = 0, weekAdmires = 0 },
		stats = { blocksDug = 0 },
		backpack = { ores = {}, finds = {} },
	}
end

local function validateFind(find: any, label: string): (boolean, string?)
	if type(find) ~= "table" then
		return false, label .. " must be a table"
	end
	if not isInteger(find.id) or find.id < 1 then
		return false, label .. " needs a positive integer id"
	end
	if type(find.findId) ~= "string" or type(find.layerId) ~= "string" or type(find.rarityId) ~= "string" then
		return false, label .. " needs string findId, layerId and rarityId"
	end
	if find.mutationId ~= nil and type(find.mutationId) ~= "string" then
		return false, label .. " has a non-string mutationId"
	end
	if not isNonNegativeInteger(find.value) then
		return false, label .. " needs a non-negative integer value"
	end
	return true, nil
end

-- Checks a container of ore counts and finds (backpack, depot). `seenIds` and
-- `nextFindId` are shared over all containers, so find ids stay unique.
local function validateStash(
	stash: any,
	name: string,
	seenIds: { [number]: boolean },
	nextFindId: number
): (boolean, string?)
	if type(stash) ~= "table" then
		return false, name .. " must be a table"
	end
	if type(stash.ores) ~= "table" then
		return false, name .. ".ores must be a table"
	end
	for oreId, count in stash.ores do
		if type(oreId) ~= "string" or not isNonNegativeInteger(count) then
			return false, string.format("%s.ores.%s must be a non-negative integer", name, tostring(oreId))
		end
	end
	if type(stash.finds) ~= "table" then
		return false, name .. ".finds must be a table"
	end
	for index, find in stash.finds do
		local label = string.format("%s.finds[%d]", name, index)
		local ok, reason = validateFind(find, label)
		if not ok then
			return false, reason
		end
		if seenIds[find.id] then
			return false, string.format("%s has a duplicate id %d", label, find.id)
		end
		seenIds[find.id] = true
		if find.id >= nextFindId then
			return false, "nextFindId must be higher than every find id"
		end
	end
	return true, nil
end

-- Returns true when `profile` has the current format with sane values,
-- otherwise false and a reason (for logging).
function ProfileData.validate(profile: any, rules: Rules): (boolean, string?)
	if type(profile) ~= "table" then
		return false, "profile must be a table"
	end
	if profile.version ~= rules.version then
		return false, string.format("version is %s, expected %d", tostring(profile.version), rules.version)
	end
	if not isNonNegativeInteger(profile.createdAt) then
		return false, "createdAt must be a non-negative integer"
	end
	if not isNonNegativeInteger(profile.coins) then
		return false, "coins must be a non-negative integer"
	end
	if not (type(profile.depth) == "number" and profile.depth >= 0 and profile.depth < math.huge) then
		return false, "depth must be a finite non-negative number"
	end

	if type(profile.upgradeLevels) ~= "table" then
		return false, "upgradeLevels must be a table"
	end
	for upgradeId, levelCount in rules.levelCounts do
		local level = profile.upgradeLevels[upgradeId]
		if not isInteger(level) or level < 1 or level > levelCount then
			return false, string.format("upgradeLevels.%s must be an integer from 1 to %d", upgradeId, levelCount)
		end
	end

	if type(profile.layerSeeds) ~= "table" then
		return false, "layerSeeds must be a table"
	end
	for _, layerId in rules.layerIds do
		local seed = profile.layerSeeds[layerId]
		if not isInteger(seed) or seed < 1 then
			return false, string.format("layerSeeds.%s must be a positive integer", layerId)
		end
	end

	local onboarding = profile.onboarding
	if
		type(onboarding) ~= "table"
		or not isInteger(onboarding.step)
		or onboarding.step < 1
		or onboarding.step > rules.onboardingMaxStep
		or type(onboarding.firstFindGiven) ~= "boolean"
	then
		return false, "onboarding needs an integer step in range and a boolean firstFindGiven"
	end
	if type(profile.stats) ~= "table" or not isNonNegativeInteger(profile.stats.blocksDug) then
		return false, "stats.blocksDug must be a non-negative integer"
	end

	if not isInteger(profile.nextFindId) or profile.nextFindId < 1 then
		return false, "nextFindId must be a positive integer"
	end
	local seenIds: { [number]: boolean } = {}
	for _, name in { "backpack", "depot" } do
		local ok, reason = validateStash(profile[name], name, seenIds, profile.nextFindId)
		if not ok then
			return false, reason
		end
	end

	local house = profile.house
	if
		type(house) ~= "table"
		or not isInteger(house.level)
		or house.level < 1
		or house.level > #rules.museumSlotsByHouseLevel
	then
		return false, string.format("house.level must be an integer from 1 to %d", #rules.museumSlotsByHouseLevel)
	end

	local museum = profile.museum
	if type(museum) ~= "table" then
		return false, "museum must be a table"
	end
	for _, field in { "incomeSince", "admires", "week", "weekAdmires" } do
		if not isNonNegativeInteger(museum[field]) then
			return false, string.format("museum.%s must be a non-negative integer", field)
		end
	end
	if type(museum.displays) ~= "table" then
		return false, "museum.displays must be a table"
	end
	local slotCount = rules.museumSlotsByHouseLevel[house.level]
	local seenSlots: { [number]: boolean } = {}
	for index, display in museum.displays do
		if type(display) ~= "table" or not isInteger(display.slot) or display.slot < 1 or display.slot > slotCount then
			return false, string.format("museum.displays[%d] needs a slot from 1 to %d", index, slotCount)
		end
		if seenSlots[display.slot] then
			return false, string.format("museum.displays[%d] reuses slot %d", index, display.slot)
		end
		seenSlots[display.slot] = true
		local ok, reason = validateFind(display.find, string.format("museum.displays[%d].find", index))
		if not ok then
			return false, reason
		end
		if seenIds[display.find.id] then
			return false, string.format("museum.displays[%d] has a duplicate find id %d", index, display.find.id)
		end
		seenIds[display.find.id] = true
		if display.find.id >= profile.nextFindId then
			return false, "nextFindId must be higher than every find id"
		end
	end

	local digger = profile.digger
	if type(digger) ~= "table" or (digger.leftAt ~= nil and not isNonNegativeInteger(digger.leftAt)) then
		return false, "digger.leftAt must be a non-negative integer when set"
	end

	local quests = profile.quests
	if
		type(quests) ~= "table"
		or not isNonNegativeInteger(quests.day)
		or type(quests.ids) ~= "table"
		or type(quests.progress) ~= "table"
		or type(quests.claimed) ~= "table"
		or type(quests.bonusClaimed) ~= "boolean"
	then
		return false, "quests needs day, ids, progress, claimed and bonusClaimed"
	end
	for _, questId in quests.ids do
		if type(questId) ~= "string" then
			return false, "quests.ids must be strings"
		end
	end
	for questId, amount in quests.progress do
		if type(questId) ~= "string" or not isNonNegativeInteger(amount) then
			return false, "quests.progress needs non-negative integers per quest id"
		end
	end
	for questId, claimed in quests.claimed do
		if type(questId) ~= "string" or claimed ~= true then
			return false, "quests.claimed needs true per quest id"
		end
	end

	local login = profile.login
	if
		type(login) ~= "table"
		or not isNonNegativeInteger(login.lastDay)
		or not isNonNegativeInteger(login.streak)
		or login.streak > rules.loginChainLength
		or type(login.claimed) ~= "boolean"
	then
		return false, string.format("login needs lastDay, a streak from 0 to %d and claimed", rules.loginChainLength)
	end

	if type(profile.passes) ~= "table" then
		return false, "passes must be a table"
	end
	for passKey, owned in profile.passes do
		if type(passKey) ~= "string" or owned ~= true then
			return false, "passes needs true per pass key"
		end
	end

	local boosters = profile.boosters
	if type(boosters) ~= "table" or type(boosters.expires) ~= "table" or type(boosters.receipts) ~= "table" then
		return false, "boosters needs expires, receipts and freeClaimedAt"
	end
	if not isNonNegativeInteger(boosters.freeClaimedAt) then
		return false, "boosters.freeClaimedAt must be a non-negative integer"
	end
	for boosterId, expires in boosters.expires do
		if type(boosterId) ~= "string" or not isNonNegativeInteger(expires) then
			return false, "boosters.expires needs a non-negative integer per booster id"
		end
	end
	for index, purchaseId in boosters.receipts do
		if type(index) ~= "number" or type(purchaseId) ~= "string" or purchaseId == "" then
			return false, "boosters.receipts must be a list of non-empty strings"
		end
	end

	return true, nil
end

-- Upgrades stored data to the current version by applying the migrations in
-- order. The input is never modified. Returns the migrated data, or nil and a
-- reason when the data is unusable (missing/invalid version, newer than this
-- server knows, or a failing migration).
function ProfileData.migrate(data: any, migrations: { Migration }): (Data?, string?)
	if type(data) ~= "table" then
		return nil, "profile data must be a table"
	end

	local version = data.version
	if not isInteger(version) or version < 1 then
		return nil, "profile data has a missing or invalid version"
	end

	local current = ProfileData.currentVersion(migrations)
	if version > current then
		return nil, string.format("profile version %d is newer than the supported version %d", version, current)
	end

	local migrated: Data = deepCopy(data)
	for from = version, current - 1 do
		local ok, result = pcall(migrations[from], migrated)
		if not ok then
			return nil, string.format("migration from version %d failed: %s", from, tostring(result))
		end
		if type(result) ~= "table" then
			return nil, string.format("migration from version %d did not return a table", from)
		end
		migrated = result
		migrated.version = from + 1
	end
	return migrated, nil
end

return ProfileData
