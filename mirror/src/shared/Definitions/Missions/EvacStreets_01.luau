--!strict
-- Sample mission (A1.6): the architecture §9.2 example, with the enemy pool and elite schedule cut to the sample enemies.
return {
	Id = "EvacStreets_01",
	ZoneId = "EvacuationStreets",
	DurationCap = 480,
	SpawnBudget = { MaxAlive = 90, BaseRate = 1.2, RatePerProtocol = 0.5 },
	EnemyPool = { "Walker" },
	EliteSchedule = {},
	BossId = "MutantAlpha",
	BossAtProtocol = 5,
	ProtocolRate = { SecondsPerLevel = 55, ElitesPerLevel = 3 },
	ExtractionWindows = { { Protocol = 3, Seconds = 45 }, { Protocol = 5, Seconds = 40 }, { Protocol = 7, Seconds = 35 } },
	RewardTable = "Zone1_Normal",
}
