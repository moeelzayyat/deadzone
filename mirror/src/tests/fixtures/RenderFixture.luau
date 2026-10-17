--!strict
-- Test fixture (A2.4): fresh copies of the client's render libraries (StarterPlayerScripts/Client/Render/Lib) for the
-- SnapshotInterpolation, EnemyPose, EnemyRigs and RigPool specs. Studio caches require per ModuleScript, so a clone
-- picks up edits; the libraries touch no Players or RunService state when required, so they load in Edit and on the
-- server alike.

local StarterPlayer = game:GetService("StarterPlayer")

local RenderFixture = {}

function RenderFixture.lib(): Instance
	local scripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	local client = scripts and scripts:FindFirstChild("Client")
	local render = client and client:FindFirstChild("Render")
	local lib = render and render:FindFirstChild("Lib")
	assert(lib ~= nil, "StarterPlayerScripts/Client/Render/Lib is missing")
	return lib:Clone()
end

function RenderFixture.require(lib: Instance, name: string): any
	local module = lib:FindFirstChild(name)
	assert(module ~= nil and module:IsA("ModuleScript"), `Render/Lib/{name} is missing`)
	return (require :: any)(module)
end

return RenderFixture
