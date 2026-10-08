--!strict
-- Profile format migrations, in order. Entry n migrates a profile from version
-- n to version n + 1, so the current version is #migrations + 1.
--
-- Every change to the stored profile format needs a new entry here AND a test
-- in tests/specs/ProfileData.spec.luau (keep the frozen older fixtures migrating).
-- Version 1 is the first format.
--   1 -> 2: every rare find gets a unique id (needed for museum and trading);
--           nextFindId is the next free id.

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
}

return migrations
