--!strict
-- Test fixture (A2.3): small arena grids and enemy definitions for the FlowField, EnemySteering and EnemyService specs.
-- mini(): the 12 × 12 grid of ArenaFixture as data (2-stud cells, wall ring, a 2 × 2-cell box at (8..9, 8..9), spawn
-- (5, 5), edges North (2..11, 2) and South (2..11, 11)), so specs need no template Instances.
-- definitions(): Walker and Runner as shipped, read from a clone of Shared/Definitions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyFixture = {}

function EnemyFixture.miniData(): { [string]: any }
	local rows = { "############" }
	for z = 2, 11 do
		if z == 8 or z == 9 then
			table.insert(rows, "#......##..#")
		else
			table.insert(rows, "#..........#")
		end
	end
	table.insert(rows, "############")
	return {
		CellSize = 2,
		Width = 12,
		Depth = 12,
		Rows = rows,
		PlayerSpawn = { X = 5, Z = 5 },
		SpawnEdges = {
			{ Id = "North", Min = { X = 2, Z = 2 }, Max = { X = 11, Z = 2 } },
			{ Id = "South", Min = { X = 2, Z = 11 }, Max = { X = 11, Z = 11 } },
		},
	}
end

-- Fresh copies of the shipped modules (Studio caches require per ModuleScript, so a clone picks up edits).
function EnemyFixture.shared(): Instance
	return ReplicatedStorage.Shared:Clone()
end

function EnemyFixture.definitions(shared: Instance): { [string]: any }
	local folder = (shared :: any).Definitions.Enemies
	return {
		Walker = (require :: any)(folder.Walker),
		Runner = (require :: any)(folder.Runner),
	}
end

return EnemyFixture
