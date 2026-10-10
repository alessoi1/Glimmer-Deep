--!strict
-- Pure combat logic for the overworld: zones by strength, who may enter, hits,
-- life, spawn protection and the bounty with its abuse limits. No Roblox
-- services and no logging; the CombatService measures reach and positions,
-- decides who fights whom, applies the results and logs. All times are server
-- seconds.

export type ZoneDef = { id: string, minStrength: number, maxStrength: number, bounty: number }

export type Config = {
	zones: { ZoneDef },
	entryMargin: number,
	attackCooldown: number,
	reachStuds: number,
	respawnSeconds: number,
	spawnProtectionSeconds: number,
	bountyVictimLockSeconds: number,
	bountyDailyCap: number,
	bountyMinStrengthRatio: number,
	secondsPerDay: number,
	portalMinArmorPieces: number,
}

-- What the fighter state needs from the equipment (Equipment.Stats).
export type Stats = { life: number, damage: number, strength: number }

export type Fighter = {
	life: number,
	maxLife: number,
	alive: boolean,
	protectedUntil: number, -- spawn protection ends at this time
	lastAttackAt: number,
}

export type HitFailure = "self" | "dead_attacker" | "dead_victim" | "protected" | "cooldown" | "out_of_reach"
export type HitResult = { ok: boolean, reason: HitFailure?, dealt: number, defeated: boolean }

-- Bounty bookkeeping per killer (saved in memory only, it resets on rejoin).
export type Ledger = { day: number, earned: number, lastByVictim: { [number]: number } }

export type BountyFailure = "unknown_zone" | "victim_protected" | "victim_too_weak" | "victim_locked" | "daily_cap"
export type BountyResult = { ok: boolean, reason: BountyFailure?, coins: number }

export type PortalFailure = "onboarding" | "no_weapon" | "no_armor" | "too_strong"
export type PortalResult = { ok: boolean, reason: PortalFailure?, zones: { number } }

local Combat = {}

function Combat.newFighter(stats: Stats, now: number, config: Config): Fighter
	return {
		life = stats.life,
		maxLife = stats.life,
		alive = true,
		protectedUntil = now + config.spawnProtectionSeconds,
		lastAttackAt = -math.huge,
	}
end

function Combat.newLedger(): Ledger
	return { day = 0, earned = 0, lastByVictim = {} }
end

-- Damage of one hit: weapon damage times the strength potion, rounded up, at least 1.
function Combat.hitDamage(weaponDamage: number, potionMultiplier: number?): number
	local multiplier = potionMultiplier
	if multiplier == nil or multiplier ~= multiplier or multiplier < 1 then
		multiplier = 1
	end
	return math.max(1, math.ceil(weaponDamage * multiplier))
end

function Combat.inReach(distance: number, config: Config): boolean
	return distance == distance and distance >= 0 and distance <= config.reachStuds
end

-- Zones the strength may enter, as zone numbers (lowest first).
function Combat.zonesFor(strength: number, config: Config): { number }
	local zones = {}
	if strength ~= strength then
		return zones
	end
	for index, zone in config.zones do
		if strength >= zone.minStrength and strength <= zone.maxStrength * (1 + config.entryMargin) then
			table.insert(zones, index)
		end
	end
	return zones
end

-- The zone that fits best (the highest the strength is in the range of).
function Combat.bestZone(strength: number, config: Config): number?
	local zones = Combat.zonesFor(strength, config)
	return zones[#zones]
end

-- Portal rules: onboarding done, a weapon and armor worn, and not over the top zone.
function Combat.portal(
	onboardingDone: boolean,
	hasWeapon: boolean,
	armorPieces: number,
	strength: number,
	config: Config
): PortalResult
	if not onboardingDone then
		return { ok = false, reason = "onboarding", zones = {} }
	end
	if not hasWeapon then
		return { ok = false, reason = "no_weapon", zones = {} }
	end
	if armorPieces < config.portalMinArmorPieces then
		return { ok = false, reason = "no_armor", zones = {} }
	end
	local zones = Combat.zonesFor(strength, config)
	if #zones == 0 then
		return { ok = false, reason = "too_strong", zones = {} }
	end
	return { ok = true, reason = nil, zones = zones }
end

-- One hit. Changes the victim and the attacker's attack time only when it lands.
function Combat.hit(
	attacker: Fighter,
	victim: Fighter,
	damage: number,
	distance: number,
	now: number,
	config: Config
): HitResult
	local function fail(reason: HitFailure): HitResult
		return { ok = false, reason = reason, dealt = 0, defeated = false }
	end
	if attacker == victim then
		return fail("self")
	end
	if not attacker.alive then
		return fail("dead_attacker")
	end
	if not victim.alive then
		return fail("dead_victim")
	end
	if now < victim.protectedUntil then
		return fail("protected")
	end
	if now - attacker.lastAttackAt < config.attackCooldown then
		return fail("cooldown")
	end
	if not Combat.inReach(distance, config) then
		return fail("out_of_reach")
	end

	attacker.lastAttackAt = now
	-- Attacking ends the attacker's own spawn protection (no hiding behind it).
	attacker.protectedUntil = math.min(attacker.protectedUntil, now)
	local dealt = math.min(damage, victim.life)
	victim.life -= dealt
	local defeated = victim.life <= 0
	if defeated then
		victim.alive = false
	end
	return { ok = true, reason = nil, dealt = dealt, defeated = defeated }
end

-- Heals a share (0 to 1) of the maximum life; returns the life gained.
function Combat.heal(fighter: Fighter, share: number): number
	if not fighter.alive or share ~= share or share <= 0 then
		return 0
	end
	local gained = math.min(math.ceil(fighter.maxLife * math.min(share, 1)), fighter.maxLife - fighter.life)
	fighter.life += gained
	return gained
end

-- Back to life with full life and fresh spawn protection (after respawnSeconds).
function Combat.respawn(fighter: Fighter, stats: Stats, now: number, config: Config)
	fighter.maxLife = stats.life
	fighter.life = stats.life
	fighter.alive = true
	fighter.protectedUntil = now + config.spawnProtectionSeconds
end

-- Reward for defeating a player. Only on success the ledger changes. `victimId`
-- is the loser's UserId. Weaker-than-half, protected and recently defeated
-- players give nothing; the daily cap cuts the last reward to what is left.
function Combat.bounty(
	ledger: Ledger,
	config: Config,
	zoneIndex: number,
	killerStrength: number,
	victimStrength: number,
	victimProtected: boolean,
	victimId: number,
	now: number
): BountyResult
	local function fail(reason: BountyFailure): BountyResult
		return { ok = false, reason = reason, coins = 0 }
	end
	local zone = config.zones[zoneIndex]
	if zone == nil then
		return fail("unknown_zone")
	end
	if victimProtected then
		return fail("victim_protected")
	end
	if not (victimStrength >= killerStrength * config.bountyMinStrengthRatio) then
		return fail("victim_too_weak")
	end

	local day = math.floor(now / config.secondsPerDay)
	if ledger.day ~= day then
		ledger.day = day
		ledger.earned = 0
	end
	local last = ledger.lastByVictim[victimId]
	if last ~= nil and now - last < config.bountyVictimLockSeconds then
		return fail("victim_locked")
	end
	local coins = math.min(zone.bounty, config.bountyDailyCap - ledger.earned)
	if coins <= 0 then
		return fail("daily_cap")
	end

	ledger.earned += coins
	ledger.lastByVictim[victimId] = now
	return { ok = true, reason = nil, coins = coins }
end

-- Drops lock entries that are over (keeps the ledger small).
function Combat.prune(ledger: Ledger, config: Config, now: number)
	for victimId, last in ledger.lastByVictim do
		if now - last >= config.bountyVictimLockSeconds then
			ledger.lastByVictim[victimId] = nil
		end
	end
end

-- Returns true when the config is usable, otherwise false and a reason.
function Combat.validateConfig(config: Config): (boolean, string?)
	if #config.zones == 0 then
		return false, "no zones configured"
	end
	if config.zones[1].minStrength ~= 0 then
		return false, "first zone must start at strength 0"
	end
	for index, zone in config.zones do
		if zone.maxStrength <= zone.minStrength then
			return false, "zone " .. zone.id .. " has an empty strength range"
		end
		if zone.bounty < 0 then
			return false, "zone " .. zone.id .. " has a negative bounty"
		end
		local nextZone = config.zones[index + 1]
		if nextZone ~= nil and nextZone.minStrength ~= zone.maxStrength then
			return false, "zones " .. zone.id .. " and " .. nextZone.id .. " are not contiguous"
		end
	end
	if config.entryMargin < 0 or config.attackCooldown < 0 or config.reachStuds <= 0 then
		return false, "margin, cooldown and reach need sane values"
	end
	if config.bountyMinStrengthRatio < 0 or config.bountyMinStrengthRatio > 1 then
		return false, "bountyMinStrengthRatio must be between 0 and 1"
	end
	if config.bountyDailyCap < config.zones[1].bounty then
		return false, "daily cap is lower than one bounty"
	end
	return true, nil
end

return Combat
