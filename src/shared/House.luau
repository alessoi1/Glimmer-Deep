--!strict
-- Pure house logic: the upgrade to the next level, buying decoration with
-- coins and placing it on the free places of the house. Everything is decided
-- from the profile data passed in; no Roblox services. The HouseService calls
-- this, logs and builds the world.

export type ItemDef = {
	price: number,
	sizeX: number,
	sizeY: number,
	sizeZ: number,
	color: { r: number, g: number, b: number },
}

export type Config = {
	maxLevel: number,
	upgradeCosts: { number },
	decorSlotsByLevel: { number },
	actionCooldown: number,
	promptDistance: number,
	useDistance: number,
	order: { string },
	items: { [string]: ItemDef },
}

export type Placed = { slot: number, id: string }

export type Decor = {
	owned: { [string]: boolean }, -- decoration id -> true once bought
	placed: { Placed },
}

-- The part of a profile this module reads and changes.
export type Subject = {
	coins: number,
	house: { level: number, decor: Decor },
}

export type ItemView = {
	id: string,
	price: number,
	owned: boolean,
	placedSlot: number?,
}

export type View = {
	level: number,
	maxLevel: number,
	nextCost: number?, -- nil at the highest level
	canUpgrade: boolean,
	decorSlots: number,
	items: { ItemView },
	placed: { Placed },
}

export type Result = { ok: boolean, reason: string? }

local House = {}

local function isPositiveInteger(value: any): boolean
	return type(value) == "number" and value >= 1 and value < math.huge and value % 1 == 0
end

local function isNonNegativeInteger(value: any): boolean
	return type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0
end

-- Returns true when the config is usable, otherwise false and a reason.
function House.validateConfig(config: Config): (boolean, string?)
	if not isPositiveInteger(config.maxLevel) then
		return false, "maxLevel must be a positive integer"
	end
	if #config.upgradeCosts < config.maxLevel or #config.decorSlotsByLevel < config.maxLevel then
		return false, "upgradeCosts and decorSlotsByLevel need an entry per level"
	end
	for level = 1, config.maxLevel do
		if not isNonNegativeInteger(config.upgradeCosts[level]) then
			return false, "upgradeCosts needs a non-negative integer per level"
		end
		if not isNonNegativeInteger(config.decorSlotsByLevel[level]) then
			return false, "decorSlotsByLevel needs a non-negative integer per level"
		end
		if level > 1 and config.upgradeCosts[level] <= 0 then
			return false, "upgrading must cost coins"
		end
		if level > 1 and config.decorSlotsByLevel[level] < config.decorSlotsByLevel[level - 1] then
			return false, "decorSlotsByLevel must not shrink"
		end
	end
	if not (type(config.actionCooldown) == "number" and config.actionCooldown >= 0) then
		return false, "actionCooldown must be a non-negative number"
	end
	local inOrder: { [string]: boolean } = {}
	for _, id in config.order do
		if config.items[id] == nil then
			return false, "order names the unknown item " .. id
		end
		inOrder[id] = true
	end
	for id, def in config.items do
		if not inOrder[id] then
			return false, id .. " is missing from the order"
		end
		if not isPositiveInteger(def.price) then
			return false, id .. " needs a positive integer price"
		end
	end
	return true, nil
end

function House.newDecor(): Decor
	return { owned = {}, placed = {} }
end

function House.decorSlots(config: Config, level: number): number
	return config.decorSlotsByLevel[math.clamp(level, 1, #config.decorSlotsByLevel)] or 0
end

local function placedSlotOf(decor: Decor, id: string): number?
	for _, entry in decor.placed do
		if entry.id == id then
			return entry.slot
		end
	end
	return nil
end

-- Buys the next house level. Fails with "max_level" or "not_enough_coins".
function House.upgrade(subject: Subject, config: Config): Result
	local nextLevel = subject.house.level + 1
	if nextLevel > config.maxLevel then
		return { ok = false, reason = "max_level" }
	end
	local cost = config.upgradeCosts[nextLevel]
	if subject.coins < cost then
		return { ok = false, reason = "not_enough_coins" }
	end
	subject.coins -= cost
	subject.house.level = nextLevel
	return { ok = true, reason = nil }
end

-- Buys a decoration once. Fails with "unknown_item", "already_owned",
-- "no_decor_yet" (the house has no decoration places) or "not_enough_coins".
function House.buy(subject: Subject, config: Config, id: string): Result
	local def = config.items[id]
	if def == nil then
		return { ok = false, reason = "unknown_item" }
	end
	if subject.house.decor.owned[id] == true then
		return { ok = false, reason = "already_owned" }
	end
	if House.decorSlots(config, subject.house.level) <= 0 then
		return { ok = false, reason = "no_decor_yet" }
	end
	if subject.coins < def.price then
		return { ok = false, reason = "not_enough_coins" }
	end
	subject.coins -= def.price
	subject.house.decor.owned[id] = true
	return { ok = true, reason = nil }
end

-- Places an owned decoration on a place; a decoration stands in one place at a
-- time, and the decoration that stood there before steps down. Fails with
-- "not_owned" or "bad_slot".
function House.place(subject: Subject, config: Config, id: string, slot: number): Result
	local decor = subject.house.decor
	if decor.owned[id] ~= true then
		return { ok = false, reason = "not_owned" }
	end
	if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > House.decorSlots(config, subject.house.level) then
		return { ok = false, reason = "bad_slot" }
	end
	for index = #decor.placed, 1, -1 do
		local entry = decor.placed[index]
		if entry.id == id or entry.slot == slot then
			table.remove(decor.placed, index)
		end
	end
	table.insert(decor.placed, { slot = slot, id = id })
	return { ok = true, reason = nil }
end

-- Takes the decoration from a place back (it stays owned). Fails with "empty_slot".
function House.remove(subject: Subject, slot: number): Result
	local decor = subject.house.decor
	for index, entry in decor.placed do
		if entry.slot == slot then
			table.remove(decor.placed, index)
			return { ok = true, reason = nil }
		end
	end
	return { ok = false, reason = "empty_slot" }
end

function House.view(subject: Subject, config: Config): View
	local level = subject.house.level
	local nextCost: number? = if level < config.maxLevel then config.upgradeCosts[level + 1] else nil
	local decor = subject.house.decor
	local items: { ItemView } = {}
	for _, id in config.order do
		table.insert(items, {
			id = id,
			price = config.items[id].price,
			owned = decor.owned[id] == true,
			placedSlot = placedSlotOf(decor, id),
		})
	end
	local placed: { Placed } = {}
	local slots = House.decorSlots(config, level)
	for _, entry in decor.placed do
		-- A place beyond the current level (never happens) is not shown.
		if entry.slot <= slots and config.items[entry.id] ~= nil then
			table.insert(placed, { slot = entry.slot, id = entry.id })
		end
	end
	table.sort(placed, function(a, b)
		return a.slot < b.slot
	end)
	return {
		level = level,
		maxLevel = config.maxLevel,
		nextCost = nextCost,
		canUpgrade = nextCost ~= nil and subject.coins >= nextCost,
		decorSlots = slots,
		items = items,
		placed = placed,
	}
end

return House
