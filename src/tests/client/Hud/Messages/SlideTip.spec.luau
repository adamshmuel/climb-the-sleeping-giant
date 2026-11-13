--!strict
-- Rule 84: a slide is a fall, and the first one gets a tip. The server fires SlideTip once; the tip plate shows the
-- words for Config.Nests.SlideTipSeconds, and a carrier's pill gives its place to the tip for that time.
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Messages = require(StarterPlayer.StarterPlayerScripts.Client.Hud.Messages)
local Helpers = require(script.Parent.Helpers)

afterEach(Helpers.cleanUp)

-- A player who already grabbed once (so the footprints tip is gone) and now carries nothing.
local function seasonedRig(): Helpers.Rig
	local rig = Helpers.newRig()
	rig.setCarrying("Common")
	rig.setCarrying(nil)
	return rig
end

describe("Messages: the slide tip", function()
	it("shows the slide words for the configured seconds on a player who carries nothing, then hides them", function()
		local rig = seasonedRig()
		expect(rig.tip().Visible).toBe(false)
		rig.slideTip:Fire()
		expect(rig.tip().Visible).toBe(true)
		expect(rig.tipText().Text).toBe(Messages.slideText)
		expect(#rig.timers).toBe(1)
		expect(rig.timers[1].seconds).toBe(Config.Nests.SlideTipSeconds)
		rig.runLastTimer()
		expect(rig.tip().Visible).toBe(false)
	end)

	it("hides a carrier's pill while the tip shows and brings it back after", function()
		local rig = Helpers.newRig()
		rig.setCarrying("Rare")
		expect(rig.pill().Visible).toBe(true)
		rig.slideTip:Fire()
		expect(rig.pill().Visible).toBe(false)
		expect(rig.tip().Visible).toBe(true)
		expect(rig.tipText().Text).toBe(Messages.slideText)
		rig.runLastTimer()
		expect(rig.pill().Visible).toBe(true)
		expect(rig.tip().Visible).toBe(false)
	end)

	it(
		"waits for the 85% tip to end, then shows its full seconds, with the carrier's pill hidden through both",
		function()
			local rig = Helpers.newRig()
			rig.setCarrying("Rare")
			rig.warning:Fire(85)
			expect(rig.tipText().Text).toBe(Messages.standStillText)
			rig.slideTip:Fire()
			expect(rig.tipText().Text).toBe(Messages.standStillText) -- the warning wins
			expect(#rig.timers).toBe(1) -- the slide tip's seconds have not started
			expect(rig.pill().Visible).toBe(false)
			rig.runLastTimer() -- the 85% tip ends
			expect(rig.tipText().Text).toBe(Messages.slideText)
			expect(rig.tip().Visible).toBe(true)
			expect(rig.pill().Visible).toBe(false)
			expect(#rig.timers).toBe(2)
			expect(rig.timers[2].seconds).toBe(Config.Nests.SlideTipSeconds)
			rig.runLastTimer()
			expect(rig.tip().Visible).toBe(false)
			expect(rig.pill().Visible).toBe(true)
		end
	)

	it("waits while the phone grab pill is pinned, then shows its full seconds once it is let go", function()
		local rig = seasonedRig()
		rig.handle.setPillPinned(true)
		rig.slideTip:Fire()
		expect(rig.tip().Visible).toBe(false)
		expect(#rig.timers).toBe(0) -- nobody can see the tip yet, so the seconds have not started
		rig.handle.setPillPinned(false)
		expect(rig.tip().Visible).toBe(true)
		expect(rig.tipText().Text).toBe(Messages.slideText)
		expect(#rig.timers).toBe(1)
		expect(rig.timers[1].seconds).toBe(Config.Nests.SlideTipSeconds)
	end)

	it("does not extend the tip when a second one arrives while it shows", function()
		local rig = seasonedRig()
		rig.slideTip:Fire()
		rig.slideTip:Fire()
		expect(#rig.timers).toBe(1)
		expect(rig.timers[1].cancelled).toBe(false)
		rig.runLastTimer()
		expect(rig.tip().Visible).toBe(false)
	end)
end)
