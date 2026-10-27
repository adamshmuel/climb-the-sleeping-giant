--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

-- Stuck safety Task 41, test 4. Step 1 (read-only, 2026-10-27) found 12 parts touching the old pillow: his body, head and
-- nightcap pieces (they stay), and 9 guards in World.WalkSurfaces.SteepGuards. Eight of the guards also touch a part
-- that stays, so they stay. CapSideLeft_52 touched only the old pillow, so it goes (decision table, first row). No
-- meadow prop stands in the new pillow's footprint (step 1 found none), so no prop is listed.
describe("the real world, the old pillow's fitted parts", function()
	local Workspace = game:GetService("Workspace")
	local REMOVED_GUARDS = { "CapSideLeft_52" }

	it("the old pillow's fitted parts and the meadow props in its footprint are gone", function()
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local guards = (world :: any).WalkSurfaces.SteepGuards :: Instance
		local still: { string } = {}
		for _, name in REMOVED_GUARDS do
			if guards:FindFirstChild(name) ~= nil then
				table.insert(still, `World.WalkSurfaces.SteepGuards.{name} is still there`)
			end
		end
		expect(still).toEqual({})
	end)
end)
