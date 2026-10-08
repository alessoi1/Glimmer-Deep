--!strict
-- Shop panel for the local player: the game passes with name, effect, price and
-- an "Angebot ansehen" button. The button is hidden during the first minutes of
-- a new player (no purchase offers then). The client only says which offer it
-- wants to see; the server opens the Roblox purchase prompt. Built in code so
-- Rojo owns it (no GUI edits in Studio).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoosterMessages = require(Shared:WaitForChild("BoosterMessages"))
local Boosters = require(Shared:WaitForChild("Boosters"))
local Log = require(Shared:WaitForChild("Log"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ShopLogic = require(Shared:WaitForChild("ShopLogic"))
local ShopMessages = require(Shared:WaitForChild("ShopMessages"))
local Strings = require(Shared:WaitForChild("Strings"))

local log = Log.new("ShopUI")

-- Layout and timing of the interface (not game values).
local TOGGLE_WIDTH = 120
local TOGGLE_HEIGHT = 44
-- The toggle sits above the quests toggle in the button column on the right.
local STACK_BELOW_TOGGLE = 24 + 120 + 12 + 64 + 12 + 44 + 12 + 44 + 12
local BUTTON_MARGIN = 24
local BUTTON_GAP = 12
local PANEL_WIDTH = 300
local PADDING = 8
local ROW_HEIGHT = 84
local ACTION_HEIGHT = 36
local TEXT_SIZE = 16
local MESSAGE_SECONDS = 2.5
local MESSAGE_TOP = 232 -- below the other messages
local MESSAGE_WIDTH = 320
local RETRY_SECONDS = 0.5
local AVAILABLE_POLL_SECONDS = 5

local COLOR_TOGGLE = Color3.fromRGB(90, 190, 190)
local COLOR_TOGGLE_TEXT = Color3.fromRGB(10, 40, 40)
local COLOR_PANEL = Color3.fromRGB(30, 30, 36)
local COLOR_ROW = Color3.fromRGB(48, 48, 58)
local COLOR_ACTION = Color3.fromRGB(230, 170, 60)
local COLOR_ACTION_TEXT = Color3.fromRGB(40, 30, 10)
local COLOR_DISABLED = Color3.fromRGB(95, 95, 105)
local COLOR_DISABLED_TEXT = Color3.fromRGB(215, 215, 220)
local COLOR_TEXT = Color3.fromRGB(245, 245, 245)
local COLOR_MUTED = Color3.fromRGB(190, 190, 200)
local COLOR_HEADING = Color3.fromRGB(170, 190, 255)

type BoosterResultPayload = {
	ok: boolean,
	reason: string?,
	snapshot: Boosters.Snapshot?,
}

type ResultPayload = {
	ok: boolean,
	reason: string?,
	snapshot: ShopLogic.View?,
}

local ShopUI = {}

local started = false

local function newText(parent: Instance, text: string, bold: boolean, color: Color3, height: number)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -2 * PADDING, 0, height)
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	label.TextSize = TEXT_SIZE
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Text = text
	label.Parent = parent
end

function ShopUI.start()
	if started then
		return
	end
	started = true

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local getShop = Remotes.func(Remotes.names.getShop)
	local offerRemote = Remotes.event(Remotes.names.shopOffer)
	local travelRemote = Remotes.event(Remotes.names.quickTravel)
	local shopResult = Remotes.event(Remotes.names.shopResult)
	local getBoosters = Remotes.func(Remotes.names.getBoosters)
	local boosterOffer = Remotes.event(Remotes.names.boosterOffer)
	local boosterFree = Remotes.event(Remotes.names.boosterFree)
	local boosterResult = Remotes.event(Remotes.names.boosterResult)

	local gui = Instance.new("ScreenGui")
	gui.Name = "ShopHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets

	local toggle = Instance.new("TextButton")
	toggle.Visible = false -- appears once the shop is available
	toggle.AnchorPoint = Vector2.new(1, 1)
	toggle.Position = UDim2.new(1, -BUTTON_MARGIN, 1, -STACK_BELOW_TOGGLE)
	toggle.Size = UDim2.fromOffset(TOGGLE_WIDTH, TOGGLE_HEIGHT)
	toggle.BackgroundColor3 = COLOR_TOGGLE
	toggle.TextColor3 = COLOR_TOGGLE_TEXT
	toggle.Font = Enum.Font.GothamBold
	toggle.TextSize = TEXT_SIZE + 2
	toggle.Text = Strings.shop.open
	toggle.Parent = gui
	local toggleCorner = Instance.new("UICorner")
	toggleCorner.Parent = toggle

	local panel = Instance.new("Frame")
	panel.Visible = false
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -(BUTTON_MARGIN + TOGGLE_WIDTH + BUTTON_GAP), 0.5, 0)
	panel.Size = UDim2.new(0, PANEL_WIDTH, 0.85, 0)
	panel.BackgroundColor3 = COLOR_PANEL
	panel.BackgroundTransparency = 0.1
	panel.Parent = gui
	local panelCorner = Instance.new("UICorner")
	panelCorner.Parent = panel
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(PANEL_WIDTH, 460)
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
	local function newBox(order: number): Frame
		local box = Instance.new("Frame")
		box.BackgroundTransparency = 1
		box.LayoutOrder = order
		box.Size = UDim2.fromScale(1, 0)
		box.AutomaticSize = Enum.AutomaticSize.Y
		box.Parent = body
		local boxList = Instance.new("UIListLayout")
		boxList.Padding = UDim.new(0, 6)
		boxList.SortOrder = Enum.SortOrder.LayoutOrder
		boxList.HorizontalAlignment = Enum.HorizontalAlignment.Center
		boxList.Parent = box
		return box
	end
	local passesBox = newBox(1)
	local boostersBox = newBox(2)

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

	local function addButton(parent: Instance, text: string, enabled: boolean, onActivated: () -> ())
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, -2 * PADDING, 0, ACTION_HEIGHT)
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

	local available = false

	local function render(view: ShopLogic.View)
		available = view.available
		toggle.Visible = view.available
		if not view.available then
			panel.Visible = false
		end
		for _, child in passesBox:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		newText(passesBox, Strings.shop.note, false, COLOR_MUTED, 2 * (TEXT_SIZE + 4))
		local travelOwned = false
		for _, pass in view.passes do
			if pass.key == "quick_travel" and pass.owned then
				travelOwned = true
			end
			local row = Instance.new("Frame")
			row.BackgroundColor3 = COLOR_ROW
			row.Size = UDim2.new(1, -2 * PADDING, 0, ROW_HEIGHT + ACTION_HEIGHT + PADDING)
			row.Parent = passesBox
			local corner = Instance.new("UICorner")
			corner.Parent = row
			local rowList = Instance.new("UIListLayout")
			rowList.Padding = UDim.new(0, 4)
			rowList.SortOrder = Enum.SortOrder.LayoutOrder
			rowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
			rowList.Parent = row
			newText(row, ShopMessages.passName(Strings, pass.key), true, COLOR_TEXT, TEXT_SIZE + 6)
			newText(row, ShopMessages.passDescription(Strings, pass.key), false, COLOR_MUTED, 2 * (TEXT_SIZE + 2))
			newText(row, ShopMessages.priceText(Strings, pass.robux), false, COLOR_TEXT, TEXT_SIZE + 4)
			addButton(row, ShopMessages.actionText(Strings, pass), pass.buyable, function()
				offerRemote:FireServer(pass.key)
			end)
		end

		if travelOwned then
			newText(passesBox, Strings.shop.travelHeading, true, COLOR_HEADING, TEXT_SIZE + 8)
			addButton(passesBox, Strings.shop.travelSell, true, function()
				travelRemote:FireServer("sell")
			end)
			addButton(passesBox, Strings.shop.travelShaft, true, function()
				travelRemote:FireServer("shaft")
			end)
		end
	end

	local function newRow(parent: Instance): Frame
		local row = Instance.new("Frame")
		row.BackgroundColor3 = COLOR_ROW
		row.Size = UDim2.new(1, -2 * PADDING, 0, 0)
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
		rowPadding.PaddingTop = UDim.new(0, PADDING)
		rowPadding.PaddingBottom = UDim.new(0, PADDING)
		rowPadding.Parent = row
		return row
	end

	local function renderBoosters(snapshot: Boosters.Snapshot)
		for _, child in boostersBox:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local view = snapshot.view
		boostersBox.Visible = view.available
		if not view.available then
			return
		end

		newText(boostersBox, Strings.shop.boosters.heading, true, COLOR_HEADING, TEXT_SIZE + 8)
		newText(boostersBox, Strings.shop.boosters.note, false, COLOR_MUTED, 2 * (TEXT_SIZE + 4))
		for _, booster in view.boosters do
			local row = newRow(boostersBox)
			newText(row, BoosterMessages.name(Strings, booster.key), true, COLOR_TEXT, TEXT_SIZE + 6)
			newText(row, BoosterMessages.description(Strings, booster.key), false, COLOR_MUTED, 3 * (TEXT_SIZE + 2))
			-- Paid random item: show the exact chances before the purchase.
			if booster.luckBonus > 0 then
				newText(row, Strings.shop.boosters.chancesHeading, false, COLOR_MUTED, 2 * (TEXT_SIZE + 2))
				for _, chance in snapshot.chances do
					newText(
						row,
						BoosterMessages.chanceLine(Strings, chance.rarityId, chance.base, chance.boosted),
						false,
						COLOR_TEXT,
						TEXT_SIZE + 2
					)
				end
				newText(
					row,
					BoosterMessages.mutationLine(Strings, snapshot.mutationBase, snapshot.mutationBoosted),
					false,
					COLOR_TEXT,
					TEXT_SIZE + 2
				)
			end
			newText(row, BoosterMessages.priceText(Strings, booster.robux), false, COLOR_TEXT, TEXT_SIZE + 4)
			if booster.remaining > 0 then
				newText(
					row,
					BoosterMessages.runningText(Strings, booster.remaining),
					true,
					COLOR_HEADING,
					TEXT_SIZE + 4
				)
			end
			addButton(row, BoosterMessages.actionText(Strings, booster), booster.buyable, function()
				boosterOffer:FireServer(booster.key)
			end)
		end

		local free = view.free
		if free ~= nil then
			local row = newRow(boostersBox)
			newText(row, Strings.shop.boosters.freeHeading, true, COLOR_TEXT, TEXT_SIZE + 6)
			newText(row, Strings.shop.boosters.freeNote, false, COLOR_MUTED, 2 * (TEXT_SIZE + 2))
			newText(row, Strings.shop.boosters.chancesHeading, false, COLOR_MUTED, 2 * (TEXT_SIZE + 2))
			for _, chance in snapshot.chances do
				newText(
					row,
					BoosterMessages.chanceLine(Strings, chance.rarityId, chance.base, chance.boosted),
					false,
					COLOR_TEXT,
					TEXT_SIZE + 2
				)
			end
			addButton(row, BoosterMessages.freeText(Strings, free), free.canClaim, function()
				boosterFree:FireServer()
			end)
		end
	end

	local function refresh(): boolean
		local ok, result = pcall(function()
			return getShop:InvokeServer()
		end)
		if ok and type(result) == "table" then
			render(result :: ShopLogic.View)
			local boostersOk, snapshot = pcall(function()
				return getBoosters:InvokeServer()
			end)
			if boostersOk and type(snapshot) == "table" then
				renderBoosters(snapshot :: Boosters.Snapshot)
			elseif not boostersOk then
				log.warn("could not read the boosters", { error = tostring(snapshot) })
			end
			return true
		end
		if not ok then
			log.warn("could not read the shop", { error = tostring(result) })
		end
		return false
	end

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			task.spawn(refresh)
		end
	end)

	shopResult.OnClientEvent:Connect(function(payload: ResultPayload)
		if type(payload) ~= "table" then
			log.warn("unexpected shop result from server")
			return
		end
		if type(payload.snapshot) == "table" then
			render(payload.snapshot)
		end
		if not payload.ok or payload.reason ~= nil then
			showMessage(ShopMessages.describeResult(Strings, payload.ok, payload.reason))
		end
	end)

	boosterResult.OnClientEvent:Connect(function(payload: BoosterResultPayload)
		if type(payload) ~= "table" then
			log.warn("unexpected booster result from server")
			return
		end
		if type(payload.snapshot) == "table" then
			renderBoosters(payload.snapshot)
		end
		if not payload.ok or payload.reason ~= nil then
			showMessage(BoosterMessages.describeResult(Strings, payload.ok, payload.reason))
		end
	end)

	gui.Parent = playerGui

	-- The profile may still be loading, and the shop opens only after the onboarding.
	task.spawn(function()
		while not refresh() do
			task.wait(RETRY_SECONDS)
		end
		-- Look again until the onboarding is over and the shop opens.
		while not available do
			task.wait(AVAILABLE_POLL_SECONDS)
			refresh()
		end
	end)
end

return ShopUI
