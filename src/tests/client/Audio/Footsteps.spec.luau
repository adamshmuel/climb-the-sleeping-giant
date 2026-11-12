--!strict
-- Tiptoe is quiet (plan 7 Task 14; spec 7 Rule 9 "Tiptoe is quiet", Rule 96 "Your own noise is heard", section 8).
-- Silent: the character is a fake model with real AudioPlayers that have no file, so nothing is ever heard. Roblox's
-- footstep sounds are AudioPlayers named Running and Climbing under HumanoidRootPart (Task 14, Step 1), so the clips
-- sit under a HumanoidRootPart here, never straight under the character.
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Footsteps = require(StarterPlayer.StarterPlayerScripts.Client.Audio.Footsteps)

local PRECISION = 3 -- AudioPlayer.Volume is a 32-bit number, so volumes compare to about 0.001
local FOOTSTEP_VOLUME = 0.65 -- what Roblox gives its footsteps (Step 1)
local QUARTER = FOOTSTEP_VOLUME * 0.25

type Clips = { running: AudioPlayer, climbing: AudioPlayer, jumping: AudioPlayer }
type Rig = {
	player: Footsteps.PlayerLike,
	character: Model,
	clips: Clips,
	clicks: { number }, -- one entry per playClick call
	handle: Footsteps.Handle,
	setTiptoe: (value: boolean) -> (),
	setOtherTiptoe: (value: boolean) -> (),
	giveCharacter: (self: Rig) -> (Model, Clips), -- a new character: set on the player, CharacterAdded fired
}

local madeInstances: { Instance } = {}
local handles: { Footsteps.Handle } = {}

local function made<T>(instance: T): T
	table.insert(madeInstances, instance :: any)
	return instance
end

afterEach(function()
	for _, handle in handles do
		handle.destroy()
	end
	table.clear(handles)
	for _, instance in madeInstances do
		instance:Destroy()
	end
	table.clear(madeInstances)
end)

local function newClip(parent: Instance, name: string, volume: number): AudioPlayer
	local clip = Instance.new("AudioPlayer")
	clip.Name = name
	clip.Volume = volume
	clip.Parent = parent
	return clip
end

-- A fake character: a Model holding a HumanoidRootPart that holds the three clips.
local function newCharacter(runningVolume: number?, climbingVolume: number?): (Model, Clips)
	local character = made(Instance.new("Model"))
	character.Name = "FakeCharacter"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Parent = character
	local clips: Clips = {
		running = newClip(root, "Running", runningVolume or FOOTSTEP_VOLUME),
		climbing = newClip(root, "Climbing", climbingVolume or FOOTSTEP_VOLUME),
		jumping = newClip(root, "Jumping", FOOTSTEP_VOLUME),
	}
	return character, clips
end

local function settle()
	task.wait() -- attribute changes and new children reach listeners a moment after they happen
end

-- Starts Footsteps on a fake player. `startOn` sets Tiptoe before the start, as when a player joins with it on.
local function newRig(startOn: boolean?, runningVolume: number?, climbingVolume: number?): Rig
	local character, clips = newCharacter(runningVolume, climbingVolume)
	local attributes = made(Instance.new("Folder"))
	local other = made(Instance.new("Folder")) -- another player's attributes: Footsteps is never given them
	local characterAdded = made(Instance.new("BindableEvent"))
	if startOn then
		attributes:SetAttribute("Tiptoe", true)
	end
	local clicks: { number } = {}
	local player: Footsteps.PlayerLike = {
		Character = character,
		CharacterAdded = characterAdded.Event,
		GetAttribute = function(_self: any, name: string): any
			return attributes:GetAttribute(name)
		end,
		GetAttributeChangedSignal = function(_self: any, name: string): RBXScriptSignal
			return attributes:GetAttributeChangedSignal(name)
		end,
	}
	local handle = Footsteps.start({
		player = player,
		names = { "Running", "Climbing" },
		playClick = function()
			table.insert(clicks, #clicks + 1)
		end,
	})
	table.insert(handles, handle)
	settle()
	local rig: Rig
	rig = {
		player = player,
		character = character,
		clips = clips,
		clicks = clicks,
		handle = handle,
		setTiptoe = function(value: boolean)
			attributes:SetAttribute("Tiptoe", value)
			settle()
		end,
		setOtherTiptoe = function(value: boolean)
			other:SetAttribute("Tiptoe", value)
			settle()
		end,
		giveCharacter = function(_self: Rig): (Model, Clips)
			local newOne, newClips = newCharacter()
			player.Character = newOne
			characterAdded:Fire(newOne)
			settle()
			return newOne, newClips
		end,
	}
	return rig
end

describe("Footsteps while Tiptoe is on", function()
	it("plays Running and Climbing at a quarter and leaves Jumping alone", function()
		local rig = newRig()
		rig.setTiptoe(true)
		expect(rig.clips.running.Volume).toBeCloseTo(QUARTER, PRECISION)
		expect(rig.clips.climbing.Volume).toBeCloseTo(QUARTER, PRECISION)
		expect(rig.clips.jumping.Volume).toBeCloseTo(FOOTSTEP_VOLUME, PRECISION)
	end)

	it("puts each clip back to its own stored volume when Tiptoe goes off", function()
		local rig = newRig(false, FOOTSTEP_VOLUME, 0.4)
		rig.setTiptoe(true)
		expect(rig.clips.running.Volume).toBeCloseTo(FOOTSTEP_VOLUME * 0.25, PRECISION)
		expect(rig.clips.climbing.Volume).toBeCloseTo(0.4 * 0.25, PRECISION)
		rig.setTiptoe(false)
		expect(rig.clips.running.Volume).toBeCloseTo(FOOTSTEP_VOLUME, PRECISION)
		expect(rig.clips.climbing.Volume).toBeCloseTo(0.4, PRECISION)
	end)

	it("is a quarter again after on, off, on (never a sixteenth)", function()
		local rig = newRig()
		rig.setTiptoe(true)
		rig.setTiptoe(false)
		rig.setTiptoe(true)
		expect(rig.clips.running.Volume).toBeCloseTo(QUARTER, PRECISION)
		expect(rig.clips.climbing.Volume).toBeCloseTo(QUARTER, PRECISION)
	end)

	it("is a quarter at once when it starts with Tiptoe already on, and does not click", function()
		local rig = newRig(true)
		expect(rig.clips.running.Volume).toBeCloseTo(QUARTER, PRECISION)
		expect(rig.clips.climbing.Volume).toBeCloseTo(QUARTER, PRECISION)
		expect(#rig.clicks).toBe(0)
	end)

	it("gives a new character a quarter at once", function()
		local rig = newRig()
		rig.setTiptoe(true)
		local _newOne, newClips = rig:giveCharacter()
		expect(newClips.running.Volume).toBeCloseTo(QUARTER, PRECISION)
		expect(newClips.climbing.Volume).toBeCloseTo(QUARTER, PRECISION)
		expect(newClips.jumping.Volume).toBeCloseTo(FOOTSTEP_VOLUME, PRECISION)
	end)

	it("drops the old character's clips on respawn, then is a quarter again for the new one after off, on", function()
		local rig = newRig()
		rig.setTiptoe(true)
		local _newOne, newClips = rig:giveCharacter()
		rig.setTiptoe(false)
		expect(newClips.running.Volume).toBeCloseTo(FOOTSTEP_VOLUME, PRECISION)
		expect(rig.clips.running.Volume).toBeCloseTo(QUARTER, PRECISION) -- dropped, so off did not touch it
		expect(rig.clips.climbing.Volume).toBeCloseTo(QUARTER, PRECISION)
		rig.setTiptoe(true)
		expect(newClips.running.Volume).toBeCloseTo(QUARTER, PRECISION)
		expect(newClips.climbing.Volume).toBeCloseTo(QUARTER, PRECISION)
		expect(rig.clips.running.Volume).toBeCloseTo(QUARTER, PRECISION)
	end)

	it("gives a footstep sound that appears later a quarter", function()
		local rig = newRig()
		rig.setTiptoe(true)
		local root = rig.character:FindFirstChild("HumanoidRootPart") :: Instance
		local late = newClip(root, "Running", FOOTSTEP_VOLUME)
		settle()
		expect(late.Volume).toBeCloseTo(QUARTER, PRECISION)
	end)

	it("leaves a new character at full volume when Tiptoe is off", function()
		local rig = newRig()
		local _newOne, newClips = rig:giveCharacter()
		expect(newClips.running.Volume).toBeCloseTo(FOOTSTEP_VOLUME, PRECISION)
	end)
end)

describe("Footsteps click", function()
	it("clicks once for each Tiptoe change", function()
		local rig = newRig()
		rig.setTiptoe(true)
		expect(#rig.clicks).toBe(1)
		rig.setTiptoe(false)
		expect(#rig.clicks).toBe(2)
		rig.setTiptoe(true)
		expect(#rig.clicks).toBe(3)
	end)

	it("does nothing for another player's Tiptoe", function()
		local rig = newRig()
		rig.setOtherTiptoe(true)
		expect(#rig.clicks).toBe(0)
		expect(rig.clips.running.Volume).toBeCloseTo(FOOTSTEP_VOLUME, PRECISION)
		expect(rig.clips.climbing.Volume).toBeCloseTo(FOOTSTEP_VOLUME, PRECISION)
	end)
end)

describe("Footsteps after destroy", function()
	it("puts the footstep volumes back when destroyed while Tiptoe is on, then ignores Tiptoe", function()
		local rig = newRig()
		rig.setTiptoe(true)
		expect(rig.clips.running.Volume).toBeCloseTo(QUARTER, PRECISION)
		expect(rig.clips.climbing.Volume).toBeCloseTo(QUARTER, PRECISION)
		expect(#rig.clicks).toBe(1)
		rig.handle.destroy()
		expect(rig.clips.running.Volume).toBeCloseTo(FOOTSTEP_VOLUME, PRECISION)
		expect(rig.clips.climbing.Volume).toBeCloseTo(FOOTSTEP_VOLUME, PRECISION)
		rig.setTiptoe(false)
		rig.setTiptoe(true)
		expect(rig.clips.running.Volume).toBeCloseTo(FOOTSTEP_VOLUME, PRECISION)
		expect(rig.clips.climbing.Volume).toBeCloseTo(FOOTSTEP_VOLUME, PRECISION)
		expect(#rig.clicks).toBe(1)
	end)

	it("does nothing when Tiptoe changes, a character comes or a sound appears", function()
		local rig = newRig()
		rig.handle.destroy()
		rig.setTiptoe(true)
		expect(#rig.clicks).toBe(0)
		expect(rig.clips.running.Volume).toBeCloseTo(FOOTSTEP_VOLUME, PRECISION)
		local _newOne, newClips = rig:giveCharacter()
		expect(newClips.running.Volume).toBeCloseTo(FOOTSTEP_VOLUME, PRECISION)
		local root = rig.character:FindFirstChild("HumanoidRootPart") :: Instance
		local late = newClip(root, "Climbing", FOOTSTEP_VOLUME)
		settle()
		expect(late.Volume).toBeCloseTo(FOOTSTEP_VOLUME, PRECISION)
	end)
end)
