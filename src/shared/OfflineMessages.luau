--!strict
-- Pure text building for the "Während du weg warst" window: turns the offline
-- report into German lines using Strings. No Roblox services; the client shows
-- what this returns.

local MuseumMessages = require("./MuseumMessages")

export type Strings = {
	ore: { [string]: string },
	find: { [string]: string },
	rarity: { [string]: string },
	mutation: { [string]: string },
	layer: { [string]: string },
	offline: {
		title: string,
		away: string,
		blocks: string,
		oreLine: string,
		findsLabel: string,
		capped: string,
		lost: string,
		nothing: string,
		durationHours: string,
		durationMinutes: string,
	},
	museum: MuseumMessages.Texts,
}

-- Structural subset of OfflineLogic.Report.
export type Report = {
	seconds: number,
	hours: number,
	capped: boolean,
	blocks: number,
	lost: number,
	ores: { [string]: number },
	finds: { MuseumMessages.Find },
}

local SECONDS_PER_MINUTE = 60
local MINUTES_PER_HOUR = 60

local OfflineMessages = {}

-- "2 Std 15 Min", or "15 Min" below one hour.
function OfflineMessages.formatDuration(strings: Strings, seconds: number): string
	local totalMinutes = math.floor(seconds / SECONDS_PER_MINUTE)
	local hours = totalMinutes // MINUTES_PER_HOUR
	local minutes = totalMinutes % MINUTES_PER_HOUR
	if hours > 0 then
		return string.format(strings.offline.durationHours, hours, minutes)
	end
	return string.format(strings.offline.durationMinutes, minutes)
end

-- The lines of the window, top to bottom. `maxSeconds` is the longest absence
-- that counts (shown when the absence was capped).
function OfflineMessages.describeReport(strings: Strings, report: Report, maxSeconds: number): { string }
	local texts = strings.offline
	local lines: { string } = {}
	table.insert(lines, string.format(texts.away, OfflineMessages.formatDuration(strings, report.seconds)))
	if report.blocks > 0 then
		table.insert(lines, string.format(texts.blocks, report.blocks))
	end

	local oreIds: { string } = {}
	for oreId in report.ores do
		table.insert(oreIds, oreId)
	end
	table.sort(oreIds)
	for _, oreId in oreIds do
		local name = strings.ore[oreId] or oreId
		table.insert(lines, string.format(texts.oreLine, report.ores[oreId], name))
	end

	if #report.finds > 0 then
		table.insert(lines, texts.findsLabel)
		for _, find in report.finds do
			table.insert(lines, MuseumMessages.describeFind(strings, find))
		end
	end

	if report.capped then
		table.insert(lines, string.format(texts.capped, OfflineMessages.formatDuration(strings, maxSeconds)))
	end
	if report.lost > 0 then
		table.insert(lines, string.format(texts.lost, report.lost))
	end
	if report.blocks == 0 and #oreIds == 0 and #report.finds == 0 then
		table.insert(lines, texts.nothing)
	end
	return lines
end

return OfflineMessages
