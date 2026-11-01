--!strict
-- Wires the client together. The rules live in the modules next to this script.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local CameraFx = require(script.Fx.CameraFx)
local Celebrations = require(script.Fx.Celebrations)
local GiantFx = require(script.Fx.GiantFx)
local SlamFx = require(script.Fx.SlamFx)
local RouteData = require(ReplicatedStorage.Shared.RouteData)
local Recovery = require(script.Player.Recovery)
local RescueFx = require(script.Fx.RescueFx)
local GrabPrompt = require(script.Hud.GrabPrompt)
local Messages = require(script.Hud.Messages)
local Layout = require(script.Hud.Layout)
local SleepMeterUi = require(script.Hud.SleepMeterUi)
local TiptoeButton = require(script.Hud.TiptoeButton)
local BodyBeams = require(script.World.BodyBeams)
local EggFade = require(script.World.EggFade)
local Footprints = require(script.World.Footprints)
local RouteGraph = require(script.World.RouteGraph)
local SpotLabels = require(script.World.SpotLabels)

-- Seconds to wait for the server's remotes and the giant's state before carrying on without them.
local NET_WAIT_SECONDS = 15

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
	-- When he wakes, the screen shakes a little (the camera's point moves by at most 0.5 studs for 0.5 seconds).
	local shaker = CameraFx.shakeOnWake({
		giantState = server.GiantState,
		player = Players.LocalPlayer,
		step = RunService.RenderStepped,
		now = os.clock,
	})
	script.Destroying:Once(function()
		bouncedConnection:Disconnect()
		cameraWatcher.stop()
		shaker.stop()
	end)
	SleepMeterUi.start({
		parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
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
	Messages.start({
		parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
		player = Players.LocalPlayer,
		grabMissed = { OnClientEvent = server.GrabMissed.OnClientEvent },
		eggHome = { OnClientEvent = server.EggHome.OnClientEvent },
		warning = { OnClientEvent = server.Warning.OnClientEvent },
		caught = { OnClientEvent = server.Caught.OnClientEvent },
		giantState = server.GiantState,
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
		Celebrations.start({
			eggHome = { OnClientEvent = server.EggHome.OnClientEvent },
			findEmitter = Celebrations.emitterInWorld(world),
			caught = { OnClientEvent = server.Caught.OnClientEvent },
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
		GiantFx.start({
			world = world,
			warning = { OnClientEvent = server.Warning.OnClientEvent },
			slamWarning = { OnClientEvent = server.SlamWarning.OnClientEvent },
			giantState = server.GiantState,
			step = RunService.RenderStepped,
			now = os.clock,
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
		})
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
		})
		-- The rarity names over waiting eggs and the refill countdowns over empty spots. A rarity name fades while it
		-- overlaps a nearer one, touches the sleep meter or reaches past the top of the screen. The meter's box is read
		-- in the same pixels the world is projected into: the meter's screen reports positions from just below the top
		-- bar, so the bar's height is added back.
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		SpotLabels.start({
			parent = playerGui,
			root = eggSpots,
			now = function()
				return Workspace:GetServerTimeNow()
			end,
			step = RunService.RenderStepped,
			view = SpotLabels.screenView(function()
				return Workspace.CurrentCamera
			end, function(): SpotLabels.Rect?
				local hudTop = playerGui:FindFirstChild("HudTop")
				local meter = if hudTop then hudTop:FindFirstChild("SleepMeter") else nil
				local panel = if meter then meter:FindFirstChild("Panel") else nil
				if panel == nil or not panel:IsA("GuiObject") or panel.AbsoluteSize.X <= 0 then
					return nil
				end
				local inset = GuiService:GetGuiInset()
				return {
					x = panel.AbsolutePosition.X + inset.X,
					y = panel.AbsolutePosition.Y + inset.Y,
					width = panel.AbsoluteSize.X,
					height = panel.AbsoluteSize.Y,
				}
			end),
		})
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
		slamWarning = { OnClientEvent = server.SlamWarning.OnClientEvent },
		slamLanded = { OnClientEvent = server.SlamLanded.OnClientEvent },
		fist = slamFist,
		parent = Workspace,
		surfaceNormal = SlamFx.workspaceSurfaceNormal(Workspace, Players, Workspace),
		castHug = castHug,
		refreshHug = refreshHug,
		onCircle = cameraWatcher.circleAt,
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
