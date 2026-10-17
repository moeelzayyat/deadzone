--!strict
-- Client Bootstrap (architecture §4.3).
-- Checks the client layout (A1.1), then requires every module in Controllers, then Render, then UI (name order inside
-- each folder), and runs its start() in its own thread, so a module waiting for the server's phase 8 remotes blocks no
-- one (A1.8; UI since A2.1, Render since A2.4). Each is a ModuleScript returning { Name = <module name>, start = function };
-- library modules live in subfolders (Render/Lib), which are not started.

local Players = game:GetService("Players")

local FOLDERS = { "Controllers", "UI", "Effects", "Render" }
local STARTED = { "Controllers", "Render", "UI" } -- started in this order

local startedAt = os.clock()
local clientRoot = script.Parent :: Instance

for _, name in FOLDERS do
	if clientRoot:FindFirstChild(name) == nil then
		error(string.format("[Boot][Client] missing %s.%s", clientRoot:GetFullName(), name), 0)
	end
end

local modules: { ModuleScript } = {}
for _, folder in STARTED do
	local inFolder: { ModuleScript } = {}
	for _, child in (clientRoot:FindFirstChild(folder) :: Instance):GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(inFolder, child)
		end
	end
	table.sort(inFolder, function(a: ModuleScript, b: ModuleScript): boolean
		return a.Name < b.Name
	end)
	table.move(inFolder, 1, #inFolder, #modules + 1, modules)
end

local controllers: { string } = {}
for _, module in modules do
	local controller = require(module) :: any
	if typeof(controller) ~= "table" or controller.Name ~= module.Name or typeof(controller.start) ~= "function" then
		error(string.format("[Boot][Client] %s must return { Name = %q, start = function }", module.Name, module.Name), 0)
	end
	task.spawn(controller.start)
	table.insert(controllers, module.Name)
end

print(string.format(
	"[Boot][Client] ready for %s in %.2f ms · modules (%d): %s",
	Players.LocalPlayer.Name,
	(os.clock() - startedAt) * 1000,
	#controllers,
	if #controllers > 0 then table.concat(controllers, ", ") else "none yet"
))
