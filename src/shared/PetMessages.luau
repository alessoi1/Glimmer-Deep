--!strict
-- Pure text building for the pet panel. Texts stay neutral ("Angebot ansehen"),
-- never pushy. No Roblox services; the client displays what this returns.

local SellMessages = require("./SellMessages")

export type Strings = {
	shop: { viewOffer: string, soon: string, price: string },
	rarity: { [string]: string },
	pets: {
		pet: { [string]: string },
		effectTempo: string,
		effectLuck: string,
		effectOffline: string,
		chanceLine: string,
		petChanceLine: string,
		pityLine: string,
		pityProgress: string,
		pityNext: string,
		freeIn: string,
		freeClaim: string,
		hatched: string,
		hatchedGuaranteed: string,
		equipped: string,
		unequipped: string,
		eggsCount: string,
		slotsLine: string,
		collectionLine: string,
		durationHours: string,
		durationMinutes: string,
		noEgg: string,
		full: string,
		notAvailable: string,
		cooldown: string,
		unknown: string,
	},
}

-- Structural subsets of Pets.View parts.
export type EggState = { buyable: boolean }
export type FreeState = { canClaim: boolean, secondsUntil: number }
export type Effect = { tempoBonus: number?, luckBonus: number?, offlineBonus: number? }

local SECONDS_PER_MINUTE = 60
local MINUTES_PER_HOUR = 60
local PERCENT = 100

local PetMessages = {}

function PetMessages.petName(strings: Strings, petId: string): string
	return strings.pets.pet[petId] or petId
end

function PetMessages.rarityName(strings: Strings, rarityId: string): string
	return strings.rarity[rarityId] or rarityId
end

-- "Tempo +6 %", several effects joined with ", ".
function PetMessages.effectText(strings: Strings, effect: Effect): string
	local parts = {}
	local function add(format: string, value: number?)
		if value ~= nil and value > 0 then
			table.insert(parts, string.format(format, math.floor(value * PERCENT + 0.5)))
		end
	end
	add(strings.pets.effectTempo, effect.tempoBonus)
	add(strings.pets.effectLuck, effect.luckBonus)
	add(strings.pets.effectOffline, effect.offlineBonus)
	return table.concat(parts, ", ")
end

-- A percentage with one decimal and a decimal comma: 4.5 -> "4,5".
function PetMessages.percentText(percent: number): string
	return (string.gsub(string.format("%.1f", percent), "%.", ","))
end

-- "Selten: 25,0 %".
function PetMessages.rarityChanceLine(strings: Strings, rarityId: string, percent: number): string
	return string.format(
		strings.pets.chanceLine,
		PetMessages.rarityName(strings, rarityId),
		PetMessages.percentText(percent)
	)
end

-- "Maulwurf (Gewöhnlich): 30,0 %".
function PetMessages.petChanceLine(strings: Strings, petId: string, rarityId: string, percent: number): string
	return string.format(
		strings.pets.petChanceLine,
		PetMessages.petName(strings, petId),
		PetMessages.rarityName(strings, rarityId),
		PetMessages.percentText(percent)
	)
end

-- "Spätestens das 10. Ei ist mindestens selten."
function PetMessages.pityLine(strings: Strings, afterEggs: number, rarityId: string): string
	return string.format(strings.pets.pityLine, afterEggs, string.lower(PetMessages.rarityName(strings, rarityId)))
end

-- Progress to the guarantee: "Die Garantie gilt für das nächste Ei" or "... höchstens 4 Eier".
function PetMessages.pityProgress(strings: Strings, eggsUntil: number): string
	if eggsUntil <= 1 then
		return strings.pets.pityNext
	end
	return string.format(strings.pets.pityProgress, eggsUntil)
end

function PetMessages.durationText(strings: Strings, seconds: number): string
	local totalMinutes = math.ceil(seconds / SECONDS_PER_MINUTE)
	local hours = totalMinutes // MINUTES_PER_HOUR
	local minutes = totalMinutes % MINUTES_PER_HOUR
	if hours > 0 then
		return string.format(strings.pets.durationHours, hours, minutes)
	end
	return string.format(strings.pets.durationMinutes, minutes)
end

function PetMessages.priceText(strings: Strings, robux: number): string
	return string.format(strings.shop.price, SellMessages.formatCoins(robux))
end

function PetMessages.actionText(strings: Strings, egg: EggState): string
	if egg.buyable then
		return strings.shop.viewOffer
	end
	return strings.shop.soon
end

function PetMessages.freeText(strings: Strings, free: FreeState): string
	if free.canClaim then
		return strings.pets.freeClaim
	end
	return string.format(strings.pets.freeIn, PetMessages.durationText(strings, free.secondsUntil))
end

function PetMessages.eggsText(strings: Strings, eggs: number): string
	return string.format(strings.pets.eggsCount, eggs)
end

function PetMessages.slotsText(strings: Strings, working: number, slots: number): string
	return string.format(strings.pets.slotsLine, working, slots)
end

function PetMessages.collectionText(strings: Strings, owned: number, maxOwned: number): string
	return string.format(strings.pets.collectionLine, owned, maxOwned)
end

-- Message after hatching an egg.
function PetMessages.hatchedText(strings: Strings, petId: string, rarityId: string, guaranteed: boolean): string
	local format = if guaranteed then strings.pets.hatchedGuaranteed else strings.pets.hatched
	return string.format(format, PetMessages.petName(strings, petId), PetMessages.rarityName(strings, rarityId))
end

-- Message after a pet action; unknown reasons give a neutral text.
function PetMessages.describeResult(strings: Strings, ok: boolean, reason: string?): string
	if ok then
		return ""
	elseif reason == "no_egg" then
		return strings.pets.noEgg
	elseif reason == "full" then
		return strings.pets.full
	elseif reason == "not_available" then
		return strings.pets.notAvailable
	elseif reason == "cooldown" then
		return strings.pets.cooldown
	end
	return strings.pets.unknown
end

return PetMessages
