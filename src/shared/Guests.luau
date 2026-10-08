--!strict
-- Pure guest logic: who digs on whose plot, the guest limit, and the coins a
-- host gets for the blocks of the guests (with a daily cap). Players are
-- identified by user id only. No Roblox services; the GuestService asks Roblox
-- for friendship and positions and calls this.

export type Config = {
	maxGuests: number,
	hostCoinsPerBlock: number,
	hostDailyCap: number,
	friendsOnly: boolean,
	promptDistance: number,
	joinDistance: number,
	joinCooldown: number,
}

export type Registry = {
	-- Makes `guest` a guest of `host`. Fails with "own_plot", "already_guest",
	-- "not_friends" or "full".
	join: (guest: number, host: number, areFriends: boolean) -> (boolean, string?),
	-- Ends the guest's visit. Returns the host it left, or nil.
	leave: (guest: number) -> number?,
	-- Removes a player in both roles (leaving the server). Returns the guests
	-- that lost their host.
	forget: (userId: number) -> { number },
	hostOf: (guest: number) -> number?,
	guestsOf: (host: number) -> { number },
	-- Coins the host gets for one block of a guest on `day` (UTC day number),
	-- already counted against the daily cap. 0 when the cap is reached.
	creditBlock: (host: number, day: number) -> number,
	earnedToday: (host: number, day: number) -> number,
}

local Guests = {}

-- Returns true when the config is usable, otherwise false and a reason.
function Guests.validateConfig(config: Config): (boolean, string?)
	for _, field in { "maxGuests", "hostCoinsPerBlock", "hostDailyCap" } do
		local value = (config :: any)[field]
		if type(value) ~= "number" or value < 1 or value % 1 ~= 0 or value == math.huge then
			return false, field .. " must be a positive integer"
		end
	end
	if type(config.friendsOnly) ~= "boolean" then
		return false, "friendsOnly must be a boolean"
	end
	for _, field in { "promptDistance", "joinDistance", "joinCooldown" } do
		local value = (config :: any)[field]
		if type(value) ~= "number" or value <= 0 or value == math.huge then
			return false, field .. " must be positive"
		end
	end
	return true, nil
end

function Guests.new(config: Config): Registry
	local hostOfGuest: { [number]: number } = {}
	local guestsOfHost: { [number]: { number } } = {}
	local earned: { [number]: { day: number, coins: number } } = {}

	local function guestsOf(host: number): { number }
		return table.clone(guestsOfHost[host] or {})
	end

	local function leave(guest: number): number?
		local host = hostOfGuest[guest]
		if host == nil then
			return nil
		end
		hostOfGuest[guest] = nil
		local list = guestsOfHost[host]
		if list ~= nil then
			local index = table.find(list, guest)
			if index ~= nil then
				table.remove(list, index)
			end
			if #list == 0 then
				guestsOfHost[host] = nil
			end
		end
		return host
	end

	local function join(guest: number, host: number, areFriends: boolean): (boolean, string?)
		if guest == host then
			return false, "own_plot"
		end
		if hostOfGuest[guest] ~= nil then
			return false, "already_guest"
		end
		if config.friendsOnly and not areFriends then
			return false, "not_friends"
		end
		local list = guestsOfHost[host]
		if list ~= nil and #list >= config.maxGuests then
			return false, "full"
		end
		if list == nil then
			list = {}
			guestsOfHost[host] = list
		end
		table.insert(list, guest)
		hostOfGuest[guest] = host
		return true, nil
	end

	local function forget(userId: number): { number }
		leave(userId)
		local orphaned = guestsOf(userId)
		for _, guest in orphaned do
			hostOfGuest[guest] = nil
		end
		guestsOfHost[userId] = nil
		earned[userId] = nil
		return orphaned
	end

	local function earnedToday(host: number, day: number): number
		local entry = earned[host]
		if entry == nil or entry.day ~= day then
			return 0
		end
		return entry.coins
	end

	local function creditBlock(host: number, day: number): number
		local so = earnedToday(host, day)
		local coins = math.min(config.hostCoinsPerBlock, config.hostDailyCap - so)
		if coins <= 0 then
			return 0
		end
		earned[host] = { day = day, coins = so + coins }
		return coins
	end

	return {
		join = join,
		leave = leave,
		forget = forget,
		hostOf = function(guest: number): number?
			return hostOfGuest[guest]
		end,
		guestsOf = guestsOf,
		creditBlock = creditBlock,
		earnedToday = earnedToday,
	}
end

return Guests
