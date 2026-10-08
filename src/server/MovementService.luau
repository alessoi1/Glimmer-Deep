--!strict
-- Sets the walking speed of every character from the player's bonuses (the
-- "Seilwinde" skill). The speed comes from the profile on the server; refresh()
-- is called when a bonus changes. Only checkable in Roblox Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local SkillConfig = require(Shared:WaitForChild("Config"):WaitForChild("Skills"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local ModifierService = require(script.Parent:WaitForChild("ModifierService"))

local log = Log.new("Movement")

local MovementService = {}

local started = false

local function apply(player: Player)
	local character = player.Character
	local profile = DataService.getData(player)
	if character == nil or profile == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	local speed = SkillConfig.baseWalkSpeed * ModifierService.get(profile).walkSpeedMultiplier
	humanoid.WalkSpeed = speed
	log.debug("walk speed set", { userId = player.UserId, speed = speed })
end

-- Applies the current bonus to the player's character (after a bonus changed).
function MovementService.refresh(player: Player)
	apply(player)
end

function MovementService.start()
	if started then
		log.warn("start called twice")
		return
	end
	started = true

	local function track(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			character:WaitForChild("Humanoid")
			apply(player)
		end)
		apply(player)
	end
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end

	log.info("started", { baseWalkSpeed = SkillConfig.baseWalkSpeed })
end

return MovementService
