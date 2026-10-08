--!strict
-- Season panel for the local player: opens when the server says so (the player
-- used the season sign). Shows the weekly event, the season progress and the
-- free and premium reward of every level. The client only asks to claim a
-- reward (track and level); the server decides. A short notice appears when a
-- season level is reached. Built in code so Rojo owns it (no GUI edits in
-- Studio).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Season = require(Shared:WaitForChild("Season"))
local SeasonMessages = require(Shared:WaitForChild("SeasonMessages"))
local Strings = require(Shared:WaitForChild("Strings"))

local log = Log.new("SeasonUI")

-- Layout and timing of the interface (not game values).
local PANEL_WIDTH = 340
local PANEL_MAX_HEIGHT = 460
local PANEL_PADDING = 8
local HEADER_HEIGHT = 48
local ACTION_HEIGHT = 32
local ACTION_WIDTH = 104
local TEXT_SIZE = 16
local TITLE_SIZE = 20
local MESSAGE_SECONDS = 3
local MESSAGE_TOP = 364 -- below the other messages
local MESSAGE_WIDTH = 320

local COLOR_PANEL = Color3.fromRGB(30, 30, 36)
local COLOR_ROW = Color3.fromRGB(48, 48, 58)
local COLOR_ACTION = Color3.fromRGB(230, 170, 60)
local COLOR_ACTION_TEXT = Color3.fromRGB(40, 30, 10)
local COLOR_DISABLED = Color3.fromRGB(95, 95, 105)
local COLOR_DISABLED_TEXT = Color3.fromRGB(215, 215, 220)
local COLOR_CLOSE = Color3.fromRGB(110, 110, 125)
local COLOR_TEXT = Color3.fromRGB(245, 245, 245)
local COLOR_MUTED = Color3.fromRGB(190, 190, 200)
local COLOR_HEADING = Color3.fromRGB(170, 190, 255)

type ResultPayload = {
	ok: boolean,
	reason: string?,
	level: number?,
	snapshot: Season.Snapshot?,
}

local SeasonUI = {}

local started = false

local function newText(parent: Instance, text: string, bold: boolean, color: Color3, height: number)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -2 * PANEL_PADDING, 0, height)
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	label.TextSize = TEXT_SIZE
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Text = text
	label.Parent = parent
end

local function addButton(parent: Instance, text: string, enabled: boolean, onActivated: () -> ())
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -2 * PANEL_PADDING, 0, ACTION_HEIGHT)
	button.BackgroundColor3 = if enabled then COLOR_ACTION else COLOR_DISABLED
	button.TextColor3 = if enabled then COLOR_ACTION_TEXT else COLOR_DISABLED_TEXT
	button.Font = Enum.Font.GothamBold
	button.TextSize = TEXT_SIZE
	button.Text = text
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.Parent = button
	if enabled then
		button.Activated:Connect(onActivated)
	end
end

local function newRow(parent: Instance): Frame
	local row = Instance.new("Frame")
	row.BackgroundColor3 = COLOR_ROW
	row.Size = UDim2.new(1, -2 * PANEL_PADDING, 0, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.Parent = parent
	local corner = Instance.new("UICorner")
	corner.Parent = row
	local rowList = Instance.new("UIListLayout")
	rowList.Padding = UDim.new(0, 4)
	rowList.SortOrder = Enum.SortOrder.LayoutOrder
	rowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowList.Parent = row
	local rowPadding = Instance.new("UIPadding")
	rowPadding.PaddingTop = UDim.new(0, PANEL_PADDING)
	rowPadding.PaddingBottom = UDim.new(0, PANEL_PADDING)
	rowPadding.Parent = row
	return row
end

function SeasonUI.start()
	if started then
		return
	end
	started = true

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local seasonOpen = Remotes.event(Remotes.names.seasonOpen)
	local seasonResult = Remotes.event(Remotes.names.seasonResult)
	local claimRemote = Remotes.event(Remotes.names.seasonClaim)

	local gui = Instance.new("ScreenGui")
	gui.Name = "SeasonHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets

	local panel = Instance.new("Frame")
	panel.Visible = false
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0, PANEL_WIDTH, 0.85, 0)
	panel.BackgroundColor3 = COLOR_PANEL
	panel.BackgroundTransparency = 0.1
	panel.Parent = gui
	local panelCorner = Instance.new("UICorner")
	panelCorner.Parent = panel
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(PANEL_WIDTH, PANEL_MAX_HEIGHT)
	sizeLimit.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(PANEL_PADDING, PANEL_PADDING)
	title.Size = UDim2.new(1, -(ACTION_WIDTH + 3 * PANEL_PADDING), 0, HEADER_HEIGHT - PANEL_PADDING)
	title.Font = Enum.Font.GothamBold
	title.TextSize = TITLE_SIZE
	title.TextColor3 = COLOR_TEXT
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = Strings.season.title
	title.Parent = panel

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -PANEL_PADDING, 0, PANEL_PADDING)
	close.Size = UDim2.fromOffset(ACTION_WIDTH, HEADER_HEIGHT - PANEL_PADDING)
	close.BackgroundColor3 = COLOR_CLOSE
	close.TextColor3 = COLOR_TEXT
	close.Font = Enum.Font.GothamBold
	close.TextSize = TEXT_SIZE
	close.Text = Strings.season.close
	close.Parent = panel
	local closeCorner = Instance.new("UICorner")
	closeCorner.Parent = close

	local body = Instance.new("ScrollingFrame")
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(0, HEADER_HEIGHT)
	body.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT)
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.ScrollBarThickness = 6
	body.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = body

	local messageLabel = Instance.new("TextLabel")
	messageLabel.BackgroundTransparency = 1
	messageLabel.AnchorPoint = Vector2.new(0.5, 0)
	messageLabel.Position = UDim2.new(0.5, 0, 0, MESSAGE_TOP)
	messageLabel.Size = UDim2.fromOffset(MESSAGE_WIDTH, TEXT_SIZE + 14)
	messageLabel.Font = Enum.Font.GothamBold
	messageLabel.TextSize = TEXT_SIZE + 4
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

	local function render(snapshot: Season.Snapshot)
		for _, child in body:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local view = snapshot.season
		local event = snapshot.event

		local eventRow = newRow(body)
		newText(eventRow, SeasonMessages.eventLine(Strings, event), true, COLOR_TEXT, 2 * (TEXT_SIZE + 4))
		newText(eventRow, SeasonMessages.eventDescription(Strings, event.id), false, COLOR_MUTED, 3 * (TEXT_SIZE + 2))

		local seasonRow = newRow(body)
		newText(
			seasonRow,
			SeasonMessages.seasonLine(Strings, view.season, view.secondsLeft),
			true,
			COLOR_HEADING,
			2 * (TEXT_SIZE + 4)
		)
		newText(
			seasonRow,
			SeasonMessages.levelText(Strings, view.level, view.maxLevel),
			true,
			COLOR_TEXT,
			TEXT_SIZE + 6
		)
		newText(
			seasonRow,
			SeasonMessages.xpText(Strings, view.xpIntoLevel, view.xpForNext),
			false,
			COLOR_MUTED,
			TEXT_SIZE + 4
		)
		newText(seasonRow, Strings.season.note, false, COLOR_MUTED, 3 * (TEXT_SIZE + 2))
		if not view.premium then
			newText(seasonRow, Strings.season.premiumNote, false, COLOR_MUTED, 4 * (TEXT_SIZE + 2))
		end

		for _, level in view.levels do
			local row = newRow(body)
			newText(
				row,
				string.format("%d  (%s)", level.level, SeasonMessages.xpText(Strings, 0, level.needed)),
				true,
				COLOR_HEADING,
				TEXT_SIZE + 4
			)
			newText(
				row,
				Strings.season.freeHeading .. ": " .. SeasonMessages.rewardText(Strings, level.free),
				false,
				COLOR_TEXT,
				2 * (TEXT_SIZE + 2)
			)
			addButton(
				row,
				SeasonMessages.claimText(Strings, level.reached, level.freeClaimed, false),
				level.freeReady,
				function()
					claimRemote:FireServer("free", level.level)
				end
			)
			newText(
				row,
				Strings.season.premiumHeading .. ": " .. SeasonMessages.rewardText(Strings, level.premium),
				false,
				COLOR_TEXT,
				2 * (TEXT_SIZE + 2)
			)
			addButton(
				row,
				SeasonMessages.claimText(Strings, level.reached, level.premiumClaimed, not view.premium),
				level.premiumReady,
				function()
					claimRemote:FireServer("premium", level.level)
				end
			)
		end
	end

	close.Activated:Connect(function()
		panel.Visible = false
	end)

	seasonOpen.OnClientEvent:Connect(function(snapshot: Season.Snapshot)
		if type(snapshot) ~= "table" then
			log.warn("unexpected season snapshot from server")
			return
		end
		render(snapshot)
		panel.Visible = true
	end)

	seasonResult.OnClientEvent:Connect(function(payload: ResultPayload)
		if type(payload) ~= "table" then
			log.warn("unexpected season result from server")
			return
		end
		if type(payload.snapshot) == "table" and panel.Visible then
			render(payload.snapshot)
		end
		if payload.level ~= nil then
			showMessage(SeasonMessages.levelUpText(Strings, payload.level))
		elseif payload.reason ~= nil or not payload.ok then
			showMessage(SeasonMessages.describeResult(Strings, payload.ok, payload.reason))
		else
			showMessage(SeasonMessages.describeResult(Strings, true, nil))
		end
	end)

	gui.Parent = playerGui
end

return SeasonUI
