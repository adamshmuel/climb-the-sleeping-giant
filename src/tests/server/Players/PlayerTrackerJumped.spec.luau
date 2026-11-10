--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local SlideWatch = require(ServerScriptService.Server.Players.SlideWatch)
local TrackerRig = require(script.Parent.TrackerRig)

local START = Vector3.new(0, 10, 0)
local ACROSS = 4 -- SlideWatch's local "across" limit

-- Reads the tracker once at `seconds`, with the character in the air or on the ground.
local function tickAt(rig: TrackerRig.Rig, character: Model, seconds: number, grounded: boolean)
	rig.setGrounded(grounded)
	return TrackerRig.readAt(rig, character, seconds, START.X, START.Y)
end

describe("PlayerTracker Sample.jumped", function()
	it("is true on the take-off tick and every tick of the fall after a hop", function()
		local character = TrackerRig.makeCharacter(START)
		local rig = TrackerRig.groundSpeedRig(character)
		expect(tickAt(rig, character, 0, true).jumped).toBe(false)
		rig.setTakeoffs({ START })
		local takeoff = tickAt(rig, character, 0.1, false)
		expect(takeoff.jumped).toBe(true)
		for i = 2, 5 do
			local sample = tickAt(rig, character, i * 0.1, false)
			expect(sample.falling).toBe(true)
			expect(sample.jumped).toBe(true)
		end
		character:Destroy()
	end)

	it("is false on every tick of a fall walked off an edge", function()
		local character = TrackerRig.makeCharacter(START)
		local rig = TrackerRig.groundSpeedRig(character)
		expect(tickAt(rig, character, 0, true).jumped).toBe(false)
		local sawFalling = false
		for i = 1, 6 do
			local sample = tickAt(rig, character, i * 0.1, false)
			sawFalling = sawFalling or sample.falling
			expect(sample.jumped).toBe(false)
		end
		expect(sawFalling).toBe(true)
		character:Destroy()
	end)
end)

describe("SlideWatch.pointBelowSeam", function()
	local seam: { SlideWatch.SeamPoint } = {
		{ position = Vector3.new(0, 40, 0), down = Vector3.new(0, 0, -1) },
		{ position = Vector3.new(0, 40, -3), down = Vector3.new(0, 0, -1) },
	}

	it("agrees with belowSeam at the config match and its own across limit", function()
		local match = Config.Nests.SeamMatch
		local points = {
			Vector3.new(0, 30, -3 - match - 1), -- past the seam, in line: below
			Vector3.new(0, 30, -3 - match + 0.5), -- not past by enough
			Vector3.new(ACROSS + 2, 30, -20), -- past it but too far to the side
			Vector3.new(0, 30, 5), -- on the uphill side
		}
		local belowCount = 0
		for _, point in points do
			local expected = SlideWatch.belowSeam(point, seam, match, ACROSS)
			if expected then
				belowCount += 1
			end
			expect(SlideWatch.pointBelowSeam(point, seam)).toBe(expected)
		end
		expect(belowCount).toBe(1)
	end)
end)
