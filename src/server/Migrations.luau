--!strict
-- Profile format migrations, in order. Entry n migrates a profile from version
-- n to version n + 1, so the current version is #migrations + 1.
--
-- Every change to the stored profile format needs a new entry here AND a test
-- in tests/specs/ProfileData.spec.luau (keep the frozen older fixtures migrating).
-- Version 1 is the first format.
--   1 -> 2: every rare find gets a unique id (needed for museum and trading);
--           nextFindId is the next free id.
--   2 -> 3: onboarding progress and stats. Players who already played skip the
--           onboarding (step 7, first find counted as given).
--   3 -> 4: house (level 1) and museum (no showcases yet; the visitor income
--           counts from the profile creation, which pays nothing without finds).
--   4 -> 5: depot (offline yield), digger (absence time) and digger level 1.
--   5 -> 6: skill levels (strong_arms, ore_finder, cable_winch, lamp) at level 1.
--   6 -> 7: daily quests and login chain (not started).
--   7 -> 8: owned game passes (none).
--   8 -> 9: boosters (none running), remembered purchase ids and the free claim time.
--   9 -> 10: pets (no pets, no eggs, guarantee counter at 0).

local migrations: { (data: { [string]: any }) -> { [string]: any } } = {
	function(data)
		local nextId = 1
		local backpack = data.backpack
		if type(backpack) == "table" and type(backpack.finds) == "table" then
			for _, find in backpack.finds do
				if type(find) == "table" then
					find.id = nextId
					nextId += 1
				end
			end
		end
		data.nextFindId = nextId
		return data
	end,
	function(data)
		local played = (type(data.depth) == "number" and data.depth > 0)
			or (type(data.coins) == "number" and data.coins > 0)
		data.onboarding = if played then { step = 7, firstFindGiven = true } else { step = 1, firstFindGiven = false }
		data.stats = { blocksDug = 0 }
		return data
	end,
	function(data)
		data.house = { level = 1 }
		data.museum = {
			displays = {},
			incomeSince = if type(data.createdAt) == "number" then data.createdAt else 0,
			admires = 0,
			week = 0,
			weekAdmires = 0,
		}
		return data
	end,
	function(data)
		data.depot = { ores = {}, finds = {} }
		data.digger = {}
		if type(data.upgradeLevels) == "table" then
			data.upgradeLevels.digger = 1
		end
		return data
	end,
	function(data)
		if type(data.upgradeLevels) == "table" then
			for _, skillId in { "strong_arms", "ore_finder", "cable_winch", "lamp" } do
				data.upgradeLevels[skillId] = 1
			end
		end
		return data
	end,
	function(data)
		data.quests = { day = 0, ids = {}, progress = {}, claimed = {}, bonusClaimed = false }
		data.login = { lastDay = 0, streak = 0, claimed = true }
		return data
	end,
	function(data)
		data.passes = {}
		return data
	end,
	function(data)
		data.boosters = { expires = {}, receipts = {}, freeClaimedAt = 0 }
		return data
	end,
	function(data)
		data.pets = { owned = {}, nextId = 1, equipped = {}, eggs = 0, sinceRare = 0, freeEggAt = 0, receipts = {} }
		return data
	end,
}

return migrations
