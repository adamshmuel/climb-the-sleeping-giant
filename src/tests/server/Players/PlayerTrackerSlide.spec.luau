--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local PlayerTracker = require(ServerScriptService.Server.Players.PlayerTracker)
local TrackerRig = require(script.Parent.TrackerRig)

-- A tracker for one character with the slide fields: a "standing on the ground" switch, a clock, and a stitched-edge
-- answer the test sets by hand. `asked` counts how many times the tracker asked about the stitched edge.
type SlideRig = {
	tracker: PlayerTracker.Tracker,
	setGrounded: (grounded: boolean) -> (),
	setTime: (seconds: number) -> (),
	setStitched: (stitched: boolean) -> (),
	asked: () -> number,
}

local function slideRig(character: Model): SlideRig
	local players: { PlayerTracker.PlayerLike } = { { UserId = 1, Character = character } }
	local grounded = true
	local time = 0
	local stitched = false
	local asked = 0
	local tracker = PlayerTracker.new({
		getPlayers = function()
			return players
		end,
		zoneBoxes = TrackerRig.noZones,
		gardens = TrackerRig.noGardens,
		isGrounded = function(_character: Model): boolean
			return grounded
		end,
		takeoffs = function(_character: Model): { Vector3 }
			return {}
		end,
		now = function()
			return time
		end,
		onStitchedEdge = function(_character: Model): boolean
			asked += 1
			return stitched
		end,
	})
	return {
		tracker = tracker,
		setGrounded = function(value: boolean)
			grounded = value
		end,
		setTime = function(seconds: number)
			time = seconds
		end,
		setStitched = function(value: boolean)
			stitched = value
		end,
		asked = function()
			return asked
		end,
	}
end

describe("PlayerTracker slide fields", function()
	it("says falling after 3 air ticks, and not while on the ground", function()
		local character = TrackerRig.makeCharacter(Vector3.new(0, 50, 0))
		local rig = slideRig(character)
		expect(rig.tracker:tick()[1].falling).toBe(false)
		rig.setGrounded(false)
		local sample = rig.tracker:tick()[1]
		for _ = 1, 2 do
			sample = rig.tracker:tick()[1]
		end
		expect(sample.falling).toBe(true)
		character:Destroy()
	end)

	it("sets moveGrace on the tick after moved, and clears it on the next normal tick", function()
		local character = TrackerRig.makeCharacter(Vector3.new(0, 50, 0))
		local rig = slideRig(character)
		rig.tracker:tick()
		rig.tracker:moved(1)
		rig.setTime(10) -- past the 1.5 s grace, so this is the grace's last tick
		expect(rig.tracker:tick()[1].moveGrace).toBe(true)
		rig.setTime(11)
		expect(rig.tracker:tick()[1].moveGrace).toBe(false)
		character:Destroy()
	end)

	it("asks about the stitched edge on ground ticks and carries the answer", function()
		local character = TrackerRig.makeCharacter(Vector3.new(0, 50, 0))
		local rig = slideRig(character)
		rig.setStitched(true)
		expect(rig.tracker:tick()[1].onStitchedEdge).toBe(true)
		rig.setStitched(false)
		expect(rig.tracker:tick()[1].onStitchedEdge).toBe(false)
		expect(rig.asked()).toBe(2)
		character:Destroy()
	end)

	it("does not ask about the stitched edge on a falling tick, and says false", function()
		local character = TrackerRig.makeCharacter(Vector3.new(0, 50, 0))
		local rig = slideRig(character)
		rig.setStitched(true)
		rig.setGrounded(false)
		local sample = rig.tracker:tick()[1]
		for _ = 1, 3 do
			sample = rig.tracker:tick()[1]
		end
		local askedBefore = rig.asked()
		sample = rig.tracker:tick()[1]
		expect(sample.falling).toBe(true)
		expect(sample.onStitchedEdge).toBe(false)
		expect(rig.asked()).toBe(askedBefore)
		character:Destroy()
	end)
end)

describe("PlayerTracker.onStitchedEdgeByRay", function()
	local function answerOver(marked: boolean): boolean
		local character = TrackerRig.makeCharacter(Vector3.new(5000, 100, 5000))
		local floor = Instance.new("Part")
		floor.Anchored = true
		floor.Size = Vector3.new(6, 1, 6)
		floor.Position = Vector3.new(5000, 99, 5000)
		if marked then
			floor:SetAttribute("StitchedEdge", true)
		end
		floor.Parent = workspace
		local answer = PlayerTracker.onStitchedEdgeByRay(character)
		floor:Destroy()
		character:Destroy()
		return answer
	end

	it("answers true over a part marked StitchedEdge", function()
		expect(answerOver(true)).toBe(true)
	end)

	it("answers false over an unmarked part", function()
		expect(answerOver(false)).toBe(false)
	end)
end)
