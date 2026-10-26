--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Footprints = require(StarterPlayer.StarterPlayerScripts.Client.World.Footprints)
local RouteGraph = require(StarterPlayer.StarterPlayerScripts.Client.World.RouteGraph)
local Helpers = require(script.Parent.Helpers)
type Point = Helpers.Point
type Rig = Helpers.Rig
local UPDATE_SECONDS = Helpers.UPDATE_SECONDS
local cleanUp = Helpers.cleanUp
local defaultPoints = Helpers.defaultPoints
local expectNear = Helpers.expectNear
local made = Helpers.made
local newRig = Helpers.newRig

afterEach(cleanUp)

describe("Footprints.feetOf", function()
	local function newCharacter(hipHeight: number): Model
		local character = made(Instance.new("Model"))
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2, 2, 1)
		root.CFrame = CFrame.new(10, 8, 5)
		root.Anchored = true
		root.Parent = character
		local humanoid = Instance.new("Humanoid")
		humanoid.HipHeight = hipHeight
		humanoid.Parent = character
		return character
	end

	it("is nil without a character", function()
		expect(Footprints.feetOf(nil)).toBeNil()
	end)

	it("is nil for a character without a root part", function()
		local character = made(Instance.new("Model"))
		expect(Footprints.feetOf(character)).toBeNil()
	end)

	it("is the point on the ground under the root part: half its height plus the hip height below it", function()
		local feet = Footprints.feetOf(newCharacter(2))
		expect(feet).never.toBeNil()
		-- 8 - 1 (half the root part) - 2 (the legs) = 5.
		expectNear(feet :: Vector3, Vector3.new(10, 5, 5))
	end)

	it("is nil for a character that has died", function()
		local character = newCharacter(2)
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.Health = 0
		expect(Footprints.feetOf(character)).toBeNil()
	end)
end)

describe("Footprints.workspaceGround", function()
	local function newFloor(topY: number): Part
		local floor = made(Instance.new("Part"))
		floor.Anchored = true
		floor.Size = Vector3.new(40, 2, 40)
		floor.CFrame = CFrame.new(1000, topY - 1, 1000)
		floor.Parent = Workspace
		return floor
	end

	local noPlayers = {
		GetPlayers = function(_self: any)
			return {}
		end,
	}

	it("finds the ground under a position, with its slope", function()
		newFloor(0)
		local ground = Footprints.workspaceGround(Workspace, noPlayers)
		local hit, normal = ground(Vector3.new(1000, 0, 1000), made(Instance.new("Folder")))
		expect(hit).never.toBeNil()
		expectNear(hit :: Vector3, Vector3.new(1000, 0, 1000))
		expectNear(normal :: Vector3, Vector3.new(0, 1, 0))
	end)

	it("starts 3 studs above the position, so ground a little higher than the route line is still found", function()
		newFloor(2)
		local ground = Footprints.workspaceGround(Workspace, noPlayers)
		local hit = ground(Vector3.new(1000, 0, 1000), made(Instance.new("Folder")))
		expect(hit).never.toBeNil()
		expect((hit :: Vector3).Y).toBeCloseTo(2, 3)
	end)

	it("gives the part it hit as a third value", function()
		local floor = newFloor(0)
		floor.Name = "Ramp_Walk"
		local ground = Footprints.workspaceGround(Workspace, noPlayers)
		local hit, normal, part = ground(Vector3.new(1000, 0, 1000), made(Instance.new("Folder")))
		expect(hit).never.toBeNil()
		expect(normal).never.toBeNil()
		expect(part).toBe(floor)
	end)

	it("gives no part where there is no ground", function()
		local ground = Footprints.workspaceGround(Workspace, noPlayers)
		local _hit, _normal, part = ground(Vector3.new(5000, 0, 5000), made(Instance.new("Folder")))
		expect(part).toBeNil()
	end)

	it("ignores a part that can't be collided with, such as a bush", function()
		local floor = newFloor(0)
		local bush = made(Instance.new("Part"))
		bush.Anchored = true
		bush.CanCollide = false
		bush.Size = Vector3.new(4, 2, 4)
		bush.CFrame = CFrame.new(1000, 1.5, 1000)
		bush.Parent = Workspace
		local ground = Footprints.workspaceGround(Workspace, noPlayers)
		local hit = ground(Vector3.new(1000, 0, 1000), made(Instance.new("Folder")))
		expect(hit).never.toBeNil()
		expect((hit :: Vector3).Y).toBeCloseTo(floor.Position.Y + 1, 3)
	end)

	it("ignores every player's character", function()
		newFloor(0)
		local character = made(Instance.new("Model"))
		local body = Instance.new("Part")
		body.Anchored = true
		body.Size = Vector3.new(4, 2, 4)
		body.CFrame = CFrame.new(1000, 1.5, 1000)
		body.Parent = character
		character.Parent = Workspace
		local players = {
			GetPlayers = function(_self: any)
				return { { Character = character } }
			end,
		}
		local ground = Footprints.workspaceGround(Workspace, players)
		local hit = ground(Vector3.new(1000, 0, 1000), made(Instance.new("Folder")))
		expect(hit).never.toBeNil()
		expect((hit :: Vector3).Y).toBeCloseTo(0, 3)
	end)

	it("ignores the footprints themselves", function()
		newFloor(0)
		local holder = made(Instance.new("Folder"))
		local copy = Instance.new("Part")
		copy.Anchored = true
		copy.CanQuery = true
		copy.Size = Vector3.new(1.5, 0.15, 2.7)
		copy.CFrame = CFrame.new(1000, 0.1, 1000)
		copy.Parent = holder
		holder.Parent = Workspace
		local ground = Footprints.workspaceGround(Workspace, noPlayers)
		local hit = ground(Vector3.new(1000, 0, 1000), holder)
		expect(hit).never.toBeNil()
		expect((hit :: Vector3).Y).toBeCloseTo(0, 3)
	end)

	it("gives nothing where there is no ground", function()
		local ground = Footprints.workspaceGround(Workspace, noPlayers)
		local hit, normal = ground(Vector3.new(5000, 0, 5000), made(Instance.new("Folder")))
		expect(hit).toBeNil()
		expect(normal).toBeNil()
	end)
end)

describe("Footprints.firstEgg", function()
	-- The fake route's egg spots stand where their route points are: EggSpot_Common_1 20 studs along +X, EggSpot_Common_2 40
	-- studs along -Z. (The rig makes them as empty models at the origin, so each test puts them in place.)
	local function placeSpots(rig: Rig)
		local first = rig.root:FindFirstChild("EggSpot_Common_1") :: Model?
		if first then
			first:PivotTo(CFrame.new(20, 1, 0))
		end
		local second = rig.root:FindFirstChild("EggSpot_Common_2") :: Model?
		if second then
			second:PivotTo(CFrame.new(0, 1, -40))
		end
	end

	local function asked(rig: Rig, points: { Point }?, feet: Vector3?): Vector3?
		return Footprints.firstEgg(RouteGraph.new(points or defaultPoints()), rig.root, rig.player :: any, feet)
	end

	it("is the place of the nearest waiting egg", function()
		local rig = newRig()
		placeSpots(rig)
		local egg = asked(rig, nil, Vector3.new(0, 0, 0))
		expect(egg).never.toBeNil()
		expectNear(egg :: Vector3, Vector3.new(20, 1, 0))
	end)

	it("is the other egg when the nearest one is not waiting", function()
		local rig = newRig()
		placeSpots(rig)
		rig.setWaiting("EggSpot_Common_1", false)
		local egg = asked(rig, nil, Vector3.new(0, 0, 0))
		expect(egg).never.toBeNil()
		expectNear(egg :: Vector3, Vector3.new(0, 1, -40))
	end)

	it("is nil when no egg is waiting", function()
		local rig = newRig()
		placeSpots(rig)
		rig.setWaiting("EggSpot_Common_1", false)
		rig.setWaiting("EggSpot_Common_2", false)
		expect(asked(rig, nil, Vector3.new(0, 0, 0))).toBeNil()
	end)

	it("is nil while the player carries an egg, because the trail leads home then", function()
		local rig = newRig()
		placeSpots(rig)
		rig.player:SetAttribute("Carrying", "Common")
		expect(asked(rig, nil, Vector3.new(0, 0, 0))).toBeNil()
	end)

	it("is nil for a player with no garden number", function()
		local rig = newRig({ noPlot = true })
		placeSpots(rig)
		expect(asked(rig, nil, Vector3.new(0, 0, 0))).toBeNil()
	end)

	it("is nil without feet (no character)", function()
		local rig = newRig()
		placeSpots(rig)
		expect(asked(rig, nil, nil)).toBeNil()
	end)

	it("is nil when the waiting egg has no route point", function()
		local rig = newRig({ waiting = { "EggSpot_Common_9" } })
		expect(asked(rig, nil, Vector3.new(0, 0, 0))).toBeNil()
	end)

	it("picks the egg with the shortest walk, not the nearest in a straight line, like the trail", function()
		-- The wall route of an earlier test: E1 is 20 studs away in a straight line but 80 by the route, E2 is 40.
		local points: { Point } = {
			{ name = "S", position = Vector3.new(0, 0, 0), neighbours = { "E2", "U" }, target = nil },
			{ name = "U", position = Vector3.new(0, 0, 30), neighbours = { "S", "V" }, target = nil },
			{ name = "V", position = Vector3.new(20, 0, 30), neighbours = { "U", "E1" }, target = nil },
			{ name = "E1", position = Vector3.new(20, 0, 0), neighbours = { "V" }, target = "EggSpot_Common_1" },
			{ name = "E2", position = Vector3.new(0, 0, -40), neighbours = { "S" }, target = "EggSpot_Common_2" },
		}
		local rig = newRig({ points = points })
		placeSpots(rig)
		local egg = asked(rig, points, Vector3.new(0, 0, 0))
		expect(egg).never.toBeNil()
		expectNear(egg :: Vector3, Vector3.new(0, 1, -40))
	end)

	it("is the egg the trail leads to, from several places along the route", function()
		local rig = newRig()
		placeSpots(rig)
		for _, feet in { Vector3.new(0, 0, 0), Vector3.new(15, 0, 0), Vector3.new(0, 0, -30), Vector3.new(-10, 0, 5) } do
			rig.feet.value = feet
			rig.advance(UPDATE_SECONDS)
			local egg = asked(rig, nil, feet) :: Vector3
			expect(egg).never.toBeNil()
			-- The trail lays its first footprint at the target, so one footprint stands on the egg's own spot.
			local nearest = math.huge
			for _, model in rig.shown() do
				local position = model:GetPivot().Position
				nearest = math.min(nearest, Vector2.new(position.X - egg.X, position.Z - egg.Z).Magnitude)
			end
			expect(nearest < 0.01).toBe(true)
		end
	end)
end)
