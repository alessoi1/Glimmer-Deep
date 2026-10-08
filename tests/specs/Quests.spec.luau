--!strict
local Framework = require("../Framework")
local QuestConfig = require("../../src/shared/Config/Quests")
local Quests = require("../../src/shared/Quests")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals

local pool = QuestConfig.pool
local DAY = 19000

local function fresh(): Quests.State
	return Quests.new()
end

-- Config ---------------------------------------------------------------------------

test("the shipped quest pool is valid", function()
	local ok, reason = Quests.validatePool(pool, QuestConfig.perDay)
	assertTrue(ok, reason)
end)

test("every quest of the shipped pool counts a known event", function()
	local known: { [string]: boolean } = {}
	for _, event in Quests.events do
		known[event] = true
	end
	for _, def in pool do
		assertTrue(known[def.event], def.id .. " counts the unknown event " .. def.event)
	end
end)

test("validatePool rejects duplicate ids and events, bad targets and too few quests", function()
	local function copyWith(entries: { Quests.QuestDef }): { Quests.QuestDef }
		return entries
	end
	local a = { id = "a", event = "dig", target = 5, reward = 10 }
	local b = { id = "b", event = "sold", target = 5, reward = 10 }
	assertTrue(not Quests.validatePool(copyWith({ a, { id = "a", event = "sold", target = 1, reward = 1 } }), 2))
	assertTrue(not Quests.validatePool(copyWith({ a, { id = "b", event = "dig", target = 1, reward = 1 } }), 2))
	assertTrue(not Quests.validatePool(copyWith({ a, { id = "b", event = "sold", target = 0, reward = 1 } }), 2))
	assertTrue(not Quests.validatePool(copyWith({ a, { id = "b", event = "sold", target = 1, reward = -1 } }), 2))
	assertTrue(not Quests.validatePool(copyWith({ a, b }), 3), "perDay larger than the pool")
	assertTrue(Quests.validatePool(copyWith({ a, b }), 2))
end)

-- Picking the daily quests ----------------------------------------------------------

test("a new day picks distinct quests from the pool", function()
	local state = fresh()
	assertTrue(Quests.refresh(state, pool, QuestConfig.perDay, DAY, 42))
	assertEquals(state.day, DAY)
	assertEquals(#state.ids, QuestConfig.perDay)
	local seen: { [string]: boolean } = {}
	for _, id in state.ids do
		assertTrue(not seen[id], "duplicate quest " .. id)
		seen[id] = true
		local found = false
		for _, def in pool do
			found = found or def.id == id
		end
		assertTrue(found, id .. " is not in the pool")
	end
end)

test("the same day and player always get the same quests", function()
	local a, b = fresh(), fresh()
	Quests.refresh(a, pool, 3, DAY, 7)
	Quests.refresh(b, pool, 3, DAY, 7)
	assertTrue(Framework.deepEqual(a.ids, b.ids))
end)

test("other days and other players get other quests (not always, but over many)", function()
	local distinct: { [string]: boolean } = {}
	for day = DAY, DAY + 20 do
		local state = fresh()
		Quests.refresh(state, pool, 3, day, 7)
		distinct[table.concat(state.ids, ",")] = true
	end
	assertTrue(next(distinct, next(distinct)) ~= nil, "the quests never change from day to day")
end)

test("refreshing on the same day changes nothing", function()
	local state = fresh()
	Quests.refresh(state, pool, 3, DAY, 7)
	local def = Quests.find(pool, state.ids[1]) :: Quests.QuestDef
	Quests.record(state, pool, def.event, 1)
	local progress = state.progress[def.id]
	assertEquals(Quests.refresh(state, pool, 3, DAY, 7), false)
	assertEquals(state.progress[def.id], progress)
end)

test("a new day clears progress, claims and the bonus", function()
	local state = fresh()
	Quests.refresh(state, pool, 3, DAY, 7)
	local def = Quests.find(pool, state.ids[1]) :: Quests.QuestDef
	Quests.record(state, pool, def.event, def.target)
	Quests.claim(state, pool, def.id)
	state.bonusClaimed = true
	assertTrue(Quests.refresh(state, pool, 3, DAY + 1, 7))
	assertEquals(next(state.progress), nil)
	assertEquals(next(state.claimed), nil)
	assertEquals(state.bonusClaimed, false)
end)

-- Progress ---------------------------------------------------------------------------

local function stateWith(ids: { string }): Quests.State
	local state = fresh()
	state.day = DAY
	state.ids = ids
	return state
end

test("an event counts for the quests that listen to it", function()
	local state = stateWith({ "dig_blocks", "sell_trips" })
	Quests.record(state, pool, "dig", 10)
	Quests.record(state, pool, "dig", 5)
	assertEquals(state.progress.dig_blocks, 15)
	assertEquals(state.progress.sell_trips, nil)
end)

test("progress stops at the target", function()
	local state = stateWith({ "sell_trips" })
	Quests.record(state, pool, "sold", 100)
	assertEquals(state.progress.sell_trips, 3)
end)

test("events without a matching quest or with bad amounts change nothing", function()
	local state = stateWith({ "sell_trips" })
	Quests.record(state, pool, "dig", 5)
	Quests.record(state, pool, "sold", 0)
	Quests.record(state, pool, "sold", -3)
	Quests.record(state, pool, "sold", 0 / 0)
	assertEquals(next(state.progress), nil)
end)

test("record returns the quests that just reached their target", function()
	local state = stateWith({ "sell_trips", "find_mutation" })
	assertEquals(#Quests.record(state, pool, "sold", 2), 0)
	local done = Quests.record(state, pool, "sold", 1)
	assertEquals(#done, 1)
	assertEquals(done[1], "sell_trips")
	assertEquals(#Quests.record(state, pool, "sold", 1), 0, "already done")
end)

-- Claiming ---------------------------------------------------------------------------

test("a finished quest pays its reward once", function()
	local state = stateWith({ "sell_trips" })
	Quests.record(state, pool, "sold", 3)
	local result = Quests.claim(state, pool, "sell_trips")
	assertTrue(result.ok)
	assertEquals(result.coins, 150)
	local again = Quests.claim(state, pool, "sell_trips")
	assertTrue(not again.ok)
	assertEquals(again.reason, "already_claimed")
end)

test("an unfinished, unknown or not-picked quest cannot be claimed", function()
	local state = stateWith({ "sell_trips" })
	Quests.record(state, pool, "sold", 2)
	assertEquals(Quests.claim(state, pool, "sell_trips").reason, "not_done")
	assertEquals(Quests.claim(state, pool, "find_rare").reason, "not_picked")
	assertEquals(Quests.claim(state, pool, "nonsense").reason, "unknown_quest")
	assertEquals(Quests.claim(state, pool, 5 :: any).reason, "unknown_quest")
end)

test("the bonus is paid once after all quests of the day are claimed", function()
	local state = stateWith({ "sell_trips", "dig_blocks" })
	assertEquals(Quests.claimBonus(state, QuestConfig.allDoneBonus).reason, "not_done")
	Quests.record(state, pool, "sold", 3)
	Quests.record(state, pool, "dig", 150)
	Quests.claim(state, pool, "sell_trips")
	assertEquals(Quests.claimBonus(state, QuestConfig.allDoneBonus).reason, "not_done")
	Quests.claim(state, pool, "dig_blocks")
	local result = Quests.claimBonus(state, QuestConfig.allDoneBonus)
	assertTrue(result.ok)
	assertEquals(result.coins, QuestConfig.allDoneBonus)
	assertEquals(Quests.claimBonus(state, QuestConfig.allDoneBonus).reason, "already_claimed")
end)

-- View -----------------------------------------------------------------------------------

test("the view lists the quests with progress and state", function()
	local state = stateWith({ "sell_trips", "dig_blocks" })
	Quests.record(state, pool, "sold", 3)
	Quests.record(state, pool, "dig", 20)
	Quests.claim(state, pool, "sell_trips")
	local view = Quests.view(state, pool, QuestConfig.allDoneBonus)
	assertEquals(#view.quests, 2)
	assertEquals(view.quests[1].id, "sell_trips")
	assertEquals(view.quests[1].progress, 3)
	assertEquals(view.quests[1].done, true)
	assertEquals(view.quests[1].claimed, true)
	assertEquals(view.quests[2].progress, 20)
	assertEquals(view.quests[2].done, false)
	assertEquals(view.bonus, QuestConfig.allDoneBonus)
	assertEquals(view.bonusClaimable, false)
	assertEquals(view.bonusClaimed, false)
end)
