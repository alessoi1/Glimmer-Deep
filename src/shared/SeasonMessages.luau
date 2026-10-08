--!strict
-- Pure text building for the season panel and the weekly event line. Texts
-- stay neutral, never pushy. No Roblox services; the client displays what this
-- returns.

local SellMessages = require("./SellMessages")

export type Strings = {
	shop: { boosters: { booster: { [string]: { name: string } } } },
	house: { item: { [string]: string } },
	events: { [string]: { name: string, description: string } },
	season: {
		eventLine: string,
		mutationLine: string,
		durationDays: string,
		durationHours: string,
		durationMinutes: string,
		seasonLine: string,
		levelLine: string,
		xpLine: string,
		xpMax: string,
		resetsIn: string,
		rewardCoins: string,
		rewardEgg: string,
		rewardBooster: string,
		rewardDecor: string,
		claim: string,
		claimed: string,
		locked: string,
		premiumLocked: string,
		paid: string,
		levelUp: string,
		notReached: string,
		noPremium: string,
		alreadyClaimed: string,
		unknown: string,
	},
	mutation: { [string]: string },
}

-- Structural subsets of the reward and event views.
export type Reward = { kind: string, amount: number?, id: string? }
export type EventView = { id: string, secondsLeft: number, mutationId: string?, mutationFactor: number? }

local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 3600
local SECONDS_PER_DAY = 86400

local SeasonMessages = {}

function SeasonMessages.eventName(strings: Strings, id: string): string
	local entry = strings.events[id]
	return if entry ~= nil then entry.name else id
end

function SeasonMessages.eventDescription(strings: Strings, id: string): string
	local entry = strings.events[id]
	return if entry ~= nil then entry.description else ""
end

-- "3 Tg 4 Std", "5 Std 12 Min" or "7 Min", rounded down (up to one minute).
function SeasonMessages.durationText(strings: Strings, seconds: number): string
	local days = seconds // SECONDS_PER_DAY
	local hours = (seconds % SECONDS_PER_DAY) // SECONDS_PER_HOUR
	local minutes = math.max(1, (seconds % SECONDS_PER_HOUR) // SECONDS_PER_MINUTE)
	if days > 0 then
		return string.format(strings.season.durationDays, days, hours)
	elseif hours > 0 then
		return string.format(strings.season.durationHours, hours, (seconds % SECONDS_PER_HOUR) // SECONDS_PER_MINUTE)
	end
	return string.format(strings.season.durationMinutes, minutes)
end

-- "Event: Glühwoche (endet in 3 Tg 4 Std)".
function SeasonMessages.eventLine(strings: Strings, event: EventView): string
	return string.format(
		strings.season.eventLine,
		SeasonMessages.eventName(strings, event.id),
		SeasonMessages.durationText(strings, event.secondsLeft)
	)
end

-- "Glühend 4x häufiger" for events that boost a mutation; empty otherwise.
function SeasonMessages.mutationLine(strings: Strings, event: EventView): string
	if event.mutationId == nil or event.mutationFactor == nil then
		return ""
	end
	return string.format(
		strings.season.mutationLine,
		strings.mutation[event.mutationId] or event.mutationId,
		event.mutationFactor
	)
end

function SeasonMessages.seasonLine(strings: Strings, season: number, secondsLeft: number): string
	return string.format(strings.season.seasonLine, season, SeasonMessages.durationText(strings, secondsLeft))
end

function SeasonMessages.levelText(strings: Strings, level: number, maxLevel: number): string
	return string.format(strings.season.levelLine, level, maxLevel)
end

-- "250/700 Punkte" or the maximum text.
function SeasonMessages.xpText(strings: Strings, into: number, forNext: number?): string
	if forNext == nil then
		return strings.season.xpMax
	end
	return string.format(strings.season.xpLine, into, forNext)
end

-- "300 Münzen", "2 Eier", "Tempo-Booster x1" or "Deko: Laterne".
function SeasonMessages.rewardText(strings: Strings, reward: Reward): string
	local amount = reward.amount or 1
	if reward.kind == "coins" then
		return string.format(strings.season.rewardCoins, SellMessages.formatCoins(amount))
	elseif reward.kind == "egg" then
		return string.format(strings.season.rewardEgg, amount)
	elseif reward.kind == "booster" and reward.id ~= nil then
		local entry = strings.shop.boosters.booster[reward.id]
		return string.format(strings.season.rewardBooster, if entry ~= nil then entry.name else reward.id, amount)
	elseif reward.kind == "decor" and reward.id ~= nil then
		return string.format(strings.season.rewardDecor, strings.house.item[reward.id] or reward.id)
	end
	return ""
end

-- Button text of one reward.
function SeasonMessages.claimText(strings: Strings, reached: boolean, claimed: boolean, locked: boolean): string
	if claimed then
		return strings.season.claimed
	elseif locked then
		return strings.season.premiumLocked
	elseif not reached then
		return strings.season.locked
	end
	return strings.season.claim
end

function SeasonMessages.levelUpText(strings: Strings, level: number): string
	return string.format(strings.season.levelUp, level)
end

-- Message after a claim; unknown reasons give a neutral text.
function SeasonMessages.describeResult(strings: Strings, ok: boolean, reason: string?): string
	if ok then
		return strings.season.paid
	elseif reason == "locked_level" then
		return strings.season.notReached
	elseif reason == "no_premium" then
		return strings.season.noPremium
	elseif reason == "already_claimed" then
		return strings.season.alreadyClaimed
	end
	return strings.season.unknown
end

return SeasonMessages
