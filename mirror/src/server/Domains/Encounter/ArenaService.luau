--!strict
-- Encounter/ArenaService (architecture §4.4, §8.3): arena templates and their collision grids. Arenas are Models in
-- ServerStorage/Arenas; a mission gets its own copy, offset to a slot (one place, streaming enabled), and its enemies
-- steer on the copy's grid in arena-local space.
-- Init checks every Arenas definition against its template: the template exists and a fresh rasterization
-- (Util/ArenaRaster) equals the stored grid, so geometry and grid cannot drift apart; any mismatch stops the boot.
--   grid(arenaId) → ArenaGrid.Grid            the collision grid (read by EnemyService steering, A2.3)
--   place(arenaId, slot) → Placed              clones the template to its slot under Workspace/Arenas
--   release(placed)                            destroys the copy and frees the slot
--   slotOrigin(slot) → CFrame                  the arena origin (floor top centre) of a slot
--   toLocal(placed, world) / toWorld(placed, local) → Vector3
--   spawnCFrame(placed, character) → CFrame?   standing on the player spawn cell, facing north (-Z)
-- Test harness (flag TestArena, A2.2): Start places TestArena in slot 0 and moves every character there when it spawns.
-- Run sessions (A3) take this over; the flag goes off then.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ArenaGrid = require(ReplicatedStorage.Shared.Util.ArenaGrid)
local ArenaRaster = require(ReplicatedStorage.Shared.Util.ArenaRaster)
local Registry = require(ReplicatedStorage.Shared.Definitions._Registry)
local Lifecycle = require(script.Parent.Parent.Parent.Lifecycle)

local ARENA_ORIGIN = Vector3.new(0, 0, 1600) -- slot 0, past the baseplate edge (±1024) where the hub will stand
local SLOT_SPACING = 400 -- studs between slot origins along +X; templates up to 352 studs wide keep a 48-stud gap
local TEST_ARENA = "TestArena"

export type Placed = {
	Id: string,
	Slot: number,
	Model: Model,
	Origin: CFrame,
	Grid: ArenaGrid.Grid,
}

-- The part of FeatureFlagService this service uses (tests pass a fake).
export type FlagReader = { get: (self: any, name: string) -> any }

export type Options = {
	templates: Instance?, -- default ServerStorage/Arenas
	definitions: { { [string]: any } }?, -- default Registry.shared():all("Arenas")
	flags: FlagReader?, -- default FeatureFlagService, resolved in Init
	parent: Instance?, -- where Workspace/Arenas-style copies go; default Workspace/Arenas
	players: boolean?, -- move spawning characters into the test arena (default true)
}

export type ArenaService = {
	Name: string,
	Init: (self: ArenaService) -> (),
	Start: (self: ArenaService) -> (),
	grid: (self: ArenaService, arenaId: string) -> ArenaGrid.Grid,
	place: (self: ArenaService, arenaId: string, slot: number) -> Placed,
	release: (self: ArenaService, placed: Placed) -> (),
	slotOrigin: (self: ArenaService, slot: number) -> CFrame,
	toLocal: (self: ArenaService, placed: Placed, world: Vector3) -> Vector3,
	toWorld: (self: ArenaService, placed: Placed, position: Vector3) -> Vector3,
	spawnCFrame: (self: ArenaService, placed: Placed, character: Model) -> CFrame?,
	verify: (self: ArenaService) -> { string },
	new: (options: Options?) -> ArenaService,
}

local function new(options: Options?): ArenaService
	local injectedTemplates = options and options.templates
	local injectedDefinitions = options and options.definitions
	local injectedFlags = options and options.flags
	local injectedParent = options and options.parent
	local harness = not (options and options.players == false)

	local grids: { [string]: ArenaGrid.Grid } = {}
	local definitions: { [string]: { [string]: any } } = {}
	local occupied: { [number]: Placed } = {}
	local flags: FlagReader? = nil

	local function templates(): Instance?
		return injectedTemplates or ServerStorage:FindFirstChild("Arenas")
	end

	local function arenaParent(): Instance
		if injectedParent then
			return injectedParent
		end
		local folder = workspace:FindFirstChild("Arenas")
		if folder == nil then
			folder = Instance.new("Folder")
			folder.Name = "Arenas"
			folder.Parent = workspace
		end
		return folder :: Instance
	end

	local service = {} :: ArenaService
	service.Name = "ArenaService"
	service.new = new

	-- Loads every definition, checks it against its template and builds its grid. Returns the problems (empty = ok).
	function service.verify(_: ArenaService): { string }
		local problems: { string } = {}
		local list = injectedDefinitions or (Registry.shared():all("Arenas") :: any)
		local folder = templates()
		for _, def in list do
			local id: string = def.Id
			local template = folder and folder:FindFirstChild(def.Template)
			if template == nil or not template:IsA("Model") then
				table.insert(problems, `{id}: no template Model ServerStorage/Arenas/{def.Template}`)
				continue
			end
			local result, rasterProblems = ArenaRaster.rasterize(template, def.CellSize)
			for _, problem in rasterProblems do
				table.insert(problems, `{id}: template {problem}`)
			end
			if result == nil then
				continue
			end
			local diffs = ArenaRaster.diff(def, result)
			if #diffs > 0 then
				table.insert(
					problems,
					`{id}: the stored grid no longer matches the template ({table.concat(diffs, "; ")}); re-run tools/arena_export.luau`
				)
				continue
			end
			grids[id] = ArenaGrid.new(def :: any)
			definitions[id] = def
		end
		return problems
	end

	function service.Init(self: ArenaService)
		local startedAt = os.clock()
		local problems = self:verify()
		if #problems > 0 then
			error(`[Arena] {#problems} problems; the boot stops until they are fixed: {table.concat(problems, " | ")}`, 0)
		end
		flags = injectedFlags or (Lifecycle.get("FeatureFlagService") :: any)
		for id, grid in grids do
			print(
				string.format(
					"[Arena] %s %d × %d cells, %d open, %d spawn edges, checked against the template in %.2f ms",
					id,
					grid.width,
					grid.depth,
					grid.openCount,
					#grid.edges,
					(os.clock() - startedAt) * 1000
				)
			)
		end
	end

	function service.Start(self: ArenaService)
		local reader = flags
		if reader == nil or reader:get("TestArena") ~= true or grids[TEST_ARENA] == nil then
			return
		end
		local placed = self:place(TEST_ARENA, 0)
		if not harness then
			return
		end
		local function onCharacter(character: Model)
			if character.Parent == nil then
				character.AncestryChanged:Wait()
			end
			character:WaitForChild("HumanoidRootPart", 10)
			local target = self:spawnCFrame(placed, character)
			if target then
				character:PivotTo(target)
				local spawn = placed.Grid.spawn
				print(`[Arena] {character.Name} spawned in {placed.Id} slot {placed.Slot} at cell ({spawn.X},{spawn.Z})`)
			end
		end
		local function watch(player: Player)
			player.CharacterAdded:Connect(onCharacter)
			if player.Character then
				task.spawn(onCharacter, player.Character)
			end
		end
		Players.PlayerAdded:Connect(watch)
		for _, player in Players:GetPlayers() do
			watch(player)
		end
	end

	function service.grid(_: ArenaService, arenaId: string): ArenaGrid.Grid
		local grid = grids[arenaId]
		if grid == nil then
			error(`[Arena] unknown arena {arenaId}`, 2)
		end
		return grid
	end

	function service.slotOrigin(_: ArenaService, slot: number): CFrame
		return CFrame.new(ARENA_ORIGIN + Vector3.new(slot * SLOT_SPACING, 0, 0))
	end

	function service.place(self: ArenaService, arenaId: string, slot: number): Placed
		local def = definitions[arenaId]
		if def == nil then
			error(`[Arena] unknown arena {arenaId}`, 2)
		end
		if slot < 0 or slot % 1 ~= 0 then
			error(`[Arena] slot must be a whole number ≥ 0, got {slot}`, 2)
		end
		if occupied[slot] ~= nil then
			error(`[Arena] slot {slot} already holds {occupied[slot].Id}`, 2)
		end
		local folder = templates()
		local template = (folder :: Instance):FindFirstChild(def.Template) :: Model
		local startedAt = os.clock()
		local copy = template:Clone()
		copy.Name = `{arenaId}_{slot}`
		local origin = self:slotOrigin(slot)
		copy:PivotTo(origin)
		copy.Parent = arenaParent()
		local placed: Placed = table.freeze({
			Id = arenaId,
			Slot = slot,
			Model = copy,
			Origin = origin,
			Grid = grids[arenaId],
		})
		occupied[slot] = placed
		print(
			string.format(
				"[Arena] placed %s in slot %d at (%d, %d, %d) in %.2f ms",
				arenaId,
				slot,
				origin.X,
				origin.Y,
				origin.Z,
				(os.clock() - startedAt) * 1000
			)
		)
		return placed
	end

	function service.release(_: ArenaService, placed: Placed)
		if occupied[placed.Slot] == placed then
			occupied[placed.Slot] = nil
		end
		placed.Model:Destroy()
	end

	function service.toLocal(_: ArenaService, placed: Placed, world: Vector3): Vector3
		return placed.Origin:PointToObjectSpace(world)
	end

	function service.toWorld(_: ArenaService, placed: Placed, position: Vector3): Vector3
		return placed.Origin:PointToWorldSpace(position)
	end

	function service.spawnCFrame(_: ArenaService, placed: Placed, character: Model): CFrame?
		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if root == nil or not root:IsA("BasePart") or humanoid == nil then
			return nil
		end
		local spawn = placed.Grid.spawn
		local height = humanoid.HipHeight + (root :: BasePart).Size.Y / 2 + 0.1
		return placed.Origin * CFrame.new(placed.Grid:center(spawn.X, spawn.Z) + Vector3.new(0, height, 0))
	end

	return service
end

return new()
