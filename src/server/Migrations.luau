--!strict
-- Profile format migrations, in order. Entry n migrates a profile from version
-- n to version n + 1, so the current version is #migrations + 1.
--
-- Every change to the stored profile format needs a new entry here AND a test
-- in tests/specs/ProfileData.spec.luau (keep the frozen older fixtures migrating).
-- Version 1 is the first format, so there are no migrations yet.

local migrations: { (data: { [string]: any }) -> { [string]: any } } = {}

return migrations
