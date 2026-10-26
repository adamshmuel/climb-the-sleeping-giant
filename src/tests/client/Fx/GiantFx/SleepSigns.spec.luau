--!strict
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Helpers = require(script.Parent.Helpers)
local cleanUp = Helpers.cleanUp
local made = Helpers.made
local newRig = Helpers.newRig

afterEach(cleanUp)

describe("GiantFx.start: the Z Z Z and puffs coming back", function()
	it("come back when Meter goes to 75 while he is Asleep", function()
		local rig = newRig()
		rig.fire(85)
		rig.setState(75, "Asleep")
		expect(rig.floatingZ.Enabled).toBe(true)
		expect(rig.puff.Enabled).toBe(true)
	end)

	it("stay off at a Meter of 76", function()
		local rig = newRig()
		rig.fire(85)
		rig.setState(76, "Asleep")
		expect(rig.floatingZ.Enabled).toBe(false)
		expect(rig.puff.Enabled).toBe(false)
	end)

	it("come back when Phase turns HeavySleep with Meter still at 100", function()
		local rig = newRig()
		rig.fire(85)
		rig.setState(100, "HeavySleep")
		expect(rig.floatingZ.Enabled).toBe(true)
		expect(rig.puff.Enabled).toBe(true)
	end)

	it("stay off at 75 while Phase is Awake", function()
		local rig = newRig()
		rig.fire(85)
		rig.setState(75, "Awake")
		expect(rig.floatingZ.Enabled).toBe(false)
		expect(rig.puff.Enabled).toBe(false)
	end)

	it("go off again at the next 85 after they came back", function()
		local rig = newRig()
		rig.fire(85)
		rig.setState(70, "Asleep")
		rig.fire(85)
		expect(rig.floatingZ.Enabled).toBe(false)
	end)

	it("stay off when a 60 fade ends while they are off, and come back at their normal transparencies", function()
		local rig = newRig()
		rig.fire(60)
		rig.advance(0.5)
		rig.fire(85)
		rig.advance(1.6) -- the fade is over now
		expect(rig.floatingZ.Enabled).toBe(false)
		rig.setState(70, "Asleep")
		expect(rig.floatingZ.Enabled).toBe(true)
		for index, letter in rig.letters do
			expect(letter.TextTransparency).toBe(rig.normalLetters[index])
			expect(rig.outlines[index].Transparency).toBe(0)
		end
	end)
end)

describe("GiantFx.start: streaming", function()
	it(
		"gives GiantFX, when it streams in after the 85, the off state for the Z Z Z and puffs and the bubble on",
		function()
			local rig = newRig(false)
			rig.fire(85) -- GiantFX is not on the device yet
			rig.fx.Parent = rig.world
			task.wait()
			expect(rig.floatingZ.Enabled).toBe(false)
			expect(rig.puff.Enabled).toBe(false)
			expect(rig.bubble.Enabled).toBe(true)
		end
	)

	it("gives a part added to GiantFX after the 85 the current state", function()
		local rig = newRig()
		rig.fire(85)
		-- A fresh copy of the pieces arrives from the server, switched on as it made them.
		rig.floatingZ.Enabled = true
		rig.puff.Enabled = true
		local extra = made(Instance.new("Part"))
		extra.Parent = rig.fx
		task.wait()
		expect(rig.floatingZ.Enabled).toBe(false)
		expect(rig.puff.Enabled).toBe(false)
	end)

	it("skips pieces that are not there", function()
		local rig = newRig()
		rig.snoreEmitter.Parent = nil
		(rig.bubble :: any):Destroy()
		rig.arm.Parent = nil
		rig.fire(60)
		rig.fire(85)
		rig.advance(0.25)
		rig.advance(3.1)
		expect(rig.step:count()).toBe(0)
	end)
end)

describe("GiantFx.start: a wake clears the snort cloud", function()
	it("clears the snort emitter once when he wakes 1 second after the 85", function()
		local rig = newRig()
		rig.fire(85)
		rig.advance(0.5)
		rig.advance(0.5) -- both bursts are out, and the cloud is in the air
		rig.setState(100, "Awake")
		expect(#rig.clears).toBe(1)
		expect(rig.clears[1]).toBe(rig.snortPuff)
	end)

	it("clears the snort emitter at a wake with no 85 before it (harmless)", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		expect(#rig.clears).toBe(1)
		expect(rig.clears[1]).toBe(rig.snortPuff)
	end)

	it("clears nothing, and gives no error, at a wake with no nose in the world", function()
		local rig = newRig(nil, nil, false)
		rig.fire(85)
		rig.advance(1)
		rig.setState(100, "Awake")
		expect(#rig.clears).toBe(0)
		expect(rig.awakeParts[1].Transparency).toBe(0) -- the rest of the wake still ran
	end)

	it("clears the nose that streams in later, found at the wake", function()
		local rig = newRig(nil, nil, false)
		local nose = Instance.new("Part")
		nose.Name = "SnortNose"
		nose.Parent = rig.fx
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "SnortPuff"
		emitter.Parent = nose
		rig.setState(100, "Awake")
		expect(#rig.clears).toBe(1)
		expect(rig.clears[1]).toBe(emitter)
	end)

	it("clears the first burst and never makes the second when he wakes between the two bursts", function()
		local rig = newRig()
		rig.fire(85)
		rig.advance(0.3)
		expect(#rig.bursts).toBe(1)
		rig.setState(100, "Awake")
		expect(#rig.clears).toBe(1)
		expect(rig.clears[1]).toBe(rig.snortPuff)
		rig.advance(0.5)
		rig.advance(1)
		expect(#rig.bursts).toBe(1)
		expect(#rig.clears).toBe(1)
	end)

	it("does not clear the snort while he sleeps", function()
		local rig = newRig()
		rig.fire(85)
		rig.advance(0.5)
		rig.advance(3)
		expect(#rig.clears).toBe(0)
	end)

	it("clears again at a second wake", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.setState(0, "Asleep")
		rig.fire(85)
		rig.setState(100, "Awake")
		expect(#rig.clears).toBe(2)
	end)
end)

describe("GiantFx.start: the bubble's saved first look", function()
	it("keeps no entry for a bubble that was removed from the game", function()
		local rig = newRig()
		rig.fire(85)
		expect(rig.handle.savedBubbleCount()).toBe(1)
		rig.bubble:Destroy()
		task.wait()
		expect(rig.handle.savedBubbleCount()).toBe(0)
	end)

	it("keeps no entry for a bubble that streamed out without being destroyed", function()
		local rig = newRig()
		rig.fire(85)
		expect(rig.handle.savedBubbleCount()).toBe(1)
		rig.bubble.Parent = nil
		task.wait()
		expect(rig.handle.savedBubbleCount()).toBe(0)
	end)

	it("keeps the entry of a bubble that only moves inside the world", function()
		local rig = newRig()
		rig.fire(85)
		rig.bubble.Parent = rig.fx
		task.wait()
		expect(rig.handle.savedBubbleCount()).toBe(1)
	end)

	it("saves the first look of a new bubble that streams in later, and paints it right", function()
		local rig = newRig()
		local fresh = made(rig.bubble:Clone()) -- the server's copy, as it was made (never painted)
		rig.fire(85)
		rig.bubble:Destroy()
		task.wait()
		expect(rig.handle.savedBubbleCount()).toBe(0)
		fresh.Parent = rig.snoreEmitter -- streams in while the bubble is showing
		task.wait()
		expect(rig.handle.savedBubbleCount()).toBe(1)
		expect(fresh.Enabled).toBe(true)
		rig.advance(3.0) -- 3.0 seconds into the bubble: fully there
		local words = (fresh:FindFirstChild("Frame") :: Frame):FindFirstChild("TextLabel") :: TextLabel
		expect(words.TextTransparency).toBe(0)
		rig.advance(0.15) -- half way through the fade
		expect(words.TextTransparency > 0.3 and words.TextTransparency < 0.7).toBe(true)
		rig.advance(0.2)
		expect(fresh.Enabled).toBe(false) -- it is switched off, not painted to the end (as for the first bubble)
		rig.handle.stop()
		expect(words.TextTransparency).toBe(0) -- the first look it was saved with
		expect(fresh.Size).toEqual(UDim2.fromScale(41.6, 14.4))
	end)

	it("lets go of the entries, and the watching, when it is stopped", function()
		local rig = newRig()
		rig.fire(85)
		rig.handle.stop()
		expect(rig.handle.savedBubbleCount()).toBe(0)
	end)
end)

describe("GiantFx.start: the step", function()
	it("is not connected before the first warning", function()
		local rig = newRig()
		expect(rig.step:count()).toBe(0)
	end)

	it("is connected while a warning plays and let go of when every motion has ended", function()
		local rig = newRig()
		rig.fire(60)
		expect(rig.step:count()).toBe(1)
		rig.advance(1)
		expect(rig.step:count()).toBe(1) -- the fade is still playing
		rig.advance(1)
		expect(rig.step:count()).toBe(0)
	end)

	it("stays connected for the whole 3.3 seconds of the 85 bubble, and no longer", function()
		local rig = newRig()
		rig.fire(85)
		rig.advance(1)
		rig.advance(2.2)
		expect(rig.step:count()).toBe(1)
		rig.advance(0.11)
		expect(rig.step:count()).toBe(0)
	end)

	it("is connected only once when two warnings play at the same time", function()
		local rig = newRig()
		rig.fire(60)
		rig.fire(85)
		rig.fire(60)
		expect(rig.step:count()).toBe(1)
	end)
end)

describe("GiantFx.start: stop", function()
	it("puts every piece back as it was and lets go of everything", function()
		local rig = newRig()
		rig.fire(60)
		rig.advance(0.25)
		rig.fire(85)
		rig.advance(0.25)
		rig.handle.stop()
		expect(rig.leftLid:GetPivot() == rig.leftStart).toBe(true)
		expect(rig.rightLid:GetPivot() == rig.rightStart).toBe(true)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		expect(rig.leftSliver.Transparency).toBe(1)
		expect(rig.floatingZ.Enabled).toBe(true)
		expect(rig.puff.Enabled).toBe(true)
		expect(rig.bubble.Enabled).toBe(false)
		for index, letter in rig.letters do
			expect(letter.TextTransparency).toBe(rig.normalLetters[index])
			expect(rig.outlines[index].Transparency).toBe(0)
		end
		expect(rig.step:count()).toBe(0)
		expect(rig.warning:count()).toBe(0)
	end)

	it("changes nothing on later steps or warnings", function()
		local rig = newRig()
		rig.fire(85)
		rig.handle.stop()
		rig.fire(85)
		rig.fire(60)
		rig.advance(0.25)
		rig.setState(10, "Asleep")
		expect(rig.floatingZ.Enabled).toBe(true)
		expect(rig.bubble.Enabled).toBe(false)
		expect(rig.leftLid:GetPivot() == rig.leftStart).toBe(true)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
	end)

	it("can be stopped twice without an error", function()
		local rig = newRig()
		rig.handle.stop()
		rig.handle.stop()
		expect(rig.warning:count()).toBe(0)
	end)
end)
