--!strict
-- Wires the client together. The rules live in the modules next to this script.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local CameraFx = require(script.Fx.CameraFx)
local Celebrations = require(script.Fx.Celebrations)
local FlowerShake = require(script.Fx.FlowerShake)
local GiantFx = require(script.Fx.GiantFx)
local NestPop = require(script.Fx.NestPop)
local SlamFx = require(script.Fx.SlamFx)
local WakeWorld = require(script.Fx.WakeWorld)
local BonkFx = require(script.Fx.BonkFx)
local RouteData = require(ReplicatedStorage.Shared.RouteData)
local ClimbGate = require(script.Player.ClimbGate)
local Recovery = require(script.Player.Recovery)
local RescueFx = require(script.Fx.RescueFx)
local GrabPrompt = require(script.Hud.GrabPrompt)
local Messages = require(script.Hud.Messages)
local HuntView = require(script.Hud.HuntView)
local Layout = require(script.Hud.Layout)
local MeterZs = require(script.Hud.MeterZs)
local MeterZsView = require(script.Hud.MeterZsView)
local RedEdges = require(script.Hud.RedEdges)
local RunHome = require(script.Hud.RunHome)
local SleepMeterUi = require(script.Hud.SleepMeterUi)
local Ui = require(script.Hud.Ui)
local TiptoeButton = require(script.Hud.TiptoeButton)
local Moments = require(script.Audio.Moments)
local Music = require(script.Audio.Music)
local Snore = require(script.Audio.Snore)
local SoundBoard = require(script.Audio.SoundBoard)
local BodyBeams = require(script.World.BodyBeams)
local EggFade = require(script.World.EggFade)
local Footprints = require(script.World.Footprints)
local RankGlowView = require(script.World.RankGlowView)
local RouteGraph = require(script.World.RouteGraph)
local SpotLabels = require(script.World.SpotLabels)

-- Seconds to wait for the server's remotes and the giant's state before carrying on without them.
local NET_WAIT_SECONDS = 15

-- The sound board (plan 7): the buses and one player per sound file, built once on this device, with one real speaker
-- output. Music (Task 6) plays the two tunes on it, below; the later audio tasks call play with a row's name.
local soundRoot = Instance.new("Folder")
soundRoot.Name = "SoundBoard"
soundRoot.Parent = SoundService
local speakers = Instance.new("AudioDeviceOutput")
speakers.Name = "Speakers"
speakers.Parent = soundRoot
local soundBoard = SoundBoard.start({
	root = soundRoot,
	output = speakers,
	worldParent = Workspace.Terrain,
	startPlaying = function(player: AudioPlayer)
		player:Play()
	end,
	isReady = function(player: AudioPlayer): boolean
		return player.IsReady
	end,
	ended = function(player: AudioPlayer, callback: () -> ()): SoundBoard.Disconnectable
		local connection = player.Ended:Connect(callback)
		return {
			Disconnect = function()
				connection:Disconnect()
			end,
		}
	end,
	fadeOut = function(copy: AudioPlayer, afterSeconds: number, seconds: number)
		-- The cut sound's last moments fade to nothing so the cut doesn't click (the snort's 0.05 s).
		TweenService:Create(
			copy,
			TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, afterSeconds),
			{
				Volume = 0,
			}
		):Play()
	end,
	now = os.clock,
})

-- The named sound places (a name from the game's code to a sound board row, see Cues): the snorts, mumble, the wake-up
-- sounds, the yawn and the players' boings. A name with no row plays nothing.
local moments = Moments.start({
	board = soundBoard,
	after = function(seconds: number, callback: () -> ())
		task.delay(seconds, callback)
	end,
	playerList = Players,
	rootOf = function(player: Instance): Vector3?
		local character = if player:IsA("Player") then player.Character else nil
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		return if root ~= nil and root:IsA("BasePart") then root.Position else nil
	end,
	localPlayer = Players.LocalPlayer,
})
script.Destroying:Once(moments.destroy)

-- The route and the egg spots never stream out (they are Persistent), so they are there at once. The camera needs them from
-- the very first spawn, to turn the player away from the egg the footprints lead to. The footprints below use the same ones.
local footprintWorld = Workspace:WaitForChild("World", NET_WAIT_SECONDS)
local route = if footprintWorld then footprintWorld:WaitForChild("Route", NET_WAIT_SECONDS) else nil
local footprintSpots = if footprintWorld then footprintWorld:WaitForChild("EggSpots", NET_WAIT_SECONDS) else nil
local routePoints: { RouteGraph.Point } = {}
if route then
	local points, problems = RouteData.read(route)
	if #problems > 0 then
		warn(`The footprint route has problems: {table.concat(problems, "; ")}`)
	end
	routePoints = points
end

-- Where the egg the footprints lead to is right now (the same answer the footprints use), or nil. Without the route or the
-- egg spots the camera gets no finder, and simply never turns the player.
local findFirstEgg: (() -> Vector3?)? = nil
if route and footprintSpots then
	local routeGraph = RouteGraph.new(routePoints)
	local localPlayer = Players.LocalPlayer
	findFirstEgg = function(): Vector3?
		return Footprints.firstEgg(routeGraph, footprintSpots, localPlayer, Footprints.feetOf(localPlayer.Character))
	end
end

local cameraWatcher = CameraFx.watch(Players.LocalPlayer, function()
	return Workspace.CurrentCamera
end, Config.Spawn.CameraTiltUpDegrees, Config.Spawn.EaseBackSeconds, nil, nil, { firstEgg = findFirstEgg })

-- The sleep meter, the Tiptoe button and the messages need the server's remotes and the giant's state, so this part waits for
-- them (after the camera is set up).
local server = Net.waitForClient(ReplicatedStorage, NET_WAIT_SECONDS)
-- The art the place holds for the client: the footprint, the slam fist and the caught star puff.
local assets = ReplicatedStorage:WaitForChild("Assets", NET_WAIT_SECONDS)
if server then
	-- When the server bounces this player off the giant, it sends the way they now face, and the camera snaps behind
	-- them. The server decides what is sent, and the watcher checks it anyway.
	local bouncedConnection = server.Bounced.OnClientEvent:Connect(cameraWatcher.bounce)
	-- When the server moves this player back to a safe spot, this device moves its own character there too.
	-- It also takes over Roblox's Reset button: a Reset asks the server, which decides what happens.
	local recovery = Recovery.start({
		rescued = server.Rescued.OnClientEvent,
		localPlayer = Players.LocalPlayer,
		setCore = function(name: string, value: any)
			StarterGui:SetCore(name :: any, value)
		end,
		requestReset = function()
			server.RequestReset:FireServer()
		end,
		wait = task.wait,
		setPressing = function(on: boolean)
			server.SetPressing:FireServer(on)
		end,
		humanoidOf = function(character: Model)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
				or character:WaitForChild("Humanoid", NET_WAIT_SECONDS)
			return humanoid :: any -- a real Humanoid has both members that HumanoidLike names
		end,
	})
	script.Destroying:Once(function()
		recovery:destroy()
	end)
	-- Only the four wooden ladders climb: everywhere else this device's Humanoid has its Climbing state switched off.
	local climbGate = ClimbGate.start({
		localPlayer = Players.LocalPlayer,
		findLadders = ClimbGate.findLadders,
		eachStep = ClimbGate.eachStep,
	})
	script.Destroying:Once(function()
		climbGate:destroy()
	end)
	-- A lavender puff with gold sparkles hides each rescue, for every player, where they were and where they are now.
	local rescueFx = RescueFx.start({
		rescued = server.Rescued.OnClientEvent,
		parent = Workspace,
		after = function(seconds: number, fn: () -> ())
			task.delay(seconds, fn)
		end,
		emit = function(emitter: ParticleEmitter, count: number)
			emitter:Emit(count)
		end,
	})
	script.Destroying:Once(function()
		rescueFx.destroy()
	end)
	-- When he wakes, the screen shakes (the camera's point moves by at most 1.5 studs for 1 second), and each slam shakes it
	-- by how near it lands (at most 1 stud for 0.4 seconds, none from 60 studs). Reduce Motion turns both off, and changes no
	-- sound (Rule 88): the wake rumble plays either way.
	-- The two slam remotes, as plain signals (the shaker's optional fields don't take an engine signal directly).
	local slamWarningSignal: SlamFx.SignalLike = server.SlamWarning.OnClientEvent
	local slamLandedSignal: SlamFx.SignalLike = server.SlamLanded.OnClientEvent
	local shaker = CameraFx.shakeOnWake({
		giantState = server.GiantState,
		player = Players.LocalPlayer,
		step = RunService.RenderStepped,
		now = os.clock,
		slamWarning = { OnClientEvent = slamWarningSignal },
		slamLanded = { OnClientEvent = slamLandedSignal },
		serverNow = function()
			return Workspace:GetServerTimeNow()
		end,
		reducedMotion = function(): boolean
			return GuiService.ReducedMotionEnabled
		end,
		playSound = moments.play,
	})
	script.Destroying:Once(function()
		bouncedConnection:Disconnect()
		cameraWatcher.stop()
		shaker.stop()
	end)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	-- The Z Z Z beside the sleep meter. GiantFx says what they should look like; the meter says where they go.
	local meterZs = MeterZs.new(Ui.hudTop(playerGui), {
		reducedMotion = function(): boolean
			return GuiService.ReducedMotionEnabled
		end,
	})
	script.Destroying:Once(meterZs.destroy)
	-- The red RUN HOME! pill right of the meter (spec 6 Rule 67). HuntView says when it shows, from the giant's phase and
	-- this player's own attributes; each change of one of them asks again (no polling). The meter says where it sits.
	local runHome = RunHome.new(Ui.hudTop(playerGui))
	local runHomeScreen: Layout.Screen? = nil
	local runHomeShown = false
	-- The same view also feeds the bottom tip (Messages): `latestView` is its latest answer, and `viewListeners` are told
	-- after each change. There is still one watcher.
	local latestView: HuntView.View = { runHome = false, edges = false, tip = "none" }
	local viewListeners: { [() -> ()]: true } = {}
	local stopRunHome = HuntView.watch(server.GiantState, Players.LocalPlayer, function(view: HuntView.View)
		latestView = view
		runHomeShown = view.runHome
		runHome.setShown(view.runHome)
		for listener in table.clone(viewListeners) do
			listener()
		end
	end)
	script.Destroying:Once(function()
		stopRunHome()
		runHome.destroy()
	end)
	-- The red edges while he hunts you (spec 6 Rule 68): the same view's `edges`, through one more listener.
	local redEdges = RedEdges.new(playerGui, {
		step = RunService.RenderStepped,
		now = os.clock,
		screenSize = function(): Vector2
			local camera = Workspace.CurrentCamera
			return if camera then camera.ViewportSize else Vector2.new(1280, 720)
		end,
		reducedMotion = function(): boolean
			return GuiService.ReducedMotionEnabled
		end,
	})
	local function showRedEdges()
		redEdges.setEdges(latestView.edges)
	end
	viewListeners[showRedEdges] = true
	redEdges.setEdges(latestView.edges)
	script.Destroying:Once(function()
		viewListeners[showRedEdges] = nil
		redEdges.destroy()
	end)
	SleepMeterUi.start({
		onLayout = function(screen: Layout.Screen, meterRight: number)
			meterZs.place(screen, meterRight)
			runHomeScreen = screen
			runHome.place(screen, meterRight)
		end,
		parent = playerGui,
		giantState = server.GiantState,
		warning = { OnClientEvent = server.Warning.OnClientEvent },
		viewport = SleepMeterUi.workspaceViewport(Workspace),
		topbarInset = SleepMeterUi.guiServiceTopbar(GuiService),
		createTween = function(instance: Instance, info: TweenInfo, goal: { [string]: any })
			return TweenService:Create(instance, info, goal)
		end,
		now = function()
			return Workspace:GetServerTimeNow()
		end,
	})
	TiptoeButton.start({
		parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
		player = Players.LocalPlayer,
		send = function(on: boolean)
			server.SetTiptoe:FireServer(on)
		end,
		input = UserInputService,
		warning = { OnClientEvent = server.Warning.OnClientEvent },
		step = RunService.RenderStepped,
		now = os.clock,
		viewport = SleepMeterUi.workspaceViewport(Workspace),
	})
	local messagesHandle = Messages.start({
		parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
		player = Players.LocalPlayer,
		grabMissed = { OnClientEvent = server.GrabMissed.OnClientEvent },
		eggHome = { OnClientEvent = server.EggHome.OnClientEvent },
		warning = { OnClientEvent = server.Warning.OnClientEvent },
		caught = { OnClientEvent = server.Caught.OnClientEvent },
		slideTip = { OnClientEvent = server.SlideTip.OnClientEvent },
		giantState = server.GiantState,
		huntView = {
			get = function(): HuntView.View
				return latestView
			end,
			connect = function(callback: () -> ()): () -> ()
				viewListeners[callback] = true
				return function()
					viewListeners[callback] = nil
				end
			end,
		},
		viewport = SleepMeterUi.workspaceViewport(Workspace),
	})
	-- The grab prompts on the egg spots use the Custom style, so GrabPrompt draws them and switches them off while
	-- the player carries an egg or the spot is empty. The egg spots never stream out (they are Persistent), so they are
	-- always there.
	local world = Workspace:WaitForChild("World", NET_WAIT_SECONDS)
	local eggSpots = if world then world:WaitForChild("EggSpots", NET_WAIT_SECONDS) else nil
	-- Confetti from the banker's own Safe Gate and "+1 egg" over the new egg, for every egg that comes home. The gates
	-- never stream out (they are Persistent), but the finder looks again every time and skips what isn't there.
	if world then
		local findSpawnSpot = Celebrations.spawnSpotInWorld(world)
		moments.hearEggHome({ OnClientEvent = server.EggHome.OnClientEvent }) -- the egg-home sounds (plan 7 Task 11)
		moments.hearEggPop({ OnClientEvent = server.EggPop.OnClientEvent }) -- the egg-pop sounds (plan 7 Task 12)
		moments.hearThud({ OnClientEvent = server.Thud.OnClientEvent }) -- the landing flump (plan 7 Task 13)
		Celebrations.start({
			eggHome = { OnClientEvent = server.EggHome.OnClientEvent },
			findEmitter = Celebrations.emitterInWorld(world),
			caught = { OnClientEvent = server.Caught.OnClientEvent },
			localPlayer = Players.LocalPlayer, -- only your own "Caught" plays a sound
			playSound = moments.play,
			findSpawnSpot = findSpawnSpot,
			poofTemplate = if assets then assets:FindFirstChild("CaughtPoof") else nil,
			burst = function(emitter: ParticleEmitter, count: number)
				emitter:Emit(count)
			end,
			anchorParent = Workspace.Terrain,
			step = RunService.RenderStepped,
			now = os.clock,
		})
		-- The giant himself: the eyelids at 60, at 85 the snort, the Z Z Z, the puffs and the bubble beside his nose, the
		-- waking pose, and the arm swinging toward each slam. The bubble reads three things each time it is placed: whether
		-- this is a phone screen, which way the camera's right side points, and whether Reduce Motion is on.
		local function currentCamera(): Camera?
			return Workspace.CurrentCamera
		end
		-- The snore (plan 7 Task 7): GiantFx says when the puffs are on, and the snore plays from his mouth while they are.
		local mouthPart: BasePart? = nil
		local function snoreMouth(): Vector3?
			if mouthPart == nil or mouthPart.Parent == nil then
				local giant = world:FindFirstChild("Giant")
				local awake = if giant then giant:FindFirstChild("AwakeMouth") else nil
				local found = if awake then awake:FindFirstChild("Mouth") else nil
				mouthPart = if found and found:IsA("BasePart") then found else nil
			end
			return if mouthPart ~= nil then mouthPart.Position else nil
		end
		local snore = Snore.start({
			board = soundBoard,
			step = RunService.RenderStepped,
			now = os.clock,
			meter = function(): number
				local value: any = server.GiantState:GetAttribute("Meter")
				return if type(value) == "number" then value else 0
			end,
			mouth = snoreMouth,
			random = math.random,
			looped = function(copy: AudioPlayer, callback: () -> ()): SoundBoard.Disconnectable
				local connection = copy.Looped:Connect(callback)
				return {
					Disconnect = function()
						connection:Disconnect()
					end,
				}
			end,
		})
		script.Destroying:Once(snore.destroy)
		GiantFx.start({
			world = world,
			playSound = moments.play,
			stopSound = moments.stop,
			warning = { OnClientEvent = server.Warning.OnClientEvent },
			slamWarning = { OnClientEvent = server.SlamWarning.OnClientEvent },
			giantState = server.GiantState,
			step = RunService.RenderStepped,
			now = os.clock,
			serverNow = function()
				return Workspace:GetServerTimeNow()
			end,
			armClear = GiantFx.workspaceArmClear(Workspace, world),
			isPhone = function(): boolean
				local camera = currentCamera()
				-- No camera yet: a computer screen, as the meter assumes.
				return camera ~= nil and Layout.isPhone(camera.ViewportSize)
			end,
			cameraRight = function(): Vector3
				local camera = currentCamera()
				return if camera ~= nil then camera.CFrame.RightVector else Vector3.xAxis
			end,
			reducedMotion = function(): boolean
				return GuiService.ReducedMotionEnabled
			end,
			onSignsChanged = function(sign: GiantFx.Sign)
				meterZs.setLook(MeterZsView.look(sign))
			end,
			onPuffsChanged = snore.setPuffs,
		})
		-- The world reacts to the wake: 24 birds fly off behind him and 7 dust spots on his body puff. Without its assets it
		-- is not started.
		local wakeBirds = if assets then assets:WaitForChild("WakeBirds", NET_WAIT_SECONDS) else nil
		local giantFxFolder = if world then world:WaitForChild("GiantFX", NET_WAIT_SECONDS) else nil
		local wakeDust = if giantFxFolder then giantFxFolder:WaitForChild("WakeDust", NET_WAIT_SECONDS) else nil
		if wakeBirds ~= nil and giantFxFolder ~= nil and wakeDust ~= nil then
			local stopWakeWorld = WakeWorld.start({
				giantState = server.GiantState,
				birds = wakeBirds,
				dust = wakeDust,
				parent = giantFxFolder,
				step = RunService.RenderStepped,
				now = os.clock,
				emit = function(emitter: ParticleEmitter, count: number)
					emitter:Emit(count)
				end,
				playSound = moments.play,
			})
			script.Destroying:Once(stopWakeWorld)
		else
			warn("WakeWorld not started: Assets.WakeBirds or World.GiantFX.WakeDust is missing")
		end
		-- The bonk on screen: every player's `Bonked` attribute tips their body and shows stars and a puff (spec Rule 61).
		local stopBonkFx = BonkFx.start({
			playSound = moments.play,
			players = function()
				return Players:GetPlayers()
			end,
			playerAdded = Players.PlayerAdded,
			playerRemoving = Players.PlayerRemoving,
			step = RunService.PreSimulation,
			now = os.clock,
			reducedMotion = function()
				return GuiService.ReducedMotionEnabled
			end,
			burst = function(emitter: ParticleEmitter, count: number)
				emitter:Emit(count)
			end,
		})
		script.Destroying:Once(stopBonkFx)
		-- When a hand slam catches this player, the server puts them on their own spawn spot and tells every device. Their
		-- camera snaps behind them there. The spawn spot is a loose part, so with streaming it can be missing for a moment:
		-- the camera waits for it, for a short time.
		local cancelSnap: (() -> ())? = nil
		local caughtConnection = server.Caught.OnClientEvent:Connect(function(who: any)
			if who ~= Players.LocalPlayer then
				return
			end
			if cancelSnap then
				cancelSnap()
			end
			cancelSnap = CameraFx.whenSpotIsThere(function()
				local plotIndex: any = Players.LocalPlayer:GetAttribute("PlotIndex")
				return if type(plotIndex) == "number" then findSpawnSpot(plotIndex) else nil
			end, cameraWatcher.caught)
		end)
		script.Destroying:Once(function()
			caughtConnection:Disconnect()
			if cancelSnap then
				cancelSnap()
			end
		end)
	else
		warn("The world was not found, so the safe-home confetti, +1 egg and the giant's warnings have no look.")
	end
	if eggSpots then
		GrabPrompt.start({
			parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
			service = {
				PromptShown = ProximityPromptService.PromptShown,
				PromptHidden = ProximityPromptService.PromptHidden,
				PromptButtonHoldBegan = ProximityPromptService.PromptButtonHoldBegan,
				PromptButtonHoldEnded = ProximityPromptService.PromptButtonHoldEnded,
			},
			player = Players.LocalPlayer,
			root = eggSpots,
			step = RunService.RenderStepped,
			now = os.clock,
			viewport = SleepMeterUi.workspaceViewport(Workspace),
			-- On a phone the pill pins to the bottom centre when the egg's point is low or off the screen, and the
			-- bottom tips hide while it is pinned (Task 56).
			project = function(adornee: Instance): Vector2?
				local camera = Workspace.CurrentCamera
				if camera == nil or not adornee:IsA("Attachment") then
					return nil
				end
				local point = camera:WorldToViewportPoint(adornee.WorldPosition)
				if point.Z <= 0 then
					return nil
				end
				return Vector2.new(point.X, point.Y)
			end,
			onPinned = messagesHandle.setPillPinned,
		})
		-- The rarity names over waiting eggs (an empty spot shows nothing, Rule 77). A rarity name fades while it
		-- overlaps a nearer one, touches the sleep meter or reaches past the top of the screen. The meter's box is read
		-- in the same pixels the world is projected into: the meter's screen reports positions from just below the top
		-- bar, so the bar's height is added back (SpotLabels.screenRect). The pill's box is read the same way while it
		-- shows, widened to what it paints (RunHome.paintedBox: the tilt turns it about its centre, and its outline
		-- and shadow reach past it).
		SpotLabels.start({
			parent = playerGui,
			root = eggSpots,
			now = function()
				return Workspace:GetServerTimeNow()
			end,
			step = RunService.RenderStepped,
			view = SpotLabels.screenView(
				function()
					return Workspace.CurrentCamera
				end,
				function(): SpotLabels.Rect?
					local hudTop = playerGui:FindFirstChild("HudTop")
					local meter = if hudTop then hudTop:FindFirstChild("SleepMeter") else nil
					local panel = if meter then meter:FindFirstChild("Panel") else nil
					if panel == nil or not panel:IsA("GuiObject") then
						return nil
					end
					return SpotLabels.screenRect(panel, GuiService:GetGuiInset())
				end,
				nil,
				function(): SpotLabels.Rect?
					local hudTop = playerGui:FindFirstChild("HudTop")
					local pill = if hudTop then hudTop:FindFirstChild("RunHome") else nil
					local screen = runHomeScreen
					if pill == nil or not pill:IsA("GuiObject") or screen == nil or not runHomeShown then
						return nil
					end
					local box = SpotLabels.screenRect(pill, GuiService:GetGuiInset())
					return if box then RunHome.paintedBox(box, screen) else nil
				end
			),
		})
		-- When an empty nest gets its egg back, the egg grows in and gold stars rise (Rule 77). The stars are the
		-- RefillPop part the place holds; without it only the grow-in plays. Reduce Motion drops the grow-in and
		-- keeps still stars.
		local refillPop = if assets then assets:WaitForChild("RefillPop", NET_WAIT_SECONDS) else nil
		local nestPop = NestPop.start({
			root = eggSpots,
			template = if refillPop and refillPop:IsA("BasePart") then refillPop else nil,
			reducedMotion = function(): boolean
				return GuiService.ReducedMotionEnabled
			end,
			step = RunService.RenderStepped,
			now = os.clock,
			emit = function(emitter: ParticleEmitter, count: number)
				emitter:Emit(count)
			end,
		})
		script.Destroying:Once(nestPop)
		-- An egg between the camera and this player's own character turns 70% see-through on this screen only. The egg this
		-- player carries on their back fades when it covers their head or body (a box at 75% of its size), to 60%, and
		-- waits 0.2 s with no line crossing before it starts back to solid.
		local eggFade = EggFade.start({
			root = eggSpots,
			camera = function()
				local camera = Workspace.CurrentCamera
				return if camera then camera.CFrame else nil
			end,
			targets = function()
				return EggFade.targetsOf(Players.LocalPlayer.Character)
			end,
			carried = function()
				local character = Players.LocalPlayer.Character
				local egg = if character then character:FindFirstChild("CarriedEgg") else nil
				return if egg and egg:IsA("Model") then egg else nil
			end,
			step = RunService.RenderStepped,
			now = os.clock,
		})
		script.Destroying:Once(eggFade.stop)
		-- The light beam of an egg on his body turns off while the camera is within 30 studs of it, and on again beyond 35
		-- (this screen only). Which eggs are on his body is read from the zone boxes in World.Zones.
		if world then
			local bodyBeams = BodyBeams.start({
				root = eggSpots,
				isOnBody = BodyBeams.bodyReader(world),
				camera = function()
					local camera = Workspace.CurrentCamera
					return if camera then camera.CFrame else nil
				end,
				step = RunService.RenderStepped,
			})
			script.Destroying:Once(bodyBeams.stop)
		end
		-- The rank glow: a halo of see-through rings behind every waiting egg above Common, hidden up close and strongest
		-- from 75 studs (this screen only).
		local rankGlow = RankGlowView.start({
			root = eggSpots,
			camera = function()
				local camera = Workspace.CurrentCamera
				return if camera then camera.CFrame else nil
			end,
			step = RunService.RenderStepped,
		})
		script.Destroying:Once(rankGlow.stop)
	else
		warn("The egg spots were not found, so the grab prompts and the egg labels have no look.")
	end
end

-- The glowing footprints (spec Rule 2). The route and the egg spots were looked up above, and the footprint model comes
-- with the place. If any of them is missing, the player plays on without footprints.
local footprintTemplate = if assets then assets:WaitForChild("Footprint", NET_WAIT_SECONDS) else nil
if route and footprintSpots and footprintTemplate and footprintTemplate:IsA("Model") then
	local localPlayer = Players.LocalPlayer
	local footprints = Footprints.start({
		points = routePoints,
		root = footprintSpots,
		player = localPlayer,
		feet = function()
			return Footprints.feetOf(localPlayer.Character)
		end,
		ground = Footprints.workspaceGround(Workspace, Players),
		template = footprintTemplate,
		parent = Workspace,
		step = RunService.Heartbeat,
		now = os.clock,
	})
	-- After a bounce off the giant the camera sits low and tilted up, and the trail next to the landing spot would fill
	-- the screen. So the trail hides from the bounce, and fades back in over the same time as the camera's ease, at the
	-- first move after landing.
	local removeTrailListener = cameraWatcher.onTrail(function(change)
		if change == "hide" then
			footprints.hide()
		elseif change == "fadeIn" then
			footprints.fadeIn(Config.Spawn.EaseBackSeconds)
		else
			footprints.show()
		end
	end)
	script.Destroying:Once(removeTrailListener)
else
	warn("The footprint route, the egg spots or the footprint model was not found, so there are no footprints.")
end

-- The hand slams: the red circle, the falling fist and the dust. The fist comes with the place, in the same Assets folder
-- as the footprint (looked up above, so a missing asset never delays the grab prompt). The circle lies on the world's
-- Terrain, his body, the ramps and the bridges (SlamFx.workspaceCastHug). When a circle appears under a player who has
-- just landed from a bounce, the camera starts its ease (cameraWatcher.circleAt). If the fist or the world is missing,
-- the player plays on without slams on screen.
local slamFist = if assets then assets:WaitForChild("SlamFist", NET_WAIT_SECONDS) else nil
if server and slamFist and slamFist:IsA("Model") and footprintWorld then
	local castHug, refreshHug = SlamFx.workspaceCastHug(Workspace, footprintWorld)
	local slams = SlamFx.start({
		playSound = moments.play,
		slamWarning = { OnClientEvent = server.SlamWarning.OnClientEvent },
		slamLanded = { OnClientEvent = server.SlamLanded.OnClientEvent },
		fist = slamFist,
		parent = Workspace,
		surfaceNormal = SlamFx.workspaceSurfaceNormal(Workspace, Players, Workspace),
		castHug = castHug,
		refreshHug = refreshHug,
		onCircle = cameraWatcher.circleAt,
		-- This device's own body, read once per landing: the root's position and the top of the head. No joint is read.
		ownBody = function(): SlamFx.OwnBody?
			local character = Players.LocalPlayer.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			local head = if character then character:FindFirstChild("Head") else nil
			if root == nil or head == nil or not root:IsA("BasePart") or not head:IsA("BasePart") then
				return nil
			end
			return { middle = root.Position, headTopY = head.Position.Y + head.Size.Y / 2 }
		end,
		serverNow = function()
			return Workspace:GetServerTimeNow()
		end,
		step = RunService.RenderStepped,
		burst = function(emitter: ParticleEmitter, count: number)
			emitter:Emit(count)
		end,
	})
	script.Destroying:Once(slams.stop)
elseif server then
	warn("The slam fist or the world was not found, so the hand slams have no circle, fist or dust.")
end

-- The flowers shake: when a hand slam lands, every flower inside its circle tips away and wobbles back in 0.5 s (spec Rule 69).
-- It listens to the same landing as the slams above, needs no asset, and ignores Reduce Motion on purpose (the spec says so).
-- One OverlapParams is reused for every part search; the module keeps only the flowers (Models marked ShakesOnSlam).
if server then
	local flowerParams = OverlapParams.new()
	-- The landing remote, passed on as a plain signal (the module's field doesn't take an engine signal directly).
	local flowerLandedSignal: SpotLabels.SignalLike = {
		Connect = function(_self: any, callback: (...any) -> ())
			local connection = server.SlamLanded.OnClientEvent:Connect(callback)
			return {
				Disconnect = function()
					connection:Disconnect()
				end,
			}
		end,
	}
	local flowerShake = FlowerShake.start({
		slamLanded = { OnClientEvent = flowerLandedSignal },
		step = RunService.RenderStepped,
		now = function()
			return Workspace:GetServerTimeNow()
		end,
		partsNear = function(point: Vector3, radius: number): { BasePart }
			return Workspace:GetPartBoundsInRadius(point, radius, flowerParams)
		end,
	})
	script.Destroying:Once(flowerShake.destroy)
end

-- The music (plan 7 Task 6): the calm tune plays for the session and follows the sleep meter; the chase tune follows the
-- wake. It plays on the sound board above, once this player's character has spawned.
if server then
	-- The Warning remote, passed on as a plain signal (the module's field doesn't take an engine signal directly).
	local musicWarningSignal: Music.SignalLike = {
		Connect = function(_self: any, callback: (...any) -> ())
			local connection = server.Warning.OnClientEvent:Connect(callback)
			return {
				Disconnect = function()
					connection:Disconnect()
				end,
			}
		end,
	}
	local music = Music.start({
		board = soundBoard,
		root = soundRoot,
		step = RunService.RenderStepped,
		giantState = server.GiantState,
		player = Players.LocalPlayer,
		warning = { OnClientEvent = musicWarningSignal },
		serverNow = function()
			return Workspace:GetServerTimeNow()
		end,
		hasCharacter = function()
			return Players.LocalPlayer.Character ~= nil
		end,
	})
	script.Destroying:Once(music.destroy)
end
