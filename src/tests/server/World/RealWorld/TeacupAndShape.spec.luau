--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerScriptService = game:GetService("ServerScriptService")
local PathCheck = require(ServerScriptService.Server.World.PathCheck)
local Helpers = require(script.Parent.Helpers)
local BODY_PIECES = Helpers.BODY_PIECES
local bodyMesh = Helpers.bodyMesh

-- The teacup's bowl (V2 stuck safety, Task 6). The cup's bowl is open on top, so a player who got in was wedged (the
-- 4 stuck spots of the Task 18 review). tools/world/14-teacup-tea.luau sets the cup's collision to Hull (Roblox's smooth
-- wrap, which fills the bowl up to its rim) and adds the tea: one flat brown disc just below the rim, so a player
-- standing on top of the filled bowl stands over something they can see. The tea is tilted like the cup, because the
-- cup's rim is not level (designer, docs/specs/v2/research/decisions-plans.md, "Stuck safety Task 6: the tea on a tilted
-- rim").
describe("the real world, the teacup's bowl", function()
	local Workspace = game:GetService("Workspace")

	-- MEASURED BY HAND on 2026-10-19, in Studio Edit mode, before the cup became Hull (once it is Hull the inside of the
	-- bowl can't be measured again). The method: rays straight down onto the cup's own mesh (RespectCanCollide off,
	-- only the cup in the filter), outwards from (76, 30) every 0.1 studs from 6 to 16 studs, at 72 angles 5 degrees
	-- apart. The rim crest of each angle is its highest hit. The rim plane is the least-squares plane through the 72
	-- crest points: y = RIM_SLOPE_X * x + RIM_SLOPE_Z * z + RIM_BASE. It tilts the rim 8.8 degrees, highest to the
	-- west/north-west (lowest crest 18.35, highest on the bowl 23.0).
	local RIM_SLOPE_X = -0.134338
	local RIM_SLOPE_Z = -0.077725
	local RIM_BASE = 26.486
	-- The cup was measured at its old place; it now sits this far away (Tasks 4e3 and 4f moved it). The measured
	-- spots below are shifted by it, and the rim plane is read at the old place.
	local MOVED_X = -0.497
	local MOVED_Z = 87.713
	-- The crest point that sits farthest below the plane (the worst one), 0.45336 studs under it.
	local WORST_RIM_X = 69.55 + MOVED_X
	local WORST_RIM_Z = -46.8283 + MOVED_Z
	local WORST_RIM_Y = 20.3291
	-- The tea's top is this far under the rim plane: the worst point's distance plus 0.1 (designer).
	local TEA_DROP = 0.5534
	-- The circle fitted to the inside of the bowl at the tea's height (the wall found by rays down along 72 angles
	-- in the tea's own plane): its centre, on the tea's top plane, and its radius. The tea's radius is that plus 0.3,
	-- so its edge tucks into the cup wall (designer).
	local CIRCLE_CENTRE_X = 77.3985 + MOVED_X
	local CIRCLE_CENTRE_Z = -57.1986 + MOVED_Z
	local CIRCLE_RADIUS = 11.941
	local TEA_RADIUS = CIRCLE_RADIUS + 0.3
	local TEA_THICKNESS = 0.4
	local TEA_COLOUR = Color3.fromHex("9C5E34")
	-- A player's feet over the tea, measured straight down from the feet to the tea's top (designer).
	local FEET_NEAREST = 0.4
	local FEET_FARTHEST = 1.0
	local TOLERANCE = 0.02

	local function teacup(): Model
		local world = Workspace:FindFirstChild("World")
		expect(world).never.toBeNil()
		local things = (world :: Instance):FindFirstChild("GiantsThings")
		expect(things).never.toBeNil()
		local cup = (things :: Instance):FindFirstChild("Teacup")
		expect(cup).never.toBeNil()
		return cup :: Model
	end

	local function cupMesh(): MeshPart
		local mesh = teacup():FindFirstChild("body_geom", true)
		expect(mesh).never.toBeNil()
		return mesh :: MeshPart
	end

	-- Every part named Tea in the teacup.
	local function teaParts(): { BasePart }
		local found: { BasePart } = {}
		for _, descendant in teacup():GetDescendants() do
			if descendant.Name == "Tea" and descendant:IsA("BasePart") then
				table.insert(found, descendant)
			end
		end
		return found
	end

	-- The one tea part, or a failed test.
	local function tea(): Part
		local parts = teaParts()
		expect(#parts).toBe(1)
		return parts[1] :: Part
	end

	-- The tea's own top: the point in the middle of its top face, and the direction that face points (its X axis,
	-- because Roblox's cylinder stands along X).
	local function teaTop(part: BasePart): (Vector3, Vector3)
		local up = part.CFrame.RightVector
		return part.Position + up * (part.Size.X / 2), up
	end

	-- The height of the tea's top surface straight above or below (x, z).
	local function teaTopHeightAt(part: BasePart, x: number, z: number): number
		local point, up = teaTop(part)
		return point.Y - (up.X * (x - point.X) + up.Z * (z - point.Z)) / up.Y
	end

	local function rimPlaneHeight(x: number, z: number): number
		return RIM_SLOPE_X * (x - MOVED_X) + RIM_SLOPE_Z * (z - MOVED_Z) + RIM_BASE
	end

	it("the teacup's collision is the smooth wrap", function()
		expect(cupMesh().CollisionFidelity).toBe(Enum.CollisionFidelity.Hull)
	end)

	-- The stuck scan's standing places in the bowl, found with rays down onto the cup's own mesh on 2026-10-19 (before the
	-- cup became Hull): each is where a ray lands and the ground's slope there. The first four are the stuck spots of the
	-- Task 18 review (the scan listed them rounded to 0.1). The last is the bottom of the bowl, near the cup's middle.
	-- A standing body fits at every one of them today; the box tilts with the slope, as the scan's does.
	it("no standing body fits in the teacup's bowl", function()
		local options = PathCheck.defaults(Workspace)
		local spots: { { name: string, feet: Vector3, up: Vector3 } } = {
			{
				name = "stuck spot 1",
				feet = Vector3.new(69.2, 11.6036, 27),
				up = Vector3.new(0.8267, 0.5524, -0.1065).Unit,
			},
			{
				name = "stuck spot 2",
				feet = Vector3.new(69.2, 11.7288, 29),
				up = Vector3.new(0.6058, 0.7956, 0.0002).Unit,
			},
			{
				name = "stuck spot 3",
				feet = Vector3.new(69.2, 11.7282, 31),
				up = Vector3.new(0.6058, 0.7956, 0.0002).Unit,
			},
			{
				name = "stuck spot 4",
				feet = Vector3.new(69.2, 11.7276, 33),
				up = Vector3.new(0.6058, 0.7956, 0.0002).Unit,
			},
			{
				name = "bottom of the bowl",
				feet = Vector3.new(75, 6.0759, 30),
				up = Vector3.new(0.1949, 0.9799, -0.0424).Unit,
			},
		}
		local fitting: { string } = {}
		for _, spot in spots do
			if PathCheck.roomToStand(options, spot.feet, spot.up) then
				table.insert(fitting, spot.name)
			end
		end
		PathCheck.cleanup(options) -- takes the body probe out of the Workspace, whatever the result
		expect(fitting).toEqual({})
	end)

	it("there is exactly one Tea part in the teacup", function()
		expect(#teaParts()).toBe(1)
	end)

	it("the tea is tea brown, smooth plastic and not see-through", function()
		local part = tea()
		expect(part.Color).toEqual(TEA_COLOUR)
		expect(part.Material).toBe(Enum.Material.SmoothPlastic)
		expect(part.Transparency).toBe(0)
	end)

	it("the tea is a round disc", function()
		local part = tea()
		expect(part:IsA("Part")).toBe(true)
		expect(part.Shape).toBe(Enum.PartType.Cylinder)
	end)

	it("nobody bumps into the tea, finds it with a check or touches it, and it stays put", function()
		local part = tea()
		expect(part.CanCollide).toBe(false)
		expect(part.CanQuery).toBe(false)
		expect(part.CanTouch).toBe(false)
		expect(part.Anchored).toBe(true)
	end)

	it("the tea is 0.4 studs thick and as wide as the bowl's inside plus 0.3 studs each side", function()
		local part = tea()
		expect(math.abs(part.Size.X - TEA_THICKNESS) < TOLERANCE).toBe(true)
		expect(math.abs(part.Size.Y - TEA_RADIUS * 2) < TOLERANCE).toBe(true)
		expect(math.abs(part.Size.Z - TEA_RADIUS * 2) < TOLERANCE).toBe(true)
	end)

	it("the tea lies in the same tilt as the cup's rim", function()
		local part = tea()
		local expected = Vector3.new(-RIM_SLOPE_X, 1, -RIM_SLOPE_Z).Unit
		expect((part.CFrame.RightVector - expected).Magnitude < 0.001).toBe(true)
	end)

	it("the tea's middle is the fitted circle's middle and its top is 0.5534 studs under the rim plane", function()
		local part = tea()
		local point = teaTop(part)
		expect(math.abs(point.X - CIRCLE_CENTRE_X) < TOLERANCE).toBe(true)
		expect(math.abs(point.Z - CIRCLE_CENTRE_Z) < TOLERANCE).toBe(true)
		local planeHeight = rimPlaneHeight(point.X, point.Z)
		expect(math.abs(planeHeight - TEA_DROP - point.Y) < TOLERANCE).toBe(true)
	end)

	it("the tea never shows above the rim: it is at least 0.1 studs under the worst rim point", function()
		local part = tea()
		-- the worst crest point is 0.45336 under the plane; the tea's top is 0.1 under it
		local gap = WORST_RIM_Y - teaTopHeightAt(part, WORST_RIM_X, WORST_RIM_Z)
		expect(gap >= 0.1 - 0.001).toBe(true)
	end)

	it("a player on top of the filled bowl stands 0.4 to 1.0 studs over the tea, west, middle and east", function()
		local part = tea()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { teacup() }
		params.RespectCanCollide = true -- sees only what a player bumps into
		local points: { [string]: Vector3 } = {
			west = Vector3.new(68, 0, 30),
			middle = Vector3.new(76, 0, 30),
			east = Vector3.new(86, 0, 30),
		}
		local bad: { string } = {}
		for name, point in points do
			local hit = Workspace:Raycast(Vector3.new(point.X, 60, point.Z), Vector3.new(0, -80, 0), params)
			if hit == nil then
				table.insert(bad, `{name}: the ray hit nothing`)
			else
				local feetOver = hit.Position.Y - teaTopHeightAt(part, point.X, point.Z)
				if feetOver < FEET_NEAREST or feetOver > FEET_FARTHEST then
					table.insert(bad, `{name}: feet {string.format("%.2f", feetOver)} studs over the tea`)
				end
			end
		end
		table.sort(bad)
		expect(bad).toEqual({})
	end)
end)

-- Stuck safety Task 19: his real shape (docs/plans/v2/stuck-safety.md, "How his real shape is patched"). The giant's six
-- body pieces keep Roblox's closest collision match of the mesh players see (tools/world/15-real-shape.luau), so the
-- surface players stand on is the skin they see. The pieces stay in the normal collision group, so players, every check
-- and the camera all meet the same surface. These tests only READ the world.
describe("the real world, his real shape", function()
	-- Task 26 ("Ruling after step 26-3", and Ruling 9 after step 26-4e): the belly and chair, the legs, the head and the
	-- nightcap use the closer fit (Tunable at CollisionPrecision 1). Both arms keep Roblox's Precise shape.
	local CLOSER_FIT_PIECES: { [string]: boolean } = {
		legs_and_boots = true,
		body_and_cushion = true,
		head_with_beard = true,
		nightcap = true,
	}
	local CLOSER_FIT_PRECISION = 0.99

	it("his six body pieces use his real shape", function()
		local wrong: { string } = {}
		for _, pieceName in BODY_PIECES do
			local mesh = bodyMesh(pieceName)
			local wanted = if CLOSER_FIT_PIECES[pieceName]
				then Enum.CollisionFidelity.Tunable
				else Enum.CollisionFidelity.PreciseConvexDecomposition
			local precisionOk = not CLOSER_FIT_PIECES[pieceName] or mesh.CollisionPrecision >= CLOSER_FIT_PRECISION
			if mesh.CollisionFidelity ~= wanted or not precisionOk then
				local precisionText = string.format("%.2f", mesh.CollisionPrecision)
				local wantedText = wanted.Name
				if CLOSER_FIT_PIECES[pieceName] then
					wantedText ..= " with CollisionPrecision at least 0.99"
				end
				table.insert(
					wrong,
					`{pieceName}: CollisionFidelity is {mesh.CollisionFidelity.Name}, CollisionPrecision {precisionText}, wanted {wantedText}`
				)
			end
			if not (mesh.CanCollide and mesh.CanQuery and mesh.CanTouch) then
				table.insert(
					wrong,
					`{pieceName}: CanCollide {mesh.CanCollide}, CanQuery {mesh.CanQuery}, CanTouch {mesh.CanTouch}`
				)
			end
			if mesh.CollisionGroup ~= "Default" then
				table.insert(wrong, `{pieceName}: CollisionGroup is {mesh.CollisionGroup}`)
			end
		end
		expect(wrong).toEqual({})
	end)
end)
