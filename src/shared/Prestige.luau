--!strict
-- Pure prestige logic for the rebirth "Neue Bohrung": when a rebirth is
-- possible, the prestige points it gives, buying permanent bonuses with those
-- points and the Modifiers part the bonuses make. The reset of the profile
-- itself is in the server (RebirthReset). No Roblox services.

local Modifiers = require("./Modifiers")

export type UpgradeDef = {
	costs: { number },
	perLevel: Modifiers.Part,
}

export type Config = {
	requiredDepth: number,
	points: { base: number, perRebirth: number },
	actionCooldown: number,
	promptDistance: number,
	useDistance: number,
	order: { string },
	upgrades: { [string]: UpgradeDef },
}

-- What the profile stores.
export type State = {
	points: number, -- unspent prestige points
	rebirths: number, -- how many rebirths were done
	levels: { [string]: number }, -- bonus id -> bought levels
}

export type UpgradeView = {
	id: string,
	level: number,
	maxLevel: number,
	nextCost: number?, -- nil at the highest level
	affordable: boolean,
	perLevel: Modifiers.Part,
}

export type View = {
	rebirths: number,
	points: number,
	depth: number,
	requiredDepth: number,
	canRebirth: boolean,
	pointsForNext: number, -- what the next rebirth would give
	upgrades: { UpgradeView },
}

export type Result = { ok: boolean, reason: string? }

local Prestige = {}

local function isPositiveInteger(value: any): boolean
	return type(value) == "number" and value >= 1 and value < math.huge and value % 1 == 0
end

-- Returns true when the config is usable, otherwise false and a reason.
function Prestige.validateConfig(config: Config): (boolean, string?)
	if not isPositiveInteger(config.requiredDepth) then
		return false, "requiredDepth must be a positive integer"
	end
	if not isPositiveInteger(config.points.base) then
		return false, "points.base must be a positive integer"
	end
	if
		type(config.points.perRebirth) ~= "number"
		or config.points.perRebirth < 0
		or config.points.perRebirth % 1 ~= 0
	then
		return false, "points.perRebirth must be a non-negative integer"
	end
	if not (type(config.actionCooldown) == "number" and config.actionCooldown >= 0) then
		return false, "actionCooldown must be a non-negative number"
	end
	local inOrder: { [string]: boolean } = {}
	for _, id in config.order do
		if config.upgrades[id] == nil then
			return false, "order names the unknown bonus " .. id
		end
		inOrder[id] = true
	end
	for id, def in config.upgrades do
		if not inOrder[id] then
			return false, id .. " is missing from the order"
		end
		if #def.costs == 0 then
			return false, id .. " needs at least one level"
		end
		local previous = 0
		for level, cost in def.costs do
			if not isPositiveInteger(cost) then
				return false, string.format("%s level %d needs a positive integer cost", id, level)
			end
			if cost < previous then
				return false, id .. " costs must not get cheaper"
			end
			previous = cost
		end
		local fields = 0
		for field, value in def.perLevel do
			fields += 1
			if table.find(Modifiers.knownFields, field) == nil then
				return false, string.format("%s has the unknown effect %s", id, tostring(field))
			end
			if type(value) ~= "number" or value <= 0 or value == math.huge then
				return false, string.format("%s needs a positive %s", id, tostring(field))
			end
		end
		if fields == 0 then
			return false, id .. " needs an effect"
		end
	end
	return true, nil
end

function Prestige.newState(): State
	return { points = 0, rebirths = 0, levels = {} }
end

function Prestige.canRebirth(depth: number, config: Config): boolean
	return depth >= config.requiredDepth
end

-- Points the next rebirth gives for a player who did `rebirths` before.
function Prestige.pointsFor(rebirths: number, config: Config): number
	return config.points.base + rebirths * config.points.perRebirth
end

-- Counts a finished rebirth and gives its points. Returns the points given.
-- The profile reset is done by the caller; this only changes the prestige state.
function Prestige.complete(state: State, config: Config): number
	local given = Prestige.pointsFor(state.rebirths, config)
	state.points += given
	state.rebirths += 1
	return given
end

-- Buys the next level of a bonus. Fails with "unknown_upgrade", "max_level" or
-- "not_enough_points".
function Prestige.buy(state: State, config: Config, id: string): Result
	local def = config.upgrades[id]
	if def == nil then
		return { ok = false, reason = "unknown_upgrade" }
	end
	local level = state.levels[id] or 0
	local cost = def.costs[level + 1]
	if cost == nil then
		return { ok = false, reason = "max_level" }
	end
	if state.points < cost then
		return { ok = false, reason = "not_enough_points" }
	end
	state.points -= cost
	state.levels[id] = level + 1
	return { ok = true, reason = nil }
end

-- The combined bonus of all bought levels; nil without any.
function Prestige.effectOf(state: State, config: Config): Modifiers.Part?
	local total: { [string]: number } = {}
	local any = false
	for id, def in config.upgrades do
		local level = math.min(state.levels[id] or 0, #def.costs)
		if level > 0 then
			any = true
			for field, value in def.perLevel do
				total[field] = (total[field] or 0) + value * level
			end
		end
	end
	if not any then
		return nil
	end
	return total :: any
end

function Prestige.view(state: State, depth: number, config: Config): View
	local upgrades: { UpgradeView } = {}
	for _, id in config.order do
		local def = config.upgrades[id]
		local level = math.min(state.levels[id] or 0, #def.costs)
		local nextCost: number? = def.costs[level + 1]
		table.insert(upgrades, {
			id = id,
			level = level,
			maxLevel = #def.costs,
			nextCost = nextCost,
			affordable = nextCost ~= nil and state.points >= nextCost,
			perLevel = def.perLevel,
		})
	end
	return {
		rebirths = state.rebirths,
		points = state.points,
		depth = depth,
		requiredDepth = config.requiredDepth,
		canRebirth = Prestige.canRebirth(depth, config),
		pointsForNext = Prestige.pointsFor(state.rebirths, config),
		upgrades = upgrades,
	}
end

return Prestige
