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

export type Onboarding = { step: number, firstFindGiven: boolean }

export type Profile = {
	version: number,
	createdAt: number, -- server time (os.time) when the profile was created
	coins: number,
	nextFindId: number, -- next free find id
	upgradeLevels: { [string]: number }, -- upgrade id -> level, starting at 1
	depth: number, -- meters
	layerSeeds: { [string]: number }, -- layer id -> random seed for the hole shape
	onboarding: Onboarding,
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
		stats = { blocksDug = 0 },
		backpack = { ores = {}, finds = {} },
	}
end

local function validateFind(find: any, index: number): (boolean, string?)
	local label = string.format("backpack.finds[%d]", index)
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

	if type(profile.backpack) ~= "table" then
		return false, "backpack must be a table"
	end
	if type(profile.backpack.ores) ~= "table" then
		return false, "backpack.ores must be a table"
	end
	for oreId, count in profile.backpack.ores do
		if type(oreId) ~= "string" or not isNonNegativeInteger(count) then
			return false, string.format("backpack.ores.%s must be a non-negative integer", tostring(oreId))
		end
	end
	if type(profile.backpack.finds) ~= "table" then
		return false, "backpack.finds must be a table"
	end
	if not isInteger(profile.nextFindId) or profile.nextFindId < 1 then
		return false, "nextFindId must be a positive integer"
	end
	local seenIds: { [number]: boolean } = {}
	for index, find in profile.backpack.finds do
		local ok, reason = validateFind(find, index)
		if not ok then
			return false, reason
		end
		if seenIds[find.id] then
			return false, string.format("backpack.finds[%d] has a duplicate id %d", index, find.id)
		end
		seenIds[find.id] = true
		if find.id >= profile.nextFindId then
			return false, "nextFindId must be higher than every find id"
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
