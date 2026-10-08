--!strict
-- Pure time slots from server time (os.time, UTC seconds). Days, weeks and
-- slots are counted from the Unix epoch, so every server agrees. Never use a
-- time that comes from a client.

local SECONDS_PER_DAY = 86400
local SECONDS_PER_WEEK = 7 * SECONDS_PER_DAY

local Calendar = {
	secondsPerDay = SECONDS_PER_DAY,
	secondsPerWeek = SECONDS_PER_WEEK,
}

function Calendar.dayOf(now: number): number
	return math.floor(now / SECONDS_PER_DAY)
end

function Calendar.weekOf(now: number): number
	return math.floor(now / SECONDS_PER_WEEK)
end

-- Index of the slot of `length` seconds that contains `now`.
function Calendar.slotOf(now: number, length: number): number
	return math.floor(now / length)
end

function Calendar.secondsUntilNextDay(now: number): number
	return SECONDS_PER_DAY - now % SECONDS_PER_DAY
end

function Calendar.secondsUntilNextWeek(now: number): number
	return SECONDS_PER_WEEK - now % SECONDS_PER_WEEK
end

return Calendar
