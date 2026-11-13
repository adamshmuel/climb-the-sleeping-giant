--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Helpers = require(script.Parent.Helpers)
type Point = Helpers.Point
local SIT_HEIGHT = Helpers.SIT_HEIGHT
local UPDATE_SECONDS = Helpers.UPDATE_SECONDS
local cleanUp = Helpers.cleanUp
local expectNear = Helpers.expectNear
local newRig = Helpers.newRig
local pivotsAlong = Helpers.pivotsAlong

afterEach(cleanUp)

local SPACING = 3.6

local MAX_SHOWN = 100

local function setLocked(rig: Helpers.Rig, spotName: string, locked: boolean)
	local spot = rig.root:FindFirstChild(spotName) :: Instance
	spot:SetAttribute("Locked", locked)
end

describe("Footprints.start: the way to an egg", function()
	it("shows the way to the nearest waiting egg", function()
		local rig = newRig()
		-- E1 is 20 studs away: footprints at 20, 16.4, 12.8, 9.2, 5.6 and 2 studs along +X, toes pointing +X.
		local pivots = pivotsAlong(rig.shown(), "X", true)
		expect(#pivots).toBe(6)
		for index, pivot in pivots do
			expectNear(pivot.Position, Vector3.new(20 - (index - 1) * SPACING, SIT_HEIGHT, 0))
			expectNear(pivot.LookVector, Vector3.new(1, 0, 0))
		end
	end)

	it("leads to the nearest egg by walking distance, not the nearest in a straight line", function()
		-- A wall: E1 is 20 studs from S in a straight line, but the only way there goes 60 studs round.
		local points: { Point } = {
			{ name = "S", position = Vector3.new(0, 0, 0), neighbours = { "E2", "U" }, target = nil },
			{ name = "U", position = Vector3.new(0, 0, 30), neighbours = { "S", "V" }, target = nil },
			{ name = "V", position = Vector3.new(20, 0, 30), neighbours = { "U", "E1" }, target = nil },
			{ name = "E1", position = Vector3.new(20, 0, 0), neighbours = { "V" }, target = "EggSpot_Common_1" },
			{ name = "E2", position = Vector3.new(0, 0, -40), neighbours = { "S" }, target = "EggSpot_Common_2" },
		}
		local rig = newRig({ points = points })
		-- E2 is 40 studs away along -Z; E1 is 80 by the route.
		local pivots = pivotsAlong(rig.shown(), "Z", false)
		expectNear(pivots[1].Position, Vector3.new(0, SIT_HEIGHT, -40))
		expectNear(pivots[1].LookVector, Vector3.new(0, 0, -1))
	end)

	it("leaves out an egg that is not waiting", function()
		local rig = newRig()
		rig.setWaiting("EggSpot_Common_1", false)
		rig.advance(UPDATE_SECONDS)
		local pivots = pivotsAlong(rig.shown(), "Z", false)
		expectNear(pivots[1].Position, Vector3.new(0, SIT_HEIGHT, -40))
	end)

	it("moves on to the next egg when the first one is taken", function()
		local rig = newRig()
		expect(#rig.shown()).toBe(6)
		rig.setWaiting("EggSpot_Common_1", false)
		rig.advance(UPDATE_SECONDS)
		-- E2 is 40 studs away along -Z: footprints at 40, 36.4, ... 4 studs, toes pointing -Z.
		local pivots = pivotsAlong(rig.shown(), "Z", false)
		expect(#pivots).toBe(12)
		for index, pivot in pivots do
			expectNear(pivot.Position, Vector3.new(0, SIT_HEIGHT, -40 + (index - 1) * SPACING))
			expectNear(pivot.LookVector, Vector3.new(0, 0, -1))
		end
	end)

	-- Plan 5 Task 17, test 6: a nest whose Locked attribute is true is never a trail's target, even when it is waiting.
	it("never leads to a locked nest, and goes to the next waiting one", function()
		local rig = newRig()
		-- E1 is the nearest (20 studs along +X) but locked; E2 is 40 studs along -Z.
		setLocked(rig, "EggSpot_Common_1", true)
		rig.advance(UPDATE_SECONDS)
		local pivots = pivotsAlong(rig.shown(), "Z", false)
		expectNear(pivots[1].Position, Vector3.new(0, SIT_HEIGHT, -40))
	end)

	it("shows nothing when every waiting nest is locked, and leads to it again when it unlocks", function()
		local rig = newRig()
		setLocked(rig, "EggSpot_Common_1", true)
		setLocked(rig, "EggSpot_Common_2", true)
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown()).toBe(0)
		setLocked(rig, "EggSpot_Common_1", false)
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown()).toBe(6)
	end)

	it("goes back to an egg when it is waiting again", function()
		local rig = newRig()
		rig.setWaiting("EggSpot_Common_1", false)
		rig.advance(UPDATE_SECONDS)
		rig.setWaiting("EggSpot_Common_1", true)
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown()).toBe(6)
	end)

	it("shows nothing when no egg is waiting", function()
		local rig = newRig()
		rig.setWaiting("EggSpot_Common_1", false)
		rig.setWaiting("EggSpot_Common_2", false)
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown()).toBe(0)
	end)

	it("shows nothing when an egg spot has no route point", function()
		local rig = newRig({ waiting = { "EggSpot_Common_9" } })
		expect(#rig.shown()).toBe(0)
	end)

	it("shows nothing without a character, and shows the way again when the character is back", function()
		local rig = newRig()
		rig.feet.value = nil
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown()).toBe(0)
		rig.feet.value = Vector3.new(0, 0, 0)
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown()).toBe(6)
	end)

	it("shows nothing when the player has no garden number", function()
		local rig = newRig({ noPlot = true })
		expect(#rig.shown()).toBe(0)
	end)

	it("shows nothing at the start when there is no character yet", function()
		local rig = newRig({ noCharacter = true })
		expect(#rig.shown()).toBe(0)
		rig.feet.value = Vector3.new(0, 0, 0)
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown()).toBe(6)
	end)
end)

describe("Footprints.start: carrying an egg", function()
	it("shows the way to the player's own Safe Gate", function()
		local rig = newRig()
		rig.player:SetAttribute("Carrying", "Common")
		rig.advance(UPDATE_SECONDS)
		-- Gate_3 is 20 studs along -X.
		local pivots = pivotsAlong(rig.shown(), "X", false)
		expect(#pivots).toBe(6)
		for index, pivot in pivots do
			expectNear(pivot.Position, Vector3.new(-20 + (index - 1) * SPACING, SIT_HEIGHT, 0))
			expectNear(pivot.LookVector, Vector3.new(-1, 0, 0))
		end
	end)

	it("leads home even if no egg is waiting", function()
		local rig = newRig()
		rig.setWaiting("EggSpot_Common_1", false)
		rig.setWaiting("EggSpot_Common_2", false)
		rig.player:SetAttribute("Carrying", "Rare")
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown()).toBe(6)
	end)

	it("leads to the gate of the player's own garden, not another one", function()
		local rig = newRig()
		rig.player:SetAttribute("Carrying", "Common")
		rig.player:SetAttribute("PlotIndex", 4) -- there is no Gate_4 in the fake route
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown()).toBe(0)
	end)

	it("turns back to the eggs when the player has banked", function()
		local rig = newRig()
		rig.player:SetAttribute("Carrying", "Common")
		rig.advance(UPDATE_SECONDS)
		rig.player:SetAttribute("Carrying", nil)
		rig.advance(UPDATE_SECONDS)
		local pivots = pivotsAlong(rig.shown(), "X", true)
		expectNear(pivots[1].Position, Vector3.new(20, SIT_HEIGHT, 0))
	end)

	it("shows nothing while carrying and the garden number is missing", function()
		local rig = newRig({ noPlot = true })
		rig.player:SetAttribute("Carrying", "Common")
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown()).toBe(0)
	end)
end)

describe("Footprints.start: how often it looks again", function()
	it("works the way out again only every 0.25 seconds", function()
		local rig = newRig()
		rig.setWaiting("EggSpot_Common_1", false)
		rig.advance(0.1)
		-- Not yet: the footprints still lead to E1.
		expectNear(pivotsAlong(rig.shown(), "X", true)[1].Position, Vector3.new(20, SIT_HEIGHT, 0))
		rig.advance(0.1)
		expectNear(pivotsAlong(rig.shown(), "X", true)[1].Position, Vector3.new(20, SIT_HEIGHT, 0))
		rig.advance(0.05)
		-- 0.25 s have passed: now they lead to E2.
		expectNear(pivotsAlong(rig.shown(), "Z", false)[1].Position, Vector3.new(0, SIT_HEIGHT, -40))
	end)

	it("keeps the footprints ahead where they are while the player walks along the way", function()
		local rig = newRig()
		local before = pivotsAlong(rig.shown(), "X", true)
		rig.feet.value = Vector3.new(1, 0, 0)
		rig.advance(UPDATE_SECONDS)
		local after = pivotsAlong(rig.shown(), "X", true)
		expect(#after).toBe(#before)
		for index, pivot in before do
			expectNear(after[index].Position, pivot.Position)
		end
	end)

	it("takes away only the footprint the player has walked past", function()
		local rig = newRig()
		local before = pivotsAlong(rig.shown(), "X", true)
		-- The last footprint is at x = 2. At x = 3 the player has passed it.
		rig.feet.value = Vector3.new(3, 0, 0)
		rig.advance(UPDATE_SECONDS)
		local after = pivotsAlong(rig.shown(), "X", true)
		expect(#after).toBe(#before - 1)
		for index, pivot in after do
			expectNear(pivot.Position, before[index].Position)
		end
	end)
end)

describe("Footprints.start: the copies", function()
	it("switches off touching, bumping, being found by rays and shadows on every part, and anchors them", function()
		local rig = newRig()
		local models = rig.shown()
		expect(#models > 0).toBe(true)
		for _, model in models do
			local parts = 0
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") then
					parts += 1
					expect(descendant.CanCollide).toBe(false)
					expect(descendant.CanQuery).toBe(false)
					expect(descendant.CanTouch).toBe(false)
					expect(descendant.CastShadow).toBe(false)
					expect(descendant.Anchored).toBe(true)
				end
			end
			expect(parts).toBe(2)
		end
	end)

	it("never changes the template itself", function()
		local rig = newRig()
		local sole = rig.template:FindFirstChild("Sole") :: Part
		expect(sole.CanTouch).toBe(true)
		expect(sole.CanQuery).toBe(true)
		expect(rig.template.Parent).toBeNil()
	end)

	it("never shows more than 100 at once, and keeps the ones nearest the player", function()
		-- 500 studs from the player to the egg is 139 footprints.
		local points: { Point } = {
			{ name = "S", position = Vector3.new(0, 0, 0), neighbours = { "E1" }, target = nil },
			{ name = "E1", position = Vector3.new(500, 0, 0), neighbours = { "S" }, target = "EggSpot_Common_1" },
		}
		local rig = newRig({ points = points, waiting = { "EggSpot_Common_1" } })
		local pivots = pivotsAlong(rig.shown(), "X", false)
		expect(#pivots).toBe(MAX_SHOWN)
		-- 500 - 138 * 3.6 = 3.2 is the footprint nearest the player.
		expect(pivots[1].Position.X).toBeCloseTo(3.2, 3)
	end)

	it("reuses its copies instead of making new ones on every update", function()
		local rig = newRig()
		local seen: { [Model]: boolean } = {}
		for _, model in rig.shown() do
			seen[model] = true
		end
		-- Walk and come back several times: the same copies show again each time.
		for round = 1, 4 do
			rig.feet.value = Vector3.new(if round % 2 == 0 then 0 else 8, 0, 0)
			rig.advance(UPDATE_SECONDS)
			for _, model in rig.shown() do
				expect(seen[model]).toBe(true)
			end
		end
	end)

	it("hides a copy it does not need and shows it again later", function()
		local rig = newRig()
		rig.feet.value = Vector3.new(15, 0, 0)
		rig.advance(UPDATE_SECONDS)
		local fewer = #rig.shown()
		expect(fewer < 6).toBe(true)
		rig.feet.value = Vector3.new(0, 0, 0)
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown()).toBe(6)
	end)
end)
