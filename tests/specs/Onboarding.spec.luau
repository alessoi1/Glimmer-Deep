--!strict
local Framework = require("../Framework")
local Onboarding = require("../../src/shared/Onboarding")
local OnboardingConfig = require("../../src/shared/Config/Onboarding")
local Mutations = require("../../src/shared/Config/Mutations")
local BackpackConfig = require("../../src/shared/Config/Backpack")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals

test("a new player starts at step 1 and has not received the first find", function()
	local state = Onboarding.new()
	assertEquals(state.step, 1)
	assertEquals(state.firstFindGiven, false)
	assertTrue(not Onboarding.isDone(state))
end)

test("an existing player counts as done", function()
	local state = Onboarding.completed()
	assertTrue(Onboarding.isDone(state))
	assertEquals(state.firstFindGiven, true)
	assertEquals(state.step, Onboarding.maxStep)
end)

test("events move the steps forward in the intended order", function()
	local state = Onboarding.new()
	assertTrue(Onboarding.advance(state, "dug"))
	assertEquals(state.step, 2)
	assertTrue(Onboarding.advance(state, "found"))
	assertEquals(state.step, 3)
	assertTrue(Onboarding.advance(state, "sold"))
	assertEquals(state.step, 4)
	assertTrue(Onboarding.advance(state, "upgraded"))
	assertEquals(state.step, 5)
	assertTrue(Onboarding.advance(state, "displayed"))
	assertEquals(state.step, 6)
	assertTrue(Onboarding.advance(state, "dug"))
	assertEquals(state.step, 7)
	assertTrue(Onboarding.isDone(state))
end)

test("events never move the step backwards or repeat", function()
	local state = Onboarding.new()
	Onboarding.advance(state, "sold")
	assertEquals(state.step, 4)
	assertEquals(Onboarding.advance(state, "dug"), false)
	assertEquals(Onboarding.advance(state, "found"), false)
	assertEquals(state.step, 4)
	assertEquals(Onboarding.advance(state, "sold"), false)
end)

test("events can skip steps when the player acts out of order", function()
	local state = Onboarding.new()
	assertTrue(Onboarding.advance(state, "upgraded"))
	assertEquals(state.step, 5)
end)

test("a dig only finishes the onboarding after the museum step", function()
	local state = Onboarding.new()
	state.step = 5
	assertEquals(Onboarding.advance(state, "dug"), false)
	assertEquals(state.step, 5)
end)

test("unknown events are ignored", function()
	local state = Onboarding.new()
	assertEquals(Onboarding.advance(state, "nonsense" :: any), false)
	assertEquals(state.step, 1)
end)

test("the shipped onboarding config is consistent", function()
	assertTrue(OnboardingConfig.firstFindAfterBlocks >= 1)
	assertTrue(OnboardingConfig.firstFindAfterBlocks < BackpackConfig.startCapacity)
	local found = false
	for _, mutation in Mutations do
		if mutation.id == OnboardingConfig.firstFindMutation then
			found = true
		end
	end
	assertTrue(found, "firstFindMutation must be a configured mutation")
end)
