--!strict
-- Telemetry/ErrorReportService: placeholder (A1.4) holding the §5.2 Init/Start contract. Structured error reporting arrives in A1.8.

local Lifecycle = require(script.Parent.Parent.Parent.Lifecycle)

local ErrorReportService: Lifecycle.Service = {
	Name = "ErrorReportService",
	Init = function(_self: Lifecycle.Service) end,
	Start = function(_self: Lifecycle.Service) end,
}

return ErrorReportService
