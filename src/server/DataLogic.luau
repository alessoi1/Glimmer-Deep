--!strict
-- Pure decisions of the DataService: profile keys and what to do with the data
-- ProfileStore returned. No Roblox services, no logging; the DataService logs
-- the outcome. Testable without Studio.

local ProfileData = require("./ProfileData")

export type Status = "new" | "loaded" | "migrated" | "rejected"

-- `data` is set for every status except "rejected". A rejected profile must
-- stay untouched in the DataStore (never overwrite data we cannot read).
export type Outcome = {
	status: Status,
	data: ProfileData.Data?,
	reason: string?,
}

local KEY_PREFIX = "Player_"

local DataLogic = {}

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

local function rejected(reason: string?): Outcome
	return { status = "rejected", data = nil, reason = reason }
end

-- DataStore key for a player, or nil when the user id is not a positive integer.
function DataLogic.profileKey(userId: number): string?
	if type(userId) ~= "number" or userId ~= userId or userId < 1 or userId == math.huge or userId % 1 ~= 0 then
		return nil
	end
	return KEY_PREFIX .. string.format("%d", userId)
end

-- Decides what to do with the stored data of a player:
--   empty table -> "new" profile, current format
--   current or older valid profile -> "loaded" / "migrated"
--   anything else -> "rejected" with a reason (corrupt, newer version, failing migration)
-- The input is never modified.
function DataLogic.prepare(
	raw: any,
	rules: ProfileData.Rules,
	migrations: { ProfileData.Migration },
	rng: () -> number,
	now: number
): Outcome
	if type(raw) ~= "table" then
		return rejected("stored data must be a table")
	end

	if next(raw) == nil then
		local profile = ProfileData.new(rules, rng, now)
		local ok, reason = ProfileData.validate(profile, rules)
		if not ok then
			return rejected("new profile is invalid: " .. tostring(reason))
		end
		return { status = "new", data = profile :: any, reason = nil }
	end

	local migrated, migrateReason = ProfileData.migrate(raw, migrations)
	if migrated == nil then
		return rejected(migrateReason)
	end

	local ok, reason = ProfileData.validate(migrated, rules)
	if not ok then
		return rejected(reason)
	end

	local status: Status = if raw.version == rules.version then "loaded" else "migrated"
	return { status = status, data = migrated, reason = nil }
end

-- Replaces everything in `target` with a copy of `source`, keeping the same
-- table (ProfileStore holds on to Profile.Data).
function DataLogic.replaceContents(target: { [any]: any }, source: { [any]: any })
	for key in target do
		target[key] = nil
	end
	for key, value in source do
		target[key] = deepCopy(value)
	end
end

return DataLogic
