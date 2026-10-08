--!strict
-- Pure text building for the quest UI: turns quests, the login chain and results
-- into German player texts using Strings. No Roblox services; the client
-- displays what this returns.

local SellMessages = require("./SellMessages")

export type Strings = {
	quests: {
		text: { [string]: string }, -- quest id -> format with the target
		progress: string,
		loginLine: string,
		bonusLine: string,
		resetIn: string,
		durationHours: string,
		durationMinutes: string,
		paid: string,
		notDone: string,
		alreadyClaimed: string,
		completed: string,
		unknown: string,
	},
}

-- Structural subsets of Quests.QuestView and LoginChain.View.
export type QuestView = {
	id: string,
	target: number,
	progress: number,
}
export type LoginView = { streak: number, reward: number, chainLength: number }

local SECONDS_PER_MINUTE = 60
local MINUTES_PER_HOUR = 60

local QuestMessages = {}

-- The quest text with its target, for example "Verkaufe 3-mal".
function QuestMessages.questTitle(strings: Strings, quest: QuestView): string
	local format = strings.quests.text[quest.id]
	if format == nil then
		return quest.id
	end
	return string.format(format, quest.target)
end

-- The quest text followed by the progress, for example "Verkaufe 3-mal (1/3)".
function QuestMessages.describeQuest(strings: Strings, quest: QuestView): string
	return string.format(
		"%s (%s)",
		QuestMessages.questTitle(strings, quest),
		string.format(strings.quests.progress, quest.progress, quest.target)
	)
end

function QuestMessages.describeLogin(strings: Strings, login: LoginView): string
	return string.format(
		strings.quests.loginLine,
		login.streak,
		login.chainLength,
		SellMessages.formatCoins(login.reward)
	)
end

function QuestMessages.describeBonus(strings: Strings, bonus: number): string
	return string.format(strings.quests.bonusLine, SellMessages.formatCoins(bonus))
end

-- "Neue Aufgaben in 5 Std 12 Min".
function QuestMessages.describeReset(strings: Strings, seconds: number): string
	local totalMinutes = math.floor(seconds / SECONDS_PER_MINUTE)
	local hours = totalMinutes // MINUTES_PER_HOUR
	local minutes = totalMinutes % MINUTES_PER_HOUR
	local duration = if hours > 0
		then string.format(strings.quests.durationHours, hours, minutes)
		else string.format(strings.quests.durationMinutes, minutes)
	return string.format(strings.quests.resetIn, duration)
end

-- Message after claiming; unknown reasons give a neutral text.
function QuestMessages.describeResult(strings: Strings, ok: boolean, coins: number, reason: string?): string
	if ok then
		return string.format(strings.quests.paid, SellMessages.formatCoins(coins))
	elseif reason == "not_done" then
		return strings.quests.notDone
	elseif reason == "already_claimed" then
		return strings.quests.alreadyClaimed
	end
	return strings.quests.unknown
end

function QuestMessages.describeCompleted(strings: Strings, quest: QuestView): string
	return string.format(strings.quests.completed, QuestMessages.questTitle(strings, quest))
end

return QuestMessages
