--!strict
-- Data/MigrationService: placeholder (A1.4) holding the §5.2 Init/Start contract. Profile schema migrations arrive in A5.5.

local Lifecycle = require(script.Parent.Parent.Parent.Lifecycle)

local MigrationService: Lifecycle.Service = {
	Name = "MigrationService",
	Init = function(_self: Lifecycle.Service) end,
	Start = function(_self: Lifecycle.Service) end,
}

return MigrationService
