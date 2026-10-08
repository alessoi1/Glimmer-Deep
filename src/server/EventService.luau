--!strict
-- The weekly event: which one runs now (from server time only), its bonus for
-- every player, the mutation boost for digging and the host coin factor for
-- guests. Other services ask this module; it keeps no per-player state. Only
-- checkable in Roblox Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DigRoll = require(Shared:WaitForChild("DigRoll"))
local Events = require(Shared:WaitForChild("Events"))
local Log = require(Shared:WaitForChild("Log"))
local Modifiers = require(Shared:WaitForChild("Modifiers"))
local Config = Shared:WaitForChild("Config")
local EventConfig = require(Config:WaitForChild("Events"))
local MutationConfig = require(Config:WaitForChild("Mutations"))
local ModifierService = require(script.Parent:WaitForChild("ModifierService"))

local log = Log.new("Events")

local EventService = {}

local config: Events.Config = EventConfig
local started = false
local lastLoggedWeek = -1

-- The event running now.
function EventService.current(): Events.Current
	local current = Events.current(config, os.time())
	if current.week ~= lastLoggedWeek then
		lastLoggedWeek = current.week
		log.info("event running", { id = current.id, week = current.week, secondsLeft = current.secondsLeft })
	end
	return current
end

-- The mutation the running event makes more likely, or nil.
function EventService.mutationBoost(): DigRoll.MutationBoost?
	return EventService.current().def.mutation
end

-- Factor on the host's coins for guest blocks (1 outside the friends week).
function EventService.hostCoinFactor(): number
	return Events.hostCoinFactor(EventService.current().def)
end

function EventService.info(): Events.Info
	return Events.info(EventService.current())
end

function EventService.start()
	if started then
		log.warn("start called twice")
		return
	end
	started = true

	local mutationIds = {}
	for _, mutation in MutationConfig do
		table.insert(mutationIds, mutation.id)
	end
	local ok, reason = Events.validateConfig(config, mutationIds)
	if not ok then
		log.error("event config is invalid", { reason = reason })
	end

	ModifierService.register("event", function(): Modifiers.Part?
		return Events.modifierPart(EventService.current().def)
	end)

	local current = EventService.current()
	log.info("started", { rotation = #config.rotation, current = current.id })
end

return EventService
