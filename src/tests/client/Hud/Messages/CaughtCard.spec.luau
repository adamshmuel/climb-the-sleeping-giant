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
