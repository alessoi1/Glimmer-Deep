--!strict
-- Sell button and sale message for the local player. The client only sends the
-- intention to sell and shows what the server reports; it computes no coins.
-- The coin and backpack numbers are updated by the DigUI from the same result.
-- Built in code so Rojo owns it (no GUI edits in Studio).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SellMessages = require(Shared:WaitForChild("SellMessages"))
local Strings = require(Shared:WaitForChild("Strings"))

local log = Log.new("SellUI")

-- Layout and timing of the interface (not game values).
local BUTTON_WIDTH = 120
local BUTTON_HEIGHT = 64
local DIG_BUTTON_SIZE = 120 -- the sell button sits above the dig button of the DigUI
local BUTTON_MARGIN = 24
local BUTTON_GAP = 12
local TEXT_SIZE = 20
local MESSAGE_SECONDS = 2.5
local MESSAGE_TOP = 56 -- below the dig message
local MESSAGE_WIDTH = 320
local CLICK_DEBOUNCE_SECONDS = 0.3

local COLOR_BUTTON = Color3.fromRGB(90, 190, 120)
local COLOR_BUTTON_TEXT = Color3.fromRGB(15, 40, 25)
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
	local sellRemote = Remotes.event(Remotes.names.sell)
	local sellResult = Remotes.event(Remotes.names.sellResult)

	local gui = Instance.new("ScreenGui")
	gui.Name = "SellHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -BUTTON_MARGIN, 1, -(BUTTON_MARGIN + DIG_BUTTON_SIZE + BUTTON_GAP))
	button.Size = UDim2.fromOffset(BUTTON_WIDTH, BUTTON_HEIGHT)
	button.BackgroundColor3 = COLOR_BUTTON
	button.TextColor3 = COLOR_BUTTON_TEXT
	button.Font = Enum.Font.GothamBold
	button.TextSize = TEXT_SIZE
	button.Text = Strings.sell.button
	button.AutoButtonColor = true
	button.Parent = gui
	local corner = Instance.new("UICorner")
	corner.Parent = button

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
	local lastClickAt = 0

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

	button.Activated:Connect(function()
		local now = os.clock()
		if now - lastClickAt < CLICK_DEBOUNCE_SECONDS then
			return
		end
		lastClickAt = now
		sellRemote:FireServer()
	end)

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
