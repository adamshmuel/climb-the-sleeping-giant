--!strict
-- Starts the full test run in the background, in Edit (Lessons 22, 29 and 51). Paste as one execute_luau call, wait
-- about 60 s, then paste full-run-fetch.luau. If a run is already going, this says so and starts nothing.
local SS = game:GetService("ServerStorage")
local requireModule: (Instance) -> any = require :: any
if game:GetService("RunService"):IsRunning() then
	return "STOP: Play is on, this job runs in Edit"
end
local tests = SS:FindFirstChild("Tests")
if tests == nil or tests:FindFirstChild("BackgroundRun") == nil or tests:FindFirstChild("TestRunner") == nil then
	return "FIRED lookups: ServerStorage.Tests.BackgroundRun or TestRunner is missing (lost input)"
end
local folder = SS:FindFirstChild("FullRunFolder")
if folder == nil then
	folder = Instance.new("Folder")
	folder.Name = "FullRunFolder"
	folder.Archivable = false
	folder.Parent = SS
end
local specs = 0
for _, d in tests:GetDescendants() do
	if d:IsA("ModuleScript") and string.sub(d.Name, -5) == ".spec" then
		specs += 1
	end
end
local BackgroundRun: any = requireModule(tests.BackgroundRun:Clone())
local runner: any = requireModule(tests.TestRunner:Clone()).runRaw
local bg: any = BackgroundRun.new({ folder = folder, runner = runner })
return "full run: " .. tostring(bg.start(nil)) .. "; spec files " .. specs
