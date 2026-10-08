--!strict
-- Builds the models of the world from the pure descriptions in ModelSpecs. If a
-- model with the same name exists in ServerStorage.Models (the folder
-- assets/models, exported from Studio as .rbxm), that one is used instead of
-- the placeholder, so uploaded meshes replace the blocks without code changes.
-- The rules for uploaded models are in docs/MODELLE.md. Only checkable in
-- Roblox Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local ModelSpecs = require(Shared:WaitForChild("ModelSpecs"))
local LookConfig = require(Shared:WaitForChild("Config"):WaitForChild("Look"))

local log = Log.new("Models")

local ModelFactory = {}

local LABEL_WIDTH = 180
local LABEL_HEIGHT = 36
local LABEL_LIFT = 1
local OVERRIDE_FOLDER = "Models"

local palette: ModelSpecs.Palette = LookConfig.palette

ModelFactory.palette = palette
local usedOverrides: { [string]: boolean } = {}

local function color(rgb: ModelSpecs.Rgb): Color3
	return Color3.fromRGB(rgb.r, rgb.g, rgb.b)
end

local function shapeOf(name: string): Enum.PartType
	if name == "Ball" then
		return Enum.PartType.Ball
	elseif name == "Cylinder" then
		return Enum.PartType.Cylinder
	end
	return Enum.PartType.Block
end

local function materialOf(name: string): Enum.Material
	local ok, material = pcall(function()
		return Enum.Material[name]
	end)
	if ok and material ~= nil then
		return material
	end
	log.warn("unknown material, using plastic", { material = name })
	return Enum.Material.Plastic
end

-- The uploaded model with this name, or nil.
local function findOverride(name: string): Model?
	local folder = ServerStorage:FindFirstChild(OVERRIDE_FOLDER)
	local found = if folder ~= nil then folder:FindFirstChild(name) else nil
	if found ~= nil and found:IsA("Model") then
		return found
	end
	return nil
end

local function primaryOf(model: Model, name: string): BasePart?
	if model.PrimaryPart ~= nil then
		return model.PrimaryPart
	end
	local byName = model:FindFirstChild(name, true)
	if byName ~= nil and byName:IsA("BasePart") then
		return byName
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end
	return nil
end

local function buildPart(spec: ModelSpecs.PartSpec, position: Vector3): Part
	local part = Instance.new("Part")
	part.Name = spec.name
	part.Shape = shapeOf(spec.shape)
	part.Size = Vector3.new(spec.sx, spec.sy, spec.sz)
	part.CFrame = CFrame.new(position + Vector3.new(spec.x, spec.y, spec.z))
		* CFrame.Angles(math.rad(spec.rotX or 0), math.rad(spec.rotY or 0), math.rad(spec.rotZ or 0))
	part.Anchored = true
	part.Color = color(spec.color)
	part.Material = materialOf(spec.material)
	part.Transparency = spec.transparency or 0
	part.CanCollide = spec.collide ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if spec.light ~= nil then
		local light = Instance.new("PointLight")
		light.Brightness = spec.light.brightness
		light.Range = spec.light.range
		light.Color = color(spec.light.color)
		light.Parent = part
	end
	return part
end

-- Builds a model at `position` (the center of its base on the ground) under
-- `parent`. Returns the model and its primary part (where prompts and labels
-- attach). An uploaded model with the same name replaces the placeholder; its
-- origin must be the center of its base.
function ModelFactory.build(spec: ModelSpecs.ModelSpec, position: Vector3, parent: Instance): (Model, BasePart)
	local override = if spec.allowOverride == false then nil else findOverride(spec.name)
	if override ~= nil then
		local model = override:Clone()
		model:PivotTo(CFrame.new(position))
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end
		local primary = primaryOf(model, spec.primary)
		if primary ~= nil then
			if not usedOverrides[spec.name] then
				usedOverrides[spec.name] = true
				log.info("using an uploaded model", { name = spec.name })
			end
			model.Parent = parent
			return model, primary
		end
		log.error("uploaded model has no part, using the placeholder", { name = spec.name })
		model:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = spec.name
	local primary: BasePart? = nil
	for _, partSpec in spec.parts do
		local part = buildPart(partSpec, position)
		part.Parent = model
		if partSpec.name == spec.primary then
			primary = part
		end
	end
	if primary == nil then
		-- Cannot happen: a spec checks that every model has its primary part.
		log.error("model without primary part", { name = spec.name })
		primary = model:FindFirstChildWhichIsA("BasePart")
	end
	model.PrimaryPart = primary
	model.Parent = parent
	return model, primary :: BasePart
end

-- Adds a floating text label above a model: `lift` studs over its highest point.
function ModelFactory.addLabel(model: Model, primary: BasePart, text: string, lift: number?)
	local boxCFrame, boxSize = model:GetBoundingBox()
	local top = boxCFrame.Position.Y + boxSize.Y / 2
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(LABEL_WIDTH, LABEL_HEIGHT)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, top - primary.Position.Y + (lift or LABEL_LIFT), 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 64
	billboard.Parent = primary
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextStrokeTransparency = 0.5
	label.Text = text
	label.Parent = billboard
end

-- Builds a sign (post and board) at x, z of `box` relative to `center`, labels
-- its board and returns the board, where the prompt attaches.
function ModelFactory.sign(
	id: string,
	parent: Instance,
	center: Vector3,
	size: number,
	x: number,
	z: number,
	rgb: ModelSpecs.Rgb,
	text: string
): BasePart
	local spec = ModelSpecs.sign(palette, size, rgb, ModelSpecs.signKind(id))
	local model, board = ModelFactory.build(spec, center + Vector3.new(x, 0, z), parent)
	ModelFactory.addLabel(model, board, text, LABEL_LIFT)
	return board
end

return ModelFactory
