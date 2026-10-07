--!strict
-- Pure text building for the dig HUD: turns ids into German player texts using
-- Strings. No Roblox services; the client displays what this returns.

local DigRoll = require("./DigRoll")

export type Strings = {
	ore: { [string]: string },
	find: { [string]: string },
	rarity: { [string]: string },
	mutation: { [string]: string },
	layer: { [string]: string },
	dig: {
		foundOre: string,
		foundRare: string,
		foundRareMutated: string,
		backpackFull: string,
		tooFar: string,
		unknown: string,
	},
}

local DigMessages = {}

local function nameOf(names: { [string]: string }, id: string?): string
	if id == nil then
		return ""
	end
	return names[id] or id
end

-- Depth in meters with one decimal and a decimal comma, for example "12,3 m".
function DigMessages.formatDepth(depth: number): string
	local text = string.format("%.1f", depth)
	return (string.gsub(text, "%.", ",")) .. " m"
end

function DigMessages.layerName(strings: Strings, layerId: string): string
	return nameOf(strings.layer, layerId)
end

-- One line for a dug block: the ore, or the rare find with mutation and rarity.
function DigMessages.describeBlock(strings: Strings, block: DigRoll.BlockResult): string
	if block.kind == "ore" then
		return string.format(strings.dig.foundOre, nameOf(strings.ore, block.oreId))
	end
	local find = nameOf(strings.find, block.findId)
	local rarity = nameOf(strings.rarity, block.rarityId)
	if block.mutationId ~= nil then
		return string.format(strings.dig.foundRareMutated, nameOf(strings.mutation, block.mutationId), find, rarity)
	end
	return string.format(strings.dig.foundRare, find, rarity)
end

-- Text for a rejected dig that the player should see; other reasons give a neutral text.
function DigMessages.describeFailure(strings: Strings, reason: string): string
	if reason == "backpack_full" then
		return strings.dig.backpackFull
	elseif reason == "too_far" then
		return strings.dig.tooFar
	end
	return strings.dig.unknown
end

return DigMessages
