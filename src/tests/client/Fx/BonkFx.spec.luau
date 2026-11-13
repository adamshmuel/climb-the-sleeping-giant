--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local BonkFx = require(StarterPlayer.StarterPlayerScripts.Client.Fx.BonkFx)
local BonkPose = require(StarterPlayer.StarterPlayerScripts.Client.Fx.BonkPose)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local BonkRigs = require(script.Parent.BonkRigs)

type Kind = BonkRigs.Kind
type Rig = BonkRigs.Rig

-- Float32 CFrames: compare to about 1e-4 (luau.md, "Test first").
local MARGIN = 1e-4
local STAR = "⭐"
local STAR_COUNT = 4
-- Design B4: the ring's size and place; B7: the puff's burst.
local RING_WIDTH = 5.5
local RING_HEIGHT = 2.6
local RING_RISE = 2.4
local PUFF_COUNT = 5
local START_CLOCK = 100 -- the fake clock starts away from 0, so nothing can lean on a clock that starts at 0

-- A tiny stand-in for a Roblox event: Connect, Fire and Disconnect, all in plain Luau, plus how many handlers are on.
local function newSignal()
	local handlers: { (...any) -> () } = {}
	return {
		Connect = function(_self: any, callback: (...any) -> ())
			table.insert(handlers, callback)
			return {
				Disconnect = function()
					local at = table.find(handlers, callback)
					if at then
						table.remove(handlers, at)
					end
				end,
			}
		end,
		Fire = function(_self: any, ...: any)
			for _, handler in table.clone(handlers) do
				handler(...)
			end
		end,
		count = function(_self: any): number
			return #handlers
		end,
	}
end

type Signal = typeof(newSignal())

-- A player as plain data: a Character, attributes, and the two signals a real Player has.
type FakePlayer = {
	Character: Model?,
	attributes: { [string]: any },
	changed: Signal,
	CharacterRemoving: Signal,
	GetAttribute: (self: any, name: string) -> any,
	GetAttributeChangedSignal: (self: any, name: string) -> Signal,
}

type Burst = { emitter: ParticleEmitter, count: number }
type Sound = { name: string, at: Vector3? }

type Harness = {
	step: Signal,
	added: Signal,
	removing: Signal,
	clock: { t: number },
	reduced: { on: boolean },
	bursts: { Burst },
	sounds: { Sound },
	t0: number, -- the clock reading when the latest bonk began
	stop: () -> (),
}

local madeInstances: { Instance } = {}
local stops: { () -> () } = {}

afterEach(function()
	for _, stop in stops do
		stop()
	end
	table.clear(stops)
	for _, instance in madeInstances do
		instance:Destroy()
	end
	table.clear(madeInstances)
end)

local function newRig(kind: Kind, reversed: boolean?): Rig
	local rig = BonkRigs.build(kind, reversed)
	table.insert(madeInstances, rig.character)
	return rig
end

local function newPlayer(character: Model?, bonked: string?): FakePlayer
	local attributes: { [string]: any } = { Bonked = bonked }
	local changed = newSignal()
	return {
		Character = character,
		attributes = attributes,
		changed = changed,
		CharacterRemoving = newSignal(),
		GetAttribute = function(_self: any, name: string): any
			return attributes[name]
		end,
		GetAttributeChangedSignal = function(_self: any, _name: string): Signal
			return changed
		end,
	}
end

-- Starts BonkFx on fake players with a fake clock and frame signal, recording every burst and sound.
-- With `withSound` false the playSound dep is left out. With `throttled` set, the animatorThrottled dep answers it
-- (EvaluationThrottled can't be set in Edit).
local function setup(players: { FakePlayer }, withSound: boolean?, throttled: boolean?): Harness
	local step = newSignal()
	local added = newSignal()
	local removing = newSignal()
	local clock = { t = START_CLOCK }
	local reduced = { on = false }
	local bursts: { Burst } = {}
	local sounds: { Sound } = {}
	local listed: { BonkFx.PlayerLike } = {}
	for _, player in players do
		table.insert(listed, player :: any)
	end
	local deps: BonkFx.Deps = {
		players = function()
			return listed
		end,
		playerAdded = added,
		playerRemoving = removing,
		step = step,
		now = function()
			return clock.t
		end,
		reducedMotion = function()
			return reduced.on
		end,
		burst = function(emitter: ParticleEmitter, count: number)
			table.insert(bursts, { emitter = emitter, count = count })
		end,
	}
	if withSound ~= false then
		deps.playSound = function(name: string, at: Vector3?)
			table.insert(sounds, { name = name, at = at })
		end
	end
	if throttled ~= nil then
		deps.animatorThrottled = function(_animator: Animator): boolean
			return throttled
		end
	end
	local stop = BonkFx.start(deps)
	table.insert(stops, stop)
	return {
		step = step,
		added = added,
		removing = removing,
		clock = clock,
		reduced = reduced,
		bursts = bursts,
		sounds = sounds,
		t0 = clock.t,
		stop = stop,
	}
end

-- The server sets Bonked and the client sees the change.
local function setBonked(player: FakePlayer, value: string?)
	player.attributes.Bonked = value
	player.changed:Fire()
end

-- A bonk begins now: the clock reading is kept, and `at` counts seconds from it.
local function begin(h: Harness, player: FakePlayer, value: string)
	h.t0 = h.clock.t
	setBonked(player, value)
end

-- One frame, `seconds` after the latest bonk began.
local function at(h: Harness, seconds: number)
	h.clock.t = h.t0 + seconds
	h.step:Fire()
end

local function total(): number
	local wake = Config.Wake
	return wake.TumbleDownSeconds + wake.TumbleStillSeconds + wake.TumbleUpSeconds
end

-- A named check: a failure shows the label instead of a bare false.
local function expectTrue(label: string, ok: boolean)
	expect(`{label}: {ok}`).toBe(`{label}: true`)
end

local function closeCFrame(a: CFrame, b: CFrame): boolean
	local ca = { a:GetComponents() }
	local cb = { b:GetComponents() }
	for index = 1, 12 do
		if math.abs(ca[index] - cb[index]) > MARGIN then
			return false
		end
	end
	return true
end

local function ringsOf(rig: Rig): { BillboardGui }
	local found: { BillboardGui } = {}
	for _, child in rig.head:GetChildren() do
		if child:IsA("BillboardGui") then
			table.insert(found, child)
		end
	end
	return found
end

local function labelsOf(ring: BillboardGui): { TextLabel }
	local found: { TextLabel } = {}
	for _, child in ring:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(found, child)
		end
	end
	return found
end

-- The puff: every ParticleEmitter in an Attachment on the root part.
local function puffsOf(rig: Rig): { ParticleEmitter }
	local found: { ParticleEmitter } = {}
	for _, child in rig.root:GetChildren() do
		if child:IsA("Attachment") then
			for _, inner in child:GetChildren() do
				if inner:IsA("ParticleEmitter") then
					table.insert(found, inner)
				end
			end
		end
	end
	return found
end

-- Where the 4 labels are now (empty when there is no ring).
local function positionsOf(rig: Rig): { UDim2 }
	local positions: { UDim2 } = {}
	local ring: BillboardGui? = ringsOf(rig)[1]
	if ring ~= nil then
		for _, label in labelsOf(ring) do
			table.insert(positions, label.Position)
		end
	end
	return positions
end

-- Where the jointed part is placed (in the root part's space, with C1 identity): C0 * Transform. C0 is only ever read.
local function placeOf(rig: Rig, rest: CFrame): CFrame
	return rest * rig.joint.Transform
end

local function expectedPlace(kind: Kind, rest: CFrame, seconds: number): CFrame
	local pivot = BonkPose.pivotOf(BonkRigs.boxesOf(kind))
	return BonkPose.tipped(rest, pivot, BonkPose.angleAt(seconds))
end

-- The joint is at rest: its Transform is the identity and C0 was never written.
local function atRest(rig: Rig, rest: CFrame): boolean
	return rig.joint.Transform == CFrame.identity and BonkRigs.c0Of(rig) == rest
end

-- A real Animator under the Humanoid (not throttled: its EvaluationThrottled is false and read-only in Edit).
local function addAnimator(rig: Rig): Animator
	local humanoid = rig.character:FindFirstChildOfClass("Humanoid") :: Humanoid
	local animator = Instance.new("Animator")
	animator.Parent = humanoid
	return animator
end

-- One frame as the Animator would leave it: it writes `pose` into Transform, then the frame handler runs.
local function atAnimated(h: Harness, rig: Rig, seconds: number, pose: CFrame)
	BonkRigs.setTransform(rig, pose)
	at(h, seconds)
end

-- Nothing of the bonk is left on the rig: the joint is at rest and the ring and puff are gone.
local function expectClean(label: string, rig: Rig, rest: CFrame, h: Harness)
	expectTrue(`{label} joint at rest`, atRest(rig, rest))
	expect(`{label} rings {#ringsOf(rig)}`).toBe(`{label} rings 0`)
	expect(`{label} puffs {#puffsOf(rig)}`).toBe(`{label} puffs 0`)
	expect(`{label} step handlers {h.step:count()}`).toBe(`{label} step handlers 0`)
end

local function expectTumbles(kind: Kind, reversed: boolean)
	local rig = newRig(kind, reversed)
	local rest = BonkRigs.c0Of(rig)
	local player = newPlayer(rig.character)
	local h = setup({ player })
	begin(h, player, "Ground")
	for _, seconds in { 0.075, 0.15, 0.45, 0.75 } do
		at(h, seconds)
		expectTrue(`{kind} at {seconds} s`, closeCFrame(placeOf(rig, rest), expectedPlace(kind, rest, seconds)))
	end
	at(h, total())
	expectTrue(`{kind} at the end the joint is at rest exactly`, atRest(rig, rest))
end

local function expectRootUntouched(kind: Kind, reversed: boolean)
	local rig = newRig(kind, reversed)
	local rootAtRest = rig.root.CFrame
	local player = newPlayer(rig.character)
	local h = setup({ player })
	begin(h, player, "Ground")
	for _, seconds in { 0, 0.075, 0.15, 0.45, 0.75, 0.95, total() } do
		at(h, seconds)
		expectTrue(`{kind} root at {seconds} s`, rig.root.CFrame == rootAtRest)
	end
end

describe("BonkFx.start Ground tumble (B1, B2)", function()
	it("tips the R15 joint along the pose and puts it back exactly at 1.0 s (B1)", function()
		expectTumbles("R15", false)
	end)

	it("never writes the R15 root part (B1)", function()
		expectRootUntouched("R15", false)
	end)

	it("tips the R6 joint (RootJoint, built in the other child order) the same way (B2)", function()
		expectTumbles("R6", true)
	end)

	it("never writes the R6 root part (B2)", function()
		expectRootUntouched("R6", true)
	end)
end)

-- Studio's real R15 joint is an AnimationConstraint: C0 and C1 are read-only stand-ins for its attachments' CFrames, so
-- the tumble goes through Transform (the Animator rewrites it every frame, so it is multiplied onto that).
describe("BonkFx.start on the real R15 joint, an AnimationConstraint (R1 to R4)", function()
	it("tips the part through Transform while an Animator rewrites it each frame (R1)", function()
		local rig = newRig("R15")
		addAnimator(rig)
		local rest = BonkRigs.c0Of(rig)
		local player = newPlayer(rig.character)
		local h = setup({ player })
		begin(h, player, "Ground")
		for _, seconds in { 0.075, 0.15, 0.45, 0.75 } do
			atAnimated(h, rig, seconds, CFrame.identity)
			expectTrue(`at {seconds} s`, closeCFrame(placeOf(rig, rest), expectedPlace("R15", rest, seconds)))
		end
	end)

	it("multiplies onto the pose the Animator wrote, not over it (R1)", function()
		local rig = newRig("R15")
		addAnimator(rig)
		local rest = BonkRigs.c0Of(rig)
		local pose = CFrame.new(0.1, 0.2, 0) * CFrame.Angles(0, 0.3, 0)
		local player = newPlayer(rig.character)
		local h = setup({ player })
		begin(h, player, "Ground")
		atAnimated(h, rig, 0.45, pose)
		local tip = rest:Inverse() * expectedPlace("R15", rest, 0.45)
		expectTrue("tip times pose", closeCFrame(rig.joint.Transform, tip * pose))
	end)

	it("never changes either attachment's CFrame, during or after the bonk (R2)", function()
		local rig = newRig("R15")
		local first = rig.attachments[1].CFrame
		local second = rig.attachments[2].CFrame
		local player = newPlayer(rig.character)
		local h = setup({ player })
		begin(h, player, "Ground")
		for _, seconds in { 0.075, 0.45, 0.75, total() } do
			at(h, seconds)
			if seconds == 0.45 then
				expectTrue("the tumble is drawing", rig.joint.Transform ~= CFrame.identity)
			end
			expectTrue(`Attachment0 at {seconds} s`, rig.attachments[1].CFrame == first)
			expectTrue(`Attachment1 at {seconds} s`, rig.attachments[2].CFrame == second)
		end
	end)

	it("leaves Transform alone on a frame the Animator did not rewrite (R3)", function()
		local rig = newRig("R15")
		addAnimator(rig)
		local pose = CFrame.new(0.1, 0.2, 0) * CFrame.Angles(0, 0.3, 0)
		local player = newPlayer(rig.character)
		local h = setup({ player }, nil, true)
		begin(h, player, "Ground")
		BonkRigs.setTransform(rig, pose)
		for _, seconds in { 0.15, 0.45, 0.75 } do
			at(h, seconds)
			expectTrue(`throttled frame at {seconds} s`, closeCFrame(rig.joint.Transform, pose))
		end
	end)

	it("with no Animator, sets Transform each frame and ends on the identity exactly (R4)", function()
		local rig = newRig("R15")
		local rest = BonkRigs.c0Of(rig)
		local player = newPlayer(rig.character)
		local h = setup({ player })
		begin(h, player, "Ground")
		at(h, 0.45)
		expectTrue("tipped mid-bonk", rig.joint.Transform ~= CFrame.identity)
		at(h, 0.6)
		expectTrue("set, not piled up", closeCFrame(placeOf(rig, rest), expectedPlace("R15", rest, 0.6)))
		at(h, total())
		expectTrue("identity at the end", rig.joint.Transform == CFrame.identity)
	end)
end)

describe("BonkFx.start Ladder (B3)", function()
	it("leaves the joint alone, on the real R15 joint (B3, R5)", function()
		local rig = newRig("R15")
		local rest = BonkRigs.c0Of(rig)
		local player = newPlayer(rig.character)
		local h = setup({ player })
		begin(h, player, "Ladder")
		for _, seconds in { 0.075, 0.3, 0.75 } do
			at(h, seconds)
			expectTrue(`ladder joint at {seconds} s`, atRest(rig, rest))
		end
	end)

	it("still shows the star ring and the puff", function()
		local rig = newRig("R15")
		local player = newPlayer(rig.character)
		local h = setup({ player })
		begin(h, player, "Ladder")
		at(h, 0.3)
		expect(`rings {#ringsOf(rig)}`).toBe("rings 1")
		expect(`puffs {#puffsOf(rig)}`).toBe("puffs 1")
	end)
end)

describe("BonkFx.start the ring (B4, B5, B6)", function()
	it("is one BillboardGui on the Head with 4 star labels that move between frames (B4)", function()
		local rig = newRig("R15")
		local player = newPlayer(rig.character)
		local h = setup({ player })
		begin(h, player, "Ground")
		at(h, 0.05)
		expect(`rings {#ringsOf(rig)}`).toBe("rings 1")
		local ring = ringsOf(rig)[1]
		expectTrue("width", math.abs(ring.Size.X.Scale - RING_WIDTH) < MARGIN)
		expectTrue("height", math.abs(ring.Size.Y.Scale - RING_HEIGHT) < MARGIN)
		expectTrue("offset", (ring.StudsOffset - Vector3.new(0, RING_RISE, 0)).Magnitude < MARGIN)
		expect(ring.LightInfluence).toBe(0)
		expect(ring.AlwaysOnTop).toBe(false)
		expect(ring.ResetOnSpawn).toBe(false)
		local labels = labelsOf(ring)
		expect(`labels {#labels}`).toBe(`labels {STAR_COUNT}`)
		for index, label in labels do
			expect(`label {index} text {label.Text}`).toBe(`label {index} text {STAR}`)
			expectTrue(`label {index} scaled`, label.TextScaled)
			expect(label.BackgroundTransparency).toBe(1)
		end
		local first = positionsOf(rig)
		at(h, 0.15)
		local later = positionsOf(rig)
		for index = 1, STAR_COUNT do
			expectTrue(`label {index} moved`, first[index] ~= later[index])
		end
	end)

	it("stands still with Reduce Motion on, while the tumble still plays (B5)", function()
		local rig = newRig("R15")
		local rest = BonkRigs.c0Of(rig)
		local player = newPlayer(rig.character)
		local h = setup({ player })
		h.reduced.on = true
		begin(h, player, "Ground")
		at(h, 0.05)
		local first = positionsOf(rig)
		expect(`labels {#first}`).toBe(`labels {STAR_COUNT}`)
		at(h, 0.15)
		local later = positionsOf(rig)
		for index = 1, STAR_COUNT do
			expectTrue(`label {index} still`, first[index] == later[index])
		end
		at(h, 0.075)
		expectTrue("tumble", closeCFrame(placeOf(rig, rest), expectedPlace("R15", rest, 0.075)))
	end)

	it("reads Reduce Motion at each bonk: off then on gives a still second ring (B6)", function()
		local rig = newRig("R15")
		local player = newPlayer(rig.character)
		local h = setup({ player })
		begin(h, player, "Ground")
		at(h, 0.05)
		local first = positionsOf(rig)
		at(h, 0.15)
		local later = positionsOf(rig)
		expectTrue("first bonk moves", #first == STAR_COUNT and first[1] ~= later[1])
		setBonked(player, nil)
		h.reduced.on = true
		begin(h, player, "Ground")
		at(h, 0.05)
		local second = positionsOf(rig)
		at(h, 0.15)
		local secondLater = positionsOf(rig)
		expectTrue("second bonk has a ring", #second == STAR_COUNT)
		for index = 1, #second do
			expectTrue(`second bonk label {index} still`, second[index] == secondLater[index])
		end
	end)
end)

describe("BonkFx.start the puff and its sound (B7, B11)", function()
	it("bursts 5 once on an emitter under the root part, at the start only (B7)", function()
		local rig = newRig("R15")
		local player = newPlayer(rig.character)
		local h = setup({ player })
		begin(h, player, "Ground")
		expect(`bursts {#h.bursts}`).toBe("bursts 1")
		local burst = h.bursts[1]
		expect(`count {burst.count}`).toBe(`count {PUFF_COUNT}`)
		local attachment = burst.emitter.Parent
		expectTrue("emitter is under an Attachment on the root", attachment ~= nil and attachment.Parent == rig.root)
		at(h, 0.1)
		at(h, 0.5)
		expect(`bursts later {#h.bursts}`).toBe("bursts later 1")
	end)

	it("plays Bonk once per bonk, at the root's position (B11)", function()
		local rig = newRig("R15")
		local player = newPlayer(rig.character)
		local h = setup({ player })
		begin(h, player, "Ground")
		at(h, 0.3)
		at(h, 0.6)
		expect(`sounds {#h.sounds}`).toBe("sounds 1")
		expect(h.sounds[1].name).toBe("Bonk")
		expectTrue("at the root", h.sounds[1].at == rig.root.Position)
		setBonked(player, nil)
		begin(h, player, "Ladder")
		expect(`sounds after the second {#h.sounds}`).toBe("sounds after the second 2")
	end)

	it("plays nothing and does not fail when the player has no character (B11)", function()
		local player = newPlayer(nil)
		local h = setup({ player })
		expect(function()
			begin(h, player, "Ground")
			at(h, 0.3)
		end).never.toThrow()
		expect(#h.sounds).toBe(0)
		expect(#h.bursts).toBe(0)
	end)

	it("does not fail without a playSound dep (B11)", function()
		local rig = newRig("R15")
		local player = newPlayer(rig.character)
		local h = setup({ player }, false)
		expect(function()
			begin(h, player, "Ground")
			at(h, 0.3)
		end).never.toThrow()
		expect(#h.sounds).toBe(0)
	end)
end)

describe("BonkFx.start the end of a bonk (B8, B9, B10)", function()
	it("puts everything back at once when the attribute clears at 0.5 s (B8)", function()
		local rig = newRig("R15")
		local rest = BonkRigs.c0Of(rig)
		local player = newPlayer(rig.character)
		local h = setup({ player })
		begin(h, player, "Ground")
		at(h, 0.3)
		expect(`step handlers while on {h.step:count()}`).toBe("step handlers while on 1")
		at(h, 0.5)
		setBonked(player, nil)
		expectClean("cleared", rig, rest, h)
		at(h, 0.6)
		expectTrue("later frames leave the joint alone", atRest(rig, rest))
	end)

	it("clears everything by itself at 1.0 s when the attribute is left set (B8)", function()
		local rig = newRig("R15")
		local rest = BonkRigs.c0Of(rig)
		local player = newPlayer(rig.character)
		local h = setup({ player })
		begin(h, player, "Ground")
		at(h, total())
		expectClean("left set", rig, rest, h)
		at(h, 1.5)
		expectClean("left set, later", rig, rest, h)
	end)

	it("replaces a Ladder bonk with a Ground one: one ring, the pose starts at 0 (B9)", function()
		local rig = newRig("R15")
		local rest = BonkRigs.c0Of(rig)
		local player = newPlayer(rig.character)
		local h = setup({ player })
		begin(h, player, "Ladder")
		at(h, 0.3)
		begin(h, player, "Ground")
		expect(`rings {#ringsOf(rig)}`).toBe("rings 1")
		expect(`puffs {#puffsOf(rig)}`).toBe("puffs 1")
		at(h, 0.075)
		expectTrue("restarted", closeCFrame(placeOf(rig, rest), expectedPlace("R15", rest, 0.075)))
	end)

	it("replaces a Ground bonk with a Ladder one: the joint is at rest at once, one ring (B9)", function()
		local rig = newRig("R15")
		local rest = BonkRigs.c0Of(rig)
		local player = newPlayer(rig.character)
		local h = setup({ player })
		begin(h, player, "Ground")
		at(h, 0.6)
		begin(h, player, "Ladder")
		expectTrue("at rest at once", atRest(rig, rest))
		expect(`rings {#ringsOf(rig)}`).toBe("rings 1")
		expect(`puffs {#puffsOf(rig)}`).toBe("puffs 1")
		at(h, 0.3)
		expectTrue("at rest later", atRest(rig, rest))
	end)

	it("makes nothing but the ring with its 4 labels and the puff pieces (B10)", function()
		local rig = newRig("R15")
		local player = newPlayer(rig.character)
		local h = setup({ player })
		local before: { [Instance]: boolean } = {}
		for _, existing in rig.character:GetDescendants() do
			before[existing] = true
		end
		begin(h, player, "Ground")
		at(h, 0.3)
		local counts: { [string]: number } = {}
		for _, found in rig.character:GetDescendants() do
			if not before[found] then
				counts[found.ClassName] = (counts[found.ClassName] or 0) + 1
				if found:IsA("TextLabel") then
					expect(found.Text).toBe(STAR)
				end
			end
		end
		local names: { string } = {}
		for className in counts do
			table.insert(names, className)
		end
		table.sort(names)
		local parts: { string } = {}
		for _, className in names do
			table.insert(parts, `{className} {counts[className]}`)
		end
		expect(table.concat(parts, ", ")).toBe("Attachment 1, BillboardGui 1, ParticleEmitter 1, TextLabel 4")
	end)
end)

describe("BonkFx.start more than one player (B12)", function()
	it("draws each player's own bonk on their own body", function()
		local rigA = newRig("R15")
		local rigB = newRig("R6", true)
		local restA = BonkRigs.c0Of(rigA)
		local restB = BonkRigs.c0Of(rigB)
		local a = newPlayer(rigA.character)
		local b = newPlayer(rigB.character)
		local h = setup({ a, b })
		begin(h, a, "Ground")
		at(h, 0.15)
		expectTrue("A tipped", closeCFrame(placeOf(rigA, restA), expectedPlace("R15", restA, 0.15)))
		expectTrue("B untouched", atRest(rigB, restB))
		expect(`A rings {#ringsOf(rigA)}`).toBe("A rings 1")
		expect(`B rings {#ringsOf(rigB)}`).toBe("B rings 0")
		-- B's bonk begins at the same clock reading as A's, so one `at` times both.
		setBonked(b, "Ground")
		at(h, 0.45)
		expectTrue("A at 0.45", closeCFrame(placeOf(rigA, restA), expectedPlace("R15", restA, 0.45)))
		expectTrue("B at 0.45", closeCFrame(placeOf(rigB, restB), expectedPlace("R6", restB, 0.45)))
		expect(`B rings later {#ringsOf(rigB)}`).toBe("B rings later 1")
	end)

	it("watches a player added after start", function()
		local rig = newRig("R15")
		local rest = BonkRigs.c0Of(rig)
		local h = setup({})
		local player = newPlayer(rig.character)
		h.added:Fire(player)
		begin(h, player, "Ground")
		at(h, 0.15)
		expectTrue("tipped", closeCFrame(placeOf(rig, rest), expectedPlace("R15", rest, 0.15)))
		expect(`rings {#ringsOf(rig)}`).toBe("rings 1")
	end)

	it("cleans a removed player's bonk and ignores their later changes", function()
		local rig = newRig("R15")
		local rest = BonkRigs.c0Of(rig)
		local player = newPlayer(rig.character)
		local h = setup({ player })
		begin(h, player, "Ground")
		at(h, 0.3)
		expect(`rings before {#ringsOf(rig)}`).toBe("rings before 1")
		h.removing:Fire(player)
		expectClean("removed", rig, rest, h)
		setBonked(player, nil)
		begin(h, player, "Ladder")
		expect(`rings after {#ringsOf(rig)}`).toBe("rings after 0")
	end)
end)

describe("BonkFx.start a bonk already on and a body that goes (B13)", function()
	it("plays nothing for a bonk already on at start or when the player is added", function()
		local rigA = newRig("R15")
		local restA = BonkRigs.c0Of(rigA)
		local a = newPlayer(rigA.character, "Ground")
		local h = setup({ a })
		local rigB = newRig("R6", true)
		local restB = BonkRigs.c0Of(rigB)
		local b = newPlayer(rigB.character, "Ground")
		h.added:Fire(b)
		at(h, 0.15)
		expectClean("A", rigA, restA, h)
		expectClean("B", rigB, restB, h)
		expect(#h.bursts).toBe(0)
		expect(#h.sounds).toBe(0)
	end)

	it("cleans the ring and the puff when the character is removed mid-bonk", function()
		local rig = newRig("R15")
		local rest = BonkRigs.c0Of(rig)
		local player = newPlayer(rig.character)
		local h = setup({ player })
		begin(h, player, "Ground")
		at(h, 0.3)
		expect(`rings before {#ringsOf(rig)}`).toBe("rings before 1")
		player.CharacterRemoving:Fire()
		expectClean("removed character", rig, rest, h)
	end)
end)

describe("BonkFx.start stop (B14)", function()
	it("puts everything back mid-bonk and starts no more", function()
		local rig = newRig("R15")
		local rest = BonkRigs.c0Of(rig)
		local player = newPlayer(rig.character)
		local h = setup({ player })
		begin(h, player, "Ground")
		at(h, 0.3)
		expect(`rings before {#ringsOf(rig)}`).toBe("rings before 1")
		h.stop()
		expectClean("stopped", rig, rest, h)
		setBonked(player, nil)
		begin(h, player, "Ladder")
		at(h, 0.3)
		expectClean("after stop", rig, rest, h)
	end)

	it("keeps no frame handler while idle", function()
		local rig = newRig("R15")
		local player = newPlayer(rig.character)
		local h = setup({ player })
		expect(h.step:count()).toBe(0)
	end)
end)
