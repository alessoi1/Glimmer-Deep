--!strict
-- Pure selling logic: turns backpack contents into coins at the NPC.
-- No Roblox services; the server decides when to sell and applies the result.

-- Structural subset of Backpack.Backpack (kept local so this module has no requires).
export type Sellable = {
	ores: { [string]: number },
	finds: { { value: number } },
}

export type OreValues = { [string]: number }

export type SellResult = {
	coins: number,
	oreCoins: number,
	findCoins: number,
	oreCount: number,
	findCount: number,
	unknownOres: { [string]: number }, -- ores without a price; left in the backpack
}

-- Guards float rounding such as 20 * 1.15 = 22.999999999999996.
local ROUNDING_EPSILON = 1e-9

local Selling = {}

-- Sells everything with a known price and removes it from the backpack.
-- oreMultiplier (for example the "Doppelte Münzen" pass) applies to ore only,
-- never to rare finds. Ores without a price stay in the backpack and are
-- reported in unknownOres so the caller can log them.
function Selling.sellAll(backpack: Sellable, oreValues: OreValues, oreMultiplier: number?): SellResult
	local multiplier = oreMultiplier
	if multiplier == nil or multiplier ~= multiplier or multiplier < 1 then
		multiplier = 1
	end

	local baseOreCoins = 0
	local oreCount = 0
	local unknownOres: { [string]: number } = {}
	local soldOreIds: { string } = {}

	for oreId, count in backpack.ores do
		local price = oreValues[oreId]
		if price == nil then
			unknownOres[oreId] = count
		else
			baseOreCoins += price * count
			oreCount += count
			table.insert(soldOreIds, oreId)
		end
	end
	for _, oreId in soldOreIds do
		backpack.ores[oreId] = nil
	end

	local findCoins = 0
	local findCount = #backpack.finds
	for _, find in backpack.finds do
		findCoins += find.value
	end
	table.clear(backpack.finds)

	local oreCoins = math.floor(baseOreCoins * multiplier + ROUNDING_EPSILON)
	return {
		coins = oreCoins + findCoins,
		oreCoins = oreCoins,
		findCoins = findCoins,
		oreCount = oreCount,
		findCount = findCount,
		unknownOres = unknownOres,
	}
end

-- Every ore and herb that can be found in any layer needs a non-negative integer price.
function Selling.validateOreValues(
	layers: { { id: string, ores: { string }, herbs: { string }? } },
	oreValues: OreValues
): (boolean, string?)
	for _, layer in layers do
		-- Herbs are stored and sold like ore.
		local itemIds = table.clone(layer.ores)
		for _, herbId in layer.herbs or {} do
			table.insert(itemIds, herbId)
		end
		for _, oreId in itemIds do
			local price = oreValues[oreId]
			if price == nil then
				return false, string.format("item %s (layer %s) has no price", oreId, layer.id)
			end
			if price ~= price or price < 0 or price % 1 ~= 0 then
				return false, string.format("item %s needs a non-negative integer price", oreId)
			end
		end
	end
	return true, nil
end

return Selling
