--!strict
-- Render/Lib/RigPool (architecture §6.4, §23 "object pooling (measured)"): reusable enemy rigs per definition. A rig
-- leaves the pool by acquire() and comes back by release(); a released rig stays parented under the container and is
-- parked by moving its parts to PARK (far above the arena, outside every camera view), so reuse costs one BulkMoveTo
-- instead of building parts and inserting them into the DataModel. trim() destroys parked rigs beyond `keep` per
-- definition that sat unused for `idle` seconds, so a past wave does not hold memory forever.
--   RigPool.new(container, build) → Pool        build(defId) → (Model, { BasePart })
--   pool:acquire(defId) → Rig · pool:release(rig) · pool:prewarm(defId, n) → built · pool:trim(now, keep, idle) → destroyed
--   pool:stats() → { Built, Reused, Released, Destroyed, Active, Parked }

export type Rig = { DefId: string, Model: Model, Parts: { BasePart }, ParkedAt: number }

export type Stats = { Built: number, Reused: number, Released: number, Destroyed: number, Active: number, Parked: number }

export type Pool = {
	acquire: (self: Pool, defId: string) -> Rig,
	release: (self: Pool, rig: Rig) -> (),
	prewarm: (self: Pool, defId: string, count: number) -> number,
	trim: (self: Pool, now: number, keep: number, idle: number) -> number,
	stats: (self: Pool) -> Stats,
	parked: (self: Pool, defId: string) -> number,
}

local PARK = CFrame.new(0, 10000, 0)

local RigPool = { PARK = PARK }

function RigPool.new(container: Instance, build: (defId: string) -> (Model, { BasePart })): Pool
	local free: { [string]: { Rig } } = {}
	local counts = { Built = 0, Reused = 0, Released = 0, Destroyed = 0, Active = 0 }

	local function park(rig: Rig)
		workspace:BulkMoveTo(rig.Parts, table.create(#rig.Parts, PARK), Enum.BulkMoveMode.FireCFrameChanged)
	end

	local function make(defId: string): Rig
		local model, parts = build(defId)
		local rig = { DefId = defId, Model = model, Parts = parts, ParkedAt = 0 }
		park(rig)
		model.Parent = container
		counts.Built += 1
		return rig
	end

	local pool = {} :: Pool

	function pool.acquire(_self: Pool, defId: string): Rig
		local list = free[defId]
		local rig = list and table.remove(list)
		if rig then
			counts.Reused += 1
		else
			rig = make(defId)
		end
		counts.Active += 1
		return rig :: Rig
	end

	function pool.release(_self: Pool, rig: Rig)
		park(rig)
		rig.ParkedAt = os.clock()
		local list = free[rig.DefId]
		if list == nil then
			list = {}
			free[rig.DefId] = list
		end
		table.insert(list, rig)
		counts.Released += 1
		counts.Active -= 1
	end

	function pool.prewarm(_self: Pool, defId: string, count: number): number
		local list = free[defId]
		if list == nil then
			list = {}
			free[defId] = list
		end
		local built = 0
		while #list < count do
			local rig = make(defId)
			rig.ParkedAt = os.clock()
			table.insert(list, rig)
			built += 1
		end
		return built
	end

	function pool.trim(_self: Pool, now: number, keep: number, idle: number): number
		local destroyed = 0
		for _, list in free do
			-- the oldest parked rigs sit at the front (release appends, acquire takes from the end)
			while #list > keep and now - list[1].ParkedAt >= idle do
				local rig = table.remove(list, 1) :: Rig
				rig.Model:Destroy()
				destroyed += 1
			end
		end
		counts.Destroyed += destroyed
		return destroyed
	end

	function pool.parked(_self: Pool, defId: string): number
		local list = free[defId]
		return if list then #list else 0
	end

	function pool.stats(_self: Pool): Stats
		local parked = 0
		for _, list in free do
			parked += #list
		end
		return {
			Built = counts.Built,
			Reused = counts.Reused,
			Released = counts.Released,
			Destroyed = counts.Destroyed,
			Active = counts.Active,
			Parked = parked,
		}
	end

	return pool
end

return table.freeze(RigPool)
