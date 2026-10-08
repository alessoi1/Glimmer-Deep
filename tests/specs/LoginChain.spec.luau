--!strict
local Framework = require("../Framework")
local LoginChain = require("../../src/shared/LoginChain")
local QuestConfig = require("../../src/shared/Config/Quests")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals

local rewards = QuestConfig.login.rewards
local DAY = 19000

test("the shipped login rewards grow and fill a week", function()
	assertEquals(#rewards, 7)
	local previous = 0
	for _, reward in rewards do
		assertTrue(reward > previous and reward % 1 == 0)
		previous = reward
	end
end)

test("a first login starts the chain at day 1 with the reward open", function()
	local state = LoginChain.new()
	assertEquals(LoginChain.update(state, DAY, #rewards), "first")
	assertEquals(state.streak, 1)
	assertEquals(state.lastDay, DAY)
	assertEquals(state.claimed, false)
end)

test("a login on the next day continues the chain", function()
	local state = LoginChain.new()
	LoginChain.update(state, DAY, #rewards)
	LoginChain.claim(state, rewards)
	assertEquals(LoginChain.update(state, DAY + 1, #rewards), "next")
	assertEquals(state.streak, 2)
	assertEquals(state.claimed, false)
end)

test("after the last day the chain starts again at day 1", function()
	local state = { lastDay = DAY, streak = #rewards, claimed = true }
	assertEquals(LoginChain.update(state, DAY + 1, #rewards), "next")
	assertEquals(state.streak, 1)
end)

test("a missed day sets the chain back by one day, not to zero", function()
	local state = { lastDay = DAY, streak = 5, claimed = true }
	assertEquals(LoginChain.update(state, DAY + 3, #rewards), "missed")
	assertEquals(state.streak, 4)
	assertEquals(state.lastDay, DAY + 3)
end)

test("a missed day never drops below day 1", function()
	local state = { lastDay = DAY, streak = 1, claimed = true }
	LoginChain.update(state, DAY + 10, #rewards)
	assertEquals(state.streak, 1)
end)

test("logging in again on the same day changes nothing", function()
	local state = LoginChain.new()
	LoginChain.update(state, DAY, #rewards)
	LoginChain.claim(state, rewards)
	assertEquals(LoginChain.update(state, DAY, #rewards), "same")
	assertEquals(state.streak, 1)
	assertEquals(state.claimed, true)
end)

test("a clock that went backwards changes nothing", function()
	local state = { lastDay = DAY, streak = 3, claimed = false }
	assertEquals(LoginChain.update(state, DAY - 2, #rewards), "same")
	assertEquals(state.streak, 3)
	assertEquals(state.lastDay, DAY)
end)

test("the reward of the day is paid once", function()
	local state = LoginChain.new()
	LoginChain.update(state, DAY, #rewards)
	local result = LoginChain.claim(state, rewards)
	assertTrue(result.ok)
	assertEquals(result.coins, rewards[1])
	local again = LoginChain.claim(state, rewards)
	assertTrue(not again.ok)
	assertEquals(again.reason, "already_claimed")
end)

test("there is nothing to claim before the first login", function()
	local result = LoginChain.claim(LoginChain.new(), rewards)
	assertTrue(not result.ok)
end)

test("the view shows the day, the reward and whether it can be claimed", function()
	local state = { lastDay = DAY, streak = 3, claimed = false }
	local view = LoginChain.view(state, rewards)
	assertEquals(view.streak, 3)
	assertEquals(view.reward, rewards[3])
	assertEquals(view.claimable, true)
	assertEquals(view.chainLength, 7)
	state.claimed = true
	assertEquals(LoginChain.view(state, rewards).claimable, false)
end)
