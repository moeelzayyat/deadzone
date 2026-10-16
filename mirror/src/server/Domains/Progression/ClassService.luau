--!strict
-- Progression/ClassService: placeholder (A1.4) holding the §5.2 Init/Start contract. Classes arrive with the progression substages.

local Lifecycle = require(script.Parent.Parent.Parent.Lifecycle)

local ClassService: Lifecycle.Service = {
	Name = "ClassService",
	Init = function(_self: Lifecycle.Service) end,
	Start = function(_self: Lifecycle.Service) end,
}

return ClassService
