--!strict
-- Test fixture (A2.2): a 24 × 24-stud arena template built in memory, for ArenaRaster.spec and ArenaService.spec.
-- With 2-stud cells it is a 12 × 12 grid: a one-cell wall ring, a 4 × 4-stud box covering cells (8..9, 8..9), the
-- player spawn at cell (5, 5) and two spawn edges, North (2..11, 2) and South (2..11, 11).

local ArenaFixture = {}

local function part(parent: Instance, name: string, size: Vector3, position: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = CFrame.new(position)
	p.Parent = parent
	return p
end

function ArenaFixture.template(name: string?): Model
	local model = Instance.new("Model")
	model.Name = name or "Mini"
	model:SetAttribute("ZoneId", "EvacuationStreets")
	part(model, "Floor", Vector3.new(24, 1, 24), Vector3.new(0, -0.5, 0))
	model.WorldPivot = CFrame.new(0, 0, 0)
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = model
	part(walls, "North", Vector3.new(24, 6, 2), Vector3.new(0, 3, -11))
	part(walls, "South", Vector3.new(24, 6, 2), Vector3.new(0, 3, 11))
	part(walls, "West", Vector3.new(2, 6, 24), Vector3.new(-11, 3, 0))
	part(walls, "East", Vector3.new(2, 6, 24), Vector3.new(11, 3, 0))
	part(model, "Box", Vector3.new(4, 5, 4), Vector3.new(4, 2.5, 4))
	local markers = Instance.new("Folder")
	markers.Name = "Markers"
	markers.Parent = model
	for _, marker in
		{
			part(markers, "PlayerSpawn", Vector3.new(2, 1, 2), Vector3.new(-4, 1, -4)),
			part(markers, "SpawnEdge_North", Vector3.new(20, 1, 2), Vector3.new(0, 0.5, -9)),
			part(markers, "SpawnEdge_South", Vector3.new(20, 1, 2), Vector3.new(0, 0.5, 9)),
		}
	do
		marker.CanCollide = false
		marker.Transparency = 1
	end
	return model
end

-- An Arenas definition for a rasterization of the template.
function ArenaFixture.definition(result: any, id: string?): { [string]: any }
	return {
		Id = id or "Mini",
		ZoneId = result.ZoneId,
		Template = id or "Mini",
		CellSize = result.CellSize,
		Width = result.Width,
		Depth = result.Depth,
		PlayerSpawn = result.PlayerSpawn,
		SpawnEdges = result.SpawnEdges,
		Rows = table.clone(result.Rows),
	}
end

return ArenaFixture
