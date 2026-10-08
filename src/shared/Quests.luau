--!strict
-- Pure daily quest logic: picking the quests of a day, counting progress from
-- game events, claiming rewards. No Roblox services and no logging; the
-- QuestService feeds in the events and the server day (Calendar.dayOf) and logs
-- the outcome. The state is changed in place. Server-side only use.

export type QuestDef = {
	id: string,
	event: string, -- the game event this quest counts
	target: number,
	reward: number, -- coins
}

-- Stored in the profile. Progress and claims are keyed by quest id.
export type State = {
	day: number, -- Calendar.dayOf of the day the quests were picked for
	ids: { string },
	progress: { [string]: number },
	claimed: { [string]: boolean },
	bonusClaimed: boolean, -- the all-done bonus of the day
}

export type ClaimResult = {
	ok: boolean,
	reason: ("unknown_quest" | "not_picked" | "already_claimed" | "not_done")?,
	coins: number,
}

export type QuestView = {
	id: string,
	event: string,
	target: number,
	progress: number,
	reward: number,
	done: boolean,
	claimed: boolean,
}

export type View = {
	quests: { QuestView },
	bonus: number,
	bonusClaimable: boolean,
	bonusClaimed: boolean,
}

local Quests = {
	-- The events the game reports; the quest pool refers to them by name.
	events = {
		dig = "dig",
		backpackFilled = "backpackFilled",
		mutation = "mutation",
		rare = "rare",
		sold = "sold",
		upgraded = "upgraded",
		displayed = "displayed",
		collected = "collected",
	},
}

local function isPositiveInteger(value: any): boolean
	return type(value) == "number" and value >= 1 and value < math.huge and value % 1 == 0
end

function Quests.new(): State
	return { day = 0, ids = {}, progress = {}, claimed = {}, bonusClaimed = false }
end

function Quests.find(pool: { QuestDef }, questId: any): QuestDef?
	for _, def in pool do
		if def.id == questId then
			return def
		end
	end
	return nil
end

-- Returns true when the pool is usable, otherwise false and a reason.
function Quests.validatePool(pool: { QuestDef }, perDay: number): (boolean, string?)
	if #pool < perDay or perDay < 1 then
		return false, "the pool needs at least perDay quests"
	end
	local ids: { [string]: boolean } = {}
	local events: { [string]: boolean } = {}
	for _, def in pool do
		if ids[def.id] then
			return false, "duplicate quest id " .. def.id
		end
		ids[def.id] = true
		if events[def.event] then
			return false, "event " .. def.event .. " is used by two quests"
		end
		events[def.event] = true
		if not isPositiveInteger(def.target) then
			return false, def.id .. " needs a positive integer target"
		end
		if type(def.reward) ~= "number" or def.reward < 0 or def.reward % 1 ~= 0 then
			return false, def.id .. " needs a non-negative integer reward"
		end
	end
	return true, nil
end

-- Park-Miller generator, so the same day and player always pick the same quests.
local function sequence(seed: number): () -> number
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function(): number
		state = (state * 48271) % 2147483647
		return state
	end
end

-- Picks the quests for `day` when the state is from another day (clearing all
-- progress, claims and the bonus). `salt` (for example the user id) makes the
-- picks differ between players. Returns true when new quests were picked.
function Quests.refresh(state: State, pool: { QuestDef }, perDay: number, day: number, salt: number): boolean
	if state.day == day then
		return false
	end
	local next = sequence(day * 7919 + salt)
	local candidates: { string } = {}
	for _, def in pool do
		table.insert(candidates, def.id)
	end
	-- Fisher-Yates shuffle, then take the first perDay.
	for index = #candidates, 2, -1 do
		local other = next() % index + 1
		candidates[index], candidates[other] = candidates[other], candidates[index]
	end
	local ids: { string } = {}
	for index = 1, math.min(perDay, #candidates) do
		table.insert(ids, candidates[index])
	end

	state.day = day
	state.ids = ids
	state.progress = {}
	state.claimed = {}
	state.bonusClaimed = false
	return true
end

-- Counts an event for the quests of the day. Returns the ids of the quests that
-- just reached their target.
function Quests.record(state: State, pool: { QuestDef }, event: string, amount: number): { string }
	local reached: { string } = {}
	if type(amount) ~= "number" or not (amount > 0) or amount == math.huge then
		return reached
	end
	for _, questId in state.ids do
		local def = Quests.find(pool, questId)
		if def ~= nil and def.event == event then
			local before = state.progress[questId] or 0
			if before < def.target then
				local after = math.min(before + amount, def.target)
				state.progress[questId] = after
				if after >= def.target then
					table.insert(reached, questId)
				end
			end
		end
	end
	return reached
end

-- Pays the reward of a finished quest once. `questId` is untrusted client input.
function Quests.claim(state: State, pool: { QuestDef }, questId: any): ClaimResult
	local def = Quests.find(pool, questId)
	if def == nil then
		return { ok = false, reason = "unknown_quest", coins = 0 }
	end
	if not table.find(state.ids, def.id) then
		return { ok = false, reason = "not_picked", coins = 0 }
	end
	if state.claimed[def.id] then
		return { ok = false, reason = "already_claimed", coins = 0 }
	end
	if (state.progress[def.id] or 0) < def.target then
		return { ok = false, reason = "not_done", coins = 0 }
	end
	state.claimed[def.id] = true
	return { ok = true, reason = nil, coins = def.reward }
end

local function allClaimed(state: State): boolean
	if #state.ids == 0 then
		return false
	end
	for _, questId in state.ids do
		if not state.claimed[questId] then
			return false
		end
	end
	return true
end

-- Pays the bonus for claiming all quests of the day, once.
function Quests.claimBonus(state: State, bonus: number): ClaimResult
	if state.bonusClaimed then
		return { ok = false, reason = "already_claimed", coins = 0 }
	end
	if not allClaimed(state) then
		return { ok = false, reason = "not_done", coins = 0 }
	end
	state.bonusClaimed = true
	return { ok = true, reason = nil, coins = bonus }
end

-- Everything the quest panel shows.
function Quests.view(state: State, pool: { QuestDef }, bonus: number): View
	local quests: { QuestView } = {}
	for _, questId in state.ids do
		local def = Quests.find(pool, questId)
		if def ~= nil then
			local progress = state.progress[questId] or 0
			table.insert(quests, {
				id = def.id,
				event = def.event,
				target = def.target,
				progress = progress,
				reward = def.reward,
				done = progress >= def.target,
				claimed = state.claimed[questId] == true,
			})
		end
	end
	return {
		quests = quests,
		bonus = bonus,
		bonusClaimable = not state.bonusClaimed and allClaimed(state),
		bonusClaimed = state.bonusClaimed,
	}
end

return Quests
