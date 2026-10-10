--!strict
-- Packs a set of block indexes into a short text (6 bits per character) so a
-- slice of the cave fits into a profile. Pure; no Roblox services.

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local BITS_PER_CHAR = 6

local VALUE_OF: { [string]: number } = {}
for index = 1, #ALPHABET do
	VALUE_OF[string.sub(ALPHABET, index, index)] = index - 1
end

local CaveCodec = {}

-- Number of characters needed for `totalBits` bits.
function CaveCodec.charCount(totalBits: number): number
	return math.ceil(totalBits / BITS_PER_CHAR)
end

-- `bits` maps an index (0-based) to true. Indexes outside 0 to totalBits - 1 are ignored.
function CaveCodec.encode(bits: { [number]: boolean }, totalBits: number): string
	local chars = {}
	for charIndex = 0, CaveCodec.charCount(totalBits) - 1 do
		local value = 0
		for offset = 0, BITS_PER_CHAR - 1 do
			local index = charIndex * BITS_PER_CHAR + offset
			if index < totalBits and bits[index] == true then
				value += 2 ^ offset
			end
		end
		chars[charIndex + 1] = string.sub(ALPHABET, value + 1, value + 1)
	end
	return table.concat(chars)
end

-- Returns the set of indexes, or nil when the text has the wrong length, a
-- foreign character or set bits beyond `totalBits`.
function CaveCodec.decode(text: string, totalBits: number): { [number]: boolean }?
	if type(text) ~= "string" or #text ~= CaveCodec.charCount(totalBits) then
		return nil
	end
	local bits: { [number]: boolean } = {}
	for charIndex = 0, #text - 1 do
		local value = VALUE_OF[string.sub(text, charIndex + 1, charIndex + 1)]
		if value == nil then
			return nil
		end
		for offset = 0, BITS_PER_CHAR - 1 do
			if bit32.band(value, bit32.lshift(1, offset)) ~= 0 then
				local index = charIndex * BITS_PER_CHAR + offset
				if index >= totalBits then
					return nil
				end
				bits[index] = true
			end
		end
	end
	return bits
end

return CaveCodec
