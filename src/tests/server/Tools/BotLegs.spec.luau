--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local ServerStorage = game:GetService("ServerStorage")
local Helpers = require(ServerStorage.Tests.server.World.RealWorld.Helpers)
local BotLegs = require(ServerStorage.Tools.checks.BotLegs)
local inFakeWorld = Helpers.inFakeWorld

local function box(world: WorldModel, name: string, min: Vector3, max: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = max - min
	part.CFrame = CFrame.new((min + max) / 2)
	part.Parent = world
	return part
end

-- A floor whose top is y 0, and a thin 30-stud square top over it, whose top is y 8 (x and z from -15 to 15).
local function floorAndTop(world: WorldModel)
	box(world, "Floor", Vector3.new(-40, -1, -40), Vector3.new(40, 0, 40))
	box(world, "Top", Vector3.new(-15, 7, -15), Vector3.new(15, 8, 15))
end

local AREA = { min = Vector3.new(-30, -12, -30), max = Vector3.new(30, 12, 30) }

-- A route point: a small part standing on the ground at `position`, linked to `neighbour`.
local function routePoint(route: Model, name: string, position: Vector3, neighbour: string)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = CFrame.new(position - Vector3.new(0, 0.5, 0)) -- its top centre is `position`
	part:SetAttribute("Neighbours", neighbour)
	part.Parent = route
end

-- Stuck safety Task 8 (Rule 24: A bot walks every way): the bot's legs list, worked out on made-up worlds.
describe("BotLegs.legs", function()
	it("gives an up leg and a down leg for each way up", function()
		inFakeWorld(function(world)
			box(world, "Floor", Vector3.new(-40, -1, -40), Vector3.new(40, 0, 40))
			box(world, "Ramp", Vector3.new(0, 0, -2), Vector3.new(10, 6, 2))
			local route = Instance.new("Model")
			route.Name = "Route"
			route.Parent = world
			routePoint(route, "RoutePoint_Foot", Vector3.new(0, 0, 0), "RoutePoint_Top")
			routePoint(route, "RoutePoint_Top", Vector3.new(10, 6, 0), "RoutePoint_Foot")

			local legs, missing = BotLegs.legs(world, {
				ways = { { name = "Test ramp", from = "RoutePoint_Foot", to = "RoutePoint_Top" } },
			})

			expect(missing).toEqual({})
			expect(#legs).toBe(2)
			expect(legs[1].kind).toBe("up")
			expect(legs[1].from).toEqual(Vector3.new(0, 0, 0))
			expect(legs[1].to).toEqual(Vector3.new(10, 6, 0))
			expect(legs[2].kind).toBe("down")
			expect(legs[2].from).toEqual(Vector3.new(10, 6, 0))
			expect(legs[2].to).toEqual(Vector3.new(0, 0, 0))
		end)
	end)

	it("gives a step-off every 10 studs along an edge", function()
		inFakeWorld(function(world)
			floorAndTop(world)

			local legs, missing = BotLegs.legs(world, { area = AREA })
			expect(missing).toEqual({})
			expect(#legs > 0).toBe(true)

			-- the edge at the lowest z: its legs start on the top's rim, and each ends on the floor
			local lowestZ = math.huge
			for _, leg in legs do
				expect(leg.kind).toBe("stepoff")
				expect(leg.from.Y).toBeCloseTo(8, 0)
				expect(leg.to.Y).toBeCloseTo(0, 0)
				lowestZ = math.min(lowestZ, leg.from.Z)
			end
			local along: { number } = {}
			for _, leg in legs do
				if math.abs(leg.from.Z - lowestZ) < 0.01 then
					table.insert(along, leg.from.X)
				end
			end
			table.sort(along)
			expect(#along >= 3).toBe(true)
			for index = 2, #along do
				expect(along[index] - along[index - 1]).toBeCloseTo(10, 1)
			end
		end)
	end)

	it("keeps a step-off on a lower ledge beside a higher edge", function()
		inFakeWorld(function(world)
			floorAndTop(world)
			-- a 3-stud-wide ledge whose top is y 4, one stud east of the top, so its spots sit within 10 studs of the rim
			box(world, "Ledge", Vector3.new(16, 3, -15), Vector3.new(19, 4, 15))

			-- every = 60: every start in this world is within 60 studs (flat) of the first one kept, the top's west rim, so
			-- only a height check can keep a start on the ledge (code_lead: makes the red certain)
			local legs, missing = BotLegs.legs(world, { area = AREA, every = 60 })
			expect(missing).toEqual({})

			local onLedge = 0
			for _, leg in legs do
				if math.abs(leg.from.Y - 4) < 0.5 and leg.from.X > 15.5 then
					onLedge += 1
				end
			end
			expect(onLedge > 0).toBe(true)
		end)
	end)

	it("adds the two cuff step-offs by name", function()
		inFakeWorld(function(world)
			floorAndTop(world)

			local legs, missing = BotLegs.legs(world, {
				area = AREA,
				cuffs = {
					{ name = "Cuff right 4", position = Vector3.new(14, 8, 0) },
					{ name = "Cuff left 4", position = Vector3.new(-14, 8, 0) },
					{ name = "Cuff nowhere", position = Vector3.new(100, 8, 100) },
				},
			})

			expect(missing).toEqual({ "Cuff nowhere" })
			for _, name in { "Cuff right 4", "Cuff left 4" } do
				local found: BotLegs.Leg? = nil
				for _, leg in legs do
					if leg.name == name then
						found = leg
					end
				end
				expect(found).never.toBeNil()
				local leg = found :: BotLegs.Leg
				expect(leg.kind).toBe("stepoff")
				expect(leg.to.Y).toBeCloseTo(0, 0)
			end
		end)
	end)
end)
