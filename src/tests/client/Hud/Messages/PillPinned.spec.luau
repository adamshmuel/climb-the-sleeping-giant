--!strict
-- The bottom tips hide while the phone grab pill is pinned, and a timed tip that comes due then waits for its full
-- time (Task 56; designer's pill place, product's change: tips that come due while the pill is pinned wait).
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local Messages = require(StarterPlayer.StarterPlayerScripts.Client.Hud.Messages)
local Helpers = require(script.Parent.Helpers)

afterEach(Helpers.cleanUp)

describe("Messages: the pinned grab pill", function()
	it("hides the footprints tip while the pill is pinned and brings it back when it is not", function()
		local rig = Helpers.newRig()
		expect(rig.tip().Visible).toBe(true)
		rig.handle.setPillPinned(true)
		expect(rig.tip().Visible).toBe(false)
		rig.handle.setPillPinned(false)
		expect(rig.tip().Visible).toBe(true)
	end)

	it("keeps a missed-grab tip that comes due while pinned waiting, then shows it for its full 2 seconds", function()
		local rig = Helpers.newRig()
		rig.handle.setPillPinned(true)
		rig.grabMissed:Fire()
		expect(rig.tip().Visible).toBe(false)
		expect(#rig.timers).toBe(0) -- the 2 seconds have not started: nobody can see the tip
		rig.handle.setPillPinned(false)
		expect(rig.tip().Visible).toBe(true)
		expect(rig.tipText().Text).toBe(Messages.missedText)
		expect(#rig.timers).toBe(1)
		expect(rig.timers[1].seconds).toBe(Messages.missedSeconds)
	end)

	it("keeps the 85% warning tip that comes due while pinned waiting, then shows it for its full 3 seconds", function()
		local rig = Helpers.newRig()
		rig.handle.setPillPinned(true)
		rig.warning:Fire(85)
		expect(rig.tip().Visible).toBe(false)
		expect(#rig.timers).toBe(0)
		rig.handle.setPillPinned(false)
		expect(rig.tip().Visible).toBe(true)
		expect(rig.tipText().Text).toBe(Messages.standStillText)
		expect(#rig.timers).toBe(1)
		expect(rig.timers[1].seconds).toBe(Messages.standStillSeconds)
	end)

	it("starts no second clock when a tip that already runs is still running as the pill unpins", function()
		local rig = Helpers.newRig()
		rig.grabMissed:Fire()
		expect(#rig.timers).toBe(1)
		rig.handle.setPillPinned(true)
		rig.handle.setPillPinned(false)
		expect(#rig.timers).toBe(1)
	end)
end)
