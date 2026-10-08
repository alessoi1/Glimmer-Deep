--!strict
-- The guest line on screen: who digs on your plot, or whose plot you dig on,
-- plus the reason when joining did not work. Display only; joining happens at
-- the guest sign in the world. Built in code so Rojo owns it (no GUI edits in
-- Studio).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GuestMessages = require(Shared:WaitForChild("GuestMessages"))
local Log = require(Shared:WaitForChild("Log"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))

local log = Log.new("GuestUI")

-- Layout and timing of the interface (not game values).
local TEXT_SIZE = 16
local LINE_TOP = 64 -- below the top bar, above the other messages
local LINE_WIDTH = 340
local MESSAGE_SECONDS = 3
local MESSAGE_TOP = 96

local COLOR_TEXT = Color3.fromRGB(245, 245, 245)
local COLOR_GUEST = Color3.fromRGB(150, 230, 230)

type Payload = GuestMessages.Status & { reason: string? }

local GuestUI = {}

local started = false

local function newLabel(gui: ScreenGui, top: number, size: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, top)
	label.Size = UDim2.fromOffset(LINE_WIDTH, size + 8)
	label.Font = Enum.Font.GothamBold
	label.TextSize = size
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.5
	label.TextWrapped = true
	label.Text = ""
	label.Parent = gui
	return label
end

function GuestUI.start()
	if started then
		return
	end
	started = true

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local guestStatus = Remotes.event(Remotes.names.guestStatus)

	local gui = Instance.new("ScreenGui")
	gui.Name = "GuestHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets

	local statusLabel = newLabel(gui, LINE_TOP, TEXT_SIZE, COLOR_GUEST)
	local messageLabel = newLabel(gui, MESSAGE_TOP, TEXT_SIZE + 2, COLOR_TEXT)

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

	guestStatus.OnClientEvent:Connect(function(payload: Payload)
		if type(payload) ~= "table" then
			log.warn("unexpected guest status from server")
			return
		end
		statusLabel.Text = GuestMessages.statusText(Strings, payload)
		if payload.reason ~= nil then
			showMessage(GuestMessages.describeReason(Strings, payload.reason))
		end
	end)

	gui.Parent = playerGui
end

return GuestUI
