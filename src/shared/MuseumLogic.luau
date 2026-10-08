--!strict
-- Pure museum logic: showcases, visitor income, layer sets and admiration.
-- No Roblox services and no logging; the MuseumService decides who may do what
-- and logs the outcome. The profile is changed in place. Server-side only use.
--
-- A showcase holds one rare find, moved out of the backpack. Visitors pay a
-- fraction of the displayed values per hour; the income is paid out whenever
-- the player collects it or changes a showcase (so the time before a change is
-- never lost or applied to the wrong set of finds).

local Backpack = require("./Backpack")
local Onboarding = require("./Onboarding")

export type Find = Backpack.Find

export type Display = { slot: number, find: Find }

export type Museum = {
	displays: { Display },
	incomeSince: number, -- server time from which the income is counted
	admires: number, -- total admirations received
	week: number, -- week of weekAdmires (Calendar.weekOf)
	weekAdmires: number,
}

export type MuseumProfile = {
	coins: number,
	backpack: { ores: { [string]: number }, finds: { Find } },
	depot: { ores: { [string]: number }, finds: { Find } },
	museum: Museum,
	onboarding: Onboarding.State,
}

export type Config = {
	incomePerHourFraction: number,
	incomeMaxHours: number,
	setCoinBonus: number,
	setLuckBonus: number,
}

export type Context = {
	now: number, -- server time in seconds
	slotCount: number,
	config: Config,
	coinMultiplier: number,
	backpackCapacity: number,
}

export type FailureReason =
	"bad_input"
	| "bad_slot"
	| "no_such_find"
	| "slot_taken"
	| "empty_slot"
	| "backpack_full"
	| "nothing_to_collect"

export type Result = { ok: boolean, reason: FailureReason? }
export type CollectResult = { ok: boolean, reason: FailureReason?, coins: number }

export type LayerDef = { id: string, finds: { string } }
export type SetProgress = { layerId: string, have: number, need: number, complete: boolean }

export type View = {
	slotCount: number,
	displays: { Display },
	backpackFinds: { Find },
	sets: { SetProgress },
	pendingIncome: number,
	incomePerHour: number,
	incomeMaxHours: number,
	admires: number,
	weekAdmires: number,
}

-- Guards float rounding such as 0.1 * 3 = 0.30000000000000004.
local ROUNDING_EPSILON = 1e-9
local SECONDS_PER_HOUR = 3600

local MuseumLogic = {}

local function isInteger(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge and value % 1 == 0
end

local function copyFind(find: Find): Find
	return {
		id = find.id,
		findId = find.findId,
		layerId = find.layerId,
		rarityId = find.rarityId,
		mutationId = find.mutationId,
		value = find.value,
	}
end

-- Showcases of a house level, clamped to the configured levels.
function MuseumLogic.slotCount(slotsByHouseLevel: { number }, houseLevel: number): number
	local index = 1
	if houseLevel == houseLevel then
		index = math.clamp(math.floor(houseLevel), 1, #slotsByHouseLevel)
	end
	return slotsByHouseLevel[index]
end

local function incomeRate(museum: Museum, config: Config): number
	local total = 0
	for _, display in museum.displays do
		total += display.find.value
	end
	return total * config.incomePerHourFraction
end

-- Coins per hour for display (rounded down).
function MuseumLogic.incomePerHour(museum: Museum, config: Config, coinMultiplier: number): number
	return math.floor(incomeRate(museum, config) * coinMultiplier + ROUNDING_EPSILON)
end

-- Income earned since the last payout, limited to the maximum hours.
function MuseumLogic.pendingIncome(museum: Museum, now: number, config: Config, coinMultiplier: number): number
	local elapsed = now - museum.incomeSince
	if not (elapsed > 0) then
		return 0
	end
	local hours = math.min(elapsed / SECONDS_PER_HOUR, config.incomeMaxHours)
	return math.floor(incomeRate(museum, config) * hours * coinMultiplier + ROUNDING_EPSILON)
end

-- Pays the pending income into the coins and restarts the timer. Returns the coins paid.
local function settle(profile: MuseumProfile, context: Context): number
	local museum = profile.museum
	local coins = MuseumLogic.pendingIncome(museum, context.now, context.config, context.coinMultiplier)
	profile.coins += coins
	if context.now > museum.incomeSince then
		museum.incomeSince = context.now
	end
	return coins
end

local function findDisplayIndex(museum: Museum, slot: number): number?
	for index, display in museum.displays do
		if display.slot == slot then
			return index
		end
	end
	return nil
end

-- Moves a find out of the backpack into a showcase. `findId` is the unique find
-- id (untrusted input from the client). On failure nothing is changed.
function MuseumLogic.display(profile: MuseumProfile, findId: any, slot: any, context: Context): Result
	if type(findId) ~= "number" or type(slot) ~= "number" then
		return { ok = false, reason = "bad_input" }
	end
	if not isInteger(slot) or slot < 1 or slot > context.slotCount then
		return { ok = false, reason = "bad_slot" }
	end

	-- The find is in the backpack or in the depot (offline yield).
	local source: { Find }? = nil
	local sourceIndex: number? = nil
	for _, finds in { profile.backpack.finds, profile.depot.finds } do
		for index, find in finds do
			if find.id == findId then
				source = finds
				sourceIndex = index
				break
			end
		end
		if source ~= nil then
			break
		end
	end
	if source == nil or sourceIndex == nil then
		return { ok = false, reason = "no_such_find" }
	end
	if findDisplayIndex(profile.museum, slot) ~= nil then
		return { ok = false, reason = "slot_taken" }
	end

	settle(profile, context)
	local find = table.remove(source, sourceIndex) :: Find
	table.insert(profile.museum.displays, { slot = slot, find = copyFind(find) })
	Onboarding.advance(profile.onboarding, "displayed")
	return { ok = true, reason = nil }
end

-- Moves the find of a showcase back into the backpack (needs a free slot there).
function MuseumLogic.remove(profile: MuseumProfile, slot: any, context: Context): Result
	if type(slot) ~= "number" then
		return { ok = false, reason = "bad_input" }
	end
	if not isInteger(slot) or slot < 1 or slot > context.slotCount then
		return { ok = false, reason = "bad_slot" }
	end

	local displayIndex = findDisplayIndex(profile.museum, slot)
	if displayIndex == nil then
		return { ok = false, reason = "empty_slot" }
	end
	local backpack: Backpack.Backpack = {
		capacity = context.backpackCapacity,
		ores = profile.backpack.ores,
		finds = profile.backpack.finds,
	}
	if Backpack.isFull(backpack) then
		return { ok = false, reason = "backpack_full" }
	end

	settle(profile, context)
	local display = table.remove(profile.museum.displays, displayIndex) :: Display
	table.insert(profile.backpack.finds, display.find)
	return { ok = true, reason = nil }
end

-- Pays out the visitor income.
function MuseumLogic.collect(profile: MuseumProfile, context: Context): CollectResult
	local coins = MuseumLogic.pendingIncome(profile.museum, context.now, context.config, context.coinMultiplier)
	if coins <= 0 then
		return { ok = false, reason = "nothing_to_collect", coins = 0 }
	end
	settle(profile, context)
	return { ok = true, reason = nil, coins = coins }
end

-- Progress of every layer set: how many find types of the layer are on display.
function MuseumLogic.setProgress(museum: Museum, layers: { LayerDef }): { SetProgress }
	local shown: { [string]: boolean } = {}
	for _, display in museum.displays do
		shown[display.find.layerId .. ":" .. display.find.findId] = true
	end
	local progress: { SetProgress } = {}
	for _, layer in layers do
		local have = 0
		for _, findId in layer.finds do
			if shown[layer.id .. ":" .. findId] then
				have += 1
			end
		end
		table.insert(progress, {
			layerId = layer.id,
			have = have,
			need = #layer.finds,
			complete = have == #layer.finds,
		})
	end
	return progress
end

function MuseumLogic.completedSets(museum: Museum, layers: { LayerDef }): { string }
	local completed = {}
	for _, entry in MuseumLogic.setProgress(museum, layers) do
		if entry.complete then
			table.insert(completed, entry.layerId)
		end
	end
	return completed
end

-- Bonuses of the completed sets, as a Modifiers part.
function MuseumLogic.modifierPart(
	museum: Museum,
	layers: { LayerDef },
	config: Config
): { coinBonus: number, luckBonus: number }
	local count = #MuseumLogic.completedSets(museum, layers)
	return { coinBonus = count * config.setCoinBonus, luckBonus = count * config.setLuckBonus }
end

-- Counts one admiration for the total and for the given week.
function MuseumLogic.admire(museum: Museum, week: number)
	if museum.week ~= week then
		museum.week = week
		museum.weekAdmires = 0
	end
	museum.admires += 1
	museum.weekAdmires += 1
end

-- Admirations in a week; an older stored week counts as zero.
function MuseumLogic.weeklyAdmires(museum: Museum, week: number): number
	if museum.week ~= week then
		return 0
	end
	return museum.weekAdmires
end

export type BoardEntry = { name: string, weekAdmires: number }

-- The most admired museums of the week: highest count first, ties by name;
-- museums without admirations are left out.
function MuseumLogic.board(entries: { BoardEntry }, size: number): { BoardEntry }
	local sorted: { BoardEntry } = {}
	for _, entry in entries do
		if entry.weekAdmires > 0 then
			table.insert(sorted, entry)
		end
	end
	table.sort(sorted, function(a: BoardEntry, b: BoardEntry)
		if a.weekAdmires ~= b.weekAdmires then
			return a.weekAdmires > b.weekAdmires
		end
		return a.name < b.name
	end)
	local top: { BoardEntry } = {}
	for index = 1, math.min(size, #sorted) do
		table.insert(top, { name = sorted[index].name, weekAdmires = sorted[index].weekAdmires })
	end
	return top
end

-- Everything the museum panel of the client shows.
function MuseumLogic.view(profile: MuseumProfile, layers: { LayerDef }, context: Context, week: number): View
	local displays: { Display } = {}
	for _, display in profile.museum.displays do
		table.insert(displays, { slot = display.slot, find = copyFind(display.find) })
	end
	table.sort(displays, function(a: Display, b: Display)
		return a.slot < b.slot
	end)
	local backpackFinds: { Find } = {}
	for _, find in profile.backpack.finds do
		table.insert(backpackFinds, copyFind(find))
	end
	for _, find in profile.depot.finds do
		table.insert(backpackFinds, copyFind(find))
	end
	return {
		slotCount = context.slotCount,
		displays = displays,
		backpackFinds = backpackFinds,
		sets = MuseumLogic.setProgress(profile.museum, layers),
		pendingIncome = MuseumLogic.pendingIncome(profile.museum, context.now, context.config, context.coinMultiplier),
		incomePerHour = MuseumLogic.incomePerHour(profile.museum, context.config, context.coinMultiplier),
		incomeMaxHours = context.config.incomeMaxHours,
		admires = profile.museum.admires,
		weekAdmires = MuseumLogic.weeklyAdmires(profile.museum, week),
	}
end

return MuseumLogic
