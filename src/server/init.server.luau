--!strict
-- Wires the server together. The rules live in the modules next to this script.

local PhysicsService = game:GetService("PhysicsService")
local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Analytics = require(script.Analytics)
local Banking = require(script.Eggs.Banking)
local Carry = require(script.Eggs.Carry)
local Grab = require(script.Eggs.Grab)
local HomeDisplay = require(script.Eggs.HomeDisplay)
local Catcher = require(script.Giant.Catcher)
local GiantDirector = require(script.Giant.GiantDirector)
local SlamSurface = require(script.Giant.SlamSurface)
local Collisions = require(script.Players.Collisions)
local Floater = require(script.Players.Floater)
local JumpWatcher = require(script.Players.JumpWatcher)
local PlayerInfo = require(script.Players.PlayerInfo)
local PlayerTracker = require(script.Players.PlayerTracker)
local Spawning = require(script.Players.Spawning)
local TiptoeHandler = require(script.Remotes.TiptoeHandler)
local WorldIndex = require(script.World.WorldIndex)

-- The most ticks one frame may run when the server has fallen behind. The rest are dropped.
local MAX_TICKS_PER_FRAME = 3

-- The world lives in the place file, not in git. If it is not there, stop with a clear message
-- instead of waiting for it forever.
local world = Workspace:FindFirstChild("World")
if world == nil then
	error("Workspace.World is missing: the place file doesn't match the code")
end

-- If the world does not match what the code needs, this stops the server with a clear message.
local gardens = WorldIndex.loadGardens(world)
local zoneBoxes = WorldIndex.loadZones(world)

-- The egg spots and the egg models are part of the world contract too.
local eggSpots = WorldIndex.loadEggSpots(world)
-- And the meadow spots where bounced players land when he wakes.
local landingSpots = WorldIndex.loadLandingSpots(world)
-- And the point on his face that bounced players turn to look at.
local facePoint = WorldIndex.loadGiantFace(world)
-- So is the footprint route (each client draws its own footprints from it). The server uses its meadow points as the
-- places where he slams when no one carries an egg; a place without a good route stops here with every problem listed.
local meadowPoints: { Vector3 } = {}
for _, point in WorldIndex.loadRoute(world) do
	if string.match(point.name, "^RoutePoint_Meadow_%d+$") then
		table.insert(meadowPoints, point.position)
	end
end
-- Where each garden is, as boxes: the sleep meter and the slams both need them.
local gardenBoxes = PlayerTracker.gardenBoxes(gardens)
local assets = ServerStorage:FindFirstChild("Assets")
if assets == nil then
	error("ServerStorage.Assets is missing: the place file doesn't match the code")
end
local eggTemplates = WorldIndex.loadEggTemplates(assets)
local carriedEggOffset, carriedEggHeight = Carry.readCarriedEggLook(assets)

-- The remotes and GiantState, which clients wait for.
local net = Net.setup(ReplicatedStorage)

Collisions.start(Players, PhysicsService)
Spawning.start(gardens, Players)

-- Tiptoe: the one thing a client may ask for. The server checks it and sets the player's own Tiptoe attribute,
-- and keeps every Humanoid's walking speed in line with it.
TiptoeHandler.start({
	remote = { OnServerEvent = net.SetTiptoe.OnServerEvent },
	players = Players,
	now = os.clock,
})
Carry.watchSpeed(Players)

-- Grabbing eggs: a hold prompt on every egg spot. Grab owns the state of all the egg spots and the refills.
local grab = Grab.start({
	spots = eggSpots,
	templates = eggTemplates,
	carriedOffset = carriedEggOffset,
	carriedHeight = carriedEggHeight,
	players = Players,
	heartbeat = RunService.Heartbeat,
	grabMissed = function(player)
		net.GrabMissed:FireClient(player :: any)
	end,
	now = function()
		return Workspace:GetServerTimeNow()
	end,
})

-- Bringing eggs home: banks a carrier who stands in their own garden, and sends a carried egg back to its spot
-- when its carrier dies, loses their character or leaves. It banks on the giant's tick, below.
local banking = Banking.start({ grab = grab, players = Players })

-- Eggs at home: a quiet copy of each banked egg on the garden's next home spot, the gold "eggs waiting" tag over the
-- incubator, and EggHome to everyone (Task 22 draws the celebration there).
HomeDisplay.start({
	gardens = gardens,
	templates = eggTemplates,
	banked = banking.banked,
	players = Players,
	fireEggHome = function(player, rarity, position)
		net.EggHome:FireAllClients(player, rarity, position)
	end,
})

-- When he wakes, everyone on him is turned to face him, moved above a landing spot and lowered onto it. It lets go on
-- the giant's tick, below.
local floater = Floater.start({ players = Players, facePoint = facePoint, now = os.clock })

-- Jumps: each character's Humanoid tells the server when it jumps, because a jump up the steep belly path is in the air
-- for too short a time for the ground check to see, and a held Jump hops again within 0.3 s. The server notes where
-- each jump took off. It runs for the whole life of the server, so nothing stops it.
local jumpWatcher = JumpWatcher.start({
	players = Players,
	stateChanged = JumpWatcher.humanoidStateChanged,
	rootPosition = JumpWatcher.rootPositionOf,
})

-- The giant's sleep meter: it reads every player's position ten times a second.
local tracker = PlayerTracker.new({
	getPlayers = function()
		return Players:GetPlayers()
	end,
	zoneBoxes = zoneBoxes,
	gardens = gardenBoxes,
	isGrounded = PlayerTracker.groundedByRay,
	takeoffs = function(character: Model)
		return jumpWatcher:took(character)
	end,
	now = os.clock,
})

-- A caught carrier's egg goes back, and they are put on their own spawn spot facing him.
local catcher = Catcher.new({
	players = Players,
	grab = grab,
	gardens = gardens,
	facePoint = facePoint,
	fireCaught = function(player)
		net.Caught:FireAllClients(player)
	end,
})
-- The analytics events (spec section 10). It is made after the director below, because it listens to his `woke` signal;
-- the director's tick passes it every player's place, so it waits here until then.
local analytics: Analytics.Analytics? = nil
-- Picks which empty-meadow point a slam goes to.
local slamRandom = Random.new()
local director = GiantDirector.new({
	tick = function()
		local samples = tracker:tick()
		banking:check(samples)
		if analytics ~= nil then
			analytics:check(samples)
		end
		floater:step()
		return samples
	end,
	players = function()
		local infos: { PlayerInfo.Info } = {}
		for _, player in Players:GetPlayers() do
			table.insert(infos, PlayerInfo.fromPlayer(player))
		end
		return infos
	end,
	state = net.GiantState,
	fireWarning = function(mark: number)
		net.Warning:FireAllClients(mark)
	end,
	now = function()
		return Workspace:GetServerTimeNow()
	end,
	landingSpots = landingSpots,
	bounce = function(userId: number, spot: WorldIndex.LandingSpot)
		local player = Players:GetPlayerByUserId(userId)
		if player ~= nil then
			-- The player's device is told which way they now face, so the camera can snap behind them.
			local look = floater:float(player, spot)
			if look ~= nil then
				net.Bounced:FireClient(player, look)
			end
		end
	end,
	gardens = gardenBoxes,
	meadowPoints = meadowPoints,
	face = facePoint,
	floating = function(userId: number)
		return floater:isFloating(userId)
	end,
	landedAgo = function(userId: number)
		return floater:landedAgo(userId)
	end,
	pick = function(count: number)
		return slamRandom:NextInteger(1, count)
	end,
	surfaceBelow = function(centre: Vector3)
		-- The ray ignores every player's character: a player's own body is not the ground.
		local characters: { Instance } = {}
		for _, player in Players:GetPlayers() do
			if player.Character ~= nil then
				table.insert(characters, player.Character)
			end
		end
		return SlamSurface.below(Workspace, centre, characters)
	end,
	fireSlamWarning = function(slam: number, point: Vector3, landsAt: number)
		net.SlamWarning:FireAllClients(slam, point, landsAt)
	end,
	fireSlamLanded = function(slam: number, point: Vector3)
		net.SlamLanded:FireAllClients(slam, point)
	end,
	catch = function(userId: number)
		catcher:catch(userId)
	end,
})

-- Analytics: listens to grabs, banked eggs, catches, wake-ups and slams, and to the ticks above. In Studio, Roblox prints a line
-- for each event and sends nothing; a published game's server sends them to the Creator Dashboard.
local gardenSpots: { Analytics.GardenSpot } = {}
for _, garden in gardens do
	table.insert(gardenSpots, { index = garden.index, spawnPosition = garden.spawnSpot.Position })
end
analytics = Analytics.start({
	service = AnalyticsService,
	players = Players,
	grabbed = grab.grabbed,
	banked = banking.banked,
	caught = catcher.caught,
	woke = director.woke,
	slammed = director.slammed,
	gardens = gardenSpots,
	now = os.clock,
	newId = function()
		return HttpService:GenerateGUID(false)
	end,
})

GiantDirector.run(director, RunService.Heartbeat, Config.Tick.Seconds, MAX_TICKS_PER_FRAME)
