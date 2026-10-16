--!strict
-- Encounter/SimulationClock (architecture §9.1): one pausable clock per match. Everything in a run (enemy ticks, cooldowns,
-- DoT, protocol progress, extraction timers) reads `match.Clock`, never os.clock().
--   SimulationClock.new() -> Clock      a clock at 0 s, running
--   clock:Tick(dt) -> number            advances by dt (capped at MaxStep, so a server hitch slows the run instead of
--                                       teleporting it) and returns the time added; a paused clock adds 0
--   clock:Now() -> number               simulation seconds since the match started (paused time excluded)
--   clock:Pause() / clock:Resume()      set Paused; both are idempotent. Pausing is the only thing that stops the clock;
--                                       nothing else needs to know (§9.1).
-- The match loop (A2/A3) calls Tick once per server step with the Heartbeat dt. A negative, NaN or infinite dt is a bug
-- and throws "[Clock] ...".
-- The module is also the Encounter service of that name (§5.1), with empty Init/Start: clocks belong to matches.

export type Clock = {
	Time: number,
	Paused: boolean,
	Ticks: number, -- ticks that advanced the clock
	MaxStep: number,
	Tick: (self: Clock, dt: number) -> number,
	Now: (self: Clock) -> number,
	Pause: (self: Clock) -> (),
	Resume: (self: Clock) -> (),
}

export type Options = { maxStep: number? }

local DEFAULT_MAX_STEP = 0.25 -- seconds; equals the §7.1 rewind window

local function fail(message: string): never
	error("[Clock] " .. message, 0)
end

local function finite(x: number): boolean
	return x == x and x ~= math.huge and x ~= -math.huge
end

local function tick(self: Clock, dt: number): number
	if typeof(dt) ~= "number" or not finite(dt) or dt < 0 then
		fail(`dt must be a finite number ≥ 0, got {tostring(dt)}`)
	end
	if self.Paused or dt == 0 then
		return 0
	end
	local step = math.min(dt, self.MaxStep)
	self.Time += step
	self.Ticks += 1
	return step
end

local function now(self: Clock): number
	return self.Time
end

local function pause(self: Clock)
	self.Paused = true
end

local function resume(self: Clock)
	self.Paused = false
end

local function new(options: Options?): Clock
	local maxStep = if options and options.maxStep then options.maxStep else DEFAULT_MAX_STEP
	if typeof(maxStep) ~= "number" or not finite(maxStep) or maxStep <= 0 then
		fail(`maxStep must be a finite number > 0, got {tostring(maxStep)}`)
	end
	local clock: Clock = {
		Time = 0,
		Paused = false,
		Ticks = 0,
		MaxStep = maxStep,
		Tick = tick,
		Now = now,
		Pause = pause,
		Resume = resume,
	}
	return clock
end

local SimulationClock = {
	Name = "SimulationClock",
	DEFAULT_MAX_STEP = DEFAULT_MAX_STEP,
	new = new,
	Init = function(_self: unknown) end,
	Start = function(_self: unknown) end,
}

return table.freeze(SimulationClock)
