--!strict
local Combat = require("../../src/shared/Combat")
local CombatConfig = require("../../src/shared/Config/Combat")
local Equipment = require("../../src/shared/Equipment")
local EquipmentConfig = require("../../src/shared/Config/Equipment")
local Framework = require("../Framework")

local test = Framework.test
local assertTrue = Framework.assertTrue
local assertEquals = Framework.assertEquals

local config: Combat.Config = CombatConfig
local NOW = 100000

local function stats(life: number, damage: number): Combat.Stats
	return { life = life, damage = damage, strength = life * damage }
end

local function fighter(life: number): Combat.Fighter
	-- Protection already over at NOW.
	local f = Combat.newFighter(stats(life, 10), NOW - 100, config)
	return f
end

test("shipped combat config is valid", function()
	local ok, reason = Combat.validateConfig(config)
	assertTrue(ok, reason)
end)

test("config validation rejects gaps and bad ratios", function()
	local gap: any = table.clone(config)
	gap.zones = {
		{ id = "a", minStrength = 0, maxStrength = 10, bounty = 1 },
		{ id = "b", minStrength = 20, maxStrength = 30, bounty = 1 },
	}
	local ok = Combat.validateConfig(gap)
	assertTrue(not ok)
	local ratio: any = table.clone(config)
	ratio.bountyMinStrengthRatio = 1.5
	assertTrue(not Combat.validateConfig(ratio))
	local start: any = table.clone(config)
	start.zones = { { id = "a", minStrength = 5, maxStrength = 10, bounty = 1 } }
	assertTrue(not Combat.validateConfig(start))
end)

test("the tiers of the equipment land in the intended zones", function()
	local function fullSet(tier: number): number
		local t = EquipmentConfig.tiers[tier]
		local life = EquipmentConfig.baseLife + t.life
		return Equipment.strengthOf(life, t.damage)
	end
	assertEquals(Combat.bestZone(Equipment.strengthOf(EquipmentConfig.baseLife, EquipmentConfig.baseDamage), config), 1)
	assertEquals(Combat.bestZone(fullSet(1), config), 1)
	assertEquals(Combat.bestZone(fullSet(2), config), 1)
	assertEquals(Combat.bestZone(fullSet(3), config), 2)
	assertEquals(Combat.bestZone(fullSet(4), config), 2)
	assertEquals(Combat.bestZone(fullSet(5), config), 3)
end)

test("a player just over a zone limit may still enter it, but not far over", function()
	local limit = config.zones[1].maxStrength
	local justOver = limit * (1 + config.entryMargin) - 1
	assertEquals(Combat.zonesFor(justOver, config)[1], 1)
	assertEquals(Combat.zonesFor(limit * (1 + config.entryMargin) + 1, config)[1], 2)
	assertEquals(#Combat.zonesFor(0 / 0, config), 0)
end)

test("hit damage rounds up, uses the potion and ignores bad multipliers", function()
	assertEquals(Combat.hitDamage(14, nil), 14)
	assertEquals(Combat.hitDamage(14, 1.25), 18)
	assertEquals(Combat.hitDamage(14, 0 / 0), 14)
	assertEquals(Combat.hitDamage(14, 0.1), 14)
	assertEquals(Combat.hitDamage(0, 1), 1)
end)

test("a hit takes life, sets the cooldown and can defeat", function()
	local a = fighter(100)
	local v = fighter(30)
	local first = Combat.hit(a, v, 20, 3, NOW, config)
	assertTrue(first.ok)
	assertEquals(first.dealt, 20)
	assertEquals(v.life, 10)
	assertTrue(not first.defeated)
	local tooSoon = Combat.hit(a, v, 20, 3, NOW + 0.1, config)
	assertEquals(tooSoon.reason, "cooldown")
	assertEquals(v.life, 10)
	local second = Combat.hit(a, v, 20, 3, NOW + 1, config)
	assertTrue(second.defeated)
	assertEquals(second.dealt, 10)
	assertEquals(v.life, 0)
	assertTrue(not v.alive)
	assertEquals(Combat.hit(a, v, 20, 3, NOW + 2, config).reason, "dead_victim")
end)

test("hits are refused for self, a dead attacker, spawn protection and reach", function()
	local a = fighter(100)
	local v = fighter(100)
	assertEquals(Combat.hit(a, a, 5, 1, NOW, config).reason, "self")
	assertEquals(Combat.hit(a, v, 5, config.reachStuds + 0.5, NOW, config).reason, "out_of_reach")
	assertEquals(Combat.hit(a, v, 5, 0 / 0, NOW, config).reason, "out_of_reach")
	assertEquals(Combat.hit(a, v, 5, -1, NOW, config).reason, "out_of_reach")
	v.protectedUntil = NOW + 3
	assertEquals(Combat.hit(a, v, 5, 1, NOW, config).reason, "protected")
	assertEquals(v.life, 100)
	a.alive = false
	assertEquals(Combat.hit(a, v, 5, 1, NOW + 10, config).reason, "dead_attacker")
end)

test("attacking ends the attacker's own spawn protection", function()
	local a = Combat.newFighter(stats(100, 10), NOW, config)
	local v = fighter(100)
	assertTrue(a.protectedUntil > NOW)
	assertTrue(Combat.hit(a, v, 5, 1, NOW, config).ok)
	assertTrue(a.protectedUntil <= NOW)
	-- The victim can hit back at once.
	assertTrue(Combat.hit(v, a, 5, 1, NOW, config).ok)
end)

test("healing is limited to the missing life and by share", function()
	local f = fighter(100)
	f.life = 50
	assertEquals(Combat.heal(f, 0.4), 40)
	assertEquals(f.life, 90)
	assertEquals(Combat.heal(f, 0.4), 10)
	assertEquals(f.life, 100)
	assertEquals(Combat.heal(f, 0.4), 0)
	f.alive = false
	f.life = 0
	assertEquals(Combat.heal(f, 1), 0)
end)

test("respawn gives full life and fresh protection", function()
	local f = fighter(100)
	f.life = 0
	f.alive = false
	Combat.respawn(f, stats(120, 10), NOW, config)
	assertTrue(f.alive)
	assertEquals(f.life, 120)
	assertEquals(f.protectedUntil, NOW + config.spawnProtectionSeconds)
end)

test("the portal needs onboarding, a weapon, armor and a fitting strength", function()
	assertEquals(Combat.portal(false, true, 4, 2000, config).reason, "onboarding")
	assertEquals(Combat.portal(true, false, 4, 2000, config).reason, "no_weapon")
	assertEquals(Combat.portal(true, true, 0, 2000, config).reason, "no_armor")
	local ok = Combat.portal(true, true, 1, 2000, config)
	assertTrue(ok.ok)
	assertEquals(ok.zones[1], 1)
	assertEquals(Combat.portal(true, true, 1, 0 / 0, config).reason, "too_strong")
end)

test("a bounty pays the zone amount and locks the same victim", function()
	local ledger = Combat.newLedger()
	local first = Combat.bounty(ledger, config, 1, 2000, 2000, false, 7, NOW)
	assertTrue(first.ok)
	assertEquals(first.coins, config.zones[1].bounty)
	local again = Combat.bounty(ledger, config, 1, 2000, 2000, false, 7, NOW + 60)
	assertEquals(again.reason, "victim_locked")
	assertEquals(again.coins, 0)
	local other = Combat.bounty(ledger, config, 1, 2000, 2000, false, 8, NOW + 60)
	assertTrue(other.ok)
	local later = Combat.bounty(ledger, config, 1, 2000, 2000, false, 7, NOW + config.bountyVictimLockSeconds)
	assertTrue(later.ok)
end)

test("no bounty for a protected or much weaker victim, and a failure changes nothing", function()
	local ledger = Combat.newLedger()
	assertEquals(Combat.bounty(ledger, config, 1, 2000, 2000, true, 7, NOW).reason, "victim_protected")
	assertEquals(Combat.bounty(ledger, config, 1, 2000, 999, false, 7, NOW).reason, "victim_too_weak")
	assertEquals(Combat.bounty(ledger, config, 1, 2000, 1000, false, 7, NOW).ok, true)
	assertEquals(Combat.bounty(ledger, config, 9, 2000, 2000, false, 8, NOW).reason, "unknown_zone")
	assertEquals(Combat.bounty(ledger, config, 1, 2000, 0 / 0, false, 9, NOW).reason, "victim_too_weak")
	assertEquals(ledger.lastByVictim[7], NOW)
	assertEquals(ledger.lastByVictim[8], nil)
	assertEquals(ledger.lastByVictim[9], nil)
	assertEquals(ledger.earned, config.zones[1].bounty)
end)

test("the daily cap cuts the last reward and resets on the next day", function()
	local ledger = Combat.newLedger()
	local total = 0
	local victim = 100
	while true do
		victim += 1
		local result = Combat.bounty(ledger, config, 3, 20000, 20000, false, victim, NOW)
		if not result.ok then
			assertEquals(result.reason, "daily_cap")
			break
		end
		total += result.coins
		assertTrue(victim < 200, "cap never reached")
	end
	assertEquals(total, config.bountyDailyCap)
	local nextDay = Combat.bounty(ledger, config, 3, 20000, 20000, false, 5, NOW + config.secondsPerDay)
	assertTrue(nextDay.ok)
	assertEquals(nextDay.coins, config.zones[3].bounty)
end)

test("prune drops finished locks only", function()
	local ledger = Combat.newLedger()
	Combat.bounty(ledger, config, 1, 2000, 2000, false, 1, NOW)
	Combat.bounty(ledger, config, 1, 2000, 2000, false, 2, NOW + 500)
	Combat.prune(ledger, config, NOW + config.bountyVictimLockSeconds)
	assertEquals(ledger.lastByVictim[1], nil)
	assertEquals(ledger.lastByVictim[2], NOW + 500)
end)
