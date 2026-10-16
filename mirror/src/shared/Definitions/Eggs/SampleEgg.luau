--!strict
-- Sample egg (A1.6). Placeholder: price, odds and pity are content for B3.1. Gameplay currency only (§13).
return {
	Id = "SampleEgg",
	DisplayName = "Sample Egg",
	Price = { Currency = "Gold", Amount = 500 },
	Odds = { { PetId = "MedicalDrone", Weight = 1 } },
	PityAfter = 50,
}
