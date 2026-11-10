--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Client = StarterPlayer.StarterPlayerScripts.Client
local SpotLabels = require(Client.World.SpotLabels)
local Helpers = require(script.Parent.Helpers)
local addEgg = Helpers.addEgg
local cleanUp = Helpers.cleanUp
local newRig = Helpers.newRig
local newScreen = Helpers.newScreen
local outlineSeeThrough = Helpers.outlineSeeThrough
local overlappingRares = Helpers.overlappingRares
local rect = Helpers.rect
local seeThrough = Helpers.seeThrough

afterEach(cleanUp)

local function candidate(id: number, area: SpotLabels.Rect, distance: number): SpotLabels.Candidate
	return { id = id, rect = area, distance = distance }
end

-- Where the labels are placed in these tests: well below the top edge, with no meter unless a test gives one.
local NEAR = 10

local MIDDLE = 20

local FAR = 30

describe("SpotLabels.pickShown: labels never stack", function()
	it("shows only the nearer of two overlapping labels", function()
		local shown = SpotLabels.pickShown({
			candidate(1, rect(100, 100, 60, 20), FAR),
			candidate(2, rect(130, 105, 60, 20), NEAR),
		}, nil)
		expect(shown[2]).toBe(true)
		expect(shown[1]).toBe(false)
	end)

	it("shows both labels when they do not overlap", function()
		local shown = SpotLabels.pickShown({
			candidate(1, rect(100, 100, 60, 20), NEAR),
			candidate(2, rect(200, 100, 60, 20), FAR),
		}, nil)
		expect(shown[1]).toBe(true)
		expect(shown[2]).toBe(true)
	end)

	it("shows both labels when they only touch edge to edge, side by side", function()
		local shown = SpotLabels.pickShown({
			candidate(1, rect(100, 100, 60, 20), NEAR),
			candidate(2, rect(160, 100, 60, 20), FAR),
		}, nil)
		expect(shown[1]).toBe(true)
		expect(shown[2]).toBe(true)
	end)

	it("shows both labels when they only touch edge to edge, one above the other", function()
		local shown = SpotLabels.pickShown({
			candidate(1, rect(100, 100, 60, 20), NEAR),
			candidate(2, rect(100, 120, 60, 20), FAR),
		}, nil)
		expect(shown[1]).toBe(true)
		expect(shown[2]).toBe(true)
	end)

	it("in a row where only neighbours overlap, shows the nearest and the farthest", function()
		local shown = SpotLabels.pickShown({
			candidate(1, rect(100, 100, 60, 20), NEAR),
			candidate(2, rect(140, 100, 60, 20), MIDDLE),
			candidate(3, rect(180, 100, 60, 20), FAR),
		}, nil)
		expect(shown[1]).toBe(true)
		expect(shown[2]).toBe(false)
		expect(shown[3]).toBe(true)
	end)

	it("gives the same answer when the list comes in another order", function()
		local one = candidate(1, rect(100, 100, 60, 20), NEAR)
		local two = candidate(2, rect(140, 100, 60, 20), MIDDLE)
		local three = candidate(3, rect(180, 100, 60, 20), FAR)
		local forward = SpotLabels.pickShown({ one, two, three }, nil)
		local backward = SpotLabels.pickShown({ three, two, one }, nil)
		local shuffled = SpotLabels.pickShown({ two, three, one }, nil)
		for id = 1, 3 do
			expect(backward[id]).toBe(forward[id])
			expect(shuffled[id]).toBe(forward[id])
		end
	end)

	it("picks the same one of two labels at the same distance, whatever the order", function()
		local one = candidate(1, rect(100, 100, 60, 20), NEAR)
		local two = candidate(2, rect(130, 100, 60, 20), NEAR)
		local forward = SpotLabels.pickShown({ one, two }, nil)
		local backward = SpotLabels.pickShown({ two, one }, nil)
		expect(forward[1]).toBe(true)
		expect(forward[2]).toBe(false)
		expect(backward[1]).toBe(true)
		expect(backward[2]).toBe(false)
	end)

	it("answers for every label it was given, and for none when given none", function()
		local shown = SpotLabels.pickShown({ candidate(7, rect(100, 100, 60, 20), NEAR) }, nil)
		expect(shown[7]).toBe(true)
		expect(next(SpotLabels.pickShown({}, nil))).toBeNil()
	end)
end)

describe("SpotLabels.pickShown: labels never sit under the meter", function()
	local meter = rect(500, 16, 400, 54) -- 500 to 900 across, 16 to 70 down

	it("hides a label that overlaps the meter's box", function()
		local shown = SpotLabels.pickShown({ candidate(1, rect(480, 50, 60, 20), NEAR) }, meter)
		expect(shown[1]).toBe(false)
	end)

	it("hides a label that only touches the meter's box edge to edge", function()
		local shown = SpotLabels.pickShown({
			candidate(1, rect(440, 30, 60, 20), NEAR), -- its right edge is the meter's left edge
			candidate(2, rect(600, 70, 60, 20), NEAR), -- its top edge is the meter's bottom edge
		}, meter)
		expect(shown[1]).toBe(false)
		expect(shown[2]).toBe(false)
	end)

	it("shows a label that is clear of the meter's box", function()
		local shown = SpotLabels.pickShown({
			candidate(1, rect(300, 30, 60, 20), NEAR), -- to the left
			candidate(2, rect(600, 100, 60, 20), NEAR), -- below
		}, meter)
		expect(shown[1]).toBe(true)
		expect(shown[2]).toBe(true)
	end)

	it("hides a label that reaches past the top edge of the screen", function()
		local shown = SpotLabels.pickShown({
			candidate(1, rect(100, -1, 60, 20), NEAR),
			candidate(2, rect(200, 0, 60, 20), NEAR), -- exactly at the edge is still on the screen
		}, nil)
		expect(shown[1]).toBe(false)
		expect(shown[2]).toBe(true)
	end)

	it("with no meter, only the top edge counts", function()
		local shown = SpotLabels.pickShown({
			candidate(1, rect(600, 30, 60, 20), NEAR), -- where the meter would be
			candidate(2, rect(100, -5, 60, 20), NEAR),
		}, nil)
		expect(shown[1]).toBe(true)
		expect(shown[2]).toBe(false)
	end)

	it("lets a label hidden by the meter step aside for a farther label that overlaps it", function()
		local shown = SpotLabels.pickShown({
			candidate(1, rect(470, 50, 60, 20), NEAR), -- under the meter (500 to 900 across)
			candidate(2, rect(440, 55, 50, 20), FAR), -- overlaps label 1, but ends at 490, clear of the meter
		}, meter)
		expect(shown[1]).toBe(false)
		expect(shown[2]).toBe(true)
	end)

	it("lets a label hidden by the top edge step aside for a farther label that overlaps it", function()
		local shown = SpotLabels.pickShown({
			candidate(1, rect(100, -5, 60, 20), NEAR),
			candidate(2, rect(120, 10, 60, 20), FAR),
		}, nil)
		expect(shown[1]).toBe(false)
		expect(shown[2]).toBe(true)
	end)
end)

describe("SpotLabels.wordsRect", function()
	it("centres the words on the billboard when the label fills it", function()
		local words =
			SpotLabels.wordsRect(Vector2.new(400, 300), Vector2.new(100, 30), Vector2.new(100, 30), Vector2.new(60, 20))
		expect(words.width).toBe(60)
		expect(words.height).toBe(20)
		expect(words.x).toBe(370)
		expect(words.y).toBe(290)
	end)

	it("keeps the label's bottom edge on the billboard's bottom edge when the label is capped smaller", function()
		-- billboard 160 x 50 around (400, 300): bottom at 325. The label is capped to 130 x 36, so it spans 289 to 325.
		local words = SpotLabels.wordsRect(
			Vector2.new(400, 300),
			Vector2.new(160, 50),
			Vector2.new(130, 36),
			Vector2.new(130, 36)
		)
		expect(words.x).toBe(335)
		expect(words.y).toBe(289)
		expect(words.width).toBe(130)
		expect(words.height).toBe(36)
	end)

	it("uses the drawn words, not the whole label, when the words are narrower", function()
		local words =
			SpotLabels.wordsRect(Vector2.new(400, 300), Vector2.new(160, 50), Vector2.new(130, 36), Vector2.new(65, 36))
		expect(words.x).toBe(367.5)
		expect(words.width).toBe(65)
	end)

	it("never lets the words reach outside the label", function()
		local words = SpotLabels.wordsRect(
			Vector2.new(400, 300),
			Vector2.new(100, 30),
			Vector2.new(100, 30),
			Vector2.new(140, 50)
		)
		expect(words.width).toBe(100)
		expect(words.height).toBe(30)
	end)
end)

describe("SpotLabels: two overlapping labels", function()
	it("fades the farther label to fully see-through over 0.15 s, words and outline together", function()
		local screen = newScreen()
		local rig, near, far = overlappingRares(screen)
		rig.advance(0.075)
		expect(seeThrough(rig, far)).toBeCloseTo(0.5, 3)
		expect(outlineSeeThrough(rig, far)).toBeCloseTo(0.5, 3)
		rig.advance(0.075)
		expect(seeThrough(rig, far)).toBeCloseTo(1, 3)
		expect(outlineSeeThrough(rig, far)).toBeCloseTo(1, 3)
		expect(seeThrough(rig, near)).toBe(0)
		expect(outlineSeeThrough(rig, near)).toBe(0)
	end)

	it("brings the label back over 0.15 s once they no longer overlap", function()
		local screen = newScreen()
		local rig, near, far = overlappingRares(screen)
		rig.advance(0.075)
		rig.advance(0.075)
		expect(seeThrough(rig, far)).toBeCloseTo(1, 3)
		-- the player walks on: the two labels separate
		screen.places["EggSpot_Rare_2"] = { rect = rect(500, 210, 80, 30), distance = 20 }
		rig.advance(0.075)
		-- the next check comes at 0.1 s after the last one, which was at the very first step
		rig.advance(0.075)
		expect(seeThrough(rig, far) < 1).toBe(true)
		rig.advance(0.075)
		rig.advance(0.075)
		expect(seeThrough(rig, far)).toBeCloseTo(0, 3)
		expect(outlineSeeThrough(rig, far)).toBeCloseTo(0, 3)
		expect(seeThrough(rig, near)).toBe(0)
	end)

	it("takes exactly 0.15 s to come back: half see-through after 0.075 s of coming back", function()
		local screen = newScreen()
		local rig, _near, far = overlappingRares(screen)
		rig.advance(0.075)
		rig.advance(0.075)
		screen.places["EggSpot_Rare_2"] = { rect = rect(500, 210, 80, 30), distance = 20 }
		rig.advance(0.075) -- a check comes: they have separated, and the fade back starts
		expect(seeThrough(rig, far)).toBeCloseTo(0.5, 3)
		rig.advance(0.075)
		expect(seeThrough(rig, far)).toBeCloseTo(0, 3)
	end)

	it("never touches the eggs themselves", function()
		local screen = newScreen()
		local rig = newRig(screen.view)
		local near = rig.addSpot("EggSpot_Rare_1", "Rare")
		local far = rig.addSpot("EggSpot_Rare_2", "Rare")
		addEgg(near, 7)
		addEgg(far, 7)
		screen.places["EggSpot_Rare_1"] = { rect = rect(300, 200, 80, 30), distance = 10 }
		screen.places["EggSpot_Rare_2"] = { rect = rect(330, 210, 80, 30), distance = 20 }
		rig.set(near, "Waiting", true)
		rig.set(far, "Waiting", true)
		rig.advance(0.2)
		rig.advance(0.2)
		for _, spot in { near, far } do
			for _, descendant in spot:GetDescendants() do
				if descendant:IsA("BasePart") then
					expect(descendant.Transparency).toBe(0)
					expect(descendant.LocalTransparencyModifier).toBe(0)
				end
			end
		end
		expect(seeThrough(rig, far)).toBeCloseTo(1, 3)
	end)

	it("leaves labels alone that only sit close together", function()
		local screen = newScreen()
		local rig = newRig(screen.view)
		local one = rig.addSpot("EggSpot_Common_3", "Common")
		local two = rig.addSpot("EggSpot_Common_4", "Common")
		screen.places["EggSpot_Common_3"] = { rect = rect(300, 200, 60, 20), distance = 10 }
		screen.places["EggSpot_Common_4"] = { rect = rect(362, 200, 60, 20), distance = 12 }
		rig.set(one, "Waiting", true)
		rig.set(two, "Waiting", true)
		rig.advance(0.3)
		expect(seeThrough(rig, one)).toBe(0)
		expect(seeThrough(rig, two)).toBe(0)
	end)

	it("does not count a label that is behind the camera or past 75 studs", function()
		local screen = newScreen()
		local rig = newRig(screen.view)
		local near = rig.addSpot("EggSpot_Rare_1", "Rare")
		local far = rig.addSpot("EggSpot_Rare_2", "Rare")
		-- the near spot has no place this moment (the screen couldn't measure it), the far one has
		screen.places["EggSpot_Rare_2"] = { rect = rect(330, 210, 80, 30), distance = 20 }
		rig.set(near, "Waiting", true)
		rig.set(far, "Waiting", true)
		rig.advance(0.3)
		expect(seeThrough(rig, near)).toBe(0)
		expect(seeThrough(rig, far)).toBe(0)
	end)
end)

describe("SpotLabels: where the screen is told the label is", function()
	it("is the label's intended world spot: straight above the egg's tip on a tilted spot", function()
		-- The screen is told the point Roblox draws the label at. On a tilted spot that must be the spot the label was
		-- meant for (straight above the egg's tip), so the rectangle matches the drawn words.
		local screen = newScreen()
		local rig = newRig(screen.view)
		local tilted = CFrame.new(0, 10, 0) * CFrame.Angles(0, 0, -math.pi / 2) -- the Base's up points along +X
		local spot = rig.addSpot("EggSpot_Rare_1", "Rare", tilted)
		addEgg(spot, 4)
		screen.places["EggSpot_Rare_1"] = { rect = rect(300, 200, 80, 30), distance = 10 }
		rig.set(spot, "Waiting", true)
		rig.advance(0.1)
		local gui = rig.labelOf(spot) :: BillboardGui
		local base = gui.Adornee :: BasePart
		local tip = (tilted * CFrame.new(0, 0.1, 0)).Position + tilted.UpVector * 4
		-- the word's bottom is WORD_BOTTOM_STUDS (8) above the base top, or GAP_ABOVE_EGG (1) over the egg when taller
		-- (SpotLabels.offsetFor); this egg is 4 tall, so the gap over its tip is 8 - 4
		local gap = math.max(1, 8 - 4)
		local intended = tip + Vector3.new(0, gap + gui.Size.Y.Scale / 2, 0)
		local told = screen.centres["EggSpot_Rare_1"]
		expect(told.X).toBeCloseTo(intended.X, 3)
		expect(told.Y).toBeCloseTo(intended.Y, 3)
		expect(told.Z).toBeCloseTo(intended.Z, 3)
		expect(told).never.toEqual(base.Position + gui.StudsOffsetWorldSpace)
	end)

	it("is the plain offset on a Base that stands straight", function()
		local screen = newScreen()
		local rig = newRig(screen.view)
		local spot = rig.addSpot("EggSpot_Common_1", "Common", CFrame.new(0, 10, 0))
		screen.places["EggSpot_Common_1"] = { rect = rect(300, 200, 80, 30), distance = 10 }
		rig.set(spot, "Waiting", true)
		rig.advance(0.1)
		local gui = rig.labelOf(spot) :: BillboardGui
		expect(screen.centres["EggSpot_Common_1"]).toEqual(
			(gui.Adornee :: BasePart).Position + gui.StudsOffsetWorldSpace
		)
	end)
end)
