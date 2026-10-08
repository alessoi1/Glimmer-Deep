--!strict
-- Pure effects of upgrade levels (skills and the shovel's reach) as bonuses for
-- the Modifiers. The level a player has decides the bonus; the bonus of a level
-- replaces the one of the level before. No Roblox services.

export type Level = {
	price: number,
	tempoBonus: number?,
	rareFindBonus: number?,
	walkSpeedBonus: number?,
	luckBonus: number?,
	rangeBonus: number?, -- studs
}

export type Tracks = { [string]: { levels: { Level } } }

-- Bonuses of all upgrades, every field present (0 when nothing applies).
export type Part = {
	tempoBonus: number,
	rareFindBonus: number,
	walkSpeedBonus: number,
	luckBonus: number,
	rangeBonus: number,
}

-- A named effect for the upgrade panel, for example "luck" +5 %.
export type Effect = { kind: string, percent: number }

-- The fields that count as an effect, in the order they are named in the panel.
local PERCENT_EFFECTS = {
	{ kind = "tempo", field = "tempoBonus" },
	{ kind = "rareFind", field = "rareFindBonus" },
	{ kind = "walkSpeed", field = "walkSpeedBonus" },
	{ kind = "luck", field = "luckBonus" },
}

local UpgradeEffects = {}

local function clampedLevel(levels: { Level }, level: number): Level?
	if level ~= level or #levels == 0 then
		return nil
	end
	return levels[math.clamp(math.floor(level), 1, #levels)]
end

-- Adds up the bonus of the current level of every track. Unknown tracks are
-- skipped; a level number outside the range counts as the nearest valid one,
-- and a level below 1 counts as no bonus.
function UpgradeEffects.part(upgradeLevels: { [string]: number }, tracks: Tracks): Part
	local part: Part = { tempoBonus = 0, rareFindBonus = 0, walkSpeedBonus = 0, luckBonus = 0, rangeBonus = 0 }
	for upgradeId, track in tracks do
		local level = upgradeLevels[upgradeId]
		if level ~= nil and level >= 1 then
			local def = clampedLevel(track.levels, level)
			if def ~= nil then
				part.tempoBonus += def.tempoBonus or 0
				part.rareFindBonus += def.rareFindBonus or 0
				part.walkSpeedBonus += def.walkSpeedBonus or 0
				part.luckBonus += def.luckBonus or 0
				part.rangeBonus += def.rangeBonus or 0
			end
		end
	end
	return part
end

-- The percentage effect a level brings, or nil when it has none (level 1, the shovel).
function UpgradeEffects.effectOf(level: Level): Effect?
	for _, entry in PERCENT_EFFECTS do
		local value = (level :: any)[entry.field]
		if type(value) == "number" and value > 0 then
			return { kind = entry.kind, percent = math.floor(value * 100 + 0.5) }
		end
	end
	return nil
end

return UpgradeEffects
