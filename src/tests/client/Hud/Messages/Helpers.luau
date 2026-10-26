--!strict
local StarterPlayer = game:GetService("StarterPlayer")
-- The little house is compared with `==` and checked for true, because Jest's failure messages break on emoji.
local Hud = StarterPlayer.StarterPlayerScripts.Client.Hud
local Messages = require(Hud.Messages)

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

-- A tiny stand-in for a RemoteEvent's OnClientEvent: Connect, Fire and Disconnect, all in plain Luau.
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

type Timer = { seconds: number, callback: () -> (), cancelled: boolean, ran: boolean }

export type Rig = {
	parent: Folder,
	attributes: Folder,
	giantState: Folder,
	grabMissed: any,
	eggHome: any,
	warning: any,
	caught: any,
	me: any,
	timers: { Timer },
	handle: Messages.Handle,
	setCarrying: (value: any) -> (),
	setPhase: (phase: string) -> (),
	setWokenBy: (name: any) -> (),
	-- What the server does on a wake-up: WokenBy first, then Phase.
	wake: (name: string?) -> (),
	setViewport: (size: Vector2) -> (),
	runLastTimer: () -> (),
	hud: () -> ScreenGui,
	pill: () -> Frame,
	pillText: () -> TextLabel,
	pillEgg: () -> Frame,
	pillHome: () -> TextLabel,
	tip: () -> Frame,
	tipText: () -> TextLabel,
	hudTop: () -> ScreenGui?,
	card: () -> Frame?,
	cardText: () -> TextLabel,
	cardEgg: () -> Frame,
	banner: () -> Frame?,
	bannerBody: () -> Frame,
	bannerShadow: () -> Frame,
	bannerEmoji: () -> TextLabel,
	bannerText: () -> TextLabel,
	bannerSecond: () -> TextLabel,
	caughtCard: () -> Frame?,
	caughtBody: () -> Frame,
	caughtShadow: () -> Frame,
	caughtEmoji: () -> TextLabel,
	caughtTitle: () -> TextLabel,
	caughtLine: () -> TextLabel,
}

-- Starts the messages on fake stand-ins for the player's screen, the player, the remote, the screen size and the
-- clock, so a test can drive all of them.
local function newRig(viewport: Vector2?, startPhase: string?): Rig
	local parent = made(Instance.new("Folder"))
	local attributes = made(Instance.new("Folder"))
	local giantState = made(Instance.new("Folder"))
	giantState:SetAttribute("Phase", startPhase or "Asleep")
	local viewportEvent = made(Instance.new("BindableEvent"))
	local viewportSize = viewport or Vector2.new(1280, 720)
	local grabMissed = newSignal()
	local eggHome = newSignal()
	local warning = newSignal()
	local caught = newSignal()
	local timers: { Timer } = {}
	-- This player. EggHome carries the player who banked, and the card is for this one only.
	local me = {
		GetAttribute = function(_self: any, name: string): any
			return attributes:GetAttribute(name)
		end,
		GetAttributeChangedSignal = function(_self: any, name: string): RBXScriptSignal
			return attributes:GetAttributeChangedSignal(name)
		end,
	}

	local handle = Messages.start({
		parent = parent,
		player = me,
		grabMissed = { OnClientEvent = grabMissed },
		eggHome = { OnClientEvent = eggHome },
		warning = { OnClientEvent = warning },
		caught = { OnClientEvent = caught },
		giantState = giantState,
		viewport = {
			get = function()
				return viewportSize
			end,
			connect = function(callback: () -> ())
				local connection = viewportEvent.Event:Connect(callback)
				return function()
					connection:Disconnect()
				end
			end,
		},
		-- A fake clock: nothing runs until the test says so.
		after = function(seconds: number, callback: () -> ())
			local timer: Timer = { seconds = seconds, callback = callback, cancelled = false, ran = false }
			table.insert(timers, timer)
			return function()
				timer.cancelled = true
			end
		end,
	})
	table.insert(stops, handle.stop)

	local function find<T>(name: string): T
		local hud = parent:FindFirstChild("Hud") :: Instance
		return hud:FindFirstChild(name, true) :: any
	end
	-- Finds a piece of the banner anywhere on the player's screens (it moves from one to the other).
	local function findBanner(name: string): any
		return parent:FindFirstChild(name, true)
	end
	return {
		parent = parent,
		attributes = attributes,
		giantState = giantState,
		grabMissed = grabMissed,
		eggHome = eggHome,
		warning = warning,
		caught = caught,
		me = me,
		timers = timers,
		handle = handle,
		setCarrying = function(value: any)
			attributes:SetAttribute("Carrying", value)
			task.wait()
		end,
		setPhase = function(phase: string)
			giantState:SetAttribute("Phase", phase)
			task.wait()
		end,
		setWokenBy = function(name: any)
			giantState:SetAttribute("WokenBy", name)
			task.wait()
		end,
		wake = function(name: string?)
			giantState:SetAttribute("WokenBy", name or "")
			giantState:SetAttribute("Phase", "Awake")
			task.wait()
		end,
		setViewport = function(size: Vector2)
			viewportSize = size
			viewportEvent:Fire()
			task.wait()
		end,
		runLastTimer = function()
			local timer = timers[#timers]
			if timer and not timer.cancelled then
				timer.ran = true
				timer.callback()
			end
		end,
		hud = function()
			return parent:FindFirstChild("Hud") :: ScreenGui
		end,
		pill = function()
			return find("CarryPill")
		end,
		pillText = function()
			return find("CarryText")
		end,
		pillEgg = function()
			return find("CarryEgg")
		end,
		pillHome = function()
			return find("CarryHome")
		end,
		tip = function()
			return find("Tip")
		end,
		tipText = function()
			return find("TipText")
		end,
		hudTop = function()
			return parent:FindFirstChild("HudTop") :: ScreenGui?
		end,
		card = function()
			local top = parent:FindFirstChild("HudTop")
			return if top then top:FindFirstChild("SafeCard", true) :: Frame? else nil
		end,
		cardText = function()
			return (parent:FindFirstChild("HudTop") :: Instance):FindFirstChild("SafeCardText", true) :: TextLabel
		end,
		cardEgg = function()
			return (parent:FindFirstChild("HudTop") :: Instance):FindFirstChild("SafeCardEgg", true) :: Frame
		end,
		banner = function()
			return findBanner("WakeBanner")
		end,
		bannerBody = function()
			return findBanner("WakeBannerBody")
		end,
		bannerShadow = function()
			return findBanner("WakeBannerShadow")
		end,
		bannerEmoji = function()
			return findBanner("WakeBannerEmoji")
		end,
		bannerText = function()
			return findBanner("WakeBannerText")
		end,
		bannerSecond = function()
			return findBanner("WakeBannerSecond")
		end,
		caughtCard = function()
			return findBanner("CaughtCard")
		end,
		caughtBody = function()
			return findBanner("CaughtCardBody")
		end,
		caughtShadow = function()
			return findBanner("CaughtCardShadow")
		end,
		caughtEmoji = function()
			return findBanner("CaughtCardEmoji")
		end,
		caughtTitle = function()
			return findBanner("CaughtCardTitle")
		end,
		caughtLine = function()
			return findBanner("CaughtCardLine")
		end,
	}
end

return {
	cleanUp = cleanUp,
	made = made,
	newRig = newRig,
	newSignal = newSignal,
	stops = stops,
}
