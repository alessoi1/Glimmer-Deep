--!strict
-- Pure weekly event logic: which event runs now (from server time only), how
-- long it still runs and what it gives. No Roblox services.

local Calendar = require("./Calendar")
local Modifiers = require("./Modifiers")

export type MutationBoost = { id: string, factor: number }

export type EventDef = {
	mutation: MutationBoost?,
	bonus: Modifiers.Part?,
	hostCoinFactor: number?,
}

export type Config = {
	rotation: { string },
	events: { [string]: EventDef },
}

export type Current = {
	id: string,
	def: EventDef,
	week: number,
	secondsLeft: number, -- until the event ends (the next week starts)
}

-- What the client shows about the running event.
export type Info = {
	id: string,
	secondsLeft: number,
	mutationId: string?,
	mutationFactor: number?,
	bonus: Modifiers.Part?,
	hostCoinFactor: number,
}

local Events = {}

-- Returns true when the config is usable, otherwise false and a reason. The
-- known mutation ids come from the dig config.
function Events.validateConfig(config: Config, mutationIds: { string }): (boolean, string?)
	if #config.rotation == 0 then
		return false, "rotation is empty"
	end
	for _, id in config.rotation do
		if config.events[id] == nil then
			return false, "rotation names the unknown event " .. id
		end
	end
	for id, def in config.events do
		if table.find(config.rotation, id) == nil then
			return false, id .. " is missing from the rotation"
		end
		if def.mutation ~= nil then
			if table.find(mutationIds, def.mutation.id) == nil then
				return false, id .. " boosts the unknown mutation " .. def.mutation.id
			end
			local factor = def.mutation.factor
			if type(factor) ~= "number" or factor < 1 or factor ~= factor or factor == math.huge then
				return false, id .. " needs a mutation factor of at least 1"
			end
		end
		for field, value in def.bonus or {} do
			if table.find(Modifiers.knownFields, field) == nil then
				return false, string.format("%s has the unknown bonus %s", id, tostring(field))
			end
			if type(value) ~= "number" or value <= 0 or value == math.huge then
				return false, string.format("%s needs a positive %s", id, tostring(field))
			end
		end
		local factor = def.hostCoinFactor
		if factor ~= nil and (type(factor) ~= "number" or factor < 1 or factor ~= factor or factor == math.huge) then
			return false, id .. " needs a hostCoinFactor of at least 1"
		end
	end
	return true, nil
end

-- The event running at server time `now` (UTC seconds).
function Events.current(config: Config, now: number): Current
	local week = Calendar.weekOf(now)
	local id = config.rotation[week % #config.rotation + 1]
	return {
		id = id,
		def = config.events[id],
		week = week,
		secondsLeft = (week + 1) * Calendar.secondsPerWeek - now,
	}
end

-- The bonus part of an event; nil when it has none.
function Events.modifierPart(def: EventDef): Modifiers.Part?
	return def.bonus
end

-- Factor on the host's coins for guest blocks (1 when the event does not change it).
function Events.hostCoinFactor(def: EventDef): number
	local factor = def.hostCoinFactor
	if factor == nil or factor ~= factor or factor < 1 then
		return 1
	end
	return factor
end

function Events.info(current: Current): Info
	local mutation = current.def.mutation
	return {
		id = current.id,
		secondsLeft = current.secondsLeft,
		mutationId = if mutation ~= nil then mutation.id else nil,
		mutationFactor = if mutation ~= nil then mutation.factor else nil,
		bonus = current.def.bonus,
		hostCoinFactor = Events.hostCoinFactor(current.def),
	}
end

return Events
