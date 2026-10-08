--!strict
-- Quest panel for the local player: the daily login reward, the quests of the
-- day with progress, the all-done bonus and the time until new quests. The
-- client only sends what to claim and shows what the server reports. Built in
-- code so Rojo owns it (no GUI edits in Studio).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local LoginChain = require(Shared:WaitForChild("LoginChain"))
local QuestMessages = require(Shared:WaitForChild("QuestMessages"))
local Quests = require(Shared:WaitForChild("Quests"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))

local log = Log.new("QuestUI")

-- Layout and timing of the interface (not game values).
local TOGGLE_WIDTH = 120
local TOGGLE_HEIGHT = 44
-- The toggle sits above the upgrades toggle in the button column on the right.
local STACK_BELOW_TOGGLE = 24 + 120 + 12 + 44 + 12
local BUTTON_MARGIN = 24
local PANEL_WIDTH = 300
local PANEL_MARGIN = 12
local PADDING = 8
local ROW_HEIGHT = 56
local ACTION_WIDTH = 96
local TEXT_SIZE = 14
local MESSAGE_SECONDS = 2.5
local MESSAGE_TOP = 188 -- below the other messages
local MESSAGE_WIDTH = 320
local RETRY_SECONDS = 0.5

local COLOR_TOGGLE = Color3.fromRGB(150, 120, 220)
local COLOR_TOGGLE_TEXT = Color3.fromRGB(25, 15, 50)
local COLOR_PANEL = Color3.fromRGB(30, 30, 36)
local COLOR_ROW = Color3.fromRGB(48, 48, 58)
local COLOR_ACTION = Color3.fromRGB(230, 170, 60)
local COLOR_ACTION_TEXT = Color3.fromRGB(40, 30, 10)
local COLOR_DISABLED = Color3.fromRGB(95, 95, 105)
local COLOR_DISABLED_TEXT = Color3.fromRGB(215, 215, 220)
local COLOR_TEXT = Color3.fromRGB(245, 245, 245)
local COLOR_HEADING = Color3.fromRGB(170, 190, 255)

type Snapshot = {
	quests: Quests.View,
	login: LoginChain.View,
	secondsToReset: number,
}

type ResultPayload = {
	ok: boolean,
	kind: string?,
	coins: number?,
	reason: string?,
	snapshot: Snapshot?,
}

local QuestUI = {}

local started = false

local function newText(parent: Instance, text: string, bold: boolean, color: Color3)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -2 * PADDING, 0, TEXT_SIZE + 10)
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	label.TextSize = TEXT_SIZE
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Text = text
	label.Parent = parent
end

-- A row with a text and a button; a disabled button is greyed out and does nothing.
local function newRow(parent: Instance, text: string, actionText: string, enabled: boolean, onAction: () -> ())
	local row = Instance.new("Frame")
	row.BackgroundColor3 = COLOR_ROW
	row.Size = UDim2.new(1, -2 * PADDING, 0, ROW_HEIGHT)
	row.Parent = parent
	local corner = Instance.new("UICorner")
	corner.Parent = row

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(PADDING, 0)
	label.Size = UDim2.new(1, -(3 * PADDING + ACTION_WIDTH), 1, 0)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = TEXT_SIZE
	label.TextColor3 = COLOR_TEXT
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Text = text
	label.Parent = row

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -PADDING, 0.5, 0)
	button.Size = UDim2.fromOffset(ACTION_WIDTH, ROW_HEIGHT - 12)
	button.BackgroundColor3 = if enabled then COLOR_ACTION else COLOR_DISABLED
	button.TextColor3 = if enabled then COLOR_ACTION_TEXT else COLOR_DISABLED_TEXT
	button.Font = Enum.Font.GothamBold
	button.TextSize = TEXT_SIZE
	button.Text = actionText
	button.Parent = row
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.Parent = button
	if enabled then
		button.Activated:Connect(onAction)
	end
end

function QuestUI.start()
	if started then
		return
	end
	started = true

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local getQuests = Remotes.func(Remotes.names.getQuests)
	local claimRemote = Remotes.event(Remotes.names.questClaim)
	local questResult = Remotes.event(Remotes.names.questResult)
	local questDone = Remotes.event(Remotes.names.questDone)

	local gui = Instance.new("ScreenGui")
	gui.Name = "QuestHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets

	local toggle = Instance.new("TextButton")
	toggle.AnchorPoint = Vector2.new(1, 1)
	toggle.Position = UDim2.new(1, -BUTTON_MARGIN, 1, -STACK_BELOW_TOGGLE)
	toggle.Size = UDim2.fromOffset(TOGGLE_WIDTH, TOGGLE_HEIGHT)
	toggle.BackgroundColor3 = COLOR_TOGGLE
	toggle.TextColor3 = COLOR_TOGGLE_TEXT
	toggle.Font = Enum.Font.GothamBold
	toggle.TextSize = TEXT_SIZE + 2
	toggle.Text = Strings.quests.open
	toggle.Parent = gui
	local toggleCorner = Instance.new("UICorner")
	toggleCorner.Parent = toggle

	-- Left of the screen, vertically centered, so it does not cover the buttons.
	local panel = Instance.new("Frame")
	panel.Visible = false
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.new(0, PANEL_MARGIN, 0.5, 0)
	panel.Size = UDim2.new(0, PANEL_WIDTH, 0.85, 0)
	panel.BackgroundColor3 = COLOR_PANEL
	panel.BackgroundTransparency = 0.1
	panel.Parent = gui
	local panelCorner = Instance.new("UICorner")
	panelCorner.Parent = panel
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(PANEL_WIDTH, 440)
	sizeLimit.Parent = panel

	local body = Instance.new("ScrollingFrame")
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Size = UDim2.fromScale(1, 1)
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.ScrollBarThickness = 6
	body.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = body
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, PADDING)
	padding.PaddingBottom = UDim.new(0, PADDING)
	padding.Parent = body

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

	local lastSnapshot: Snapshot? = nil

	local function render(snapshot: Snapshot)
		lastSnapshot = snapshot
		for _, child in body:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		newText(body, Strings.quests.loginHeading, true, COLOR_HEADING)
		local login = snapshot.login
		if login.streak >= 1 then
			newRow(
				body,
				QuestMessages.describeLogin(Strings, login),
				if login.claimable then Strings.quests.claim else Strings.quests.claimed,
				login.claimable,
				function()
					claimRemote:FireServer("login")
				end
			)
		end

		newText(body, Strings.quests.questsHeading, true, COLOR_HEADING)
		for _, quest in snapshot.quests.quests do
			local actionText = if quest.claimed
				then Strings.quests.claimed
				elseif quest.done then Strings.quests.claim
				else string.format(Strings.quests.progress, quest.progress, quest.target)
			newRow(
				body,
				QuestMessages.questTitle(Strings, quest),
				actionText,
				quest.done and not quest.claimed,
				function()
					claimRemote:FireServer("quest", quest.id)
				end
			)
		end

		newRow(
			body,
			QuestMessages.describeBonus(Strings, snapshot.quests.bonus),
			if snapshot.quests.bonusClaimed then Strings.quests.claimed else Strings.quests.claim,
			snapshot.quests.bonusClaimable,
			function()
				claimRemote:FireServer("bonus")
			end
		)
		newText(body, QuestMessages.describeReset(Strings, snapshot.secondsToReset), false, COLOR_TEXT)
	end

	local function refresh(): boolean
		local ok, result = pcall(function()
			return getQuests:InvokeServer()
		end)
		if ok and type(result) == "table" then
			render(result :: Snapshot)
			return true
		end
		if not ok then
			log.warn("could not read the quests", { error = tostring(result) })
		end
		return false
	end

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			task.spawn(refresh)
		end
	end)

	questResult.OnClientEvent:Connect(function(payload: ResultPayload)
		if type(payload) ~= "table" then
			log.warn("unexpected quest result from server")
			return
		end
		if type(payload.snapshot) == "table" and panel.Visible then
			render(payload.snapshot)
		end
		showMessage(QuestMessages.describeResult(Strings, payload.ok, payload.coins or 0, payload.reason))
	end)

	questDone.OnClientEvent:Connect(function(questIds: { string })
		if type(questIds) ~= "table" or lastSnapshot == nil then
			return
		end
		for _, quest in lastSnapshot.quests.quests do
			if table.find(questIds, quest.id) then
				showMessage(QuestMessages.describeCompleted(Strings, quest))
			end
		end
		if panel.Visible then
			task.spawn(refresh)
		end
	end)

	gui.Parent = playerGui

	-- Load once so the done-toast knows the quest texts; the profile may still be loading.
	task.spawn(function()
		while not refresh() do
			task.wait(RETRY_SECONDS)
		end
	end)
end

return QuestUI
