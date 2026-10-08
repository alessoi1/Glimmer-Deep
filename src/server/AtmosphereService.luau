--!strict
-- Sets the light of the world: sun position, ambient colors, atmosphere and
-- soft post effects, all from Config/Look. Runs once at server start. The
-- values are only a look; they change nothing about how the game plays. Only
-- checkable in Roblox Studio.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local LookConfig = require(Shared:WaitForChild("Config"):WaitForChild("Look"))

local log = Log.new("Atmosphere")

local AtmosphereService = {}

local started = false

local function color(rgb: { r: number, g: number, b: number }): Color3
	return Color3.fromRGB(rgb.r, rgb.g, rgb.b)
end

-- Removes effects of the same class that an earlier start or a Studio template left.
local function clearOld(className: string)
	for _, child in Lighting:GetChildren() do
		if child:IsA(className) then
			child:Destroy()
		end
	end
end

function AtmosphereService.start()
	if started then
		log.warn("start called twice")
		return
	end
	started = true

	local look = LookConfig.lighting
	Lighting.ClockTime = look.clockTime
	Lighting.Brightness = look.brightness
	Lighting.Ambient = color(look.ambient)
	Lighting.OutdoorAmbient = color(look.outdoorAmbient)
	Lighting.ExposureCompensation = look.exposure
	Lighting.GlobalShadows = true

	clearOld("Atmosphere")
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = look.atmosphere.density
	atmosphere.Offset = look.atmosphere.offset
	atmosphere.Color = color(look.atmosphere.color)
	atmosphere.Decay = color(look.atmosphere.decay)
	atmosphere.Glare = look.atmosphere.glare
	atmosphere.Haze = look.atmosphere.haze
	atmosphere.Parent = Lighting

	clearOld("BloomEffect")
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = look.bloom.intensity
	bloom.Size = look.bloom.size
	bloom.Threshold = look.bloom.threshold
	bloom.Parent = Lighting

	clearOld("ColorCorrectionEffect")
	local correction = Instance.new("ColorCorrectionEffect")
	correction.Saturation = look.colorCorrection.saturation
	correction.Contrast = look.colorCorrection.contrast
	correction.Brightness = look.colorCorrection.brightness
	correction.Parent = Lighting

	clearOld("SunRaysEffect")
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = look.sunRays.intensity
	rays.Spread = look.sunRays.spread
	rays.Parent = Lighting

	log.info("started", { clockTime = look.clockTime })
end

return AtmosphereService
