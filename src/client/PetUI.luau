--!strict
-- Pet panel for the local player: eggs, the egg offer with all chances in
-- percent, the free egg for restricted players, hatching and the collection.
-- The client only sends intentions (look at the offer, open an egg, put a pet
-- to work); the server rolls and decides. The panel is hidden during the first
-- minutes of a new player. Built in code so Rojo owns it (no GUI edits in Studio).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local PetMessages = require(Shared:WaitForChild("PetMessages"))
local Pets = require(Shared:WaitForChild("Pets"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))

local log = Log.new("PetUI")

-- Layout and timing of the interface (not game values).
local TOGGLE_WIDTH = 120
local TOGGLE_HEIGHT = 44
-- The toggle sits above the shop toggle in the button column on the right.
local STACK_BELOW_TOGGLE = 24 + 120 + 12 + 64 + 12 + 44 + 12 + 44 + 12 + 44 + 12
local BUTTON_MARGIN = 24
local BUTTON_GAP = 12
local PANEL_WIDTH = 300
local PADDING = 8
local ACTION_HEIGHT = 36
local TEXT_SIZE = 16
local MESSAGE_SECONDS = 3
local MESSAGE_TOP = 268 -- below the other messages
local MESSAGE_WIDTH = 320
local RETRY_SECONDS = 0.5
local AVAILABLE_POLL_SECONDS = 5

local COLOR_TOGGLE = Color3.fromRGB(120, 200, 140)
local COLOR_TOGGLE_TEXT = Color3.fromRGB(10, 40, 20)
local COLOR_PANEL = Color3.fromRGB(30, 30, 36)
local COLOR_ROW = Color3.fromRGB(48, 48, 58)
local COLOR_ACTION = Color3.fromRGB(230, 170, 60)
local COLOR_ACTION_TEXT = Color3.fromRGB(40, 30, 10)
local COLOR_ACTIVE = Color3.fromRGB(120, 200, 140)
local COLOR_DISABLED = Color3.fromRGB(95, 95, 105)
local COLOR_DISABLED_TEXT = Color3.fromRGB(215, 215, 220)
local COLOR_TEXT = Color3.fromRGB(245, 245, 245)
local COLOR_MUTED = Color3.fromRGB(190, 190, 200)
local COLOR_HEADING = Color3.fromRGB(170, 190, 255)

type ResultPayload = {
	ok: boolean,
	reason: string?,
	snapshot: Pets.Snapshot?,
	hatched: Pets.OpenResult?,
}

local PetUI = {}

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

local function clearChildren(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
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

local function addButton(parent: Instance, text: string, enabled: boolean, color: Color3?, onActivated: () -> ())
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -2 * PADDING, 0, ACTION_HEIGHT)
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

function PetUI.start()
	if started then
		return
	end
	started = true

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local getPets = Remotes.func(Remotes.names.getPets)
	local offerRemote = Remotes.event(Remotes.names.petOffer)
	local openRemote = Remotes.event(Remotes.names.petOpen)
	local equipRemote = Remotes.event(Remotes.names.petEquip)
	local freeRemote = Remotes.event(Remotes.names.petFree)
	local petResult = Remotes.event(Remotes.names.petResult)

	local gui = Instance.new("ScreenGui")
	gui.Name = "PetHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets

	local toggle = Instance.new("TextButton")
	toggle.Visible = false -- appears once the pets are available
	toggle.AnchorPoint = Vector2.new(1, 1)
	toggle.Position = UDim2.new(1, -BUTTON_MARGIN, 1, -STACK_BELOW_TOGGLE)
	toggle.Size = UDim2.fromOffset(TOGGLE_WIDTH, TOGGLE_HEIGHT)
	toggle.BackgroundColor3 = COLOR_TOGGLE
	toggle.TextColor3 = COLOR_TOGGLE_TEXT
	toggle.Font = Enum.Font.GothamBold
	toggle.TextSize = TEXT_SIZE + 2
	toggle.Text = Strings.pets.open
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

	local available = false

	local function render(snapshot: Pets.Snapshot)
		local view = snapshot.view
		available = view.available
		toggle.Visible = view.available
		if not view.available then
			panel.Visible = false
		end
		clearChildren(body)

		newText(body, Strings.pets.note, false, COLOR_MUTED, 3 * (TEXT_SIZE + 2))

		-- Eggs and what can be done with them.
		local eggRow = newRow(body)
		newText(eggRow, Strings.pets.eggHeading, true, COLOR_TEXT, TEXT_SIZE + 6)
		newText(eggRow, PetMessages.eggsText(Strings, view.eggs), true, COLOR_HEADING, TEXT_SIZE + 4)
		addButton(eggRow, Strings.pets.openEgg, view.eggs > 0, COLOR_ACTIVE, function()
			openRemote:FireServer()
		end)
		local egg = view.egg
		if egg ~= nil then
			newText(eggRow, PetMessages.priceText(Strings, egg.robux), false, COLOR_TEXT, TEXT_SIZE + 4)
			addButton(eggRow, PetMessages.actionText(Strings, egg), egg.buyable, nil, function()
				offerRemote:FireServer()
			end)
		end
		local free = view.free
		if free ~= nil then
			newText(eggRow, Strings.pets.freeNote, false, COLOR_MUTED, 2 * (TEXT_SIZE + 2))
			addButton(eggRow, PetMessages.freeText(Strings, free), free.canClaim, nil, function()
				freeRemote:FireServer()
			end)
		end

		-- All chances in percent, before anything is bought.
		local chanceRow = newRow(body)
		newText(chanceRow, Strings.pets.eggNote, false, COLOR_MUTED, 2 * (TEXT_SIZE + 2))
		for _, row in snapshot.rarities do
			newText(
				chanceRow,
				PetMessages.rarityChanceLine(Strings, row.rarityId, row.percent),
				false,
				COLOR_TEXT,
				TEXT_SIZE + 2
			)
		end
		newText(
			chanceRow,
			PetMessages.pityLine(Strings, snapshot.pityAfter, snapshot.pityRarity),
			false,
			COLOR_MUTED,
			2 * (TEXT_SIZE + 2)
		)
		newText(
			chanceRow,
			PetMessages.pityProgress(Strings, view.eggsUntilGuarantee),
			false,
			COLOR_MUTED,
			2 * (TEXT_SIZE + 2)
		)
		newText(chanceRow, Strings.pets.petsHeading, false, COLOR_MUTED, 2 * (TEXT_SIZE + 2))
		for _, row in snapshot.pets do
			newText(
				chanceRow,
				PetMessages.petChanceLine(Strings, row.petId, row.rarityId, row.percent),
				true,
				COLOR_TEXT,
				TEXT_SIZE + 2
			)
			newText(chanceRow, PetMessages.effectText(Strings, row.effect), false, COLOR_MUTED, TEXT_SIZE + 2)
		end

		-- The collection.
		newText(body, Strings.pets.collectionHeading, true, COLOR_HEADING, TEXT_SIZE + 8)
		local working = 0
		for _, pet in view.owned do
			if pet.equipped then
				working += 1
			end
		end
		newText(body, PetMessages.slotsText(Strings, working, view.slots), false, COLOR_MUTED, TEXT_SIZE + 4)
		newText(
			body,
			PetMessages.collectionText(Strings, #view.owned, view.maxOwned),
			false,
			COLOR_MUTED,
			TEXT_SIZE + 4
		)
		if #view.owned == 0 then
			newText(body, Strings.pets.empty, false, COLOR_MUTED, TEXT_SIZE + 4)
		end
		for _, pet in view.owned do
			local row = newRow(body)
			newText(
				row,
				string.format(
					"%s (%s)",
					PetMessages.petName(Strings, pet.petId),
					PetMessages.rarityName(Strings, pet.rarityId)
				),
				true,
				COLOR_TEXT,
				TEXT_SIZE + 4
			)
			newText(row, PetMessages.effectText(Strings, pet.effect), false, COLOR_MUTED, TEXT_SIZE + 2)
			addButton(
				row,
				if pet.equipped then Strings.pets.rest else Strings.pets.work,
				true,
				if pet.equipped then COLOR_ACTIVE else nil,
				function()
					equipRemote:FireServer(pet.instanceId)
				end
			)
		end
	end

	local function refresh(): boolean
		local ok, result = pcall(function()
			return getPets:InvokeServer()
		end)
		if ok and type(result) == "table" then
			render(result :: Pets.Snapshot)
			return true
		end
		if not ok then
			log.warn("could not read the pets", { error = tostring(result) })
		end
		return false
	end

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			task.spawn(refresh)
		end
	end)

	petResult.OnClientEvent:Connect(function(payload: ResultPayload)
		if type(payload) ~= "table" then
			log.warn("unexpected pet result from server")
			return
		end
		if type(payload.snapshot) == "table" then
			render(payload.snapshot)
		end
		local hatched = payload.hatched
		if hatched ~= nil then
			showMessage(PetMessages.hatchedText(Strings, hatched.petId, hatched.rarityId, hatched.guaranteed))
		elseif not payload.ok then
			showMessage(PetMessages.describeResult(Strings, payload.ok, payload.reason))
		end
	end)

	gui.Parent = playerGui

	-- The profile may still be loading, and the pets open only after the onboarding.
	task.spawn(function()
		while not refresh() do
			task.wait(RETRY_SECONDS)
		end
		while not available do
			task.wait(AVAILABLE_POLL_SECONDS)
			refresh()
		end
	end)
end

return PetUI
