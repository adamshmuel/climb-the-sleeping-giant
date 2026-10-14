--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

-- The little house is compared with `==` and checked for true, because Jest's failure messages break on emoji.
local Hud = StarterPlayer.StarterPlayerScripts.Client.Hud
local Messages = require(Hud.Messages)
local Theme = require(Hud.Theme)

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

type Rig = {
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

describe("Messages.carryText", function()
	it("says Rare egg! Get it home for a Rare egg", function()
		expect(Messages.carryText("Rare")).toBe("Rare egg! Get it home")
	end)

	it("says Common egg! Get it home for a Common egg", function()
		expect(Messages.carryText("Common")).toBe("Common egg! Get it home")
	end)

	it("says Uncommon egg! Get it home for an Uncommon egg", function()
		expect(Messages.carryText("Uncommon")).toBe("Uncommon egg! Get it home")
	end)
end)

describe("Messages.safeText", function()
	it("says Safe! Common egg is home for a Common egg", function()
		expect(Messages.safeText("Common")).toBe("Safe! Common egg is home")
	end)

	it("says Safe! Uncommon egg is home for an Uncommon egg", function()
		expect(Messages.safeText("Uncommon")).toBe("Safe! Uncommon egg is home")
	end)

	it("says Safe! Rare egg is home for a Rare egg", function()
		expect(Messages.safeText("Rare")).toBe("Safe! Rare egg is home")
	end)
end)

describe("Messages: the footprints tip's words", function()
	it("says 👣 Follow the glowing footprints!", function()
		-- Compared with `==`, because Jest's failure messages break on emoji.
		expect(Messages.footprintsText == "👣 Follow the glowing footprints!").toBe(true)
	end)
end)

describe("Messages: the missed tip's words", function()
	it("says Someone else got it!", function()
		expect(Messages.missedText).toBe("Someone else got it!")
	end)

	it("lasts 2 seconds", function()
		expect(Messages.missedSeconds).toBe(2)
	end)
end)

describe("Messages: the carry pill", function()
	it("is not there at the start", function()
		local rig = newRig()
		expect(rig.pill().Visible).toBe(false)
	end)

	it("shows while Carrying is set, with the words for that rarity", function()
		local rig = newRig()
		rig.setCarrying("Rare")
		expect(rig.pill().Visible).toBe(true)
		expect(rig.pillText().Text).toBe("Rare egg! Get it home")
		expect(rig.pillHome().Text == "🏡").toBe(true)
	end)

	it("hides when Carrying is cleared", function()
		local rig = newRig()
		rig.setCarrying("Rare")
		rig.setCarrying(nil)
		expect(rig.pill().Visible).toBe(false)
	end)

	it("shows if the player is already carrying when it starts", function()
		local parent = made(Instance.new("Folder"))
		local attributes = made(Instance.new("Folder"))
		attributes:SetAttribute("Carrying", "Common")
		local handle = Messages.start({
			parent = parent,
			player = {
				GetAttribute = function(_self: any, name: string): any
					return attributes:GetAttribute(name)
				end,
				GetAttributeChangedSignal = function(_self: any, name: string): RBXScriptSignal
					return attributes:GetAttributeChangedSignal(name)
				end,
			},
			grabMissed = { OnClientEvent = newSignal() },
			eggHome = { OnClientEvent = newSignal() },
			warning = { OnClientEvent = newSignal() },
			caught = { OnClientEvent = newSignal() },
			giantState = made(Instance.new("Folder")),
			viewport = {
				get = function()
					return Vector2.new(1280, 720)
				end,
				connect = function(_callback: () -> ())
					return function() end
				end,
			},
		})
		table.insert(stops, handle.stop)
		local pill = (parent:FindFirstChild("Hud") :: Instance):FindFirstChild("CarryPill", true) :: Frame
		expect(pill.Visible).toBe(true)
	end)

	it("follows a change of rarity", function()
		local rig = newRig()
		rig.setCarrying("Common")
		rig.setCarrying("Uncommon")
		expect(rig.pillText().Text).toBe("Uncommon egg! Get it home")
	end)

	it("paints the egg in the rarity's colour", function()
		local rig = newRig()
		for rarity, look in Theme.rarity do
			rig.setCarrying(rarity)
			local gradient = rig.pillEgg():FindFirstChildOfClass("UIGradient") :: UIGradient
			expect(gradient.Color.Keypoints[1].Value == look.light).toBe(true)
			expect(gradient.Color.Keypoints[2].Value == look.main).toBe(true)
			expect(gradient.Color.Keypoints[3].Value == look.dark).toBe(true)
		end
	end)

	it("shows nothing for a value that is not a known rarity", function()
		local rig = newRig()
		rig.setCarrying("Mystery")
		expect(rig.pill().Visible).toBe(false)
		rig.setCarrying(42)
		expect(rig.pill().Visible).toBe(false)
	end)

	it("sits at the bottom centre of the Hud, 18 px up on a computer", function()
		local rig = newRig()
		local pill = rig.pill()
		expect(pill.AnchorPoint).toBe(Vector2.new(0.5, 1))
		expect(pill.Position).toBe(UDim2.new(0.5, 0, 1, -18))
	end)

	it("lives on the Hud screen, which keeps clear of Roblox's own buttons", function()
		local rig = newRig()
		expect(rig.hud().ScreenInsets).toBe(Enum.ScreenInsets.CoreUISafeInsets)
		expect(rig.pill():IsDescendantOf(rig.hud())).toBe(true)
	end)

	it("uses 22 px text and a 40x50 egg on a 1280x720 computer screen", function()
		local rig = newRig(Vector2.new(1280, 720))
		expect(rig.pillText().TextSize).toBe(22)
		expect(rig.pillEgg().Size).toBe(UDim2.fromOffset(40, 50))
	end)

	it("uses 14 px text and a 24x30 egg on an 844x390 phone screen", function()
		local rig = newRig(Vector2.new(844, 390))
		expect(rig.pillText().TextSize).toBe(14)
		expect(rig.pillEgg().Size).toBe(UDim2.fromOffset(24, 30))
		expect(rig.pillHome().TextSize >= 14).toBe(true)
		expect(rig.pill().Position).toBe(UDim2.new(0.5, 0, 1, -12))
	end)

	it("changes size when the screen changes from a computer to a phone", function()
		local rig = newRig(Vector2.new(1280, 720))
		rig.setViewport(Vector2.new(844, 390))
		expect(rig.pillText().TextSize).toBe(14)
	end)

	it("never uses text under 14 px", function()
		local rig = newRig(Vector2.new(844, 390))
		expect(rig.pillText().TextSize >= 14).toBe(true)
		expect(rig.tipText().TextSize >= 14).toBe(true)
	end)
end)

describe("Messages: the Follow the glowing footprints! tip", function()
	it("shows at the start, in the tip's place", function()
		local rig = newRig()
		expect(rig.tip().Visible).toBe(true)
		expect(rig.tipText().Text == Messages.footprintsText).toBe(true)
		expect(rig.tip().Position).toBe(UDim2.new(0.5, 0, 1, -18))
	end)

	it("keeps showing while the player walks, with no timer running", function()
		local rig = newRig()
		expect(#rig.timers).toBe(0)
		expect(rig.tip().Visible).toBe(true)
	end)

	it("uses 24 px text on a computer and at least 14 px on a phone", function()
		expect(newRig(Vector2.new(1280, 720)).tipText().TextSize).toBe(24)
		expect(newRig(Vector2.new(844, 390)).tipText().TextSize >= 14).toBe(true)
	end)

	it("hides at the first grab, and the carry pill takes its place", function()
		local rig = newRig()
		rig.setCarrying("Common")
		expect(rig.tip().Visible).toBe(false)
		expect(rig.pill().Visible).toBe(true)
	end)

	it("never comes back after the first grab, not even once the egg is home or after a respawn", function()
		local rig = newRig()
		rig.setCarrying("Common")
		rig.setCarrying(nil)
		expect(rig.tip().Visible).toBe(false)
		-- A second egg, then none again.
		rig.setCarrying("Rare")
		rig.setCarrying(nil)
		expect(rig.tip().Visible).toBe(false)
	end)

	it("is not shown to a player who is carrying an egg when it starts", function()
		local parent = made(Instance.new("Folder"))
		local attributes = made(Instance.new("Folder"))
		attributes:SetAttribute("Carrying", "Common")
		local handle = Messages.start({
			parent = parent,
			player = {
				GetAttribute = function(_self: any, name: string): any
					return attributes:GetAttribute(name)
				end,
				GetAttributeChangedSignal = function(_self: any, name: string): RBXScriptSignal
					return attributes:GetAttributeChangedSignal(name)
				end,
			},
			grabMissed = { OnClientEvent = newSignal() },
			eggHome = { OnClientEvent = newSignal() },
			warning = { OnClientEvent = newSignal() },
			caught = { OnClientEvent = newSignal() },
			giantState = made(Instance.new("Folder")),
			viewport = {
				get = function()
					return Vector2.new(1280, 720)
				end,
				connect = function(_callback: () -> ())
					return function() end
				end,
			},
		})
		table.insert(stops, handle.stop)
		attributes:SetAttribute("Carrying", nil)
		task.wait()
		local tip = (parent:FindFirstChild("Hud") :: Instance):FindFirstChild("Tip", true) :: Frame
		expect(tip.Visible).toBe(false)
	end)

	it("gives way to the missed tip before the first grab, then comes back after 2 seconds", function()
		local rig = newRig()
		rig.grabMissed:Fire()
		expect(rig.tip().Visible).toBe(true)
		expect(rig.tipText().Text).toBe("Someone else got it!")
		expect(rig.timers[1].seconds).toBe(2)
		rig.runLastTimer()
		expect(rig.tip().Visible).toBe(true)
		expect(rig.tipText().Text == Messages.footprintsText).toBe(true)
	end)

	it("does not come back after a miss once the player has grabbed", function()
		local rig = newRig()
		rig.setCarrying("Common")
		rig.setCarrying(nil)
		rig.grabMissed:Fire()
		rig.runLastTimer()
		expect(rig.tip().Visible).toBe(false)
	end)

	it("does not come back after a miss when the player grabs during the 2 seconds", function()
		local rig = newRig()
		rig.grabMissed:Fire()
		rig.setCarrying("Common")
		rig.setCarrying(nil)
		expect(rig.tip().Visible).toBe(false)
		rig.runLastTimer() -- the cancelled timer does nothing
		expect(rig.tip().Visible).toBe(false)
	end)
end)

describe("Messages: the Someone else got it! tip", function()
	-- Most of these start after the player's first grab, when the footprints tip is gone for good.
	local function newRigAfterFirstGrab(viewport: Vector2?): Rig
		local rig = newRig(viewport)
		rig.setCarrying("Common")
		rig.setCarrying(nil)
		return rig
	end

	it("is not there after the first grab until a grab is missed", function()
		local rig = newRigAfterFirstGrab()
		expect(rig.tip().Visible).toBe(false)
	end)

	it("shows with its words when the server says the grab was missed", function()
		local rig = newRig()
		rig.grabMissed:Fire()
		expect(rig.tip().Visible).toBe(true)
		expect(rig.tipText().Text).toBe("Someone else got it!")
	end)

	it("hides after 2 seconds", function()
		local rig = newRigAfterFirstGrab()
		rig.grabMissed:Fire()
		expect(#rig.timers).toBe(1)
		expect(rig.timers[1].seconds).toBe(2)
		expect(rig.tip().Visible).toBe(true)
		rig.runLastTimer()
		expect(rig.tip().Visible).toBe(false)
	end)

	it("starts the 2 seconds again when it is missed again", function()
		local rig = newRigAfterFirstGrab()
		rig.grabMissed:Fire()
		rig.grabMissed:Fire()
		expect(#rig.timers).toBe(2)
		expect(rig.timers[1].cancelled).toBe(true)
		expect(rig.timers[2].cancelled).toBe(false)
		expect(rig.tip().Visible).toBe(true)
	end)

	it("sits in the carry pill's place at the bottom centre, 18 px up on a computer", function()
		local rig = newRig()
		local tip = rig.tip()
		expect(tip.AnchorPoint).toBe(Vector2.new(0.5, 1))
		expect(tip.Position).toBe(UDim2.new(0.5, 0, 1, -18))
		expect(tip.Position).toBe(rig.pill().Position)
	end)

	it("uses 24 px text on a computer", function()
		local rig = newRig(Vector2.new(1280, 720))
		expect(rig.tipText().TextSize).toBe(24)
	end)

	it("is not shown while the player carries an egg: the carry pill wins", function()
		local rig = newRig()
		rig.setCarrying("Common")
		rig.grabMissed:Fire()
		expect(rig.tip().Visible).toBe(false)
		expect(rig.pill().Visible).toBe(true)
		expect(#rig.timers).toBe(0)
	end)

	it("hides when the player starts carrying, and its timer is cancelled", function()
		local rig = newRig()
		rig.grabMissed:Fire()
		rig.setCarrying("Common")
		expect(rig.tip().Visible).toBe(false)
		expect(rig.timers[1].cancelled).toBe(true)
		expect(rig.pill().Visible).toBe(true)
	end)
end)

describe("Messages: the Stand still or tiptoe! tip", function()
	it("says 🤫 Stand still or tiptoe! and lasts 3 seconds", function()
		-- Compared with `==`, because Jest's failure messages break on emoji.
		expect(Messages.standStillText == "🤫 Stand still or tiptoe!").toBe(true)
		expect(Messages.standStillSeconds).toBe(3)
	end)

	it("shows for 3 seconds at the 85 warning: there at 2.9 s, gone at 3 s", function()
		local rig = newRig()
		rig.setCarrying("Common") -- the footprints tip is over after the first grab
		rig.setCarrying(nil)
		rig.warning:Fire(85)
		expect(rig.tip().Visible).toBe(true)
		expect(rig.tipText().Text == Messages.standStillText).toBe(true)
		local timer = rig.timers[#rig.timers]
		expect(timer.seconds).toBe(3) -- the tip lasts exactly as long as this timer, so it is there before it runs
		expect(timer.ran).toBe(false)
		expect(rig.tip().Visible).toBe(true)
		rig.runLastTimer()
		expect(rig.tip().Visible).toBe(false)
	end)

	it("also shows while carrying an egg, in the carry pill's place, and the pill comes back after", function()
		local rig = newRig()
		rig.setCarrying("Rare")
		expect(rig.pill().Visible).toBe(true)
		rig.warning:Fire(85)
		expect(rig.tip().Visible).toBe(true)
		expect(rig.tipText().Text == Messages.standStillText).toBe(true)
		expect(rig.pill().Visible).toBe(false)
		rig.runLastTimer()
		expect(rig.tip().Visible).toBe(false)
		expect(rig.pill().Visible).toBe(true)
		expect(rig.pillText().Text).toBe("Rare egg! Get it home")
	end)

	it("wins over the missed-grab tip, which comes back for what is left of its 2 seconds", function()
		local rig = newRig()
		rig.grabMissed:Fire()
		rig.warning:Fire(85)
		expect(rig.tipText().Text == Messages.standStillText).toBe(true)
		rig.runLastTimer() -- the 3 seconds are over
		expect(rig.tipText().Text).toBe(Messages.missedText)
	end)

	it("wins over the footprints tip, which comes back after it before the first grab", function()
		local rig = newRig()
		expect(rig.tipText().Text == Messages.footprintsText).toBe(true)
		rig.warning:Fire(85)
		expect(rig.tipText().Text == Messages.standStillText).toBe(true)
		rig.runLastTimer()
		expect(rig.tipText().Text == Messages.footprintsText).toBe(true)
	end)

	it("shows nothing for a 60", function()
		local rig = newRig()
		rig.setCarrying("Common")
		rig.setCarrying(nil)
		rig.warning:Fire(60)
		expect(rig.tip().Visible).toBe(false)
		expect(#rig.timers).toBe(0)
	end)

	it("starts the 3 seconds again when a second 85 comes while it shows", function()
		local rig = newRig()
		rig.warning:Fire(85)
		local first = rig.timers[#rig.timers]
		rig.warning:Fire(85)
		expect(first.cancelled).toBe(true)
		local second = rig.timers[#rig.timers]
		expect(second).never.toBe(first)
		expect(second.seconds).toBe(3)
		expect(rig.tipText().Text == Messages.standStillText).toBe(true)
	end)

	it("is taken away, and its timer cancelled, when the messages are stopped", function()
		local rig = newRig()
		rig.warning:Fire(85)
		local timer = rig.timers[#rig.timers]
		rig.handle.stop()
		expect(timer.cancelled).toBe(true)
		expect(rig.warning:count()).toBe(0)
	end)
end)

describe("Messages: the green safe-home card", function()
	it("is not there at the start", function()
		local rig = newRig()
		expect((rig.card() :: Frame).Visible).toBe(false)
	end)

	it("shows with the words for the rarity when this player's egg comes home", function()
		local rig = newRig()
		rig.eggHome:Fire(rig.me, "Common", Vector3.zero)
		expect((rig.card() :: Frame).Visible).toBe(true)
		expect(rig.cardText().Text).toBe("Safe! Common egg is home")
	end)

	it("paints its egg in the rarity's colours", function()
		local rig = newRig()
		for rarity, look in Theme.rarity do
			rig.eggHome:Fire(rig.me, rarity, Vector3.zero)
			local gradient = rig.cardEgg():FindFirstChildOfClass("UIGradient") :: UIGradient
			expect(gradient.Color.Keypoints[1].Value == look.light).toBe(true)
			expect(gradient.Color.Keypoints[2].Value == look.main).toBe(true)
			expect(gradient.Color.Keypoints[3].Value == look.dark).toBe(true)
		end
	end)

	it("hides after 3 seconds", function()
		local rig = newRig()
		rig.eggHome:Fire(rig.me, "Common", Vector3.zero)
		expect(#rig.timers).toBe(1)
		expect(rig.timers[1].seconds).toBe(3)
		expect((rig.card() :: Frame).Visible).toBe(true)
		rig.runLastTimer()
		expect((rig.card() :: Frame).Visible).toBe(false)
	end)

	it("shows nothing when another player's egg comes home", function()
		local rig = newRig()
		rig.eggHome:Fire({}, "Common", Vector3.zero)
		expect((rig.card() :: Frame).Visible).toBe(false)
		expect(#rig.timers).toBe(0)
	end)

	it("replaces the words and starts the 3 seconds again when a second egg comes home", function()
		local rig = newRig()
		rig.eggHome:Fire(rig.me, "Common", Vector3.zero)
		rig.eggHome:Fire(rig.me, "Rare", Vector3.zero)
		expect(#rig.timers).toBe(2)
		expect(rig.timers[1].cancelled).toBe(true)
		expect(rig.timers[2].cancelled).toBe(false)
		expect(rig.timers[2].seconds).toBe(3)
		expect((rig.card() :: Frame).Visible).toBe(true)
		expect(rig.cardText().Text).toBe("Safe! Rare egg is home")
	end)

	it("ignores a rarity it does not know", function()
		local rig = newRig()
		rig.eggHome:Fire(rig.me, "Mystery", Vector3.zero)
		expect((rig.card() :: Frame).Visible).toBe(false)
		expect(#rig.timers).toBe(0)
	end)

	it("lives on the HudTop screen, so it lines up under the meter", function()
		local rig = newRig()
		local hudTop = rig.hudTop() :: ScreenGui
		expect(hudTop.ScreenInsets).toBe(Enum.ScreenInsets.DeviceSafeInsets)
		expect((rig.card() :: Frame):IsDescendantOf(hudTop)).toBe(true)
	end)

	it("sits at the top centre, 96 px down on a computer and 62 px down on a phone", function()
		local rig = newRig(Vector2.new(1280, 720))
		local card = rig.card() :: Frame
		expect(card.AnchorPoint).toBe(Vector2.new(0.5, 0))
		expect(card.Position.X).toBe(UDim.new(0.5, 0))
		-- the outline is drawn outside the card, so the card starts one outline's thickness lower
		expect(card.Position.Y).toBe(UDim.new(0, 96 + 4))
		rig.setViewport(Vector2.new(844, 390))
		expect(card.Position.Y).toBe(UDim.new(0, 62 + 3))
	end)

	it("has 24 px words on a computer and 14 px on a phone", function()
		local rig = newRig(Vector2.new(1280, 720))
		expect(rig.cardText().TextSize).toBe(24)
		expect(rig.cardEgg().Size.Y.Offset).toBe(40)
		rig.setViewport(Vector2.new(844, 390))
		expect(rig.cardText().TextSize).toBe(14)
		expect(rig.cardEgg().Size.Y.Offset).toBe(26)
	end)

	it("is painted green from top to bottom, with the three greens of the mockup", function()
		local rig = newRig()
		local body = (rig.card() :: Frame):FindFirstChild("SafeCardBody") :: Frame
		local gradient = body:FindFirstChildOfClass("UIGradient") :: UIGradient
		expect(gradient.Rotation).toBe(90)
		expect(gradient.Color.Keypoints[1].Value == Color3.fromHex("A6F29A")).toBe(true)
		expect(gradient.Color.Keypoints[2].Value == Color3.fromHex("5BD45B")).toBe(true)
		expect(math.abs(gradient.Color.Keypoints[2].Time - 0.55) < 0.001).toBe(true)
		expect(gradient.Color.Keypoints[3].Value == Color3.fromHex("2E9E3A")).toBe(true)
	end)

	it("is taken off and stops listening when stopped, and its timer is cancelled", function()
		local rig = newRig()
		rig.eggHome:Fire(rig.me, "Common", Vector3.zero)
		rig.handle.stop()
		expect(rig.card()).toBeNil()
		expect(rig.eggHome:count()).toBe(0)
		expect(rig.timers[1].cancelled).toBe(true)
	end)
end)

describe("Messages.start", function()
	it("takes everything off the screen and stops listening when it is stopped", function()
		local rig = newRig()
		rig.grabMissed:Fire()
		rig.handle.stop()
		expect(rig.hud():FindFirstChild("CarryPill", true)).toBeNil()
		expect(rig.hud():FindFirstChild("Tip", true)).toBeNil()
		expect(rig.grabMissed:count()).toBe(0)
		expect(rig.timers[1].cancelled).toBe(true)
	end)

	it("makes no second pill when started again on the same screen", function()
		local rig = newRig()
		local again = Messages.start({
			parent = rig.parent,
			player = {
				GetAttribute = function(_self: any, name: string): any
					return rig.attributes:GetAttribute(name)
				end,
				GetAttributeChangedSignal = function(_self: any, name: string): RBXScriptSignal
					return rig.attributes:GetAttributeChangedSignal(name)
				end,
			},
			grabMissed = { OnClientEvent = newSignal() },
			eggHome = { OnClientEvent = newSignal() },
			warning = { OnClientEvent = newSignal() },
			caught = { OnClientEvent = newSignal() },
			giantState = made(Instance.new("Folder")),
			viewport = {
				get = function()
					return Vector2.new(1280, 720)
				end,
				connect = function(_callback: () -> ())
					return function() end
				end,
			},
		})
		table.insert(stops, again.stop)
		local count = 0
		for _, child in rig.hud():GetDescendants() do
			if child.Name == "CarryPill" then
				count += 1
			end
		end
		expect(count).toBe(1)
	end)
end)

describe("Messages: the wake banner's words", function()
	it("says '[Name] woke the Giant!'", function()
		expect(Messages.wokeText("Leo")).toBe("Leo woke the Giant!")
		expect(Messages.wokeText("sushi_salmon")).toBe("sushi_salmon woke the Giant!")
	end)

	it("says 'The Giant woke up!' when nobody can be named", function()
		expect(Messages.wokeText("")).toBe("The Giant woke up!")
		expect(Messages.wokeText(nil :: any)).toBe("The Giant woke up!")
		expect(Messages.wokeText(5 :: any)).toBe("The Giant woke up!")
	end)

	it("has the second line 'Run home with your egg!' and the carrier's words 'Dodge the red circles!'", function()
		expect(Messages.runHomeText).toBe("Run home with your egg!")
		expect(Messages.dodgeText).toBe("Dodge the red circles!")
	end)
end)

describe("Messages: the wake banner", function()
	it("is not there at the start", function()
		local rig = newRig()
		expect((rig.banner() :: Frame).Visible).toBe(false)
	end)

	it("shows with 'Leo woke the Giant!' and the second line on a computer when Phase turns Awake", function()
		local rig = newRig(Vector2.new(1280, 720))
		rig.wake("Leo")
		expect((rig.banner() :: Frame).Visible).toBe(true)
		expect(rig.bannerText().Text).toBe("Leo woke the Giant!")
		expect(rig.bannerSecond().Text).toBe("Run home with your egg!")
		expect(rig.bannerSecond().Visible).toBe(true)
		expect(rig.bannerEmoji().Text == "💥").toBe(true)
	end)

	it("shows to a player who carries nothing and has not grabbed yet", function()
		local rig = newRig()
		rig.wake("Leo")
		expect((rig.banner() :: Frame).Visible).toBe(true)
	end)

	it("shows one line on a phone screen 390 px tall: the second line is hidden", function()
		local rig = newRig(Vector2.new(844, 390))
		rig.wake("Leo")
		expect((rig.banner() :: Frame).Visible).toBe(true)
		expect(rig.bannerText().Text).toBe("Leo woke the Giant!")
		expect(rig.bannerSecond().Visible).toBe(false)
	end)

	it("says 'The Giant woke up!' when WokenBy is empty, with the same second line", function()
		local rig = newRig()
		rig.wake("")
		expect(rig.bannerText().Text).toBe("The Giant woke up!")
		expect(rig.bannerSecond().Text).toBe("Run home with your egg!")
	end)

	it("says 'The Giant woke up!' when WokenBy was never written", function()
		local rig = newRig()
		rig.setPhase("Awake")
		expect(rig.bannerText().Text).toBe("The Giant woke up!")
	end)

	it("hides after 3 seconds, by the fake clock", function()
		local rig = newRig()
		rig.wake("Leo")
		local timer = rig.timers[#rig.timers]
		expect(timer.seconds).toBe(3)
		expect(timer.ran).toBe(false)
		expect((rig.banner() :: Frame).Visible).toBe(true)
		rig.runLastTimer()
		expect((rig.banner() :: Frame).Visible).toBe(false)
	end)

	it("changes its words when WokenBy changes while it shows", function()
		local rig = newRig()
		rig.setPhase("Awake") -- Phase may arrive before WokenBy on a device
		expect(rig.bannerText().Text).toBe("The Giant woke up!")
		rig.setWokenBy("Leo")
		expect(rig.bannerText().Text).toBe("Leo woke the Giant!")
		rig.setWokenBy("Mia")
		expect(rig.bannerText().Text).toBe("Mia woke the Giant!")
	end)

	it("does not start its 3 seconds again when WokenBy changes while it shows", function()
		local rig = newRig()
		rig.setPhase("Awake")
		local before = #rig.timers
		rig.setWokenBy("Leo")
		expect(#rig.timers).toBe(before)
	end)

	it("does not come back when WokenBy changes after it hid", function()
		local rig = newRig()
		rig.wake("Leo")
		rig.runLastTimer()
		rig.setWokenBy("Mia")
		expect((rig.banner() :: Frame).Visible).toBe(false)
	end)

	it("keeps up with a name of 20 letters", function()
		local rig = newRig(Vector2.new(844, 390))
		rig.wake("Leo")
		rig.setWokenBy("ABCDEFGHIJKLMNOPQRST")
		expect(rig.bannerText().Text).toBe("ABCDEFGHIJKLMNOPQRST woke the Giant!")
		expect(rig.bannerText().TextWrapped).toBe(false)
	end)

	it("is not shown when he is already awake at the start", function()
		local rig = newRig(nil, "Awake")
		expect((rig.banner() :: Frame).Visible).toBe(false)
		expect(#rig.timers).toBe(0)
	end)

	it("starts its 3 seconds again at a new wake-up", function()
		local rig = newRig()
		rig.wake("Leo")
		local first = rig.timers[#rig.timers]
		rig.setPhase("HeavySleep")
		rig.setPhase("Asleep")
		rig.wake("Mia")
		expect(first.cancelled).toBe(true)
		local second = rig.timers[#rig.timers]
		expect(second).never.toBe(first)
		expect(second.seconds).toBe(3)
		expect(rig.bannerText().Text).toBe("Mia woke the Giant!")
		expect((rig.banner() :: Frame).Visible).toBe(true)
	end)

	it("does not show for Heavy Sleep", function()
		local rig = newRig()
		rig.setPhase("HeavySleep")
		expect((rig.banner() :: Frame).Visible).toBe(false)
		expect(#rig.timers).toBe(0)
	end)

	it("is taken off, its timer cancelled, and stops listening when the messages are stopped", function()
		local rig = newRig()
		rig.wake("Leo")
		local timer = rig.timers[#rig.timers]
		rig.handle.stop()
		expect(rig.banner()).toBeNil()
		expect(timer.cancelled).toBe(true)
		rig.setPhase("HeavySleep")
		rig.wake("Mia")
		expect(rig.banner()).toBeNil()
	end)

	it("makes no second banner when started again on the same screens", function()
		local rig = newRig()
		local again = Messages.start({
			parent = rig.parent,
			player = rig.me,
			grabMissed = { OnClientEvent = newSignal() },
			eggHome = { OnClientEvent = newSignal() },
			warning = { OnClientEvent = newSignal() },
			caught = { OnClientEvent = newSignal() },
			giantState = made(Instance.new("Folder")),
			viewport = {
				get = function()
					return Vector2.new(1280, 720)
				end,
				connect = function(_callback: () -> ())
					return function() end
				end,
			},
		})
		table.insert(stops, again.stop)
		local count = 0
		for _, descendant in rig.parent:GetDescendants() do
			if descendant.Name == "WakeBanner" then
				count += 1
			end
		end
		expect(count).toBe(1)
	end)
end)

describe("Messages: where the wake banner stands", function()
	it("is low and right of centre on a computer: on the Hud screen, 66% across, bottom 100 px up", function()
		local rig = newRig(Vector2.new(1280, 720))
		local banner = rig.banner() :: Frame
		expect(banner:IsDescendantOf(rig.hud())).toBe(true)
		expect(banner.AnchorPoint).toBe(Vector2.new(0.5, 1))
		expect(banner.Position.X).toBe(UDim.new(0.66, 0))
		-- the outline is drawn outside the banner, so the banner's body ends one outline's thickness higher
		expect(banner.Position.Y).toBe(UDim.new(1, -(100 + 5)))
	end)

	it("is low and right of centre on a phone too: on the Hud screen, 66% across, bottom 100 px up", function()
		-- Under the sleep meter it covered his eyes at landing spot 6, mid-float, on the iPhone 14.
		local rig = newRig(Vector2.new(844, 390))
		local banner = rig.banner() :: Frame
		expect(banner:IsDescendantOf(rig.hud())).toBe(true)
		expect(banner.AnchorPoint).toBe(Vector2.new(0.5, 1))
		expect(banner.Position.X).toBe(UDim.new(0.66, 0))
		expect(banner.Position.Y).toBe(UDim.new(1, -(100 + 3)))
	end)

	it("stays on the Hud screen and takes the new sizes when the screen changes size", function()
		local rig = newRig(Vector2.new(1280, 720))
		rig.setViewport(Vector2.new(844, 390))
		local banner = rig.banner() :: Frame
		expect(banner:IsDescendantOf(rig.hud())).toBe(true)
		expect(banner.Position.Y).toBe(UDim.new(1, -(100 + 3)))
		expect(rig.bannerSecond().Visible).toBe(false)
		rig.setViewport(Vector2.new(1280, 720))
		expect(banner:IsDescendantOf(rig.hud())).toBe(true)
		expect(banner.Position.Y).toBe(UDim.new(1, -(100 + 5)))
		expect(rig.bannerSecond().Visible).toBe(true)
	end)

	it("is turned 2 degrees", function()
		local rig = newRig()
		expect((rig.banner() :: Frame).Rotation).toBe(-2)
	end)

	it("has 34 px words and a 17 px second line on a computer, and 14 px words on a phone", function()
		local rig = newRig(Vector2.new(1280, 720))
		expect(rig.bannerText().TextSize).toBe(34)
		expect(rig.bannerEmoji().TextSize).toBe(34)
		expect(rig.bannerSecond().TextSize).toBe(17)
		rig.setViewport(Vector2.new(844, 390))
		expect(rig.bannerText().TextSize).toBe(14)
		expect(rig.bannerEmoji().TextSize).toBe(14)
	end)

	it("never shows text under 14 px", function()
		local rig = newRig(Vector2.new(844, 390))
		expect(rig.bannerText().TextSize >= 14).toBe(true)
		expect(rig.bannerEmoji().TextSize >= 14).toBe(true)
		expect(rig.bannerSecond().TextSize >= 14).toBe(true)
	end)
end)

describe("Messages: how the wake banner looks", function()
	it("is a red plate, light at the top and dark at the bottom, with the three reds of the mockup", function()
		local rig = newRig()
		local gradient = rig.bannerBody():FindFirstChildOfClass("UIGradient") :: UIGradient
		expect(gradient.Rotation).toBe(90)
		expect(gradient.Color.Keypoints[1].Value == Color3.fromHex("FF7A86")).toBe(true)
		expect(gradient.Color.Keypoints[2].Value == Color3.fromHex("FF3B4E")).toBe(true)
		expect(math.abs(gradient.Color.Keypoints[2].Time - 0.55) < 0.001).toBe(true)
		expect(gradient.Color.Keypoints[3].Value == Color3.fromHex("C4142A")).toBe(true)
	end)

	it("has an Ink outline of 5 px and rounded corners of 18 px on a computer", function()
		local rig = newRig(Vector2.new(1280, 720))
		local stroke = rig.bannerBody():FindFirstChildOfClass("UIStroke") :: UIStroke
		expect(stroke.Color == Theme.ink).toBe(true)
		expect(stroke.Thickness).toBe(5)
		expect((rig.bannerBody():FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toBe(UDim.new(0, 18))
	end)

	it("has a phone outline of 3 px and corners of 13 px", function()
		local rig = newRig(Vector2.new(844, 390))
		local stroke = rig.bannerBody():FindFirstChildOfClass("UIStroke") :: UIStroke
		expect(stroke.Thickness).toBe(3)
		expect((rig.bannerBody():FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toBe(UDim.new(0, 13))
	end)

	it("has an Ink shadow under it: 7 px on a computer, 5 px on a phone", function()
		local rig = newRig(Vector2.new(1280, 720))
		local shadow = rig.bannerShadow()
		expect(shadow.BackgroundColor3 == Theme.ink).toBe(true)
		expect(shadow.Position).toBe(UDim2.fromOffset(0, 7))
		rig.setViewport(Vector2.new(844, 390))
		expect(shadow.Position).toBe(UDim2.fromOffset(0, 5))
	end)

	it("has white words with an Ink outline", function()
		local rig = newRig()
		for _, label in { rig.bannerText(), rig.bannerSecond() } do
			expect(label.TextColor3 == Theme.white).toBe(true)
			local stroke = label:FindFirstChildOfClass("UIStroke") :: UIStroke
			expect(stroke.Color == Theme.ink).toBe(true)
		end
		expect(rig.bannerText().FontFace == Theme.font).toBe(true)
	end)

	it("has padding of 10 px up and down and 28 px each side on a computer", function()
		local rig = newRig(Vector2.new(1280, 720))
		local padding = rig.bannerBody():FindFirstChildOfClass("UIPadding") :: UIPadding
		expect(padding.PaddingTop).toBe(UDim.new(0, 10))
		expect(padding.PaddingBottom).toBe(UDim.new(0, 10))
		expect(padding.PaddingLeft).toBe(UDim.new(0, 28))
		expect(padding.PaddingRight).toBe(UDim.new(0, 28))
	end)
end)

describe("Messages: the green card while the wake banner shows", function()
	it("stays where it is on a phone: 62 px down", function()
		local rig = newRig(Vector2.new(844, 390))
		local card = rig.card() :: Frame
		local before = card.Position
		rig.eggHome:Fire(rig.me, "Common", Vector3.zero)
		rig.wake("Leo")
		expect(card.Position).toBe(before)
		expect(card.Position.Y).toBe(UDim.new(0, 62 + 3))
		expect(card.Visible).toBe(true)
		expect((rig.banner() :: Frame).Visible).toBe(true)
	end)

	it("stays where it is on a computer: 96 px down", function()
		local rig = newRig(Vector2.new(1280, 720))
		local card = rig.card() :: Frame
		rig.eggHome:Fire(rig.me, "Common", Vector3.zero)
		rig.wake("Leo")
		expect(card.Position.Y).toBe(UDim.new(0, 96 + 4))
		expect(card.Visible).toBe(true)
		expect((rig.banner() :: Frame).Visible).toBe(true)
	end)
end)

describe("Messages: the carry pill while he is awake", function()
	it("reads 'Dodge the red circles!' for a carrier while Phase is Awake, with the egg and the house", function()
		local rig = newRig()
		rig.setCarrying("Rare")
		rig.wake("Leo")
		expect(rig.pill().Visible).toBe(true)
		expect(rig.pillText().Text).toBe("Dodge the red circles!")
		expect(rig.pillHome().Text == "🏡").toBe(true)
		local gradient = rig.pillEgg():FindFirstChildOfClass("UIGradient") :: UIGradient
		expect(gradient.Color.Keypoints[2].Value == Theme.rarity.Rare.main).toBe(true)
	end)

	it("goes back to '[Rarity] egg! Get it home' when Phase leaves Awake", function()
		local rig = newRig()
		rig.setCarrying("Rare")
		rig.wake("Leo")
		rig.setPhase("HeavySleep")
		expect(rig.pillText().Text).toBe("Rare egg! Get it home")
		expect(rig.pill().Visible).toBe(true)
	end)

	it("goes back after a reset to Asleep too", function()
		local rig = newRig()
		rig.setCarrying("Common")
		rig.wake("Leo")
		rig.setPhase("Asleep")
		expect(rig.pillText().Text).toBe("Common egg! Get it home")
	end)

	it("says 'Dodge the red circles!' for an egg picked up while he is awake", function()
		local rig = newRig()
		rig.wake("Leo")
		rig.setCarrying("Uncommon")
		expect(rig.pillText().Text).toBe("Dodge the red circles!")
	end)

	it("says 'Dodge the red circles!' at the start for a carrier who joins while he is awake", function()
		local rig = newRig(nil, "Awake")
		rig.setCarrying("Common")
		expect(rig.pillText().Text).toBe("Dodge the red circles!")
	end)

	it("shows no pill for a player who carries nothing", function()
		local rig = newRig()
		rig.wake("Leo")
		expect(rig.pill().Visible).toBe(false)
	end)

	it("keeps the rarity's colour on the egg when the words change back", function()
		local rig = newRig()
		rig.setCarrying("Uncommon")
		rig.wake("Leo")
		rig.setPhase("HeavySleep")
		local gradient = rig.pillEgg():FindFirstChildOfClass("UIGradient") :: UIGradient
		expect(gradient.Color.Keypoints[2].Value == Theme.rarity.Uncommon.main).toBe(true)
	end)
end)

describe("Messages: the 85% tip when he wakes", function()
	it("ends at once for a carrier, who sees the pill with 'Dodge the red circles!'", function()
		local rig = newRig()
		rig.setCarrying("Rare")
		rig.warning:Fire(85)
		expect(rig.tip().Visible).toBe(true)
		expect(rig.pill().Visible).toBe(false)
		local warningTimer = rig.timers[#rig.timers]
		rig.wake("Leo")
		expect(rig.tip().Visible).toBe(false)
		expect(rig.pill().Visible).toBe(true)
		expect(rig.pillText().Text).toBe("Dodge the red circles!")
		expect(warningTimer.cancelled).toBe(true)
	end)

	it("ends at once for a player who carries nothing", function()
		local rig = newRig()
		rig.setCarrying("Common")
		rig.setCarrying(nil) -- the footprints tip is over after the first grab
		rig.warning:Fire(85)
		expect(rig.tip().Visible).toBe(true)
		rig.wake("Leo")
		expect(rig.tip().Visible).toBe(false)
	end)

	it("is not shown by a late 85 that arrives after he woke", function()
		local rig = newRig()
		rig.setCarrying("Rare")
		rig.wake("Leo")
		local timers = #rig.timers
		rig.warning:Fire(85)
		expect(rig.tip().Visible).toBe(false)
		expect(rig.pill().Visible).toBe(true)
		expect(rig.pillText().Text).toBe("Dodge the red circles!")
		expect(#rig.timers).toBe(timers)
	end)

	it("shows again at an 85 after he is back asleep", function()
		local rig = newRig()
		rig.setCarrying("Rare")
		rig.wake("Leo")
		rig.setPhase("HeavySleep")
		rig.setPhase("Asleep")
		rig.warning:Fire(85)
		expect(rig.tip().Visible).toBe(true)
		expect(rig.tipText().Text == Messages.standStillText).toBe(true)
	end)
end)

describe("Messages: the Caught! card's words", function()
	it("says Caught! with the second line 'The egg went back. You lost nothing else.'", function()
		expect(Messages.caughtTitle).toBe("Caught!")
		expect(Messages.caughtLine).toBe("The egg went back. You lost nothing else.")
		expect(Messages.caughtSeconds).toBe(3)
	end)
end)

describe("Messages: the Caught! card", function()
	it("is not there at the start", function()
		local rig = newRig()
		expect((rig.caughtCard() :: Frame).Visible).toBe(false)
	end)

	it("shows with the 💫, the words and the second line when this player is caught", function()
		local rig = newRig()
		rig.caught:Fire(rig.me)
		expect((rig.caughtCard() :: Frame).Visible).toBe(true)
		expect(rig.caughtEmoji().Text == "💫").toBe(true)
		expect(rig.caughtTitle().Text).toBe("Caught!")
		expect(rig.caughtLine().Text).toBe("The egg went back. You lost nothing else.")
	end)

	it("hides after 3 seconds, and not before", function()
		local rig = newRig()
		rig.caught:Fire(rig.me)
		expect(#rig.timers).toBe(1)
		expect(rig.timers[1].seconds).toBe(3)
		expect(rig.timers[1].ran).toBe(false)
		expect((rig.caughtCard() :: Frame).Visible).toBe(true)
		rig.runLastTimer()
		expect((rig.caughtCard() :: Frame).Visible).toBe(false)
	end)

	it("shows nothing when another player is caught", function()
		local rig = newRig()
		rig.caught:Fire({})
		expect((rig.caughtCard() :: Frame).Visible).toBe(false)
		expect(#rig.timers).toBe(0)
	end)

	it("shows nothing when the argument is not a player at all", function()
		local rig = newRig()
		rig.caught:Fire(nil)
		rig.caught:Fire("Leo")
		rig.caught:Fire(1)
		rig.caught:Fire(true)
		expect((rig.caughtCard() :: Frame).Visible).toBe(false)
		expect(#rig.timers).toBe(0)
	end)

	it("keeps itself up for 3 seconds from the second catch when it is caught again while it shows", function()
		local rig = newRig()
		rig.caught:Fire(rig.me)
		rig.caught:Fire(rig.me)
		expect(#rig.timers).toBe(2)
		expect(rig.timers[1].cancelled).toBe(true)
		expect(rig.timers[2].cancelled).toBe(false)
		expect(rig.timers[2].seconds).toBe(3)
		expect((rig.caughtCard() :: Frame).Visible).toBe(true)
		rig.runLastTimer()
		expect((rig.caughtCard() :: Frame).Visible).toBe(false)
	end)

	it("is taken off and stops listening when stopped, and its timer is cancelled", function()
		local rig = newRig()
		rig.caught:Fire(rig.me)
		rig.handle.stop()
		expect(rig.caughtCard()).toBeNil()
		expect(rig.caught:count()).toBe(0)
		expect(rig.timers[1].cancelled).toBe(true)
	end)

	it("makes no second card when started again on the same screen", function()
		local rig = newRig()
		local again = Messages.start({
			parent = rig.parent,
			player = rig.me,
			grabMissed = { OnClientEvent = newSignal() },
			eggHome = { OnClientEvent = newSignal() },
			warning = { OnClientEvent = newSignal() },
			caught = { OnClientEvent = newSignal() },
			giantState = made(Instance.new("Folder")),
			viewport = {
				get = function()
					return Vector2.new(1280, 720)
				end,
				connect = function(_callback: () -> ())
					return function() end
				end,
			},
		})
		table.insert(stops, again.stop)
		local count = 0
		for _, child in rig.parent:GetDescendants() do
			if child.Name == "CaughtCard" then
				count += 1
			end
		end
		expect(count).toBe(1)
	end)
end)

describe("Messages: where the Caught! card stands", function()
	it("is bottom left of centre on a computer: on the Hud screen, 30% across, bottom 22 px up", function()
		local rig = newRig(Vector2.new(1280, 720))
		local card = rig.caughtCard() :: Frame
		expect(card:IsDescendantOf(rig.hud())).toBe(true)
		expect(card.AnchorPoint).toBe(Vector2.new(0.5, 1))
		expect(card.Position.X).toBe(UDim.new(0.3, 0))
		-- the outline is drawn outside the card, so the card's body ends one outline's thickness higher
		expect(card.Position.Y).toBe(UDim.new(1, -(22 + 4)))
	end)

	it("is bottom centre on a phone: on the Hud screen, 50% across, bottom 14 px up", function()
		local rig = newRig(Vector2.new(844, 390))
		local card = rig.caughtCard() :: Frame
		expect(card:IsDescendantOf(rig.hud())).toBe(true)
		expect(card.AnchorPoint).toBe(Vector2.new(0.5, 1))
		expect(card.Position.X).toBe(UDim.new(0.5, 0))
		expect(card.Position.Y).toBe(UDim.new(1, -(14 + 3)))
	end)

	it("moves to the other place when the screen changes size", function()
		local rig = newRig(Vector2.new(1280, 720))
		local card = rig.caughtCard() :: Frame
		rig.setViewport(Vector2.new(844, 390))
		expect(card.Position.X).toBe(UDim.new(0.5, 0))
		expect(card.Position.Y).toBe(UDim.new(1, -(14 + 3)))
		rig.setViewport(Vector2.new(1280, 720))
		expect(card.Position.X).toBe(UDim.new(0.3, 0))
		expect(card.Position.Y).toBe(UDim.new(1, -(22 + 4)))
	end)

	it("is its own frame on the Hud screen, not the carry pill's or the tips' frame", function()
		local rig = newRig(Vector2.new(1280, 720))
		local card = rig.caughtCard() :: Frame
		expect(card.Parent).toBe(rig.hud())
		expect(card).never.toBe(rig.pill())
		expect(card).never.toBe(rig.tip())
		expect(card:IsDescendantOf(rig.pill())).toBe(false)
		expect(card:IsDescendantOf(rig.tip())).toBe(false)
	end)
end)

describe("Messages: how the Caught! card looks", function()
	it("is a cream plate with an Ink outline of 4 px and corners of 20 px on a computer", function()
		local rig = newRig(Vector2.new(1280, 720))
		local body = rig.caughtBody()
		expect(body.BackgroundColor3 == Theme.cream).toBe(true)
		expect(body.BackgroundTransparency).toBe(0)
		local stroke = body:FindFirstChildOfClass("UIStroke") :: UIStroke
		expect(stroke.Color == Theme.ink).toBe(true)
		expect(stroke.Thickness).toBe(4)
		expect((body:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toBe(UDim.new(0, 20))
	end)

	it("has a phone outline of 3 px and corners of 12 px", function()
		local rig = newRig(Vector2.new(844, 390))
		local body = rig.caughtBody()
		expect((body:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness).toBe(3)
		expect((body:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius).toBe(UDim.new(0, 12))
	end)

	it("has an Ink shadow under it: 6 px on a computer, 4 px on a phone", function()
		local rig = newRig(Vector2.new(1280, 720))
		local shadow = rig.caughtShadow()
		expect(shadow.BackgroundColor3 == Theme.ink).toBe(true)
		expect(shadow.Position).toBe(UDim2.fromOffset(0, 6))
		rig.setViewport(Vector2.new(844, 390))
		expect(shadow.Position).toBe(UDim2.fromOffset(0, 4))
	end)

	it("has Ink words with no outline, in the game's font", function()
		local rig = newRig()
		local labels: { TextLabel? } = { rig.caughtTitle(), rig.caughtLine() }
		expect(#labels).toBe(2)
		for _, label in labels do
			expect(label).never.toBeNil()
			local words = label :: TextLabel
			expect(words.TextColor3 == Theme.ink).toBe(true)
			expect(words.FontFace == Theme.font).toBe(true)
			expect(words:FindFirstChildOfClass("UIStroke")).toBeNil()
		end
	end)

	it("has 24 px words, a 15 px second line and a 40 px emoji on a computer", function()
		local rig = newRig(Vector2.new(1280, 720))
		expect(rig.caughtTitle().TextSize).toBe(24)
		expect(rig.caughtLine().TextSize).toBe(15)
		expect(rig.caughtEmoji().TextSize).toBe(40)
		local padding = rig.caughtBody():FindFirstChildOfClass("UIPadding") :: UIPadding
		expect(padding.PaddingTop).toBe(UDim.new(0, 8))
		expect(padding.PaddingBottom).toBe(UDim.new(0, 8))
		expect(padding.PaddingLeft).toBe(UDim.new(0, 10))
		expect(padding.PaddingRight).toBe(UDim.new(0, 22))
	end)

	it("has 14 px words and a 26 px emoji on a phone, and never text under 14 px", function()
		local rig = newRig(Vector2.new(844, 390))
		expect(rig.caughtTitle().TextSize).toBe(14)
		expect(rig.caughtLine().TextSize).toBe(14)
		expect(rig.caughtEmoji().TextSize).toBe(26)
	end)

	it("puts the second line under the words, and the emoji before both", function()
		local rig = newRig()
		local column = rig.caughtTitle().Parent :: Frame
		expect(rig.caughtLine().Parent).toBe(column)
		local list = column:FindFirstChildOfClass("UIListLayout") :: UIListLayout
		expect(list.FillDirection).toBe(Enum.FillDirection.Vertical)
		expect(rig.caughtTitle().LayoutOrder < rig.caughtLine().LayoutOrder).toBe(true)
		expect(rig.caughtEmoji().LayoutOrder < column.LayoutOrder).toBe(true)
		expect(rig.caughtEmoji().Parent).toBe(column.Parent)
	end)
end)

describe("Messages: the Caught! card beside the other messages", function()
	it("leaves the tip and the carry pill alone: a caught player carries nothing, and the tip is unchanged", function()
		local rig = newRig()
		rig.setCarrying("Common")
		rig.setCarrying(nil) -- the server took the egg back
		expect(rig.pill().Visible).toBe(false)
		expect(rig.tip().Visible).toBe(false) -- the footprints tip ends at the first grab
		rig.caught:Fire(rig.me)
		expect((rig.caughtCard() :: Frame).Visible).toBe(true)
		expect(rig.pill().Visible).toBe(false)
		expect(rig.tip().Visible).toBe(false)
	end)

	it("does not hide a tip that is showing", function()
		local rig = newRig()
		rig.warning:Fire(85)
		expect(rig.tip().Visible).toBe(true)
		rig.caught:Fire(rig.me)
		expect(rig.tip().Visible).toBe(true)
		expect(rig.tipText().Text).toBe(Messages.standStillText)
	end)

	it("shows together with the wake banner, and neither hides the other", function()
		local rig = newRig()
		rig.wake("Leo")
		rig.caught:Fire(rig.me)
		expect((rig.banner() :: Frame).Visible).toBe(true)
		expect((rig.caughtCard() :: Frame).Visible).toBe(true)
		rig.runLastTimer() -- the card's 3 seconds
		expect((rig.banner() :: Frame).Visible).toBe(true)
		expect((rig.caughtCard() :: Frame).Visible).toBe(false)
	end)

	it("does not hide the green card", function()
		local rig = newRig()
		rig.eggHome:Fire(rig.me, "Common", Vector3.zero)
		rig.caught:Fire(rig.me)
		expect((rig.card() :: Frame).Visible).toBe(true)
		expect((rig.caughtCard() :: Frame).Visible).toBe(true)
	end)
end)
