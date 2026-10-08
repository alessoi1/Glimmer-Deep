--!strict
local Framework = require("../Framework")
local PetMessages = require("../../src/shared/PetMessages")

local test = Framework.test
local assertEquals = Framework.assertEquals

local strings: PetMessages.Strings = {
	shop = { viewOffer = "Angebot ansehen", soon = "Bald verfügbar", price = "%s Robux" },
	rarity = { rare = "Selten", common = "Gewöhnlich" },
	pets = {
		pet = { mole = "Maulwurf" },
		effectTempo = "Tempo +%d %%",
		effectLuck = "Glück +%d %%",
		effectOffline = "Bagger +%d %%",
		chanceLine = "%s: %s %%",
		petChanceLine = "%s (%s): %s %%",
		pityLine = "Spätestens das %d. Ei ist mindestens %s.",
		pityProgress = "Höchstens noch %d Eier bis zur Garantie",
		pityNext = "Die Garantie gilt für das nächste Ei",
		freeIn = "Wieder möglich in %s",
		freeClaim = "Gratis-Ei abholen",
		hatched = "Neues Haustier: %s (%s)",
		hatchedGuaranteed = "Garantiert: %s (%s)",
		equipped = "Im Einsatz",
		unequipped = "Zurückgestellt",
		eggsCount = "Eier: %d",
		slotsLine = "Im Einsatz: %d/%d",
		collectionLine = "Sammlung: %d/%d",
		durationHours = "%d Std %d Min",
		durationMinutes = "%d Min",
		noEgg = "Du hast kein Ei",
		full = "Deine Sammlung ist voll",
		notAvailable = "Noch nicht verfügbar",
		cooldown = "Einen Moment bitte",
		unknown = "?",
	},
}

test("pets and rarities show their name, with the id as fallback", function()
	assertEquals(PetMessages.petName(strings, "mole"), "Maulwurf")
	assertEquals(PetMessages.petName(strings, "mystery"), "mystery")
	assertEquals(PetMessages.rarityName(strings, "rare"), "Selten")
	assertEquals(PetMessages.rarityName(strings, "ghost"), "ghost")
end)

test("the effect text lists each bonus in a fixed order", function()
	assertEquals(PetMessages.effectText(strings, { tempoBonus = 0.06 }), "Tempo +6 %")
	assertEquals(
		PetMessages.effectText(strings, { offlineBonus = 0.3, luckBonus = 0.15 }),
		"Glück +15 %, Bagger +30 %"
	)
	assertEquals(PetMessages.effectText(strings, {}), "")
end)

test("chance lines use a decimal comma", function()
	assertEquals(PetMessages.rarityChanceLine(strings, "rare", 25), "Selten: 25,0 %")
	assertEquals(PetMessages.petChanceLine(strings, "mole", "common", 30), "Maulwurf (Gewöhnlich): 30,0 %")
	assertEquals(PetMessages.percentText(0.5), "0,5")
end)

test("the guarantee texts name the egg count and the rarity", function()
	assertEquals(PetMessages.pityLine(strings, 10, "rare"), "Spätestens das 10. Ei ist mindestens selten.")
	assertEquals(PetMessages.pityProgress(strings, 4), "Höchstens noch 4 Eier bis zur Garantie")
	assertEquals(PetMessages.pityProgress(strings, 1), "Die Garantie gilt für das nächste Ei")
end)

test("action and free texts are neutral", function()
	assertEquals(PetMessages.actionText(strings, { buyable = true }), "Angebot ansehen")
	assertEquals(PetMessages.actionText(strings, { buyable = false }), "Bald verfügbar")
	assertEquals(PetMessages.freeText(strings, { canClaim = true, secondsUntil = 0 }), "Gratis-Ei abholen")
	assertEquals(
		PetMessages.freeText(strings, { canClaim = false, secondsUntil = 5400 }),
		"Wieder möglich in 1 Std 30 Min"
	)
	assertEquals(PetMessages.priceText(strings, 99), "99 Robux")
end)

test("counts and hatch messages", function()
	assertEquals(PetMessages.eggsText(strings, 3), "Eier: 3")
	assertEquals(PetMessages.slotsText(strings, 1, 1), "Im Einsatz: 1/1")
	assertEquals(PetMessages.collectionText(strings, 4, 60), "Sammlung: 4/60")
	assertEquals(PetMessages.hatchedText(strings, "mole", "common", false), "Neues Haustier: Maulwurf (Gewöhnlich)")
	assertEquals(PetMessages.hatchedText(strings, "mole", "common", true), "Garantiert: Maulwurf (Gewöhnlich)")
end)

test("results name the failure with a neutral fallback", function()
	assertEquals(PetMessages.describeResult(strings, true, nil), "")
	assertEquals(PetMessages.describeResult(strings, false, "no_egg"), "Du hast kein Ei")
	assertEquals(PetMessages.describeResult(strings, false, "full"), "Deine Sammlung ist voll")
	assertEquals(PetMessages.describeResult(strings, false, "not_available"), "Noch nicht verfügbar")
	assertEquals(PetMessages.describeResult(strings, false, "cooldown"), "Einen Moment bitte")
	assertEquals(PetMessages.describeResult(strings, false, "other"), "?")
end)
