--!strict
-- Where the designer's nest mockup is: ServerStorage.ArtLibrary.Mockup_Nests since plan 5 Task 16b (it left the Workspace),
-- else Workspace.Mockup_Nests (a place that has not run tools/world/36-mockups-to-library.luau yet). The world scripts
-- 17, 21, 21b, 22, 23d, 24 and 27 read it through this one lookup. Mirrors src/tests/server/World/MockupNests.luau.
-- Use: `local MockupNests = (require :: any)(ServerStorage.Tools.checks.MockupNests:Clone())` (a clone: Edit caches requires).
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local MockupNests = {}

-- The Mockup_Nests folder, or nil when neither home has one.
function MockupNests.find(): Instance?
	local library = ServerStorage:FindFirstChild("ArtLibrary")
	local inLibrary = if library ~= nil then library:FindFirstChild("Mockup_Nests") else nil
	if inLibrary ~= nil then
		return inLibrary
	end
	return Workspace:FindFirstChild("Mockup_Nests")
end

return MockupNests
