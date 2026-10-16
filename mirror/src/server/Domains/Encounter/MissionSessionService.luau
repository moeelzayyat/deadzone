--!strict
-- Encounter/MissionSessionService: placeholder (A1.4) holding the §5.2 Init/Start contract. Run sessions arrive with the encounter substages.

local Lifecycle = require(script.Parent.Parent.Parent.Lifecycle)

local MissionSessionService: Lifecycle.Service = {
	Name = "MissionSessionService",
	Init = function(_self: Lifecycle.Service) end,
	Start = function(_self: Lifecycle.Service) end,
}

return MissionSessionService
