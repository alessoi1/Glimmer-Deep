--!strict
local Framework = require("../Framework")
local ShovelConfig = require("../../src/shared/Config/Shovel")
local SkillConfig = require("../../src/shared/Config/Skills")
local UpgradeEffects = require("../../src/shared/UpgradeEffects")
local Upgrades = require("../../src/shared/Upgrades")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals
local assertNear = Framework.assertNear

local tracks: UpgradeEffects.Tracks = {
	shovel = { levels = ShovelConfig.levels },
	strong_arms = SkillConfig.tracks.strong_arms,
	ore_finder = SkillConfig.tracks.ore_finder,
	cable_winch = SkillConfig.tracks.cable_winch,
	lamp = SkillConfig.tracks.lamp,
}

local function allLevelsOne(): { [string]: number }
	return { shovel = 1, strong_arms = 1, ore_finder = 1, cable_winch = 1, lamp = 1 }
end

test("the shipped skill tracks are valid upgrade tracks", function()
	for id, track in SkillConfig.tracks do
		local ok, reason = Upgrades.validateTracks({ [id] = track })
		assertTrue(ok, reason)
		assertTrue(#track.levels >= 2, id .. " needs at least two levels")
	end
end)

test("every skill raises exactly its own bonus, growing with the level", function()
	local fields =
		{ strong_arms = "tempoBonus", ore_finder = "rareFindBonus", cable_winch = "walkSpeedBonus", lamp = "luckBonus" }
	for id, field in fields do
		local previous = 0
		for index, level in SkillConfig.tracks[id].levels do
			local value = (level :: any)[field] or 0
			assertTrue(value >= previous, string.format("%s level %d does not grow", id, index))
			previous = value
		end
		assertTrue(previous > 0, id .. " never gives a bonus")
		assertEquals((SkillConfig.tracks[id].levels[1] :: any)[field], nil, id .. " level 1 must give nothing")
	end
end)

test("the shovel reach never shrinks and starts at zero", function()
	local previous = 0
	for _, level in ShovelConfig.levels do
		local reach = level.rangeBonus or 0
		assertTrue(reach >= previous)
		previous = reach
	end
	assertEquals(ShovelConfig.levels[1].rangeBonus or 0, 0)
	assertTrue(previous > 0)
end)

test("a new player has no bonuses from upgrades", function()
	local part = UpgradeEffects.part(allLevelsOne(), tracks)
	assertEquals(part.tempoBonus, 0)
	assertEquals(part.rareFindBonus, 0)
	assertEquals(part.walkSpeedBonus, 0)
	assertEquals(part.luckBonus, 0)
	assertEquals(part.rangeBonus, 0)
end)

test("the bonus of a level is the one of that level, not the sum of all", function()
	local levels = allLevelsOne()
	levels.strong_arms = 3
	local part = UpgradeEffects.part(levels, tracks)
	assertNear(part.tempoBonus :: number, SkillConfig.tracks.strong_arms.levels[3].tempoBonus :: number, 1e-9)
end)

test("the shovel level gives its reach", function()
	local levels = allLevelsOne()
	levels.shovel = #ShovelConfig.levels
	local part = UpgradeEffects.part(levels, tracks)
	assertEquals(part.rangeBonus, ShovelConfig.levels[#ShovelConfig.levels].rangeBonus)
end)

test("unknown ids and levels outside the range are ignored or clamped", function()
	local part = UpgradeEffects.part({ pet = 3, lamp = 99, strong_arms = 0 }, tracks)
	assertNear(
		part.luckBonus :: number,
		SkillConfig.tracks.lamp.levels[#SkillConfig.tracks.lamp.levels].luckBonus :: number,
		1e-9
	)
	assertEquals(part.tempoBonus, 0)
end)

test("the effect of a level is named for the upgrade panel", function()
	local effect = UpgradeEffects.effectOf(SkillConfig.tracks.lamp.levels[2])
	assertTrue(effect ~= nil)
	assertEquals((effect :: UpgradeEffects.Effect).kind, "luck")
	assertEquals(
		(effect :: UpgradeEffects.Effect).percent,
		math.floor((SkillConfig.tracks.lamp.levels[2].luckBonus :: number) * 100 + 0.5)
	)
	assertEquals(UpgradeEffects.effectOf(SkillConfig.tracks.lamp.levels[1]), nil)
	assertEquals(UpgradeEffects.effectOf(ShovelConfig.levels[2]), nil)
end)
