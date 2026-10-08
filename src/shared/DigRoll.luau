--!strict
-- Pure dig roll logic: what does one dug block contain?
-- No Roblox services; config and random source are passed in so this runs
-- under Lune tests. Only the server may call this for real rolls.

export type Rng = () -> number -- returns a number in [0, 1)

export type RarityDef = { id: string, chance: number, minValue: number }
export type MutationDef = { id: string, multiplier: number, weight: number }
export type LayerDef = {
	id: string,
	minDepth: number,
	maxDepth: number,
	ores: { string },
	finds: { string },
}

export type Config = {
	rareFindChance: number,
	mutationChance: number,
	maxLuck: number,
	maxRareFindBonus: number,
	rarities: { RarityDef },
	mutations: { MutationDef },
	layers: { LayerDef },
}

-- A weekly event can make one mutation more likely: its weight is multiplied
-- by `factor` (at least 1) when a find mutates. Draw order stays the same.
export type MutationBoost = { id: string, factor: number }

export type RollParams = {
	depth: number,
	luck: number?, -- multiplier >= 1 on rarity and mutation chances
	rareFindBonus: number?, -- multiplier >= 1 on the rare find chance
	guaranteedRare: boolean?,
	guaranteedMutation: string?, -- mutation id; only used for rare finds
	mutationBoost: MutationBoost?,
}

export type BlockResult = {
	kind: "ore" | "rare",
	layerId: string,
	oreId: string?,
	findId: string?,
	rarityId: string?,
	mutationId: string?,
	value: number?, -- NPC minimum value including mutation multiplier
}

export type RarityChance = { rarityId: string, percent: number }

local PERCENT_TOLERANCE = 1e-6

local DigRoll = {}

local function clampMultiplier(value: number?, maxValue: number): number
	if value == nil or value ~= value then
		return 1
	end
	return math.clamp(value, 1, maxValue)
end

local function draw(rng: Rng): number
	local roll = rng()
	if not (roll >= 0 and roll < 1) then
		error(string.format("rng must return a number in [0, 1), got %s", tostring(roll)), 3)
	end
	return roll
end

local function pickIndex(count: number, roll: number): number
	return math.min(math.floor(roll * count) + 1, count)
end

local function findMutation(config: Config, mutationId: string): MutationDef?
	for _, mutation in config.mutations do
		if mutation.id == mutationId then
			return mutation
		end
	end
	return nil
end

local function mutationWeight(mutation: MutationDef, boost: MutationBoost?): number
	if boost ~= nil and boost.id == mutation.id and boost.factor == boost.factor and boost.factor >= 1 then
		return mutation.weight * boost.factor
	end
	return mutation.weight
end

local function pickMutation(config: Config, roll: number, boost: MutationBoost?): MutationDef
	local total = 0
	for _, mutation in config.mutations do
		total += mutationWeight(mutation, boost)
	end
	local target = roll * total
	local accumulated = 0
	for _, mutation in config.mutations do
		accumulated += mutationWeight(mutation, boost)
		if target < accumulated then
			return mutation
		end
	end
	return config.mutations[#config.mutations]
end

-- Rarity weights with luck: the first (most common) tier keeps its weight,
-- every other tier is multiplied by luck. Percentages are renormalized.
local function rarityWeights(config: Config, luck: number): { number }
	local weights = {}
	for index, rarity in config.rarities do
		weights[index] = if index == 1 then rarity.chance else rarity.chance * luck
	end
	return weights
end

local function pickRarity(config: Config, luck: number, roll: number): RarityDef
	local weights = rarityWeights(config, luck)
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local target = roll * total
	local accumulated = 0
	for index, weight in weights do
		accumulated += weight
		if target < accumulated then
			return config.rarities[index]
		end
	end
	return config.rarities[#config.rarities]
end

function DigRoll.getLayer(config: Config, depth: number): LayerDef
	if depth ~= depth then
		error("depth must be a number, got NaN", 2)
	end
	local layers = config.layers
	if depth < layers[1].minDepth then
		return layers[1]
	end
	for _, layer in layers do
		if depth >= layer.minDepth and depth < layer.maxDepth then
			return layer
		end
	end
	return layers[#layers]
end

function DigRoll.getRareFindChance(config: Config, rareFindBonus: number?): number
	local bonus = clampMultiplier(rareFindBonus, config.maxRareFindBonus)
	return math.min(config.rareFindChance * bonus, 100)
end

function DigRoll.getMutationChance(config: Config, luck: number?): number
	return math.min(config.mutationChance * clampMultiplier(luck, config.maxLuck), 100)
end

-- Share of each mutation in percent among mutated finds (sum 100), with an
-- optional event boost.
function DigRoll.getMutationShares(config: Config, boost: MutationBoost?): { { mutationId: string, percent: number } }
	local total = 0
	for _, mutation in config.mutations do
		total += mutationWeight(mutation, boost)
	end
	local shares = {}
	for index, mutation in config.mutations do
		shares[index] = { mutationId = mutation.id, percent = mutationWeight(mutation, boost) / total * 100 }
	end
	return shares
end

-- Rarity chances in percent (sum 100) for the info window.
function DigRoll.getRarityChances(config: Config, luck: number?): { RarityChance }
	local effectiveLuck = clampMultiplier(luck, config.maxLuck)
	local weights = rarityWeights(config, effectiveLuck)
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local chances = {}
	for index, rarity in config.rarities do
		chances[index] = { rarityId = rarity.id, percent = weights[index] / total * 100 }
	end
	return chances
end

-- Draw order (relevant for tests): rare check (skipped if guaranteed), then
-- for ore: ore index; for finds: rarity, find, mutation check (skipped if
-- guaranteed), mutation pick.
function DigRoll.rollBlock(config: Config, rng: Rng, params: RollParams): BlockResult
	local layer = DigRoll.getLayer(config, params.depth)
	local luck = clampMultiplier(params.luck, config.maxLuck)

	local isRare = params.guaranteedRare == true
	if not isRare then
		isRare = draw(rng) * 100 < DigRoll.getRareFindChance(config, params.rareFindBonus)
	end

	if not isRare then
		local oreId = layer.ores[pickIndex(#layer.ores, draw(rng))]
		return { kind = "ore", layerId = layer.id, oreId = oreId }
	end

	local rarity = pickRarity(config, luck, draw(rng))
	local findId = layer.finds[pickIndex(#layer.finds, draw(rng))]

	local mutation: MutationDef? = nil
	if params.guaranteedMutation ~= nil then
		mutation = findMutation(config, params.guaranteedMutation)
		if mutation == nil then
			error("unknown guaranteed mutation: " .. params.guaranteedMutation, 2)
		end
	elseif draw(rng) * 100 < DigRoll.getMutationChance(config, luck) then
		mutation = pickMutation(config, draw(rng), params.mutationBoost)
	end

	local value = rarity.minValue
	if mutation ~= nil then
		value *= mutation.multiplier
	end

	return {
		kind = "rare",
		layerId = layer.id,
		findId = findId,
		rarityId = rarity.id,
		mutationId = if mutation then mutation.id else nil,
		value = value,
	}
end

-- Returns true when the config is usable, otherwise false and a reason.
function DigRoll.validateConfig(config: Config): (boolean, string?)
	if #config.rarities == 0 then
		return false, "no rarities configured"
	end
	local chanceSum = 0
	for _, rarity in config.rarities do
		if rarity.chance < 0 or rarity.minValue < 0 then
			return false, "rarity " .. rarity.id .. " has a negative value"
		end
		chanceSum += rarity.chance
	end
	if math.abs(chanceSum - 100) > PERCENT_TOLERANCE then
		return false, string.format("rarity chances must sum to 100, got %s", tostring(chanceSum))
	end

	if #config.mutations == 0 then
		return false, "no mutations configured"
	end
	for _, mutation in config.mutations do
		if mutation.multiplier < 1 then
			return false, "mutation " .. mutation.id .. " has a multiplier below 1"
		end
		if mutation.weight <= 0 then
			return false, "mutation " .. mutation.id .. " needs a positive weight"
		end
	end

	if #config.layers == 0 then
		return false, "no layers configured"
	end
	if config.layers[1].minDepth ~= 0 then
		return false, "first layer must start at depth 0"
	end
	for index, layer in config.layers do
		if #layer.ores == 0 or #layer.finds == 0 then
			return false, "layer " .. layer.id .. " needs ores and finds"
		end
		if layer.maxDepth <= layer.minDepth then
			return false, "layer " .. layer.id .. " has an empty depth range"
		end
		local nextLayer = config.layers[index + 1]
		if nextLayer ~= nil and nextLayer.minDepth ~= layer.maxDepth then
			return false, "layers " .. layer.id .. " and " .. nextLayer.id .. " are not contiguous"
		end
	end

	for _, percent in { config.rareFindChance, config.mutationChance } do
		if percent < 0 or percent > 100 then
			return false, "chances must be between 0 and 100"
		end
	end
	if config.maxLuck < 1 or config.maxRareFindBonus < 1 then
		return false, "maxLuck and maxRareFindBonus must be at least 1"
	end

	return true, nil
end

return DigRoll
