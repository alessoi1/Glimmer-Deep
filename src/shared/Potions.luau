--!strict
-- Pure potion logic: brewing from herbs in the stash, drinking, running
-- effects and the rules for trading. No Roblox services and no logging; the
-- PotionService decides who may do what, applies the effects and logs. All
-- times are server seconds (os.time).

export type PotionDef = {
	recipe: { [string]: number },
	coins: number,
	effect: string,
	amount: number,
	duration: number,
	cooldown: number,
}

export type Config = {
	order: { string },
	maxOwnedPerPotion: number,
	maxBrewAtOnce: number,
	maxDuration: number,
	potions: { [string]: PotionDef },
}

export type State = {
	owned: { [string]: number }, -- potion id -> count
	active: { [string]: number }, -- potion id -> server time the effect ends
	cooldownUntil: { [string]: number }, -- potion id -> server time it can be drunk again
}

export type Stash = { ores: { [string]: number } }
export type Wallet = { coins: number }

export type FailureReason =
	"unknown_potion"
	| "bad_count"
	| "not_enough_herbs"
	| "not_enough_coins"
	| "too_many"
	| "none_owned"
	| "cooldown"

export type Result = {
	ok: boolean,
	reason: FailureReason?,
	effect: string?,
	amount: number?,
	expiresAt: number?,
}

-- The multipliers of everything that is running (1 when nothing is).
export type Effects = { damage: number, speed: number, luck: number, nightVision: boolean }

local EFFECT_KINDS: { [string]: boolean } = {
	heal = true,
	damage = true,
	speed = true,
	luck = true,
	night_vision = true,
}

local Potions = {}

local function isInteger(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge and value % 1 == 0
end

function Potions.new(): State
	return { owned = {}, active = {}, cooldownUntil = {} }
end

function Potions.tradable(): boolean
	return true
end

-- Moves the herbs that some recipe uses from the backpack to the stash. Other
-- items stay. Returns the amount moved.
function Potions.depositHerbs(backpackOres: { [string]: number }, stash: Stash, config: Config): number
	local used: { [string]: boolean } = {}
	for _, potion in config.potions do
		for herb in potion.recipe do
			used[herb] = true
		end
	end
	local moved = 0
	for herb in used do
		local count = backpackOres[herb]
		if count ~= nil and count > 0 then
			stash.ores[herb] = (stash.ores[herb] or 0) + count
			backpackOres[herb] = nil
			moved += count
		end
	end
	return moved
end

-- Pays with herbs from the stash and coins and adds `count` potions. On failure
-- nothing changes.
function Potions.brew(
	state: State,
	stash: Stash,
	wallet: Wallet,
	config: Config,
	potionId: string,
	count: number
): Result
	local potion = config.potions[potionId]
	if potion == nil then
		return { ok = false, reason = "unknown_potion" }
	end
	if not isInteger(count) or count < 1 or count > config.maxBrewAtOnce then
		return { ok = false, reason = "bad_count" }
	end
	if (state.owned[potionId] or 0) + count > config.maxOwnedPerPotion then
		return { ok = false, reason = "too_many" }
	end
	for herb, perPotion in potion.recipe do
		if (stash.ores[herb] or 0) < perPotion * count then
			return { ok = false, reason = "not_enough_herbs" }
		end
	end
	local coins = potion.coins * count
	if wallet.coins < coins then
		return { ok = false, reason = "not_enough_coins" }
	end

	for herb, perPotion in potion.recipe do
		local left = (stash.ores[herb] :: number) - perPotion * count
		stash.ores[herb] = if left > 0 then left else nil
	end
	wallet.coins -= coins
	state.owned[potionId] = (state.owned[potionId] or 0) + count
	return { ok = true }
end

-- Drinks one potion at server time `now`. Instant potions return their effect
-- and amount for the caller to apply; timed potions start (or refresh) an
-- effect that lasts `duration` seconds but never longer than maxDuration from now.
function Potions.drink(state: State, config: Config, potionId: string, now: number): Result
	local potion = config.potions[potionId]
	if potion == nil then
		return { ok = false, reason = "unknown_potion" }
	end
	local owned = state.owned[potionId] or 0
	if owned < 1 then
		return { ok = false, reason = "none_owned" }
	end
	local until_ = state.cooldownUntil[potionId]
	if until_ ~= nil and now < until_ then
		return { ok = false, reason = "cooldown" }
	end

	state.owned[potionId] = if owned > 1 then owned - 1 else nil
	if potion.cooldown > 0 then
		state.cooldownUntil[potionId] = now + potion.cooldown
	end
	local expiresAt: number? = nil
	if potion.duration > 0 then
		expiresAt = now + math.min(potion.duration, config.maxDuration)
		state.active[potionId] = expiresAt
	end
	return { ok = true, effect = potion.effect, amount = potion.amount, expiresAt = expiresAt }
end

-- What is running at `now`. For the same kind the strongest one counts.
function Potions.effects(state: State, config: Config, now: number): Effects
	local effects: Effects = { damage = 1, speed = 1, luck = 1, nightVision = false }
	for potionId, endsAt in state.active do
		local potion = config.potions[potionId]
		if potion ~= nil and now < endsAt then
			if potion.effect == "damage" then
				effects.damage = math.max(effects.damage, potion.amount)
			elseif potion.effect == "speed" then
				effects.speed = math.max(effects.speed, potion.amount)
			elseif potion.effect == "luck" then
				effects.luck = math.max(effects.luck, potion.amount)
			elseif potion.effect == "night_vision" then
				effects.nightVision = true
			end
		end
	end
	return effects
end

-- Removes effects and cooldowns that are over.
function Potions.prune(state: State, now: number)
	for potionId, endsAt in state.active do
		if now >= endsAt then
			state.active[potionId] = nil
		end
	end
	for potionId, readyAt in state.cooldownUntil do
		if now >= readyAt then
			state.cooldownUntil[potionId] = nil
		end
	end
end

-- Returns true when the config is usable, otherwise false and a reason.
function Potions.validateConfig(config: Config): (boolean, string?)
	local seen: { [string]: boolean } = {}
	for _, id in config.order do
		if config.potions[id] == nil then
			return false, "order lists unknown potion " .. id
		end
		seen[id] = true
	end
	for id in config.potions do
		if not seen[id] then
			return false, "potion " .. id .. " is missing in order"
		end
	end
	if not isInteger(config.maxOwnedPerPotion) or config.maxOwnedPerPotion < 1 then
		return false, "maxOwnedPerPotion must be a positive integer"
	end
	if not isInteger(config.maxBrewAtOnce) or config.maxBrewAtOnce < 1 then
		return false, "maxBrewAtOnce must be a positive integer"
	end
	if config.maxBrewAtOnce > config.maxOwnedPerPotion then
		return false, "maxBrewAtOnce must not exceed maxOwnedPerPotion"
	end
	if not (config.maxDuration > 0) then
		return false, "maxDuration must be positive"
	end
	for id, potion in config.potions do
		if next(potion.recipe) == nil then
			return false, id .. " needs a recipe"
		end
		for herb, count in potion.recipe do
			if type(herb) ~= "string" or not isInteger(count) or count < 1 then
				return false, id .. " recipe needs positive integer amounts"
			end
		end
		if not isInteger(potion.coins) or potion.coins < 0 then
			return false, id .. " needs a non-negative integer coin price"
		end
		if not EFFECT_KINDS[potion.effect] then
			return false, id .. " has an unknown effect " .. tostring(potion.effect)
		end
		if potion.effect == "heal" then
			if not (potion.amount > 0 and potion.amount <= 1) then
				return false, id .. " heals a share of life from above 0 to 1"
			end
		elseif potion.effect ~= "night_vision" and not (potion.amount >= 1) then
			return false, id .. " needs a multiplier of at least 1"
		end
		if not (potion.duration >= 0 and potion.duration <= config.maxDuration) then
			return false, id .. " duration must be from 0 to maxDuration"
		end
		if potion.effect ~= "heal" and potion.duration <= 0 then
			return false, id .. " needs a duration"
		end
		if not (potion.cooldown >= 0) then
			return false, id .. " cooldown must not be negative"
		end
	end
	return true, nil
end

-- Returns true when the stored potion state is consistent, otherwise false and a reason.
function Potions.validate(state: any, config: Config): (boolean, string?)
	if type(state) ~= "table" or type(state.owned) ~= "table" or type(state.active) ~= "table" then
		return false, "potions need owned and active"
	end
	if type(state.cooldownUntil) ~= "table" then
		return false, "potions need cooldownUntil"
	end
	for id, count in state.owned do
		if config.potions[id] == nil then
			return false, "owned unknown potion " .. tostring(id)
		end
		if not isInteger(count) or count < 1 or count > config.maxOwnedPerPotion then
			return false, "owned " .. tostring(id) .. " must be an integer from 1 to " .. config.maxOwnedPerPotion
		end
	end
	for _, name in { "active", "cooldownUntil" } do
		for id, time in state[name] do
			if config.potions[id] == nil then
				return false, name .. " has unknown potion " .. tostring(id)
			end
			if not isInteger(time) or time < 0 then
				return false, name .. "." .. tostring(id) .. " must be a non-negative integer"
			end
		end
	end
	return true, nil
end

return Potions
