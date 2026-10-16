--!strict
-- Data/SettingsService (architecture §2.4, §6.1 PlayerSettings; API_CONTRACTS RequestSettings): the server's copy of each
-- player's settings for this session. Clients set whitelisted keys (Shared/Config/Settings) through RequestSettings; the
-- Gateway has already checked identity, rate (5/s, burst 10) and the payload guard, so the handler only stores the value.
-- A key the player never set reads nil (the client uses its device default). Values are dropped when the player leaves;
-- A5 persists them in PlayerProfile.Settings (D-020, D-023). Settings change presentation and input only, never power.
--   get(userId, key)   the stored value or nil
--   all(userId)        a copy of the player's stored values

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Settings = require(ReplicatedStorage.Shared.Config.Settings)
local Gateway = require(script.Parent.Parent.Parent.Gateway)

type Key = Settings.Key

-- The part of Server/Gateway this service uses (tests pass a fake).
export type Registrar = {
	handle: (self: any, name: string, handler: (player: Player, payload: any) -> any) -> (),
}

export type Options = {
	gateway: Registrar?, -- default Gateway.server()
	players: boolean?, -- connect Players.PlayerRemoving (default true)
}

export type SettingsService = {
	Name: string,
	Init: (self: SettingsService) -> (),
	Start: (self: SettingsService) -> (),
	get: (self: SettingsService, userId: number, key: Key) -> boolean?,
	all: (self: SettingsService, userId: number) -> { [string]: boolean },
	set: (self: SettingsService, player: Player, payload: { Key: Key, Value: boolean }) -> (),
	forget: (self: SettingsService, userId: number) -> (),
	new: (options: Options?) -> SettingsService,
}

local REMOTE = "RequestSettings"

local function new(options: Options?): SettingsService
	local injectedGateway: Registrar? = options and options.gateway
	local connectPlayers = not (options and options.players == false)
	local stored: { [number]: { [string]: boolean } } = {}

	local service = {} :: SettingsService
	service.Name = "SettingsService"
	service.new = new

	function service.Init(_: SettingsService) end

	function service.Start(self: SettingsService)
		local gateway: Registrar = injectedGateway or Gateway.server()
		gateway:handle(REMOTE, function(player: Player, payload: any)
			self:set(player, payload)
			return nil
		end)
		if connectPlayers then
			Players.PlayerRemoving:Connect(function(player: Player)
				self:forget(player.UserId)
			end)
		end
	end

	-- Called by the Gateway after the guard passed; a non-whitelisted key cannot reach here.
	function service.set(_: SettingsService, player: Player, payload: { Key: Key, Value: boolean })
		local values = stored[player.UserId]
		if values == nil then
			values = {}
			stored[player.UserId] = values
		end
		values[payload.Key] = payload.Value
		if RunService:IsStudio() then
			print(`[Settings] {player.Name} {payload.Key}={tostring(payload.Value)}`)
		end
	end

	function service.get(_: SettingsService, userId: number, key: Key): boolean?
		local values = stored[userId]
		return if values then values[key] else nil
	end

	function service.all(_: SettingsService, userId: number): { [string]: boolean }
		local values = stored[userId]
		return if values then table.clone(values) else {}
	end

	function service.forget(_: SettingsService, userId: number)
		stored[userId] = nil
	end

	return service
end

return new()
