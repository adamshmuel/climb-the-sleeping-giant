--!strict
-- Fetches the full run that full-run-start.luau started: waits inside up to 30 s, returns the report, and removes the
-- folder once the run is done. Never starts a run, so it is safe to paste again (Lesson 51).
local SS = game:GetService("ServerStorage")
local requireModule: (Instance) -> any = require :: any
local folder = SS:FindFirstChild("FullRunFolder")
if folder == nil then
	return "no run: nothing was started (paste full-run-start.luau first)"
end
local BackgroundRun: any = requireModule(SS.Tests.BackgroundRun)
local bg: any = BackgroundRun.new({ folder = folder, runner = function() end })
local report: string = bg.fetch(30)
if folder:GetAttribute("Status") == nil then
	folder:Destroy()
end
return report
