--!strict
-- TestRunner (architecture §20, §26): in-house describe/it/expect harness, run in Studio via execute_luau.
-- A spec is a ModuleScript named "*.spec" under ServerStorage/Tests/{unit,integration} that returns function(t: Spec).
-- Tests may yield (task.wait, events); each runs in its own thread with a timeout.
-- Usage (execute_luau, Edit): Studio caches require() per ModuleScript across calls, so run a clone to pick up edits:
--   local tests = game:GetService("ServerStorage").Tests:Clone()
--   return require(tests.TestRunner).run({ tests.unit, tests.integration }).summary
-- In a play test (Server datamodel) requires are fresh: require(ServerStorage.Tests.TestRunner).run() is enough.

local ServerStorage = game:GetService("ServerStorage")

export type Expectation = {
	toBe: (expected: unknown) -> (),
	toEqual: (expected: unknown) -> (),
	toBeNil: () -> (),
	toBeTruthy: () -> (),
	toBeCloseTo: (expected: number, epsilon: number?) -> (),
	toBeGreaterThan: (bound: number) -> (),
	toBeLessThan: (bound: number) -> (),
	toThrow: (fragment: string?) -> (),
}

export type Spec = {
	describe: (name: string, body: () -> ()) -> (),
	it: (name: string, body: () -> (), timeoutSeconds: number?) -> (),
	expect: (actual: unknown) -> Expectation,
}

export type TestResult = { file: string, name: string, ok: boolean, message: string?, ms: number }

export type Report = {
	passed: number,
	failed: number,
	files: number,
	ms: number,
	results: { TestResult },
	summary: string,
}

type Case = { name: string, body: () -> (), timeout: number }

local DEFAULT_TIMEOUT = 5
local PREFIX = "[TestRunner] "

local TestRunner = {}

local function show(value: unknown): string
	if typeof(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

local function deepEqual(a: unknown, b: unknown): boolean
	if a == b then
		return true
	end
	if typeof(a) ~= "table" or typeof(b) ~= "table" then
		return false
	end
	local left = a :: { [unknown]: unknown }
	local right = b :: { [unknown]: unknown }
	for key, value in left do
		if not deepEqual(value, right[key]) then
			return false
		end
	end
	for key in right do
		if left[key] == nil then
			return false
		end
	end
	return true
end

-- No error level: Luau inlining makes levels unreliable. runCase adds the spec line from the traceback instead.
local function fail(message: string)
	error(message, 0)
end

local function expect(actual: unknown): Expectation
	return {
		toBe = function(expected: unknown)
			if actual ~= expected then
				fail(`expected {show(actual)} to be {show(expected)}`)
			end
		end,
		toEqual = function(expected: unknown)
			if not deepEqual(actual, expected) then
				fail(`expected {show(actual)} to deep-equal {show(expected)}`)
			end
		end,
		toBeNil = function()
			if actual ~= nil then
				fail(`expected {show(actual)} to be nil`)
			end
		end,
		toBeTruthy = function()
			if not actual then
				fail(`expected {show(actual)} to be truthy`)
			end
		end,
		toBeCloseTo = function(expected: number, epsilon: number?)
			local tolerance = epsilon or 1e-6
			if typeof(actual) ~= "number" or math.abs(actual - expected) > tolerance then
				fail(`expected {show(actual)} to be within {tolerance} of {expected}`)
			end
		end,
		toBeGreaterThan = function(bound: number)
			if typeof(actual) ~= "number" or actual <= bound then
				fail(`expected {show(actual)} to be greater than {bound}`)
			end
		end,
		toBeLessThan = function(bound: number)
			if typeof(actual) ~= "number" or actual >= bound then
				fail(`expected {show(actual)} to be less than {bound}`)
			end
		end,
		toThrow = function(fragment: string?)
			if typeof(actual) ~= "function" then
				fail(`expected a function, got {typeof(actual)}`)
				return
			end
			local ok, err = pcall(actual :: () -> unknown)
			if ok then
				fail("expected the function to throw")
			elseif fragment and not string.find(tostring(err), fragment, 1, true) then
				fail(`expected error containing {show(fragment)}, got {show(tostring(err))}`)
			end
		end,
	}
end

-- Runs the spec's top level to register its cases. A load error fails the whole file.
local function collect(module: ModuleScript): ({ Case }, string?)
	local cases: { Case } = {}
	local stack: { string } = {}
	local spec: Spec = {
		describe = function(name: string, body: () -> ())
			table.insert(stack, name)
			body()
			table.remove(stack)
		end,
		it = function(name: string, body: () -> (), timeoutSeconds: number?)
			local path = table.clone(stack)
			table.insert(path, name)
			table.insert(cases, { name = table.concat(path, " › "), body = body, timeout = timeoutSeconds or DEFAULT_TIMEOUT })
		end,
		expect = expect,
	}
	local ok, err = pcall(function()
		local entry = require(module) :: unknown
		if typeof(entry) ~= "function" then
			error("spec must return function(t: Spec)", 0)
		end
		(entry :: (Spec) -> ())(spec)
	end)
	return cases, if ok then nil else tostring(err)
end

-- Appends "(line N)" from the first traceback frame inside the spec, unless the message already names the spec.
local function locate(err: unknown, source: string): string
	local text = tostring(err)
	if string.find(text, source .. ":", 1, true) then
		return text
	end
	for frame in string.gmatch(debug.traceback(), "[^\n]+") do
		local at = string.find(frame, source .. ":", 1, true)
		local line = if at then string.match(frame, "^(%d+)", at + #source + 1) else nil
		if line then
			return `{text} (line {line})`
		end
	end
	return text
end

-- A synchronous body finishes inside task.spawn; a yielding one is polled each frame until done or timed out.
local function runCase(case: Case, source: string): (boolean, string?)
	local done, ok, message = false, false, nil :: string?
	local thread = task.spawn(function()
		local success, err = xpcall(case.body :: () -> unknown, function(e: unknown): string
			return locate(e, source)
		end)
		ok, message, done = success, if success then nil else tostring(err), true
	end)
	local deadline = os.clock() + case.timeout
	while not done do
		if os.clock() > deadline then
			task.cancel(thread)
			return false, string.format("timed out after %.2f s", case.timeout)
		end
		task.wait()
	end
	return ok, message
end

local function specModules(roots: { Instance }): { ModuleScript }
	local found: { ModuleScript } = {}
	for _, root in roots do
		for _, item in root:GetDescendants() do
			if item:IsA("ModuleScript") and string.sub(item.Name, -5) == ".spec" then
				table.insert(found, item)
			end
		end
	end
	table.sort(found, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)
	return found
end

local function defaultRoots(): { Instance }
	local tests = ServerStorage:FindFirstChild("Tests")
	assert(tests, "ServerStorage.Tests is missing")
	local roots: { Instance } = {}
	for _, name in { "unit", "integration" } do
		local folder = tests:FindFirstChild(name)
		if folder then
			table.insert(roots, folder)
		end
	end
	return roots
end

local function label(module: ModuleScript): string
	return (string.gsub(module:GetFullName(), "^.-Tests%.", ""))
end

function TestRunner.run(roots: { Instance }?): Report
	local startedAt = os.clock()
	local results: { TestResult } = {}
	local rows: { string } = {}
	local passed, failed = 0, 0
	local modules = specModules(roots or defaultRoots())

	local function record(result: TestResult)
		table.insert(results, result)
		if result.ok then
			passed += 1
			print(string.format("%sPASS %s › %s (%.2f ms)", PREFIX, result.file, result.name, result.ms))
		else
			failed += 1
			warn(string.format("%sFAIL %s › %s (%.2f ms): %s", PREFIX, result.file, result.name, result.ms, result.message or "?"))
		end
	end

	for _, module in modules do
		local file = label(module)
		local fileStart = os.clock()
		local filePassed, fileFailed = passed, failed
		local cases, loadError = collect(module)
		if loadError then
			record({ file = file, name = "(load)", ok = false, message = loadError, ms = 0 })
		end
		for _, case in cases do
			local caseStart = os.clock()
			local ok, message = runCase(case, module:GetFullName())
			record({ file = file, name = case.name, ok = ok, message = message, ms = (os.clock() - caseStart) * 1000 })
		end
		table.insert(rows, string.format("%-40s %6d %6d %9.2f", file, passed - filePassed, failed - fileFailed, (os.clock() - fileStart) * 1000))
	end

	local ms = (os.clock() - startedAt) * 1000
	local lines = { string.format("%-40s %6s %6s %9s", "file", "passed", "failed", "ms") }
	for _, row in rows do
		table.insert(lines, row)
	end
	table.insert(lines, string.format("%d passed, %d failed (%d %s, %.2f ms)", passed, failed, #modules, if #modules == 1 then "file" else "files", ms))
	for _, line in lines do
		print(PREFIX .. line)
	end
	return { passed = passed, failed = failed, files = #modules, ms = ms, results = results, summary = table.concat(lines, "\n") }
end

return TestRunner
