--!strict
-- Platform/RemoteConfigService: placeholder (A1.4) holding the §5.2 Init/Start contract. Tunables from DataStore/MemoryStore arrive in A1.8.

local Lifecycle = require(script.Parent.Parent.Parent.Lifecycle)

local RemoteConfigService: Lifecycle.Service = {
	Name = "RemoteConfigService",
	Init = function(_self: Lifecycle.Service) end,
	Start = function(_self: Lifecycle.Service) end,
}

return RemoteConfigService
