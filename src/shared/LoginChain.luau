--!strict
-- Pure login chain: a reward for every day in a row, up to a week. A missed day
-- sets the chain back by one day instead of to zero. Days come from the server
-- (Calendar.dayOf). No Roblox services; the state is changed in place.

export type State = {
	lastDay: number, -- day of the last login, 0 = never
	streak: number, -- day of the chain, 0 = never logged in
	claimed: boolean, -- the reward of lastDay has been paid
}

export type Change = "first" | "next" | "missed" | "same"

export type ClaimResult = {
	ok: boolean,
	reason: ("already_claimed" | "no_login")?,
	coins: number,
}

export type View = {
	streak: number,
	reward: number,
	claimable: boolean,
	chainLength: number,
}

local LoginChain = {}

function LoginChain.new(): State
	return { lastDay = 0, streak = 0, claimed = true }
end

-- Registers a login on `today`. Returns what happened: the first login ever, the
-- next day of the chain, a login after missed days (chain one day back) or a
-- login on a day that was already counted (also when the clock went backwards).
function LoginChain.update(state: State, today: number, chainLength: number): Change
	if today <= state.lastDay and state.lastDay ~= 0 then
		return "same"
	end
	local change: Change
	if state.lastDay == 0 then
		state.streak = 1
		change = "first"
	elseif today == state.lastDay + 1 then
		state.streak = state.streak % chainLength + 1
		change = "next"
	else
		state.streak = math.max(1, state.streak - 1)
		change = "missed"
	end
	state.lastDay = today
	state.claimed = false
	return change
end

-- Pays the reward of today's chain day once.
function LoginChain.claim(state: State, rewards: { number }): ClaimResult
	if state.streak < 1 then
		return { ok = false, reason = "no_login", coins = 0 }
	end
	if state.claimed then
		return { ok = false, reason = "already_claimed", coins = 0 }
	end
	state.claimed = true
	return { ok = true, reason = nil, coins = rewards[state.streak] or 0 }
end

function LoginChain.view(state: State, rewards: { number }): View
	return {
		streak = state.streak,
		reward = rewards[state.streak] or 0,
		claimable = state.streak >= 1 and not state.claimed,
		chainLength = #rewards,
	}
end

return LoginChain
