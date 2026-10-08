--!strict
-- Pure text building for the guest line on screen. No Roblox services; the
-- client displays what this returns.

export type Strings = {
	guests: {
		hosting: string,
		guestOf: string,
		earned: string,
		notFriends: string,
		full: string,
		ownPlot: string,
		tooFar: string,
		unknown: string,
	},
}

export type Status = {
	role: string, -- "host", "guest" or "none"
	names: { string }?, -- the guests (role host)
	hostName: string?, -- the host (role guest)
	earnedToday: number?, -- coins from guests today (role host)
}

local GuestMessages = {}

-- The permanent line while someone hosts or visits; empty text for "none".
function GuestMessages.statusText(strings: Strings, status: Status): string
	if status.role == "host" and status.names ~= nil and #status.names > 0 then
		local text = string.format(strings.guests.hosting, table.concat(status.names, ", "))
		if status.earnedToday ~= nil and status.earnedToday > 0 then
			text ..= " " .. string.format(strings.guests.earned, status.earnedToday)
		end
		return text
	elseif status.role == "guest" and status.hostName ~= nil then
		return string.format(strings.guests.guestOf, status.hostName)
	end
	return ""
end

-- Message when joining failed; unknown reasons give a neutral text.
function GuestMessages.describeReason(strings: Strings, reason: string?): string
	if reason == "not_friends" then
		return strings.guests.notFriends
	elseif reason == "full" then
		return strings.guests.full
	elseif reason == "own_plot" then
		return strings.guests.ownPlot
	elseif reason == "too_far" then
		return strings.guests.tooFar
	end
	return strings.guests.unknown
end

return GuestMessages
