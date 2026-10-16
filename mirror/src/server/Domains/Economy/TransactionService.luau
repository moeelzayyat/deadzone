--!strict
-- Economy/TransactionService: placeholder (A1.4) holding the §5.2 Init/Start contract. Idempotent commits (TransactionService:Run) arrive in B1.1.

local Lifecycle = require(script.Parent.Parent.Parent.Lifecycle)

local TransactionService: Lifecycle.Service = {
	Name = "TransactionService",
	Init = function(_self: Lifecycle.Service) end,
	Start = function(_self: Lifecycle.Service) end,
}

return TransactionService
