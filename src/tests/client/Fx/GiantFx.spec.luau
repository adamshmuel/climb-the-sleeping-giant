--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Client = StarterPlayer.StarterPlayerScripts.Client
local GiantFx = require(Client.Fx.GiantFx)

-- Everything a test makes is destroyed afterwards, so the real place is never changed.
local madeInstances: { Instance } = {}
local stops: { () -> () } = {}

local function made<T>(instance: T): T
	table.insert(madeInstances, instance :: any)
	return instance
end

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

-- A tiny stand-in for a RemoteEvent's OnClientEvent or RenderStepped: Connect, Fire and Disconnect, in plain Luau.
local function newSignal(): any
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

local LETTER_LOOKS = { 0.05, 0.10, 0.15 }

-- One snort burst the module asked for: how many puffs, and how many seconds after the rig was built.
type Burst = { count: number, at: number, emitter: ParticleEmitter }

type Rig = {
	world: Folder,
	giant: Model,
	leftLid: Model,
	rightLid: Model,
	leftSliver: Part,
	arm: Model,
	fx: Folder,
	snoreEmitter: Part,
	floatingZ: BillboardGui,
	letters: { TextLabel },
	outlines: { UIStroke },
	normalLetters: { number }, -- as Roblox stores them (32-bit)
	puff: ParticleEmitter,
	snortPuff: ParticleEmitter?, -- nil when the rig is built without the nose
	bursts: { Burst }, -- every Emit the module asked for, with the seconds since the rig was built
	clears: { ParticleEmitter }, -- every emitter the module cleared (ParticleEmitter:Clear), in order
	bubble: BillboardGui, -- World.GiantFX.SnoreEmitter.Warning85Bubble
	bubbleFrame: Frame,
	bubbleWords: TextLabel,
	bubbleTail: Frame,
	bubbleStrokes: { UIStroke }, -- the pill's and the tail's outlines
	setPhone: (phone: boolean) -> (),
	setCameraRightZ: (z: number) -> (),
	setReducedMotion: (reduced: boolean) -> (),
	state: Folder,
	warning: any,
	slamWarning: any,
	step: any,
	handle: GiantFx.Handle,
	setArmClear: (answer: (shoulder: Vector3, direction: Vector3) -> boolean) -> (),
	armClearCalls: { { shoulder: Vector3, direction: Vector3 } },
	advance: (seconds: number) -> (),
	fire: (mark: number, kind: string?) -> (),
	setState: (meter: number, phase: string) -> (),
	armStart: CFrame,
	leftStart: CFrame,
	rightStart: CFrame,
	head: Model,
	cap: Model,
	awakeEyes: Model,
	awakeParts: { Part }, -- the 8 parts that show when he is awake
	stray: Part, -- a part of AwakeEyes that is not marked ShownWhenAwake
	sleepParts: { BasePart }, -- every part under SleepEyes
	sleepLooks: { number }, -- what each of them looked like at the start
	headStart: CFrame,
	capStart: CFrame,
	awakeEyesStart: CFrame,
}

-- Where the fake giant stands: the same pivot as the real one, with no turn (he faces -Z, his right is +X).
local GIANT_PIVOT = CFrame.new(0, -3, 0)
local HEAD_PIVOT = Vector3.new(0, 78, 18)
local HEAD_TILT_DEGREES = -12
local SHOULDER = Vector3.new(40, 58, 8)
local RAISE_DEGREES = Vector3.new(135, 0, 15)

local function newLid(name: string, parent: Instance, x: number): (Model, Part)
	local lid = Instance.new("Model")
	lid.Name = name
	lid:SetAttribute("FlutterLift", 1.4)
	local body = Instance.new("Part")
	body.Name = "Lid"
	body.Transparency = 0.2 -- not 0, so a test can tell a restored value from a default
	body.Anchored = true
	body.Size = Vector3.new(4, 1, 1)
	body.CFrame = CFrame.new(x, 95, -3)
	body.Parent = lid
	local sliver = Instance.new("Part")
	sliver.Name = "Sliver"
	sliver.Anchored = true
	sliver.Transparency = 1
	sliver.Size = Vector3.new(4, 0.2, 1)
	sliver.CFrame = CFrame.new(x, 94, -3)
	sliver.Parent = lid
	lid.Parent = parent
	return lid, sliver
end

-- A stand-in for the giant's pieces, the state folder, the Warning remote, the frame step and a fake clock, so a
-- test can drive all of them. `withFx` false builds the world without GiantFX (it streams in later).
local function newRig(withFx: boolean?, startPhase: string?, withNose: boolean?): Rig
	local world = made(Instance.new("Folder"))
	local giant = Instance.new("Model")
	giant.Name = "Giant"
	giant:SetAttribute("Awake_RightShoulderPivot", SHOULDER)
	giant:SetAttribute("Awake_RightArmRaiseDegXZ", RAISE_DEGREES)
	giant:SetAttribute("Awake_HeadPivot", HEAD_PIVOT)
	giant:SetAttribute("Awake_HeadTiltDeg", HEAD_TILT_DEGREES)
	giant.WorldPivot = GIANT_PIVOT
	giant.Parent = world
	local eyes = Instance.new("Model")
	eyes.Name = "SleepEyes"
	eyes.Parent = giant
	local leftLid, leftSliver = newLid("LeftLid", eyes, -10)
	local rightLid = newLid("RightLid", eyes, 10)
	local arm = Instance.new("Model")
	arm.Name = "right_arm"
	local armPart = Instance.new("Part")
	armPart.Anchored = true
	armPart.Size = Vector3.new(5, 20, 5)
	armPart.CFrame = CFrame.new(41, 68, 8)
	armPart.Parent = arm
	arm.Parent = giant

	local function newPiece(name: string, position: Vector3): Model
		local model = Instance.new("Model")
		model.Name = name
		local part = Instance.new("Part")
		part.Anchored = true
		part.Size = Vector3.new(10, 10, 10)
		part.CFrame = CFrame.new(position)
		part.Parent = model
		model.Parent = giant
		return model
	end
	local head = newPiece("head_with_beard", Vector3.new(0, 85, 14))
	local cap = newPiece("nightcap", Vector3.new(2, 100, 16))
	local awakeEyes = Instance.new("Model")
	awakeEyes.Name = "AwakeEyes"
	local awakeParts: { Part } = {}
	for index, name in { "EyeWhite", "Pupil", "Shine", "Brow", "EyeWhite", "Pupil", "Shine", "Brow" } do
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.Size = Vector3.new(1, 1, 1)
		part.CFrame = CFrame.new(if index <= 4 then -6 else 6, 88 + index * 0.1, -2)
		part.Transparency = 1
		part:SetAttribute("ShownWhenAwake", true)
		part.Parent = awakeEyes
		table.insert(awakeParts, part)
	end
	local stray = Instance.new("Part")
	stray.Name = "Stray"
	stray.Anchored = true
	stray.Transparency = 1
	stray.CFrame = CFrame.new(0, 90, -2)
	stray.Parent = awakeEyes
	awakeEyes.Parent = giant
	local sleepParts: { BasePart } = {}
	local sleepLooks: { number } = {}
	for _, descendant in eyes:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(sleepParts, descendant)
			table.insert(sleepLooks, descendant.Transparency)
		end
	end

	local fx = Instance.new("Folder")
	fx.Name = "GiantFX"
	local snoreEmitter = Instance.new("Part")
	snoreEmitter.Name = "SnoreEmitter"
	snoreEmitter.Anchored = true
	snoreEmitter.Parent = fx
	local floatingZ = Instance.new("BillboardGui")
	floatingZ.Name = "FloatingZ"
	floatingZ.Size = UDim2.fromScale(16, 16) -- 16 x 16 studs, as in the place
	floatingZ.StudsOffset = Vector3.new(14, 8, 2)
	floatingZ.Parent = snoreEmitter
	local letters: { TextLabel } = {}
	local outlines: { UIStroke } = {}
	local normalLetters: { number } = {}
	for _, look in LETTER_LOOKS do
		local letter = Instance.new("TextLabel")
		letter.Name = "Z"
		letter.TextTransparency = look
		letter.Parent = floatingZ
		local outline = Instance.new("UIStroke")
		outline.Transparency = 0
		outline.Parent = letter
		table.insert(letters, letter)
		table.insert(normalLetters, letter.TextTransparency)
		table.insert(outlines, outline)
	end
	local puff = Instance.new("ParticleEmitter")
	puff.Name = "SnorePuff"
	puff.Rate = 2
	puff.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 7) })
	puff.Parent = snoreEmitter
	-- The snort: its own invisible part with its own emitter, as in the place (World.GiantFX.SnortNose.SnortPuff).
	local snortPuff: ParticleEmitter? = nil
	if withNose ~= false then
		local snortNose = Instance.new("Part")
		snortNose.Name = "SnortNose"
		snortNose.Anchored = true
		snortNose.Parent = fx
		local snortEmitter = Instance.new("ParticleEmitter")
		snortEmitter.Name = "SnortPuff"
		snortEmitter.Parent = snortNose
		snortPuff = snortEmitter
	end
	-- The 85% bubble, as in the place (World.GiantFX.SnoreEmitter.Warning85Bubble): a pill with the words, and a tail.
	local bubble = Instance.new("BillboardGui")
	bubble.Name = "Warning85Bubble"
	bubble.Enabled = false
	bubble.Size = UDim2.fromScale(41.6, 14.4)
	bubble.StudsOffset = Vector3.new(14, -3, 2)
	bubble.SizeOffset = Vector2.new(0.5, 0.5)
	local bubbleFrame = Instance.new("Frame")
	bubbleFrame.Name = "Frame"
	bubbleFrame.Size = UDim2.fromScale(1, 1)
	bubbleFrame.BackgroundTransparency = 0
	bubbleFrame.Parent = bubble
	local pillStroke = Instance.new("UIStroke")
	pillStroke.Thickness = 4
	pillStroke.Transparency = 0
	pillStroke.Parent = bubbleFrame
	local bubbleWords = Instance.new("TextLabel")
	bubbleWords.Name = "TextLabel"
	bubbleWords.Text = "Mmm... my eggs..."
	bubbleWords.Size = UDim2.fromScale(0.9, 0.8)
	bubbleWords.BackgroundTransparency = 1
	bubbleWords.TextScaled = true
	bubbleWords.TextWrapped = true
	bubbleWords.TextTransparency = 0
	bubbleWords.Parent = bubbleFrame
	local bubbleTail = Instance.new("Frame")
	bubbleTail.Name = "Tail"
	bubbleTail.Size = UDim2.fromScale(0.0761538446, 0.22)
	bubbleTail.AnchorPoint = Vector2.new(0.5, 0.5)
	bubbleTail.Position = UDim2.fromScale(0.07, 0.93)
	bubbleTail.Rotation = 45
	bubbleTail.BackgroundTransparency = 0
	bubbleTail.Parent = bubble
	local tailStroke = Instance.new("UIStroke")
	tailStroke.Thickness = 4
	tailStroke.Transparency = 0
	tailStroke.Parent = bubbleTail
	bubble.Parent = snoreEmitter
	made(fx)
	if withFx ~= false then
		fx.Parent = world
	end

	local state = made(Instance.new("Folder"))
	state:SetAttribute("Meter", 0)
	state:SetAttribute("Phase", startPhase or "Asleep")
	local warning = newSignal()
	local slamWarning = newSignal()
	local step = newSignal()
	local clock = 100
	-- What the screen and the camera say right now; a test changes them with setPhone and the others.
	local onPhone = false
	local cameraRightZ = 0
	local reducedMotion = false
	-- The stand-in for "is the arm's path clear of his body?": clear unless a test says otherwise. It records its calls.
	local function clearAlways(_shoulder: Vector3, _direction: Vector3): boolean
		return true
	end
	local armClearAnswer: (shoulder: Vector3, direction: Vector3) -> boolean = clearAlways
	local armClearCalls: { { shoulder: Vector3, direction: Vector3 } } = {}
	-- The stand-in for ParticleEmitter:Emit: a real emitter can't be asked how often it was told to emit.
	local bursts: { Burst } = {}
	-- The stand-in for ParticleEmitter:Clear: a real emitter can't be asked either.
	local clears: { ParticleEmitter } = {}

	-- Where the pieces are before the module starts: a module that starts while he is awake moves them at once.
	local armStart = arm:GetPivot()
	local leftStart = leftLid:GetPivot()
	local rightStart = rightLid:GetPivot()
	local headStart = head:GetPivot()
	local capStart = cap:GetPivot()
	local awakeEyesStart = awakeEyes:GetPivot()

	local handle = GiantFx.start({
		world = world,
		warning = { OnClientEvent = warning },
		slamWarning = { OnClientEvent = slamWarning },
		giantState = state,
		step = step,
		now = function()
			return clock
		end,
		armClear = function(shoulder: Vector3, direction: Vector3): boolean
			table.insert(armClearCalls, { shoulder = shoulder, direction = direction })
			return armClearAnswer(shoulder, direction)
		end,
		burst = function(emitter: ParticleEmitter, count: number)
			table.insert(bursts, { count = count, at = clock - 100, emitter = emitter })
		end,
		clear = function(emitter: ParticleEmitter?)
			-- A call with no emitter still counts (as `false`), so a missing nose can't hide in an empty slot.
			table.insert(clears, if emitter ~= nil then emitter else false :: any)
		end,
		isPhone = function(): boolean
			return onPhone
		end,
		cameraRight = function(): Vector3
			return Vector3.new(1, 0, cameraRightZ)
		end,
		reducedMotion = function(): boolean
			return reducedMotion
		end,
	})
	table.insert(stops, handle.stop)

	return {
		world = world,
		giant = giant,
		leftLid = leftLid,
		rightLid = rightLid,
		leftSliver = leftSliver,
		arm = arm,
		fx = fx,
		snoreEmitter = snoreEmitter,
		floatingZ = floatingZ,
		letters = letters,
		outlines = outlines,
		normalLetters = normalLetters,
		puff = puff,
		snortPuff = snortPuff,
		bursts = bursts,
		clears = clears,
		bubble = bubble,
		bubbleFrame = bubbleFrame,
		bubbleWords = bubbleWords,
		bubbleTail = bubbleTail,
		bubbleStrokes = { pillStroke, tailStroke },
		setPhone = function(phone: boolean)
			onPhone = phone
		end,
		setCameraRightZ = function(z: number)
			cameraRightZ = z
		end,
		setReducedMotion = function(reduced: boolean)
			reducedMotion = reduced
		end,
		state = state,
		warning = warning,
		slamWarning = slamWarning,
		step = step,
		handle = handle,
		setArmClear = function(answer: (shoulder: Vector3, direction: Vector3) -> boolean)
			armClearAnswer = answer
		end,
		armClearCalls = armClearCalls,
		advance = function(seconds: number)
			clock += seconds
			step:Fire(seconds)
		end,
		fire = function(mark: number, kind: string?)
			warning:Fire(mark, kind)
		end,
		setState = function(meter: number, phase: string)
			state:SetAttribute("Meter", meter)
			state:SetAttribute("Phase", phase)
			task.wait() -- attribute changes reach listeners a moment after they are set
		end,
		armStart = armStart,
		leftStart = leftStart,
		rightStart = rightStart,
		head = head,
		cap = cap,
		awakeEyes = awakeEyes,
		awakeParts = awakeParts,
		stray = stray,
		sleepParts = sleepParts,
		sleepLooks = sleepLooks,
		headStart = headStart,
		capStart = capStart,
		awakeEyesStart = awakeEyesStart,
	}
end

-- True when two places are the same within 0.001 studs: the same spot, and the same turn (two points off to the side
-- of each must land together).
local function samePlace(first: CFrame, second: CFrame): boolean
	for _, offset in { Vector3.zero, Vector3.new(5, 0, 0), Vector3.new(0, 5, 0), Vector3.new(0, 0, 5) } do
		if (first:PointToWorldSpace(offset) - second:PointToWorldSpace(offset)).Magnitude > 1e-3 then
			return false
		end
	end
	return true
end

describe("GiantFx.warningPlan", function()
	it("at 60 flutters the eyelids and fades the Z Z Z", function()
		expect(GiantFx.warningPlan(60)).toEqual({ "flutterEyelids", "fadeLetters" })
	end)

	it("at 85 stops the Z Z Z and puffs, mumbles, snorts twice, glows Tiptoe and shows the tip", function()
		expect(GiantFx.warningPlan(85)).toEqual({
			"stopLetters",
			"stopPuffs",
			"mumbleBubble",
			"snortNose",
			"tiptoeGlow",
			"standStillTip",
		})
	end)

	it("at 85 has no arm twitch (Rule 100: nothing he sleeps on moves)", function()
		expect(table.find(GiantFx.warningPlan(85), "twitchArm")).toBe(nil)
	end)

	it("does nothing for any other mark", function()
		expect(GiantFx.warningPlan(50)).toEqual({})
		expect(GiantFx.warningPlan(0)).toEqual({})
		expect(GiantFx.warningPlan("85")).toEqual({})
		expect(GiantFx.warningPlan(nil)).toEqual({})
	end)
end)

describe("GiantFx.flutterLift", function()
	it("is 0 at the start", function()
		expect(GiantFx.flutterLift(0, 1.4)).toBe(0)
	end)

	it("is the whole 1.4 at the top of each flutter, 0.25 s and 0.75 s in", function()
		expect(GiantFx.flutterLift(0.25, 1.4)).toBeCloseTo(1.4, 6)
		expect(GiantFx.flutterLift(0.75, 1.4)).toBeCloseTo(1.4, 6)
	end)

	it("is back at 0 between the two flutters, 0.5 s in", function()
		expect(GiantFx.flutterLift(0.5, 1.4)).toBeCloseTo(0, 6)
	end)

	it("is 0 at 1 s and after", function()
		expect(GiantFx.flutterLift(1, 1.4)).toBe(0)
		expect(GiantFx.flutterLift(5, 1.4)).toBe(0)
	end)

	it("eases: a tenth of the way up it has lifted far less than a tenth of the way", function()
		local lift = GiantFx.flutterLift(0.025, 1.4)
		expect(lift > 0).toBe(true)
		expect(lift < 0.14).toBe(true)
	end)
end)

describe("GiantFx snort settings", function()
	it("has bursts of 20 puffs, 0.5 seconds apart (style guide, the snort)", function()
		expect(GiantFx.snortPuffs).toBe(20)
		expect(GiantFx.snortGapSeconds).toBe(0.5)
	end)

	it("no longer has the arm twitch", function()
		expect((GiantFx :: any).twitchAngle).toBe(nil)
		expect((GiantFx :: any).twitchDegrees).toBe(nil)
	end)
end)

describe("GiantFx.fadedTransparency", function()
	it("takes a letter at 0.05 to half from 0.2 s to 1.8 s", function()
		expect(GiantFx.fadedTransparency(0.05, 0.2)).toBeCloseTo(0.5, 6)
		expect(GiantFx.fadedTransparency(0.05, 1)).toBeCloseTo(0.5, 6)
		expect(GiantFx.fadedTransparency(0.05, 1.8)).toBeCloseTo(0.5, 6)
	end)

	it("is about halfway, 0.275, 0.1 s into the fade, and again 0.1 s before the end", function()
		expect(GiantFx.fadedTransparency(0.05, 0.1)).toBeCloseTo(0.275, 6)
		expect(GiantFx.fadedTransparency(0.05, 1.9)).toBeCloseTo(0.275, 6)
	end)

	it("is the normal 0.05 at the start, at 2 s and after", function()
		expect(GiantFx.fadedTransparency(0.05, 0)).toBe(0.05)
		expect(GiantFx.fadedTransparency(0.05, 2)).toBe(0.05)
		expect(GiantFx.fadedTransparency(0.05, 9)).toBe(0.05)
	end)

	it("takes an outline at 0 to half at the hold and back to 0 at 2 s", function()
		expect(GiantFx.fadedTransparency(0, 1)).toBeCloseTo(0.5, 6)
		expect(GiantFx.fadedTransparency(0, 2)).toBe(0)
	end)
end)

describe("GiantFx.fadedInTransparency", function()
	it("starts fully see-through, is half way at 0.1 s, and is the normal look from 0.2 s", function()
		expect(GiantFx.fadedInTransparency(0.05, 0)).toBe(1)
		expect(GiantFx.fadedInTransparency(0.05, 0.1)).toBeCloseTo(0.525, 6)
		expect(GiantFx.fadedInTransparency(0.05, 0.2)).toBe(0.05)
		expect(GiantFx.fadedInTransparency(0.05, 5)).toBe(0.05)
	end)

	it("takes an outline at 0 from fully see-through to 0 over 0.2 s", function()
		expect(GiantFx.fadedInTransparency(0, 0)).toBe(1)
		expect(GiantFx.fadedInTransparency(0, 0.1)).toBeCloseTo(0.5, 6)
		expect(GiantFx.fadedInTransparency(0, 0.2)).toBe(0)
	end)
end)

describe("GiantFx.start: the 60 warning", function()
	it("lifts both lids 1.4 studs at the top of a flutter and shows the white slice", function()
		local rig = newRig()
		rig.fire(60)
		rig.advance(0.25)
		expect(rig.leftLid:GetPivot().Position.Y - rig.leftStart.Position.Y).toBeCloseTo(1.4, 4)
		expect(rig.rightLid:GetPivot().Position.Y - rig.rightStart.Position.Y).toBeCloseTo(1.4, 4)
		expect(rig.leftSliver.Transparency).toBe(0)
	end)

	it("puts the lids back exactly at the start, and hides the slice again, after the two flutters", function()
		local rig = newRig()
		rig.fire(60)
		rig.advance(0.25)
		rig.advance(0.25)
		rig.advance(0.25)
		rig.advance(0.25)
		expect(rig.leftLid:GetPivot() == rig.leftStart).toBe(true)
		expect(rig.rightLid:GetPivot() == rig.rightStart).toBe(true)
		expect(rig.leftSliver.Transparency).toBe(1)
	end)

	it("lifts the lids straight up and only up", function()
		local rig = newRig()
		rig.fire(60)
		rig.advance(0.25)
		local now = rig.leftLid:GetPivot().Position
		expect(now.X).toBeCloseTo(rig.leftStart.Position.X, 5)
		expect(now.Z).toBeCloseTo(rig.leftStart.Position.Z, 5)
	end)

	it("leaves the lids exactly where they started after two 60 warnings back to back", function()
		local rig = newRig()
		rig.fire(60)
		rig.advance(0.3)
		rig.fire(60) -- a second one while the first is still lifting
		rig.advance(0.4)
		rig.advance(0.4)
		rig.advance(0.4)
		rig.advance(0.4)
		rig.fire(60)
		rig.advance(0.6)
		rig.advance(0.6)
		expect(rig.leftLid:GetPivot() == rig.leftStart).toBe(true)
		expect(rig.rightLid:GetPivot() == rig.rightStart).toBe(true)
		expect(rig.leftSliver.Transparency).toBe(1)
	end)

	it("fades every letter and outline to half and back to normal over 2 seconds", function()
		local rig = newRig()
		rig.fire(60)
		rig.advance(1)
		for index, letter in rig.letters do
			expect(letter.TextTransparency).toBeCloseTo(0.5, 6)
			expect(rig.outlines[index].Transparency).toBeCloseTo(0.5, 6)
		end
		rig.advance(1)
		for index, letter in rig.letters do
			expect(letter.TextTransparency).toBe(rig.normalLetters[index])
			expect(rig.outlines[index].Transparency).toBe(0)
		end
	end)

	it("keeps the Z Z Z and puffs on and moves no arm and shows no bubble", function()
		local rig = newRig()
		rig.fire(60)
		rig.advance(0.25)
		expect(rig.floatingZ.Enabled).toBe(true)
		expect(rig.puff.Enabled).toBe(true)
		expect(rig.bubble.Enabled).toBe(false)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
	end)
end)

describe("GiantFx.start: the 85 warning", function()
	it("turns the Z Z Z and the puffs off", function()
		local rig = newRig()
		rig.fire(85)
		expect(rig.floatingZ.Enabled).toBe(false)
		expect(rig.puff.Enabled).toBe(false)
	end)

	it("shows the bubble for 3 seconds and fades it out until 3.3 s: still there at 3.2 s, gone after 3.3 s", function()
		local rig = newRig()
		rig.fire(85)
		expect(rig.bubble.Enabled).toBe(true)
		rig.advance(2.9)
		expect(rig.bubble.Enabled).toBe(true)
		rig.advance(0.3)
		expect(rig.bubble.Enabled).toBe(true)
		rig.advance(0.11)
		expect(rig.bubble.Enabled).toBe(false)
	end)

	it("starts the bubble's time again when a second 85 comes while it shows", function()
		local rig = newRig()
		rig.fire(85)
		rig.advance(2)
		rig.fire(85)
		rig.advance(2)
		expect(rig.bubble.Enabled).toBe(true)
		rig.advance(1.31)
		expect(rig.bubble.Enabled).toBe(false)
	end)

	it("never moves the right arm: it is exactly at the start at 0, 0.25, 0.5 and 1 second", function()
		local rig = newRig()
		rig.fire(85)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		rig.advance(0.25)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		rig.advance(0.25)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		rig.advance(0.5)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
	end)

	it(
		"snorts a burst of 20 puffs at the warning and another of 20 at 0.5 seconds, and no third by 2 seconds",
		function()
			local rig = newRig()
			rig.fire(85)
			expect(#rig.bursts).toBe(1)
			expect(rig.bursts[1].count).toBe(20)
			expect(rig.bursts[1].at).toBeCloseTo(0, 6)
			expect(rig.bursts[1].emitter).toBe(rig.snortPuff)
			rig.advance(0.25)
			expect(#rig.bursts).toBe(1)
			rig.advance(0.25)
			expect(#rig.bursts).toBe(2)
			expect(rig.bursts[2].count).toBe(20)
			expect(rig.bursts[2].at).toBeCloseTo(0.5, 6)
			rig.advance(0.5)
			rig.advance(0.5)
			rig.advance(0.5)
			expect(#rig.bursts).toBe(2)
		end
	)

	it("makes only one burst when he wakes 0.3 seconds after the warning", function()
		local rig = newRig()
		rig.fire(85)
		rig.advance(0.3)
		rig.setState(100, "Awake")
		rig.advance(0.5)
		rig.advance(1)
		expect(#rig.bursts).toBe(1)
	end)

	it("makes only one burst when the module is stopped 0.3 seconds after the warning", function()
		local rig = newRig()
		rig.fire(85)
		rig.advance(0.3)
		rig.handle.stop()
		rig.advance(0.5)
		expect(#rig.bursts).toBe(1)
	end)

	it("snorts also when the nose streams in between the two bursts: the second burst finds it", function()
		local rig = newRig(nil, nil, false)
		rig.fire(85)
		expect(#rig.bursts).toBe(0)
		rig.advance(0.25)
		local nose = Instance.new("Part")
		nose.Name = "SnortNose"
		nose.Parent = rig.fx
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "SnortPuff"
		emitter.Parent = nose
		rig.advance(0.25)
		expect(#rig.bursts).toBe(1)
		expect(rig.bursts[1].emitter).toBe(emitter)
	end)

	it(
		"still runs the rest of the plan with no nose in the world: the bubble shows, the Z Z Z stay off, and no error",
		function()
			local rig = newRig(nil, nil, false)
			rig.fire(85)
			expect(#rig.bursts).toBe(0)
			expect(rig.bubble.Enabled).toBe(true)
			expect(rig.floatingZ.Enabled).toBe(false)
			expect(rig.puff.Enabled).toBe(false)
			rig.advance(0.5)
			rig.advance(2.81)
			expect(#rig.bursts).toBe(0)
			expect(rig.bubble.Enabled).toBe(false)
			expect(rig.step:count()).toBe(0)
		end
	)

	it("skips a burst when SnortPuff is not a ParticleEmitter", function()
		local rig = newRig()
		local snortPuff = rig.snortPuff :: ParticleEmitter
		local parent = snortPuff.Parent
		snortPuff:Destroy()
		local wrong = Instance.new("Folder")
		wrong.Name = "SnortPuff"
		wrong.Parent = parent
		rig.fire(85)
		rig.advance(0.5)
		expect(#rig.bursts).toBe(0)
	end)

	it("keeps the step connected until the second burst is done", function()
		local rig = newRig()
		rig.fire(85)
		expect(rig.step:count()).toBe(1)
		rig.advance(0.5)
		expect(#rig.bursts).toBe(2)
	end)

	it("leaves the arm exactly at the start after two 85 warnings back to back", function()
		local rig = newRig()
		rig.fire(85)
		rig.advance(0.3)
		rig.fire(85)
		rig.advance(0.5)
		rig.advance(0.5)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
	end)

	it("does not move the lids", function()
		local rig = newRig()
		rig.fire(85)
		rig.advance(0.25)
		expect(rig.leftLid:GetPivot() == rig.leftStart).toBe(true)
	end)

	it("does nothing for any other mark", function()
		local rig = newRig()
		rig.fire(50)
		rig.fire(86)
		expect(rig.step:count()).toBe(0)
		expect(rig.floatingZ.Enabled).toBe(true)
		expect(rig.bubble.Enabled).toBe(false)
	end)
end)

-- The 85% bubble beside his nose (V2 spec 1, Rule 17: A free save replays the 85% warning, section 5 "The 85% bubble's
-- size and spot"). The maths is in Bubble85 (its own tests); here the module places the real bubble.
describe("GiantFx.start: the 85 bubble beside his nose", function()
	local function near(actual: number, wanted: number): boolean
		return math.abs(actual - wanted) < 0.01
	end

	-- How see-through every part of the bubble is: the pill, its outline, the words, the tail and its outline.
	local function seeThrough(rig: Rig): { number }
		return {
			rig.bubbleFrame.BackgroundTransparency,
			rig.bubbleStrokes[1].Transparency,
			rig.bubbleWords.TextTransparency,
			rig.bubbleTail.BackgroundTransparency,
			rig.bubbleStrokes[2].Transparency,
		}
	end

	it("turns the bubble on at an 85 warning and off when he wakes", function()
		local rig = newRig()
		expect(rig.bubble.Enabled).toBe(false)
		rig.fire(85)
		expect(rig.bubble.Enabled).toBe(true)
		rig.advance(1)
		rig.setState(100, "Awake")
		expect(rig.bubble.Enabled).toBe(false)
	end)

	it("starts from nothing, is 110% at 0.1 s and settles at exactly 100% at 0.2 s (computer)", function()
		local rig = newRig()
		rig.fire(85)
		expect(rig.bubble.Size).toEqual(UDim2.fromOffset(0, 0))
		rig.advance(0.1)
		expect(rig.bubble.Size).toEqual(UDim2.fromOffset(187, 57))
		expect(rig.bubbleWords.TextSize).toBe(22)
		rig.advance(0.1)
		expect(rig.bubble.Size).toEqual(UDim2.fromOffset(170, 52))
		expect(rig.bubbleWords.TextSize).toBe(20)
	end)

	it("gets the computer size, 170 by 52 px with words at font size 20 on one line", function()
		local rig = newRig()
		rig.fire(85)
		rig.advance(0.3)
		expect(rig.bubble.Size).toEqual(UDim2.fromOffset(170, 52))
		expect(rig.bubbleWords.TextSize).toBe(20)
		expect(rig.bubbleWords.TextScaled).toBe(false)
		expect(rig.bubbleWords.TextWrapped).toBe(false)
	end)

	it("gets the phone size, 120 by 40 px with words at font size 14 on one line, when isPhone says true", function()
		local rig = newRig()
		rig.setPhone(true)
		rig.fire(85)
		rig.advance(0.3)
		expect(rig.bubble.Size).toEqual(UDim2.fromOffset(120, 40))
		expect(rig.bubbleWords.TextSize).toBe(14)
		expect(rig.bubbleWords.TextScaled).toBe(false)
		expect(rig.bubbleWords.TextWrapped).toBe(false)
	end)

	it("asks isPhone again each frame, so turning the phone sideways or a new window size counts", function()
		local rig = newRig()
		rig.fire(85)
		rig.advance(0.3)
		expect(rig.bubble.Size).toEqual(UDim2.fromOffset(170, 52))
		rig.setPhone(true)
		rig.advance(0.1)
		expect(rig.bubble.Size).toEqual(UDim2.fromOffset(120, 40))
	end)

	it("goes left of his nose, tail bottom-right, when the camera's RightVector.Z is above 0", function()
		local rig = newRig()
		rig.setCameraRightZ(0.6)
		rig.fire(85)
		expect(rig.bubble.StudsOffset).toEqual(Vector3.new(-14, -3, 2))
		expect(rig.bubble.SizeOffset).toEqual(Vector2.new(-0.5, 0.5))
		expect(rig.bubbleTail.Position).toEqual(UDim2.fromScale(0.93, 0.93))
	end)

	it("goes right of his nose, tail bottom-left, when the camera's RightVector.Z is 0 or below", function()
		local rig = newRig()
		rig.setCameraRightZ(-0.6)
		rig.fire(85)
		expect(rig.bubble.StudsOffset).toEqual(Vector3.new(14, -3, 2))
		expect(rig.bubble.SizeOffset).toEqual(Vector2.new(0.5, 0.5))
		expect(rig.bubbleTail.Position).toEqual(UDim2.fromScale(0.07, 0.93))
	end)

	it("switches side while it shows when the camera's RightVector.Z changes sign", function()
		local rig = newRig()
		rig.setCameraRightZ(-0.6)
		rig.fire(85)
		expect(rig.bubble.StudsOffset).toEqual(Vector3.new(14, -3, 2))
		rig.setCameraRightZ(0.6)
		rig.advance(0.5)
		expect(rig.bubble.StudsOffset).toEqual(Vector3.new(-14, -3, 2))
		expect(rig.bubble.SizeOffset).toEqual(Vector2.new(-0.5, 0.5))
		expect(rig.bubbleTail.Position).toEqual(UDim2.fromScale(0.93, 0.93))
		rig.setCameraRightZ(0)
		rig.advance(0.5)
		expect(rig.bubble.StudsOffset).toEqual(Vector3.new(14, -3, 2))
		expect(rig.bubbleTail.Position).toEqual(UDim2.fromScale(0.07, 0.93))
	end)

	it("is solid until 3 s, half see-through at 3.15 s and gone at 3.3 s", function()
		local rig = newRig()
		rig.fire(85)
		rig.advance(3)
		expect(seeThrough(rig)).toEqual({ 0, 0, 0, 0, 0 })
		rig.advance(0.15)
		expect(near(rig.bubbleFrame.BackgroundTransparency, 0.5)).toBe(true)
		expect(near(rig.bubbleStrokes[1].Transparency, 0.5)).toBe(true)
		expect(near(rig.bubbleWords.TextTransparency, 0.5)).toBe(true)
		expect(near(rig.bubbleTail.BackgroundTransparency, 0.5)).toBe(true)
		expect(near(rig.bubbleStrokes[2].Transparency, 0.5)).toBe(true)
		expect(rig.bubble.Enabled).toBe(true)
		rig.advance(0.16)
		expect(rig.bubble.Enabled).toBe(false)
	end)

	it("is solid again, at full size from the pop's start, when a second warning comes after it faded", function()
		local rig = newRig()
		rig.fire(85)
		rig.advance(3.31)
		rig.fire(85, "FreeSave")
		expect(rig.bubble.Enabled).toBe(true)
		expect(rig.bubble.Size).toEqual(UDim2.fromOffset(0, 0))
		expect(rig.bubbleFrame.BackgroundTransparency).toBe(0)
		expect(rig.bubbleWords.TextTransparency).toBe(0)
		expect(rig.bubbleStrokes[1].Transparency).toBe(0)
	end)

	it("pops again from nothing on a replayed warning, also while it still shows", function()
		local rig = newRig()
		rig.fire(85)
		rig.advance(1)
		expect(rig.bubble.Size).toEqual(UDim2.fromOffset(170, 52))
		rig.fire(85, "FreeSave")
		expect(rig.bubble.Size).toEqual(UDim2.fromOffset(0, 0))
		rig.advance(0.1)
		expect(rig.bubble.Size).toEqual(UDim2.fromOffset(187, 57))
	end)

	it("just appears at full size and goes at 3 s, with no fade, when Reduce Motion is on", function()
		local rig = newRig()
		rig.setReducedMotion(true)
		rig.fire(85)
		expect(rig.bubble.Size).toEqual(UDim2.fromOffset(170, 52))
		expect(rig.bubbleWords.TextSize).toBe(20)
		rig.advance(2.9)
		expect(rig.bubble.Enabled).toBe(true)
		expect(rig.bubbleFrame.BackgroundTransparency).toBe(0)
		rig.advance(0.11)
		expect(rig.bubble.Enabled).toBe(false)
	end)

	it("puts the bubble back as it was when stopped while it shows", function()
		local rig = newRig()
		rig.setCameraRightZ(0.6)
		rig.fire(85)
		rig.advance(3.2)
		rig.handle.stop()
		expect(rig.bubble.Enabled).toBe(false)
		expect(rig.bubble.Size).toEqual(UDim2.fromScale(41.6, 14.4))
		expect(rig.bubble.StudsOffset).toEqual(Vector3.new(14, -3, 2))
		expect(rig.bubble.SizeOffset).toEqual(Vector2.new(0.5, 0.5))
		expect(rig.bubbleWords.TextScaled).toBe(true)
		expect(rig.bubbleWords.TextWrapped).toBe(true)
		expect(rig.bubbleWords.TextSize).toBe(8)
		expect(rig.bubbleTail.Position).toEqual(UDim2.fromScale(0.07, 0.93))
		expect(rig.bubbleFrame.BackgroundTransparency).toBe(0)
		expect(rig.bubbleWords.TextTransparency).toBe(0)
		expect(rig.bubbleStrokes[1].Transparency).toBe(0)
		expect(rig.bubbleTail.BackgroundTransparency).toBe(0)
		expect(rig.bubbleStrokes[2].Transparency).toBe(0)
	end)

	it("shows nothing and raises no error when the bubble is missing from the world", function()
		local rig = newRig()
		rig.bubble.Parent = nil
		rig.fire(85)
		rig.advance(1)
		expect(rig.bubble.Enabled).toBe(false)
	end)

	it("ignores an old MumbleAnchor.Mumble: only Warning85Bubble is the bubble", function()
		local rig = newRig()
		local oldAnchor = Instance.new("Part")
		oldAnchor.Name = "MumbleAnchor"
		oldAnchor.Parent = rig.fx
		local oldBubble = Instance.new("BillboardGui")
		oldBubble.Name = "Mumble"
		oldBubble.Enabled = false
		oldBubble.Parent = oldAnchor
		rig.fire(85)
		expect(oldBubble.Enabled).toBe(false)
		expect(rig.bubble.Enabled).toBe(true)
	end)
end)

-- A free save replays the 85 warning (Rule 17): the server fires Warning with (85, "FreeSave") and sets the Meter to 70.
-- The Z Z Z and puffs stay off until the replayed warning has finished, then fade back in over 0.2 seconds, but only if
-- the Meter is at 75 or less.
describe("GiantFx.start: the replayed 85 warning", function()
	it("never moves the right arm: it is exactly at the start at 0, 0.25, 0.5 and 1 second", function()
		local rig = newRig()
		rig.setState(70, "Asleep")
		rig.fire(85, "FreeSave")
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		rig.advance(0.25)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		rig.advance(0.25)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		rig.advance(0.5)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
	end)

	it("snorts two bursts of 20 puffs, 0.5 seconds apart, also when it is the first warning", function()
		local rig = newRig()
		rig.setState(70, "Asleep")
		rig.fire(85, "FreeSave")
		rig.advance(0.5)
		rig.advance(1.5)
		expect(#rig.bursts).toBe(2)
		expect(rig.bursts[1].count).toBe(20)
		expect(rig.bursts[1].at).toBeCloseTo(0, 6)
		expect(rig.bursts[2].count).toBe(20)
		expect(rig.bursts[2].at).toBeCloseTo(0.5, 6)
	end)

	it("starts the snort again from the start when it comes 0.2 seconds after a plain 85", function()
		local rig = newRig()
		rig.fire(85)
		rig.advance(0.2)
		rig.fire(85, "FreeSave")
		rig.advance(0.49) -- 0.69 s after the first warning: the first warning's second burst (0.5 s) was cancelled
		expect(#rig.bursts).toBe(2)
		expect(rig.bursts[1].at).toBeCloseTo(0, 6)
		expect(rig.bursts[2].at).toBeCloseTo(0.2, 6)
		rig.advance(0.02) -- 0.71 s: 0.5 s after the replay
		expect(#rig.bursts).toBe(3)
		expect(rig.bursts[3].at).toBeCloseTo(0.71, 6)
		rig.advance(2)
		expect(#rig.bursts).toBe(3)
	end)

	it("starts the bubble's time again when the replay comes while the bubble shows", function()
		local rig = newRig()
		rig.fire(85)
		rig.advance(2)
		rig.fire(85, "FreeSave")
		rig.advance(2)
		expect(rig.bubble.Enabled).toBe(true)
		rig.advance(1.31)
		expect(rig.bubble.Enabled).toBe(false)
	end)

	it("turns the Z Z Z and the puffs off and shows the bubble, also when it is the first warning", function()
		local rig = newRig()
		rig.setState(70, "Asleep")
		rig.fire(85, "FreeSave")
		expect(rig.floatingZ.Enabled).toBe(false)
		expect(rig.puff.Enabled).toBe(false)
		expect(rig.bubble.Enabled).toBe(true)
	end)

	it("keeps the Z Z Z and the puffs off for 3 seconds at a Meter of 70, even when the Meter changes", function()
		local rig = newRig()
		rig.setState(70, "Asleep")
		rig.fire(85, "FreeSave")
		rig.advance(1)
		rig.setState(66, "Asleep")
		expect(rig.floatingZ.Enabled).toBe(false)
		expect(rig.puff.Enabled).toBe(false)
		rig.advance(1.9)
		expect(rig.floatingZ.Enabled).toBe(false)
		expect(rig.puff.Enabled).toBe(false)
	end)

	it("brings the Z Z Z and the puffs back at 3 seconds, fading the letters in over 0.2 seconds", function()
		local rig = newRig()
		rig.setState(70, "Asleep")
		rig.fire(85, "FreeSave")
		rig.advance(2.9)
		rig.advance(0.1)
		expect(rig.floatingZ.Enabled).toBe(true)
		expect(rig.puff.Enabled).toBe(true)
		-- The letters start fully see-through ...
		for index, letter in rig.letters do
			expect(letter.TextTransparency).toBeCloseTo(1, 3)
			expect(rig.outlines[index].Transparency).toBeCloseTo(1, 3)
		end
		-- ... are half way back to their own look at 0.1 s ...
		rig.advance(0.1)
		for index, letter in rig.letters do
			local normal = rig.normalLetters[index]
			expect(letter.TextTransparency).toBeCloseTo(normal + (1 - normal) / 2, 3)
			expect(rig.outlines[index].Transparency).toBeCloseTo(0.5, 3)
		end
		-- ... at their own look at 0.2 s (the fake clock adds up with a tiny rounding error, so this is close, not exact) ...
		rig.advance(0.1)
		for index, letter in rig.letters do
			expect(letter.TextTransparency).toBeCloseTo(rig.normalLetters[index], 6)
			expect(rig.outlines[index].Transparency).toBeCloseTo(0, 6)
		end
		-- ... and exactly at their own look right after.
		rig.advance(0.01)
		for index, letter in rig.letters do
			expect(letter.TextTransparency).toBe(rig.normalLetters[index])
			expect(rig.outlines[index].Transparency).toBe(0)
		end
	end)

	it("lets go of the step when the bubble and the fade-in are both over", function()
		local rig = newRig()
		rig.setState(70, "Asleep")
		rig.fire(85, "FreeSave")
		expect(rig.step:count()).toBe(1)
		rig.advance(3)
		expect(rig.step:count()).toBe(1) -- the fade-in is still playing
		rig.advance(0.2)
		expect(rig.step:count()).toBe(1) -- and the bubble is still fading out
		rig.advance(0.11)
		expect(rig.step:count()).toBe(0)
	end)

	it("keeps the Z Z Z off after 3 seconds when the Meter is 78, until it falls to 75", function()
		local rig = newRig()
		rig.setState(78, "Asleep")
		rig.fire(85, "FreeSave")
		rig.advance(3)
		rig.advance(1)
		expect(rig.floatingZ.Enabled).toBe(false)
		expect(rig.puff.Enabled).toBe(false)
		rig.setState(76, "Asleep")
		expect(rig.floatingZ.Enabled).toBe(false)
		rig.setState(75, "Asleep")
		expect(rig.floatingZ.Enabled).toBe(true)
		expect(rig.puff.Enabled).toBe(true)
		-- As today, they are simply back at their own look.
		for index, letter in rig.letters do
			expect(letter.TextTransparency).toBe(rig.normalLetters[index])
		end
	end)

	it("keeps them off after the 3 seconds at a Meter of 90, and brings them back when it falls", function()
		local rig = newRig()
		rig.setState(90, "Asleep")
		rig.fire(85, "FreeSave")
		rig.advance(3)
		expect(rig.floatingZ.Enabled).toBe(false)
		rig.setState(60, "Asleep")
		expect(rig.floatingZ.Enabled).toBe(true)
	end)

	it("starts the 3 seconds again when a second replay comes during them", function()
		local rig = newRig()
		rig.setState(70, "Asleep")
		rig.fire(85, "FreeSave")
		rig.advance(2)
		rig.fire(85, "FreeSave")
		rig.advance(2)
		expect(rig.floatingZ.Enabled).toBe(false)
		rig.advance(1)
		expect(rig.floatingZ.Enabled).toBe(true)
	end)

	it("brings nothing back when he wakes during the 3 seconds", function()
		local rig = newRig()
		rig.setState(70, "Asleep")
		rig.fire(85, "FreeSave")
		rig.advance(1)
		rig.setState(100, "Awake")
		rig.advance(2)
		rig.advance(1)
		expect(rig.floatingZ.Enabled).toBe(false)
		expect(rig.puff.Enabled).toBe(false)
		expect(rig.bubble.Enabled).toBe(false)
	end)

	it("puts the letters back at their own look when he wakes during the fade-in", function()
		local rig = newRig()
		rig.setState(70, "Asleep")
		rig.fire(85, "FreeSave")
		rig.advance(3)
		rig.advance(0.05)
		rig.setState(100, "Awake")
		for index, letter in rig.letters do
			expect(letter.TextTransparency).toBe(rig.normalLetters[index])
			expect(rig.outlines[index].Transparency).toBe(0)
		end
		expect(rig.floatingZ.Enabled).toBe(false)
	end)

	it("puts everything back as it was when stopped during the 3 seconds", function()
		local rig = newRig()
		rig.setState(70, "Asleep")
		rig.fire(85, "FreeSave")
		rig.advance(1)
		rig.handle.stop()
		expect(rig.floatingZ.Enabled).toBe(true)
		expect(rig.puff.Enabled).toBe(true)
		expect(rig.bubble.Enabled).toBe(false)
		expect(rig.step:count()).toBe(0)
	end)

	it("leaves a plain 85 as it was: the Z Z Z do not come back with time, only with the Meter", function()
		local rig = newRig()
		rig.setState(70, "Asleep")
		rig.fire(85)
		rig.advance(3)
		rig.advance(5)
		expect(rig.floatingZ.Enabled).toBe(false)
		expect(rig.puff.Enabled).toBe(false)
		rig.setState(69, "Asleep")
		expect(rig.floatingZ.Enabled).toBe(true)
	end)

	it("does nothing for a second value that is not FreeSave", function()
		local rig = newRig()
		rig.setState(70, "Asleep")
		rig.fire(85, "Something")
		rig.fire(60, "Something")
		expect(rig.step:count()).toBe(0)
		expect(rig.floatingZ.Enabled).toBe(true)
		expect(rig.puff.Enabled).toBe(true)
		expect(rig.bubble.Enabled).toBe(false)
		rig.advance(5)
		expect(rig.floatingZ.Enabled).toBe(true)
	end)
end)

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

describe("GiantFx.poseShare", function()
	it("is 0 at 0 seconds and before", function()
		expect(GiantFx.poseShare(0)).toBe(0)
		expect(GiantFx.poseShare(-1)).toBe(0)
	end)

	it("is 1 at 0.5 seconds and after", function()
		expect(GiantFx.poseSeconds).toBe(0.5)
		expect(GiantFx.poseShare(0.5)).toBe(1)
		expect(GiantFx.poseShare(0.6)).toBe(1)
		expect(GiantFx.poseShare(9)).toBe(1)
	end)

	it("is smooth: 0.5 at 0.25 seconds, and slow at the start", function()
		expect(GiantFx.poseShare(0.25)).toBeCloseTo(0.5, 6)
		expect(GiantFx.poseShare(0.05) < 0.1).toBe(true)
	end)
end)

describe("GiantFx.headTurn", function()
	local pivot = Vector3.new(0, 78, 18)

	it("at share 1 turns a point about the head pivot by the full tilt", function()
		local turn = GiantFx.headTurn(pivot, -12, 1)
		local probe = Vector3.new(3, 90, 30)
		local expected = pivot + CFrame.Angles(math.rad(-12), 0, 0):VectorToWorldSpace(probe - pivot)
		expect((turn:PointToWorldSpace(probe) - expected).Magnitude < 1e-3).toBe(true)
	end)

	it("keeps the pivot point where it is", function()
		local turn = GiantFx.headTurn(pivot, -12, 1)
		expect((turn:PointToWorldSpace(pivot) - pivot).Magnitude < 1e-3).toBe(true)
	end)

	it("at share 0 moves nothing", function()
		local turn = GiantFx.headTurn(pivot, -12, 0)
		for _, probe in { Vector3.zero, Vector3.new(3, 90, 30), Vector3.new(-40, 5, 9) } do
			expect((turn:PointToWorldSpace(probe) - probe).Magnitude < 1e-3).toBe(true)
		end
	end)

	it("at share 0.5 turns half the tilt", function()
		local turn = GiantFx.headTurn(pivot, -12, 0.5)
		local _, angle = turn:ToAxisAngle()
		expect(math.deg(angle)).toBeCloseTo(6, 3)
	end)
end)

describe("GiantFx.armRaise", function()
	local shoulder = Vector3.new(40, 58, 8)
	local raise = Vector3.new(135, 0, 15)
	local full = CFrame.Angles(math.rad(135), 0, math.rad(15))

	it("at share 1 turns a point about the shoulder by the full raise", function()
		local turn = GiantFx.armRaise(shoulder, raise, 1)
		for _, probe in { Vector3.new(41, 68, 8), Vector3.new(45, 40, 20) } do
			local expected = shoulder + full:VectorToWorldSpace(probe - shoulder)
			expect((turn:PointToWorldSpace(probe) - expected).Magnitude < 1e-3).toBe(true)
		end
	end)

	it("at share 0 moves nothing", function()
		local turn = GiantFx.armRaise(shoulder, raise, 0)
		for _, probe in { Vector3.zero, Vector3.new(41, 68, 8) } do
			expect((turn:PointToWorldSpace(probe) - probe).Magnitude < 1e-3).toBe(true)
		end
	end)

	it("at share 0.5 turns half the angle about the same axis as the full raise", function()
		local fullAxis, fullAngle = full:ToAxisAngle()
		local half = GiantFx.armRaise(shoulder, raise, 0.5)
		local axis, angle = half.Rotation:ToAxisAngle()
		expect(angle).toBeCloseTo(fullAngle / 2, 3)
		expect(axis:Dot(fullAxis)).toBeCloseTo(1, 3)
	end)

	it("keeps the shoulder point where it is", function()
		local turn = GiantFx.armRaise(shoulder, raise, 1)
		expect((turn:PointToWorldSpace(shoulder) - shoulder).Magnitude < 1e-3).toBe(true)
	end)

	it("moves nothing for a raise of no angle", function()
		local turn = GiantFx.armRaise(shoulder, Vector3.zero, 1)
		expect((turn:PointToWorldSpace(Vector3.new(41, 68, 8)) - Vector3.new(41, 68, 8)).Magnitude < 1e-3).toBe(true)
	end)
end)

describe("GiantFx.start: the waking pose", function()
	local function headGroup(rig: Rig): { { piece: Model, start: CFrame } }
		return {
			{ piece = rig.head, start = rig.headStart },
			{ piece = rig.cap, start = rig.capStart },
			{ piece = rig.leftLid, start = rig.leftStart },
			{ piece = rig.rightLid, start = rig.rightStart },
			{ piece = rig.awakeEyes, start = rig.awakeEyesStart },
		}
	end

	it("puts the head, the cap, both lids and the awake eyes at the full head tip after 0.5 seconds", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		local turn = GiantFx.headTurn(HEAD_PIVOT, HEAD_TILT_DEGREES, 1)
		for _, entry in headGroup(rig) do
			expect(samePlace(entry.piece:GetPivot(), turn * entry.start)).toBe(true)
		end
	end)

	it("puts the right arm at the full raise after 0.5 seconds", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		expect(samePlace(rig.arm:GetPivot(), GiantFx.armRaise(SHOULDER, RAISE_DEGREES, 1) * rig.armStart)).toBe(true)
	end)

	it("is half way, with the easing, at 0.25 seconds", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.25)
		local share = GiantFx.poseShare(0.25)
		expect(share).toBeCloseTo(0.5, 6)
		expect(samePlace(rig.head:GetPivot(), GiantFx.headTurn(HEAD_PIVOT, HEAD_TILT_DEGREES, share) * rig.headStart)).toBe(
			true
		)
		expect(samePlace(rig.arm:GetPivot(), GiantFx.armRaise(SHOULDER, RAISE_DEGREES, share) * rig.armStart)).toBe(
			true
		)
	end)

	it("does not move anything before the next step", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		expect(rig.head:GetPivot() == rig.headStart).toBe(true)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
	end)

	it("stays on the full pose on later steps", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		rig.advance(1)
		rig.advance(5)
		local turn = GiantFx.headTurn(HEAD_PIVOT, HEAD_TILT_DEGREES, 1)
		expect(samePlace(rig.head:GetPivot(), turn * rig.headStart)).toBe(true)
		expect(samePlace(rig.arm:GetPivot(), GiantFx.armRaise(SHOULDER, RAISE_DEGREES, 1) * rig.armStart)).toBe(true)
	end)

	it("swaps the eyes at once: the awake eyes show and every sleep eye part is hidden", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		for _, part in rig.awakeParts do
			expect(part.Transparency).toBe(0)
		end
		for _, part in rig.sleepParts do
			expect(part.Transparency).toBe(1)
		end
	end)

	it("shows only the awake eye parts that are marked ShownWhenAwake", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		expect(rig.stray.Transparency).toBe(1)
	end)

	it(
		"wakes from an 85 warning that is running: the arm ends on the full raise and nothing puts it back down",
		function()
			local rig = newRig()
			rig.fire(85)
			rig.advance(0.25) -- the 85 warning is running
			rig.setState(100, "Awake")
			rig.advance(0.5)
			rig.advance(2) -- the warning would have ended by now
			expect(samePlace(rig.arm:GetPivot(), GiantFx.armRaise(SHOULDER, RAISE_DEGREES, 1) * rig.armStart)).toBe(
				true
			)
		end
	)

	it("stops a flutter that is running: the lids end on the head tip alone and the slices are hidden", function()
		local rig = newRig()
		rig.fire(60)
		rig.advance(0.25) -- the lids are lifted
		rig.setState(100, "Awake")
		rig.advance(0.5)
		rig.advance(2) -- the flutter would have ended by now, and put the lids back at their start
		local turn = GiantFx.headTurn(HEAD_PIVOT, HEAD_TILT_DEGREES, 1)
		expect(samePlace(rig.leftLid:GetPivot(), turn * rig.leftStart)).toBe(true)
		expect(samePlace(rig.rightLid:GetPivot(), turn * rig.rightStart)).toBe(true)
		expect(rig.leftSliver.Transparency).toBe(1)
	end)

	it("ends the Z Z Z fade at once, with the letters at their normal looks", function()
		local rig = newRig()
		rig.fire(60)
		rig.advance(1)
		rig.setState(100, "Awake")
		for index, letter in rig.letters do
			expect(letter.TextTransparency).toBe(rig.normalLetters[index])
			expect(rig.outlines[index].Transparency).toBe(0)
		end
		rig.advance(2)
		for index, letter in rig.letters do
			expect(letter.TextTransparency).toBe(rig.normalLetters[index])
		end
	end)

	it("hides the mumble bubble at once, and it stays hidden", function()
		local rig = newRig()
		rig.fire(85)
		rig.advance(1)
		expect(rig.bubble.Enabled).toBe(true)
		rig.setState(100, "Awake")
		expect(rig.bubble.Enabled).toBe(false)
		rig.advance(5)
		expect(rig.bubble.Enabled).toBe(false)
	end)

	it("turns the Z Z Z and the puffs off even when there was no 85 warning", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		expect(rig.floatingZ.Enabled).toBe(false)
		expect(rig.puff.Enabled).toBe(false)
	end)

	it("keeps the Z Z Z and the puffs off for as long as he is awake, also when Meter changes", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.setState(40, "Awake")
		expect(rig.floatingZ.Enabled).toBe(false)
		expect(rig.puff.Enabled).toBe(false)
	end)

	it("gives a GiantFX that streams in during the wake-up the Z Z Z off state", function()
		local rig = newRig(false)
		rig.setState(100, "Awake")
		rig.fx.Parent = rig.world
		task.wait()
		expect(rig.floatingZ.Enabled).toBe(false)
		expect(rig.puff.Enabled).toBe(false)
	end)

	it("ignores a warning that arrives after he is awake", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.fire(85)
		rig.fire(60)
		rig.advance(0.5)
		expect(rig.bubble.Enabled).toBe(false)
		expect(samePlace(rig.arm:GetPivot(), GiantFx.armRaise(SHOULDER, RAISE_DEGREES, 1) * rig.armStart)).toBe(true)
		expect(rig.leftSliver.Transparency).toBe(1)
		expect(rig.step:count()).toBe(0)
	end)

	it("is connected to the step while the pose plays and let go of when it is over", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		expect(rig.step:count()).toBe(1)
		rig.advance(0.25)
		expect(rig.step:count()).toBe(1)
		rig.advance(0.25)
		expect(rig.step:count()).toBe(0)
	end)

	it("takes 0.5 seconds of the clock, however many frames that is", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		for _ = 1, 5 do
			rig.advance(0.1)
		end
		local turn = GiantFx.headTurn(HEAD_PIVOT, HEAD_TILT_DEGREES, 1)
		expect(samePlace(rig.head:GetPivot(), turn * rig.headStart)).toBe(true)
	end)

	it("does not move the giant's other pieces", function()
		local rig = newRig()
		local body = made(Instance.new("Model"))
		body.Name = "body_and_cushion"
		local bodyPart = Instance.new("Part")
		bodyPart.Anchored = true
		bodyPart.Parent = body
		body.Parent = rig.giant
		local before = body:GetPivot()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		expect(body:GetPivot() == before).toBe(true)
	end)

	it("skips pieces that are not there", function()
		local rig = newRig()
		rig.head.Parent = nil
		rig.awakeEyes.Parent = nil
		rig.arm.Parent = nil
		rig.setState(100, "Awake")
		rig.advance(0.5)
		expect(rig.step:count()).toBe(0)
	end)

	it("does not move the head when the giant has no head pivot, but still swaps the eyes", function()
		local rig = newRig()
		rig.giant:SetAttribute("Awake_HeadPivot", nil)
		rig.setState(100, "Awake")
		rig.advance(0.5)
		expect(rig.head:GetPivot() == rig.headStart).toBe(true)
		expect(rig.awakeParts[1].Transparency).toBe(0)
	end)
end)

describe("GiantFx.start: going back to sleep", function()
	it("swaps the eyes back at once, to each part's own look, with the slices still hidden", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		rig.setState(100, "HeavySleep")
		for _, part in rig.awakeParts do
			expect(part.Transparency).toBe(1)
		end
		for index, part in rig.sleepParts do
			expect(part.Transparency).toBe(rig.sleepLooks[index])
		end
		expect(rig.leftSliver.Transparency).toBe(1)
	end)

	it("puts every moved piece exactly back on its start pivot after 0.5 seconds", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		rig.setState(100, "HeavySleep")
		rig.advance(0.25)
		expect(rig.head:GetPivot() == rig.headStart).toBe(false) -- half way back
		rig.advance(0.25)
		expect(rig.head:GetPivot() == rig.headStart).toBe(true)
		expect(rig.cap:GetPivot() == rig.capStart).toBe(true)
		expect(rig.leftLid:GetPivot() == rig.leftStart).toBe(true)
		expect(rig.rightLid:GetPivot() == rig.rightStart).toBe(true)
		expect(rig.awakeEyes:GetPivot() == rig.awakeEyesStart).toBe(true)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		expect(rig.step:count()).toBe(0)
	end)

	it("goes back the same way for a reset to Asleep", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		rig.setState(0, "Asleep")
		rig.advance(0.5)
		expect(rig.head:GetPivot() == rig.headStart).toBe(true)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		expect(rig.floatingZ.Enabled).toBe(true)
	end)

	it("turns back from where it is when he falls asleep in the middle of the pose", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.25)
		rig.setState(100, "HeavySleep")
		rig.advance(0.25) -- as long as it had been going forward
		expect(rig.head:GetPivot() == rig.headStart).toBe(true)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
	end)

	it("brings the Z Z Z and the puffs back for Heavy Sleep when no warning had stopped them", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.setState(100, "HeavySleep")
		expect(rig.floatingZ.Enabled).toBe(true)
		expect(rig.puff.Enabled).toBe(true)
	end)

	it("brings the Z Z Z and the puffs back for Heavy Sleep after an 85 warning stopped them", function()
		local rig = newRig()
		rig.fire(85)
		rig.setState(100, "Awake")
		expect(rig.floatingZ.Enabled).toBe(false)
		rig.setState(100, "HeavySleep")
		expect(rig.floatingZ.Enabled).toBe(true)
		expect(rig.puff.Enabled).toBe(true)
	end)

	it("can wake him again after a return: the pose goes from the start pivots each time", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		rig.setState(100, "HeavySleep")
		rig.advance(0.5)
		rig.setState(0, "Asleep")
		rig.setState(100, "Awake")
		rig.advance(0.5)
		local turn = GiantFx.headTurn(HEAD_PIVOT, HEAD_TILT_DEGREES, 1)
		expect(samePlace(rig.head:GetPivot(), turn * rig.headStart)).toBe(true)
		expect(samePlace(rig.arm:GetPivot(), GiantFx.armRaise(SHOULDER, RAISE_DEGREES, 1) * rig.armStart)).toBe(true)
		for _, part in rig.awakeParts do
			expect(part.Transparency).toBe(0)
		end
	end)

	it("snorts and mumbles again after a return, and keeps the arm still", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		rig.setState(100, "HeavySleep")
		rig.advance(0.5)
		rig.setState(0, "Asleep")
		rig.advance(0.5)
		expect(samePlace(rig.arm:GetPivot(), rig.armStart)).toBe(true)
		rig.fire(85)
		rig.advance(0.5)
		expect(samePlace(rig.arm:GetPivot(), rig.armStart)).toBe(true)
		expect(#rig.bursts).toBe(2)
		expect(rig.bubble.Enabled).toBe(true)
	end)
end)

describe("GiantFx.start: already awake at the start", function()
	it("gives the full pose at once, with no motion, and nothing to step", function()
		local rig = newRig(nil, "Awake")
		local turn = GiantFx.headTurn(HEAD_PIVOT, HEAD_TILT_DEGREES, 1)
		expect(samePlace(rig.head:GetPivot(), turn * rig.headStart)).toBe(true)
		expect(samePlace(rig.arm:GetPivot(), GiantFx.armRaise(SHOULDER, RAISE_DEGREES, 1) * rig.armStart)).toBe(true)
		expect(rig.step:count()).toBe(0)
	end)

	it("still has the full pose on the first step", function()
		local rig = newRig(nil, "Awake")
		rig.advance(0.016)
		local turn = GiantFx.headTurn(HEAD_PIVOT, HEAD_TILT_DEGREES, 1)
		expect(samePlace(rig.head:GetPivot(), turn * rig.headStart)).toBe(true)
	end)

	it("has the eyes swapped and the Z Z Z off", function()
		local rig = newRig(nil, "Awake")
		for _, part in rig.awakeParts do
			expect(part.Transparency).toBe(0)
		end
		for _, part in rig.sleepParts do
			expect(part.Transparency).toBe(1)
		end
		expect(rig.floatingZ.Enabled).toBe(false)
		expect(rig.puff.Enabled).toBe(false)
	end)

	it("goes back to sleep over 0.5 seconds like any wake-up", function()
		local rig = newRig(nil, "Awake")
		rig.setState(100, "HeavySleep")
		rig.advance(0.25)
		rig.advance(0.25)
		expect(rig.head:GetPivot() == rig.headStart).toBe(true)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		for index, part in rig.sleepParts do
			expect(part.Transparency).toBe(rig.sleepLooks[index])
		end
	end)
end)

describe("GiantFx.start: stop during and after the pose", function()
	it("puts everything back as it was when stopped in the middle of the pose", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.25)
		rig.handle.stop()
		expect(rig.head:GetPivot() == rig.headStart).toBe(true)
		expect(rig.cap:GetPivot() == rig.capStart).toBe(true)
		expect(rig.leftLid:GetPivot() == rig.leftStart).toBe(true)
		expect(rig.rightLid:GetPivot() == rig.rightStart).toBe(true)
		expect(rig.awakeEyes:GetPivot() == rig.awakeEyesStart).toBe(true)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		for _, part in rig.awakeParts do
			expect(part.Transparency).toBe(1)
		end
		for index, part in rig.sleepParts do
			expect(part.Transparency).toBe(rig.sleepLooks[index])
		end
		expect(rig.floatingZ.Enabled).toBe(true)
		expect(rig.puff.Enabled).toBe(true)
		expect(rig.step:count()).toBe(0)
	end)

	it("puts everything back when stopped while he is awake and the pose is over", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		rig.handle.stop()
		expect(rig.head:GetPivot() == rig.headStart).toBe(true)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		for _, part in rig.awakeParts do
			expect(part.Transparency).toBe(1)
		end
		for index, part in rig.sleepParts do
			expect(part.Transparency).toBe(rig.sleepLooks[index])
		end
	end)

	it("puts everything back when stopped in a pose that was there from the start", function()
		local rig = newRig(nil, "Awake")
		rig.handle.stop()
		expect(rig.head:GetPivot() == rig.headStart).toBe(true)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		for _, part in rig.awakeParts do
			expect(part.Transparency).toBe(1)
		end
		for index, part in rig.sleepParts do
			expect(part.Transparency).toBe(rig.sleepLooks[index])
		end
	end)

	it("changes nothing on a later wake-up or step", function()
		local rig = newRig()
		rig.handle.stop()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		expect(rig.head:GetPivot() == rig.headStart).toBe(true)
		expect(rig.awakeParts[1].Transparency).toBe(1)
		expect(rig.floatingZ.Enabled).toBe(true)
	end)
end)

-- The angle in degrees between two directions.
local function degreesBetween(first: Vector3, second: Vector3): number
	local cosine = math.clamp(first.Unit:Dot(second.Unit), -1, 1)
	return math.deg(math.acos(cosine))
end

local function hasNaN(cframe: CFrame): boolean
	for _, value in { cframe:GetComponents() } do
		if value ~= value then
			return true
		end
	end
	return false
end

describe("GiantFx.slamTurn", function()
	local FROM = Vector3.new(0.3, 0.8, -0.5).Unit

	-- Where the direction `from` points after the turn.
	local function turned(turn: CFrame, from: Vector3): Vector3
		return turn:PointToWorldSpace(SHOULDER + from) - SHOULDER
	end

	it("moves nothing at share 0", function()
		local turn = GiantFx.slamTurn(SHOULDER, FROM, Vector3.new(-30, 2, -60), 0)
		expect(turn == CFrame.identity).toBe(true)
	end)

	it("at share 1 turns `from` to point exactly at the target (under 0.1 degree off)", function()
		local target = Vector3.new(-30, 2, -60)
		local turn = GiantFx.slamTurn(SHOULDER, FROM, target, 1)
		expect(degreesBetween(turned(turn, FROM), target - SHOULDER) < 0.1).toBe(true)
	end)

	it("at share 0.5 turns half the angle", function()
		local target = Vector3.new(70, 5, -40)
		local full = degreesBetween(FROM, target - SHOULDER)
		local turn = GiantFx.slamTurn(SHOULDER, FROM, target, 0.5)
		expect(math.abs(degreesBetween(FROM, turned(turn, FROM)) - full / 2) < 0.1).toBe(true)
	end)

	it("turns about the shoulder: the shoulder stays where it is", function()
		local turn = GiantFx.slamTurn(SHOULDER, FROM, Vector3.new(-30, 2, -60), 0.7)
		expect((turn:PointToWorldSpace(SHOULDER) - SHOULDER).Magnitude < 1e-3).toBe(true)
	end)

	it("gives no turn and no NaN when the directions are already the same", function()
		local target = SHOULDER + FROM * 80
		for _, share in { 0, 0.5, 1 } do
			local turn = GiantFx.slamTurn(SHOULDER, FROM, target, share)
			expect(hasNaN(turn)).toBe(false)
			expect(degreesBetween(turned(turn, FROM), FROM) < 0.1).toBe(true)
		end
	end)

	it("turns about an axis at right angles to `from` when the directions are exactly opposite", function()
		local target = SHOULDER - FROM * 80
		local turn = GiantFx.slamTurn(SHOULDER, FROM, target, 1)
		expect(hasNaN(turn)).toBe(false)
		expect(degreesBetween(turned(turn, FROM), -FROM) < 0.1).toBe(true)
		local half = GiantFx.slamTurn(SHOULDER, FROM, target, 0.5)
		expect(hasNaN(half)).toBe(false)
		expect(math.abs(degreesBetween(FROM, turned(half, FROM)) - 90) < 0.1).toBe(true)
	end)

	it("makes no NaN when the target is the shoulder itself or `from` is nothing", function()
		expect(hasNaN(GiantFx.slamTurn(SHOULDER, FROM, SHOULDER, 1))).toBe(false)
		expect(hasNaN(GiantFx.slamTurn(SHOULDER, Vector3.zero, Vector3.new(1, 2, 3), 1))).toBe(false)
	end)
end)

describe("GiantFx.slamShare", function()
	it("is 0 at the warning and before", function()
		expect(GiantFx.slamShare(0)).toBe(0)
		expect(GiantFx.slamShare(-1)).toBe(0)
	end)

	it("swings out smoothly over 0.5 seconds: half way at 0.25", function()
		expect(GiantFx.slamShare(0.25)).toBeCloseTo(0.5, 6)
		expect(GiantFx.slamShare(0.1) < 0.12).toBe(true) -- a straight line would be 0.2 here
	end)

	it("is all the way out from 0.5 seconds to 1.9 seconds, when the fist starts to lift", function()
		expect(GiantFx.slamShare(0.5)).toBe(1)
		expect(GiantFx.slamShare(1.2)).toBe(1)
		expect(GiantFx.slamShare(1.9)).toBe(1)
	end)

	it("comes back smoothly over the next 0.5 seconds: half way at 2.15", function()
		expect(GiantFx.slamShare(2.15)).toBeCloseTo(0.5, 6)
	end)

	it("is 0 from 2.4 seconds on", function()
		expect(GiantFx.slamShare(2.4)).toBeCloseTo(0, 6)
		expect(GiantFx.slamShare(3)).toBe(0)
	end)
end)

describe("GiantFx.start: the arm swing", function()
	local AHEAD_LEFT = Vector3.new(-30, 2, -60)
	local AHEAD_RIGHT = Vector3.new(90, 2, -45)
	local BELLY = Vector3.new(-12.7, 49, -40.6)

	local function armMiddle(rig: Rig): Vector3
		return (rig.arm:GetBoundingBox()).Position
	end

	-- How many degrees the arm's middle is off the line from the shoulder to `point`.
	local function offLine(rig: Rig, point: Vector3): number
		return degreesBetween(armMiddle(rig) - SHOULDER, point - SHOULDER)
	end

	local function awakeRig(): Rig
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		return rig
	end

	local function fullRaise(rig: Rig): CFrame
		return GiantFx.armRaise(SHOULDER, RAISE_DEGREES, 1) * rig.armStart
	end

	it("points the arm's middle at the target 0.5 seconds after the warning", function()
		for _, point in { AHEAD_LEFT, AHEAD_RIGHT, BELLY } do
			local rig = awakeRig()
			rig.slamWarning:Fire(1, point, 0)
			rig.advance(0.5)
			expect(offLine(rig, point) < 1).toBe(true)
		end
	end)

	it("starts from the raised fist: the warning itself moves nothing", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		expect(samePlace(rig.arm:GetPivot(), fullRaise(rig))).toBe(true)
		rig.advance(0)
		expect(samePlace(rig.arm:GetPivot(), fullRaise(rig))).toBe(true)
	end)

	it("swings out with the easing: half way round at 0.25 seconds", function()
		local rig = awakeRig()
		local raisedMiddle = armMiddle(rig)
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(0.25)
		local total = degreesBetween(raisedMiddle - SHOULDER, AHEAD_LEFT - SHOULDER)
		local done = degreesBetween(raisedMiddle - SHOULDER, armMiddle(rig) - SHOULDER)
		expect(total > 10).toBe(true)
		expect(math.abs(done - total / 2) < 1).toBe(true)
	end)

	it("is still pointing at the target at 1.9 seconds", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, AHEAD_RIGHT, 0)
		rig.advance(1.9)
		expect(offLine(rig, AHEAD_RIGHT) < 1).toBe(true)
	end)

	it("is back on the full-raise pivot at 2.4 seconds", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(1.9)
		rig.advance(0.51)
		expect(samePlace(rig.arm:GetPivot(), fullRaise(rig))).toBe(true)
	end)

	it("lets go of the step when the swing is over", function()
		local rig = awakeRig()
		expect(rig.step:count()).toBe(0)
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		expect(rig.step:count()).toBe(1)
		rig.advance(2.5)
		expect(rig.step:count()).toBe(0)
		expect(samePlace(rig.arm:GetPivot(), fullRaise(rig))).toBe(true)
	end)

	it("counts the swing from when the warning arrived, however many frames that is", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		for _ = 1, 30 do
			rig.advance(0.5 / 30)
		end
		expect(offLine(rig, AHEAD_LEFT) < 1).toBe(true)
	end)

	it("moves nothing for a warning that arrives while he is asleep", function()
		local rig = newRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(1)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		expect(rig.step:count()).toBe(0)
	end)

	it("moves nothing for a warning that arrives while he settles back to sleep", function()
		local rig = awakeRig()
		rig.setState(0, "HeavySleep")
		rig.advance(0.2) -- 0.3 seconds into the pose back
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(0.1) -- 0.2 seconds left of the pose
		local share = GiantFx.poseShare(0.2)
		expect(samePlace(rig.arm:GetPivot(), GiantFx.armRaise(SHOULDER, RAISE_DEGREES, share) * rig.armStart)).toBe(
			true
		)
		rig.advance(0.4)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
	end)

	it("puts the arm back on its start pivot when Phase leaves Awake in the middle of a swing", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(1)
		expect(offLine(rig, AHEAD_LEFT) < 1).toBe(true)
		rig.setState(0, "HeavySleep")
		rig.advance(0.6)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		rig.advance(2)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		expect(rig.step:count()).toBe(0)
	end)

	it("takes the swing back with the pose: the swing share is scaled by how far the pose still is", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(1)
		rig.setState(0, "HeavySleep")
		rig.advance(0.25) -- 1.25 s into the swing (all the way out), and half way back in the pose
		local poseShare = GiantFx.poseShare(0.25)
		-- The arm's middle at the start, which is the middle of its one part.
		local from = GiantFx.armRaise(SHOULDER, RAISE_DEGREES, 1):PointToWorldSpace(Vector3.new(41, 68, 8)) - SHOULDER
		local expected = GiantFx.slamTurn(SHOULDER, from, AHEAD_LEFT, poseShare)
			* GiantFx.armRaise(SHOULDER, RAISE_DEGREES, poseShare)
			* rig.armStart
		expect(samePlace(rig.arm:GetPivot(), expected)).toBe(true)
	end)

	it("ends the 6th swing at the end of Awake without leaving the arm out", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(6, AHEAD_RIGHT, 0)
		rig.advance(1.5) -- the 6th slam lands as Phase turns HeavySleep
		rig.setState(0, "HeavySleep")
		rig.advance(0.55) -- the pose is back at rest, but the swing has 0.35 seconds left
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		rig.advance(0.2)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		rig.advance(0.5)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		expect(rig.step:count()).toBe(0)
	end)

	it("lets a new warning replace the swing before it", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(1)
		rig.slamWarning:Fire(2, AHEAD_RIGHT, 0)
		rig.advance(0.5)
		expect(offLine(rig, AHEAD_RIGHT) < 1).toBe(true)
		rig.advance(1.9)
		expect(samePlace(rig.arm:GetPivot(), fullRaise(rig))).toBe(true)
	end)

	it("ignores a warning whose point is not a position", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, "there", 0)
		rig.slamWarning:Fire(1, nil, 0)
		rig.advance(1)
		expect(samePlace(rig.arm:GetPivot(), fullRaise(rig))).toBe(true)
		expect(rig.step:count()).toBe(0)
	end)

	it("puts the arm on its start pivot when stopped in the middle of a swing", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(1)
		rig.handle.stop()
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
		expect(rig.step:count()).toBe(0)
		expect(rig.slamWarning:count()).toBe(0)
	end)

	it("changes nothing for a warning after stop", function()
		local rig = awakeRig()
		rig.handle.stop()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(1)
		expect(rig.arm:GetPivot() == rig.armStart).toBe(true)
	end)

	it("does not move the head or the other pieces", function()
		local rig = awakeRig()
		local headBefore = rig.head:GetPivot()
		local lidBefore = rig.leftLid:GetPivot()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(1)
		expect(rig.head:GetPivot() == headBefore).toBe(true)
		expect(rig.leftLid:GetPivot() == lidBefore).toBe(true)
	end)

	it("swings from the full raise even when he was already awake when the script started", function()
		local rig = newRig(nil, "Awake")
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(0.5)
		expect(offLine(rig, AHEAD_LEFT) < 1).toBe(true)
		rig.advance(2)
		expect(samePlace(rig.arm:GetPivot(), fullRaise(rig))).toBe(true)
	end)
end)

-- The fixed pose the arm goes to when a straight swing would pass through his body: 70 degrees forward and 25 degrees
-- out to his right, as a direction in the giant's own axes (he faces -Z, his right is +X).
local FIXED_DIRECTION = Vector3.new(0.4226, -0.3100, -0.8517)

describe("GiantFx arm constants", function()
	it("has an arm 50 studs long, and a fixed pose 70 degrees forward and 25 degrees out", function()
		expect(GiantFx.armLength).toBe(50)
		expect(GiantFx.slamFixedForwardDegrees).toBe(70)
		expect(GiantFx.slamFixedOutDegrees).toBe(25)
	end)
end)

describe("GiantFx.slamFixedAim", function()
	it("is 50 studs from the shoulder, 70 degrees forward and 25 degrees out to his right", function()
		local aim = GiantFx.slamFixedAim(SHOULDER, GIANT_PIVOT)
		local offset = aim - SHOULDER
		expect(offset.Magnitude).toBeCloseTo(50, 2)
		expect((offset.Unit - FIXED_DIRECTION).Magnitude < 0.001).toBe(true)
	end)

	it("turns with the giant: a giant turned 90 degrees about Y turns the pose the same way", function()
		local turned = GIANT_PIVOT * CFrame.Angles(0, math.rad(90), 0)
		local offset = GiantFx.slamFixedAim(SHOULDER, turned) - SHOULDER
		-- A quarter turn about Y sends (x, y, z) to (z, y, -x).
		local expected = Vector3.new(FIXED_DIRECTION.Z, FIXED_DIRECTION.Y, -FIXED_DIRECTION.X)
		expect(offset.Magnitude).toBeCloseTo(50, 2)
		expect((offset.Unit - expected).Magnitude < 0.001).toBe(true)
	end)

	it("does not depend on where the giant stands, only on how he is turned", function()
		local moved = CFrame.new(300, 40, -20)
		local first = GiantFx.slamFixedAim(SHOULDER, GIANT_PIVOT) - SHOULDER
		local second = GiantFx.slamFixedAim(SHOULDER, moved) - SHOULDER
		expect((first - second).Magnitude < 0.001).toBe(true)
	end)
end)

describe("GiantFx.slamAim", function()
	local FROM = Vector3.new(0.141, 0.910, -0.390).Unit
	local POINT = Vector3.new(-97, 2, 1)
	local FIXED = Vector3.new(60, 30, -20)
	local SHARES = { 0.25, 0.5, 0.75, 1 }

	local function alwaysClear(_shoulder: Vector3, _direction: Vector3): boolean
		return true
	end

	it("gives the point itself when the arm is clear at every share", function()
		expect(GiantFx.slamAim(SHOULDER, FROM, POINT, FIXED, alwaysClear) == POINT).toBe(true)
	end)

	it("gives the fixed aim when the arm is blocked only at the full swing", function()
		local calls = 0
		local aim = GiantFx.slamAim(SHOULDER, FROM, POINT, FIXED, function(_shoulder: Vector3, _direction: Vector3)
			calls += 1
			return calls ~= 4
		end)
		expect(aim == FIXED).toBe(true)
	end)

	it("gives the fixed aim when the arm is blocked only half way through the swing", function()
		local calls = 0
		local aim = GiantFx.slamAim(SHOULDER, FROM, POINT, FIXED, function(_shoulder: Vector3, _direction: Vector3)
			calls += 1
			return calls ~= 2
		end)
		expect(aim == FIXED).toBe(true)
	end)

	it("gives the fixed aim when the arm is blocked only a quarter of the way", function()
		local calls = 0
		local aim = GiantFx.slamAim(SHOULDER, FROM, POINT, FIXED, function(_shoulder: Vector3, _direction: Vector3)
			calls += 1
			return calls ~= 1
		end)
		expect(aim == FIXED).toBe(true)
	end)

	it(
		"asks with the shoulder and the arm's direction at a quarter, half, three quarters and all of the swing",
		function()
			local seen: { { shoulder: Vector3, direction: Vector3 } } = {}
			GiantFx.slamAim(SHOULDER, FROM, POINT, FIXED, function(shoulder: Vector3, direction: Vector3)
				table.insert(seen, { shoulder = shoulder, direction = direction })
				return true
			end)
			expect(#seen).toBe(4)
			for index, share in SHARES do
				local expected = GiantFx.slamTurn(SHOULDER, FROM, POINT, share):VectorToWorldSpace(FROM)
				expect(seen[index].shoulder == SHOULDER).toBe(true)
				expect((seen[index].direction - expected).Magnitude < 1e-4).toBe(true)
			end
			-- The last one points at the point, and the first is a quarter of the way there.
			expect(degreesBetween(seen[4].direction, POINT - SHOULDER) < 0.1).toBe(true)
			expect(degreesBetween(seen[1].direction, FROM) > 1).toBe(true)
		end
	)
end)

describe("GiantFx.start: the arm and his body", function()
	local AHEAD_LEFT = Vector3.new(-30, 2, -60)
	local AHEAD_RIGHT = Vector3.new(90, 2, -45)
	-- The arm's middle at the start (the middle of its one part), and its direction from the shoulder in the full raise.
	local FROM = GiantFx.armRaise(SHOULDER, RAISE_DEGREES, 1):PointToWorldSpace(Vector3.new(41, 68, 8)) - SHOULDER

	local function armMiddle(rig: Rig): Vector3
		return (rig.arm:GetBoundingBox()).Position
	end

	local function offDirection(rig: Rig, direction: Vector3): number
		return degreesBetween(armMiddle(rig) - SHOULDER, direction)
	end

	local function awakeRig(): Rig
		local rig = newRig()
		rig.setState(100, "Awake")
		rig.advance(0.5)
		return rig
	end

	local function blocked(_shoulder: Vector3, _direction: Vector3): boolean
		return false
	end

	local function fullRaise(rig: Rig): CFrame
		return GiantFx.armRaise(SHOULDER, RAISE_DEGREES, 1) * rig.armStart
	end

	it("asks four times when the warning arrives, with the shoulder and the directions of the swing", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		expect(#rig.armClearCalls).toBe(4)
		for index, share in { 0.25, 0.5, 0.75, 1 } do
			local expected = GiantFx.slamTurn(SHOULDER, FROM, AHEAD_LEFT, share):VectorToWorldSpace(FROM)
			expect(rig.armClearCalls[index].shoulder == SHOULDER).toBe(true)
			expect((rig.armClearCalls[index].direction - expected).Magnitude < 1e-3).toBe(true)
		end
	end)

	it("points at the target when the arm is clear", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(0.5)
		expect(offDirection(rig, AHEAD_LEFT - SHOULDER) < 1).toBe(true)
	end)

	it("goes to the fixed pose 0.5 seconds after the warning when the arm is blocked", function()
		local rig = awakeRig()
		rig.setArmClear(blocked)
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(0.5)
		expect(offDirection(rig, FIXED_DIRECTION) < 1).toBe(true)
		-- And not at the target.
		expect(offDirection(rig, AHEAD_LEFT - SHOULDER) > 5).toBe(true)
	end)

	it("turns the fixed pose with the giant", function()
		local rig = awakeRig()
		rig.giant.WorldPivot = GIANT_PIVOT * CFrame.Angles(0, math.rad(90), 0)
		rig.setArmClear(blocked)
		rig.slamWarning:Fire(1, AHEAD_RIGHT, 0)
		rig.advance(0.5)
		expect(offDirection(rig, Vector3.new(FIXED_DIRECTION.Z, FIXED_DIRECTION.Y, -FIXED_DIRECTION.X)) < 1).toBe(true)
	end)

	it("keeps the fixed pose until the fist lifts, then is back on the full-raise pivot at 2.4 seconds", function()
		local rig = awakeRig()
		rig.setArmClear(blocked)
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(1.9)
		expect(offDirection(rig, FIXED_DIRECTION) < 1).toBe(true)
		rig.advance(0.51)
		expect(samePlace(rig.arm:GetPivot(), fullRaise(rig))).toBe(true)
	end)

	it("swings to the fixed pose with the same easing: half way round at 0.25 seconds", function()
		local rig = awakeRig()
		local raisedMiddle = armMiddle(rig)
		rig.setArmClear(blocked)
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(0.25)
		local total = degreesBetween(raisedMiddle - SHOULDER, FIXED_DIRECTION)
		local done = degreesBetween(raisedMiddle - SHOULDER, armMiddle(rig) - SHOULDER)
		expect(total > 10).toBe(true)
		expect(math.abs(done - total / 2) < 1).toBe(true)
	end)

	it("decides once: a stand-in that turns to blocked after the warning does not move the aim", function()
		local rig = awakeRig()
		local blockedNow = false
		rig.setArmClear(function(_shoulder: Vector3, _direction: Vector3)
			return not blockedNow
		end)
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		blockedNow = true
		rig.advance(0.5)
		expect(offDirection(rig, AHEAD_LEFT - SHOULDER) < 1).toBe(true)
		rig.advance(1.4)
		expect(offDirection(rig, AHEAD_LEFT - SHOULDER) < 1).toBe(true)
	end)

	it("decides once: a stand-in that turns to clear after the warning keeps the fixed pose", function()
		local rig = awakeRig()
		local blockedNow = true
		rig.setArmClear(function(_shoulder: Vector3, _direction: Vector3)
			return not blockedNow
		end)
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		blockedNow = false
		rig.advance(0.5)
		expect(offDirection(rig, FIXED_DIRECTION) < 1).toBe(true)
		rig.advance(1.4)
		expect(offDirection(rig, FIXED_DIRECTION) < 1).toBe(true)
	end)

	it("asks only when the warning arrives, never again on the frames of the swing", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		local asked = #rig.armClearCalls
		for _ = 1, 20 do
			rig.advance(0.1)
		end
		expect(#rig.armClearCalls).toBe(asked)
	end)

	it("decides again for the next warning", function()
		local rig = awakeRig()
		rig.setArmClear(blocked)
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		rig.advance(2.5)
		rig.setArmClear(function(_shoulder: Vector3, _direction: Vector3)
			return true
		end)
		rig.slamWarning:Fire(2, AHEAD_RIGHT, 0)
		rig.advance(0.5)
		expect(offDirection(rig, AHEAD_RIGHT - SHOULDER) < 1).toBe(true)
	end)

	it("asks nothing for a warning that arrives while he is asleep", function()
		local rig = newRig()
		rig.slamWarning:Fire(1, AHEAD_LEFT, 0)
		expect(#rig.armClearCalls).toBe(0)
	end)

	it("asks nothing for a warning whose point is not a position", function()
		local rig = awakeRig()
		rig.slamWarning:Fire(1, "there", 0)
		expect(#rig.armClearCalls).toBe(0)
	end)
end)

describe("GiantFx.workspaceArmClear", function()
	-- A fake world far from the map, with a Giant that has a body piece, a right arm and a boot.
	local SHOULDER_AT = Vector3.new(2000, 50, 2000)
	local EAST = Vector3.new(1, 0, 0)

	local function newWorld(): Folder
		local world = made(Instance.new("Folder"))
		world.Name = "World"
		local giant = Instance.new("Model")
		giant.Name = "Giant"
		giant.Parent = world
		world.Parent = Workspace
		return world
	end

	local function pieceOf(giant: Instance, name: string): Model
		local model = Instance.new("Model")
		model.Name = name
		model.Parent = giant
		return model
	end

	-- A 4-stud block `studs` east of the shoulder.
	local function blockAt(studs: number, parent: Instance): Part
		local part = Instance.new("Part")
		part.Anchored = true
		part.Size = Vector3.new(4, 4, 4)
		part.CFrame = CFrame.new(SHOULDER_AT + EAST * studs)
		part.Parent = parent
		return part
	end

	local function giantOf(world: Folder): Model
		return world:FindFirstChild("Giant") :: Model
	end

	it("is not clear when a part of his body is on the line 20 studs out", function()
		local world = newWorld()
		blockAt(20, pieceOf(giantOf(world), "body_and_cushion"))
		local clear = GiantFx.workspaceArmClear(Workspace, world)
		expect(clear(SHOULDER_AT, EAST)).toBe(false)
	end)

	it("is clear when the only part of his body on the line is 55 studs out, beyond the arm", function()
		local world = newWorld()
		blockAt(55, pieceOf(giantOf(world), "body_and_cushion"))
		local clear = GiantFx.workspaceArmClear(Workspace, world)
		expect(clear(SHOULDER_AT, EAST)).toBe(true)
	end)

	it("is clear when the only part on the line is under the right arm itself", function()
		local world = newWorld()
		blockAt(20, pieceOf(giantOf(world), "right_arm"))
		local clear = GiantFx.workspaceArmClear(Workspace, world)
		expect(clear(SHOULDER_AT, EAST)).toBe(true)
	end)

	it("is clear when the part on the line is outside the Giant", function()
		local world = newWorld()
		pieceOf(giantOf(world), "body_and_cushion")
		blockAt(20, world)
		local clear = GiantFx.workspaceArmClear(Workspace, world)
		expect(clear(SHOULDER_AT, EAST)).toBe(true)
	end)

	it("is clear when there is no Giant", function()
		local world = made(Instance.new("Folder"))
		world.Parent = Workspace
		blockAt(20, world)
		local clear = GiantFx.workspaceArmClear(Workspace, world)
		expect(clear(SHOULDER_AT, EAST)).toBe(true)
	end)

	it("is not clear when a part that is a direct child of the Giant is on the line", function()
		local world = newWorld()
		blockAt(20, giantOf(world))
		local clear = GiantFx.workspaceArmClear(Workspace, world)
		expect(clear(SHOULDER_AT, EAST)).toBe(false)
	end)

	it(
		"counts a part that can't be collided with: the body blocks the arm even if a player walks through it",
		function()
			local world = newWorld()
			blockAt(20, pieceOf(giantOf(world), "head_with_beard")).CanCollide = false
			local clear = GiantFx.workspaceArmClear(Workspace, world)
			expect(clear(SHOULDER_AT, EAST)).toBe(false)
		end
	)

	it("uses the direction's way, not its length", function()
		local world = newWorld()
		blockAt(20, pieceOf(giantOf(world), "body_and_cushion"))
		local clear = GiantFx.workspaceArmClear(Workspace, world)
		expect(clear(SHOULDER_AT, EAST * 0.01)).toBe(false)
		expect(clear(SHOULDER_AT, EAST * 500)).toBe(false)
		expect(clear(SHOULDER_AT, -EAST)).toBe(true)
	end)

	it("looks at the Giant's pieces each time it is asked, so a piece that streams in later counts", function()
		local world = newWorld()
		local clear = GiantFx.workspaceArmClear(Workspace, world)
		expect(clear(SHOULDER_AT, EAST)).toBe(true)
		blockAt(20, pieceOf(giantOf(world), "legs_and_boots"))
		expect(clear(SHOULDER_AT, EAST)).toBe(false)
	end)

	it("is clear for a direction of nothing, instead of making a NaN ray", function()
		local world = newWorld()
		blockAt(20, pieceOf(giantOf(world), "body_and_cushion"))
		local clear = GiantFx.workspaceArmClear(Workspace, world)
		expect(clear(SHOULDER_AT, Vector3.zero)).toBe(true)
	end)
end)

-- Where the sign's bottom-left corner is, in studs from the anchor in the camera's own directions: its middle (the
-- offset) minus half its size.
local function signCorner(sign: BillboardGui): Vector3
	return sign.StudsOffset - Vector3.new(sign.Size.X.Scale / 2, sign.Size.Y.Scale / 2, 0)
end

local function puffSizes(puff: ParticleEmitter): { number }
	local found: { number } = {}
	for _, keypoint in puff.Size.Keypoints do
		table.insert(found, keypoint.Value)
	end
	return found
end

local function close(actual: number, expected: number, within: number?)
	expect(math.abs(actual - expected) <= (within or 1e-3)).toBe(true)
end

describe("GiantFx Heavy Sleep settings", function()
	it("makes the Z Z Z 2.5 times bigger", function()
		expect(GiantFx.heavyLetterScale).toBe(2.5)
	end)

	it("makes the puffs come 3 times as often", function()
		expect(GiantFx.heavyPuffRateScale).toBe(3)
	end)

	it("makes the puffs 1.6 times bigger", function()
		expect(GiantFx.heavyPuffSizeScale).toBe(1.6)
	end)

	it("shrinks the Z Z Z back over 0.5 seconds, like the waking pose", function()
		expect(GiantFx.heavyShrinkSeconds).toBe(0.5)
	end)

	it("keeps the bottom-left corner of the sign where it is", function()
		expect(GiantFx.heavyFixedCorner).toBe(Vector2.new(-1, -1))
	end)
end)

describe("GiantFx.start: Heavy Sleep", function()
	it("makes the Z Z Z sign 2.5 times its size: 40 x 40 studs from 16 x 16", function()
		local rig = newRig()
		rig.setState(100, "HeavySleep")
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(40, 40))
	end)

	it("keeps the sign's bottom-left corner where it was, so it grows up and to the right", function()
		local rig = newRig()
		local before = signCorner(rig.floatingZ)
		rig.setState(100, "HeavySleep")
		local after = signCorner(rig.floatingZ)
		close((after - before).Magnitude, 0)
		expect(rig.floatingZ.StudsOffset).toBe(Vector3.new(26, 20, 2))
	end)

	it("makes the puff Rate 6 from 2", function()
		local rig = newRig()
		rig.setState(100, "HeavySleep")
		expect(rig.puff.Rate).toBe(6)
	end)

	it("makes every puff Size keypoint 1.6 times bigger: 3.2 and 11.2", function()
		local rig = newRig()
		rig.setState(100, "HeavySleep")
		local sizes = puffSizes(rig.puff)
		close(sizes[1], 3.2)
		close(sizes[2], 11.2)
	end)

	it("scales the envelope of each puff Size keypoint too, and keeps the times", function()
		local rig = newRig()
		rig.puff.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 2, 0.5), NumberSequenceKeypoint.new(1, 7, 1) })
		rig.setState(100, "HeavySleep")
		local keypoints = rig.puff.Size.Keypoints
		close(keypoints[1].Envelope, 0.8)
		close(keypoints[2].Envelope, 1.6)
		close(keypoints[1].Time, 0)
		close(keypoints[2].Time, 1)
	end)

	it("has the Z Z Z and puffs on, and big, after an 85 warning and a wake", function()
		local rig = newRig()
		rig.fire(85)
		rig.setState(100, "Awake")
		rig.advance(0.5)
		rig.setState(100, "HeavySleep")
		expect(rig.floatingZ.Enabled).toBe(true)
		expect(rig.puff.Enabled).toBe(true)
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(40, 40))
		expect(rig.puff.Rate).toBe(6)
	end)

	it("keeps them off while an 85 warning has them quiet and he is Asleep", function()
		local rig = newRig()
		rig.fire(85)
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(16, 16))
		expect(rig.puff.Rate).toBe(2)
	end)

	it("keeps the Z Z Z and puffs off, with the normal look, while he is Awake", function()
		local rig = newRig()
		rig.setState(100, "Awake")
		expect(rig.floatingZ.Enabled).toBe(false)
		expect(rig.puff.Enabled).toBe(false)
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(16, 16))
		expect(rig.puff.Rate).toBe(2)
	end)

	it("still fades the big letters with the 60 warning rules after Heavy Sleep starts from a quiet sleep", function()
		local rig = newRig()
		rig.setState(100, "HeavySleep")
		rig.fire(60)
		rig.advance(1)
		expect(rig.letters[1].TextTransparency > rig.normalLetters[1]).toBe(true)
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(40, 40))
	end)
end)

describe("GiantFx.start: Heavy Sleep ends", function()
	local function heavyRig(): Rig
		local rig = newRig()
		rig.setState(100, "HeavySleep")
		return rig
	end

	it("has the puff Rate and Size back at once", function()
		local rig = heavyRig()
		rig.setState(0, "Asleep")
		expect(rig.puff.Rate).toBe(2)
		local sizes = puffSizes(rig.puff)
		close(sizes[1], 2)
		close(sizes[2], 7)
	end)

	it("has the sign still big on the same frame, then shrinks it", function()
		local rig = heavyRig()
		rig.setState(0, "Asleep")
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(40, 40))
	end)

	it("is half way through the shrink, with the smooth easing, at 0.25 seconds, on the same corner", function()
		local rig = heavyRig()
		rig.setState(0, "Asleep")
		rig.advance(0.25)
		close(rig.floatingZ.Size.X.Scale, 28)
		close(rig.floatingZ.Size.Y.Scale, 28)
		close(rig.floatingZ.StudsOffset.X, 20)
		close(rig.floatingZ.StudsOffset.Y, 14)
		close((signCorner(rig.floatingZ) - Vector3.new(6, 0, 2)).Magnitude, 0)
	end)

	it("eases: a tenth of the way through it has shrunk far less than a tenth", function()
		local rig = heavyRig()
		rig.setState(0, "Asleep")
		rig.advance(0.05)
		expect(rig.floatingZ.Size.X.Scale > 39).toBe(true)
	end)

	it("has the sign, offset and corner back at the saved values after 0.5 seconds", function()
		local rig = heavyRig()
		rig.setState(0, "Asleep")
		rig.advance(0.5)
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(16, 16))
		expect(rig.floatingZ.StudsOffset).toBe(Vector3.new(14, 8, 2))
	end)

	it("lets go of the step when the shrink is over", function()
		local rig = heavyRig()
		rig.setState(0, "Asleep")
		expect(rig.step:count()).toBe(1)
		rig.advance(0.5)
		expect(rig.step:count()).toBe(0)
	end)

	it("counts the shrink by the clock, however many frames that is", function()
		local rig = heavyRig()
		rig.setState(0, "Asleep")
		rig.advance(0.1)
		rig.advance(0.1)
		rig.advance(0.05)
		close(rig.floatingZ.Size.X.Scale, 28)
	end)

	it("is big at once when Heavy Sleep comes back in the middle of a shrink", function()
		local rig = heavyRig()
		rig.setState(0, "Asleep")
		rig.advance(0.25)
		rig.setState(100, "HeavySleep")
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(40, 40))
		rig.advance(1)
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(40, 40))
	end)

	it("never grows the sign twice over a second round: always 2.5 times the saved size", function()
		local rig = newRig()
		rig.setState(100, "HeavySleep")
		rig.setState(0, "Asleep")
		rig.advance(0.5)
		rig.setState(100, "HeavySleep")
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(40, 40))
		expect(rig.floatingZ.StudsOffset).toBe(Vector3.new(26, 20, 2))
		expect(rig.puff.Rate).toBe(6)
		close(puffSizes(rig.puff)[2], 11.2)
	end)

	it("never grows the puffs twice over a second round, then goes back to the saved ones", function()
		local rig = newRig()
		rig.setState(100, "HeavySleep")
		rig.setState(0, "Asleep")
		rig.advance(0.5)
		rig.setState(100, "HeavySleep")
		rig.setState(0, "Asleep")
		rig.advance(0.5)
		expect(rig.puff.Rate).toBe(2)
		close(puffSizes(rig.puff)[2], 7)
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(16, 16))
	end)
end)

describe("GiantFx.start: Heavy Sleep, saved values", function()
	it(
		"takes the normal look from what the place had: a sign of 10 x 12 and a Rate of 5 keep their own numbers",
		function()
			local rig = newRig()
			rig.floatingZ.Size = UDim2.fromScale(10, 12)
			rig.floatingZ.StudsOffset = Vector3.new(3, 4, 5)
			rig.puff.Rate = 5
			rig.puff.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3) })
			rig.setState(100, "HeavySleep")
			expect(rig.floatingZ.Size).toBe(UDim2.fromScale(25, 30))
			expect(rig.puff.Rate).toBe(15)
			close(puffSizes(rig.puff)[2], 4.8)
			close((signCorner(rig.floatingZ) - Vector3.new(3 - 5, 4 - 6, 5)).Magnitude, 0)
			rig.setState(0, "Asleep")
			rig.advance(0.5)
			expect(rig.floatingZ.Size).toBe(UDim2.fromScale(10, 12))
			expect(rig.floatingZ.StudsOffset).toBe(Vector3.new(3, 4, 5))
			expect(rig.puff.Rate).toBe(5)
			close(puffSizes(rig.puff)[2], 3)
		end
	)
end)

describe("GiantFx.start: Heavy Sleep, joining", function()
	it("gives a module that starts during Heavy Sleep the big look at once", function()
		local rig = newRig(true, "HeavySleep")
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(40, 40))
		expect(rig.floatingZ.StudsOffset).toBe(Vector3.new(26, 20, 2))
		expect(rig.puff.Rate).toBe(6)
		close(puffSizes(rig.puff)[1], 3.2)
	end)

	it("shrinks a module that started during Heavy Sleep back to the saved look at its end", function()
		local rig = newRig(true, "HeavySleep")
		rig.setState(0, "Asleep")
		rig.advance(0.5)
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(16, 16))
		expect(rig.floatingZ.StudsOffset).toBe(Vector3.new(14, 8, 2))
		expect(rig.puff.Rate).toBe(2)
	end)
end)

describe("GiantFx.start: Heavy Sleep, streaming", function()
	it("gives a GiantFX that streams in during Heavy Sleep the big look", function()
		local rig = newRig(false)
		rig.setState(100, "HeavySleep")
		rig.fx.Parent = rig.world
		task.wait()
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(40, 40))
		expect(rig.floatingZ.StudsOffset).toBe(Vector3.new(26, 20, 2))
		expect(rig.puff.Rate).toBe(6)
		close(puffSizes(rig.puff)[2], 11.2)
	end)

	it("gives a GiantFX that streams in after Heavy Sleep the normal look", function()
		local rig = newRig(false)
		rig.setState(100, "HeavySleep")
		rig.setState(0, "Asleep")
		rig.advance(0.5)
		rig.fx.Parent = rig.world
		task.wait()
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(16, 16))
		expect(rig.floatingZ.StudsOffset).toBe(Vector3.new(14, 8, 2))
		expect(rig.puff.Rate).toBe(2)
		close(puffSizes(rig.puff)[2], 7)
	end)

	it("gives a part added to GiantFX during Heavy Sleep the big look", function()
		local rig = newRig()
		rig.setState(100, "HeavySleep")
		-- A fresh copy of the pieces arrives from the server, as the place made them.
		rig.floatingZ.Size = UDim2.fromScale(16, 16)
		rig.floatingZ.StudsOffset = Vector3.new(14, 8, 2)
		rig.puff.Rate = 2
		local extra = made(Instance.new("Part"))
		extra.Parent = rig.fx
		task.wait()
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(40, 40))
		expect(rig.puff.Rate).toBe(6)
	end)

	it("gives a new FloatingZ that streams in during Heavy Sleep the big look from its own size", function()
		local rig = newRig()
		rig.setState(100, "HeavySleep")
		rig.floatingZ.Parent = nil
		local fresh = made(Instance.new("BillboardGui"))
		fresh.Name = "FloatingZ"
		fresh.Size = UDim2.fromScale(8, 8)
		fresh.StudsOffset = Vector3.new(1, 2, 3)
		fresh.Parent = rig.snoreEmitter
		task.wait()
		expect(fresh.Size).toBe(UDim2.fromScale(20, 20))
		expect(fresh.StudsOffset).toBe(Vector3.new(1 + 6, 2 + 6, 3))
	end)
end)

describe("GiantFx.start: Heavy Sleep, stop", function()
	it("puts the saved sign, offset, Rate and puff Size back when stopped in Heavy Sleep", function()
		local rig = newRig()
		rig.setState(100, "HeavySleep")
		rig.handle.stop()
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(16, 16))
		expect(rig.floatingZ.StudsOffset).toBe(Vector3.new(14, 8, 2))
		expect(rig.puff.Rate).toBe(2)
		close(puffSizes(rig.puff)[1], 2)
		close(puffSizes(rig.puff)[2], 7)
	end)

	it("puts the saved look back when stopped in the middle of the shrink", function()
		local rig = newRig()
		rig.setState(100, "HeavySleep")
		rig.setState(0, "Asleep")
		rig.advance(0.2)
		rig.handle.stop()
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(16, 16))
		expect(rig.floatingZ.StudsOffset).toBe(Vector3.new(14, 8, 2))
		expect(rig.step:count()).toBe(0)
	end)

	it("changes nothing on a later Heavy Sleep after stop", function()
		local rig = newRig()
		rig.handle.stop()
		rig.setState(100, "HeavySleep")
		expect(rig.floatingZ.Size).toBe(UDim2.fromScale(16, 16))
		expect(rig.puff.Rate).toBe(2)
	end)
end)
