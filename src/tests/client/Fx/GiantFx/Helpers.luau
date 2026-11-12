--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Client = StarterPlayer.StarterPlayerScripts.Client
local GiantFx = require(Client.Fx.GiantFx)

-- Everything a test makes is destroyed afterwards, so the real place is never changed.
local madeInstances: { Instance } = {}

local stops: { () -> () } = {}

local function made<T>(instance: T): T
	table.insert(madeInstances, instance :: any)
	return instance
end

local function cleanUp()
	for _, stop in stops do
		stop()
	end
	table.clear(stops)
	for _, instance in madeInstances do
		instance:Destroy()
	end
	table.clear(madeInstances)
end

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

export type Rig = {
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
	signs: { string }, -- every look the meter Zs were told to take (onSignsChanged), in order
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
	setServerOffset: (seconds: number) -> (), -- the server's clock is the rig clock plus this (default 0)
	setPhaseEnds: (serverTime: number?) -> (), -- writes PhaseEndsAt on the state; nil removes it (no waiting)
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
	mouth: Model, -- World.Giant.AwakeMouth
	mouthParts: { Part }, -- its Mouth and Tongue, both marked ShownWhenAwake
	mouthStart: CFrame,
	bangAnchor: Part, -- World.GiantFX.BangAnchor
	bang: BillboardGui, -- BangAnchor.Bang
	zpop: BillboardGui, -- BangAnchor.ZPop
	bangSize: UDim2, -- what Bang's size was at the start
	zpopSize: UDim2,
	bangLooks: { [Instance]: number }, -- each Frame's BackgroundTransparency and UIStroke's Transparency in Bang, at the start
	sounds: { SoundCall }, -- every playSound call, in order
}

-- One playSound call the module made: the name, the place (nil for no place) and the seconds since the rig was built.
export type SoundCall = { name: string, at: Vector3?, time: number }

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
-- test can drive all of them. `withFx` false builds the world without GiantFX (it streams in later). `withSound` false
-- leaves the playSound setting out.
local function newRig(withFx: boolean?, startPhase: string?, withNose: boolean?, withSound: boolean?): Rig
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
	-- The awake mouth, as in the place (World.Giant.AwakeMouth): parts that show when he is awake.
	local mouth = Instance.new("Model")
	mouth.Name = "AwakeMouth"
	local mouthParts: { Part } = {}
	for index, name in { "Mouth", "Tongue" } do
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.Size = Vector3.new(4, 2, 1)
		part.CFrame = CFrame.new(0, 80 + index, -4)
		part.Transparency = 1
		part:SetAttribute("ShownWhenAwake", true)
		part.Parent = mouth
		table.insert(mouthParts, part)
	end
	mouth.Parent = giant
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
	-- The "!" and the bubble pop, as in the place (World.GiantFX.BangAnchor): two guis made of Frames and outlines, sized
	-- by scale, off at the start. Their looks are not 0, so a test can tell a restored look from a default.
	local bangAnchor = Instance.new("Part")
	bangAnchor.Name = "BangAnchor"
	bangAnchor.Anchored = true
	bangAnchor.CFrame = CFrame.new(-8, 104, -22)
	bangAnchor.Parent = fx
	local bangLooks: { [Instance]: number } = {}
	local function newPopGui(name: string, studs: number): BillboardGui
		local gui = Instance.new("BillboardGui")
		gui.Name = name
		gui.Enabled = false
		gui.Size = UDim2.fromScale(studs, studs)
		local disc = Instance.new("Frame")
		disc.Name = "Disc"
		disc.Size = UDim2.fromScale(1, 1)
		disc.BackgroundTransparency = 0.1
		disc.Parent = gui
		local mark = Instance.new("Frame")
		mark.Name = "Mark"
		mark.Size = UDim2.fromScale(0.2, 0.6)
		mark.BackgroundTransparency = 0.3
		mark.Parent = disc
		local outline = Instance.new("UIStroke")
		outline.Transparency = 0.2
		outline.Parent = disc
		if name == "Bang" then
			bangLooks[disc] = disc.BackgroundTransparency
			bangLooks[mark] = mark.BackgroundTransparency
			bangLooks[outline] = outline.Transparency
		end
		gui.Parent = bangAnchor
		return gui
	end
	local bang = newPopGui("Bang", 22)
	local zpop = newPopGui("ZPop", 18)
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
	-- How far the server's clock is ahead of the rig clock (Workspace:GetServerTimeNow in the game).
	local serverOffset = 0
	-- What the screen and the camera say right now; a test changes them with setPhone and the others.
	local onPhone = false
	local cameraRightZ = 0
	local reducedMotion = false
	local signs: { string } = {}
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
	-- The stand-in for the sound setting: it records each call with the seconds since the rig was built.
	local sounds: { SoundCall } = {}

	-- Where the pieces are before the module starts: a module that starts while he is awake moves them at once.
	local armStart = arm:GetPivot()
	local leftStart = leftLid:GetPivot()
	local rightStart = rightLid:GetPivot()
	local headStart = head:GetPivot()
	local capStart = cap:GetPivot()
	local awakeEyesStart = awakeEyes:GetPivot()
	local mouthStart = mouth:GetPivot()

	local handle = GiantFx.start({
		world = world,
		warning = { OnClientEvent = warning },
		slamWarning = { OnClientEvent = slamWarning },
		giantState = state,
		step = step,
		now = function()
			return clock
		end,
		serverNow = function()
			return clock + serverOffset
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
		onSignsChanged = function(sign: string)
			table.insert(signs, sign)
		end,
		playSound = if withSound ~= false
			then function(name: string, at: Vector3?)
				table.insert(sounds, { name = name, at = at, time = clock - 100 })
			end
			else nil,
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
		signs = signs,
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
		setServerOffset = function(seconds: number)
			serverOffset = seconds
		end,
		setPhaseEnds = function(serverTime: number?)
			state:SetAttribute("PhaseEndsAt", serverTime)
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
		mouth = mouth,
		mouthParts = mouthParts,
		mouthStart = mouthStart,
		bangAnchor = bangAnchor,
		bang = bang,
		zpop = zpop,
		bangSize = bang.Size,
		zpopSize = zpop.Size,
		bangLooks = bangLooks,
		sounds = sounds,
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

-- The angle in degrees between two directions.
local function degreesBetween(first: Vector3, second: Vector3): number
	local cosine = math.clamp(first.Unit:Dot(second.Unit), -1, 1)
	return math.deg(math.acos(cosine))
end

-- The fixed pose the arm goes to when a straight swing would pass through his body: 70 degrees forward and 25 degrees
-- out to his right, as a direction in the giant's own axes (he faces -Z, his right is +X).
local FIXED_DIRECTION = Vector3.new(0.4226, -0.3100, -0.8517)

-- Moves the clock on until the wake face (the "!") has finished by itself, so the step is let go of. The end time comes
-- from the game's own code: the "!" goes off when its face is over. Gives up after 10 seconds.
local function finishFace(rig: Rig)
	for _ = 1, 200 do
		if not rig.bang.Enabled then
			return
		end
		rig.advance(0.05)
	end
end

return {
	FIXED_DIRECTION = FIXED_DIRECTION,
	GIANT_PIVOT = GIANT_PIVOT,
	HEAD_PIVOT = HEAD_PIVOT,
	HEAD_TILT_DEGREES = HEAD_TILT_DEGREES,
	RAISE_DEGREES = RAISE_DEGREES,
	SHOULDER = SHOULDER,
	cleanUp = cleanUp,
	degreesBetween = degreesBetween,
	finishFace = finishFace,
	made = made,
	newRig = newRig,
	samePlace = samePlace,
}
