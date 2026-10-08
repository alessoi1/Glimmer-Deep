--!strict
-- The "Während du weg warst" window: shown once after joining when the digger
-- helper dug while the player was away. The client only displays the report
-- the server sends; it computes nothing. Built in code so Rojo owns it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local OfflineMessages = require(Shared:WaitForChild("OfflineMessages"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))

local log = Log.new("OfflineUI")

-- Layout and timing of the interface (not game values).
local PANEL_WIDTH = 320
local PANEL_MAX_HEIGHT = 420
local PADDING = 12
local TITLE_SIZE = 19
local TEXT_SIZE = 15
local BUTTON_HEIGHT = 52
local RETRY_SECONDS = 0.5

local COLOR_PANEL = Color3.fromRGB(30, 30, 36)
local COLOR_TEXT = Color3.fromRGB(245, 245, 245)
local COLOR_HINT = Color3.fromRGB(170, 190, 255)
local COLOR_BUTTON = Color3.fromRGB(230, 170, 60)
local COLOR_BUTTON_TEXT = Color3.fromRGB(40, 30, 10)

type Answer = {
	ready: boolean,
	report: OfflineMessages.Report?,
	maxSeconds: number,
}

local OfflineUI = {}

local started = false

local function newText(parent: Instance, text: string, size: number, color: Color3, bold: boolean, order: number)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -2 * PADDING, 0, size + 8)
	label.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	label.TextSize = size
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Text = text
	label.LayoutOrder = order
	label.Parent = parent
end

function OfflineUI.start()
	if started then
		return
	end
	started = true

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local getReport = Remotes.func(Remotes.names.getOfflineReport)

	task.spawn(function()
		local answer: Answer? = nil
		while answer == nil do
			local ok, result = pcall(function()
				return getReport:InvokeServer()
			end)
			if ok and type(result) == "table" and result.ready == true then
				answer = result :: Answer
			else
				if not ok then
					log.warn("could not read the offline report", { error = tostring(result) })
				end
				task.wait(RETRY_SECONDS)
			end
		end

		local report = answer.report
		if report == nil then
			return
		end

		local gui = Instance.new("ScreenGui")
		gui.Name = "OfflineHud"
		gui.ResetOnSpawn = false
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		gui.DisplayOrder = 10

		local panel = Instance.new("Frame")
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.Size = UDim2.new(0, PANEL_WIDTH, 0.8, 0)
		panel.BackgroundColor3 = COLOR_PANEL
		panel.BackgroundTransparency = 0.05
		panel.Parent = gui
		local corner = Instance.new("UICorner")
		corner.Parent = panel
		local limit = Instance.new("UISizeConstraint")
		limit.MaxSize = Vector2.new(PANEL_WIDTH, PANEL_MAX_HEIGHT)
		limit.Parent = panel

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromOffset(PADDING, PADDING)
		title.Size = UDim2.new(1, -2 * PADDING, 0, TITLE_SIZE + 8)
		title.Font = Enum.Font.GothamBold
		title.TextSize = TITLE_SIZE
		title.TextColor3 = COLOR_TEXT
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = Strings.offline.title
		title.Parent = panel

		local body = Instance.new("ScrollingFrame")
		body.BackgroundTransparency = 1
		body.BorderSizePixel = 0
		body.Position = UDim2.fromOffset(0, TITLE_SIZE + 8 + 2 * PADDING)
		body.Size = UDim2.new(1, 0, 1, -(TITLE_SIZE + 8 + 3 * PADDING + BUTTON_HEIGHT))
		body.AutomaticCanvasSize = Enum.AutomaticSize.Y
		body.CanvasSize = UDim2.new()
		body.ScrollBarThickness = 6
		body.Parent = panel
		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.Parent = body

		local lines = OfflineMessages.describeReport(Strings, report, answer.maxSeconds)
		for index, line in lines do
			newText(body, line, TEXT_SIZE, COLOR_TEXT, false, index)
		end
		newText(body, Strings.offline.depotHint, TEXT_SIZE - 1, COLOR_HINT, false, #lines + 1)

		local button = Instance.new("TextButton")
		button.AnchorPoint = Vector2.new(0.5, 1)
		button.Position = UDim2.new(0.5, 0, 1, -PADDING)
		button.Size = UDim2.new(1, -2 * PADDING, 0, BUTTON_HEIGHT)
		button.BackgroundColor3 = COLOR_BUTTON
		button.TextColor3 = COLOR_BUTTON_TEXT
		button.Font = Enum.Font.GothamBold
		button.TextSize = TEXT_SIZE + 2
		button.Text = Strings.offline.ok
		button.Parent = panel
		local buttonCorner = Instance.new("UICorner")
		buttonCorner.Parent = button
		button.Activated:Connect(function()
			gui:Destroy()
		end)

		gui.Parent = playerGui
	end)
end

return OfflineUI
