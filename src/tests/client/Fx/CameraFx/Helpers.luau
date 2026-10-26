--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local CameraFx = require(StarterPlayer.StarterPlayerScripts.Client.Fx.CameraFx)

-- How far the view points above (positive) or below (negative) the horizon, in degrees.
local function pitchOf(cframe: CFrame): number
	return math.deg(math.asin(cframe.LookVector.Y))
end

local FRAME = 1 / 60

local BOUNCE_UP = 30

local SPAWN_UP = 21 -- Roblox's -15 plus the 36 degree tilt

local EASE_SECONDS = 0.6

local rigs: { any } = {}

local madeInstances: { Instance } = {}

local function cleanUp()
	for _, rig in rigs do
		rig.watcher.stop()
	end
	table.clear(rigs)
	for _, instance in madeInstances do
		instance:Destroy()
	end
	table.clear(madeInstances)
end

local function track(instance: Instance): Instance
	table.insert(madeInstances, instance)
	return instance
end

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
	}
end

local function waitUntil(condition: () -> boolean)
	local deadline = os.clock() + 3
	while not condition() and os.clock() < deadline do
		task.wait()
	end
end

local function flatOf(look: Vector3): Vector3
	return Vector3.new(look.X, 0, look.Z).Unit
end

-- A character with a Humanoid, a root that faces `facing` and a head 2 studs above it.
local function newCharacter(facing: Vector3): (Model, Humanoid, Part)
	local character = Instance.new("Model")
	track(character)
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = CFrame.lookAt(Vector3.new(0, 5, 0), Vector3.new(0, 5, 0) + facing)
	root.Parent = character
	local head = Instance.new("Part")
	head.Name = "Head"
	head.CFrame = CFrame.new(0, 7, 0)
	head.Parent = character
	return character, humanoid, root
end

-- The tree Roblox's camera input lives in, so the turn signal can be found (and read through `readState`).
local function inputTree(): Folder
	local tree = Instance.new("Folder")
	track(tree)
	local names = { "PlayerModule", "InputContexts", "CameraContext" }
	local parent: Instance = tree
	for _, name in names do
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
		parent = folder
	end
	local action = Instance.new("InputAction")
	action.Name = "CameraRotationAction"
	action.Type = Enum.InputActionType.Direction2D
	action.Parent = parent
	return tree
end

-- Starts a watcher on a player with one character that faces +X. `frame(seconds)` plays one frame: the clock moves,
-- everything waiting for a frame carries on, then the bound ease step (if any) runs.
-- `options.eggDegrees`: the first egg sits that many degrees to the right of the way the root faces (negative is left),
-- 30 studs away; without it no egg waits. `options.noFinder`: the watcher is given no egg finder at all.
-- `options.realTurn`: the watcher is given no stand-in for turning the character, so it uses its own.
export type RigOptions = { eggDegrees: number?, noFinder: boolean?, realTurn: boolean? }

-- The place of an egg `degreesRight` to the right of the way `root` faces, `distance` studs away, flat with the root.
local function eggBeside(root: BasePart, degreesRight: number, distance: number?): Vector3
	local far = distance or 30
	local radians = math.rad(degreesRight)
	return (root.CFrame * CFrame.new(math.sin(radians) * far, 0, -math.cos(radians) * far)).Position
end

local function newRig(options: RigOptions?)
	local settings: RigOptions = options or {}
	local character, humanoid, root = newCharacter(Vector3.xAxis)
	local focus = Vector3.new(0, 7, 0)
	local rig: any = {
		egg = if settings.eggDegrees ~= nil then eggBeside(root, settings.eggDegrees) else nil,
		eggCalls = 0,
		turns = {} :: { Vector3 },
		cameraAtTurn = nil :: CFrame?,
		heightBinds = 0,
		heightActive = 0,
		heightStep = nil :: (() -> ())?,
		clock = 100,
		moving = false,
		floor = Enum.Material.Grass,
		turning = false,
		waiting = {} :: { thread },
		binds = 0,
		unbinds = 0,
		active = 0,
		step = nil :: (() -> ())?,
		character = character,
		humanoid = humanoid,
		root = root,
		camera = {
			CFrame = CameraFx.spawnView(focus, Vector3.new(0.6, 0, 0.8), 12.5, -15),
			Focus = CFrame.new(focus),
			CameraSubject = humanoid,
			CameraType = Enum.CameraType.Custom,
		},
		characterAdded = newSignal(),
		player = nil :: any,
	}
	rig.player = { Character = character, CharacterAdded = rig.characterAdded }

	function rig.frame(seconds: number)
		rig.clock += seconds
		local list = rig.waiting
		rig.waiting = {}
		for _, parked in list do
			task.spawn(parked)
		end
		if rig.step then
			rig.step()
		end
		if rig.heightStep then
			rig.heightStep()
		end
	end

	function rig.frames(count: number)
		for _ = 1, count do
			rig.frame(FRAME)
		end
	end

	local function bind(step: () -> ()): () -> ()
		rig.binds += 1
		rig.active += 1
		rig.step = step
		return function()
			rig.unbinds += 1
			rig.active -= 1
			rig.step = nil
		end
	end

	-- The watcher is waiting for its first frame once the normal camera has "settled" (the real wait for that is a
	-- few real frames) and the view is placed; one more frame puts it in the waiting loop.
	function rig.settle()
		waitUntil(function()
			return #rig.waiting > 0
		end)
		rig.frame(FRAME)
	end

	-- The server's float: the push on the root, the player in the air.
	function rig.takeOff()
		local push = Instance.new("LinearVelocity")
		push.Name = "BounceFloat"
		push.Parent = rig.root
		rig.floor = Enum.Material.Air
	end

	function rig.land()
		for _, child in rig.root:GetChildren() do
			if child.Name == "BounceFloat" then
				child:Destroy()
			end
		end
		rig.floor = Enum.Material.Grass
	end

	-- A bounce as the player's device sees it: the push is on the root, then the remote arrives. One frame later the
	-- view is placed and the watcher waits for the landing.
	function rig.float(look: Vector3)
		rig.takeOff()
		rig.watcher.bounce(look)
		rig.frame(FRAME)
	end

	function rig.distance(): number
		return (rig.camera.CFrame.Position - rig.camera.Focus.Position).Magnitude
	end

	function rig.pitch(): number
		return pitchOf(rig.camera.CFrame)
	end

	local function bindHeight(step: () -> ()): () -> ()
		rig.heightBinds += 1
		rig.heightActive += 1
		rig.heightStep = step
		return function()
			rig.heightActive -= 1
			rig.heightStep = nil
		end
	end

	local tree = inputTree()
	local parts: any = {
		bindAfterCamera = bind,
		bindHeight = bindHeight,
		containers = { tree :: Instance? },
		readState = function(_action: InputAction): unknown
			return if rig.turning then Vector2.new(1, 0) else Vector2.zero
		end,
		moveDirection = function(_humanoid: Humanoid): Vector3
			return if rig.moving then Vector3.new(0, 0, -1) else Vector3.zero
		end,
		floorMaterial = function(_humanoid: Humanoid): Enum.Material
			return rig.floor
		end,
	}
	if not settings.noFinder then
		parts.firstEgg = function(): Vector3?
			rig.eggCalls += 1
			return rig.egg
		end
	end
	if not settings.realTurn then
		-- Turns the root like the real piece does (about the vertical, keeping its place) and notes what the camera was.
		parts.turnCharacter = function(turnedCharacter: Model, look: Vector3)
			table.insert(rig.turns, look)
			rig.cameraAtTurn = rig.camera.CFrame
			local turnedRoot = turnedCharacter:FindFirstChild("HumanoidRootPart") :: BasePart
			turnedRoot.CFrame = CFrame.lookAt(turnedRoot.Position, turnedRoot.Position + look)
		end
	end
	rig.watcher = CameraFx.watch(
		rig.player,
		function()
			return rig.camera :: any
		end,
		36,
		EASE_SECONDS,
		function()
			table.insert(rig.waiting, coroutine.running())
			coroutine.yield()
		end,
		function()
			return rig.clock
		end,
		parts
	)
	table.insert(rigs, rig)
	return rig
end

local function newSettledRig(options: RigOptions?)
	local rig = newRig(options)
	rig.settle()
	return rig
end

return {
	BOUNCE_UP = BOUNCE_UP,
	EASE_SECONDS = EASE_SECONDS,
	FRAME = FRAME,
	SPAWN_UP = SPAWN_UP,
	cleanUp = cleanUp,
	eggBeside = eggBeside,
	flatOf = flatOf,
	newCharacter = newCharacter,
	newRig = newRig,
	newSettledRig = newSettledRig,
	newSignal = newSignal,
	pitchOf = pitchOf,
	rigs = rigs,
	track = track,
	waitUntil = waitUntil,
}
