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

describe("Messages: the Caught! card's words", function()
	it("says Caught! with the second line 'The egg went back. You lost nothing else.'", function()
		expect(Messages.caughtTitle).toBe("Caught!")
		expect(Messages.caughtLine).toBe("The egg went back. You lost nothing else.")
		expect(Messages.caughtSeconds).toBe(3)
	end)
end)
