--!strict
-- Types/Match (architecture §6.3): one mission's shared state, owned by the Encounter domain. Never persisted.

export type MatchOutcome = "InProgress" | "Extracted" | "Wiped" | "Abandoned"

export type MatchState = {
	MatchId: string,
	MissionId: string,
	DifficultyId: string,
	Participants: { number },
	Connected: { [number]: boolean },
	Clock: number, -- SimulationClock seconds (pausable)
	Paused: boolean,
	PauseReason: string?,
	Protocol: number,
	ProtocolProgress: number,
	Wave: number,
	Elites: number,
	Extraction: { Open: boolean, ClosesAt: number?, Votes: { [number]: string }, WindowIndex: number },
	Boss: { Active: boolean, Phase: number }?,
	Outcome: MatchOutcome,
	RewardMultiplier: number,
}

-- Types only; nothing to run.
return table.freeze({})
