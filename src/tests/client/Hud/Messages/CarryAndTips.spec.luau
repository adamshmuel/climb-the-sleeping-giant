--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
-- The little house is compared with `==` and checked for true, because Jest's failure messages break on emoji.
local Hud = StarterPlayer.StarterPlayerScripts.Client.Hud
local Messages = require(Hud.Messages)
local Theme = require(Hud.Theme)
local HuntView = require(Hud.HuntView)
local Helpers = require(script.Parent.Helpers)
type Rig = Helpers.Rig
local cleanUp = Helpers.cleanUp
local made = Helpers.made
local newRig = Helpers.newRig
local newSignal = Helpers.newSignal
local stops = Helpers.stops

afterEach(cleanUp)

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
			slideTip = { OnClientEvent = newSignal() },
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
			slideTip = { OnClientEvent = newSignal() },
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

	it("starts the 3 seconds again when the free save replays the warning while the tip shows", function()
		local rig = newRig()
		rig.setCarrying("Common") -- the footprints tip is over after the first grab
		rig.setCarrying(nil)
		rig.warning:Fire(85)
		local first = rig.timers[#rig.timers]
		rig.warning:Fire(85, "FreeSave")
		expect(first.cancelled).toBe(true)
		local second = rig.timers[#rig.timers]
		expect(second).never.toBe(first)
		expect(second.seconds).toBe(3)
		expect(second.ran).toBe(false)
		expect(rig.tip().Visible).toBe(true)
		expect(rig.tipText().Text == Messages.standStillText).toBe(true)
		rig.runLastTimer()
		expect(rig.tip().Visible).toBe(false)
	end)

	it("shows for a replay that is the first warning, for 3 seconds", function()
		local rig = newRig()
		rig.setCarrying("Common")
		rig.setCarrying(nil)
		rig.warning:Fire(85, "FreeSave")
		expect(rig.tip().Visible).toBe(true)
		expect(rig.tipText().Text == Messages.standStillText).toBe(true)
		expect(rig.timers[#rig.timers].seconds).toBe(3)
	end)

	it("gives a carrier the tip for 3 seconds again at a replay, and the pill comes back after", function()
		local rig = newRig()
		rig.setCarrying("Rare")
		rig.warning:Fire(85)
		local first = rig.timers[#rig.timers]
		rig.warning:Fire(85, "FreeSave")
		expect(first.cancelled).toBe(true)
		expect(rig.tip().Visible).toBe(true)
		expect(rig.tipText().Text == Messages.standStillText).toBe(true)
		expect(rig.pill().Visible).toBe(false)
		expect(rig.timers[#rig.timers].seconds).toBe(3)
		rig.runLastTimer()
		expect(rig.tip().Visible).toBe(false)
		expect(rig.pill().Visible).toBe(true)
		expect(rig.pillText().Text).toBe("Rare egg! Get it home")
	end)

	it("shows nothing for a second value that is not FreeSave", function()
		local rig = newRig()
		rig.setCarrying("Common")
		rig.setCarrying(nil)
		rig.warning:Fire(85, "Something")
		expect(rig.tip().Visible).toBe(false)
		expect(#rig.timers).toBe(0)
	end)

	it("leaves a carrier's pill alone for a second value that is not FreeSave", function()
		local rig = newRig()
		rig.setCarrying("Rare")
		rig.warning:Fire(85, "Something")
		expect(rig.tip().Visible).toBe(false)
		expect(rig.pill().Visible).toBe(true)
		expect(#rig.timers).toBe(0)
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

-- The strokes on a piece and everything inside it (the circle's rims may be its own or a child's).
local function strokeColors(piece: Instance): { Color3 }
	local colors: { Color3 } = {}
	for _, instance in { piece, table.unpack(piece:GetDescendants()) } do
		if instance:IsA("UIStroke") then
			table.insert(colors, instance.Color)
		end
	end
	return colors
end

local function hasColor(colors: { Color3 }, wanted: Color3): boolean
	for _, color in colors do
		if color == wanted then
			return true
		end
	end
	return false
end

describe("Messages: the bottom tip follows HuntView's tip while he is awake", function()
	it("shows the circle icon and the dodge words for a player with no egg outside a garden", function()
		local rig = newRig()
		rig.wake("Leo")
		expect(rig.tipCircle()).never.toBeNil()
		expect((rig.tipCircle() :: Frame).Visible).toBe(true)
		expect(rig.tip().Visible).toBe(true)
		expect(rig.tipText().Text).toBe(Messages.dodgeText)
		expect(rig.pill().Visible).toBe(false)
	end)

	it("draws the circle red with a gold rim and an Ink ring: 40 px on a computer, 24 px on a phone", function()
		local rig = newRig(Vector2.new(1280, 720))
		rig.wake("Leo")
		local circle = rig.tipCircle() :: Frame
		expect(circle.BackgroundColor3 == Theme.slamRed).toBe(true)
		expect(hasColor(strokeColors(circle), Theme.slamGold)).toBe(true)
		expect(hasColor(strokeColors(circle), Theme.ink)).toBe(true)
		expect(circle.Size).toBe(UDim2.fromOffset(40, 40))
		rig.setViewport(Vector2.new(844, 390))
		expect(circle.Size).toBe(UDim2.fromOffset(24, 24))
	end)

	it("keeps the egg icon for a carrier, with the dodge words, and hides the circle", function()
		local rig = newRig()
		rig.setCarrying("Rare")
		rig.wake("Leo")
		expect(rig.pill().Visible).toBe(true)
		expect(rig.pillEgg().Visible).toBe(true)
		expect(rig.pillText().Text).toBe(Messages.dodgeText)
		expect(rig.tipCircle()).never.toBeNil()
		expect((rig.tipCircle() :: Frame).Visible).toBe(false)
	end)

	it("hides both icons and both tips inside a garden, and brings them back when the view changes back", function()
		local rig = newRig()
		rig.wake("Leo")
		rig.setInGarden(3)
		expect(rig.tipCircle()).never.toBeNil()
		expect((rig.tipCircle() :: Frame).Visible).toBe(false)
		expect(rig.pill().Visible).toBe(false)
		expect(rig.tipText().Text == Messages.dodgeText and rig.tip().Visible).toBe(false)
		rig.setInGarden(0)
		expect((rig.tipCircle() :: Frame).Visible).toBe(true)
		expect(rig.tipText().Text).toBe(Messages.dodgeText)
	end)

	it("hides a carrier's egg pill inside a garden and shows it again outside", function()
		local rig = newRig()
		rig.setCarrying("Common")
		rig.wake("Leo")
		rig.setInGarden(2)
		expect(rig.pill().Visible).toBe(false)
		rig.setInGarden(0)
		expect(rig.pill().Visible).toBe(true)
		expect(rig.pillText().Text).toBe(Messages.dodgeText)
	end)

	it("turns the egg into the circle when the egg is lost while he is awake", function()
		local rig = newRig()
		rig.setCarrying("Common")
		rig.wake("Leo")
		rig.setCarrying(nil)
		expect(rig.pill().Visible).toBe(false)
		expect((rig.tipCircle() :: Frame).Visible).toBe(true)
	end)

	it("shows no circle while he sleeps", function()
		local rig = newRig()
		rig.wake("Leo")
		rig.setPhase("Asleep")
		expect(rig.tipCircle()).never.toBeNil()
		expect((rig.tipCircle() :: Frame).Visible).toBe(false)
	end)

	it("makes no new HuntView watcher: it reads the view it is given", function()
		local watch = HuntView.watch
		local calls = 0
		HuntView.watch = function(...)
			calls += 1
			return watch(...)
		end
		local ok, err = pcall(function()
			local rig = newRig()
			rig.wake("Leo")
			rig.setInGarden(1)
		end)
		HuntView.watch = watch
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(calls).toBe(0)
	end)
end)
