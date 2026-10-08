--!strict
-- Upgrade panel for the local player: a toggle button opens a panel with one
-- button per upgrade (shovel, backpack). The client only sends the upgrade id
-- and shows what the server reports (names, next level, price); it computes no
-- prices. Coin and backpack numbers are updated by the DigUI from the same
-- result. Built in code so Rojo owns it (no GUI edits in Studio).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))
local UpgradeAction = require(Shared:WaitForChild("UpgradeAction"))
local UpgradeMessages = require(Shared:WaitForChild("UpgradeMessages"))

local log = Log.new("UpgradeUI")

-- Layout and timing of the interface (not game values).
local TOGGLE_WIDTH = 120
local TOGGLE_HEIGHT = 44
-- The toggle sits above the dig button.
local STACK_BELOW_TOGGLE = 24 + 120 + 12
local BUTTON_MARGIN = 24
local BUTTON_GAP = 12
local PANEL_WIDTH = 270
local PANEL_PADDING = 8
local ROW_HEIGHT = 72
local TEXT_SIZE = 15
local MESSAGE_SECONDS = 2.5
local MESSAGE_TOP = 100 -- below the dig and sell messages
local MESSAGE_WIDTH = 320
local CLICK_DEBOUNCE_SECONDS = 0.3
local RETRY_SECONDS = 0.5

local COLOR_TOGGLE = Color3.fromRGB(110, 140, 230)
local COLOR_TOGGLE_TEXT = Color3.fromRGB(15, 20, 50)
local COLOR_PANEL = Color3.fromRGB(30, 30, 36)
local COLOR_ROW = Color3.fromRGB(230, 170, 60)
local COLOR_ROW_TEXT = Color3.fromRGB(40, 30, 10)
local COLOR_ROW_DISABLED = Color3.fromRGB(95, 95, 105)
local COLOR_ROW_DISABLED_TEXT = Color3.fromRGB(215, 215, 220)
local COLOR_TEXT = Color3.fromRGB(245, 245, 245)

type UpgradeResultPayload = {
	ok: boolean,
	reason: string?,
	upgradeId: string?,
	upgrades: { UpgradeAction.Entry }?,
}

local UpgradeUI = {}

local started = false

function UpgradeUI.start()
	if started then
		return
	end
	started = true

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local buyRemote = Remotes.event(Remotes.names.buyUpgrade)
	local upgradeResult = Remotes.event(Remotes.names.upgradeResult)
	local sellResult = Remotes.event(Remotes.names.sellResult)
	local getUpgrades = Remotes.func(Remotes.names.getUpgrades)

	local gui = Instance.new("ScreenGui")
	gui.Name = "UpgradeHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets

	local toggle = Instance.new("TextButton")
	toggle.AnchorPoint = Vector2.new(1, 1)
	toggle.Position = UDim2.new(1, -BUTTON_MARGIN, 1, -STACK_BELOW_TOGGLE)
	toggle.Size = UDim2.fromOffset(TOGGLE_WIDTH, TOGGLE_HEIGHT)
	toggle.BackgroundColor3 = COLOR_TOGGLE
	toggle.TextColor3 = COLOR_TOGGLE_TEXT
	toggle.Font = Enum.Font.GothamBold
	toggle.TextSize = TEXT_SIZE
	toggle.Text = Strings.upgrades.openButton
	toggle.Parent = gui
	local toggleCorner = Instance.new("UICorner")
	toggleCorner.Parent = toggle

	-- Beside the button column, centered vertically so it fits landscape phones.
	local panel = Instance.new("Frame")
	panel.Visible = false
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -(BUTTON_MARGIN + TOGGLE_WIDTH + BUTTON_GAP), 0.5, 0)
	panel.BackgroundColor3 = COLOR_PANEL
	panel.BackgroundTransparency = 0.15
	panel.Parent = gui
	local panelCorner = Instance.new("UICorner")
	panelCorner.Parent = panel
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.Parent = panel
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 6
	scroll.Parent = panel

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

	local rows: { [string]: TextButton } = {}
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

	local function rowFor(upgradeId: string, index: number): TextButton
		local existing = rows[upgradeId]
		if existing ~= nil then
			return existing
		end
		local row = Instance.new("TextButton")
		row.Position = UDim2.fromOffset(PANEL_PADDING, PANEL_PADDING + (index - 1) * (ROW_HEIGHT + PANEL_PADDING))
		row.Size = UDim2.new(1, -2 * PANEL_PADDING, 0, ROW_HEIGHT)
		row.Font = Enum.Font.GothamBold
		row.TextSize = TEXT_SIZE
		row.TextWrapped = true
		row.Parent = scroll
		local corner = Instance.new("UICorner")
		corner.Parent = row
		row.Activated:Connect(function()
			local now = os.clock()
			if now - lastClickAt < CLICK_DEBOUNCE_SECONDS then
				return
			end
			lastClickAt = now
			buyRemote:FireServer(upgradeId)
		end)
		rows[upgradeId] = row
		return row
	end

	local function applyEntries(entries: { UpgradeAction.Entry })
		local wanted = PANEL_PADDING + #entries * (ROW_HEIGHT + PANEL_PADDING)
		-- At most 80 % of the screen high, as high as the rows when they fit.
		panel.Size = UDim2.new(0, PANEL_WIDTH, 0.8, 0)
		sizeLimit.MaxSize = Vector2.new(PANEL_WIDTH, wanted)
		for index, entry in entries do
			local row = rowFor(entry.id, index)
			row.Text = UpgradeMessages.describeOffer(Strings, entry)
			row.BackgroundColor3 = if entry.canAfford then COLOR_ROW else COLOR_ROW_DISABLED
			row.TextColor3 = if entry.canAfford then COLOR_ROW_TEXT else COLOR_ROW_DISABLED_TEXT
		end
	end

	-- Reads the upgrades from the server; false while the profile is loading.
	local function refresh(): boolean
		local ok, result = pcall(function()
			return getUpgrades:InvokeServer()
		end)
		if ok and type(result) == "table" then
			applyEntries(result :: { UpgradeAction.Entry })
			return true
		end
		if not ok then
			log.warn("could not read upgrades", { error = tostring(result) })
		end
		return false
	end

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			task.spawn(refresh)
		end
	end)

	upgradeResult.OnClientEvent:Connect(function(payload: UpgradeResultPayload)
		if type(payload) ~= "table" then
			log.warn("unexpected upgrade result from server")
			return
		end
		if type(payload.upgrades) == "table" then
			applyEntries(payload.upgrades)
		end
		showMessage(UpgradeMessages.describeResult(Strings, payload.ok, payload.upgradeId, payload.reason))
	end)

	-- A sale changes the coins, so what the player can afford changes too.
	sellResult.OnClientEvent:Connect(function()
		if panel.Visible then
			task.spawn(refresh)
		end
	end)

	gui.Parent = playerGui

	-- The profile may still be loading: ask until the server has the upgrades.
	task.spawn(function()
		while not refresh() do
			task.wait(RETRY_SECONDS)
		end
	end)
end

return UpgradeUI
