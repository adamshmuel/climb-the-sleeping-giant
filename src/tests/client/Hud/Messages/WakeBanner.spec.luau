--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
-- The little house is compared with `==` and checked for true, because Jest's failure messages break on emoji.
local Hud = StarterPlayer.StarterPlayerScripts.Client.Hud
local Messages = require(Hud.Messages)
local Theme = require(Hud.Theme)
local Helpers = require(script.Parent.Helpers)
local cleanUp = Helpers.cleanUp
local made = Helpers.made
local newRig = Helpers.newRig
local newSignal = Helpers.newSignal
local stops = Helpers.stops

afterEach(cleanUp)

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
