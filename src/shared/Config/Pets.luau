--!strict
-- Pets from the fossil egg. Starting values, to be tested. Pets are not
-- tradable and never change auction prices; they only give small bonuses to the
-- owner (dig speed, luck, offline yield).
-- rarityOrder: from most common to rarest. The egg chances use these ids.
-- egg.chances: percent per rarity, must sum to 100. Inside a rarity every pet
--   has the same chance. Every egg gives a pet.
-- egg.productId: the id from the Creator Dashboard. 0 means "not created yet":
--   the shop never prompts a purchase then.
-- pity: the afterEggs-th egg without a pet of minRarity or better is
--   guaranteed to be minRarity or better.
-- pets: rarity and effect (a Modifiers part, see src/shared/Modifiers).
-- order: the order of the pets in the panel.
-- slots: how many pets work at the same time (the second slot comes later as a
--   pass).
-- maxOwned: the collection limit; no egg can be opened when it is full.
-- freeEgg: the way to get eggs for players restricted from paid random items,
--   without Robux: one free egg per cooldown.
-- receiptHistory: how many purchase ids the profile remembers to catch
--   repeated receipts.

return {
	rarityOrder = { "common", "rare", "epic", "legendary", "mythic" },
	egg = {
		productId = 3717307004,
		robux = 99,
		chances = { common = 60, rare = 25, epic = 10, legendary = 4, mythic = 1 },
	},
	pity = { afterEggs = 10, minRarity = "rare" },
	slots = 1,
	maxOwned = 60,
	freeEgg = { cooldownSeconds = 24 * 60 * 60 },
	receiptHistory = 100,
	order = {
		"mole",
		"glowworm",
		"badger",
		"bat",
		"salamander",
		"owl",
		"lava_fox",
		"crystal_moth",
		"stone_dragon",
		"star_beetle",
	},
	pets = {
		mole = { rarity = "common", effect = { tempoBonus = 0.03 } },
		glowworm = { rarity = "common", effect = { luckBonus = 0.02 } },
		badger = { rarity = "rare", effect = { tempoBonus = 0.06 } },
		bat = { rarity = "rare", effect = { offlineBonus = 0.1 } },
		salamander = { rarity = "epic", effect = { luckBonus = 0.06 } },
		owl = { rarity = "epic", effect = { offlineBonus = 0.2 } },
		lava_fox = { rarity = "legendary", effect = { tempoBonus = 0.12 } },
		crystal_moth = { rarity = "legendary", effect = { luckBonus = 0.1 } },
		stone_dragon = { rarity = "mythic", effect = { tempoBonus = 0.2 } },
		star_beetle = { rarity = "mythic", effect = { luckBonus = 0.15, offlineBonus = 0.3 } },
	},
}
