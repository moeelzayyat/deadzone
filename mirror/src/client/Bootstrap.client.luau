--!strict
-- Client Bootstrap (architecture §4.3).
-- A1.1: checks the client layout and logs the controller list. Controllers arrive from A2 on.

local Players = game:GetService("Players")

local FOLDERS = { "Controllers", "UI", "Effects", "Render" }

local startedAt = os.clock()
local clientRoot = script.Parent :: Instance

for _, name in FOLDERS do
	if clientRoot:FindFirstChild(name) == nil then
		error(string.format("[Boot][Client] missing %s.%s", clientRoot:GetFullName(), name), 0)
	end
end

local controllers: { string } = {}
for _, child in (clientRoot:FindFirstChild("Controllers") :: Instance):GetChildren() do
	if child:IsA("ModuleScript") then
		table.insert(controllers, child.Name)
	end
end
table.sort(controllers)

print(string.format(
	"[Boot][Client] ready for %s in %.2f ms · controllers (%d): %s",
	Players.LocalPlayer.Name,
	(os.clock() - startedAt) * 1000,
	#controllers,
	if #controllers > 0 then table.concat(controllers, ", ") else "none yet"
))
