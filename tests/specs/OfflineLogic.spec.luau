--!strict
local DiggerConfig = require("../../src/shared/Config/Digger")
local Framework = require("../Framework")
local OfflineLogic = require("../../src/shared/OfflineLogic")
local TestConfig = require("../TestConfig")
local Upgrades = require("../../src/shared/Upgrades")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals

local NOW = 1700000000
local HOUR = 3600

local function stash(): OfflineLogic.Stash
	return { ores = {}, finds = {} }
end

local function used(depot: OfflineLogic.Stash): number
	local total = #depot.finds
	for _, count in depot.ores do
		total += count
	end
	return total
end

local function params(changes: { [string]: any }?): OfflineLogic.Params
	local base: { [string]: any } = {
		leftAt = NOW - HOUR,
		now = NOW,
		digConfig = TestConfig,
		rng = Framework.seededRng(11),
		depth = 0,
		levels = DiggerConfig.levels,
		level = 1,
		config = DiggerConfig,
		extraHours = 0,
		yieldMultiplier = 1,
		luck = 1,
		depot = stash(),
		nextFindId = 1,
	}
	for key, value in changes or {} do
		base[key] = value
	end
	return base :: any
end

test("the shipped digger levels are valid upgrade levels", function()
	local ok, reason = Upgrades.validateTracks({ digger = { levels = DiggerConfig.levels } })
	assertTrue(ok, reason)
	local previous = 0
	for _, level in DiggerConfig.levels do
		assertTrue(level.blocksPerHour > previous)
		previous = level.blocksPerHour
	end
end)

test("no recorded absence gives nothing", function()
	local p = params()
	p.leftAt = nil
	local result = OfflineLogic.run(p)
	assertEquals(result.report, nil)
	assertEquals(used(p.depot), 0)
	assertEquals(result.nextFindId, 1)
end)

test("a very short absence gives nothing", function()
	local p = params({ leftAt = NOW - (DiggerConfig.minSeconds - 1) })
	assertEquals(OfflineLogic.run(p).report, nil)
	assertEquals(used(p.depot), 0)
end)

test("a clock that went backwards gives nothing", function()
	local p = params({ leftAt = NOW + 500 })
	assertEquals(OfflineLogic.run(p).report, nil)
end)

test("one hour at level 1 digs the configured blocks into the depot", function()
	local p = params()
	local result = OfflineLogic.run(p)
	local report = result.report :: OfflineLogic.Report
	assertEquals(report.blocks, DiggerConfig.levels[1].blocksPerHour)
	assertEquals(used(p.depot), DiggerConfig.levels[1].blocksPerHour)
	assertEquals(report.seconds, HOUR)
	assertEquals(report.hours, 1)
	assertEquals(report.capped, false)
	assertEquals(report.lost, 0)
end)

test("the report lists what was added to the depot", function()
	local p = params()
	local report = (OfflineLogic.run(p)).report :: OfflineLogic.Report
	local oreTotal = 0
	for oreId, count in report.ores do
		assertEquals(p.depot.ores[oreId], count)
		oreTotal += count
	end
	assertEquals(oreTotal + #report.finds, report.blocks)
	assertEquals(#report.finds, #p.depot.finds)
end)

test("a long absence is limited to the maximum hours", function()
	local p = params({ leftAt = NOW - 100 * HOUR })
	local report = (OfflineLogic.run(p)).report :: OfflineLogic.Report
	assertEquals(report.capped, true)
	assertEquals(report.hours, DiggerConfig.maxHours)
	assertEquals(report.blocks, DiggerConfig.levels[1].blocksPerHour * DiggerConfig.maxHours)
	assertEquals(report.seconds, 100 * HOUR)
end)

test("extra hours (pass) raise the limit", function()
	local p = params({ leftAt = NOW - 100 * HOUR, extraHours = 4 })
	local report = (OfflineLogic.run(p)).report :: OfflineLogic.Report
	assertEquals(report.hours, DiggerConfig.maxHours + 4)
	assertEquals(report.blocks, DiggerConfig.levels[1].blocksPerHour * (DiggerConfig.maxHours + 4))
end)

test("a higher digger level and a yield multiplier dig more", function()
	local level2 = (OfflineLogic.run(params({ level = 2 }))).report :: OfflineLogic.Report
	assertEquals(level2.blocks, DiggerConfig.levels[2].blocksPerHour)
	local boosted = (OfflineLogic.run(params({ yieldMultiplier = 1.5 }))).report :: OfflineLogic.Report
	assertEquals(boosted.blocks, math.floor(DiggerConfig.levels[1].blocksPerHour * 1.5))
end)

test("the block limit per return is respected", function()
	local config = table.clone(DiggerConfig)
	config.maxBlocks = 10
	local report = (OfflineLogic.run(params({ config = config }))).report :: OfflineLogic.Report
	assertEquals(report.blocks, 10)
end)

test("the depot capacity limits the items and counts the lost blocks", function()
	local config = table.clone(DiggerConfig)
	config.depotCapacity = 20
	local p = params({ config = config })
	local report = (OfflineLogic.run(p)).report :: OfflineLogic.Report
	assertEquals(used(p.depot), 20)
	assertEquals(report.blocks, 20)
	assertEquals(report.lost, DiggerConfig.levels[1].blocksPerHour - 20)
end)

test("an already full depot takes nothing", function()
	local config = table.clone(DiggerConfig)
	config.depotCapacity = 5
	local p = params({ config = config })
	p.depot.ores.coal = 5
	local report = (OfflineLogic.run(p)).report :: OfflineLogic.Report
	assertEquals(report.blocks, 0)
	assertEquals(p.depot.ores.coal, 5)
end)

test("offline rare finds are rarer than active ones and get consecutive ids", function()
	local levels = { { price = 0, blocksPerHour = 4000 } }
	local config = table.clone(DiggerConfig)
	config.depotCapacity = 100000
	config.maxBlocks = 100000
	local p = params({ levels = levels, config = config, nextFindId = 10, rng = Framework.seededRng(5) })
	local result = OfflineLogic.run(p)
	local report = result.report :: OfflineLogic.Report
	local chance = #report.finds / report.blocks * 100
	assertTrue(chance > 0.6 and chance < 1.5, "offline rare chance was " .. chance)
	assertEquals(result.nextFindId, 10 + #report.finds)
	for index, find in p.depot.finds do
		assertEquals(find.id, 9 + index)
	end
end)

test("the blocks come from the layer at the current depth", function()
	local p = params({ depth = 60 })
	local report = (OfflineLogic.run(p)).report :: OfflineLogic.Report
	for oreId in report.ores do
		assertTrue(oreId == "iron" or oreId == "silver", "unexpected ore " .. oreId)
	end
end)

test("the same inputs give the same result", function()
	local a = (OfflineLogic.run(params({ rng = Framework.seededRng(3) }))).report :: OfflineLogic.Report
	local b = (OfflineLogic.run(params({ rng = Framework.seededRng(3) }))).report :: OfflineLogic.Report
	assertEquals(a.blocks, b.blocks)
	assertEquals(#a.finds, #b.finds)
	assertTrue(Framework.deepEqual(a.ores, b.ores))
end)
