--!strict
-- Combat/CombatService: placeholder (A1.4) holding the §5.2 Init/Start contract. Damage resolution arrives with the combat substages (A2).

local Lifecycle = require(script.Parent.Parent.Parent.Lifecycle)

local CombatService: Lifecycle.Service = {
	Name = "CombatService",
	Init = function(_self: Lifecycle.Service) end,
	Start = function(_self: Lifecycle.Service) end,
}

return CombatService
