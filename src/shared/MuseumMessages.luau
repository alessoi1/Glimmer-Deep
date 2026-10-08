--!strict
-- Pure text building for the museum UI: turns ids and results into German player
-- texts using Strings. No Roblox services; the client displays what this returns.

local SellMessages = require("./SellMessages")

export type Texts = {
	find: string,
	findMutated: string,
	setProgress: string,
	setComplete: string,
	incomeReady: string,
	displayed: string,
	removed: string,
	collected: string,
	admired: string,
	admiredBy: string,
	nothingToCollect: string,
	backpackFull: string,
	slotTaken: string,
	noSuchFind: string,
	alreadyAdmired: string,
	emptyMuseum: string,
	tooFar: string,
	unknown: string,
}

export type Strings = {
	find: { [string]: string },
	rarity: { [string]: string },
	mutation: { [string]: string },
	layer: { [string]: string },
	museum: Texts,
}

-- Structural subsets of MuseumLogic.Find and MuseumLogic.SetProgress.
export type Find = { findId: string, rarityId: string, mutationId: string?, layerId: string }
export type SetProgress = { layerId: string, have: number, need: number, complete: boolean }

local MuseumMessages = {}

local function nameOf(names: { [string]: string }, id: string): string
	return names[id] or id
end

-- "Fossil (Episch)", or "Golden Fossil (Episch)" with a mutation.
function MuseumMessages.describeFind(strings: Strings, find: Find): string
	local name = nameOf(strings.find, find.findId)
	local rarity = nameOf(strings.rarity, find.rarityId)
	if find.mutationId ~= nil then
		return string.format(strings.museum.findMutated, nameOf(strings.mutation, find.mutationId), name, rarity)
	end
	return string.format(strings.museum.find, name, rarity)
end

function MuseumMessages.describeSet(strings: Strings, progress: SetProgress): string
	local layer = nameOf(strings.layer, progress.layerId)
	if progress.complete then
		return string.format(strings.museum.setComplete, layer)
	end
	return string.format(strings.museum.setProgress, layer, progress.have, progress.need)
end

function MuseumMessages.describeIncome(strings: Strings, pending: number, perHour: number): string
	return string.format(
		strings.museum.incomeReady,
		SellMessages.formatCoins(pending),
		SellMessages.formatCoins(perHour)
	)
end

-- Message after a museum action. `kind` names the success ("displayed",
-- "removed", "collected", "admired", "admiredBy"); `reason` the failure;
-- `name` is the other player's name for the admire messages.
function MuseumMessages.describeResult(
	strings: Strings,
	ok: boolean,
	kind: string?,
	reason: string?,
	coins: number,
	name: string?
): string
	local texts = strings.museum
	if ok then
		if kind == "displayed" then
			return texts.displayed
		elseif kind == "removed" then
			return texts.removed
		elseif kind == "collected" then
			return string.format(texts.collected, SellMessages.formatCoins(coins))
		elseif kind == "admired" then
			return string.format(texts.admired, name or "")
		elseif kind == "admiredBy" then
			return string.format(texts.admiredBy, name or "")
		end
		return texts.unknown
	end
	if reason == "nothing_to_collect" then
		return texts.nothingToCollect
	elseif reason == "backpack_full" then
		return texts.backpackFull
	elseif reason == "slot_taken" then
		return texts.slotTaken
	elseif reason == "no_such_find" then
		return texts.noSuchFind
	elseif reason == "already_admired" then
		return texts.alreadyAdmired
	elseif reason == "empty_museum" then
		return texts.emptyMuseum
	elseif reason == "too_far" then
		return texts.tooFar
	end
	return texts.unknown
end

return MuseumMessages
