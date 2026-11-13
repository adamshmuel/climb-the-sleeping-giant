--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local JestGlobals = require(game:GetService("ServerStorage").DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach
local Theme = require(StarterPlayer.StarterPlayerScripts.Client.Hud.Theme)
local Helpers = require(script.Parent.Helpers)

afterEach(Helpers.cleanUp)

local NEW_RANKS = { "Epic", "Legendary" }

-- Spec Rule 52: the rank shows everywhere, in the rank's three colours.
describe("Messages: Epic and Legendary in the carry pill", function()
	for _, rank in NEW_RANKS do
		it(`says "{rank} egg! Get it home" and paints its egg in the {rank} colours`, function()
			local rig = Helpers.newRig()
			rig.setCarrying(rank)
			expect(rig.pill().Visible).toBe(true)
			expect(rig.pillText().Text).toBe(`{rank} egg! Get it home`)
			local look = Theme.rarity[rank]
			local gradient = rig.pillEgg():FindFirstChildOfClass("UIGradient") :: UIGradient
			expect(gradient.Color.Keypoints[1].Value == look.light).toBe(true)
			expect(gradient.Color.Keypoints[2].Value == look.main).toBe(true)
			expect(gradient.Color.Keypoints[3].Value == look.dark).toBe(true)
		end)
	end

	it("still shows nothing for a made-up rank, Mythic", function()
		local rig = Helpers.newRig()
		rig.setCarrying("Mythic")
		expect(rig.pill().Visible).toBe(false)
	end)
end)

describe("Messages: Epic and Legendary in the Safe card", function()
	for _, rank in NEW_RANKS do
		it(`says "Safe! {rank} egg is home", keeps the card green and paints its egg`, function()
			local rig = Helpers.newRig()
			rig.eggHome:Fire(rig.me, rank, Vector3.zero)
			expect((rig.card() :: Frame).Visible).toBe(true)
			expect(rig.cardText().Text).toBe(`Safe! {rank} egg is home`)
			local body = (rig.card() :: Frame):FindFirstChild("SafeCardBody", true) :: Frame
			local bodyGradient = body:FindFirstChildOfClass("UIGradient") :: UIGradient
			expect(bodyGradient.Color.Keypoints[2].Value == Theme.cardGreen).toBe(true)
			local look = Theme.rarity[rank]
			local gradient = rig.cardEgg():FindFirstChildOfClass("UIGradient") :: UIGradient
			expect(gradient.Color.Keypoints[1].Value == look.light).toBe(true)
			expect(gradient.Color.Keypoints[2].Value == look.main).toBe(true)
			expect(gradient.Color.Keypoints[3].Value == look.dark).toBe(true)
		end)
	end

	it("still shows nothing for a made-up rank, Mythic", function()
		local rig = Helpers.newRig()
		rig.eggHome:Fire(rig.me, "Mythic", Vector3.zero)
		expect((rig.card() :: Frame).Visible).toBe(false)
	end)
end)
