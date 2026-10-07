--!strict
-- Dig HUD and input for the local player: a big dig button (tap = one dig, hold
-- = repeat), depth, layer, backpack and the last find. The client only sends
-- the intention to dig and shows what the server reports; it computes no game
-- values. Built in code so Rojo owns it (no GUI edits in Studio).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DigAction = require(Shared:WaitForChild("DigAction"))
local DigMessages = require(Shared:WaitForChild("DigMessages"))
local DigRoll = require(Shared:WaitForChild("DigRoll"))
local Log = require(Shared:WaitForChild("Log"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))

local log = Log.new("DigUI")

-- Layout and timing of the interface (not game values).
local BUTTON_SIZE = 120 -- px, large enough for thumbs on phones
local BUTTON_MARGIN = 24
local PANEL_WIDTH = 240
local PANEL_MARGIN = 12
-- On touch devices the left thumb uses the movement stick in the bottom-left
-- corner, so the panel sits above it.
local PANEL_BOTTOM_TOUCH = 170
local TEXT_SIZE = 20
local MESSAGE_SECONDS = 2.5
local STATE_RETRY_SECONDS = 0.5
local HOLD_POLL_SECONDS = 0.05
local COOLDOWN_SAFETY = 0.95 -- send slightly before the cooldown ends; the server decides
local FALLBACK_COOLDOWN = 1
local DIG_KEY = Enum.KeyCode.E

local COLOR_PANEL = Color3.fromRGB(30, 30, 36)
local COLOR_BUTTON = Color3.fromRGB(230, 170, 60)
local COLOR_TEXT = Color3.fromRGB(245, 245, 245)
local COLOR_BUTTON_TEXT = Color3.fromRGB(40, 30, 10)

type DigResultPayload = {
	ok: boolean,
	reason: string?,
	block: DigRoll.BlockResult?,
	state: DigAction.State,
}

local DigUI = {}

local started = false

local function newLabel(parent: Instance, order: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -16, 0, TEXT_SIZE + 6)
	label.Position = UDim2.fromOffset(8, 8 + order * (TEXT_SIZE + 6))
	label.Font = Enum.Font.GothamMedium
	label.TextSize = TEXT_SIZE
	label.TextColor3 = COLOR_TEXT
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = ""
	label.Parent = parent
	return label
end

function DigUI.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local digRemote = Remotes.event(Remotes.names.dig)
	local digResult = Remotes.event(Remotes.names.digResult)
	local getState = Remotes.func(Remotes.names.getDigState)

	local gui = Instance.new("ScreenGui")
	gui.Name = "DigHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets

	local panel = Instance.new("Frame")
	panel.BackgroundColor3 = COLOR_PANEL
	panel.BackgroundTransparency = 0.25
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, 16 + 3 * (TEXT_SIZE + 6))
	panel.AnchorPoint = Vector2.new(0, 1)
	local panelBottom = if UserInputService.TouchEnabled then PANEL_BOTTOM_TOUCH else PANEL_MARGIN
	panel.Position = UDim2.new(0, PANEL_MARGIN, 1, -panelBottom)
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.Parent = panel
	local depthLabel = newLabel(panel, 0)
	local layerLabel = newLabel(panel, 1)
	local backpackLabel = newLabel(panel, 2)

	local messageLabel = Instance.new("TextLabel")
	messageLabel.BackgroundTransparency = 1
	messageLabel.AnchorPoint = Vector2.new(0.5, 0)
	messageLabel.Position = UDim2.new(0.5, 0, 0, PANEL_MARGIN)
	messageLabel.Size = UDim2.fromOffset(PANEL_WIDTH + 80, TEXT_SIZE + 10)
	messageLabel.Font = Enum.Font.GothamBold
	messageLabel.TextSize = TEXT_SIZE + 2
	messageLabel.TextColor3 = COLOR_TEXT
	messageLabel.TextStrokeTransparency = 0.5
	messageLabel.Text = ""
	messageLabel.Parent = gui

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -BUTTON_MARGIN, 1, -BUTTON_MARGIN)
	button.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
	button.BackgroundColor3 = COLOR_BUTTON
	button.TextColor3 = COLOR_BUTTON_TEXT
	button.Font = Enum.Font.GothamBold
	button.TextSize = TEXT_SIZE + 2
	button.Text = Strings.dig.button
	button.AutoButtonColor = true
	button.Parent = gui
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0.5, 0)
	buttonCorner.Parent = button

	local state: DigAction.State? = nil
	local messageToken = 0
	local holding = false
	local lastFireAt = 0

	local function applyState(newState: DigAction.State)
		state = newState
		depthLabel.Text = string.format("%s: %s", Strings.dig.depthLabel, DigMessages.formatDepth(newState.depth))
		layerLabel.Text =
			string.format("%s: %s", Strings.dig.layerLabel, DigMessages.layerName(Strings, newState.layerId))
		backpackLabel.Text = string.format("%s: %d / %d", Strings.dig.backpackLabel, newState.used, newState.capacity)
	end

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

	local function tryDig()
		local cooldown = if state then state.digCooldown else FALLBACK_COOLDOWN
		local now = os.clock()
		if now - lastFireAt < cooldown * COOLDOWN_SAFETY then
			return
		end
		lastFireAt = now
		digRemote:FireServer()
	end

	local function startHolding()
		if holding then
			return
		end
		holding = true
		task.spawn(function()
			repeat
				tryDig()
				task.wait(HOLD_POLL_SECONDS)
			until not holding
		end)
	end

	local function stopHolding()
		holding = false
	end

	button.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			startHolding()
		end
	end)
	button.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			stopHolding()
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == DIG_KEY then
			startHolding()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.KeyCode == DIG_KEY then
			stopHolding()
		end
	end)

	digResult.OnClientEvent:Connect(function(payload: DigResultPayload)
		if type(payload) ~= "table" or type(payload.state) ~= "table" then
			log.warn("unexpected dig result from server")
			return
		end
		applyState(payload.state)
		if payload.ok and payload.block ~= nil then
			showMessage(DigMessages.describeBlock(Strings, payload.block))
		elseif payload.reason ~= nil then
			showMessage(DigMessages.describeFailure(Strings, payload.reason))
		end
	end)

	gui.Parent = playerGui

	-- The profile may still be loading: ask until the server has a state.
	task.spawn(function()
		while state == nil do
			local ok, result = pcall(function()
				return getState:InvokeServer()
			end)
			if ok and type(result) == "table" then
				applyState(result :: DigAction.State)
			else
				if not ok then
					log.warn("could not read dig state", { error = tostring(result) })
				end
				task.wait(STATE_RETRY_SECONDS)
			end
		end
	end)
end

return DigUI
