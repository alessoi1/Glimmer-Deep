--!strict
-- Museum panel for the local player: opens when the server says so (the owner
-- used the museum sign), lists the showcases, the rare finds in the backpack,
-- the layer sets, the visitor income and this server's weekly board. The client
-- only sends intentions (find id and showcase number) and shows what the server
-- reports. Built in code so Rojo owns it (no GUI edits in Studio).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local MuseumLogic = require(Shared:WaitForChild("MuseumLogic"))
local MuseumMessages = require(Shared:WaitForChild("MuseumMessages"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))

local log = Log.new("MuseumUI")

-- Layout and timing of the interface (not game values).
local PANEL_WIDTH = 340
local PANEL_MAX_HEIGHT = 460
local PANEL_PADDING = 8
local HEADER_HEIGHT = 48
local ROW_HEIGHT = 48
local ACTION_WIDTH = 104
local TEXT_SIZE = 16
local TITLE_SIZE = 20
local MESSAGE_SECONDS = 2.5
local MESSAGE_TOP = 144 -- below the dig, sell and upgrade messages
local MESSAGE_WIDTH = 320

local COLOR_PANEL = Color3.fromRGB(30, 30, 36)
local COLOR_ROW = Color3.fromRGB(48, 48, 58)
local COLOR_ACTION = Color3.fromRGB(230, 170, 60)
local COLOR_ACTION_TEXT = Color3.fromRGB(40, 30, 10)
local COLOR_CLOSE = Color3.fromRGB(110, 110, 125)
local COLOR_TEXT = Color3.fromRGB(245, 245, 245)
local COLOR_HEADING = Color3.fromRGB(170, 190, 255)

type Snapshot = {
	view: MuseumLogic.View,
	board: { MuseumLogic.BoardEntry },
}

type ResultPayload = {
	ok: boolean,
	kind: string?,
	reason: string?,
	coins: number?,
	name: string?,
	snapshot: Snapshot?,
}

local MuseumUI = {}

local started = false

local function newText(parent: Instance, text: string, size: number, color: Color3, bold: boolean): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -2 * PANEL_PADDING, 0, size + 10)
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	label.TextSize = size
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Text = text
	label.Parent = parent
	return label
end

-- A row with a text and an optional action button on the right.
local function newRow(parent: Instance, text: string, actionText: string?, onAction: (() -> ())?): Frame
	local row = Instance.new("Frame")
	row.BackgroundColor3 = COLOR_ROW
	row.Size = UDim2.new(1, -2 * PANEL_PADDING, 0, ROW_HEIGHT)
	row.Parent = parent
	local corner = Instance.new("UICorner")
	corner.Parent = row

	local hasAction = actionText ~= nil and onAction ~= nil
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(PANEL_PADDING, 0)
	label.Size = UDim2.new(1, -(PANEL_PADDING * 2 + if hasAction then ACTION_WIDTH + PANEL_PADDING else 0), 1, 0)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = TEXT_SIZE
	label.TextColor3 = COLOR_TEXT
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Text = text
	label.Parent = row

	if hasAction then
		local button = Instance.new("TextButton")
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -PANEL_PADDING, 0.5, 0)
		button.Size = UDim2.fromOffset(ACTION_WIDTH, ROW_HEIGHT - 12)
		button.BackgroundColor3 = COLOR_ACTION
		button.TextColor3 = COLOR_ACTION_TEXT
		button.Font = Enum.Font.GothamBold
		button.TextSize = TEXT_SIZE
		button.Text = actionText :: string
		button.Parent = row
		local buttonCorner = Instance.new("UICorner")
		buttonCorner.Parent = button
		button.Activated:Connect(onAction :: () -> ())
	end
	return row
end

function MuseumUI.start()
	if started then
		return
	end
	started = true

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local museumOpen = Remotes.event(Remotes.names.museumOpen)
	local museumResult = Remotes.event(Remotes.names.museumResult)
	local displayRemote = Remotes.event(Remotes.names.museumDisplay)
	local removeRemote = Remotes.event(Remotes.names.museumRemove)
	local collectRemote = Remotes.event(Remotes.names.museumCollect)

	local gui = Instance.new("ScreenGui")
	gui.Name = "MuseumHud"
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
	title.Position = UDim2.fromOffset(PANEL_PADDING * 2, 0)
	title.Size = UDim2.new(1, -(ACTION_WIDTH + PANEL_PADDING * 4), 0, HEADER_HEIGHT)
	title.Font = Enum.Font.GothamBold
	title.TextSize = TITLE_SIZE
	title.TextColor3 = COLOR_TEXT
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = Strings.museum.title
	title.Parent = panel

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -PANEL_PADDING, 0, PANEL_PADDING)
	close.Size = UDim2.fromOffset(ACTION_WIDTH, HEADER_HEIGHT - PANEL_PADDING)
	close.BackgroundColor3 = COLOR_CLOSE
	close.TextColor3 = COLOR_TEXT
	close.Font = Enum.Font.GothamBold
	close.TextSize = TEXT_SIZE
	close.Text = Strings.museum.close
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

	local function render(snapshot: Snapshot)
		for _, child in body:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
		local view = snapshot.view

		newText(
			body,
			MuseumMessages.describeIncome(Strings, view.pendingIncome, view.incomePerHour),
			TEXT_SIZE,
			COLOR_TEXT,
			false
		)
		if view.pendingIncome > 0 then
			newRow(body, Strings.museum.collect, Strings.museum.collect, function()
				collectRemote:FireServer()
			end)
		end

		newText(body, Strings.museum.setsLabel, TEXT_SIZE, COLOR_HEADING, true)
		for _, progress in view.sets do
			newText(body, MuseumMessages.describeSet(Strings, progress), TEXT_SIZE, COLOR_TEXT, false)
		end

		local used: { [number]: MuseumLogic.Display } = {}
		for _, display in view.displays do
			used[display.slot] = display
		end
		local firstFree: number? = nil
		newText(body, Strings.museum.showcasesLabel, TEXT_SIZE, COLOR_HEADING, true)
		for slot = 1, view.slotCount do
			local display = used[slot]
			if display ~= nil then
				newRow(
					body,
					string.format(Strings.museum.showcaseLine, slot, MuseumMessages.describeFind(Strings, display.find)),
					Strings.museum.remove,
					function()
						removeRemote:FireServer(slot)
					end
				)
			else
				if firstFree == nil then
					firstFree = slot
				end
				newRow(body, string.format(Strings.museum.showcaseLine, slot, Strings.museum.emptyShowcase), nil, nil)
			end
		end

		newText(body, Strings.museum.backpackLabel, TEXT_SIZE, COLOR_HEADING, true)
		if #view.backpackFinds == 0 then
			newText(body, Strings.museum.emptyBackpack, TEXT_SIZE, COLOR_TEXT, false)
		end
		for _, find in view.backpackFinds do
			local text = MuseumMessages.describeFind(Strings, find)
			local findId = find.id
			if firstFree ~= nil and findId ~= nil then
				local target = firstFree
				newRow(body, text, Strings.museum.display, function()
					displayRemote:FireServer(findId, target)
				end)
			else
				newRow(body, text, nil, nil)
			end
		end

		newText(body, Strings.museum.admiresLabel, TEXT_SIZE, COLOR_HEADING, true)
		newText(
			body,
			string.format(Strings.museum.admiresLine, view.admires, view.weekAdmires),
			TEXT_SIZE,
			COLOR_TEXT,
			false
		)
		if #snapshot.board > 0 then
			newText(body, Strings.museum.boardLabel, TEXT_SIZE, COLOR_HEADING, true)
			for rank, entry in snapshot.board do
				newText(
					body,
					string.format(Strings.museum.boardLine, rank, entry.name, entry.weekAdmires),
					TEXT_SIZE,
					COLOR_TEXT,
					false
				)
			end
		end
	end

	close.Activated:Connect(function()
		panel.Visible = false
	end)

	museumOpen.OnClientEvent:Connect(function(snapshot: Snapshot)
		if type(snapshot) ~= "table" or type(snapshot.view) ~= "table" then
			log.warn("unexpected museum snapshot from server")
			return
		end
		render(snapshot)
		panel.Visible = true
	end)

	museumResult.OnClientEvent:Connect(function(payload: ResultPayload)
		if type(payload) ~= "table" then
			log.warn("unexpected museum result from server")
			return
		end
		if type(payload.snapshot) == "table" and panel.Visible then
			render(payload.snapshot)
		end
		showMessage(
			MuseumMessages.describeResult(
				Strings,
				payload.ok,
				payload.kind,
				payload.reason,
				payload.coins or 0,
				payload.name
			)
		)
	end)

	gui.Parent = playerGui
end

return MuseumUI
