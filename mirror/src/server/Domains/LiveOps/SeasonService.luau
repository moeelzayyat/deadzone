--!strict
-- LiveOps/SeasonService: placeholder (A1.4) holding the §5.2 Init/Start contract. Seasons arrive with the live-ops substages.

local Lifecycle = require(script.Parent.Parent.Parent.Lifecycle)

local SeasonService: Lifecycle.Service = {
	Name = "SeasonService",
	Init = function(_self: Lifecycle.Service) end,
	Start = function(_self: Lifecycle.Service) end,
}

return SeasonService
