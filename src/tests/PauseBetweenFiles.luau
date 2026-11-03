--!strict
-- Jest runs this file before every spec file (the `setupFilesAfterEnv` option, wired in TestRunner). It counts the
-- file on ServerStorage.Tests and then pauses for one frame, so Studio can answer other calls between spec files
-- during a full run. It must be a plain file with no tests in it.
local ServerStorage = game:GetService("ServerStorage")

local FILES_STARTED = "FilesStarted"

local tests = ServerStorage:FindFirstChild("Tests")
if tests ~= nil then
	tests:SetAttribute(FILES_STARTED, ((tests:GetAttribute(FILES_STARTED) :: number?) or 0) + 1)
end
task.wait()

return nil
