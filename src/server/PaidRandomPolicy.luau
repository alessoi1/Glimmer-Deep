--!strict
-- Asks PolicyService once per player whether paid random items (luck boosters,
-- eggs) are restricted, and remembers the answer. An unknown answer (lookup
-- failed or not finished yet) counts as restricted, so a paid random item is
-- never offered by mistake. Only checkable in Roblox Studio.

local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Log"))

local log = Log.new("Policy")

type KnownListener = (player: Player) -> ()

local PaidRandomPolicy = {}

-- true = restricted, false = allowed, missing = not known yet.
local answers: { [Player]: boolean } = {}
local listeners: { KnownListener } = {}
local started = false

-- True when paid random items must not be shown or offered to this player.
function PaidRandomPolicy.isRestricted(player: Player): boolean
	return answers[player] ~= false
end

-- True only when PolicyService answered that the player is restricted. The
-- free alternatives are for these players, not for unknown ones.
function PaidRandomPolicy.isKnownRestricted(player: Player): boolean
	return answers[player] == true
end

-- Registers a callback that runs when a player's answer becomes known.
function PaidRandomPolicy.onKnown(listener: KnownListener)
	table.insert(listeners, listener)
end

local function lookup(player: Player)
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if not ok then
		-- Stays unknown, which counts as restricted.
		log.warn("policy lookup failed", { userId = player.UserId, error = tostring(info) })
		return
	end
	if player.Parent ~= Players then
		return
	end
	answers[player] = info.ArePaidRandomItemsRestricted == true
	log.info("policy known", { userId = player.UserId, paidRandomRestricted = answers[player] })
	for _, listener in listeners do
		local listenerOk, err = pcall(listener, player)
		if not listenerOk then
			log.error("policy listener failed", { userId = player.UserId, error = tostring(err) })
		end
	end
end

function PaidRandomPolicy.start()
	if started then
		log.warn("start called twice")
		return
	end
	started = true
	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(lookup, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(lookup, player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		answers[player] = nil
	end)
	log.info("started")
end

return PaidRandomPolicy
