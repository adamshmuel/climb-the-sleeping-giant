--!strict
-- The snorts and the mumble (plan 7 Task 8; spec 7 Rule 91 and Rule 17): the sound places GiantFx calls at the 85
-- warning, from the nose and the mouth, and the mumble it stops at a replay or a wake.
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Net = require(game:GetService("ReplicatedStorage").Shared.Net)
local Helpers = require(script.Parent.Helpers)
local cleanUp = Helpers.cleanUp
local newRig = Helpers.newRig

afterEach(cleanUp)

type Rig = Helpers.Rig

-- The snort and mumble calls so far, as "name@seconds" (the wake sounds are left out).
local function calls(rig: Rig): { string }
	local found: { string } = {}
	for _, sound in rig.sounds do
		if string.sub(sound.name, 1, 5) == "Snort" or sound.name == "Mumble" then
			table.insert(found, `{sound.name}@{sound.time}`)
		end
	end
	return found
end

-- The mumble stops so far, as seconds.
local function mumbleStops(rig: Rig): { number }
	local found: { number } = {}
	for _, stop in rig.soundStops do
		if stop.name == "Mumble" then
			table.insert(found, stop.time)
		end
	end
	return found
end

local function nosePlace(rig: Rig): Vector3
	return ((rig.snortPuff :: ParticleEmitter).Parent :: Part).Position
end

describe("GiantFx.start: the snorts and the mumble", function()
	it("plays Snort1 at the 85, Snort2 0.5 s later and Mumble at 1.0 s, each once", function()
		local rig = newRig()
		rig.fire(85)
		expect(calls(rig)).toEqual({ "Snort1@0" })
		rig.advance(0.5)
		expect(calls(rig)).toEqual({ "Snort1@0", "Snort2@0.5" })
		rig.advance(0.25)
		expect(#calls(rig)).toBe(2)
		rig.advance(0.25)
		expect(calls(rig)).toEqual({ "Snort1@0", "Snort2@0.5", "Mumble@1" })
		rig.advance(5)
		expect(#calls(rig)).toBe(3)
	end)

	it("plays both snorts from his nose and the mumble from his mouth", function()
		local rig = newRig()
		local nose = nosePlace(rig)
		local mouth = rig.mouthParts[1].Position
		rig.fire(85)
		rig.advance(0.5)
		rig.advance(0.5)
		expect(rig.sounds[1].at).toEqual(nose)
		expect(rig.sounds[2].at).toEqual(nose)
		expect(rig.sounds[3].name).toBe("Mumble")
		expect(rig.sounds[3].at).toEqual(mouth)
	end)

	it("stops a playing mumble at a free save, and plays both snorts and the mumble again", function()
		local rig = newRig()
		rig.fire(85)
		rig.advance(0.5)
		rig.advance(0.5)
		rig.advance(0.5) -- 1.5 s: the first mumble is still playing
		rig.fire(85, Net.FreeSaveKind)
		expect(mumbleStops(rig)[#mumbleStops(rig)]).toBe(1.5)
		rig.advance(0.5)
		rig.advance(0.5)
		expect(calls(rig)).toEqual({
			"Snort1@0",
			"Snort2@0.5",
			"Mumble@1",
			"Snort1@1.5",
			"Snort2@2",
			"Mumble@2.5",
		})
	end)

	it("restarts the mumble's 1.0 s at a free save that comes before the first mumble", function()
		local rig = newRig()
		rig.fire(85)
		rig.advance(0.5)
		rig.fire(85, Net.FreeSaveKind)
		rig.advance(0.5)
		rig.advance(0.5)
		expect(calls(rig)).toEqual({ "Snort1@0", "Snort2@0.5", "Snort1@0.5", "Snort2@1", "Mumble@1.5" })
	end)

	it("starts nothing new when the meter passes 85 again while a replayed warning is showing", function()
		local rig = newRig()
		rig.fire(85)
		rig.advance(0.5)
		rig.advance(0.5)
		rig.fire(85, Net.FreeSaveKind)
		rig.setState(90, "Asleep")
		rig.advance(0.25)
		expect(calls(rig)).toEqual({ "Snort1@0", "Snort2@0.5", "Mumble@1", "Snort1@1" })
	end)

	it("plays no second snort and no mumble when he wakes 0.25 s after the 85, and stops the mumble", function()
		local rig = newRig()
		rig.fire(85)
		rig.advance(0.25)
		rig.setState(100, "Awake")
		expect(mumbleStops(rig)[#mumbleStops(rig)]).toBe(0.25)
		rig.advance(0.25)
		rig.advance(0.5)
		rig.advance(5)
		expect(calls(rig)).toEqual({ "Snort1@0" })
	end)

	it("plays no mumble after the sound hooks are stopped", function()
		local rig = newRig()
		rig.fire(85)
		rig.advance(0.5)
		rig.handle.stop()
		rig.advance(1)
		expect(calls(rig)).toEqual({ "Snort1@0", "Snort2@0.5" })
	end)

	it("plays no snort when the nose is streamed out, and still plays the mumble", function()
		local rig = newRig(nil, nil, false)
		rig.fire(85)
		rig.advance(0.5)
		rig.advance(0.5)
		expect(calls(rig)).toEqual({ "Mumble@1" })
	end)

	it("plays and stops nothing, with no error, when the sound dependencies are left out", function()
		local rig = newRig(nil, nil, nil, false)
		rig.fire(85)
		rig.advance(0.5)
		rig.advance(0.5)
		rig.setState(100, "Awake")
		expect(#rig.sounds).toBe(0)
		expect(#rig.soundStops).toBe(0)
	end)
end)
