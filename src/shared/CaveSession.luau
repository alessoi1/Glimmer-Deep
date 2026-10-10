--!strict
-- Pure per-player cave session: the loaded cave, the cells that are currently
-- built in the world, reach checks, swings, chests and saving. The
-- CaveService only adds the Roblox side (parts, remotes, teleport) and the
-- logging. No Roblox services and no logging in here, so it runs under Lune.
-- Server-side only: the rolls and the profile changes must never run on the client.

local Backpack = require("./Backpack")
local Cave = require("./Cave")
local CaveAction = require("./CaveAction")
local CaveView = require("./CaveView")
local ChestLoot = require("./ChestLoot")
local DigRoll = require("./DigRoll")
local Shovel = require("./Shovel")

export type Settings = {
	blockSize: number,
	height: number,
	sliceRows: number,
	metersPerRow: number,
	entranceRows: number,
	corridorHalfWidth: number,
	corridorHeight: number,
	startRadius: number,
	maxRadius: number,
	radiusByLevel: { number },
	areaByLevel: { number },
	resourceDensity: number,
	herbShare: number,
	findSpotShare: number,
	regrowSeconds: number,
	chestChance: number,
	chestMinRow: number,
	chestRespawnSeconds: number,
	world: CaveView.World,
}

export type Session = {
	cave: Cave.State,
	saved: Cave.SavedCave, -- the profile's cave table; flush writes into it
	config: Cave.Config,
	world: CaveView.World,
	blockSize: number,
	slot: number,
	built: { [string]: boolean }, -- keys of the cells that exist in the world
	lastDigAt: number?,
}

export type SwingFailure = CaveAction.FailureReason | "out_of_reach"

export type SwingParams = {
	profile: CaveAction.DiggerProfile,
	position: CaveView.Vec, -- where the player stands
	hit: Cave.Position,
	axis: "row" | "x" | "y",
	digConfig: DigRoll.Config,
	shovelLevels: { Shovel.LevelDef },
	cooldownTolerance: number,
	backpackLevels: { Backpack.LevelDef },
	onboarding: CaveAction.OnboardingParams,
	modifiers: CaveAction.DigModifiers?,
	mutationBoost: DigRoll.MutationBoost?,
	now: number,
	time: number,
	rng: DigRoll.Rng,
}

export type SwingResult = {
	ok: boolean,
	reason: SwingFailure?,
	action: CaveAction.Result?,
}

export type ChestFailure = Cave.FailureReason | "out_of_reach"

export type ChestProfile = ChestLoot.Target & {
	upgradeLevels: { [string]: number },
}

export type ChestParams = {
	profile: ChestProfile,
	position: CaveView.Vec,
	hit: Cave.Position,
	digConfig: DigRoll.Config,
	lootConfig: ChestLoot.Config,
	lootDeps: ChestLoot.Deps,
	luck: number?,
	mutationBoost: DigRoll.MutationBoost?,
	time: number,
	rng: DigRoll.Rng,
}

export type ChestResult = {
	ok: boolean,
	reason: ChestFailure?,
	entries: { ChestLoot.Entry },
	summary: ChestLoot.Summary?,
	biomeIndex: number,
}

export type Refresh = { diff: CaveView.Diff, count: number, row: number, overBudget: boolean }

local SHOVEL_UPGRADE = "shovel"

local CaveSession = {}

-- The Cave.Config for the shipped settings and the biomes (the layers).
function CaveSession.assemble(settings: Settings, biomes: { Cave.Biome }): Cave.Config
	return {
		height = settings.height,
		sliceRows = settings.sliceRows,
		metersPerRow = settings.metersPerRow,
		entranceRows = settings.entranceRows,
		corridorHalfWidth = settings.corridorHalfWidth,
		corridorHeight = settings.corridorHeight,
		startRadius = settings.startRadius,
		maxRadius = settings.maxRadius,
		radiusByLevel = settings.radiusByLevel,
		areaByLevel = settings.areaByLevel,
		resourceDensity = settings.resourceDensity,
		herbShare = settings.herbShare,
		findSpotShare = settings.findSpotShare,
		regrowSeconds = settings.regrowSeconds,
		chestChance = settings.chestChance,
		chestMinRow = settings.chestMinRow,
		chestRespawnSeconds = settings.chestRespawnSeconds,
		biomes = biomes,
	}
end

-- Loads the player's cave. Returns nil and a reason when the saved data is
-- unusable (the service then keeps the player out of the cave and logs it).
function CaveSession.new(
	saved: Cave.SavedCave,
	config: Cave.Config,
	world: CaveView.World,
	blockSize: number,
	slot: number
): (Session?, string?)
	if type(slot) ~= "number" or slot < 0 or slot % 1 ~= 0 then
		return nil, "slot must be a non-negative integer"
	end
	local cave, reason = Cave.deserialize(saved, config)
	if cave == nil then
		return nil, reason
	end
	return {
		cave = cave,
		saved = saved,
		config = config,
		world = world,
		blockSize = blockSize,
		slot = slot,
		built = {},
		lastDigAt = nil,
	},
		nil
end

-- Where a player is put when entering: above the floor of the hall.
function CaveSession.entryPoint(session: Session): CaveView.Vec
	return CaveView.cellCenter(session.world, session.blockSize, session.slot, 1, 0, 1)
end

-- Cells to build or take down for a player standing at `position`; the session's
-- list of built cells is updated as if the service applied the diff. `overBudget`
-- tells the service that the window is bigger than the part budget (it logs).
function CaveSession.refresh(session: Session, position: CaveView.Vec, time: number): Refresh
	local row = CaveView.rowAt(session.world, session.blockSize, session.slot, position)
	row = math.max(row, 0)
	local fromRow, toRow = CaveView.windowRows(session.world, row)
	local wanted = CaveView.visibleCells(session.cave, session.config, fromRow, toRow, time)
	for _, cap in CaveView.capCells(session.config, fromRow, toRow) do
		table.insert(wanted, cap)
	end
	local diff = CaveView.diff(session.built, wanted)
	for _, key in diff.remove do
		session.built[key] = nil
	end
	for _, cell in diff.add do
		session.built[CaveView.cellKey(cell)] = true
	end
	return { diff = diff, count = #wanted, row = row, overBudget = #wanted > session.world.maxParts }
end

-- Forgets everything built (the service removed all parts).
function CaveSession.clearBuilt(session: Session)
	session.built = {}
end

local function inReach(session: Session, position: CaveView.Vec, hit: Cave.Position): boolean
	return CaveView.inReach(session.world, session.blockSize, session.slot, position, hit.row, hit.x, hit.y)
end

local function isWhole(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge and value % 1 == 0
end

local function validHit(hit: any): boolean
	return type(hit) == "table" and isWhole(hit.row) and isWhole(hit.x) and isWhole(hit.y)
end

-- One swing. Checks the reach, then runs CaveAction and writes changed slices
-- into the saved cave. On failure the profile and the cave are unchanged.
function CaveSession.swing(session: Session, params: SwingParams): SwingResult
	if not validHit(params.hit) then
		return { ok = false, reason = "invalid_hit", action = nil }
	end
	if not inReach(session, params.position, params.hit) then
		return { ok = false, reason = "out_of_reach", action = nil }
	end
	local action = CaveAction.perform({
		profile = params.profile,
		cave = session.cave,
		caveConfig = session.config,
		digConfig = params.digConfig,
		shovelLevels = params.shovelLevels,
		cooldownTolerance = params.cooldownTolerance,
		backpackLevels = params.backpackLevels,
		onboarding = params.onboarding,
		modifiers = params.modifiers,
		mutationBoost = params.mutationBoost,
		hit = params.hit,
		axis = params.axis,
		lastDigAt = session.lastDigAt,
		now = params.now,
		time = params.time,
		rng = params.rng,
	})
	if not action.ok then
		return { ok = false, reason = action.reason, action = action }
	end
	session.lastDigAt = params.now
	Cave.flush(session.cave, session.config, session.saved)
	return { ok = true, reason = nil, action = action }
end

-- Opens the chest at the hit cell and puts the loot into the profile. Chests
-- are never for sale; the loot is rolled here on the server.
function CaveSession.openChest(session: Session, params: ChestParams): ChestResult
	local function fail(reason: ChestFailure): ChestResult
		return { ok = false, reason = reason, entries = {}, summary = nil, biomeIndex = 0 }
	end
	if not validHit(params.hit) then
		return fail("out_of_bounds")
	end
	if not inReach(session, params.position, params.hit) then
		return fail("out_of_reach")
	end
	local level = params.profile.upgradeLevels[SHOVEL_UPGRADE]
	local opened =
		Cave.openChest(session.cave, session.config, level, params.hit.row, params.hit.x, params.hit.y, params.time)
	if not opened.ok then
		return fail(opened.reason or "not_a_chest")
	end

	local depth = params.hit.row * session.config.metersPerRow
	local biome = Cave.biomeAt(session.config, depth)
	local biomeIndex = 1
	for index, candidate in session.config.biomes do
		if candidate.id == biome.id then
			biomeIndex = index
			break
		end
	end
	local entries = ChestLoot.roll(params.lootConfig, params.lootDeps, biomeIndex, biome.herbs, params.rng)
	local summary = ChestLoot.apply(params.profile, entries, params.lootDeps, function()
		local block = DigRoll.rollBlock(params.digConfig, params.rng, {
			depth = depth,
			luck = params.luck,
			guaranteedRare = true,
			mutationBoost = params.mutationBoost,
		})
		return block
	end)
	Cave.flush(session.cave, session.config, session.saved)
	return { ok = true, reason = nil, entries = entries, summary = summary, biomeIndex = biomeIndex }
end

-- Writes everything unsaved into the profile's cave (before it is saved).
function CaveSession.save(session: Session): number
	return Cave.flush(session.cave, session.config, session.saved)
end

return CaveSession
