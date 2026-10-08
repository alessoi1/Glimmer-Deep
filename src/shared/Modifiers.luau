--!strict
-- Pure combination of player bonuses (museum sets, skills, pets, boosters, passes)
-- into the multipliers the game systems use. Every source delivers a Part; the
-- server gathers the parts in the ModifierService. No Roblox services.
--
-- Bonuses add up (+10 % and +10 % is x1.2); pass factors multiply. Negative,
-- missing or invalid numbers count as "no bonus".

export type Part = {
	coinBonus: number?, -- ore sales and museum visitor income
	oreSaleFactor: number?, -- multiplies ore sales only (the "Doppelte Münzen" pass)
	luckBonus: number?, -- rarity and mutation chances
	rareFindBonus: number?, -- chance of a rare find per block
	tempoBonus: number?, -- dig speed
	capacityBonus: number?, -- backpack capacity
	offlineBonus: number?, -- offline digger yield
	offlineHoursBonus: number?, -- extra hours the offline digger works (the "Nachtschicht" pass)
	rangeBonus: number?, -- extra studs of dig range
	walkSpeedBonus: number?, -- walking speed
}

export type Result = {
	coinMultiplier: number,
	oreSaleFactor: number,
	luck: number,
	rareFindMultiplier: number,
	speedMultiplier: number,
	capacityMultiplier: number,
	offlineMultiplier: number,
	offlineExtraHours: number,
	rangeBonus: number,
	walkSpeedMultiplier: number,
}

local Modifiers = {
	-- Every field a Part may have (the config checks effect tables against this).
	knownFields = {
		"coinBonus",
		"oreSaleFactor",
		"luckBonus",
		"rareFindBonus",
		"tempoBonus",
		"capacityBonus",
		"offlineBonus",
		"offlineHoursBonus",
		"rangeBonus",
		"walkSpeedBonus",
	},
}

local function valid(value: number?): number?
	if value == nil or value ~= value or value < 0 or value == math.huge then
		return nil
	end
	return value
end

local function sum(parts: { Part }, field: string): number
	local total = 0
	for _, part in parts do
		total += valid((part :: any)[field]) or 0
	end
	return total
end

function Modifiers.combine(parts: { Part }): Result
	local oreSaleFactor = 1
	for _, part in parts do
		local factor = valid(part.oreSaleFactor)
		if factor ~= nil and factor > 0 then
			oreSaleFactor *= factor
		end
	end
	return {
		coinMultiplier = 1 + sum(parts, "coinBonus"),
		oreSaleFactor = oreSaleFactor,
		luck = 1 + sum(parts, "luckBonus"),
		rareFindMultiplier = 1 + sum(parts, "rareFindBonus"),
		speedMultiplier = 1 + sum(parts, "tempoBonus"),
		capacityMultiplier = 1 + sum(parts, "capacityBonus"),
		offlineMultiplier = 1 + sum(parts, "offlineBonus"),
		offlineExtraHours = sum(parts, "offlineHoursBonus"),
		rangeBonus = sum(parts, "rangeBonus"),
		walkSpeedMultiplier = 1 + sum(parts, "walkSpeedBonus"),
	}
end

return Modifiers
