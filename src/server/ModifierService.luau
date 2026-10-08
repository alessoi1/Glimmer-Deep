--!strict
-- Collects the bonuses of a player from every system that has some (museum
-- sets, skills, pets, boosters, passes) and combines them with Modifiers.
-- Systems register a provider once at start; DigService, SellService and
-- others ask for the combined result. Only checkable in Roblox Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local Modifiers = require(Shared:WaitForChild("Modifiers"))
local ProfileData = require(script.Parent:WaitForChild("ProfileData"))

local log = Log.new("Modifiers")

export type Provider = (profile: ProfileData.Profile) -> Modifiers.Part?

local ModifierService = {}

local providers: { { name: string, provide: Provider } } = {}

-- Registers a source of bonuses. Names are for the log only.
function ModifierService.register(name: string, provider: Provider)
	table.insert(providers, { name = name, provide = provider })
	log.info("provider registered", { name = name })
end

-- Combined bonuses of a profile. A failing provider is logged and skipped, so
-- one broken system cannot stop digging or selling.
function ModifierService.get(profile: ProfileData.Profile): Modifiers.Result
	local parts: { Modifiers.Part } = {}
	for _, entry in providers do
		local ok, part = pcall(entry.provide, profile)
		if not ok then
			log.error("modifier provider failed", { name = entry.name, error = tostring(part) })
		elseif part ~= nil then
			table.insert(parts, part)
		end
	end
	return Modifiers.combine(parts)
end

return ModifierService
