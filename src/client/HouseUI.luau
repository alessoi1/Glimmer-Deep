--!strict
-- House panel for the local player: opens when the server says so (the owner
-- used the house sign). Shows the house level with the upgrade, and the
-- decoration to buy, place and take back. The client only sends intentions (an
-- item id, a place number); the server checks the coins and decides. Built in
-- code so Rojo owns it (no GUI edits in Studio).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local House = require(Shared:WaitForChild("House"))
local HouseMessages = require(Shared:WaitForChild("HouseMessages"))
local Log = require(Shared:WaitForChild("Log"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))

local log = Log.new("HouseUI")

-- Layout and timing of the interface (not game values).
local PANEL_WIDTH = 340
local PANEL_MAX_HEIGHT = 460
local PANEL_PADDING = 8
local HEADER_HEIGHT = 48
local ACTION_HEIGHT = 36
local ACTION_WIDTH = 104
local TEXT_SIZE = 14
local TITLE_SIZE = 18
local MESSAGE_SECONDS = 2.5
local MESSAGE_TOP = 300 -- below the other messages
local MESSAGE_WIDTH = 320

local COLOR_PANEL = Color3.fromRGB(30, 30, 36)
local COLOR_ROW = Color3.fromRGB(48, 48, 58)
local COLOR_ACTION = Color3.fromRGB(230, 170, 60)
local COLOR_ACTION_TEXT = Color3.fromRGB(40, 30, 10)
local COLOR_ACTIVE = Color3.fromRGB(120, 200, 140)
local COLOR_DISABLED = Color3.fromRGB(95, 95, 105)
local COLOR_DISABLED_TEXT = Color3.fromRGB(215, 215, 220)
local COLOR_CLOSE = Color3.fromRGB(110, 110, 125)
local COLOR_TEXT = Color3.fromRGB(245, 245, 245)
local COLOR_MUTED = Color3.fromRGB(190, 190, 200)
local COLOR_HEADING = Color3.fromRGB(170, 190, 255)

type ResultPayload = {
	ok: boolean,
	reason: string?,
	view: House.View?,
}

local HouseUI = {}

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

local function addButton(parent: Instance, text: string, enabled: boolean, color: Color3?, onActivated: () -> ())
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -2 * PANEL_PADDING, 0, ACTION_HEIGHT)
	button.BackgroundColor3 = if enabled then (color or COLOR_ACTION) else COLOR_DISABLED
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

-- The lowest free decoration place, or nil when all are taken.
local function firstFreeSlot(view: House.View): number?
	local taken: { [number]: boolean } = {}
	for _, entry in view.placed do
		taken[entry.slot] = true
	end
	for slot = 1, view.decorSlots do
		if not taken[slot] then
			return slot
		end
	end
	return nil
end

function HouseUI.start()
	if started then
		return
	end
	started = true

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local houseOpen = Remotes.event(Remotes.names.houseOpen)
	local houseResult = Remotes.event(Remotes.names.houseResult)
	local upgradeRemote = Remotes.event(Remotes.names.houseUpgrade)
	local buyRemote = Remotes.event(Remotes.names.houseBuy)
	local placeRemote = Remotes.event(Remotes.names.housePlace)
	local removeRemote = Remotes.event(Remotes.names.houseRemove)

	local gui = Instance.new("ScreenGui")
	gui.Name = "HouseHud"
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
	title.Text = Strings.house.title
	title.Parent = panel

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -PANEL_PADDING, 0, PANEL_PADDING)
	close.Size = UDim2.fromOffset(ACTION_WIDTH, HEADER_HEIGHT - PANEL_PADDING)
	close.BackgroundColor3 = COLOR_CLOSE
	close.TextColor3 = COLOR_TEXT
	close.Font = Enum.Font.GothamBold
	close.TextSize = TEXT_SIZE
	close.Text = Strings.house.close
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

	local function render(view: House.View)
		for _, child in body:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		local levelRow = newRow(body)
		newText(levelRow, HouseMessages.levelText(Strings, view.level), true, COLOR_TEXT, TEXT_SIZE + 6)
		newText(
			levelRow,
			HouseMessages.upgradeText(Strings, view.level, view.nextCost),
			false,
			COLOR_MUTED,
			2 * (TEXT_SIZE + 2)
		)
		if view.nextCost ~= nil then
			addButton(levelRow, Strings.house.upgrade, view.canUpgrade, nil, function()
				upgradeRemote:FireServer()
			end)
		end

		newText(body, Strings.house.decorHeading, true, COLOR_HEADING, TEXT_SIZE + 8)
		newText(body, Strings.house.decorNote, false, COLOR_MUTED, 3 * (TEXT_SIZE + 2))
		newText(
			body,
			HouseMessages.slotsText(Strings, #view.placed, view.decorSlots),
			false,
			COLOR_MUTED,
			TEXT_SIZE + 4
		)
		local freeSlot = firstFreeSlot(view)
		for _, item in view.items do
			local row = newRow(body)
			newText(row, HouseMessages.itemName(Strings, item.id), true, COLOR_TEXT, TEXT_SIZE + 4)
			if not item.owned then
				newText(row, HouseMessages.priceText(Strings, item.price), false, COLOR_MUTED, TEXT_SIZE + 2)
				addButton(row, Strings.house.buy, view.decorSlots > 0, nil, function()
					buyRemote:FireServer(item.id)
				end)
			elseif item.placedSlot ~= nil then
				local slot = item.placedSlot
				newText(row, string.format(Strings.house.placedAt, slot), false, COLOR_MUTED, TEXT_SIZE + 2)
				addButton(row, Strings.house.remove, true, COLOR_ACTIVE, function()
					removeRemote:FireServer(slot)
				end)
			else
				-- Takes the lowest free place, or replaces the first one when all are taken.
				local target = freeSlot or 1
				addButton(row, Strings.house.place, view.decorSlots > 0, COLOR_ACTIVE, function()
					placeRemote:FireServer(item.id, target)
				end)
			end
		end
	end

	close.Activated:Connect(function()
		panel.Visible = false
	end)

	houseOpen.OnClientEvent:Connect(function(view: House.View)
		if type(view) ~= "table" then
			log.warn("unexpected house view from server")
			return
		end
		render(view)
		panel.Visible = true
	end)

	houseResult.OnClientEvent:Connect(function(payload: ResultPayload)
		if type(payload) ~= "table" then
			log.warn("unexpected house result from server")
			return
		end
		if type(payload.view) == "table" then
			render(payload.view)
		end
		if not payload.ok then
			showMessage(HouseMessages.describeResult(Strings, payload.ok, payload.reason))
		end
	end)

	gui.Parent = playerGui
end

return HouseUI
