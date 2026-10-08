--!strict
-- Pure shop logic for game passes: config checks, the effect of an owned pass
-- and the view the shop panel shows. No Roblox services; the ShopService asks
-- Roblox who owns what and keeps the result in the profile. Purchases happen
-- only through MarketplaceService, never here.

local Modifiers = require("./Modifiers")

export type PassDef = {
	gamePassId: number, -- 0 = not created in the Creator Dashboard yet
	robux: number, -- price shown in the shop
	effect: Modifiers.Part?,
	perk: string?, -- a feature the server code looks for by name
}

export type Config = {
	order: { string },
	passes: { [string]: PassDef },
}

export type PassView = {
	key: string,
	robux: number,
	owned: boolean,
	buyable: boolean, -- not owned, and the id from the dashboard is set
}

export type View = {
	available: boolean, -- false during the first minutes (no purchase offers yet)
	passes: { PassView },
}

local ShopLogic = {}

local function isPositiveInteger(value: any): boolean
	return type(value) == "number" and value >= 1 and value < math.huge and value % 1 == 0
end

-- Returns true when the config is usable, otherwise false and a reason.
function ShopLogic.validateConfig(config: Config): (boolean, string?)
	local inOrder: { [string]: boolean } = {}
	for _, key in config.order do
		if config.passes[key] == nil then
			return false, "order names the unknown pass " .. key
		end
		inOrder[key] = true
	end
	for key, def in config.passes do
		if not inOrder[key] then
			return false, key .. " is missing from the order"
		end
		if not isPositiveInteger(def.robux) then
			return false, key .. " needs a positive integer price"
		end
		if type(def.gamePassId) ~= "number" or def.gamePassId < 0 or def.gamePassId % 1 ~= 0 then
			return false, key .. " needs a non-negative integer gamePassId"
		end
		for field in def.effect or {} do
			if table.find(Modifiers.knownFields, field) == nil then
				return false, string.format("%s has the unknown effect %s", key, tostring(field))
			end
		end
	end
	return true, nil
end

-- The bonus part of a pass while it is owned. Passes with only a perk, unknown
-- keys and unowned passes give nothing.
function ShopLogic.effectOf(owned: { [string]: boolean }, key: string, config: Config): Modifiers.Part?
	local def = config.passes[key]
	if def == nil or owned[key] ~= true then
		return nil
	end
	return def.effect
end

-- True when the player owns a pass that carries the named perk.
function ShopLogic.hasPerk(owned: { [string]: boolean }, perk: string, config: Config): boolean
	for key, def in config.passes do
		if def.perk == perk and owned[key] == true then
			return true
		end
	end
	return false
end

-- Pass key for the id from the dashboard, or nil. Id 0 (not set) never matches.
function ShopLogic.keyOfGamePass(config: Config, gamePassId: number): string?
	if gamePassId <= 0 then
		return nil
	end
	for key, def in config.passes do
		if def.gamePassId == gamePassId then
			return key
		end
	end
	return nil
end

function ShopLogic.view(owned: { [string]: boolean }, config: Config, available: boolean): View
	local passes: { PassView } = {}
	for _, key in config.order do
		local def = config.passes[key]
		local isOwned = owned[key] == true
		table.insert(passes, {
			key = key,
			robux = def.robux,
			owned = isOwned,
			buyable = not isOwned and def.gamePassId > 0,
		})
	end
	return { available = available, passes = passes }
end

return ShopLogic
