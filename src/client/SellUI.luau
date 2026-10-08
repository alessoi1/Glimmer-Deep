--!strict
-- The sale message for the local player. Selling happens by itself at the sell
-- stand (the server decides); the client sends nothing and only shows what the
-- server reports, it computes no coins. The coin and backpack numbers are
-- updated by the DigUI from the same result. Built in code so Rojo owns it (no
-- GUI edits in Studio).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SellMessages = require(Shared:WaitForChild("SellMessages"))
local Strings = require(Shared:WaitForChild("Strings"))

local log = Log.new("SellUI")

-- Layout and timing of the interface (not game values).
local TEXT_SIZE = 17
local MESSAGE_SECONDS = 2.5
local MESSAGE_TOP = 56 -- below the dig message
local MESSAGE_WIDTH = 320

local COLOR_TEXT = Color3.fromRGB(245, 245, 245)

type SellResultPayload = {
	ok: boolean,
	reason: string?,
	coinsEarned: number?,
}

local SellUI = {}

local started = false

function SellUI.start()
	if started then
		return
	end
	started = true

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local sellResult = Remotes.event(Remotes.names.sellResult)

	local gui = Instance.new("ScreenGui")
	gui.Name = "SellHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets

	local messageLabel = Instance.new("TextLabel")
	messageLabel.BackgroundTransparency = 1
	messageLabel.AnchorPoint = Vector2.new(0.5, 0)
	messageLabel.Position = UDim2.new(0.5, 0, 0, MESSAGE_TOP)
	messageLabel.Size = UDim2.fromOffset(MESSAGE_WIDTH, TEXT_SIZE + 10)
	messageLabel.Font = Enum.Font.GothamBold
	messageLabel.TextSize = TEXT_SIZE + 2
	messageLabel.TextColor3 = COLOR_TEXT
	messageLabel.TextStrokeTransparency = 0.5
	messageLabel.Text = ""
	messageLabel.Parent = gui

	local messageToken = 0

	local function showMessage(text: string)
		messageToken += 1
		local token = messageToken
		messageLabel.Text = text
		task.delay(MESSAGE_SECONDS, function()
			if token == messageToken then
				messageLabel.Text = ""
			end
		end)
	end

	sellResult.OnClientEvent:Connect(function(payload: SellResultPayload)
		if type(payload) ~= "table" then
			log.warn("unexpected sell result from server")
			return
		end
		if payload.ok and type(payload.coinsEarned) == "number" then
			showMessage(SellMessages.describeSale(Strings.sell, payload.coinsEarned))
		elseif payload.reason ~= nil then
			showMessage(SellMessages.describeFailure(Strings.sell, payload.reason))
		end
	end)

	gui.Parent = playerGui
end

return SellUI
