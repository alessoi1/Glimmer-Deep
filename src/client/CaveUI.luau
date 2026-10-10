--!strict
-- Cave controls for the local player: the buttons to go down and up, and tap
-- or hold on a block to swing at it (or to open a chest). The client only
-- sends which block it aims at; the server checks reach, cooldown and rules and
-- decides everything. Built in code so Rojo owns it. Only active while
-- Config/Cave.enabled is on. Only checkable in Roblox Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CaveView = require(Shared:WaitForChild("CaveView"))
local Log = require(Shared:WaitForChild("Log"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Strings = require(Shared:WaitForChild("Strings"))
local CaveConfig = require(Shared:WaitForChild("Config"):WaitForChild("Cave"))

local log = Log.new("CaveUI")

local CaveUI = {}

local started = false

-- Layout and timing (not game values).
local BUTTON_WIDTH = 150
local BUTTON_HEIGHT = 64
local BUTTON_MARGIN = 16
local TEXT_SIZE = 20
local MESSAGE_SECONDS = 2.5
local HOLD_POLL_SECONDS = 0.25
local RAY_LENGTH = 200
local COLOR_BUTTON = Color3.fromRGB(70, 110, 190)
local COLOR_BUTTON_TEXT = Color3.fromRGB(245, 245, 245)
local COLOR_TEXT = Color3.fromRGB(245, 245, 245)

type ChestSummary = { coins: number, gear: number, potions: number, herbs: number, finds: number }
type CaveResultPayload = {
	ok: boolean,
	reason: string?,
	entered: boolean?,
	left: boolean?,
	chest: ChestSummary?,
	stoppedFull: boolean?,
}

-- "row,x,y" is how the server names the block parts.
local function parseKey(name: string): (number?, number?, number?)
	local row, x, y = string.match(name, "^(-?%d+),(-?%d+),(-?%d+)$")
	if row == nil then
		return nil, nil, nil
	end
	return tonumber(row), tonumber(x), tonumber(y)
end

-- The direction the hit face looks along, from the surface normal.
local function axisOf(normal: Vector3): string
	local axes = CaveView.axes(CaveConfig.world)
	local best, bestValue = "row", -1
	local candidates = {
		{ "row", axes.forward },
		{ "x", axes.right },
		{ "y", axes.up },
	}
	for _, candidate in candidates do
		local vec = candidate[2] :: CaveView.Vec
		local value = math.abs(normal.X * vec.x + normal.Y * vec.y + normal.Z * vec.z)
		if value > bestValue then
			best, bestValue = candidate[1] :: string, value
		end
	end
	return best
end

local function newButton(gui: ScreenGui, text: string, order: number): TextButton
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0, 0)
	button.Position = UDim2.new(0, BUTTON_MARGIN, 0, BUTTON_MARGIN + order * (BUTTON_HEIGHT + 8))
	button.Size = UDim2.fromOffset(BUTTON_WIDTH, BUTTON_HEIGHT)
	button.BackgroundColor3 = COLOR_BUTTON
	button.TextColor3 = COLOR_BUTTON_TEXT
	button.Font = Enum.Font.GothamBold
	button.TextSize = TEXT_SIZE
	button.Text = text
	button.AutoButtonColor = true
	button.Parent = gui
	local corner = Instance.new("UICorner")
	corner.Parent = button
	return button
end

function CaveUI.start()
	if started then
		return
	end
	started = true
	if not CaveConfig.enabled then
		return
	end

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local enter = Remotes.event(Remotes.names.caveEnter)
	local leave = Remotes.event(Remotes.names.caveLeave)
	local swing = Remotes.event(Remotes.names.caveSwing)
	local chest = Remotes.event(Remotes.names.caveChest)
	local result = Remotes.event(Remotes.names.caveResult)

	local gui = Instance.new("ScreenGui")
	gui.Name = "CaveControls"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets

	local enterButton = newButton(gui, Strings.cave.enter, 0)
	local leaveButton = newButton(gui, Strings.cave.leave, 0)
	leaveButton.Visible = false

	local messageLabel = Instance.new("TextLabel")
	messageLabel.BackgroundTransparency = 1
	messageLabel.AnchorPoint = Vector2.new(0.5, 0)
	messageLabel.Position = UDim2.new(0.5, 0, 0, BUTTON_MARGIN + 40)
	messageLabel.Size = UDim2.fromOffset(420, TEXT_SIZE + 10)
	messageLabel.Font = Enum.Font.GothamBold
	messageLabel.TextSize = TEXT_SIZE
	messageLabel.TextColor3 = COLOR_TEXT
	messageLabel.TextStrokeTransparency = 0.5
	messageLabel.Text = ""
	messageLabel.Parent = gui

	local inCave = false
	local messageToken = 0
	local holding = false
	local pointer = Vector2.zero

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

	local function setInCave(value: boolean)
		inCave = value
		enterButton.Visible = not value
		leaveButton.Visible = value
	end

	-- What the pointer aims at: a block part of the player's own cave.
	local function aimedBlock(): (number?, number?, number?, string?, string?)
		local folder = Workspace:FindFirstChild("Caves")
		local camera = Workspace.CurrentCamera
		if folder == nil or camera == nil then
			return nil, nil, nil, nil, nil
		end
		local ray = camera:ViewportPointToRay(pointer.X, pointer.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { folder }
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)
		if hit == nil then
			return nil, nil, nil, nil, nil
		end
		local row, x, y = parseKey(hit.Instance.Name)
		if row == nil or x == nil or y == nil then
			return nil, nil, nil, nil, nil
		end
		local kind = hit.Instance:GetAttribute("Kind")
		return row, x, y, axisOf(hit.Normal), if type(kind) == "string" then kind else nil
	end

	local function swingAtPointer()
		local row, x, y, axis, kind = aimedBlock()
		if row == nil or x == nil or y == nil or axis == nil then
			return
		end
		if kind == "bedrock" then
			return
		end
		if kind == "chest" then
			chest:FireServer(row, x, y)
		else
			swing:FireServer(row, x, y, axis)
		end
	end

	local function startHolding()
		if holding then
			return
		end
		holding = true
		task.spawn(function()
			repeat
				swingAtPointer()
				task.wait(HOLD_POLL_SECONDS)
			until not holding
		end)
	end

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or not inCave then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			pointer = Vector2.new(input.Position.X, input.Position.Y)
			startHolding()
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if
			holding
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			pointer = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			holding = false
		end
	end)

	enterButton.Activated:Connect(function()
		enter:FireServer()
	end)
	leaveButton.Activated:Connect(function()
		leave:FireServer()
	end)

	result.OnClientEvent:Connect(function(payload: CaveResultPayload)
		if type(payload) ~= "table" then
			log.warn("unexpected cave result from server")
			return
		end
		if payload.entered then
			setInCave(true)
		elseif payload.left then
			setInCave(false)
		end
		local summary = payload.chest
		if payload.ok and summary ~= nil then
			showMessage(
				string.format(
					Strings.cave.chestOpened,
					summary.coins,
					summary.gear,
					summary.potions,
					summary.herbs,
					summary.finds
				)
			)
		elseif not payload.ok then
			if payload.reason == "backpack_full" then
				showMessage(Strings.cave.backpackFull)
			elseif payload.reason == "out_of_reach" then
				showMessage(Strings.cave.tooFar)
			elseif payload.reason == "unavailable" then
				showMessage(Strings.cave.unavailable)
			end
		elseif payload.stoppedFull then
			showMessage(Strings.cave.backpackFull)
		end
	end)

	-- A respawn puts the player back on the plot.
	player.CharacterAdded:Connect(function()
		setInCave(false)
	end)

	gui.Parent = playerGui
	log.info("started")
end

return CaveUI
