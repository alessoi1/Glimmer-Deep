--!strict
-- Pure onboarding progress: which hint the player sees in the first minutes.
-- The server advances the step when the matching thing happens (a dig, a rare
-- find, a sale, an upgrade, a museum display); the client only shows the hint
-- for the step. No Roblox services.
--
-- Steps: 1 dig, 2 keep digging until the first find, 3 sell, 4 buy an upgrade,
-- 5 display a find in the museum, 6 "the digger keeps working", 7 done.

export type State = {
	step: number,
	firstFindGiven: boolean, -- the guaranteed first rare find has been handed out
}

export type Event = "dug" | "found" | "sold" | "upgraded" | "displayed"

local MAX_STEP = 7
local LAST_HINT_STEP = 6

-- Step a player is at once the event has happened (never moves backwards).
local STEP_AFTER: { [string]: number } = {
	dug = 2,
	found = 3,
	sold = 4,
	upgraded = 5,
	displayed = 6,
}

local Onboarding = {
	maxStep = MAX_STEP,
	lastHintStep = LAST_HINT_STEP,
}

function Onboarding.new(): State
	return { step = 1, firstFindGiven = false }
end

-- State for players who already played before the onboarding existed.
function Onboarding.completed(): State
	return { step = MAX_STEP, firstFindGiven = true }
end

function Onboarding.isDone(state: State): boolean
	return state.step >= MAX_STEP
end

-- Moves the step forward for an event. Returns true when the step changed.
function Onboarding.advance(state: State, event: Event): boolean
	if event == "dug" and state.step == LAST_HINT_STEP then
		-- The last hint stays until the next dig, then the onboarding ends.
		state.step = MAX_STEP
		return true
	end
	local target = STEP_AFTER[event]
	if target == nil or target <= state.step then
		return false
	end
	state.step = target
	return true
end

return Onboarding
