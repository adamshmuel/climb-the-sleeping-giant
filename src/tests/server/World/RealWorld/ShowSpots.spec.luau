--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local PlayerTracker = require(ServerScriptService.Server.Players.PlayerTracker)
local ShowSlam = require(ServerScriptService.Server.Giant.ShowSlam)
local ShowSpots = require(ServerScriptService.Server.Giant.ShowSpots)
local Slams = require(ServerScriptService.Server.Giant.Slams)
local WorldIndex = require(ServerScriptService.Server.World.WorldIndex)
local Zones = require(ServerScriptService.Server.Giant.Zones)
local Helpers = require(script.Parent.Helpers)
local realWorld = Helpers.realWorld

local MIN_SPOTS = 1000
local MIN_CANDIDATES = 10 -- spec 6 Rule 63: every garden's door has at least this many show spots in reach
local DOWN_REACH = 2 -- studs: the water check's ray looks this far under a spot

local cachedSpots: { Vector3 }? = nil

local function gardens(): { Zones.GardenBox }
	return PlayerTracker.gardenBoxes(WorldIndex.loadGardens(realWorld()))
end

local function spots(): { Vector3 }
	if cachedSpots == nil then
		cachedSpots = ShowSpots.build(Workspace, gardens(), WorldIndex.loadZones(realWorld()), {})
	end
	return cachedSpots :: { Vector3 }
end

describe("the real world, show-slam meadow spots", function()
	it("has more than 1,000 spots", function()
		expect(#spots() > MIN_SPOTS).toBe(true)
	end)

	it("has no spot in a garden, on water, on a lily pad or on the giant", function()
		local boxes = gardens()
		local giant = (realWorld() :: any).Giant :: Instance
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {}
		local first: string? = nil
		local count = #spots()
		for _, spot in spots() do
			local reason: string? = nil
			if Zones.gardenAt(spot, boxes) ~= nil then
				reason = "garden"
			else
				local hit = Workspace:Raycast(spot + Vector3.new(0, 1, 0), Vector3.new(0, -(1 + DOWN_REACH), 0), params)
				if hit ~= nil then
					if hit.Material == Enum.Material.Water then
						reason = "water"
					elseif hit.Instance.Name == "LilyPad" then
						reason = "lily pad"
					elseif hit.Instance:IsDescendantOf(giant) then
						reason = "giant"
					end
				end
			end
			if reason ~= nil and first == nil then
				first = `{reason} at {spot}`
			end
		end
		expect(`{count} spots, first bad: {first}`).toBe(`{count} spots, first bad: nil`)
	end)

	it("gives every garden's spawn spot at least 10 show-slam candidates", function()
		local world = realWorld()
		local boxes = gardens()
		local landing: { Vector3 } = {}
		for _, landingSpot in WorldIndex.loadLandingSpots(world) do
			table.insert(landing, landingSpot.position)
		end
		local face = WorldIndex.loadGiantFace(world)
		local lowest: number? = nil
		local lowestGarden = 0
		for _, garden in WorldIndex.loadGardens(world) do
			local seen = 0
			-- pickShow's own random pick is told how many candidates it has: record it and choose the first.
			local pick = function(count: number): number
				seen = count
				return 1
			end
			local position = garden.spawnSpot.Position
			local player: Slams.Player = {
				userId = 1,
				position = position,
				carrying = true,
				inGarden = false,
				floating = false,
			}
			local gates = { [1] = garden.gate:GetPivot().Position }
			ShowSlam.pickShow(spots(), { player }, { player }, gates, boxes, landing, face, pick)
			if lowest == nil or seen < lowest then
				lowest = seen
				lowestGarden = garden.index
			end
		end
		local verdict = if (lowest :: number) >= MIN_CANDIDATES then "ok" else `garden {lowestGarden} sees {lowest}`
		expect(verdict).toBe("ok")
	end)
end)
