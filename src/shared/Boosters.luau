--!strict
-- Pure booster logic: config checks, running times, the effect of a running
-- booster, receipt handling (idempotent) and the view the shop shows. All
-- times are server times (os.time seconds) passed in by the caller. No Roblox
-- services; the BoosterService talks to MarketplaceService and PolicyService.

local Modifiers = require("./Modifiers")

export type Def = {
	productId: number, -- 0 = not created in the Creator Dashboard yet
	robux: number,
	durationSeconds: number,
	effect: Modifiers.Part,
	paidRandom: boolean,
}

export type Config = {
	order: { string },
	boosters: { [string]: Def },
	maxStackSeconds: number,
	receiptHistory: number,
	freeClaim: { boosterId: string, cooldownSeconds: number },
}

-- What the profile stores.
export type State = {
	expires: { [string]: number }, -- booster id -> server time it ends
	receipts: { string }, -- latest purchase ids, oldest first
	freeClaimedAt: number, -- server time of the last free claim, 0 = never
}

export type BoosterView = {
	key: string,
	robux: number,
	durationSeconds: number,
	remaining: number, -- seconds left, 0 when not running
	buyable: boolean, -- the id from the dashboard is set
	paidRandom: boolean,
	luckBonus: number, -- 0 when the booster gives no luck
}

export type FreeView = {
	key: string,
	durationSeconds: number,
	canClaim: boolean,
	secondsUntil: number, -- seconds until the next free claim, 0 when claimable
}

export type View = {
	available: boolean, -- false during the first minutes (no purchase offers yet)
	restricted: boolean, -- PolicyService restricts paid random items
	boosters: { BoosterView }, -- paid random boosters are left out when restricted
	free: FreeView?, -- only for restricted players
}

-- What the server sends to the shop panel: the view plus the shown chances.
export type Snapshot = {
	view: View,
	chances: { ChanceRow }, -- rarity chances without and with the luck booster
	mutationBase: number, -- mutation chance in percent without the luck booster
	mutationBoosted: number, -- ... and with it
	luckBoosterId: string, -- the booster the chances belong to
}

export type ChanceRow = { rarityId: string, base: number, boosted: number }

export type ReceiptOutcome = "granted" | "duplicate" | "unknown_product" | "bad_receipt"

local Boosters = {}

local function isPositiveInteger(value: any): boolean
	return type(value) == "number" and value >= 1 and value < math.huge and value % 1 == 0
end

-- Returns true when the config is usable, otherwise false and a reason.
function Boosters.validateConfig(config: Config): (boolean, string?)
	local inOrder: { [string]: boolean } = {}
	for _, key in config.order do
		if config.boosters[key] == nil then
			return false, "order names the unknown booster " .. key
		end
		inOrder[key] = true
	end
	local productIds: { [number]: string } = {}
	for key, def in config.boosters do
		if not inOrder[key] then
			return false, key .. " is missing from the order"
		end
		if not isPositiveInteger(def.robux) then
			return false, key .. " needs a positive integer price"
		end
		if not isPositiveInteger(def.durationSeconds) then
			return false, key .. " needs a positive integer duration"
		end
		if type(def.productId) ~= "number" or def.productId < 0 or def.productId % 1 ~= 0 then
			return false, key .. " needs a non-negative integer productId"
		end
		if def.productId > 0 then
			if productIds[def.productId] ~= nil then
				return false, key .. " shares its productId with " .. productIds[def.productId]
			end
			productIds[def.productId] = key
		end
		local fields = 0
		for field in def.effect do
			fields += 1
			if table.find(Modifiers.knownFields, field) == nil then
				return false, string.format("%s has the unknown effect %s", key, tostring(field))
			end
		end
		if fields == 0 then
			return false, key .. " needs an effect"
		end
		if def.durationSeconds > config.maxStackSeconds then
			return false, key .. " lasts longer than maxStackSeconds"
		end
	end
	if not isPositiveInteger(config.maxStackSeconds) then
		return false, "maxStackSeconds must be a positive integer"
	end
	if not isPositiveInteger(config.receiptHistory) then
		return false, "receiptHistory must be a positive integer"
	end
	local free = config.freeClaim
	if config.boosters[free.boosterId] == nil then
		return false, "freeClaim names the unknown booster " .. free.boosterId
	end
	if not isPositiveInteger(free.cooldownSeconds) then
		return false, "freeClaim needs a positive integer cooldown"
	end
	return true, nil
end

function Boosters.newState(): State
	return { expires = {}, receipts = {}, freeClaimedAt = 0 }
end

-- Seconds a booster still runs, 0 when it is not running or unknown.
function Boosters.remaining(state: State, key: string, now: number): number
	local expires = state.expires[key]
	if expires == nil or expires <= now then
		return 0
	end
	return expires - now
end

-- The bonus part of a booster while it runs; nil otherwise.
function Boosters.effectOf(state: State, key: string, config: Config, now: number): Modifiers.Part?
	local def = config.boosters[key]
	if def == nil or Boosters.remaining(state, key, now) <= 0 then
		return nil
	end
	return def.effect
end

-- Starts or extends a booster. The remaining time never exceeds maxStackSeconds.
-- Returns the new end time, or nil for an unknown booster.
function Boosters.grant(state: State, config: Config, key: string, now: number): number?
	local def = config.boosters[key]
	if def == nil then
		return nil
	end
	local base = math.max(now, state.expires[key] or 0)
	local expires = math.min(base + def.durationSeconds, now + config.maxStackSeconds)
	state.expires[key] = expires
	return expires
end

-- Booster id for the product id from the dashboard, or nil. Id 0 never matches.
function Boosters.keyOfProduct(config: Config, productId: number): string?
	if productId <= 0 then
		return nil
	end
	for key, def in config.boosters do
		if def.productId == productId then
			return key
		end
	end
	return nil
end

function Boosters.hasReceipt(state: State, purchaseId: string): boolean
	return table.find(state.receipts, purchaseId) ~= nil
end

-- Handles one purchase receipt: grants the booster once per purchase id.
-- A known purchase id is "duplicate" and changes nothing, so Roblox may retry
-- a receipt as often as it wants. An unknown product or a malformed receipt
-- changes nothing either.
function Boosters.processReceipt(
	state: State,
	config: Config,
	purchaseId: string,
	productId: number,
	now: number
): ReceiptOutcome
	if type(purchaseId) ~= "string" or purchaseId == "" or type(productId) ~= "number" then
		return "bad_receipt"
	end
	if Boosters.hasReceipt(state, purchaseId) then
		return "duplicate"
	end
	local key = Boosters.keyOfProduct(config, productId)
	if key == nil then
		return "unknown_product"
	end
	Boosters.grant(state, config, key, now)
	table.insert(state.receipts, purchaseId)
	while #state.receipts > config.receiptHistory do
		table.remove(state.receipts, 1)
	end
	return "granted"
end

-- Seconds until the next free claim; 0 when it can be claimed now.
function Boosters.secondsUntilFree(state: State, config: Config, now: number): number
	if state.freeClaimedAt <= 0 then
		return 0
	end
	return math.max(0, state.freeClaimedAt + config.freeClaim.cooldownSeconds - now)
end

-- The free run for restricted players. Returns true when it was granted, else
-- false and a reason ("not_restricted", "cooldown").
function Boosters.claimFree(state: State, config: Config, restricted: boolean, now: number): (boolean, string?)
	if not restricted then
		return false, "not_restricted"
	end
	if Boosters.secondsUntilFree(state, config, now) > 0 then
		return false, "cooldown"
	end
	Boosters.grant(state, config, config.freeClaim.boosterId, now)
	state.freeClaimedAt = now
	return true, nil
end

function Boosters.view(state: State, config: Config, now: number, available: boolean, restricted: boolean): View
	local list: { BoosterView } = {}
	for _, key in config.order do
		local def = config.boosters[key]
		if not (restricted and def.paidRandom) then
			table.insert(list, {
				key = key,
				robux = def.robux,
				durationSeconds = def.durationSeconds,
				remaining = Boosters.remaining(state, key, now),
				buyable = def.productId > 0,
				paidRandom = def.paidRandom,
				luckBonus = def.effect.luckBonus or 0,
			})
		end
	end
	local free: FreeView? = nil
	if restricted then
		local untilFree = Boosters.secondsUntilFree(state, config, now)
		free = {
			key = config.freeClaim.boosterId,
			durationSeconds = config.boosters[config.freeClaim.boosterId].durationSeconds,
			canClaim = untilFree <= 0,
			secondsUntil = untilFree,
		}
	end
	return { available = available, restricted = restricted, boosters = list, free = free }
end

-- Rarity chances in percent without and with the booster, row by row. Both
-- lists come from DigRoll.getRarityChances and are in the same order.
function Boosters.chanceRows(
	base: { { rarityId: string, percent: number } },
	boosted: { { rarityId: string, percent: number } }
): { ChanceRow }
	local rows: { ChanceRow } = {}
	for index, entry in base do
		local other = boosted[index]
		table.insert(rows, {
			rarityId = entry.rarityId,
			base = entry.percent,
			boosted = if other ~= nil then other.percent else entry.percent,
		})
	end
	return rows
end

return Boosters
