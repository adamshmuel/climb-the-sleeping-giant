--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Footprints = require(StarterPlayer.StarterPlayerScripts.Client.World.Footprints)
local Helpers = require(script.Parent.Helpers)
type Rig = Helpers.Rig
local SIT_HEIGHT = Helpers.SIT_HEIGHT
local UPDATE_SECONDS = Helpers.UPDATE_SECONDS
local cleanUp = Helpers.cleanUp
local defaultPoints = Helpers.defaultPoints
local expectNear = Helpers.expectNear
local newRig = Helpers.newRig
local newSignal = Helpers.newSignal
local pivotsAlong = Helpers.pivotsAlong
local stops = Helpers.stops

afterEach(cleanUp)

-- The Transparency of every part of every footprint that shows now.
local function shownTransparencies(rig: Rig): { number }
	local values: { number } = {}
	for _, model in rig.shown() do
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(values, descendant.Transparency)
			end
		end
	end
	return values
end

-- Every part of every footprint that shows now has this Transparency (and there is at least one).
local function expectAllTransparency(rig: Rig, expected: number)
	local values = shownTransparencies(rig)
	expect(#values > 0).toBe(true)
	for _, value in values do
		expect(value).toBeCloseTo(expected, 3)
	end
end

describe("Footprints.start: hiding during a bounce", function()
	it("hide makes every footprint fully see-through at once", function()
		local rig = newRig()
		expect(#rig.shown()).toBe(6)
		expectAllTransparency(rig, 0)
		rig.handle.hide()
		expect(#rig.shown()).toBe(6) -- still laid on the way, just not to be seen
		expectAllTransparency(rig, 1)
	end)

	it("footprints laid while hidden are hidden too", function()
		-- No character yet, so no copy has been made.
		local rig = newRig({ noCharacter = true })
		rig.handle.hide()
		rig.feet.value = Vector3.new(0, 0, 0)
		rig.advance(UPDATE_SECONDS) -- 6 new copies are laid
		expect(#rig.shown()).toBe(6)
		expectAllTransparency(rig, 1)
		-- Copies the pool takes out of sight and shows again are hidden too.
		rig.feet.value = Vector3.new(15, 0, 0)
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown() < 6).toBe(true)
		rig.feet.value = Vector3.new(0, 0, 0)
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown()).toBe(6)
		expectAllTransparency(rig, 1)
	end)

	it("keeps working out the way while hidden, so the trail is right when it comes back", function()
		local rig = newRig()
		rig.handle.hide()
		rig.setWaiting("EggSpot_Common_1", false)
		rig.advance(UPDATE_SECONDS)
		-- E2 is 40 studs along -Z now: 12 footprints.
		expect(#rig.shown()).toBe(12)
		rig.handle.show()
		expectAllTransparency(rig, 0)
		local pivots = pivotsAlong(rig.shown(), "Z", false)
		expectNear(pivots[1].Position, Vector3.new(0, SIT_HEIGHT, -40))
	end)

	it(
		"fadeIn brings them back evenly: half see-through at half the time, normal at the end, and never past it",
		function()
			local rig = newRig()
			rig.handle.hide()
			rig.handle.fadeIn(0.6)
			expectAllTransparency(rig, 1)
			rig.advance(0.15)
			expectAllTransparency(rig, 0.75)
			rig.advance(0.15) -- 0.3 s of 0.6
			expectAllTransparency(rig, 0.5)
			rig.advance(0.3) -- 0.6 s
			expectAllTransparency(rig, 0)
			rig.advance(0.4) -- 1.0 s
			expectAllTransparency(rig, 0)
			rig.advance(5)
			expectAllTransparency(rig, 0)
		end
	)

	it("copies laid during a fade match the fade", function()
		-- No character yet, so no copy has been made: the copies laid during the fade are all new.
		local rig = newRig({ noCharacter = true })
		rig.handle.hide()
		rig.handle.fadeIn(1.2)
		rig.feet.value = Vector3.new(0, 0, 0)
		rig.advance(UPDATE_SECONDS) -- 0.25 of 1.2 s
		expect(#rig.shown()).toBe(6)
		expectAllTransparency(rig, 1 - UPDATE_SECONDS / 1.2)
		-- Copies the pool takes out of sight and shows again during the fade match it too.
		rig.feet.value = Vector3.new(15, 0, 0)
		rig.advance(UPDATE_SECONDS) -- 0.5 s
		expect(#rig.shown() < 6).toBe(true)
		rig.feet.value = Vector3.new(0, 0, 0)
		rig.advance(UPDATE_SECONDS) -- 0.75 s
		expect(#rig.shown()).toBe(6)
		expectAllTransparency(rig, 1 - 0.75 / 1.2)
	end)

	it("the fade ends on each part's own see-through", function()
		local rig = newRig({ soleTransparency = 0.2 })
		rig.handle.hide()
		rig.handle.fadeIn(0.6)
		rig.advance(0.3)
		for _, model in rig.shown() do
			-- Halfway between its own 0.2 and 1 is 0.6; the toe goes from 0 to 1, so 0.5.
			expect((model:FindFirstChild("Sole") :: Part).Transparency).toBeCloseTo(0.6, 3)
			expect((model:FindFirstChild("Toe1") :: Part).Transparency).toBeCloseTo(0.5, 3)
		end
		rig.advance(0.3)
		for _, model in rig.shown() do
			expect((model:FindFirstChild("Sole") :: Part).Transparency).toBeCloseTo(0.2, 3)
			expect((model:FindFirstChild("Toe1") :: Part).Transparency).toBeCloseTo(0, 3)
		end
		rig.advance(1)
		for _, model in rig.shown() do
			expect((model:FindFirstChild("Sole") :: Part).Transparency).toBeCloseTo(0.2, 3)
		end
	end)

	it("show brings them back at once, and hide during a fade hides at once", function()
		local rig = newRig()
		rig.handle.hide()
		rig.handle.show()
		expectAllTransparency(rig, 0)

		-- show during a fade ends the fade
		rig.handle.hide()
		rig.handle.fadeIn(0.6)
		rig.advance(0.3)
		expectAllTransparency(rig, 0.5)
		rig.handle.show()
		expectAllTransparency(rig, 0)
		rig.advance(0.1)
		expectAllTransparency(rig, 0)

		-- hide during a fade stops the fade
		rig.handle.hide()
		rig.handle.fadeIn(0.6)
		rig.advance(0.3)
		rig.handle.hide()
		expectAllTransparency(rig, 1)
		rig.advance(0.5)
		expectAllTransparency(rig, 1)
	end)

	it("fadeIn while already shown changes nothing", function()
		local rig = newRig()
		rig.handle.fadeIn(0.6)
		expectAllTransparency(rig, 0)
		rig.advance(0.3)
		expectAllTransparency(rig, 0)
	end)

	it("a second fadeIn during a fade does not jump back to hidden", function()
		local rig = newRig()
		rig.handle.hide()
		rig.handle.fadeIn(0.6)
		rig.advance(0.3)
		rig.handle.fadeIn(0.6)
		rig.advance(0.1)
		expectAllTransparency(rig, 1 - 0.4 / 0.6) -- the first fade carries on
	end)

	it("hiding never changes the template", function()
		local rig = newRig({ soleTransparency = 0.2 })
		rig.handle.hide()
		rig.handle.fadeIn(0.6)
		rig.advance(0.3)
		expect((rig.template:FindFirstChild("Sole") :: Part).Transparency).toBeCloseTo(0.2, 3)
		expect((rig.template:FindFirstChild("Toe1") :: Part).Transparency).toBeCloseTo(0, 3)
		rig.handle.hide()
		expect((rig.template:FindFirstChild("Sole") :: Part).Transparency).toBeCloseTo(0.2, 3)
		expect(rig.template.Parent).toBeNil()
	end)

	it("does nothing, and does not error, after stop", function()
		local rig = newRig()
		rig.handle.stop()
		rig.handle.hide()
		rig.handle.fadeIn(0.6)
		rig.handle.show()
		rig.advance(UPDATE_SECONDS)
		expect(rig.folder()).toBeNil()
	end)
end)

describe("Footprints.start: stopping", function()
	it("destroys every copy and the holder, hidden ones too, and disconnects", function()
		local rig = newRig()
		local everyone: { Model } = {}
		for _, model in rig.shown() do
			table.insert(everyone, model)
		end
		-- Some copies are hidden by now.
		rig.feet.value = Vector3.new(15, 0, 0)
		rig.advance(UPDATE_SECONDS)
		expect(#rig.shown() < #everyone).toBe(true)
		local holder = rig.folder() :: Folder

		expect(rig.step:count()).toBe(1)
		rig.handle.stop()

		expect(rig.step:count()).toBe(0)
		expect(rig.folder()).toBeNil()
		expect(holder.Parent).toBeNil()
		for _, model in everyone do
			-- A destroyed instance has its parent locked.
			local ok = pcall(function()
				model.Parent = rig.parent
			end)
			expect(ok).toBe(false)
		end
	end)

	it("does nothing on later steps and can be stopped twice", function()
		local rig = newRig()
		rig.handle.stop()
		rig.advance(UPDATE_SECONDS)
		rig.handle.stop()
		expect(rig.folder()).toBeNil()
	end)

	it("makes no second holder when started again on the same parent", function()
		local rig = newRig()
		local second = Footprints.start({
			points = defaultPoints(),
			root = rig.root,
			player = {
				GetAttribute = function(_self: any, name: string): any
					return rig.player:GetAttribute(name)
				end,
			},
			feet = function()
				return Vector3.new(0, 0, 0)
			end,
			ground = function(position: Vector3, _ignore: Instance)
				return position, Vector3.new(0, 1, 0)
			end,
			template = rig.template,
			parent = rig.parent,
			step = newSignal(),
			now = function()
				return 0
			end,
		})
		table.insert(stops, second.stop)
		local holders = 0
		for _, child in rig.parent:GetChildren() do
			if child.Name == "Footprints" then
				holders += 1
			end
		end
		expect(holders).toBe(1)
	end)
end)
