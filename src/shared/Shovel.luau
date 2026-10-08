--!strict
-- Pure shovel logic: level stats and the server-side dig cooldown check.
-- No Roblox services; times are passed in (server clock only).

export type LevelDef = { id: string, price: number, digCooldown: number, rangeBonus: number? }

export type Config = {
	cooldownTolerance: number,
	levels: { LevelDef },
}

local Shovel = {}

-- Level definition for a level number, clamped to the configured range.
function Shovel.getLevel(levels: { LevelDef }, level: number): LevelDef
	local index = 1
	if level == level then
		index = math.clamp(math.floor(level), 1, #levels)
	end
	return levels[index]
end

-- Seconds between dig actions, divided by an optional speed multiplier >= 1
-- (for example the Tempo-Booster).
function Shovel.getDigCooldown(levels: { LevelDef }, level: number, speedMultiplier: number?): number
	local multiplier = speedMultiplier
	if multiplier == nil or multiplier ~= multiplier or multiplier < 1 then
		multiplier = 1
	end
	return Shovel.getLevel(levels, level).digCooldown / multiplier
end

-- True when a dig at `now` respects the cooldown since `lastDigAt` (nil for the
-- first dig). Accepts a dig after `tolerance` (0-1) of the cooldown to absorb
-- network jitter. A clock that went backwards or an invalid time is rejected.
function Shovel.isReady(lastDigAt: number?, now: number, cooldown: number, tolerance: number): boolean
	if now ~= now then
		return false
	end
	if lastDigAt == nil then
		return true
	end
	return now - lastDigAt >= cooldown * tolerance and now > lastDigAt
end

-- Returns true when the config is usable, otherwise false and a reason.
function Shovel.validateConfig(config: Config): (boolean, string?)
	if not (config.cooldownTolerance > 0 and config.cooldownTolerance <= 1) then
		return false, "cooldownTolerance must be in (0, 1]"
	end
	if #config.levels == 0 then
		return false, "no shovel levels configured"
	end
	if config.levels[1].price ~= 0 then
		return false, "shovel level 1 must be free"
	end

	local seen: { [string]: boolean } = {}
	local previousPrice = -1
	local previousCooldown = math.huge
	for index, level in config.levels do
		if seen[level.id] then
			return false, "duplicate shovel id: " .. level.id
		end
		seen[level.id] = true

		if level.price % 1 ~= 0 or level.price <= previousPrice then
			return false, string.format("shovel level %d needs a higher integer price than level %d", index, index - 1)
		end
		previousPrice = level.price

		if not (level.digCooldown > 0) or level.digCooldown >= previousCooldown then
			return false, string.format("shovel level %d must dig faster than level %d", index, index - 1)
		end
		previousCooldown = level.digCooldown
	end
	return true, nil
end

return Shovel
