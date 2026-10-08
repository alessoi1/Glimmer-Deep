--!strict
-- Pure season logic: which season runs, season points and levels, claiming the
-- free and premium rewards once, and paying a reward into the profile. All
-- times are server times passed in by the caller. No Roblox services.

local Boosters = require("./Boosters")
local Calendar = require("./Calendar")
local Events = require("./Events")

export type Reward = {
	kind: string, -- "coins" | "egg" | "booster" | "decor"
	amount: number?,
	id: string?,
}

export type Config = {
	seasonWeeks: number,
	passKey: string,
	xp: { [string]: number },
	levelXp: { number },
	free: { Reward },
	premium: { Reward },
}

-- What the profile stores.
export type State = {
	id: number, -- the season the progress belongs to
	xp: number,
	claimedFree: { number }, -- levels whose free reward was taken
	claimedPremium: { number },
}

export type LevelView = {
	level: number,
	needed: number, -- points needed for this level alone
	reached: boolean,
	free: Reward,
	premium: Reward,
	freeClaimed: boolean,
	premiumClaimed: boolean,
	freeReady: boolean,
	premiumReady: boolean, -- reached, not claimed and the premium track is unlocked
}

export type View = {
	season: number,
	secondsLeft: number,
	xp: number,
	level: number, -- levels completed
	maxLevel: number,
	xpIntoLevel: number, -- points collected towards the next level
	xpForNext: number?, -- points the next level needs; nil at the highest level
	premium: boolean, -- the premium track is unlocked
	levels: { LevelView },
}

-- The part of a profile that rewards change.
export type Subject = {
	coins: number,
	pets: { eggs: number },
	boosters: Boosters.State,
	house: { decor: { owned: { [string]: boolean } } },
}

-- References into other configs, for validation and payout.
export type Refs = {
	boosters: Boosters.Config,
	decorPrices: { [string]: number }, -- decoration id -> coin price
}

-- What the server sends to the season panel.
export type Snapshot = {
	season: View,
	event: Events.Info,
}

export type ClaimResult = { ok: boolean, reason: string?, reward: Reward? }

local Season = {}

local function isPositiveInteger(value: any): boolean
	return type(value) == "number" and value >= 1 and value < math.huge and value % 1 == 0
end

local function validateReward(reward: Reward, label: string, refs: Refs): (boolean, string?)
	if reward.kind == "coins" or reward.kind == "egg" then
		if not isPositiveInteger(reward.amount) then
			return false, label .. " needs a positive integer amount"
		end
	elseif reward.kind == "booster" then
		if not isPositiveInteger(reward.amount) then
			return false, label .. " needs a positive integer amount"
		end
		if reward.id == nil or refs.boosters.boosters[reward.id] == nil then
			return false, label .. " names an unknown booster"
		end
	elseif reward.kind == "decor" then
		if reward.id == nil or refs.decorPrices[reward.id] == nil then
			return false, label .. " names an unknown decoration"
		end
	else
		return false, label .. " has the unknown kind " .. tostring(reward.kind)
	end
	return true, nil
end

-- Returns true when the config is usable, otherwise false and a reason.
function Season.validateConfig(config: Config, refs: Refs): (boolean, string?)
	if not isPositiveInteger(config.seasonWeeks) then
		return false, "seasonWeeks must be a positive integer"
	end
	if type(config.passKey) ~= "string" or config.passKey == "" then
		return false, "passKey must be a name"
	end
	if #config.levelXp == 0 then
		return false, "levelXp is empty"
	end
	for level, needed in config.levelXp do
		if not isPositiveInteger(needed) then
			return false, string.format("level %d needs positive integer points", level)
		end
	end
	for name, amount in config.xp do
		if type(name) ~= "string" or not isPositiveInteger(amount) then
			return false, "xp needs a positive integer per event name"
		end
	end
	if #config.free ~= #config.levelXp or #config.premium ~= #config.levelXp then
		return false, "free and premium need one reward per level"
	end
	for level = 1, #config.levelXp do
		local ok, reason = validateReward(config.free[level], "free reward " .. level, refs)
		if not ok then
			return false, reason
		end
		ok, reason = validateReward(config.premium[level], "premium reward " .. level, refs)
		if not ok then
			return false, reason
		end
	end
	return true, nil
end

function Season.newState(): State
	return { id = 0, xp = 0, claimedFree = {}, claimedPremium = {} }
end

-- The season that runs at server time `now`.
function Season.seasonOf(now: number, config: Config): number
	return Calendar.weekOf(now) // config.seasonWeeks
end

function Season.secondsLeft(now: number, config: Config): number
	local endWeek = (Season.seasonOf(now, config) + 1) * config.seasonWeeks
	return endWeek * Calendar.secondsPerWeek - now
end

-- Starts the progress again when a new season began. Returns true when it did.
function Season.sync(state: State, now: number, config: Config): boolean
	local current = Season.seasonOf(now, config)
	if state.id == current then
		return false
	end
	state.id = current
	state.xp = 0
	state.claimedFree = {}
	state.claimedPremium = {}
	return true
end

local function totalXp(config: Config): number
	local total = 0
	for _, needed in config.levelXp do
		total += needed
	end
	return total
end

-- Levels completed with `xp` points.
function Season.levelOf(xp: number, config: Config): number
	local level = 0
	local remaining = xp
	for _, needed in config.levelXp do
		if remaining < needed then
			break
		end
		remaining -= needed
		level += 1
	end
	return level
end

-- Season points for a game event, 0 for events that give none.
function Season.xpFor(event: string, amount: number, config: Config): number
	local per = config.xp[event]
	if per == nil or amount ~= amount or amount <= 0 then
		return 0
	end
	return per * math.floor(amount)
end

-- Adds points (after syncing the season). Points stop at the highest level.
-- Returns the levels gained.
function Season.addXp(state: State, config: Config, amount: number, now: number): number
	Season.sync(state, now, config)
	if amount <= 0 then
		return 0
	end
	local before = Season.levelOf(state.xp, config)
	state.xp = math.min(state.xp + math.floor(amount), totalXp(config))
	return Season.levelOf(state.xp, config) - before
end

-- Takes the reward of a level once. track is "free" or "premium". Fails with
-- "bad_input", "locked_level", "no_premium" or "already_claimed". Does not pay
-- the reward; the caller does that with Season.pay.
function Season.claim(
	state: State,
	config: Config,
	track: string,
	level: number,
	hasPremium: boolean,
	now: number
): ClaimResult
	Season.sync(state, now, config)
	if (track ~= "free" and track ~= "premium") or type(level) ~= "number" or level % 1 ~= 0 then
		return { ok = false, reason = "bad_input" }
	end
	if level < 1 or level > #config.levelXp then
		return { ok = false, reason = "bad_input" }
	end
	if level > Season.levelOf(state.xp, config) then
		return { ok = false, reason = "locked_level" }
	end
	if track == "premium" and not hasPremium then
		return { ok = false, reason = "no_premium" }
	end
	local claimed = if track == "free" then state.claimedFree else state.claimedPremium
	if table.find(claimed, level) ~= nil then
		return { ok = false, reason = "already_claimed" }
	end
	table.insert(claimed, level)
	table.sort(claimed)
	local reward = if track == "free" then config.free[level] else config.premium[level]
	return { ok = true, reason = nil, reward = reward }
end

-- Pays a reward into the profile. Returns a short description of what was paid:
-- { coins = n } for coins (also in place of a decoration the player owns).
function Season.pay(subject: Subject, reward: Reward, refs: Refs, now: number): { coins: number?, eggs: number? }
	if reward.kind == "coins" then
		local amount = reward.amount or 0
		subject.coins += amount
		return { coins = amount }
	elseif reward.kind == "egg" then
		local amount = reward.amount or 0
		subject.pets.eggs += amount
		return { eggs = amount }
	elseif reward.kind == "booster" and reward.id ~= nil then
		for _ = 1, reward.amount or 1 do
			Boosters.grant(subject.boosters, refs.boosters, reward.id, now)
		end
		return {}
	elseif reward.kind == "decor" and reward.id ~= nil then
		local owned = subject.house.decor.owned
		if owned[reward.id] == true then
			local price = refs.decorPrices[reward.id] or 0
			subject.coins += price
			return { coins = price }
		end
		owned[reward.id] = true
		return {}
	end
	return {}
end

function Season.view(state: State, config: Config, hasPremium: boolean, now: number): View
	-- Reads a copy, so showing the panel never changes the stored state.
	local current = Season.seasonOf(now, config)
	local xp = if state.id == current then state.xp else 0
	local claimedFree = if state.id == current then state.claimedFree else {}
	local claimedPremium = if state.id == current then state.claimedPremium else {}
	local level = Season.levelOf(xp, config)

	local levels: { LevelView } = {}
	for index, needed in config.levelXp do
		local reached = index <= level
		local freeClaimed = table.find(claimedFree, index) ~= nil
		local premiumClaimed = table.find(claimedPremium, index) ~= nil
		table.insert(levels, {
			level = index,
			needed = needed,
			reached = reached,
			free = config.free[index],
			premium = config.premium[index],
			freeClaimed = freeClaimed,
			premiumClaimed = premiumClaimed,
			freeReady = reached and not freeClaimed,
			premiumReady = reached and not premiumClaimed and hasPremium,
		})
	end
	local into = xp
	for index = 1, level do
		into -= config.levelXp[index]
	end
	return {
		season = current,
		secondsLeft = Season.secondsLeft(now, config),
		xp = xp,
		level = level,
		maxLevel = #config.levelXp,
		xpIntoLevel = into,
		xpForNext = config.levelXp[level + 1],
		premium = hasPremium,
		levels = levels,
	}
end

return Season
