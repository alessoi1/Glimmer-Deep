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
--   10 -> 11: house decoration (nothing owned, nothing placed).
--   11 -> 12: prestige (no points, no rebirths, no bonus levels).
--   12 -> 13: season progress (no season yet, no points, nothing claimed).
--   13 -> 14: the cave. Players keep their depth as a pre-dug corridor (one row
--             per meter, frozen at this version); depth and layerSeeds stay until
--             the dig service works on the cave.
--   14 -> 15: equipment (nothing owned or worn) and the forge stash (empty).

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
	function(data)
		if type(data.house) == "table" then
			data.house.decor = { owned = {}, placed = {} }
		end
		return data
	end,
	function(data)
		data.prestige = { points = 0, rebirths = 0, levels = {} }
		return data
	end,
	function(data)
		data.season = { id = 0, xp = 0, claimedFree = {}, claimedPremium = {} }
		return data
	end,
	function(data)
		local depth = 0
		if type(data.depth) == "number" and data.depth > 0 and data.depth < math.huge then
			depth = data.depth
		end
		local rows = math.floor(depth)
		-- The seed comes from the first layer seed (by id), so it is the same on every migration.
		local seed = 1
		if type(data.layerSeeds) == "table" then
			local ids = {}
			for id in data.layerSeeds do
				table.insert(ids, id)
			end
			table.sort(ids)
			local first = if ids[1] ~= nil then data.layerSeeds[ids[1]] else nil
			if type(first) == "number" and first >= 1 then
				seed = first
			end
		end
		data.cave = { seed = seed, deepestRow = rows, preDugRow = rows, slices = {}, chests = {} }
		return data
	end,
	function(data)
		data.gear = { owned = {}, equipped = {}, nextId = 1 }
		data.stash = { ores = {} }
		return data
	end,
}

return migrations
