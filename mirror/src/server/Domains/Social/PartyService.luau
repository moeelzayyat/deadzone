--!strict
-- Social/PartyService: placeholder (A1.4) holding the §5.2 Init/Start contract. Parties arrive in A5.1.

local Lifecycle = require(script.Parent.Parent.Parent.Lifecycle)

local PartyService: Lifecycle.Service = {
	Name = "PartyService",
	Init = function(_self: Lifecycle.Service) end,
	Start = function(_self: Lifecycle.Service) end,
}

return PartyService
