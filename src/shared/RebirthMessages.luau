--!strict
-- Pure text building for the rebirth panel. No Roblox services; the client
-- displays what this returns.

export type Strings = {
	rebirth: {
		upgrade: { [string]: string },
		effectCoins: string,
		effectTempo: string,
		effectLuck: string,
		effectOffline: string,
		countLine: string,
		pointsLine: string,
		requirement: string,
		ready: string,
		givesLine: string,
		levelLine: string,
		costLine: string,
		maxLevel: string,
		done: string,
		bought: string,
		tooShallow: string,
		notEnoughPoints: string,
		unknown: string,
	},
}

-- Structural subset of Modifiers.Part.
export type Effect = { coinBonus: number?, tempoBonus: number?, luckBonus: number?, offlineBonus: number? }

local PERCENT = 100

local RebirthMessages = {}

function RebirthMessages.upgradeName(strings: Strings, id: string): string
	return strings.rebirth.upgrade[id] or id
end

-- "Münzen +10 %" for the gain of one level; several effects joined with ", ".
function RebirthMessages.effectText(strings: Strings, effect: Effect): string
	local parts = {}
	local function add(format: string, value: number?)
		if value ~= nil and value > 0 then
			table.insert(parts, string.format(format, math.floor(value * PERCENT + 0.5)))
		end
	end
	add(strings.rebirth.effectCoins, effect.coinBonus)
	add(strings.rebirth.effectTempo, effect.tempoBonus)
	add(strings.rebirth.effectLuck, effect.luckBonus)
	add(strings.rebirth.effectOffline, effect.offlineBonus)
	return table.concat(parts, ", ")
end

function RebirthMessages.countText(strings: Strings, rebirths: number): string
	return string.format(strings.rebirth.countLine, rebirths)
end

function RebirthMessages.pointsText(strings: Strings, points: number): string
	return string.format(strings.rebirth.pointsLine, points)
end

-- "Erreiche 300 m (jetzt 120 m)" or the ready text.
function RebirthMessages.requirementText(strings: Strings, depth: number, requiredDepth: number): string
	if depth >= requiredDepth then
		return strings.rebirth.ready
	end
	return string.format(strings.rebirth.requirement, requiredDepth, math.floor(depth))
end

function RebirthMessages.givesText(strings: Strings, points: number): string
	return string.format(strings.rebirth.givesLine, points)
end

function RebirthMessages.levelText(strings: Strings, level: number, maxLevel: number): string
	return string.format(strings.rebirth.levelLine, level, maxLevel)
end

-- "Kosten: 3 Punkte" or the maximum text.
function RebirthMessages.costText(strings: Strings, nextCost: number?): string
	if nextCost == nil then
		return strings.rebirth.maxLevel
	end
	return string.format(strings.rebirth.costLine, nextCost)
end

-- Message after a rebirth action; unknown reasons give a neutral text.
function RebirthMessages.describeResult(strings: Strings, ok: boolean, kind: string?, reason: string?): string
	if ok then
		if kind == "rebirth" then
			return strings.rebirth.done
		end
		return strings.rebirth.bought
	elseif reason == "too_shallow" then
		return strings.rebirth.tooShallow
	elseif reason == "not_enough_points" then
		return strings.rebirth.notEnoughPoints
	end
	return strings.rebirth.unknown
end

return RebirthMessages
